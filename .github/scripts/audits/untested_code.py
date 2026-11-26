"""Untested-code audit (weekly, Tuesday 09:07 UTC; PR with new tests; Opus).

Owner request 2026-11-18. Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md
(Part 4, "Untested code"). Contract the tests follow: R/package_metadata/contracts/coverage_test_writing.md.

Coverage is read, never re-measured for the ranking:

- R and C++: the newest `coverage-lines` artifact of test-coverage-R.yaml on main (one CSV row per
  covr expression, written by untested_code_export.R in the merge job). The covr report already holds
  the gcov lines of R/EDI/src (.cpp and .h), because the shards build with covr's --coverage flags
  (run_shard.R: type = "none"). When no `coverage-lines` artifact exists yet, the newest
  `coverage-merged` artifact is converted with untested_code_export.R if Rscript is on the PATH.
- Python: the newest `coverage-python` artifact (coverage.xml from test-coverage-python.yml, which
  runs pytest --cov on every main push through build-wheels.yml). Only python/src is measured; the
  pybind code in python/cpp is measured nowhere.
- Local runs: UNTESTED_CODE_R_LINES (CSV), UNTESTED_CODE_R_RDS (merged-coverage.rds) and
  UNTESTED_CODE_PY_XML (coverage.xml) name files instead of downloading.

Regions. Coverage line numbers belong to the commit the report measured. They are carried to HEAD
through `git diff -U0 <measured> HEAD`; a line inside a changed hunk is dropped (it was not measured
as it is now). A region is a run of uncovered lines in one function of one file, broken by any
covered line. Its id, `unt-<12 hex>`, hashes the file, the function and the region's code with
whitespace removed, not line numbers, so it survives code moving; an edit inside the region, or a
test that covers part of it, makes a new id.

Not ranked (intended-uncovered): lines marked `# nocov` / `// nocov` (and LCOV_EXCL), nocov
start/end blocks, platform branches (`#ifdef _WIN32`-style blocks, R branches on `.Platform$OS.type`
or `Sys.info()`), files the coverage registry marks excluded or codecov.yml ignores (the known
measurement artifacts, contract section 6), generated files, single isolated C++ lines with no
control flow (-O2 line noise, contract 6.3), and ALLOWLIST rows. Every allowlist row must lead its
reason with an open release TODO (`v1.0.6-TODO-6: ...`), as the calibration and NA allowlists do; a
row whose TODO is ticked, moved or missing does not excuse anything and is reported (the
allowlist-hygiene audit also removes it).

Ranking: risk, not size. score = 8 if the region is in an exported function or a documented public
R6 method (+2 for compute_* and design entry points), 3 if in an Rcpp-exported kernel, + 4 if it
is an error or guard branch (stop/warning/throw, return NA/NULL/false, finiteness checks), + 2 if
its lines changed in the last RECENT_DAYS days, + 1 if a commit citing a TODO of the current
release changed them. The region's size only breaks ties.

Claude stage (Opus, 3 regions per agent, at most TOP_N regions a run): read-only, as every audit.
For each region the agent returns one outcome: `test` (a testthat test for the bulk tier, following
the contract), `unreachable` (no public path reaches it, with the evidence), `intended` (should be
uncovered: the owner may add an allowlist row), or `bug` (a test that fails on the current code).

Finish stage (EDI built on the runner with covr's --coverage flags, EDI_UNITY=0, in place):
each test runs in its own Rscript under pkgload::load_all(compile = FALSE), inside
covr::environment_coverage() for the R lines (in-process tracing of the loaded namespace, which also
attributes composed classes back to their component files) and with fresh .gcda files read by gcov
for the C++ lines. A `test` is kept only if every expectation passed, none errored or skipped, it
asserts a value (not only that the code ran), and it hits at least MIN_COVERED_SHARE of the region's
lines. Kept tests go into the PR under R/package_tests/testthat_bulk/. A `bug` test is kept only if
it fails as claimed; it is reported under "Decisions for you", never committed. `unreachable`
regions go to untested-code/unreachable.json on audit-notes, which the dead-code audit reads.

State on audit-notes (untested-code/): regions.json (id -> status, attempts, last reason),
unreachable.json, manifest.json, findings.jsonl. A region whose test failed verification is retried
after COOLDOWN_WEEKS weeks with the failure in its context, at most MAX_ATTEMPTS times; then it
becomes a decision for the owner. The run is skipped (no Claude) when scripts/significant_changes.py
finds no code or test change since the last run, unless scope is `all`.

Mutation testing (do the kept tests detect a changed line?) is future work (plan doc).
Stdlib only.
"""
import csv
import fnmatch
import io
import json
import os
import re
import subprocess
import sys
import time
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve()
if str(HERE.parents[1]) not in sys.path:   # a local or CLI run: make audit_common importable
    sys.path.insert(0, str(HERE.parents[1]))
import audit_common as ac  # noqa: E402

SPEC = {
    "name": "untested-code",
    "title": "Untested code",
    "report": "pr",
    "claude": True,
    "model": ac.OPUS,
    "batch_size": 3,       # each region needs its code, its callers and a reference test
    "max_batches": 4,      # TOP_N = 12 regions a run
    "cycle_weeks": 1,      # units() returns only the regions due this run
    "max_turns": 80,
    "tools": "Read,Glob,Grep",
}
TOP_N = SPEC["batch_size"] * SPEC["max_batches"]

ALLOWLIST = "R/package_metadata/audits/untested_code_allowlist.csv"
REGISTRY = "R/package_tests/coverage_gap_registry.csv"
CODECOV = "codecov.yml"
NAMESPACE = "R/EDI/NAMESPACE"
MAN_DIR = "R/EDI/man"
BULK = "R/package_tests/testthat_bulk"
EXPORT_R = str(HERE.parent / "untested_code_export.R")
SOURCE_DIRS = ("R/EDI/R", "R/EDI/src", "python/src")
CHANGE_PATHS = ("R/EDI/R", "R/EDI/src", "python/src", "python/cpp", "R/EDI/tests", BULK)
GENERATED = ("*/RcppExports.*", "*.pyi")
ARTIFACT_LINES, ARTIFACT_MERGED, ARTIFACT_PY = "coverage-lines", "coverage-merged", "coverage-python"

RECENT_DAYS = 90
COOLDOWN_WEEKS = 4
MAX_ATTEMPTS = 2
MIN_COVERED_SHARE = 0.5
PER_TEST_TIMEOUT = 600     # traced R runs several times slower than plain R
TOTAL_TEST_BUDGET = 75 * 60
MAX_EXCERPT_LINES = 220
MAX_PER_FUNCTION = 2       # a run's regions spread over functions and files: the same guard copied into
MAX_PER_FILE = 3           # twenty classes (compute_estimate_with_bootstrap_weights) is not twenty risks

R_EXT, CPP_EXT, PY_EXT = (".R", ".r"), (".cpp", ".cc", ".c", ".h", ".hpp"), (".py",)
OUTCOMES = ("test", "unreachable", "intended", "bug")


def lang_of(path):
    return "R" if path.endswith(R_EXT) else "C++" if path.endswith(CPP_EXT) else "Python" if path.endswith(PY_EXT) else "?"


# ---------------------------------------------------------------- coverage input

def parse_lines_csv(text):
    """untested_code_export.R output -> (meta, [(file, first, last, value, fn)])."""
    meta, body = {}, []
    for line in text.splitlines():
        if line.startswith("#"):
            meta.update(dict(kv.split("=", 1) for kv in line[1:].split() if "=" in kv))
        else:
            body.append(line)
    rows = []
    for r in csv.DictReader(io.StringIO("\n".join(body))):
        try:
            rows.append((r["file"], int(r["first_line"]), int(r["last_line"]), float(r["value"]), r.get("fn") or ""))
        except (KeyError, TypeError, ValueError):
            continue
    return meta, rows


def expressions_to_lines(rows):
    """{file: {line: [hits, fn]}}: a line's count is the smallest count of any expression spanning it
    (an outer call that ran with an inner branch that did not leaves the branch's lines at 0, as covr's
    line tally does); its function is that of the narrowest expression on it."""
    out, span = {}, {}
    for f, a, b, v, fn in rows:
        fl, fs = out.setdefault(f, {}), span.setdefault(f, {})
        for ln in range(a, max(a, b) + 1):
            width = b - a
            if ln not in fl:
                fl[ln], fs[ln] = [v, fn], width
            else:
                fl[ln][0] = min(fl[ln][0], v)
                if width < fs[ln] and fn:
                    fl[ln][1], fs[ln] = fn, width
    return out


def parse_cobertura(xml_text):
    """coverage.py's cobertura XML -> {repo path: {line: [hits, ""]}} for python/src files."""
    import xml.etree.ElementTree as ET
    root = ET.fromstring(xml_text)
    out = {}
    for cls in root.iter("class"):
        fn = (cls.get("filename") or "").replace("\\", "/")
        i = fn.find("edi_kernels/")
        if i < 0:
            continue
        rel = "python/src/" + fn[i:]
        lines = out.setdefault(rel, {})
        for ln in cls.iter("line"):
            try:
                lines[int(ln.get("number"))] = [float(ln.get("hits", "0")), ""]
            except (TypeError, ValueError):
                pass
    return out


def _gh(*args, binary=False):
    r = subprocess.run(["gh", *args], capture_output=True, text=not binary)
    if r.returncode:
        err = r.stderr if not binary else r.stderr.decode(errors="replace")
        raise RuntimeError(f"gh {' '.join(args[:2])}: {err.strip()[:300]}")
    return r.stdout


