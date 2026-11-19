#!/usr/bin/env python3
"""Benchmark stage for algorithm-research findings (Phase 0; owner, 2026-11-17).

Plan: R/package_metadata/new_feature_plans/v1_0_6/algorithm_research_bench_stage.md.
Workflow: .github/workflows/algorithm-research-bench.yml (dispatched by hand in Phase 0).

A research finding says a candidate is faster than what EDI does today. Its bench spec (one JSON
file, written by an agent that cannot run code) gives `setup` (defines bench_setup()),
`current` and `candidate` (each defines bench_run(d)), the CRAN `packages` it needs, and the D2
`tier` / `tol` the two results must agree under. Both sides run against the SAME EDI build, so
A = current and B = candidate. The timing, the result comparison and the statistics are the
compiled-code audit's, imported from compiled_code_verify.py, not copied:
run_once (compiled_code_bench.R in a fresh process), abba_order, block_diffs, summarize and
compare_results.

  plan    --specs DIR                 matrix of benchmarkable specs (GitHub output)
  bench   --spec F --lib L --work W --out V   equal results?, then ABBA timing -> verdict JSON
  report  --specs DIR --verdicts DIR --out MD  the result table

Verdicts: faster | not_faster | faster_not_equivalent | not_benchmarked.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import compiled_code_verify as cv  # noqa: E402

MIN_GAIN = 0.05  # owner 2026-11-19: "faster" needs >= 5% at the interval's upper end; "not faster" is a reject
TIERS = {"exact": 0.0, "closed_form": cv.FLOAT_TIER}
REQUIRED = ("finding_id", "setup", "current", "candidate", "tier")


def key(finding_id):
    """A file / artifact / job-name safe key: 'cox-ph-fit#43925959437.3' -> 'cox-ph-fit--43925959437-3'."""
    return re.sub(r"[^A-Za-z0-9_-]", "-", finding_id.replace("#", "--"))


def load_specs(folder):
    out = []
    for f in sorted(Path(folder).glob("*.json")):
        try:
            s = json.loads(f.read_text())
        except ValueError as e:
            out.append({"finding_id": f.stem, "_error": f"spec is not valid JSON ({e})"})
            continue
        out.append(s)
    return out


def spec_problem(s):
    """'' if the spec can be run, else why not."""
    if s.get("_error"):
        return s["_error"]
    if not s.get("benchmarkable", True):
        return "not benchmarkable without editing EDI: " + (s.get("why_not") or "no reason given")
    miss = [k for k in REQUIRED if not str(s.get(k) or "").strip()]
    if miss:
        return "spec is missing " + ", ".join(miss)
    if s["tier"] not in TIERS and s["tier"] != "iterative":
        return f"unknown tier {s['tier']!r}"
    if s["tier"] == "iterative" and not isinstance(s.get("tol"), (int, float)):
        return "tier iterative needs a numeric tol"
    if any(not re.fullmatch(r"[A-Za-z][A-Za-z0-9.]*", p) for p in s.get("packages") or []):
        return "packages must be bare CRAN package names"
    return ""


def tolerance(s):
    return float(s["tol"]) if s["tier"] == "iterative" else TIERS[s["tier"]]


def cmd_plan(a):
    specs = load_specs(a.specs)
    runnable = [s for s in specs if not spec_problem(s)]
    matrix = [{"key": key(s["finding_id"]), "finding_id": s["finding_id"],
               "packages": ", ".join(["any::jsonlite"] + [f"any::{p}" for p in s.get("packages") or []])}
              for s in runnable]
    cv.out(a.github_output, has="true" if matrix else "false", matrix=json.dumps(matrix))
    print(f"{len(matrix)} of {len(specs)} spec(s) runnable")
    for s in specs:
        if spec_problem(s):
            print(f"  skip {s.get('finding_id')}: {spec_problem(s)}")
    return 0


def classify(v, min_gain=MIN_GAIN):
    """Verdict dict -> (verdict, reason), from the agreement check and the ABBA summary."""
    if v.get("error"):
        return "not_benchmarked", v["error"]
    s = v.get("timing")
    if not s:
        return "not_benchmarked", "no complete ABBA block"
    pct = lambda r: f"{(1 - r) * 100:+.1f}%"
    span = f"{pct(s['ratio'])} faster (95% interval {pct(s['hi'])} to {pct(s['lo'])})"
    fast = s["hi"] <= 1 - min_gain
    if not v.get("equal"):
        if fast:
            return "faster_not_equivalent", f"{span}; results differ: {v.get('equal_detail', '')}"
        return "not_faster", f"{span}; results also differ: {v.get('equal_detail', '')}"
    if fast:
        return "faster", span
    return "not_faster", (f"needs {min_gain:.0%} at the interval's upper end: " if s["lo"] < 1 else "slower: ") + span


def cmd_bench(a):
    s = json.loads(Path(a.spec).read_text())
    work = Path(a.work)
    work.mkdir(parents=True, exist_ok=True)
    v = {"finding_id": s.get("finding_id"), "kind": s.get("kind"), "tier": s.get("tier"),
         "tol": s.get("tol"), "packages": s.get("packages") or []}
    code = {"A": work / "current.R", "B": work / "candidate.R"}
    try:
        why = spec_problem(s)
        if why:
            raise RuntimeError(why)
        code["A"].write_text(s["setup"] + "\n\n" + s["current"] + "\n")
        code["B"].write_text(s["setup"] + "\n\n" + s["candidate"] + "\n")
        for x, side in (("A", "current"), ("B", "candidate")):
            try:
                cv.run_once(a.lib, str(code[x]), str(work / f"{x}.json"), str(work / f"{x}.rds"),
                            timeout=a.timeout)
            except (RuntimeError, subprocess.TimeoutExpired) as e:
                raise RuntimeError(f"the {side} side fails: {e}") from None
        v["equal"], v["equal_detail"] = cv.compare_results(str(work / "A.rds"), str(work / "B.rds"),
                                                            tol=tolerance(s))
        # Timed even when the results differ: "faster but not equivalent" is an estimator change
        # for triage, not a reject.
        times = {}
        for k, (b, x) in enumerate(cv.abba_order(a.blocks)):
            t = cv.run_once(a.lib, str(code[x]), str(work / f"t{k}.json"), timeout=a.timeout)
            times.setdefault(b, {}).setdefault(x, []).append(t)
        v["times"] = {str(b): t for b, t in times.items()}
        v["timing"] = cv.summarize(cv.block_diffs(times))
    except (RuntimeError, subprocess.TimeoutExpired) as e:
        v["error"] = str(e)[:800]
    v["verdict"], v["reason"] = classify(v, a.min_gain)
    Path(a.out).write_text(json.dumps(v, indent=1))
    print(json.dumps({k: v.get(k) for k in ("finding_id", "verdict", "reason")}))
    return 0


def render(specs, verdicts, run_url=""):
    by = {v.get("finding_id"): v for v in verdicts}
    rows, counts = [], {}
    for s in specs:
        fid = s.get("finding_id")
        v = by.get(fid)
        if spec_problem(s):
            verdict, reason, ratio = "not_benchmarked", spec_problem(s), ""
        elif v is None:
            verdict, reason, ratio = "not_benchmarked", "no verdict (the bench job failed; see the run)", ""
        else:
            verdict, reason = v["verdict"], v["reason"]
            t = v.get("timing") or {}
            ratio = f"{t['ratio']:.3g}" if t else ""
        counts[verdict] = counts.get(verdict, 0) + 1
        rows.append(f"| `{fid}` | {s.get('kind', '')} | **{verdict}** | {ratio} | "
                    f"{reason.replace('|', '/').replace(chr(10), ' ')[:300]} |")
    head = ["# Algorithm research bench (Phase 0)", "",
            f"{len(specs)} specs: " + ", ".join(f"{n} {k}" for k, n in sorted(counts.items())) + ".",
            f"Both sides run on one EDI build; A = current, B = candidate; {cv.BLOCKS} ABBA blocks by "
            f"default; ratio = candidate time / current time (median block); \"faster\" needs the 95% "
            f"interval's upper end at least {MIN_GAIN:.0%} below 1." + (f" Run: {run_url}" if run_url else ""),
            "", "| finding | kind | verdict | ratio | reason |", "|---|---|---|---|---|"]
    return "\n".join(head + rows) + "\n", counts


def cmd_report(a):
    specs = load_specs(a.specs)
    verdicts = []
    for f in sorted(Path(a.verdicts).rglob("*.json")):
        try:
            verdicts.append(json.loads(f.read_text()))
        except ValueError:
            pass
    text, counts = render(specs, verdicts, a.run_url)
    Path(a.out).write_text(text)
    print(text)
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("plan")
    s.add_argument("--specs", required=True)
    s.add_argument("--github-output", default=None)
    s = sub.add_parser("bench")
    s.add_argument("--spec", required=True)
    s.add_argument("--lib", required=True)
    s.add_argument("--work", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("--blocks", type=int, default=cv.BLOCKS)
    s.add_argument("--min-gain", type=float, default=MIN_GAIN)
    s.add_argument("--timeout", type=int, default=900)
    s = sub.add_parser("report")
    s.add_argument("--specs", required=True)
    s.add_argument("--verdicts", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("--run-url", default="")
    a = ap.parse_args(argv)
    return {"plan": cmd_plan, "bench": cmd_bench, "report": cmd_report}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
