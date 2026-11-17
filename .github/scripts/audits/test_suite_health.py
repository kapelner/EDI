"""Test-suite health audit (weekly, mechanical only).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4, "Test-suite health").

Static checks over R/EDI/tests/testthat and R/package_tests/testthat_bulk:

- test_that() blocks that call no expectation, directly or through a helper that does;
- skip() calls that nothing can stop from running (the test or the rest of the file never runs);
- skip_if() / skip_if_not() / skip_on_os() calls whose literal arguments mean they never lift;
- test files whose names carry a TODO number (forbidden by CLAUDE.md);
- test files whose status in the bulk runs (test-bulk-non-cran.yml, correctness shards' timings.csv)
  went from pass to fail more than once in the last 8 weeks, or differed on the same commit.

The R files are only parsed (test_suite_health.R, getParseData); nothing loads EDI.

The PR renames TODO-numbered test files (the TODO moves into a top comment in the v<version>-TODO-<n>
form) and rewrites FINDINGS_FILE with the other findings. It removes and skips nothing. Deleting a line
of FINDINGS_FILE on the PR branch rejects that finding, so it is not raised again.
"""
import csv
import datetime as dt
import io
import json
import os
import re
import subprocess
import zipfile
from pathlib import Path

import audit_common as ac

SPEC = {
    "name": "test-suite-health",
    "title": "Test-suite health",
    "report": "pr",
    "claude": False,
}

TEST_DIRS = ("R/EDI/tests/testthat", "R/package_tests/testthat_bulk")
HELPER_DIRS = ("R/package_tests",)   # top-level helpers the bulk tests source
FINDINGS_FILE = "R/package_metadata/audits/test_suite_health.md"
RUNTIMES_CSV = "R/package_tests/ci/test_runtimes.csv"
PARSER = Path(__file__).with_suffix(".R")
BULK_WORKFLOW = "test-bulk-non-cran.yml"
HISTORY_WEEKS = 8
MAX_NEW_RUNS = 40          # bulk runs downloaded per audit run; older ones are read next week
NOTES_CACHE = "bulk_runs.json"

# testthat functions that record an expectation (expect_* is matched by prefix).
EXPECTATIONS = {"expect", "fail", "succeed", "verify_output", "pass"}
TODO_IN_NAME = re.compile(r"(?i)(?:^|[-_])(todo-?(\d+))(?=[-_.])")
ALL_OSES = {"windows", "mac", "linux", "solaris"}

KIND_TITLES = {
    "no-expectation": "Tests with no expectation",
    "unconditional-skip": "Skips that always run",
    "never-lifts": "Skips whose condition never lifts",
    "todo-in-name": "Test files named for a TODO number",
    "flaky": "Test files that flip between pass and fail in the bulk runs",
    "parse-error": "Test files that do not parse",
}


# ---------------------------------------------------------------- files and parsing

def test_files(repo):
    """(test files holding test_that blocks, every R file that may define a helper)."""
    files = [f for f in ac.tracked_files(*TEST_DIRS, cwd=repo) if f.endswith(".R")]
    tests = [f for f in files if re.match(r"test.*\.R$", os.path.basename(f))
             and os.path.dirname(f) in TEST_DIRS]
    helpers = files + [f for f in ac.tracked_files(*HELPER_DIRS, cwd=repo)
                       if f.endswith(".R") and os.path.dirname(f) in HELPER_DIRS]
    return tests, sorted(set(helpers))


def parse_r(repo, files, out_path):
    """Run the R parser over `files` (repo-relative). Returns the parsed list, or raises RuntimeError."""
    r = subprocess.run(["Rscript", str(PARSER), str(out_path), *files], cwd=repo, capture_output=True,
                       text=True)
    if r.returncode:
        raise RuntimeError(f"Rscript failed: {(r.stderr or r.stdout).strip()[-600:]}")
    return json.loads(Path(out_path).read_text())


def as_list(x):
    if x is None:
        return []
    return x if isinstance(x, list) else [x]