def find_artifact(name, branch="main", repo_slug=None):
    """Newest unexpired artifact `name` from a run on `branch`: {id, run, sha, created} or None."""
    repo_slug = repo_slug or os.environ.get("GITHUB_REPOSITORY", "kapelner/EDI")
    data = json.loads(_gh("api", f"repos/{repo_slug}/actions/artifacts?name={name}&per_page=30"))
    for a in sorted(data.get("artifacts", []), key=lambda a: a.get("created_at", ""), reverse=True):
        run = a.get("workflow_run") or {}
        if a.get("expired") or (branch and run.get("head_branch") != branch):
            continue
        return {"id": a["id"], "run": run.get("id"), "sha": run.get("head_sha", ""), "created": a.get("created_at", "")}
    return None


def download_artifact(art, dest, repo_slug=None):
    """Unzip artifact `art` into `dest` (a new directory). Returns the extracted paths."""
    repo_slug = repo_slug or os.environ.get("GITHUB_REPOSITORY", "kapelner/EDI")
    blob = _gh("api", f"repos/{repo_slug}/actions/artifacts/{art['id']}/zip", binary=True)
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(blob)) as z:
        for m in z.namelist():
            if m.startswith("/") or ".." in Path(m).parts:
                raise RuntimeError(f"unsafe path in artifact: {m}")
        z.extractall(dest)
    return sorted(p for p in dest.rglob("*") if p.is_file())


def export_rds(rds, out_csv):
    r = subprocess.run(["Rscript", EXPORT_R, str(rds), str(out_csv)], capture_output=True, text=True, timeout=600)
    if r.returncode:
        raise RuntimeError("untested_code_export.R failed: " + (r.stderr.strip().splitlines() or ["?"])[-1][:300])


def load_coverage(ctx):
    """{"lines": {file: {line: [hits, fn]}}, "sha": measured commit, "sources": [...], "errors": [...]}."""
    work = Path(ctx.workdir) / "coverage"
    lines, sources, errors, sha = {}, [], [], ""
    r_csv = os.environ.get("UNTESTED_CODE_R_LINES")
    r_rds = os.environ.get("UNTESTED_CODE_R_RDS")
    try:
        if not r_csv and not r_rds:
            art = find_artifact(ARTIFACT_LINES)
            if art:
                files = download_artifact(art, work / "lines")
                r_csv = next((str(p) for p in files if p.suffix == ".csv"), None)
                sources.append(f"`{ARTIFACT_LINES}` artifact of run {art['run']} ({art['created'][:10]})")
            else:
                art = find_artifact(ARTIFACT_MERGED)
                if art:
                    files = download_artifact(art, work / "merged")
                    r_rds = next((str(p) for p in files if p.suffix == ".rds"), None)
                    sources.append(f"`{ARTIFACT_MERGED}` artifact of run {art['run']} ({art['created'][:10]}), "
                                   "converted on the runner")
        if r_rds and not r_csv:
            r_csv = str(work / "lines-from-rds.csv")
            work.mkdir(parents=True, exist_ok=True)
            export_rds(r_rds, r_csv)
            if not sources:
                sources.append(f"`{r_rds}` (local)")
        if r_csv:
            meta, rows = parse_lines_csv(Path(r_csv).read_text())
            sha = meta.get("commit", "")
            lines.update(expressions_to_lines(rows))
            if not sources:
                sources.append(f"`{r_csv}` (local)")
            sources[-1] += f", commit {sha[:10] or 'unknown'}, measured {meta.get('measured_at', '?')[:16]}, covr {meta.get('covr', '?')}"
        else:
            errors.append("no R coverage report found (neither a `coverage-lines` nor a `coverage-merged` artifact on main)")
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as e:
        errors.append(f"R coverage could not be read: {e}")
    py_xml = os.environ.get("UNTESTED_CODE_PY_XML")
    py_sha = ""
    try:
        if not py_xml and not os.environ.get("UNTESTED_CODE_R_LINES") and not r_rds:
            art = find_artifact(ARTIFACT_PY)
            if art:
                files = download_artifact(art, work / "python")
                py_xml = next((str(p) for p in files if p.suffix == ".xml"), None)
                py_sha = art["sha"]
                sources.append(f"`{ARTIFACT_PY}` artifact of run {art['run']} ({art['created'][:10]}), commit {py_sha[:10]}")
            else:
                errors.append("no `coverage-python` artifact on main yet (Python not ranked this run)")
        if py_xml:
            py = parse_cobertura(Path(py_xml).read_text())
            lines.update({f: v for f, v in py.items()})
            if not py_sha:
                sources.append(f"`{py_xml}` (local)")
    except (RuntimeError, OSError, ValueError) as e:
        errors.append(f"Python coverage could not be read: {e}")
    return {"lines": lines, "sha": sha, "py_sha": py_sha, "sources": sources, "errors": errors}


# ---------------------------------------------------------------- moving lines to HEAD

HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")


def parse_diff(diff_text):
    """`git diff -U0` -> {path: {"hunks": [(old_start, old_len, new_start, new_len)], "deleted": bool,
    "new_path": str}} keyed by the OLD path."""
    out, cur = {}, None
    old = None
    for line in diff_text.splitlines():
        if line.startswith("--- "):
            old = line[6:] if line.startswith("--- a/") else None
        elif line.startswith("+++ "):
            new = line[6:] if line.startswith("+++ b/") else None
            key = old or new
            cur = out.setdefault(key, {"hunks": [], "deleted": new is None, "new_path": new})
        elif cur is not None:
            m = HUNK.match(line)
            if m:
                cur["hunks"].append((int(m.group(1)), int(m.group(2) or 1), int(m.group(3)), int(m.group(4) or 1)))
    return out


def map_line(hunks, line):
    """Old line -> new line, or None when the line is inside a changed hunk."""
    offset = 0
    for os_, ol, ns, nl in hunks:
        if ol == 0:                    # pure insertion after old line os_
            if line <= os_:
                return line + offset
        else:
            if line < os_:
                return line + offset
            if line < os_ + ol:
                return None
        offset += nl - ol
    return line + offset


def changed_new_lines(hunks):
    """New-side line numbers a diff added or changed."""
    out = set()
    for _os, _ol, ns, nl in hunks:
        out.update(range(ns, ns + nl))
    return out


