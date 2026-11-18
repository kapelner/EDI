"""Code-duplication audit (weekly) and the per-push duplication check.

Owner request 2026-11-18. Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md
(Part 4, "Code duplication").

Why: several of the 2026-11-18 bugs were copies that drifted. InferenceSurvivalLogRank and
InferenceSurvivalGehanWilcox share compute_shared_icen(); one got the ictest() arm-sign fix and the
other did not (v1.0.6-TODO-117/-121). The GEE family parse is written out in R/EDI/src/fast_gee.cpp
and again in python/cpp/bindings_incidence.cpp (v1.0.6-TODO-103). So the audit ranks DIVERGENT
near-clones first: pairs of regions that are mostly identical but differ in a few lines.

Detection (no Claude, about 1 s): jscpd (token-based copy/paste detector) over SCAN_DIRS, with
comments skipped. jscpd reports runs of identical tokens; a near-clone with a few changed lines shows
up as several runs between the same two files with short gaps between them. This module

1. merges the runs of one file pair whose gaps are at most GAP_LINES on both sides into one pair of
   regions ("family": two regions, possibly in one file);
2. extends both regions by up to EXTEND_LINES lines each way and diffs them line by line
   (comments and whitespace removed), trimming unmatched ends, so the family covers the whole
   shared stretch, not only the parts jscpd matched exactly;
3. classifies each differing hunk as `renamed` (equal once identifiers and literals are masked:
   log_rank vs gehan, "logrank1" vs "wmw") or `structural` (an operator, a call, an extra line:
   the `arm_sign *` of v1.0.6-TODO-117), and gives the family a divergence score that is highest
   for a long shared stretch with a few structural differences.

A family's id (`dup-<12 hex>`) hashes its two file paths and the normalized text of its two regions,
not line numbers, so it survives code moving around the file; any edit inside a region makes a new
id. Its decision id (`code-duplication-d<8 hex>`, from the framework) is what the owner lists in
R/package_metadata/audits/dismissed_decisions.md to dismiss it.

Weekly job (audit-code-duplication.yml): candidates are the divergent families plus long exact
cross-file clones. Claude triages only candidates with no verdict yet (verdicts are kept in
`code-duplication/verdicts.json` on the audit-notes branch) and not dismissed, at most
MAX_BATCHES x 8 per run, highest score first; the rest wait for the next run. When no R/C++/Python
code changed since the last run (scripts/significant_changes.py: comment- and whitespace-only edits
do not count) and nothing is waiting, the Claude stage is skipped. Each candidate gets one verdict:
`intentional`, `refactor` (should share a helper) or `divergence_bug` (the copies drifted; one got a
fix the other did not). Refactor and divergence verdicts stay listed as decisions in the audit's
issue while the family exists, until dismissed or cited by an open release TODO.

Per-push check (code-duplication-push.yml; `python3 code_duplication.py push ...`): no Claude. Scans
the base and the head and reports what the push or PR introduces: NEW clones (a candidate family at
head that overlaps added lines and has no counterpart at base) and NEW divergences (a base family
where the change edits one region and leaves the other alone). Only files significant_changes.py
counts are looked at. Non-blocking unless --fail-on-divergence is given.

Stdlib only.
"""
import argparse
import difflib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve()
if str(HERE.parents[1]) not in sys.path:   # a local or CLI run: make audit_common importable
    sys.path.insert(0, str(HERE.parents[1]))
import audit_common as ac  # noqa: E402

SPEC = {
    "name": "code-duplication",
    "title": "Code duplication audit",
    "report": "issue",
    "claude": True,
    "model": ac.SONNET,
    "batch_size": 8,
    "cycle_weeks": 1,      # units() returns only candidates still waiting for a verdict
    "max_batches": 12,     # at most 96 candidates a run; the rest wait, highest score first
    "tools": "Read,Glob,Grep",
    "max_turns": 60,
}

SCAN_DIRS = ("R/EDI/R", "R/EDI/src", "python/src", "python/cpp")
IGNORE = ("**/RcppExports.*", "**/*.pyi", "**/*.o", "**/*.so")   # generated code and type stubs
MIN_TOKENS = 50        # jscpd --min-tokens (tuned 2026-11-18; see the plan's table)
GAP_LINES = 8          # merge jscpd runs of one file pair separated by at most this many lines
EXTEND_LINES = 20      # look this far past each end for more shared lines
ANCHOR_TOKENS = 8      # a family starts and ends with a run of at least this many equal tokens
MIN_SHARED_TOKENS = 100  # a candidate shares at least this many tokens
MIN_SIMILARITY = 0.8   # (shared + renamed) / (shared + renamed + structurally different) tokens
MAX_DIFF_TOKENS = 300  # more structurally different tokens than this is two functions, not a drift
MIN_EXACT_TOKENS = 250  # an exact clone is a candidate (refactor?) only when this long and cross-file
VERDICTS = ("intentional", "refactor", "divergence_bug")