def expectation_helpers(parsed):
    """Names of functions that call an expectation, directly or through another such function.

    Only calls count here, and plain symbols that look like expectations (expect_*): a variable that
    shares a helper's name must not make every function that reads it a helper."""
    defs = {}
    for f in parsed:
        for fn in as_list(f.get("functions")):
            d = defs.setdefault(fn["name"], set())
            d.update(as_list(fn.get("calls")))
            d.update(s for s in as_list(fn.get("symbols")) if is_expectation(s, set()))
    found = set()
    changed = True
    while changed:
        changed = False
        for name, uses in defs.items():
            if name not in found and any(is_expectation(u, found) for u in uses):
                found.add(name)
                changed = True
    return found


def is_expectation(name, helpers):
    return name.startswith("expect_") or name in EXPECTATIONS or name in helpers


def block_expects(t, helpers):
    """A test_that block records an expectation: it calls one (or a helper), or passes one by name."""
    return any(is_expectation(u, helpers) for u in as_list(t.get("calls")) + as_list(t.get("symbols")))


def desc_of(t):
    d = t.get("desc") or ""
    return d.strip("\"'") or f"line {t.get('line')}"


def never_lifts(fn, text):
    """Why a skip_* call with literal arguments can never lift, or None. Simple literal cases only."""
    t = re.sub(r"\s+", "", re.sub(r"^testthat::", "", text))
    if fn == "skip_if" and re.match(r"skip_if\((TRUE|T|!FALSE|!F)[,)]", t):
        return "its condition is the literal TRUE"
    if fn == "skip_if_not" and re.match(r"skip_if_not\((FALSE|F|!TRUE|!T)[,)]", t):
        return "its condition is the literal FALSE"
    if fn == "skip_on_os":
        oses = set(re.findall(r"[\"'](\w+)[\"']", t))
        if ALL_OSES <= oses:
            return "it lists every operating system"
    return None


def static_findings(parsed, test_set):
    """Findings from the parsed R files. `test_set`: files whose test_that blocks are checked."""
    helpers = expectation_helpers(parsed)
    out = []
    for f in parsed:
        path = f["file"]
        if f.get("error"):
            if path in test_set:
                out.append({"unit": path, "kind": "parse-error",
                            "text": "does not parse: " + f["error"].splitlines()[0][:200]})
            continue
        if path not in test_set:
            continue
        tests = as_list(f.get("tests"))
        skips = as_list(f.get("skips"))
        by_line = {t["line"]: t for t in tests}
        always_skipped = set()
        for s in skips:
            where = by_line.get(s.get("test_line"))
            unit = f"{path} :: {desc_of(where)}" if where else f"{path} (file level)"
            if s["fn"] == "skip" and s.get("unconditional"):
                if where:
                    always_skipped.add(where["line"])
                    text = f"`{s['text']}` runs unconditionally, so this test never runs"
                else:
                    text = f"`{s['text']}` at file level runs unconditionally, so nothing after it runs"
                out.append({"unit": unit, "kind": "unconditional-skip", "text": text, "line": s["line"]})
                continue
            why = never_lifts(s["fn"], s.get("text", ""))
            if why:
                if where:
                    always_skipped.add(where["line"])
                out.append({"unit": unit, "kind": "never-lifts",
                            "text": f"`{s['text']}` never lifts: {why}", "line": s["line"]})
        for t in tests:
            if t["line"] in always_skipped:
                continue
            if block_expects(t, helpers):
                continue
            how = " (it checks with stopifnot() only, which testthat does not count)" \
                if "stopifnot" in as_list(t.get("calls")) else ""
            out.append({"unit": f"{path} :: {desc_of(t)}", "kind": "no-expectation",
                        "text": f"test_that() block calls no expectation{how}", "line": t["line"]})
    return out


def todo_name_findings(files):
    out = []
    for path in files:
        m = TODO_IN_NAME.search(os.path.basename(path))
        if m:
            out.append({"unit": path, "kind": "todo-in-name",
                        "text": f"file name carries TODO-{int(m.group(2))}; CLAUDE.md asks for a name that "
                                "says what the test checks", "todo": int(m.group(2))})
    return out