def move_to_head(lines, sha, repo, paths=SOURCE_DIRS):
    """Carry {file: {line: v}} measured at `sha` to HEAD. Returns (moved, dropped line count)."""
    if not sha:
        return lines, 0
    r = subprocess.run(["git", "diff", "-U0", "--no-renames", "--no-color", sha, "HEAD", "--", *paths],
                       cwd=repo, capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(f"cannot diff the measured commit {sha[:10]} against HEAD: {r.stderr.strip()[:200]}")
    diff = parse_diff(r.stdout)
    out, dropped = {}, 0
    for f, fl in lines.items():
        d = diff.get(f)
        if d is None:
            out[f] = fl
            continue
        if d["deleted"]:
            dropped += len(fl)
            continue
        nf = {}
        for ln, v in fl.items():
            n = map_line(d["hunks"], ln)
            if n is None:
                dropped += 1
            else:
                nf[n] = v
        out[f] = nf
    return out, dropped


# ---------------------------------------------------------------- reading sources

def strip_cpp(text):
    """C/C++ with comments and string contents blanked, newlines kept (so line numbers hold)."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append("".join(ch if ch == "\n" else " " for ch in text[i:j]))
            i = j
        elif c in "\"'":
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            out.append(c + " " * (min(j, n) - i - 1) + (c if j < n and text[j] == c else ""))
            i = j + 1 if j < n and text[j] == c else j
        else:
            out.append(c)
            i += 1
    return "".join(out)


CONTAINER = re.compile(r"\b(namespace|class|struct|union|enum)\b[^;{}()]*$|extern\s+\"?C?\"?\s*$")
FUNC_HEAD = re.compile(r"([A-Za-z_~][\w:~]*|operator\s*\S+)\s*\([^;{}]*\)\s*(?:const|noexcept|override|final|mutable|"
                       r"->\s*[\w:<>,\s*&]+|\s|:\s*[^;{}]*)*$", re.S)


def cpp_functions(text):
    """[(name, first line, last line)] for the function bodies of a C/C++ file (outermost function
    only; lambdas and blocks inside count as the function)."""
    s = strip_cpp(text)
    funcs, stack, last_stmt_end, line = [], [], 0, 1
    for i, c in enumerate(s):
        if c == "\n":
            line += 1
        elif c == "{":
            head = s[last_stmt_end:i]
            kind = "block"
            in_func = any(k == "func" for k, _, _ in stack)
            if not in_func:
                h = re.sub(r"\s+", " ", head).strip()
                if CONTAINER.search(h) and not h.endswith(")"):
                    kind = "container"
                else:
                    m = FUNC_HEAD.search(h)
                    if m and not re.match(r"^(if|for|while|switch|catch|return)\b", m.group(1)):
                        kind = "func"
                        name = m.group(1).split("::")[-1] if "operator" not in m.group(1) else m.group(1)
                        stack.append((kind, name, line))
                        last_stmt_end = i + 1
                        continue
            stack.append((kind, None, line))
            last_stmt_end = i + 1
        elif c == "}":
            if stack:
                kind, name, start = stack.pop()
                if kind == "func":
                    funcs.append((name, start, line))
            last_stmt_end = i + 1
        elif c == ";":
            last_stmt_end = i + 1
    return sorted(funcs, key=lambda x: x[1])


def enclosing(funcs, line):
    best = None
    for name, a, b in funcs:
        if a <= line <= b and (best is None or a >= best[1]):
            best = (name, a, b)
    return best


R_FUN_DEF = re.compile(r"^\s*(?:[\w.]+\s*(?:=|<-)\s*)?function\s*\(|^\s*([\w.]+)\s*(?:=|<-)\s*function\s*\(")


def r_function_span(src_lines, line, fn):
    """(first, last) lines of the R function holding `line`: from the nearest line above that
    defines `fn` (or any function), to the line where its braces close."""
    start = None
    pat = re.compile(r"^\s*`?" + re.escape(fn) + r"`?\s*(?:=|<-)\s*function\b") if fn else None
    for k in range(line, 0, -1):
        t = src_lines[k - 1]
        if (pat and pat.search(t)) or (not pat and R_FUN_DEF.search(t)):
            start = k
            break
    if start is None:
        return max(1, line - 30), min(len(src_lines), line + 30)
    depth, seen = 0, False
    for k in range(start, len(src_lines) + 1):
        code = strip_r_comment(src_lines[k - 1])
        depth += code.count("{") - code.count("}")
        seen = seen or "{" in code
        if seen and depth <= 0:
            return start, k
    return start, len(src_lines)


def strip_r_comment(line):
    q, i = None, 0
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\":
                i += 1
            elif c == q:
                q = None
        elif c in "\"'`":
            q = c
        elif c == "#":
            return line[:i]
        i += 1
    return line


NOCOV_LINE = re.compile(r"(#|//)\s*nocov\b(?!\s*(start|end))|LCOV_EXCL_LINE")
NOCOV_START = re.compile(r"(#|//)\s*nocov\s+start\b|LCOV_EXCL_START")
NOCOV_END = re.compile(r"(#|//)\s*nocov\s+end\b|LCOV_EXCL_STOP")
PLATFORM_MACRO = re.compile(r"\b(_WIN32|_WIN64|WIN32|__MINGW\w*|_MSC_VER|__APPLE__|__MACH__|__linux__|__FreeBSD__|"
                            r"__sun|__aarch64__|__arm__|__ARM_NEON\w*|__x86_64__|__i386__|__AVX\w*|__SSE\w*|__FMA__|"
                            r"__powerpc\w*|__s390\w*|__clang__|__INTEL_COMPILER|EDI_PORTABLE)\b")
PLATFORM_R = re.compile(r"\.Platform\$(OS\.type|file\.sep|dynlib\.ext)|Sys\.info\(\)|R\.version\$(os|platform|arch)|"
                        r"\.Machine\$sizeof|\bwindows\b|\bdarwin\b|\bsolaris\b", re.I)


def nocov_lines(src_lines):
    out, inside = set(), False
    for k, t in enumerate(src_lines, 1):
        if NOCOV_START.search(t):
            inside = True
        if inside or NOCOV_LINE.search(t):
            out.add(k)
        if NOCOV_END.search(t):
            inside = False
    return out


def cpp_platform_lines(src_lines):
    """Lines inside a preprocessor block whose condition names a platform or instruction set."""
    out, stack = set(), []
    for k, t in enumerate(src_lines, 1):
        s = t.strip()
        if re.match(r"#\s*if", s):
            stack.append(bool(PLATFORM_MACRO.search(s)))
        elif re.match(r"#\s*(elif|else)", s) and stack:
            stack[-1] = stack[-1] or bool(PLATFORM_MACRO.search(s))
        elif re.match(r"#\s*endif", s) and stack:
            stack.pop()
            continue
        if any(stack):
            out.add(k)
    return out


def controlling_line(src_lines, first):
    """The line that opens the block a region starts in (the nearest line above with less indentation),
    if it is an if/else/switch/case/catch line; else ''. A region that starts right after its own
    `if (...) {` line (same indentation as the region's first statement is impossible) is handled by
    the indentation rule too."""
    if not (0 < first <= len(src_lines)):
        return ""
    t0 = src_lines[first - 1].expandtabs(4)
    ind = len(t0) - len(t0.lstrip())
    for k in range(first - 1, max(0, first - 60), -1):
        t = src_lines[k - 1].expandtabs(4)
        if not t.strip():
            continue
        if len(t) - len(t.lstrip()) < ind:
            return t.strip() if re.search(r"\b(if|else|switch|case|catch|tryCatch)\b", t) else ""
    return ""


GUARD = re.compile(r"\bstop\s*\(|\bwarning\s*\(|\bstopifnot\b|\babort\b|Rcpp::stop|\bthrow\b|\bassert\w*\s*\(|"
                   r"return\s*\(?\s*(NA\w*|NULL|FALSE|false|R_NaN|NAN|nullptr|std::numeric_limits)|"
                   r"\bis\.na\b|!\s*is\.finite|is\.nan|\bstd::isnan|\bstd::isfinite|allFinite|hasNaN|tryCatch|"
                   r"\berror\s*=\s*function|\bconverged\b|non.?finite|singular")
TRIVIAL = re.compile(r"^[\s{}()\[\];,]*$|^\s*(\}?\s*else\s*\{?|\}\s*\)|break;|default:|return;)\s*$")
CONTROL = re.compile(r"\b(if|else|for|while|switch|case|return|throw|break|continue|goto)\b|\?")


def code_text(path, src_lines, nums):
    """The code of these lines with comments and whitespace removed (for ids)."""
    out = []
    for n in nums:
        t = src_lines[n - 1] if 0 < n <= len(src_lines) else ""
        t = strip_r_comment(t) if path.endswith(R_EXT) or path.endswith(PY_EXT) else re.sub(r"//.*", "", t)
        out.append(re.sub(r"\s+", "", t))
    return "\n".join(x for x in out if x)


def region_id(path, fn, src_lines, nums, salt=0):
    return "unt-" + ac.text_hash(path, fn or "", code_text(path, src_lines, nums), salt)[:12]


# ---------------------------------------------------------------- regions

def build_regions(lines, sources):
    """lines: {file: {line: [hits, fn]}} at HEAD; sources: {file: text}. -> [region dict]."""
    regions = []
    for f in sorted(lines):
        text = sources.get(f)
        if text is None:
            continue
        src = text.splitlines()
        funcs = cpp_functions(text) if f.endswith(CPP_EXT) else None
        fl = lines[f]

        def fn_of(ln, covr_fn):
            if funcs is not None:
                e = enclosing(funcs, ln)
                return e[0] if e else ""
            return covr_fn or ""

        cur = None
        for ln in sorted(fl):
            if ln > len(src):
                continue
            hits, cfn = fl[ln]
            fn = fn_of(ln, cfn)
            if hits > 0 or TRIVIAL.match(src[ln - 1]):
                if hits > 0 and cur:
                    regions.append(cur)
                    cur = None
                continue
            if cur and cur["fn"] == fn:
                cur["lines"].append(ln)
            else:
                if cur:
                    regions.append(cur)
                cur = {"file": f, "fn": fn, "lines": [ln]}
        if cur:
            regions.append(cur)
    seen = {}
    for r in regions:
        src = sources[r["file"]].splitlines()
        r["first"], r["last"] = r["lines"][0], r["lines"][-1]
        r["lang"] = lang_of(r["file"])
        rid = region_id(r["file"], r["fn"], src, r["lines"])
        n = seen.get(rid, 0)
        seen[rid] = n + 1
        r["id"] = rid if n == 0 else region_id(r["file"], r["fn"], src, r["lines"], salt=n)
    return regions


def file_measured(lines):
    """{file: (measured lines, hit lines)}."""
    return {f: (len(fl), sum(1 for v in fl.values() if v[0] > 0)) for f, fl in lines.items()}


# ---------------------------------------------------------------- exclusions

def codecov_ignores(text):
    out, inside = [], False
    for line in (text or "").splitlines():
        if re.match(r"^ignore:\s*$", line):
            inside = True
            continue
        if inside:
            m = re.match(r"^\s+-\s*[\"']?([^\"'#]+?)[\"']?\s*(#.*)?$", line)
            if m:
                out.append(m.group(1).strip())
            elif line.strip() and not line.lstrip().startswith("#"):
                inside = False
    return out


def glob_match(path, pattern):
    pattern = pattern.rstrip("/")
    if pattern.endswith("/**"):
        return path.startswith(pattern[:-3] + "/")
    return fnmatch.fnmatchcase(path, pattern)


def registry_excluded(text):
    out = set()
    for r in csv.DictReader(io.StringIO(text or "")):
        if (r.get("status") or "").strip() == "excluded" and r.get("file"):
            out.add(r["file"].strip())
    return out


# ---------------------------------------------------------------- the allowlist

ALLOWLIST_HEADER = ["match", "reason"]
LEAD_CITE = re.compile(r"^\s*v(\d+(?:\.\d+){0,2})-TODO-(\d+[a-z]?)\b")


def read_allowlist(text):
    """[(row number, {"match", "reason"})]."""
    if not text or not text.strip():
        return []
    return [(i, r) for i, r in enumerate(csv.DictReader(io.StringIO(text)), start=2)]


def release_file_of(version):
    parts = [int(x) for x in version.split(".")]
    parts += [0] * (3 - len(parts))
    return "release_v{}_{}_{}.md".format(*parts[:3])


def validate_allowlist(rows, todo_state):
    """todo_state(release_file, number) -> ("open"|"ticked"|"moved"|"missing", why).
    Returns (valid rows, problems: [str])."""
    valid, problems = [], []
    for i, r in rows:
        match = (r.get("match") or "").strip()
        reason = (r.get("reason") or "").strip()
        if not match:
            problems.append(f"`{ALLOWLIST}` row {i}: empty `match`.")
            continue
        m = LEAD_CITE.match(reason)
        if not m:
            problems.append(f"`{ALLOWLIST}` row {i} (`{match}`): the reason must start with an open release TODO "
                            "(`v1.0.6-TODO-6: ...`); the row excuses nothing until it does.")
            continue
        state, why = todo_state(release_file_of(m.group(1)), m.group(2))
        if state != "open":
            problems.append(f"`{ALLOWLIST}` row {i} (`{match}`): `v{m.group(1)}-TODO-{m.group(2)}` is {state}"
                            + (f" ({why})" if why else "") + "; the row excuses nothing.")
            continue
        valid.append({"match": match, "reason": reason, "row": i})
    return valid, problems


def allow_match(region, rows):
    for r in rows:
        m = r["match"]
        if m.startswith("unt-"):
            if region["id"] == m:
                return r
            continue
        path, _, fn = m.partition("::")
        if glob_match(region["file"], path) and (not fn or fnmatch.fnmatchcase(region["fn"] or "", fn)):
            return r
    return None


def todo_state_fn(repo):
    """A (release_file, number) -> (state, why) function from the TODO-status audit's parser; when it
    cannot be loaded every citation reads as missing (so nothing is excused by accident)."""
    try:
        from audits import allowlist_hygiene as ah
        st = ah.TodoState(repo)
        return st.state
    except Exception as e:  # noqa: BLE001  (fail closed)
        return lambda base, num: ("missing", f"TODO state unavailable: {e.__class__.__name__}")


def exclusion_reason(region, src_lines, nocov, platform, ignores, registry, allow):
    f = region["file"]
    if any(glob_match(f, g) for g in GENERATED):
        return "generated file"
    if f in registry:
        return "coverage registry marks the file excluded (measurement artifact)"
    if any(glob_match(f, g) for g in ignores):
        return "codecov.yml ignores the file"
    kept = [n for n in region["lines"] if n not in nocov]
    if not kept:
        return "nocov"
    region["lines"] = kept
    region["first"], region["last"] = kept[0], kept[-1]
    if f.endswith(CPP_EXT) and all(n in platform for n in kept):
        return "platform branch"
    if f.endswith(R_EXT):
        ctl = controlling_line(src_lines, region["first"])
        body = "\n".join(src_lines[n - 1] for n in kept)
        # Only a condition on the platform alone: `force_mirai || .Platform$OS.type != "unix"` is reachable
        # on Linux and stays ranked.
        if (PLATFORM_R.search(ctl) and "||" not in ctl) or (len(kept) <= 3 and PLATFORM_R.search(body)):
            return "platform branch"
    if f.endswith(CPP_EXT) and len(kept) == 1:
        t = src_lines[kept[0] - 1]
        if not CONTROL.search(t) and not GUARD.search(t):
            return "-O2 line noise (one isolated line with no control flow)"
    a = allow_match(region, allow)
    if a:
        return f"allowlisted ({a['reason'][:80]})"
    return None


# ---------------------------------------------------------------- ranking signals

def namespace_exports(text):
    out = set()
    for m in re.finditer(r"^export\(([^)]+)\)", text or "", re.M):
        out.update(x.strip().strip('"`') for x in m.group(1).split(","))
    return out


RD_METHOD = re.compile(r'id="method-([A-Za-z]\w*)-([A-Za-z_.][\w.]*)"')


def public_methods(repo):
    """Public R6 method names of documented classes (from the Rd method anchors) -> {name: {classes}}."""
    out = {}
    d = Path(repo) / MAN_DIR
    if d.is_dir():
        for p in d.glob("*.Rd"):
            try:
                text = p.read_text(errors="replace")
            except OSError:
                continue
            for cls, meth in RD_METHOD.findall(text):
                out.setdefault(meth, set()).add(cls)
    return out


ENTRY = re.compile(r"^(compute_\w+|initialize|add_\w*subject\w*|assign_\w+|add_all_subject\w*|"
                   r"add_one_subject\w*|overwrite_\w+|get_w|redraw_w\w*|draw_ws\w*)$")


def git_lines(repo, *args):
    r = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True)
    return r.stdout if not r.returncode else ""


def recent_changed_lines(repo, days=RECENT_DAYS, paths=SOURCE_DIRS):
    """{file: set(lines at HEAD)} changed in the last `days` days."""
    base = git_lines(repo, "rev-list", "-1", f"--before={days}.days", "HEAD").strip()
    if not base:
        return {}
    diff = parse_diff(git_lines(repo, "diff", "-U0", "--no-renames", "--no-color", base, "HEAD", "--", *paths))
    return {(d["new_path"] or f): changed_new_lines(d["hunks"]) for f, d in diff.items() if not d["deleted"]}


def todo_fixed_lines(repo, release_label, files, max_commits=150):
    """{file: set(lines at HEAD)} that commits citing a TODO of `release_label` (v1.0.6-TODO-n, or the
    older `v1.0.6 TODO-n`) changed, carried to HEAD. Only `files` are looked at."""
    if not release_label or not files:
        return {}
    ver = re.escape(release_label.lstrip("v"))
    shas = git_lines(repo, "log", "-E", f"--grep=v{ver}[- ]TODO-[0-9]+", "--format=%H",
                     f"-n{max_commits}", "HEAD", "--", *SOURCE_DIRS).split()
    shas += [x for x in release_commits(repo, release_label) if x not in shas]
    out = {}
    files = sorted(files)
    for sha in shas:
        touched = parse_diff(git_lines(repo, "show", "-U0", "--no-renames", "--no-color", "--format=", sha, "--", *files))
        if not touched:
            continue
        later = parse_diff(git_lines(repo, "diff", "-U0", "--no-renames", "--no-color", sha, "HEAD", "--",
                                     *[d["new_path"] for d in touched.values() if d["new_path"]]))
        for f, d in touched.items():
            if d["deleted"] or not d["new_path"]:
                continue
            path = d["new_path"]
            fwd = later.get(path)
            if fwd and fwd["deleted"]:
                continue
            for ln in changed_new_lines(d["hunks"]):
                n = map_line(fwd["hunks"], ln) if fwd else ln
                if n is not None:
                    out.setdefault(path, set()).add(n)
    return out


def release_commits(repo, release_label):
    """Commits the release file names (8-40 hex digits that resolve to a commit): the evidence its
    TODOs cite for a fix (most commits here do not cite a TODO in their message)."""
    v = release_label.lstrip("v").split(".")
    if len(v) != 3:
        return []
    p = Path(repo) / "R/package_metadata/future_release_plans" / f"release_v{v[0]}_{v[1]}_{v[2]}.md"
    try:
        cands = sorted(set(re.findall(r"\b[0-9a-f]{8,40}\b", p.read_text(errors="replace"))))
    except OSError:
        return []
    if not cands:
        return []
    r = subprocess.run(["git", "rev-parse", "--verify", "-q", *[c + "^{commit}" for c in cands]], cwd=repo,
                       capture_output=True, text=True)
    # rev-parse stops at the first bad name, so check one by one when any fails.
    if r.returncode == 0:
        return r.stdout.split()
    out = []
    for c in cands:
        q = subprocess.run(["git", "rev-parse", "--verify", "-q", c + "^{commit}"], cwd=repo, capture_output=True, text=True)
        if q.returncode == 0:
            out.append(q.stdout.strip())
    return out


def current_release(repo):
    try:
        from audits import todo_status as ts
        st = ts.load_todo_state(repo)
        rels = st.get("releases") if isinstance(st, dict) else None
        if rels:
            _opus, cur, _nxt = ts.model_split(rels)
            return cur["label"] if cur else ""
    except Exception:  # noqa: BLE001
        pass
    # Fallback: the lowest release_v*.md above DESCRIPTION's version.
    try:
        desc = Path(repo, "R/EDI/DESCRIPTION").read_text()
        v = tuple(int(x) for x in re.search(r"^Version:\s*(\d+)\.(\d+)\.(\d+)", desc, re.M).groups())
    except (OSError, AttributeError):
        return ""
    vers = []
    for p in Path(repo, "R/package_metadata/future_release_plans").glob("release_v*_*_*.md"):
        m = re.search(r"release_v(\d+)_(\d+)_(\d+)\.md$", p.name)
        if m:
            t = tuple(int(x) for x in m.groups())
            if t > v:
                vers.append(t)
    return "v" + ".".join(map(str, min(vers))) if vers else ""


def rcpp_exports_by_file(sources):
    try:
        from audits import _edi_index as ei
    except Exception:  # noqa: BLE001
        return {}
    return {f: set(ei.rcpp_exports(t)) for f, t in sources.items() if f.endswith(CPP_EXT)}


def score_region(r, src_lines, exports, rd_methods, kernel_exports, recent, todo_lines):
    """Adds r["signals"], r["score"]; returns the score."""
    sig = []
    fn = r["fn"] or ""
    base = fn.split("$")[-1]
    s = 0.0
    if r["lang"] == "R" and (base in exports or base in rd_methods):
        s += 8
        sig.append("public API" + (f" ({', '.join(sorted(rd_methods[base])[:3])}{'...' if len(rd_methods[base]) > 3 else ''}$)"
                                   if base in rd_methods else " (exported)"))
        if ENTRY.match(base):
            s += 2
            sig.append("compute_* / design entry point")
    elif r["lang"] == "Python" and not base.startswith("_"):
        s += 8
        sig.append("public Python API")
    elif r["lang"] == "C++" and base in kernel_exports.get(r["file"], set()):
        s += 3
        sig.append("Rcpp-exported kernel")
    body = "\n".join(src_lines[n - 1] for n in r["lines"])
    ctl = controlling_line(src_lines, r["first"])
    if GUARD.search(body) or GUARD.search(ctl):
        s += 4
        sig.append("error/guard branch")
    if set(r["lines"]) & recent.get(r["file"], set()):
        s += 2
        sig.append(f"changed in the last {RECENT_DAYS} days")
    if set(r["lines"]) & todo_lines.get(r["file"], set()):
        s += 1
        sig.append("on a line a current-release TODO fix changed")
    s += min(len(r["lines"]), 40) / 100.0      # size only breaks ties
    r["signals"], r["score"] = sig, round(s, 2)
    return r["score"]


# ---------------------------------------------------------------- state on audit-notes

def load_json(path, default):
    try:
        v = json.loads(Path(path).read_text())
        return v if isinstance(v, type(default)) else default
    except (OSError, ValueError):
        return default


def regions_state(ctx):
    return load_json(ctx.notes.dir / "regions.json", {})


def save_regions_state(ctx, st):
    (ctx.notes.dir / "regions.json").write_text(json.dumps(st, indent=1, sort_keys=True) + "\n")


def due(rec, now, cooldown_weeks=COOLDOWN_WEEKS, max_attempts=MAX_ATTEMPTS):
    """Whether a region with state `rec` may be attempted this run."""
    if not rec:
        return True
    status = rec.get("status")
    if status in ("proposed", "unreachable", "intended", "bug", "gave_up", "rejected"):
        return False
    if status == "failed":
        if rec.get("attempts", 0) >= max_attempts:
            return False
        t = ac.parse_time(rec.get("last_attempt"))
        return t is None or (now - t).days >= 7 * cooldown_weeks
    return True


def rejected_regions(ctx):
    """Region ids whose proposed test the owner rejected (PR closed, or the file removed on the branch)."""
    return {h.get("unit") for h in ctx.notes.findings() if h.get("status") == "rejected"}


# ---------------------------------------------------------------- the pipeline (prepare)

def code_changed_since(ctx, sha):
    if not sha:
        return True
    head = git_lines(ctx.repo, "rev-parse", "HEAD").strip()
    if head and git_lines(ctx.repo, "rev-parse", sha).strip() == head:
        return False
    for d in (Path(ctx.repo) / "scripts", HERE.parents[2] / "scripts"):
        if (d / "significant_changes.py").exists() and str(d) not in sys.path:
            sys.path.insert(0, str(d))
    try:
        import significant_changes as sc
        return bool(sc.significant_changes(str(ctx.repo), sha, "HEAD", [f":(glob){d}/**" for d in CHANGE_PATHS]))
    except Exception:  # noqa: BLE001  (unknown commit, no git: fail open)
        return True


def read_sources(repo, files):
    """File texts from the work tree; from HEAD when UNTESTED_CODE_FROM_HEAD=1 (local runs in a checkout
    with uncommitted edits: the coverage lines are carried to HEAD, so HEAD's text is the one they fit)."""
    out = {}
    if os.environ.get("UNTESTED_CODE_FROM_HEAD") == "1":
        for f in files:
            r = subprocess.run(["git", "show", f"HEAD:{f}"], cwd=repo, capture_output=True, text=True, errors="replace")
            if r.returncode == 0:
                out[f] = r.stdout
        return out
    for f in files:
        try:
            out[f] = (Path(repo) / f).read_text(encoding="utf-8", errors="replace")
        except OSError:
            pass
    return out


def analyse(ctx, coverage=None):
    """Everything prepare and finish need; cached on ctx."""
    if getattr(ctx, "_unt", None) is not None:
        return ctx._unt
    repo = ctx.repo
    cov = coverage if coverage is not None else load_coverage(ctx)
    res = {"coverage": cov, "errors": list(cov["errors"]), "regions": [], "excluded": {}, "allow_problems": [],
           "dropped_lines": 0, "files": {}}
    ctx._unt = res
    if not cov["lines"]:
        return res
    r_lines = {f: v for f, v in cov["lines"].items() if not f.startswith("python/")}
    py_lines = {f: v for f, v in cov["lines"].items() if f.startswith("python/")}
    try:
        r_lines, dropped = move_to_head(r_lines, cov["sha"], repo)
        if cov.get("py_sha"):
            py_lines, d2 = move_to_head(py_lines, cov["py_sha"], repo, ("python/src",))
            dropped += d2
    except RuntimeError as e:
        res["errors"].append(str(e))
        return res
    res["dropped_lines"] = dropped
    lines = {**r_lines, **py_lines}
    lines = {f: v for f, v in lines.items() if f.startswith(SOURCE_DIRS)}
    sources = read_sources(repo, lines)
    res["files"] = file_measured(lines)
    regions = build_regions(lines, sources)

    ignores = codecov_ignores(ctx.read(CODECOV))
    registry = registry_excluded(ctx.read(REGISTRY))
    allow_rows = read_allowlist(ctx.read(ALLOWLIST))
    allow, res["allow_problems"] = validate_allowlist(allow_rows, todo_state_fn(repo)) if allow_rows else ([], [])
    exports = namespace_exports(ctx.read(NAMESPACE))
    rd_methods = public_methods(repo)
    kernel_exports = rcpp_exports_by_file(sources)
    recent = recent_changed_lines(repo)
    region_files = {r["file"] for r in regions}
    release = current_release(repo)
    res["release"] = release
    todo_lines = todo_fixed_lines(repo, release, region_files)

    kept = []
    per_file = {}
    for r in regions:
        src = sources[r["file"]].splitlines()
        if r["file"] not in per_file:
            per_file[r["file"]] = (nocov_lines(src), cpp_platform_lines(src) if r["file"].endswith(CPP_EXT) else set())
        nocov, platform = per_file[r["file"]]
        why = exclusion_reason(r, src, nocov, platform, ignores, registry, allow)
        if why:
            key = why.split(" (")[0]
            res["excluded"][key] = res["excluded"].get(key, 0) + 1
            continue
        score_region(r, src, exports, rd_methods, kernel_exports, recent, todo_lines)
        kept.append(r)
    kept.sort(key=lambda r: (-r["score"], r["file"], r["first"]))
    res["regions"] = kept
    res["sources"] = sources
    return res


def excerpt(r, src_lines, max_lines=MAX_EXCERPT_LINES):
    """The enclosing function with line numbers, the region's lines marked `>>`."""
    if r["lang"] == "C++":
        e = enclosing(cpp_functions("\n".join(src_lines)), r["first"])
        a, b = (e[1], e[2]) if e else (r["first"] - 30, r["last"] + 30)
    else:
        a, b = r_function_span(src_lines, r["first"], (r["fn"] or "").split("$")[-1])
    a, b = max(1, a), min(len(src_lines), b)
    if b - a + 1 > max_lines:
        a = max(1, min(a, r["first"] - max_lines // 3))
        b = min(len(src_lines), a + max_lines - 1)
    mark = set(r["lines"])
    return "\n".join(f"{'>>' if n in mark else '  '} {n:5d}  {src_lines[n - 1]}" for n in range(a, b + 1))


def region_context(ctx, r, sources, rec):
    src = sources[r["file"]].splitlines()
    ctxd = {"region": r["id"], "file": r["file"], "language": r["lang"], "function": r["fn"],
            "lines": f"{r['first']}-{r['last']}", "uncovered_lines": r["lines"], "score": r["score"],
            "why_ranked": r["signals"], "excerpt": excerpt(r, src)}
    try:
        from audits import _edi_index as ei
        if not hasattr(ctx, "_edi_idx"):
            ctx._edi_idx = ei.Index(ctx.repo)
        idx = ctx._edi_idx
        names = [x for x in [(r["fn"] or "").split("$")[-1]] if x]
        if r["lang"] == "R":
            classes = idx.classes.get(r["file"], [])
            ctxd["classes_in_file"] = classes[:20]
            ctxd["test_files"] = idx.tests_naming(names + classes, max_files=15)
        elif r["lang"] == "C++":
            ex = sorted(idx.exports.get(r["file"], []))
            ctxd["rcpp_exports_in_file"] = ex[:20]
            callers = idx.callers(ex) if ex else []
            ctxd["r_callers"] = callers[:10]
            ctxd["test_files"] = idx.tests_naming(names + ex + idx.classes_in([c["file"] for c in callers]),
                                                  max_files=15)
        ctxd["recent_commits"] = ei.git_log(ctx.repo, r["file"], n=3)
    except Exception as e:  # noqa: BLE001  (context is a help, not a requirement)
        ctxd["context_note"] = f"index unavailable: {e.__class__.__name__}"
    if rec and rec.get("status") == "failed":
        ctxd["previous_attempt"] = {"attempts": rec.get("attempts"), "why_not_kept": rec.get("last_reason"),
                                    "at": rec.get("last_attempt")}
    return ctxd


SAVED = "untested_code_analysis.json"
SAVED_KEYS = ("errors", "regions", "excluded", "allow_problems", "dropped_lines", "release", "skipped", "waiting",
              "python_regions")


def save_analysis(ctx, res):
    """The prepare stage's analysis, for finish (which reads it from the work artifact instead of
    downloading the coverage again: its token has no actions: read)."""
    d = {k: res.get(k) for k in SAVED_KEYS if k in res}
    d["coverage"] = {k: res["coverage"].get(k) for k in ("sha", "py_sha", "sources", "errors")}
    Path(ctx.workdir).mkdir(parents=True, exist_ok=True)
    (Path(ctx.workdir) / SAVED).write_text(json.dumps(d, indent=1))


def load_analysis(ctx):
    d = load_json(Path(ctx.workdir) / SAVED, {})
    if not d:
        return None
    d.setdefault("coverage", {}).setdefault("sources", [])
    for k in ("errors", "regions", "allow_problems"):
        d.setdefault(k, [])
    d.setdefault("excluded", {})
    d.setdefault("dropped_lines", 0)
    return d


def mechanical(ctx):
    res = analyse(ctx)
    out = [{"unit": "coverage-input", "kind": "input", "text": e} for e in res["errors"]]
    out += [{"unit": ALLOWLIST, "kind": "allowlist", "text": p} for p in res["allow_problems"]]
    return out


def units(ctx):
    res = analyse(ctx)
    last = ctx.manifest.get("code_sha")
    changed = code_changed_since(ctx, last)
    res["code_changed"] = changed
    if ctx.scope != "all" and last and not changed:
        res["skipped"] = f"no code or test change since {str(last)[:8]} (scripts/significant_changes.py)"
        save_analysis(ctx, res)
        return {}
    if not res["regions"]:
        save_analysis(ctx, res)
        return {}
    out = choose(ctx, res)
    save_analysis(ctx, res)
    return out


def choose(ctx, res):
    """The TOP_N regions due this run, as framework units. Python regions are listed, not sent to an
    agent: the finish stage does not build the Python package (python/src is at 100% line coverage as
    of 2026-11-18, so this costs nothing yet)."""
    state = regions_state(ctx)
    rejected = rejected_regions(ctx)
    dismissed = ac.dismissed_decisions(ctx.repo)
    out, waiting, py, eligible = {}, 0, [], []
    for r in res["regions"]:
        rec = state.get(r["id"])
        if r["id"] in rejected or decision_id_of(r["id"]) in dismissed or not due(rec, ctx.now):
            continue
        if r["lang"] == "Python":
            py.append(r)
            continue
        waiting += 1
        eligible.append(r)
    for r in diversify(eligible, TOP_N):
        out[r["id"]] = {"hash": r["id"], "priority": -int(r["score"] * 100),
                        "context": region_context(ctx, r, res["sources"], state.get(r["id"]))}
    res["waiting"] = waiting
    res["python_regions"] = py      # every one: each is a tracked mechanical finding
    return out


def diversify(regions, n, per_fn=MAX_PER_FUNCTION, per_file=MAX_PER_FILE):
    """The first n regions in rank order, at most per_fn per function name and per_file per file."""
    out, by_fn, by_file = [], {}, {}
    for r in regions:
        fn = (r.get("fn") or "").split("$")[-1] or f"<{r['file']}>"
        if by_fn.get(fn, 0) >= per_fn or by_file.get(r["file"], 0) >= per_file:
            continue
        out.append(r)
        by_fn[fn] = by_fn.get(fn, 0) + 1
        by_file[r["file"]] = by_file.get(r["file"], 0) + 1
        if len(out) >= n:
            break
    return out


PY_UNIT = "python-regions"     # the unit of every Python-region mechanical finding (keyed by region id)


def decision_id_of(region):
    return ac.decision_id(SPEC["name"], region, "region", "")


# ---------------------------------------------------------------- verification (finish)

PLAIN_R = r"""
# One test, plain (no tracing), in a fresh process: the run that decides pass/fail, and the run whose
# .gcda files give the C++ lines it executed.
args = commandArgs(trailingOnly = TRUE)
pkg = args[[1]]; test_path = args[[2]]; out_path = args[[3]]
suppressPackageStartupMessages(library(testthat))
clean = function(x) gsub("[\r\n\t]+", " ", paste(x, collapse = " "))
loaded = tryCatch({ suppressMessages(pkgload::load_all(pkg, compile = FALSE, quiet = TRUE)); TRUE },
	error = function(e) { writeLines(paste0("error\tload_all(compile = FALSE) failed: ", clean(conditionMessage(e))), out_path); FALSE })
if (!loaded) quit(status = 3)
rows = character(0)
res = tryCatch(testthat::test_file(test_path, reporter = "silent", stop_on_failure = FALSE),
	error = function(e) { rows <<- c(rows, paste0("error\t", clean(conditionMessage(e)))); NULL })
if (!is.null(res)) for (t in res) for (e in t$results) {
	kind = if (inherits(e, "expectation_failure")) "fail" else if (inherits(e, "expectation_error")) "error"
		else if (inherits(e, "expectation_skip")) "skip" else if (inherits(e, "expectation_warning")) "warning" else "pass"
	rows = c(rows, paste0(kind, "\t", clean(conditionMessage(e))))
}
writeLines(rows, out_path)
"""

TRACED_R = r"""
# All R-targeting tests in ONE process: tracing EDI's namespace with covr takes minutes (4.5 min
# measured locally, 2026-11-18), the traced tests themselves seconds. The namespace is traced once
# and the cumulative counts are snapshotted after each test; a test's lines are the difference.
# Tracing the loaded namespace in place also attributes the methods that define_inference_class()
# composes back to their component files, which a package_coverage() run cannot (contract section 6).
# Uses covr internals (trace_environment, .counters, as_coverage, and sync_counts in covr >= 4), so
# it falls back to one covr::environment_coverage() per test when they are missing.
args = commandArgs(trailingOnly = TRUE)
pkg = args[[1]]; list_path = args[[2]]; out_dir = args[[3]]
suppressPackageStartupMessages(library(testthat))
suppressMessages(pkgload::load_all(pkg, compile = FALSE, quiet = TRUE))
tests = readLines(list_path)
ns = asNamespace("EDI"); cv = asNamespace("covr")
fast = all(vapply(c("trace_environment", ".counters", "as_coverage"), exists, logical(1), envir = cv, inherits = FALSE))
keyed = function(df) {
	df$filename = gsub("\\\\", "/", df$filename)
	df$key = paste(df$filename, df$first_line, df$first_byte, df$last_line, df$last_byte, sep = ":")
	df
}
write_hits = function(df, out) {
	df = df[df$value > 0, , drop = FALSE]
	f = sub("^.*/R/EDI/", "R/EDI/", df$filename)
	f = ifelse(startsWith(f, "R/EDI/"), f, file.path("R/EDI/R", basename(f)))
	utils::write.csv(data.frame(file = f, first_line = df$first_line, last_line = df$last_line,
		fn = df$functions, value = df$value), out, row.names = FALSE)
}
run_test = function(path) tryCatch(testthat::test_file(path, reporter = "silent", stop_on_failure = FALSE),
	error = function(e) NULL)
if (fast) {
	cv$trace_environment(ns)
	snap = function() {
		if (exists("sync_counts", envir = cv, inherits = FALSE)) cv$sync_counts()
		keyed(as.data.frame(cv$as_coverage(cv$.counters)))
	}
	before = snap()
	for (t in tests) {
		run_test(t)
		after = snap()
		prev = before$value[match(after$key, before$key)]
		after$value = after$value - ifelse(is.na(prev), 0, prev)
		write_hits(after, file.path(out_dir, paste0(basename(dirname(t)), "-rcov.csv")))
		before = snap()
	}
} else {
	for (t in tests) {
		wrapper = tempfile(fileext = ".R")
		writeLines(sprintf("testthat::test_file(%s, reporter = 'silent', stop_on_failure = FALSE)", deparse(t)), wrapper)
		cov = tryCatch(covr::environment_coverage(ns, test_files = wrapper), error = function(e) NULL)
		if (!is.null(cov)) write_hits(keyed(as.data.frame(cov)), file.path(out_dir, paste0(basename(dirname(t)), "-rcov.csv")))
	}
}
"""


def gcov_hits(repo, src_dir="R/EDI/src", gcov="gcov"):
    """{repo path: {line: count}} from the .gcda files under src_dir (gcov --json-format --stdout,
    one JSON document per translation unit, headers included)."""
    d = Path(repo) / src_dir
    out = {}
    for gcda in sorted(d.glob("*.gcda")):
        try:
            r = subprocess.run([gcov, "--json-format", "--stdout", "-o", str(d), str(gcda)], cwd=str(d),
                               capture_output=True, text=True, timeout=120)
        except (OSError, subprocess.TimeoutExpired):
            continue
        merge_gcov_json(r.stdout, d, repo, out)
    return out


def merge_gcov_json(text, src_dir, repo, out):
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            doc = json.loads(line)
        except ValueError:
            continue
        for fobj in doc.get("files", []):
            name = fobj.get("file", "")
            p = Path(name) if os.path.isabs(name) else Path(src_dir) / name
            try:
                rel = p.resolve().relative_to(Path(repo).resolve()).as_posix()
            except ValueError:
                continue      # a system or package header
            fl = out.setdefault(rel, {})
            for ln in fobj.get("lines", []):
                n = ln.get("line_number")
                fl[n] = fl.get(n, 0) + (ln.get("count") or 0)
    return out


def clear_gcda(repo, src_dir="R/EDI/src"):
    for p in (Path(repo) / src_dir).glob("*.gcda"):
        try:
            p.unlink()
        except OSError:
            pass


VALUE_EXPECT = re.compile(r"\bexpect_(equal|identical|equivalent|lt|lte|gt|gte|match|named|length|setequal|"
                          r"mapequal|s3_class|s4_class|r6_class|type|true|false|null|vector|contains|in)\s*\(")
CONDITION_EXPECT = re.compile(r"\bexpect_(error|warning|message|condition)\s*\(")
WEAK_ONLY = re.compile(r"\bexpect_true\s*\(\s*TRUE\s*\)|\bexpect_false\s*\(\s*FALSE\s*\)")


def call_args(code, start):
    """Top-level argument texts of the call whose "(" is at code[start - 1]."""
    args, depth, cur, q, i = [], 0, [], None, start
    while i < len(code):
        c = code[i]
        if q:
            cur.append(c)
            if c == "\\":
                cur.append(code[i + 1] if i + 1 < len(code) else "")
                i += 1
            elif c == q:
                q = None
        elif c in "\"'`":
            q = c
            cur.append(c)
        elif c in "([{":
            depth += 1
            cur.append(c)
        elif c in ")]}":
            if depth == 0:
                args.append("".join(cur).strip())
                return args
            depth -= 1
            cur.append(c)
        elif c == "," and depth == 0:
            args.append("".join(cur).strip())
            cur = []
        else:
            cur.append(c)
        i += 1
    return args


def specific_condition(code):
    """True if some expect_error/warning/message/condition names the condition: a regexp (second
    positional argument or `regexp =`) or a `class =`."""
    for m in CONDITION_EXPECT.finditer(code):
        args = call_args(code, m.end())
        if any(re.match(r"^(regexp|class)\s*=", a) for a in args):
            return True
        positional = [a for a in args[1:] if not re.match(r"^[\w.]+\s*=", a)]
        if positional:
            return True
    return False


def asserts_behaviour(code):
    """(ok, why): the test checks a value or a specific condition, not only that the code ran."""
    stripped = WEAK_ONLY.sub("", code or "")
    if VALUE_EXPECT.search(stripped) or specific_condition(stripped):
        return True, ""
    if re.search(r"\bexpect_(no_error|silent|no_warning|no_condition)\s*\(", stripped):
        return False, "it only checks that the code runs (expect_no_error / expect_silent), not what it returns"
    return False, "it has no expectation on a value or a specific error"


def covered_share(region, r_hits, c_hits):
    """(share, n) of the region's lines the test executed. r_hits/c_hits: {file: {line: count}}."""
    hits = (r_hits if region["lang"] == "R" else c_hits).get(region["file"], {})
    lines = region["lines"]
    n = sum(1 for ln in lines if hits.get(ln, 0) > 0)
    return (n / len(lines) if lines else 0.0), n


def r_hits_from_csv(path):
    if not Path(path).exists():
        return None
    _meta, rows = parse_lines_csv(Path(path).read_text())
    return {f: {ln: v[0] for ln, v in fl.items()} for f, fl in expressions_to_lines(rows).items()}


def verify_available(repo, timeout=300):
    """(ok, reason): R, testthat, covr and pkgload are there, and EDI loads without compiling."""
    code = ('suppressPackageStartupMessages({library(testthat); library(covr); library(pkgload)}); '
            f'suppressMessages(pkgload::load_all("{Path(repo) / "R/EDI"}", compile = FALSE, quiet = TRUE)); cat("ok")')
    try:
        r = subprocess.run(["Rscript", "-e", code], capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as e:
        return False, f"Rscript could not run ({e.__class__.__name__})"
    if r.returncode or "ok" not in r.stdout:
        return False, "EDI could not be loaded with load_all(compile = FALSE): " + \
            ((r.stderr.strip().splitlines() or ["no message"])[-1][:200])
    return True, ""


def run_tests(ctx, tests, timeout=PER_TEST_TIMEOUT, traced_timeout=None):
    """tests: [{"key", "name", "body", "region"}]. Each runs plain in its own Rscript under
    load_all(compile = FALSE) (pass/fail, and gcov for C++ regions); the R-region tests that ran
    then run together in one traced process for their R lines.
    -> {key: {"counts", "messages", "timed_out", "seconds", "r_hits", "c_hits", "timeout"}}."""
    from audits import _testthat_verify as tv
    vdir = Path(ctx.workdir) / "verify"
    vdir.mkdir(parents=True, exist_ok=True)
    (vdir / "plain.R").write_text(PLAIN_R)
    (vdir / "traced.R").write_text(TRACED_R)
    pkg = str(Path(ctx.repo) / "R/EDI")
    runs, traced, start = {}, [], time.time()
    for t in tests:
        if time.time() - start > TOTAL_TEST_BUDGET:
            break     # the rest are reported NOT VERIFIED and tried again next run
        d = vdir / t["key"]
        d.mkdir(parents=True, exist_ok=True)
        tp = d / "test.R"
        tp.write_text("library(testthat)\nlibrary(EDI)\n\n" + tv.test_text(t["name"], t["body"]))
        clear_gcda(ctx.repo)
        t0, timed_out = time.time(), False
        try:
            subprocess.run(["Rscript", str(vdir / "plain.R"), pkg, str(tp), str(d / "results.tsv")],
                           capture_output=True, text=True, timeout=timeout, env={**os.environ, "NOT_CRAN": "true"})
        except subprocess.TimeoutExpired:
            timed_out = True
        res = d / "results.tsv"
        counts, msgs = tv.parse_rows(res.read_text() if res.exists() else "")
        run = {"counts": counts, "messages": msgs, "timed_out": timed_out, "seconds": round(time.time() - t0, 1),
               "r_hits": {}, "c_hits": {}, "timeout": f"{timeout} s"}
        if t["region"]["lang"] == "C++":
            run["c_hits"] = gcov_hits(ctx.repo)
        elif t["region"]["lang"] == "R" and t.get("trace", True) and not timed_out and sum(counts.values()):
            traced.append(str(tp))
        runs[t["key"]] = run
    if traced:
        (vdir / "traced.txt").write_text("\n".join(traced) + "\n")
        try:
            subprocess.run(["Rscript", str(vdir / "traced.R"), pkg, str(vdir / "traced.txt"), str(vdir)],
                           capture_output=True, text=True, env={**os.environ, "NOT_CRAN": "true"},
                           timeout=traced_timeout or (20 * 60 + len(traced) * timeout))
        except subprocess.TimeoutExpired:
            pass
        for t in tests:
            if t["key"] not in runs:
                continue
            hits = r_hits_from_csv(vdir / f"{t['key']}-rcov.csv")
            if hits is not None:
                runs[t["key"]]["r_hits"] = hits
            elif str(vdir / t["key"] / "test.R") in traced:
                runs[t["key"]]["r_not_measured"] = True
    return runs


def judge_test(run, region, code, min_share=MIN_COVERED_SHARE):
    """(kept, reason) for a `test` outcome."""
    c, msgs = run["counts"], run["messages"]
    if run["timed_out"]:
        return False, f"the test hit the {run.get('timeout', 'time')} limit"
    if sum(c.values()) == 0:
        return False, "the test ran no expectations (it may not parse, EDI may not load, or R crashed)"
    if c["error"]:
        return False, "the test errored: " + next((m for k, m in msgs if k == "error"), "")[:300]
    if c["fail"]:
        return False, ("an expectation failed (a wrong test, or a bug to report as `bug`): "
                       + next((m for k, m in msgs if k == "fail"), "")[:300])
    if c["skip"]:
        return False, "the test skipped itself"
    ok, why = asserts_behaviour(code)
    if not ok:
        return False, f"the test passed, but {why}"
    if run.get("r_not_measured"):
        return False, "the test passed, but its R coverage could not be measured (the traced run failed)"
    share, n = covered_share(region, run["r_hits"], run["c_hits"])
    if share < min_share:
        return False, (f"the test passed but executed {n} of the region's {len(region['lines'])} lines "
                       f"(needs {int(min_share * 100)}%)")
    return True, f"passed; executed {n} of {len(region['lines'])} target lines ({run['seconds']} s)"


# ---------------------------------------------------------------- apply (finish)

def _norm(s):
    return re.sub(r"\s+", " ", str(s or "")).strip()


def finding_text(region_id, outcome):
    """Stable text, so the history id of a region's finding does not depend on agent prose."""
    return f"{outcome} for {region_id}"


def apply(ctx, results, mech, verifier=None, availability=None):
    """verifier(ctx, tests) (see run_tests) and availability() are injectable for the unit tests."""
    from audits import _testthat_verify as tv
    availability = availability or (lambda: verify_available(ctx.repo))
    verifier = verifier or run_tests
    res = load_analysis(ctx) or analyse(ctx)
    regions = {r["id"]: r for r in res["regions"]}
    plan = load_json(Path(ctx.workdir) / "plan.json", {})
    plan_units = set((plan.get("units") or {}).keys())
    state = regions_state(ctx)
    stamp = ac.now_utc().isoformat(timespec="seconds")
    unreach_path = ctx.notes.dir / "unreachable.json"
    unreachable = load_json(unreach_path, {})
    applied, human, info, proposed = [], [], [], []
    counts = {"kept": 0, "not kept": 0, "unreachable": 0, "intended": 0, "bug": 0, "bug not confirmed": 0}

    items = []
    for r in results:
        for f in r.get("findings") or []:
            if isinstance(f, dict) and f.get("unit") in regions and f.get("outcome") in OUTCOMES:
                items.append(f)
    need_r = any(f["outcome"] in ("test", "bug") for f in items)
    ok, why = availability() if need_r else (True, "")
    taken = set()

    def fail(rid, reason, f):
        rec = state.get(rid, {})
        attempts = rec.get("attempts", 0) + 1
        status = "gave_up" if attempts >= MAX_ATTEMPTS else "failed"
        state[rid] = {**rec, "status": status, "attempts": attempts, "last_attempt": stamp, "last_reason": reason[:400],
                      "file": regions[rid]["file"], "fn": regions[rid]["fn"]}
        loc = f"`{regions[rid]['file']}:{regions[rid]['first']}-{regions[rid]['last']}` ({regions[rid]['fn'] or 'top level'})"
        if status == "gave_up":
            human.append(ac.decision(f"No test after {attempts} attempts for {loc} [{rid}]: {reason[:300]}. Write one by "
                                     f"hand, or allowlist the region (`{ALLOWLIST}`, citing an open release TODO).",
                                     unit=rid, key="gave-up"))
        else:
            info.append(f"Not kept, retried in {COOLDOWN_WEEKS} weeks: {loc} [{rid}]: {reason[:300]}")
        counts["not kept"] += 1

    # Pass 1: verdicts that need no run; collect the tests to run (one verification pass for all).
    to_run = []
    for i, f in enumerate(items, 1):
        rid, outcome = f["unit"], f["outcome"]
        reg = regions[rid]
        loc = f"`{reg['file']}:{reg['first']}-{reg['last']}` ({reg['fn'] or 'top level'})"
        text = _norm(f.get("text"))
        if outcome == "unreachable":
            unreachable[rid] = {"file": reg["file"], "fn": reg["fn"], "first_line": reg["first"], "last_line": reg["last"],
                                "text": text[:600], "evidence": _norm(f.get("evidence"))[:800], "found_at": stamp}
            state[rid] = {**state.get(rid, {}), "status": "unreachable", "last_attempt": stamp, "file": reg["file"], "fn": reg["fn"]}
            info.append(f"Dead-code candidate (no public path reaches it; passed to the dead-code audit): {loc} [{rid}]: {text[:300]}")
            counts["unreachable"] += 1
            continue
        if outcome == "intended":
            state[rid] = {**state.get(rid, {}), "status": "intended", "last_attempt": stamp, "file": reg["file"], "fn": reg["fn"]}
            human.append(ac.decision(f"Intentionally untested? {loc} [{rid}]: {text[:400]} If so, add `{rid}` to "
                                     f"`{ALLOWLIST}` with a reason that starts with an open release TODO.",
                                     unit=rid, key="intended"))
            counts["intended"] += 1
            continue
        body = f.get("test_code") or ""
        if not body.strip():
            fail(rid, "no test code", f)
            continue
        if not ok:
            human.append(ac.decision(f"NOT VERIFIED ({why}): {outcome} for {loc} [{rid}]", unit=rid, key="not-verified"))
            continue
        name = f.get("test_name") or text or rid
        to_run.append({"key": f"{i:03d}", "name": name, "body": body, "region": reg, "finding": f, "loc": loc,
                       "text": text, "trace": outcome == "test"})

    runs = verifier(ctx, to_run) if to_run else {}

    # Pass 2: judge each run.
    for t in to_run:
        f, reg, loc, text, name, body = t["finding"], t["region"], t["loc"], t["text"], t["name"], t["body"]
        rid, outcome = f["unit"], f["outcome"]
        run = runs.get(t["key"])
        if run is None:
            info.append(f"NOT VERIFIED (the run did not finish): {loc} [{rid}]; it is tried again next run")
            continue
        if outcome == "bug":
            keep, reason = tv.judge(run, f)
            if keep:
                state[rid] = {**state.get(rid, {}), "status": "bug", "last_attempt": stamp, "file": reg["file"], "fn": reg["fn"]}
                human.append(ac.decision(
                    f"**Possible bug** in {loc} [{rid}]: {text[:400]} The agent's test fails on commit "
                    f"{ctx.sha[:10] or 'HEAD'} with: {reason[:300]}. Not committed; open a release TODO and add the "
                    f"test with the fix.\n\n<details><summary>test</summary>\n\n```r\n{tv.test_text(name, body)}```\n\n</details>",
                    unit=rid, key="bug"))
                counts["bug"] += 1
            else:
                fail(rid, f"claimed a bug, but {reason}", f)
                counts["bug not confirmed"] += 1
            continue
        keep, reason = judge_test(run, reg, body)
        if not keep:
            fail(rid, reason, f)
            continue
        rel = tv.unique_test_path(ctx.repo, tv.slugify(f.get("test_file_slug") or name), taken)
        header = tv.comment_block([
            f"Untested-code audit, {ctx.now.date().isoformat()}: covers {reg['file']}:{reg['first']}-{reg['last']} "
            f"({reg['fn'] or 'top level'}; region {rid}).",
            f"Reference: {_norm(f.get('reference')) or 'see the assertions'}",
            f"Verified on commit {ctx.sha[:12] or 'unknown'} under pkgload::load_all(compile = FALSE): {reason}.",
        ])
        content = header + "\nlibrary(testthat)\nlibrary(EDI)\n\n" + tv.test_text(name, body)
        ctx.path(rel).parent.mkdir(parents=True, exist_ok=True)
        ctx.path(rel).write_text(content)
        first = tv.test_text(name, body).splitlines()[0]
        applied.append(f"`{rel}`: covers {loc} [{rid}] ({', '.join(reg['signals']) or 'uncovered'}); {reason}")
        proposed.append({"unit": rid, "kind": "test", "text": finding_text(rid, "test"), "applied_file": rel,
                         "applied_text": first})
        state[rid] = {**state.get(rid, {}), "status": "proposed", "last_attempt": stamp, "test_file": rel,
                      "attempts": state.get(rid, {}).get("attempts", 0) + 1, "file": reg["file"], "fn": reg["fn"]}
        counts["kept"] += 1
    if counts["kept"]:
        note = tv.refresh_runtime_manifest(ctx.repo)
        if note:
            human.append(note)

    # Regions no longer uncovered (a merged test covered them, or the code changed) leave the state;
    # unreachable and intended verdicts stay while the region exists.
    if regions:
        for rid in list(state):
            if rid not in regions and rid not in plan_units:
                state.pop(rid)
        for rid in list(unreachable):
            if rid not in regions:
                unreachable.pop(rid)
    save_regions_state(ctx, state)
    unreach_path.write_text(json.dumps(unreachable, indent=1, sort_keys=True) + "\n")
    m = ctx.notes.manifest()
    if not res["errors"] or res["regions"]:
        m["code_sha"] = ctx.sha or ac.git("rev-parse", "HEAD", cwd=ctx.repo, check=False).strip()
        m["coverage_sha"] = res["coverage"].get("sha", "")
    ctx.notes.save_manifest(m)

    summary = []
    cov = res["coverage"]
    summary.append("Coverage read from: " + ("; ".join(cov["sources"]) or "nothing") + ".")
    if res["errors"]:
        summary.append("**Input problems:** " + " ".join(res["errors"]))
    if res["regions"] or res["excluded"]:
        top = res["regions"][:5]
        summary.append(f"{len(res['regions'])} uncovered region(s) ranked (release {res.get('release') or '?'}); "
                       f"{sum(res['excluded'].values())} not ranked ("
                       + ", ".join(f"{v} {k}" for k, v in sorted(res["excluded"].items())) + f"); "
                       f"{res['dropped_lines']} measured line(s) dropped because the code changed since the measurement.")
        if top:
            info.append("Top of the ranking: " + "; ".join(
                f"`{r['file']}:{r['first']}` {r['fn'] or ''} ({r['score']})" for r in top))
    if res.get("skipped"):
        summary.append(f"Claude stage skipped: {res['skipped']}.")
    elif "waiting" in res:
        summary.append(f"Regions due this run: {res['waiting']} (at most {TOP_N} go to the agents).")
    summary.append("Outcomes: " + ", ".join(f"{v} {k}" for k, v in counts.items() if v) + "." if any(counts.values())
                   else "Outcomes: none this run.")
    # Python regions are not sent to an agent: each is a mechanical finding ("write a pytest by hand"),
    # tracked by region id, so it can be cited or dismissed and counts as fixed once covered. A run that
    # did not rank the regions (no code change, no coverage input) carries the earlier ones.
    mech_lines = [x["text"] for x in mech]
    for r in res.get("python_regions") or []:
        mech_lines.append({"text": f"Python region with no test (write a pytest by hand): "
                                   f"`{r['file']}:{r['first']}-{r['last']}` {r['fn'] or ''}".rstrip(),
                           "unit": PY_UNIT, "kind": "python-region", "key": r["id"]})
    scope = {"coverage-input", ALLOWLIST} | ({PY_UNIT} if "python_regions" in res else set())
    return {"summary": "\n".join(summary), "applied": applied, "mechanical": mech_lines,
            "mechanical_scope_units": sorted(scope), "human": human, "info": info, "proposed": proposed}


# ---------------------------------------------------------------- CLI: the ranking alone

def _rank_cli(a):
    class _N:
        def __init__(self, d):
            self.dir = Path(d)
            self.root = self.dir

        def manifest(self):
            return {"units": {}}

        def findings(self):
            return []
    import tempfile
    work = tempfile.mkdtemp()
    if a.lines:
        os.environ["UNTESTED_CODE_R_LINES"] = a.lines
    if a.rds:
        os.environ["UNTESTED_CODE_R_RDS"] = a.rds
    if a.python_xml:
        os.environ["UNTESTED_CODE_PY_XML"] = a.python_xml
    os.environ.setdefault("UNTESTED_CODE_FROM_HEAD", "1")
    ctx = ac.Context(dict(SPEC, label="audit-untested-code"), a.repo, _N(work), work, scope="all")
    res = analyse(ctx)
    if a.json:
        print(json.dumps([{k: r[k] for k in ("id", "file", "fn", "first", "last", "score", "signals")}
                          | {"n_lines": len(r["lines"])} for r in res["regions"][:a.top]], indent=1))
    else:
        print("sources:", "; ".join(res["coverage"]["sources"]))
        for e in res["errors"] + res["allow_problems"]:
            print("problem:", e)
        print(f"{len(res['regions'])} regions ranked; not ranked: {res['excluded']}; dropped lines: {res['dropped_lines']}")
        shown = diversify(res["regions"], a.top) if a.diverse else res["regions"][:a.top]
        for k, r in enumerate(shown, 1):
            print(f"{k:3d}. {r['score']:5.2f} {r['id']} {r['file']}:{r['first']}-{r['last']} "
                  f"[{r['fn'] or '-'}] {len(r['lines'])} line(s): {', '.join(r['signals'])}")
    return 0


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description="Rank uncovered regions (no Claude, nothing edited).")
    ap.add_argument("--repo", default=".")
    ap.add_argument("--lines", help="untested_code_export.R CSV")
    ap.add_argument("--rds", help="merged-coverage.rds (converted with Rscript)")
    ap.add_argument("--python-xml", help="coverage.xml from pytest --cov")
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--diverse", action="store_true", help="apply the per-function and per-file caps a run uses")
    return _rank_cli(ap.parse_args(argv))


if __name__ == "__main__":
    sys.exit(main())