R_EXT = (".R", ".r")
PY_EXT = (".py",)
TRIVIAL = re.compile(r"^[\s{}()\[\];,]*$|^(?:else|end|\}\s*else\s*\{|\)\s*\{|\}\s*\)|\}\s*,)$")
KEYWORDS = set("""if else for while repeat return function break next in TRUE FALSE NULL NA Inf NaN
    self private super invisible stop warning is.null is.na length
    const static void auto int double bool std throw try catch new delete true false nullptr
    def lambda None True False not and or is pass raise yield with as import from class""".split())
TOKEN = re.compile(r"\"(?:[^\"\\]|\\.)*\"|'(?:[^'\\]|\\.)*'|\d+\.?\d*(?:[eE][+-]?\d+)?[LfF]?|"
                   r"[A-Za-z_.][A-Za-z0-9_.]*|::|->|<-|<=|>=|==|!=|&&|\|\||\S")


# ---------------------------------------------------------------- normalizing source lines

def _strip_hash_comment(line):
    """The code part of an R or Python line: drops a # comment that is not inside a string."""
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


def _strip_cpp_comments(text):
    """Comments replaced by spaces (newlines kept, so line numbers stay right)."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c in "\"'":
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            out.append(text[i:j + 1])
            i = j + 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append(re.sub(r"[^\n]", " ", text[i:j]))
            i = j
        else:
            out.append(c)
            i += 1
    return "".join(out)


def code_lines(path, text):
    """[normalized line] for every line of the file (index 0 = line 1): comments removed, runs of
    whitespace collapsed; "" for a line with no code."""
    if path.endswith(R_EXT + PY_EXT):
        lines = [_strip_hash_comment(l) for l in text.splitlines()]
    else:
        lines = _strip_cpp_comments(text).splitlines()
    return [_squeeze(l) for l in lines]


def _squeeze(line):
    """Whitespace dropped except one space between two word characters, so `for(int i=0;` and
    `for (int i = 0;` read the same."""
    return re.sub(r"(?<!\w) | (?!\w)", "", re.sub(r"\s+", " ", line).strip())


def nontrivial(line):
    return bool(line) and not TRIVIAL.match(line)


# ---------------------------------------------------------------- jscpd

# jscpd 5.x (the Rust engine). Pinned to a release at least two weeks old (5.4.2: 2026-10-20; 5.4.3,
# 2026-11-08, was too new on 2026-11-18). The CI workflows install this version; bump it deliberately.
JSCPD_VERSION = "5.4.2"


def find_jscpd():
    """The command that runs jscpd: $JSCPD, else jscpd on PATH, else `npx --yes jscpd@JSCPD_VERSION`."""
    if os.environ.get("JSCPD"):
        return [os.environ["JSCPD"]]
    if shutil.which("jscpd"):
        return [shutil.which("jscpd")]
    if shutil.which("npx"):
        return [shutil.which("npx"), "--yes", f"jscpd@{JSCPD_VERSION}"]
    return None


def run_jscpd(root, dirs=SCAN_DIRS, min_tokens=MIN_TOKENS, jscpd=None):
    """jscpd's duplicates over root/<dirs>: [{"a": (rel, start, end), "b": (rel, start, end), "tokens"}].
    Raises RuntimeError when jscpd is missing or fails."""
    cmd0 = ([jscpd] if isinstance(jscpd, str) else jscpd) or find_jscpd()
    if not cmd0:
        raise RuntimeError(f"jscpd is not installed (npm install -g jscpd@{JSCPD_VERSION})")
    root = Path(root).resolve()
    paths = [str(root / d) for d in dirs if (root / d).is_dir()]
    if not paths:
        return []
    with tempfile.TemporaryDirectory() as out:
        cmd = [*cmd0, "--absolute", "--mode", "weak", "--min-tokens", str(min_tokens),
               "--ignore", ",".join(IGNORE), "--reporters", "json", "--output", out, "--silent", *paths]
        r = subprocess.run(cmd, capture_output=True, text=True, env={**os.environ, "JSCPD_NO_TIPS": "1"})
        rep = Path(out) / "jscpd-report.json"
        if not rep.exists():
            raise RuntimeError(f"jscpd failed ({r.returncode}): {(r.stderr or r.stdout).strip()[:500]}")
        data = json.loads(rep.read_text())
    return parse_jscpd(data, root)


def parse_jscpd(data, root):
    """jscpd's JSON report -> clone list with repo-relative paths (jscpd 3-5 report shapes)."""
    root = Path(root).resolve()
    out = []

    def side(f):
        name = f.get("name") or f.get("sourceId") or ""
        p = Path(name)
        rel = str(p.resolve().relative_to(root)) if p.is_absolute() and str(p).startswith(str(root)) else name
        start = (f.get("startLoc") or {}).get("line", f.get("start"))
        end = (f.get("endLoc") or {}).get("line", f.get("end"))
        return rel, int(start), int(end)

    for d in data.get("duplicates", []):
        a, b = side(d["firstFile"]), side(d["secondFile"])
        if (b[0], b[1]) < (a[0], a[1]):
            a, b = b, a
        out.append({"a": a, "b": b, "tokens": d.get("tokens", 0)})
    return out


