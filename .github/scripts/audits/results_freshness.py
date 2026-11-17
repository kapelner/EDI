"""Results freshness: result rows generated before the class or kernel behind them last changed.

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4, "Results
freshness"). No Claude; reports with one issue, because regenerating results is a campaign, not an edit.

Sources and how each row's generation commit is known:

- The committed comprehensive-test aggregates (`R/package_tests/comprehensive_tests_{size,power,
  coverage,mse}.csv`, `comprehensive_coverage_attempt_summary.csv`) carry no commit or date per row,
  so the file's own last commit stands in for every row (the report says so). The raw per-row files
  that do carry `github_commit_id` (`comprehensive_tests_results_nc_*.csv`) are gitignored and are
  not on the runner.
- The calibration study: the latest campaign on the `calibration-results` branch,
  `campaigns/<id>/summary/calibration_summary.csv`, generated at the `SHA` in its `campaign.env`.

A row group is (results file, class). It is stale when a file it depends on has a functional change
(benchmark_gate.is_functional_change: not only blank or comment lines) between its generation
commit and HEAD. Dependencies, from benchmark_gate.r_targets (imported, not copied):

- class-specific: the class's own R file and the files of the classes it inherits from;
- family-wide: any other file under R/EDI/R or R/EDI/src whose benchmark targets include the class's
  response family (`models-<family>` / `wald-<family>`), except family-specific `inference_<family>_*.R`
  files of other classes, and except build files (DESCRIPTION, NAMESPACE, Makevars, configure).
"""
import contextlib
import csv
import io
import os
import re
import subprocess

import audit_common as ac
import benchmark_gate as bg
from audits import todo_status as ts

SPEC = {
    "name": "results-freshness",
    "title": "Results freshness",
    "report": "issue",
    "claude": False,
}

PT = "R/package_tests"
AGGREGATES = {
    f"{PT}/comprehensive_tests_size.csv": "inference_class",
    f"{PT}/comprehensive_tests_power.csv": "inference_class",
    f"{PT}/comprehensive_tests_coverage.csv": "inference_class",
    f"{PT}/comprehensive_tests_mse.csv": "inference_class",
    f"{PT}/comprehensive_coverage_attempt_summary.csv": "class",
}
CAL_BRANCH = "origin/calibration-results"
CAL_SUMMARY = "summary/calibration_summary.csv"
CODE = ("R/EDI/R/", "R/EDI/src/")
MAX_LIST = 8

# Regeneration commands, as the repository documents them.
COMPREHENSIVE_CMD = ("(from `R/`) `Rscript package_tests/comprehensive_tests.R <nrep> <ncores> {rt} NA '^{cls}' NA NA NA NA` "
                     "(usage: `R/package_metadata/contracts/new_model_creation.md`; argument 5 is a class regex), "
                     "then `Rscript package_tests/analyze_comprehensive_tests.R` for the size/power/coverage/mse "
                     "files and `Rscript R/package_tests/audit_comprehensive_results.R --force` for the attempt summary")
CAL_CLASS_CMD = ("`Rscript R/package_tests/calibration/run_calibration_study.R --response-type {rt} --design <design> "
                 "--n <n> --effect null --reps <reps> --out-dir DIR --only {cls}` (usage: "
                 "`R/package_tests/calibration/run_calibration_study.R` header), per stale cell")
CAL_FAMILY_CMD = ("a new campaign: run `.github/workflows/calibration-study.yml` by hand with `campaign` blank (a new "
                  "campaign at this commit) and `response_types={rt}`")


@contextlib.contextmanager
def in_dir(path):
    old = os.getcwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(old)


def _git(repo, *args):
    r = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


INHERIT = re.compile(r"\binherit\s*=\s*([A-Z]\w+)")


def class_tree(repo):
    """name -> (file, parent or None) for classes defined in R/EDI/R."""
    out = {}
    for f in ts.tracked(repo, "R/EDI/R/*.R"):
        try:
            text = (repo / f).read_text(errors="replace")
        except OSError:
            continue
        for m in ts.CLASS_DEF.finditer(text):
            name = m.group(1) or m.group(2) or m.group(3)
            if name in out:
                continue
            p = INHERIT.search(text[m.end():m.end() + 600])
            out[name] = (f, p.group(1) if p else None)
    return out


def chain_files(tree, cls):
    files, seen = [], set()
    while cls and cls in tree and cls not in seen:
        seen.add(cls)
        f, cls = tree[cls]
        if f not in files:
            files.append(f)
    return files


def resolve_class(tree, raw):
    name = (raw or "").strip().split(" ")[0]
    if name in tree:
        return name
    if "Inference" + name in tree:
        return "Inference" + name
    return name or None


def family_of(rt):
    rt = (rt or "").strip().lower()
    return rt if rt in bg.FAMILIES else None


def changes_since(repo, base):
    """[(path, short sha, date)] of code files with a functional change between base and HEAD."""
    names = _git(repo, "diff", "--name-only", f"{base}..HEAD", "--", *CODE)
    if names is None:
        return None
    out = []
    with in_dir(repo):
        for p in names.split():
            if p in bg.BUILD_FILES:
                continue
            if not (repo / p).exists():
                out.append((p, "deleted", ""))
                continue
            if bg.is_functional_change(base, "HEAD", p):
                last = (_git(repo, "log", "-1", "--format=%h %cs", "--", p) or "").split()
                out.append((p, last[0] if last else "?", last[1] if len(last) > 1 else ""))
    return out