# ---------------------------------------------------------------- bulk-run history

def _gh(*args):
    """`gh api ...` stdout as bytes; raises RuntimeError. Tests replace this function."""
    try:
        r = subprocess.run(["gh", "api", *args], capture_output=True)
    except FileNotFoundError as e:
        raise RuntimeError("gh is not installed") from e
    if r.returncode:
        raise RuntimeError(r.stderr.decode("utf-8", "replace").strip()[:300])
    return r.stdout


def _gh_lines(*args):
    return [json.loads(l) for l in _gh(*args).decode().splitlines() if l.strip()]


def read_timings(zip_bytes):
    """{test_file: status} from a correctness-shard artifact zip."""
    out = {}
    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as z:
        for name in z.namelist():
            if os.path.basename(name) == "timings.csv":
                for row in csv.DictReader(io.StringIO(z.read(name).decode("utf-8", "replace"))):
                    if row.get("test_file"):
                        out[row["test_file"]] = row.get("status") or "unknown"
    return out


def update_history(cache, repo_slug, now):
    """Add the bulk runs of the last HISTORY_WEEKS weeks that are not in `cache` yet.

    cache: {run_id: {"created_at", "sha", "attempt", "statuses": {file: status}}}. Returns (cache, note).
    """
    since = (now - dt.timedelta(weeks=HISTORY_WEEKS)).date().isoformat()
    cache = {k: v for k, v in cache.items() if (v.get("created_at") or "") >= since}
    runs = _gh_lines(f"repos/{repo_slug}/actions/workflows/{BULK_WORKFLOW}/runs"
                     f"?branch=main&status=completed&created=%3E%3D{since}&per_page=100",
                     "--paginate", "--jq",
                     ".workflow_runs[] | {id, created_at, head_sha, run_attempt, conclusion}")
    new = [r for r in runs if str(r["id"]) not in cache and r.get("conclusion") not in ("cancelled", "skipped")]
    new.sort(key=lambda r: r["created_at"], reverse=True)
    for r in new[:MAX_NEW_RUNS]:
        arts = _gh_lines(f"repos/{repo_slug}/actions/runs/{r['id']}/artifacts?per_page=100", "--paginate",
                         "--jq", ".artifacts[] | {id, name, expired}")
        statuses = {}
        for a in arts:
            if a.get("expired") or not re.fullmatch(r"correctness-shard-\d+", a.get("name", "")):
                continue
            try:
                statuses.update(read_timings(_gh(f"repos/{repo_slug}/actions/artifacts/{a['id']}/zip")))
            except (RuntimeError, zipfile.BadZipFile):
                continue
        cache[str(r["id"])] = {"created_at": r["created_at"], "sha": r.get("head_sha", ""),
                               "attempt": r.get("run_attempt", 1), "statuses": statuses}
    left = max(0, len(new) - MAX_NEW_RUNS)
    note = f"{len(cache)} bulk run(s) since {since}" + (f"; {left} older run(s) left for next week" if left else "")
    return cache, note


def flaky_findings(cache):
    """Files that went pass -> fail at least twice, or passed and failed on the same commit.

    Pass = status "complete". timings.csv records "complete" even when a test in the file failed an
    expectation (run_selected_tests.R), so a fail here is an error, a crash or a time-out.
    """
    runs = sorted(cache.values(), key=lambda r: r.get("created_at") or "")
    seq, by_sha = {}, {}
    for r in runs:
        for f, st in (r.get("statuses") or {}).items():
            ok = st == "complete"
            seq.setdefault(f, []).append(ok)
            by_sha.setdefault((f, r.get("sha")), set()).add(ok)
    out = []
    for f, s in sorted(seq.items()):
        breaks = sum(1 for a, b in zip(s, s[1:]) if a and not b)
        same = sorted(sha[:8] for (ff, sha), v in by_sha.items() if ff == f and len(v) == 2 and sha)
        if breaks >= 2 or same:
            why = []
            if breaks >= 2:
                why.append(f"went from pass to fail {breaks} times")
            if same:
                why.append(f"passed and failed on the same commit ({', '.join(same[:3])})")
            out.append({"unit": f, "kind": "flaky",
                        "text": f"status flips between pass and fail in the bulk runs of the last {HISTORY_WEEKS} weeks",
                        "detail": f"{'; '.join(why)}; failed in {s.count(False)} of {len(s)} runs"})
    return out