# ---------------------------------------------------------------- families

def merge_runs(clones, gap=GAP_LINES):
    """Merge jscpd runs of one file pair that follow each other with gaps of at most `gap` lines on both
    sides. Returns [(fileA, a1, a2, fileB, b1, b2, runs)]."""
    by_pair = {}
    for c in clones:
        by_pair.setdefault((c["a"][0], c["b"][0]), []).append(c)
    fams = []
    for (fa, fb), cs in sorted(by_pair.items()):
        cs.sort(key=lambda c: (c["a"][1], c["b"][1]))
        cur = None
        for c in cs:
            (_, a1, a2), (_, b1, b2) = c["a"], c["b"]
            if cur and -2 <= a1 - cur[2] <= gap + 1 and -2 <= b1 - cur[5] <= gap + 1:
                cur = [fa, cur[1], max(cur[2], a2), fb, cur[4], max(cur[5], b2), cur[6] + 1]
            else:
                if cur:
                    fams.append(tuple(cur))
                cur = [fa, a1, a2, fb, b1, b2, 1]
        if cur:
            fams.append(tuple(cur))
    # A region of one file matched against itself, overlapping, is not a clone.
    return [f for f in fams if not (f[0] == f[3] and f[4] <= f[2])]


def tokens_of(lines, lo, hi):
    """[(line number, token)] for lines lo..hi (1-based, inclusive) of code_lines() output."""
    out = []
    for n in range(lo, hi + 1):
        out += [(n, t) for t in TOKEN.findall(lines[n - 1])]
    return out


def mask_token(t):
    if t[0] in "\"'":
        return "S"
    if t[0].isdigit():
        return "N"
    if re.match(r"[A-Za-z_.]", t) and t not in KEYWORDS:
        return "I"
    return t


def analyze(fam, lines_a, lines_b, extend=EXTEND_LINES):
    """Extend, diff and score one merged family. lines_* are code_lines() of the two files.

    The diff is over tokens, not lines, so the same code laid out differently (a one-line loop in
    R/EDI/src, the same loop over four lines in python/cpp) still lines up. Returns a family dict,
    or None if the two regions share no run of ANCHOR_TOKENS tokens."""
    fa, a1, a2, fb, b1, b2, runs = fam
    lo_a, hi_a = max(1, a1 - extend), min(len(lines_a), a2 + extend)
    lo_b, hi_b = max(1, b1 - extend), min(len(lines_b), b2 + extend)
    if fa == fb and lo_b <= hi_a:   # two regions of one file: the extensions must not overlap
        mid = (a2 + b1) // 2
        hi_a, lo_b = min(hi_a, max(a2, mid)), max(lo_b, min(b1, mid + 1))
    ta, tb = tokens_of(lines_a, lo_a, hi_a), tokens_of(lines_b, lo_b, hi_b)
    if not ta or not tb:
        return None
    ops = difflib.SequenceMatcher(None, [t for _, t in ta], [t for _, t in tb], autojunk=False).get_opcodes()
    # The family runs from the first to the last long equal run: short chance matches at the
    # edges of the extension (a lone "}" or "return") do not stretch it.
    good = [k for k, op in enumerate(ops) if op[0] == "equal" and op[2] - op[1] >= ANCHOR_TOKENS]
    if not good:
        return None
    ops = ops[good[0]:good[-1] + 1]
    shared, shared_lines, raw, cur = 0, set(), [], None
    for tag, i1, i2, j1, j2 in ops:
        if tag == "equal":
            shared += i2 - i1
            shared_lines.update(ta[i][0] for i in range(i1, i2))
            if i2 - i1 >= 3:
                if cur:
                    raw.append(cur)
                cur = None
            elif cur:   # a token or two in common inside a changed stretch: one hunk, not three
                cur[1], cur[3] = i2, j2
            continue
        if cur is None:
            cur = [i1, i2, j1, j2]
        else:
            cur[1], cur[3] = i2, j2
    if cur:
        raw.append(cur)
    hunks, struct_tokens, renamed_tokens = [], 0, 0
    for i1, i2, j1, j2 in raw:
        xa, xb = [t for _, t in ta[i1:i2]], [t for _, t in tb[j1:j2]]
        kind = "renamed" if len(xa) == len(xb) and list(map(mask_token, xa)) == list(map(mask_token, xb)) \
            else "structural"
        if kind == "renamed":
            renamed_tokens += len(xa)
        else:
            struct_tokens += max(len(xa), len(xb))
        la = sorted({n for n, _ in ta[i1:i2]})
        lb = sorted({n for n, _ in tb[j1:j2]})
        # A pure insertion has no lines on the other side: point at the line it follows.
        hunks.append({"kind": kind, "a": la or [ta[i1 - 1][0]], "b": lb or [tb[j1 - 1][0]],
                      "a_tokens": " ".join(xa), "b_tokens": " ".join(xb),
                      "a_text": [lines_a[n - 1] for n in la], "b_text": [lines_b[n - 1] for n in lb]})
    first, last = ops[0], ops[-1]
    ra = (ta[first[1]][0], ta[last[2] - 1][0])
    rb = (tb[first[3]][0], tb[last[4] - 1][0])
    same = shared + renamed_tokens
    similarity = same / (same + struct_tokens) if same + struct_tokens else 0.0
    structural = sum(1 for h in hunks if h["kind"] == "structural")
    if not hunks:
        score = 0.0
    else:
        weight = 1.0 if structural else 0.2
        score = shared / 10 * similarity ** 2 * weight / (1 + 0.5 * max(0, structural - 1))
    norm_a = " ".join(t for _, t in ta[first[1]:last[2]])
    norm_b = " ".join(t for _, t in tb[first[3]:last[4]])
    uid = "dup-" + ac.text_hash(fa, fb, norm_a, norm_b)[:12]
    return {"id": uid, "a": [fa, ra[0], ra[1]], "b": [fb, rb[0], rb[1]], "runs": runs,
            "shared": sum(1 for n in shared_lines if nontrivial(lines_a[n - 1])), "shared_tokens": shared,
            "differing_tokens": struct_tokens, "renamed_tokens": renamed_tokens,
            "similarity": round(similarity, 3), "hunks": hunks, "structural_hunks": structural,
            "score": round(score, 2), "kind": "exact" if not hunks else ("divergent" if structural else "renamed")}