def family_wide(path, family):
    if path.startswith("R/EDI/R/") and os.path.basename(path).startswith("inference_"):
        if bg.inference_file_family(os.path.splitext(os.path.basename(path))[0]):
            return False            # another class's own file
    targets = bg.r_targets(path)
    return bool(targets & {f"models-{family}", f"wald-{family}"})


def groups_from_csv(text, class_col, type_col="response_type"):
    """{(class raw, response type): row count}."""
    out = {}
    for row in csv.DictReader(io.StringIO(text)):
        k = ((row.get(class_col) or "").split(" ")[0], row.get(type_col) or "")
        out[k] = out.get(k, 0) + 1
    return out


def sources(ctx):
    """[(label, generated-at commit, how known, {(class, type): rows}, kind)]."""
    repo = ctx.repo
    out = []
    for rel, col in AGGREGATES.items():
        text = ctx.read(rel)
        if text is None:
            continue
        sha = (_git(repo, "log", "-1", "--format=%H", "--", rel) or "").strip()
        if sha:
            out.append((rel, sha, "the file's last commit (no per-row commit or date)", groups_from_csv(text, col),
                        "comprehensive"))
    listing = _git(repo, "ls-tree", "--name-only", f"{CAL_BRANCH}:campaigns")
    if listing:
        camp = sorted(l for l in listing.split() if l)[-1]
        env = _git(repo, "show", f"{CAL_BRANCH}:campaigns/{camp}/campaign.env") or ""
        m = re.search(r"^SHA=([0-9a-f]{7,40})", env, re.M)
        text = _git(repo, "show", f"{CAL_BRANCH}:campaigns/{camp}/{CAL_SUMMARY}")
        if m and text:
            out.append((f"calibration-results:campaigns/{camp}/{CAL_SUMMARY}", m.group(1),
                        "the campaign's SHA in campaign.env", groups_from_csv(text, "inf_class"), "calibration"))
    return out


def _fmt_files(files):
    shown = [f"`{p}` ({s} {d})".replace(" )", ")") for p, s, d in files[:MAX_LIST]]
    more = len(files) - MAX_LIST
    return ", ".join(shown) + (f" and {more} more" if more > 0 else "")


def mechanical(ctx):
    repo = ctx.repo
    tree = class_tree(repo)
    out = []
    for label, base, how, groups, kind in sources(ctx):
        if _git(repo, "cat-file", "-e", f"{base}^{{commit}}") is None:
            out.append({"unit": label, "kind": "unknown-commit",
                        "text": f"`{label}`: generated at `{base[:10]}`, which is not in this repository's history; "
                                "cannot tell which rows are stale."})
            continue
        changed = changes_since(repo, base) or []
        if not changed:
            continue
        by_family = {}
        for (raw, rt), n in sorted(groups.items()):
            cls, fam = resolve_class(tree, raw), family_of(rt)
            if not cls or not fam:
                continue
            own = set(chain_files(tree, cls))
            mine = [c for c in changed if c[0] in own]
            if mine:
                cmd = (COMPREHENSIVE_CMD if kind == "comprehensive" else CAL_CLASS_CMD).format(rt=rt, cls=cls)
                out.append({"unit": f"{label}::{cls}::{rt}", "kind": "stale-class",
                            "text": f"`{label}` ({n} rows of `{cls}`, {rt}; generated at `{base[:8]}`, {how}): its "
                                    f"class changed since: {_fmt_files(mine)}. Regenerate: {cmd}."})
            wide = [c for c in changed if c[0] not in own and family_wide(c[0], fam)]
            if wide:
                g = by_family.setdefault(fam, {"files": {}, "classes": set(), "rows": 0})
                for c in wide:
                    g["files"][c[0]] = c
                g["classes"].add(cls)
                g["rows"] += n
        for fam, g in sorted(by_family.items()):
            files = sorted(g["files"].values())
            names = sorted(g["classes"])
            cmd = (COMPREHENSIVE_CMD.format(rt=fam, cls=f"Inference({'|'.join(n[len('Inference'):] for n in names)})")
                   if kind == "comprehensive" else CAL_FAMILY_CMD.format(rt=fam))
            listed = ", ".join(f"`{n}`" for n in names[:MAX_LIST]) + (
                f" and {len(names) - MAX_LIST} more" if len(names) > MAX_LIST else "")
            out.append({"unit": f"{label}::family::{fam}", "kind": "stale-family",
                        "text": f"`{label}` ({g['rows']} rows, {len(names)} {fam} classes: {listed}; generated at "
                                f"`{base[:8]}`, {how}): shared {fam} code changed since: {_fmt_files(files)}. "
                                f"Regenerate: {cmd}."})
    return out


def apply(ctx, results, mech):
    n_class = sum(1 for f in mech if f["kind"] == "stale-class")
    n_fam = sum(1 for f in mech if f["kind"] == "stale-family")
    summary = (f"{n_class} class row group(s) whose own class changed, and {n_fam} family group(s) whose shared "
               "code changed, since their rows were generated. A functional change is one that is not only blank "
               "or comment lines; file-to-family rules are `.github/scripts/benchmark_gate.py`'s.")
    return {"summary": summary, "applied": [], "mechanical": [f["text"] for f in mech], "human": [], "proposed": []}
