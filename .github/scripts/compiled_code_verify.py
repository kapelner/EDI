#!/usr/bin/env python3
"""Benchmark check for the compiled-code audit's proposals (stage 4).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 5). Workflow:
the verify-* jobs in .github/workflows/audit-compiled-code.yml, run after the audit's finish job.

The audit's finish job applies every clean proposal to a draft PR (branch audit/compiled-code)
and uploads `followup/proposals.json`. Then, on GitHub's runners only (no Claude):

  plan    which builds to make: the run's commit ("base") and, per proposal, that commit plus
          only that proposal ("p1", "p2", ...).
  patch   apply one or more proposals to a checkout (exact text replacement, once each).
  build   (workflow) R CMD INSTALL each build into its own library; the proposal builds also
          run the tests related to the changed file (select_pr_coverage_tests.py) under D2.
  bench   for one proposal: the proposal's bench code (bench_setup / bench_run, written by the
          agent) runs on base and on the proposal's build. Results must agree under the D2
          closed-form tier (integers, logicals and strings exact; doubles within
          1e-10 * max(1, |base|)). Then BLOCKS blocks of four fresh processes, A B B A, on one
          runner; each block gives log(B) - log(A) from the means of its two A and two B
          per-call medians, which cancels a linear drift in runner speed within the block.
          The estimate is the median block difference; its 95% interval is a seeded bootstrap.
  report  keep a proposal only if its tests passed, its results agree and the upper end of the
          interval is at least MIN_GAIN faster than base. The PR branch is rebuilt from the
          run's commit with the kept proposals only, the result table goes into the PR body,
          and the PR is marked ready; with nothing kept the PR is closed, which the next audit
          run's harvest records as rejected (so the agent does not propose it again).
"""
import argparse
import json
import math
import os
import random
import statistics
import subprocess
import sys
from pathlib import Path

BLOCKS = 20             # ABBA blocks per proposal (80 timed processes)
MIN_GAIN = 0.02         # keep only if the 95% upper bound is at least 2% faster
BOOT = 4000
SEED = 20261117
FLOAT_TIER = 1e-10      # D2 closed-form tier
HERE = Path(__file__).resolve().parent
BENCH_R = HERE / "compiled_code_bench.R"
BOT_NAME = "github-actions[bot]"
BOT_EMAIL = "41898282+github-actions[bot]@users.noreply.github.com"
BRANCH = "audit/compiled-code"


def out(path, **kv):
    if not path:
        return
    with open(path, "a") as fh:
        for k, v in kv.items():
            fh.write(f"{k}={v}\n")


def load_proposals(path):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return []


# ---------------------------------------------------------------- plan / patch

def cmd_plan(a):
    props = load_proposals(Path(a.followup) / "proposals.json")
    ids = [p["id"] for p in props]
    out(a.github_output, has="true" if ids else "false", builds=json.dumps(["base"] + ids),
        proposals=json.dumps(ids))
    print(f"{len(ids)} proposal(s): {', '.join(ids) or 'none'}")
    return 0


def apply_proposals(repo, props):
    """Apply proposals in order; returns [(id, error or None)]. A proposal whose old code does
    not occur exactly once (after the earlier ones) is skipped."""
    res = []
    for p in props:
        f = Path(repo) / p["file"]
        try:
            text = f.read_text()
        except OSError:
            res.append((p["id"], f"{p['file']} does not exist"))
            continue
        n = text.count(p["old_code"]) if p.get("old_code") else 0
        if n != 1:
            res.append((p["id"], f"the old code occurs {n} times in {p['file']}"))
            continue
        f.write_text(text.replace(p["old_code"], p["new_code"], 1))
        res.append((p["id"], None))
    return res


def cmd_patch(a):
    props = {p["id"]: p for p in load_proposals(a.proposals)}
    want = [props[i] for i in a.ids.split(",") if i in props]
    bad = [(i, e) for i, e in apply_proposals(a.repo, want) if e]
    for i, e in bad:
        print(f"{i}: {e}", file=sys.stderr)
    return 1 if bad else 0