def is_candidate(f):
    """Worth a look: a divergent or renamed near-clone, or a long exact clone across two files."""
    if f["shared_tokens"] < MIN_SHARED_TOKENS:
        return False
    if f["kind"] == "exact":
        return f["shared_tokens"] >= MIN_EXACT_TOKENS and f["a"][0] != f["b"][0]
    return f["similarity"] >= MIN_SIMILARITY and f["differing_tokens"] <= MAX_DIFF_TOKENS


def families(root, clones, reader=None):
    """Analyzed families for jscpd clones under root, best score first, duplicates (same id) removed."""
    root = Path(root)
    cache = {}

    def lines(rel):
        if rel not in cache:
            text = reader(rel) if reader else (root / rel).read_text(encoding="utf-8", errors="replace")
            cache[rel] = code_lines(rel, text or "")
        return cache[rel]

    analyzed = [f for f in (analyze(fam, lines(fam[0]), lines(fam[3])) for fam in merge_runs(clones)) if f]
    # Runs jscpd split by a longer gap are analyzed separately, and their extensions can cover the
    # same code again: keep the largest family and drop any that mostly repeats a kept one.
    analyzed.sort(key=lambda f: (-f["shared_tokens"], f["id"]))
    out, kept = [], {}
    for f in analyzed:
        pair = (f["a"][0], f["b"][0])
        if any(_span_overlap(f["a"], g["a"]) >= 0.5 and _span_overlap(f["b"], g["b"]) >= 0.5
               for g in kept.get(pair, [])):
            continue
        kept.setdefault(pair, []).append(f)
        out.append(f)
    out.sort(key=lambda f: (-f["score"], -f["shared"], f["id"]))
    return out


def _span_overlap(x, y):
    """Lines two regions [path, first, last] share, as a share of the shorter one."""
    common = min(x[2], y[2]) - max(x[1], y[1]) + 1
    return max(0, common) / min(x[2] - x[1] + 1, y[2] - y[1] + 1)


def detect(root, jscpd=None, min_tokens=MIN_TOKENS):
    """(families, stats) for the tree at root."""
    t0 = time.monotonic()
    clones = run_jscpd(root, min_tokens=min_tokens, jscpd=jscpd)
    t1 = time.monotonic()
    fams = families(root, clones)
    stats = {"jscpd_clones": len(clones), "families": len(fams),
             "candidates": sum(1 for f in fams if is_candidate(f)),
             "divergent": sum(1 for f in fams if is_candidate(f) and f["kind"] == "divergent"),
             "jscpd_seconds": round(t1 - t0, 2), "analysis_seconds": round(time.monotonic() - t1, 2),
             "min_tokens": min_tokens}
    return fams, stats


# ---------------------------------------------------------------- presentation

def loc(f, side):
    p, s, e = f[side]
    return f"{p}:{s}-{e}"