# ---------------------------------------------------------------- stages

def mechanical(ctx):
    ctx.workdir.mkdir(parents=True, exist_ok=True)
    info = {}
    tests, helpers = test_files(ctx.repo)
    out = todo_name_findings(tests)
    try:
        parsed = parse_r(ctx.repo, helpers, ctx.workdir / "test_suite_health_parse.json")
        out += static_findings(parsed, set(tests))
        info["parsed"] = f"{len(tests)} test files parsed, {len(helpers)} R files read for helpers"
    except (RuntimeError, OSError, ValueError) as e:
        info["parsed"] = f"NOT RUN: the R parser failed ({e})"

    slug = os.environ.get("GITHUB_REPOSITORY")
    cache_path = ctx.notes.dir / NOTES_CACHE
    try:
        cache = json.loads(cache_path.read_text()) if cache_path.exists() else {}
    except ValueError:
        cache = {}
    if slug:
        try:
            cache, info["history"] = update_history(cache, slug, ctx.now)
            cache_path.write_text(json.dumps(cache, sort_keys=True) + "\n")
        except RuntimeError as e:
            info["history"] = f"NOT RUN: could not read the bulk runs ({e})"
    else:
        info["history"] = "NOT RUN: no GITHUB_REPOSITORY (local run)"
    if cache:
        out += flaky_findings(cache)
    (ctx.workdir / "test_suite_health_info.json").write_text(json.dumps(info, indent=1))
    return out


# ---------------------------------------------------------------- renames

def resolve_release(ctx, path, todo):
    """The release version that owns TODO-<todo> for this test file, or None."""
    pat = re.compile(rf"v(\d+\.\d+\.\d+)[- ]TODO-{todo}\b")
    body = ctx.read(path) or ""
    m = pat.search(body)
    if m:
        return m.group(1)
    m = re.search(rf"release_v(\d+)_(\d+)_(\d+)\.md\W+(?:→\s*)?TODO-{todo}\b", body)
    if m:
        return ".".join(m.groups())
    log = subprocess.run(["git", "log", "--follow", "--format=%s%n%b", "--", path], cwd=ctx.repo,
                         capture_output=True, text=True).stdout
    m = pat.search(log)
    if m:
        return m.group(1)
    # A release file whose TODO-<todo> entry names the test file.
    base = os.path.basename(path)
    hits = set()
    for rel in sorted(ctx.repo.glob("R/package_metadata/future_release_plans/release_v*.md")):
        text = rel.read_text(errors="replace")
        for block in re.split(r"\n(?=- \[[ xX]\] )", text):
            if re.match(rf"- \[[ xX]\] TODO-{todo}\b", block) and base in block:
                hits.add(".".join(re.findall(r"\d+", rel.stem)))
    return hits.pop() if len(hits) == 1 else None


def new_name(path):
    """The file name without its TODO number, or None when nothing descriptive is left."""
    base = os.path.basename(path)
    m = TODO_IN_NAME.search(base)
    if not m:
        return None
    stem = base[:m.start(1)] + base[m.end(1):]
    stem = re.sub(r"[-_]{2,}", "-", stem).replace("-.R", ".R").replace("_.R", ".R")
    if re.fullmatch(r"test[-_]?\.R", stem):
        return None
    return os.path.join(os.path.dirname(path), stem)