# ---------------------------------------------------------------- bench

def abba_order(blocks):
    """[(block, build)] in run order: A B B A per block."""
    return [(b, x) for b in range(blocks) for x in ("A", "B", "B", "A")]


def block_diffs(times):
    """times: {block: {"A": [t, t], "B": [t, t]}} -> [log(mean B) - log(mean A)] per complete block."""
    d = []
    for b in sorted(times):
        A, B = times[b].get("A", []), times[b].get("B", [])
        if len(A) == 2 and len(B) == 2 and min(A + B) > 0:
            d.append(math.log(sum(B) / 2) - math.log(sum(A) / 2))
    return d


def summarize(diffs, boot=BOOT, seed=SEED):
    """Median block difference and its 95% bootstrap interval, as time ratios new/base."""
    if not diffs:
        return None
    rng = random.Random(seed)
    meds = sorted(statistics.median(rng.choices(diffs, k=len(diffs))) for _ in range(boot))
    lo, hi = meds[int(0.025 * boot)], meds[min(boot - 1, int(0.975 * boot))]
    return {"ratio": math.exp(statistics.median(diffs)), "lo": math.exp(lo), "hi": math.exp(hi),
            "blocks": len(diffs)}


def decide(v):
    """Verdict dict -> (keep, reason)."""
    if v.get("error"):
        return False, v["error"]
    t = v.get("tests", {})
    if t.get("status") == "fail":
        return False, "related tests failed: " + ", ".join(t.get("failed", [])[:5])
    if t.get("status") not in ("pass", "none"):
        return False, "the related tests did not run"
    if not v.get("equal"):
        return False, "results changed: " + v.get("equal_detail", "not equal under D2")
    s = v.get("timing")
    if not s:
        return False, "no complete ABBA block"
    pct = lambda r: f"{(1 - r) * 100:+.1f}%"
    span = f"{pct(s['ratio'])} faster (95% interval {pct(s['hi'])} to {pct(s['lo'])})"
    if s["hi"] <= 1 - MIN_GAIN:
        return True, span
    if s["lo"] >= 1:
        return False, "slower: " + span
    return False, f"not clearly faster (needs {MIN_GAIN:.0%} at the interval's upper end): " + span


COMPARE_R = r"""
a = readRDS(commandArgs(TRUE)[1]); b = readRDS(commandArgs(TRUE)[2]); tol = as.numeric(commandArgs(TRUE)[3])
worst = 0; msg = character()
walk = function(x, y, path) {
	if (!identical(class(x), class(y)) || length(x) != length(y)) { msg <<- c(msg, paste0(path, ": type or length differs")); return() }
	if (is.list(x)) { for (i in seq_along(x)) walk(x[[i]], y[[i]], paste0(path, "[[", i, "]]")); return() }
	if (is.environment(x) || is.function(x)) return()
	if (is.double(x) || is.complex(x)) {
		fx = is.finite(x); fy = is.finite(y)
		if (!identical(fx, fy) || !identical(x[!fx], y[!fy])) { msg <<- c(msg, paste0(path, ": non-finite values differ")); return() }
		r = abs(x[fx] - y[fy]) / pmax(1, abs(x[fx]))
		if (length(r)) worst <<- max(worst, r)
		if (length(r) && max(r) > tol) msg <<- c(msg, sprintf("%s: moved by %.3g (relative)", path, max(r)))
	} else if (!identical(unclass(x), unclass(y))) msg <<- c(msg, paste0(path, ": differs (must be exact)"))
}
invisible(walk(a, b, "result"))
cat(if (length(msg)) paste(head(msg, 3), collapse = "; ") else sprintf("OK %.3g", worst))
"""


def compare_results(a_rds, b_rds, tol=FLOAT_TIER):
    r = subprocess.run(["Rscript", "-e", COMPARE_R, a_rds, b_rds, str(tol)], capture_output=True, text=True,
                       timeout=600)
    txt = (r.stdout or "").strip() or (r.stderr or "").strip()[-300:]
    return (r.returncode == 0 and txt.startswith("OK")), txt