def short(f):
    return (f"`{loc(f, 'a')}` vs `{loc(f, 'b')}`: {f['shared']} shared lines, {f['structural_hunks']} structural "
            f"and {len(f['hunks']) - f['structural_hunks']} renaming difference(s), similarity {f['similarity']}, "
            f"score {f['score']}")


def unified(f, max_lines=120):
    """A readable diff of the two regions: each structural difference with its lines (comments and
    whitespace removed), then the renamings in one line. For the agent and the reports."""
    out = []
    for h in f["hunks"]:
        if h["kind"] != "structural":
            continue
        out.append(f"@@ {f['a'][0]}:{h['a'][0]} vs {f['b'][0]}:{h['b'][0]}")
        out += [f"- {x}" for x in h["a_text"]] + [f"+ {x}" for x in h["b_text"]]
        out.append(f"  (tokens: `{h['a_tokens'][:200]}` -> `{h['b_tokens'][:200]}`)")
        if len(out) > max_lines:
            out.append(f"... ({f['structural_hunks']} structural differences in all)")
            break
    ren = list(dict.fromkeys(f"{h['a_tokens']} -> {h['b_tokens']}" for h in f["hunks"] if h["kind"] == "renamed"))
    if ren:
        out.append("renamed: " + "; ".join(ren[:20]) + (f"; ... ({len(ren)} in all)" if len(ren) > 20 else ""))
    return "\n".join(out[:max_lines + 2])


def boundary(f):
    """One region in python/ and the other in R/: a pybind11 binding and its R/EDI counterpart."""
    return {f["a"][0].split("/")[0], f["b"][0].split("/")[0]} == {"R", "python"}


def hints(f):
    """Facts the agent should weigh when judging whether a duplicate is intentional."""
    out = []
    pa, pb = f["a"][0], f["b"][0]
    if boundary(f):
        out.append("R/Python boundary: one copy is a pybind11 binding, the other R/EDI code")
    if "ivwc" in (pa + pb).lower():
        out.append("one side is a legacy IVWC class (frozen; never published)")
    if pa == pb:
        out.append("both regions are in one file")
    if any(x in (pa + pb) for x in ("fast_", "_fast", "speedup")):
        out.append("may be a performance fast path")
    return out


def decision_id_of(uid):
    return ac.decision_id(SPEC["name"], uid, "dup", "")


# ---------------------------------------------------------------- weekly audit stages

def _detected(ctx):
    if getattr(ctx, "_dup", None) is None:
        try:
            fams, stats = detect(ctx.repo)
            err = None
        except (RuntimeError, OSError, ValueError) as e:
            fams, stats, err = [], {}, str(e)
        ctx._dup = {"families": fams, "stats": stats, "error": err}
    return ctx._dup


def load_verdicts(ctx):
    try:
        v = json.loads((ctx.notes.dir / "verdicts.json").read_text())
        return v if isinstance(v, dict) else {}
    except (OSError, ValueError):
        return {}


def save_verdicts(ctx, v):
    (ctx.notes.dir / "verdicts.json").write_text(json.dumps(v, indent=1, sort_keys=True) + "\n")


def code_changed_since(ctx, sha):
    """True/False whether R/C++/Python code under SCAN_DIRS changed since `sha` (comment and
    whitespace edits do not count); True when it cannot tell."""
    if not sha:
        return True
    sys.path.insert(0, str(Path(ctx.repo) / "scripts"))
    try:
        import significant_changes as sc
        return bool(sc.significant_changes(str(ctx.repo), sha, "HEAD", [f":(glob){d}/**" for d in SCAN_DIRS]))
    except Exception:   # unknown commit, no git: fail open
        return True


def mechanical(ctx):
    d = _detected(ctx)
    if d["error"]:
        return [{"unit": "jscpd", "kind": "tool", "text": f"Detection did not run: {d['error']}"}]
    return []


def units(ctx):
    d = _detected(ctx)
    verdicts = load_verdicts(ctx)
    dismissed = ac.dismissed_decisions(ctx.repo)
    waiting = [f for f in d["families"] if is_candidate(f) and f["id"] not in verdicts
               and decision_id_of(f["id"]) not in dismissed]
    ctx._dup["waiting"] = len(waiting)
    last = ctx.manifest.get("code_sha")
    changed = code_changed_since(ctx, last)
    ctx._dup["code_changed"] = changed
    if ctx.scope != "all" and not changed and not ctx.manifest.get("backlog"):
        ctx._dup["skipped"] = f"no R/C++/Python code change since {str(last)[:8]} and no backlog"
        return {}
    out = {}
    for f in waiting:
        out[f["id"]] = {
            # Highest score first; an R/Python boundary pair counts three times (the v1.0.6-TODO-103 shape:
            # layout differences there lower the score of code that must stay in step).
            "hash": f["id"], "priority": -int(f["score"] * 100 * (3 if boundary(f) else 1) + f["shared"]),
            "context": {"files": [loc(f, "a"), loc(f, "b")], "kind": f["kind"], "score": f["score"],
                        "shared_lines": f["shared"], "similarity": f["similarity"], "structural_differences": f["structural_hunks"],
                        "diff": unified(f), "hints": hints(f)}}
    return out