def rename_test(ctx, finding):
    """Rename one TODO-numbered test file. Returns (applied line, proposed finding) or (None, reason)."""
    old = finding["unit"]
    version = resolve_release(ctx, old, finding["todo"])
    if not version:
        return None, (f"`{old}`: carries TODO-{finding['todo']}, but no release cites it, so the "
                      "v<version>-TODO-<n> comment cannot be written; rename it by hand")
    new = new_name(old)
    if not new:
        return None, f"`{old}`: nothing but the TODO number names the test; choose a name by hand"
    if ctx.path(new).exists():
        return None, f"`{old}`: the name without the TODO number, `{new}`, is taken; rename it by hand"
    comment = f"# v{version}-TODO-{finding['todo']} (this file was {os.path.basename(old)})."
    body = ctx.read(old) or ""
    ctx.path(new).write_text(comment + "\n" + body)
    ctx.path(old).unlink()
    runtimes = ctx.read(RUNTIMES_CSV)
    if runtimes and old in runtimes:
        ctx.path(RUNTIMES_CSV).write_text(re.sub(rf"(?m)^{re.escape(old)},", new + ",", runtimes))
    others = [f for f in ac.git("grep", "-l", "-F", os.path.basename(old), cwd=ctx.repo, check=False).splitlines()
              if f not in (old, RUNTIMES_CSV) and not f.endswith(".md")]
    line = f"`{old}` -> `{new}`, with the top comment `{comment}`"
    if others:
        line += f" (still named in {', '.join(f'`{o}`' for o in others[:5])}: update by hand)"
    return line, {**finding, "applied_file": new, "applied_text": comment}


# ---------------------------------------------------------------- findings file

def finding_line(f):
    return f"- `{f['unit']}`: {f['text']}"


def render_findings_file(findings):
    md = ["# Test-suite health: open findings", "",
          "Written by the test-suite-health audit (`.github/workflows/audit-test-suite-health.yml`) and "
          "rewritten on each run. To reject a finding, delete its line in the audit PR: the audit will not "
          "raise it again. Fix a finding in the test itself; the line goes away on the next run.", ""]
    if not findings:
        md += ["No open findings.", ""]
    for kind, title in KIND_TITLES.items():
        rows = sorted({finding_line(f) for f in findings if f["kind"] == kind})
        if rows:
            md += [f"## {title} ({len(rows)})", ""] + rows + [""]
    return "\n".join(md)


def apply(ctx, results, mech):
    info = {}
    p = ctx.workdir / "test_suite_health_info.json"
    if p.exists():
        try:
            info = json.loads(p.read_text())
        except ValueError:
            pass
    applied, human, proposed = [], [], []
    for f in mech:
        if f["kind"] == "todo-in-name" and f.get("todo") is not None:
            line, extra = rename_test(ctx, f)
            if line:
                applied.append(line)
                proposed.append(extra)
            else:
                human.append(extra)
    listed = [f for f in mech if f["kind"] != "todo-in-name"]
    old_file = ctx.read(FINDINGS_FILE)
    new_file = render_findings_file(listed)
    if listed or old_file is not None:
        if new_file != old_file:
            ctx.path(FINDINGS_FILE).parent.mkdir(parents=True, exist_ok=True)
            ctx.path(FINDINGS_FILE).write_text(new_file)
        for f in listed:
            proposed.append({**f, "applied_file": FINDINGS_FILE, "applied_text": finding_line(f)})
    mechanical = []
    for f in listed:
        loc = f" (line {f['line']})" if f.get("line") else ""
        detail = f" ({f['detail']})" if f.get("detail") else ""
        mechanical.append(f"{KIND_TITLES.get(f['kind'], f['kind'])}: `{f['unit']}`{loc}: {f['text']}{detail}")
    counts = {}
    for f in mech:
        counts[f["kind"]] = counts.get(f["kind"], 0) + 1
    summary = [f"Static checks: {info.get('parsed', 'not recorded')}.",
               f"Bulk-run history: {info.get('history', 'not recorded')}.",
               "Findings by kind: " + (", ".join(f"{k} {v}" for k, v in sorted(counts.items())) or "none") + ".",
               f"Findings other than renames are listed in `{FINDINGS_FILE}`; nothing is skipped or removed."]
    return {"summary": "\n".join(summary), "applied": applied, "mechanical": mechanical, "human": human,
            "proposed": proposed}