def run_once(lib, code, outj, rds=None, timeout=900):
    cmd = ["Rscript", str(BENCH_R), lib, code, outj] + ([rds] if rds else [])
    env = {**os.environ, "OMP_NUM_THREADS": "1", "OPENBLAS_NUM_THREADS": "1", "MKL_NUM_THREADS": "1"}
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)
    if r.returncode:
        raise RuntimeError((r.stderr or r.stdout or "").strip()[-600:])
    return json.loads(Path(outj).read_text())["per_call"]


def cmd_bench(a):
    props = {p["id"]: p for p in load_proposals(a.proposals)}
    p = props[a.id]
    work = Path(a.work)
    work.mkdir(parents=True, exist_ok=True)
    v = {"id": a.id, "unit": p.get("unit"), "finding_id": p.get("finding_id")}
    try:
        v["tests"] = json.loads(Path(a.tests).read_text())
    except (OSError, ValueError):
        v["tests"] = {"status": "missing"}
    code = work / "bench.R"
    code.write_text(p.get("bench_code") or "")
    libs = {"A": a.base_lib, "B": a.new_lib}
    try:
        if not (p.get("bench_code") or "").strip():
            raise RuntimeError("the proposal has no bench code")
        if not Path(libs["B"]).is_dir():
            raise RuntimeError("the build with the change failed (see the verify-build job)")
        try:
            run_once(libs["A"], str(code), str(work / "a.json"), str(work / "a.rds"))
        except RuntimeError as e:
            raise RuntimeError(f"the bench code fails on base: {e}") from None
        try:
            run_once(libs["B"], str(code), str(work / "b.json"), str(work / "b.rds"))
        except RuntimeError as e:
            raise RuntimeError(f"the bench code fails with the change: {e}") from None
        v["equal"], v["equal_detail"] = compare_results(str(work / "a.rds"), str(work / "b.rds"))
        times = {}
        if v["equal"]:
            for k, (b, x) in enumerate(abba_order(a.blocks)):
                t = run_once(libs[x], str(code), str(work / f"t{k}.json"))
                times.setdefault(b, {}).setdefault(x, []).append(t)
        v["times"] = {str(b): t for b, t in times.items()}
        v["timing"] = summarize(block_diffs(times))
    except (RuntimeError, subprocess.TimeoutExpired) as e:
        v["error"] = str(e)[:800]
    v["keep"], v["reason"] = decide(v)
    Path(a.out).write_text(json.dumps(v, indent=1))
    print(json.dumps({k: v.get(k) for k in ("id", "keep", "reason")}))
    return 0


# ---------------------------------------------------------------- report

def render(props, verdicts, run_url=""):
    kept = [p for p in props if verdicts.get(p["id"], {}).get("keep")]
    lines = ["## Compiled-code audit: benchmark check", "",
             f"Each proposal was built on its own on top of the run's commit, its related tests were run, "
             f"its bench code was checked for equal results under the D2 closed-form tier "
             f"(doubles within {FLOAT_TIER:g} relative, everything else exact) and timed in {BLOCKS} "
             f"ABBA blocks against the unchanged build on one runner. A proposal is kept only if the "
             f"upper end of the 95% interval is at least {MIN_GAIN:.0%} faster.", "",
             "| | Function | File | Verdict | Detail |", "|---|---|---|---|---|"]
    for p in props:
        v = verdicts.get(p["id"], {"reason": "no verdict (the bench job did not finish)"})
        fn = (p.get("function") or p.get("unit") or "").replace("|", "\\|")[:80]
        lines.append(f"| {p['id']} | `{fn}` | `{p.get('file', '')}` | "
                     f"{'kept' if v.get('keep') else 'dropped'} | {v.get('reason', '').replace('|', '/')} |")
    lines += ["", f"{len(kept)} of {len(props)} kept."]
    if kept:
        lines += ["", "### Kept changes", ""]
        for p in kept:
            lines += [f"- **{p['id']}** `{p.get('file')}`: {p.get('text', '').strip()}",
                      f"  - Removes: {p.get('removes', '')}. Risk to results: {p.get('risk_to_results', '')}"]
    if run_url:
        lines += ["", f"Run: {run_url}"]
    return "\n".join(lines) + "\n", kept