def _verdict_text(v):
    label = {"divergence_bug": "Divergence-bug suspect", "refactor": "Refactor candidate"}[v["verdict"]]
    ev = "; ".join(v.get("evidence") or [])
    files = v.get("files") or ["?", "?"]
    return (f"**{label}**: `{files[0]}` vs `{files[1]}`. {v.get('text', '').strip()}"
            + (f" Evidence: {ev}." if ev else ""))


def apply(ctx, results, mech):
    d = _detected(ctx)
    fams = {f["id"]: f for f in d["families"]}
    verdicts = load_verdicts(ctx)
    stamp = ac.now_utc().isoformat(timespec="seconds")
    new_counts = {}
    for r in results:
        for f in r.get("findings") or []:
            u, v = f.get("unit"), f.get("verdict")
            if u not in fams or v not in VERDICTS:
                continue
            verdicts[u] = {"verdict": v, "text": re.sub(r"\s+", " ", f.get("text", "")).strip(),
                           "evidence": f.get("evidence") or [], "judged_at": stamp,
                           "run": os.environ.get("GITHUB_RUN_ID", "")}
            new_counts[v] = new_counts.get(v, 0) + 1
    for u, v in verdicts.items():   # where the family is now (lines move; the id does not)
        if u in fams:
            v["files"] = [loc(fams[u], "a"), loc(fams[u], "b")]
    save_verdicts(ctx, verdicts)
    dismissed = ac.dismissed_decisions(ctx.repo)
    waiting = [f for f in d["families"] if is_candidate(f) and f["id"] not in verdicts
               and decision_id_of(f["id"]) not in dismissed]
    m = ctx.notes.manifest()
    if not d["error"]:
        m["code_sha"] = ctx.sha or ac.git("rev-parse", "HEAD", cwd=ctx.repo, check=False).strip()
        m["backlog"] = len(waiting)
        m["stats"] = d["stats"]
    ctx.notes.save_manifest(m)

    # A refactor or divergence verdict stays a decision while its family is still detected. When
    # detection failed, every such verdict is listed again, so a tool failure resolves nothing.
    order = {"divergence_bug": 0, "refactor": 1}
    score = {u: f["score"] for u, f in fams.items()}
    listed = [u for u, v in verdicts.items() if v.get("verdict") in order and (d["error"] or u in fams)]
    listed.sort(key=lambda u: (order[verdicts[u]["verdict"]], -score.get(u, 0), u))
    human = [ac.decision(_verdict_text(verdicts[u]), unit=u, key="dup") for u in listed]
    st = d["stats"]
    cands = [f for f in d["families"] if is_candidate(f)]
    intentional = sum(1 for f in cands if verdicts.get(f["id"], {}).get("verdict") == "intentional")
    summary = []
    if d["error"]:
        summary.append(f"**Detection did not run**: {d['error']}")
    else:
        summary.append(
            f"jscpd (min {st['min_tokens']} tokens, comments skipped) found {st['jscpd_clones']} identical runs in "
            f"{', '.join(SCAN_DIRS)} ({st['jscpd_seconds']} s); merged and diffed: {st['families']} clone families, "
            f"{st['candidates']} candidates ({st['divergent']} divergent near-clones).")
        summary.append(f"Triaged this run: {sum(new_counts.values())} "
                       f"({', '.join(f'{v} {k}' for k, v in sorted(new_counts.items())) or 'none'}); "
                       f"waiting for triage: {len(waiting)}; judged intentional: {intentional}.")
        if d.get("skipped"):
            summary.append(f"Claude stage skipped: {d['skipped']}.")
    info = [f"Top divergent near-clone (not yet a decision): {short(f)}"
            for f in [f for f in waiting if f["kind"] == "divergent"][:10]]
    return {"summary": "\n".join(summary), "applied": [], "mechanical": [x["text"] for x in mech],
            "human": human, "info": info, "proposed": []}


# ---------------------------------------------------------------- per-push check

HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")


def parse_hunks(diff_text):
    """{path: {"old": [(start, count)], "new": [(start, count)]}} from `git diff -U0` output."""
    out, cur = {}, None
    for line in diff_text.splitlines():
        if line.startswith("+++ "):
            p = line[4:].strip()
            if p != "/dev/null":   # a deleted file keeps the old path set by its "---" line
                cur = p[2:] if p.startswith("b/") else p
                out.setdefault(cur, {"old": [], "new": []})
        elif line.startswith("--- "):
            p = line[4:].strip()
            if p != "/dev/null":
                old_path = p[2:] if p.startswith("a/") else p
                out.setdefault(old_path, {"old": [], "new": []})
                cur = old_path
        elif cur is not None and line.startswith("@@"):
            m = HUNK.match(line)
            if m:
                o, oc, n, nc = m.group(1), m.group(2), m.group(3), m.group(4)
                out[cur]["old"].append((int(o), 1 if oc is None else int(oc)))
                out[cur]["new"].append((int(n), 1 if nc is None else int(nc)))
    return out


def touches(ranges, start, end):
    """Does a list of (start, count) diff ranges touch lines start..end? A pure insertion
    (count 0, after line s) touches the region when it lands inside it."""
    for s, c in ranges:
        if c == 0:
            if start <= s < end:
                return True
        elif s <= end and s + c - 1 >= start:
            return True
    return False


def _line_set(lines, s, e):
    return {l for l in lines[s - 1:e] if nontrivial(l)}


def new_clones(head_fams, base_fams, hunks, head_lines, base_lines, dismissed=frozenset()):
    """Candidate families at head that this change created: one region is mostly (at least half of
    its non-trivial lines) lines the change added, and no base family pairs the same two files over
    the same code (half or more of the smaller region's lines in common on both sides).
    head_lines/base_lines: {path: code_lines}."""
    out = []
    base_ids = {f["id"] for f in base_fams}
    for f in head_fams:
        if not is_candidate(f) or f["id"] in base_ids or decision_id_of(f["id"]) in dismissed:
            continue
        added = False
        for s in ("a", "b"):
            p, lo, hi = f[s]
            lines = head_lines.get(p, [])
            real = [n for n in range(lo, hi + 1) if n <= len(lines) and nontrivial(lines[n - 1])]
            new = [n for n in real if touches(hunks.get(p, {}).get("new", []), n, n)]
            if real and len(new) * 2 >= len(real):
                added = True
        if not added:
            continue
        ha = _line_set(head_lines.get(f["a"][0], []), f["a"][1], f["a"][2])
        hb = _line_set(head_lines.get(f["b"][0], []), f["b"][1], f["b"][2])
        known = False
        for g in base_fams:
            if (g["a"][0], g["b"][0]) != (f["a"][0], f["b"][0]):
                continue
            ga = _line_set(base_lines.get(g["a"][0], []), g["a"][1], g["a"][2])
            gb = _line_set(base_lines.get(g["b"][0], []), g["b"][1], g["b"][2])
            if _overlap(ha, ga) >= 0.5 and _overlap(hb, gb) >= 0.5:
                known = True
                break
        if not known:
            out.append(f)
    return out


def _overlap(x, y):
    """Share of the smaller set that is in the other."""
    return len(x & y) / min(len(x), len(y)) if x and y else 0.0


def new_divergences(base_fams, hunks, significant, head_exists, dismissed=frozenset()):
    """Base candidate families where the change edits one region and leaves the other untouched.
    hunks: parse_hunks() of base..head; significant: paths whose change is more than comments and
    whitespace; head_exists(path): False for a file the change deletes (removing a copy is not drift)."""
    out = []
    for f in base_fams:
        if not is_candidate(f) or decision_id_of(f["id"]) in dismissed:
            continue
        pa, pb = f["a"][0], f["b"][0]
        if not (head_exists(pa) and head_exists(pb)):
            continue
        ta = pa in significant and touches(hunks.get(pa, {}).get("old", []), f["a"][1], f["a"][2])
        tb = pb in significant and touches(hunks.get(pb, {}).get("old", []), f["b"][1], f["b"][2])
        if ta != tb:
            out.append({**f, "edited": "a" if ta else "b"})
    return out


def _git(repo, *args):
    r = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout


def export_tree(repo, rev, dest):
    """The SCAN_DIRS of `rev` written under dest (git archive, no checkout)."""
    present = [d for d in SCAN_DIRS if _git(repo, "ls-tree", "-d", "--name-only", rev, d).strip()]
    if not present:
        return
    arch = subprocess.run(["git", "-C", str(repo), "archive", rev, *present], capture_output=True, check=True)
    subprocess.run(["tar", "-x", "-C", str(dest)], input=arch.stdout, check=True)