def gh(*args, check=True):
    r = subprocess.run(["gh", *args], capture_output=True, text=True)
    if check and r.returncode:
        raise RuntimeError(f"gh {' '.join(args[:3])}: {r.stderr.strip()}")
    return r.stdout.strip()


def cmd_report(a):
    props = load_proposals(a.proposals)
    verdicts = {}
    for f in Path(a.verdicts).glob("**/verdict-*.json"):
        try:
            v = json.loads(f.read_text())
            verdicts[v["id"]] = v
        except (OSError, ValueError, KeyError):
            continue
    run_url = os.environ.get("GITHUB_SERVER_URL", "") and (
        f"{os.environ['GITHUB_SERVER_URL']}/{os.environ.get('GITHUB_REPOSITORY')}/actions/runs/"
        f"{os.environ.get('GITHUB_RUN_ID')}")
    body, kept = render(props, verdicts, run_url)
    Path(a.out).write_text(body)
    if not a.publish:
        print(body)
        return 0
    pr = gh("pr", "list", "--head", BRANCH, "--state", "open", "--json", "number", "--jq",
            ".[0].number // empty", check=False)
    if not pr:
        print("no open PR for the branch; the result is in the job summary only")
        return 0
    authors = gh("pr", "view", pr, "--json", "commits", "--jq",
                 "[.commits[].authors[].login] | unique | join(\",\")", check=False)
    humans = [x for x in authors.split(",") if x and x not in ("github-actions", "github-actions[bot]",
                                                               "app/github-actions")]
    if humans:
        gh("pr", "comment", pr, "--body", body + "\nThe branch has commits by " + ", ".join(humans)
           + ", so it was not rewritten.")
        return 0
    if not kept:
        gh("pr", "comment", pr, "--body", body)
        gh("pr", "close", pr)
        print(f"PR #{pr} closed: nothing kept")
        return 0
    g = lambda *x: subprocess.run(["git", *x], cwd=a.repo, check=True, capture_output=True, text=True)
    g("config", "user.name", BOT_NAME)
    g("config", "user.email", BOT_EMAIL)
    g("switch", "-C", BRANCH, a.sha)
    bad = [e for _, e in apply_proposals(a.repo, kept) if e]
    if bad:
        raise RuntimeError("kept proposals no longer apply together: " + "; ".join(bad))
    g("add", "-A")
    g("commit", "-qm", f"Compiled-code audit: {len(kept)} benchmarked change(s)\n\n{run_url}")
    g("push", "--force", "origin", f"{BRANCH}:{BRANCH}")
    old = gh("pr", "view", pr, "--json", "body", "--jq", ".body", check=False)
    gh("pr", "edit", pr, "--body", (body + "\n---\n\n" + old)[:60000])
    gh("pr", "ready", pr, check=False)
    print(f"PR #{pr}: {len(kept)} of {len(props)} kept, marked ready")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("plan")
    s.add_argument("--followup", required=True)
    s.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT"))
    s = sub.add_parser("patch")
    s.add_argument("--proposals", required=True)
    s.add_argument("--ids", required=True)
    s.add_argument("--repo", required=True)
    s = sub.add_parser("bench")
    s.add_argument("--proposals", required=True)
    s.add_argument("--id", required=True)
    s.add_argument("--base-lib", required=True)
    s.add_argument("--new-lib", required=True)
    s.add_argument("--tests", required=True)
    s.add_argument("--work", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("--blocks", type=int, default=BLOCKS)
    s = sub.add_parser("report")
    s.add_argument("--proposals", required=True)
    s.add_argument("--verdicts", required=True)
    s.add_argument("--repo", required=True)
    s.add_argument("--sha", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("--publish", action="store_true")
    a = ap.parse_args(argv)
    return {"plan": cmd_plan, "patch": cmd_patch, "bench": cmd_bench, "report": cmd_report}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