def push_check(repo, base, head="HEAD", jscpd=None, dismissed=None):
    """Everything the per-push check reports, as a dict."""
    t0 = time.monotonic()
    repo = Path(repo).resolve()
    sys.path.insert(0, str(repo / "scripts"))
    import significant_changes as sc
    specs = [f":(glob){d}/**" for d in SCAN_DIRS]
    significant = set(sc.significant_changes(str(repo), base, head, specs))
    dismissed = ac.dismissed_decisions(repo) if dismissed is None else dismissed
    res = {"base": base, "head": head, "significant": sorted(significant), "new_clones": [], "new_divergences": []}
    if not significant:
        res["seconds"] = round(time.monotonic() - t0, 2)
        return res
    hunks = parse_hunks(_git(repo, "diff", "-U0", "--no-renames", base, head, "--", *sorted(significant)))
    with tempfile.TemporaryDirectory() as tb, tempfile.TemporaryDirectory() as th:
        export_tree(repo, base, tb)
        export_tree(repo, head, th)
        base_fams = families(tb, run_jscpd(tb, jscpd=jscpd))
        head_fams = families(th, run_jscpd(th, jscpd=jscpd))

        def all_lines(root, fams):
            out = {}
            for f in fams:
                for s in ("a", "b"):
                    p = f[s][0]
                    if p not in out:
                        out[p] = code_lines(p, (Path(root) / p).read_text(encoding="utf-8", errors="replace"))
            return out

        res["new_clones"] = new_clones(head_fams, base_fams, hunks, all_lines(th, head_fams),
                                       all_lines(tb, base_fams), dismissed)
        res["new_divergences"] = new_divergences(base_fams, hunks, significant,
                                                 lambda p: (Path(th) / p).exists(), dismissed)
    res["seconds"] = round(time.monotonic() - t0, 2)
    return res


MARKER = "<!-- code-duplication-check -->"


def render_push(res, blocking=False):
    md = [MARKER, "## Code duplication check", ""]
    nc, nd = res["new_clones"], res["new_divergences"]
    if not res["significant"]:
        md.append("No R, C++ or Python code changed (comment- and whitespace-only edits do not count).")
    elif not nc and not nd:
        md.append(f"No new clones and no new divergences in the {len(res['significant'])} changed source file(s).")
    if nd:
        md += [f"### Edits to one copy of a duplicated region ({len(nd)})", "",
               "The change edits one region of a known clone pair and leaves the other alone. If the edit is a "
               "fix, the other copy probably needs it too (the v1.0.6-TODO-117 / -121 pattern). Line numbers are "
               "the base's.", ""]
        for f in nd:
            e, o = f["edited"], "b" if f["edited"] == "a" else "a"
            md.append(f"- edited `{loc(f, e)}`, not its copy `{loc(f, o)}` ({f['shared']} shared lines) "
                      f"<sub>`{decision_id_of(f['id'])}`</sub>")
        md.append("")
    if nc:
        md += [f"### New duplicated code ({len(nc)})", "",
               "Code this change adds that repeats code already in the tree. Consider a shared helper.", ""]
        for f in nc:
            md.append(f"- {short(f)} <sub>`{decision_id_of(f['id'])}`</sub>")
        md.append("")
    md += ["", "Not a review verdict, only a mechanical signal (jscpd, comments ignored). To silence an item for good, "
           f"list its `code-duplication-d<hex>` id in `{ac.DISMISSED_FILE}` with a reason."
           + (" This check is **blocking** on new divergences." if blocking else " This check does not block."),
           f"<sub>{res.get('seconds', '?')} s; base `{str(res['base'])[:12]}`.</sub>"]
    return "\n".join(md) + "\n"


# ---------------------------------------------------------------- CLI

def _scan_cli(a):
    fams, stats = detect(a.repo, min_tokens=a.min_tokens)
    cands = [f for f in fams if is_candidate(f)]
    div = [f for f in cands if f["kind"] == "divergent"]
    if a.json:
        print(json.dumps({"stats": stats, "candidates": cands}, indent=1))
        return 0
    print(json.dumps(stats))
    for f in div[:a.top]:
        print(f"{f['score']:7.2f}  {f['id']}  {short(f)}")
        if a.diff:
            print("    " + unified(f, 30).replace("\n", "\n    "))
    return 0


def _push_cli(a):
    res = push_check(a.repo, a.base, a.head)
    md = render_push(res, a.fail_on_divergence)
    if a.out:
        Path(a.out).write_text(md)
    else:
        print(md)
    if a.github_output:
        with open(a.github_output, "a") as fh:
            fh.write(f"new_clones={len(res['new_clones'])}\nnew_divergences={len(res['new_divergences'])}\n")
    if a.json_out:
        Path(a.json_out).write_text(json.dumps(res, indent=1, default=str))
    return 3 if a.fail_on_divergence and res["new_divergences"] else 0   # 3: the workflow's blocking switch


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("scan", help="detect and list the top divergent near-clones")
    s.add_argument("--repo", default=".")
    s.add_argument("--min-tokens", type=int, default=MIN_TOKENS)
    s.add_argument("--top", type=int, default=15)
    s.add_argument("--diff", action="store_true")
    s.add_argument("--json", action="store_true")
    p = sub.add_parser("push", help="per-push check: new clones and new divergences since base")
    p.add_argument("--repo", default=".")
    p.add_argument("--base", required=True)
    p.add_argument("--head", default="HEAD")
    p.add_argument("--out")
    p.add_argument("--json-out")
    p.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT"))
    p.add_argument("--fail-on-divergence", action="store_true")
    a = ap.parse_args(argv)
    return {"scan": _scan_cli, "push": _push_cli}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
