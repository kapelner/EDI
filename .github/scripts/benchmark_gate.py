#!/usr/bin/env python3
"""Decide which nightly benchmark jobs to run (nightly.yml, change-gate job).

The R benchmarks are split into jobs: one per response family for each of the
models and wald sections, plus utility, procedures and designs. The Python
benchmark is one more job. The benchmark-results branch keeps every job's last
rows and a manifest.json recording the commit each job last timed. Each night
a job runs only when

  * it has no saved rows, or its rows are older than --max-age-days, or
  * its last run's release-vs-current verdict failed (so a regression is
    reported every night until fixed, as before the gating), or
  * a file it depends on has a functional change (not just blank lines or
    comments) between the commit it last timed and HEAD.

Jobs that don't run keep their saved rows, and the report says which parts
were carried over. FILE_RULES below maps a changed file to the jobs it can
affect. A code file that no rule claims reruns every R job, so a missing rule
costs time, never a stale row.

Usage:
  benchmark_gate.py --manifest FILE [--mode auto|all|none] [--max-age-days 14]
                    [--github-output FILE] [--summary FILE]
  benchmark_gate.py --list-jobs     # every R job id, one per line
"""
import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys

# The repo-wide "is this a code change?" rule (comments/whitespace never count).
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, os.pardir, "scripts"))
import significant_changes  # noqa: E402

FAMILIES = ["continuous", "incidence", "count", "proportion", "ordinal", "survival"]
FAMILY_SECTIONS = ["models", "wald"]
R_JOBS = ([f"{sec}-{fam}" for sec in FAMILY_SECTIONS for fam in FAMILIES]
          + ["utility", "procedures", "designs"])
ALL_R = frozenset(R_JOBS)
PYTHON_JOB = "python"

# The families whose classes the procedures section resamples (OLS, logistic,
# exact Fisher/Zhang, Cox) besides the all-responses mean difference.
PROCEDURE_FAMILIES = {"continuous", "incidence", "survival"}


def family_jobs(fams):
    out = {f"{sec}-{fam}" for sec in FAMILY_SECTIONS for fam in fams}
    if set(fams) & PROCEDURE_FAMILIES:
        out.add("procedures")
    return out


# Keywords in a file's base name that tie it to one response family. Ordinal
# is checked first and exclusively (ordinal_probit is not incidence).
ORDINAL_KEYS = ["ordinal", "adjacent_category", "adjcat", "continuation_ratio", "contratio",
                "stereotype", "ridit", "jonckheere", "clmm"]
FAMILY_KEYS = {
    "survival": ["surviv", "cox", "weibull", "kaplan", "logrank", "log_rank", "rmst", "turnbull",
                 "gehan", "frailty", "clayton", "interval_cens", "kmdiff", "km_diff"],
    "incidence": ["logistic", "probit", "binomial", "incid", "indicidence", "miettinen", "newcombe",
                  "zhang", "cmh", "clogit", "fisher", "riskdiff", "risk_diff"],
    "count": ["poisson", "negbin", "zinb", "zero_augmented", "hurdle", "count", "log_lik_nb"],
    "proportion": ["beta", "zero_one", "zoib", "fractional", "proportion"],
    "continuous": ["fast_ols", "quantile", "gaussian_lmm", "robust_regression", "continuous", "fast_bai"],
}
# Design-generation code: the designs section, and procedures (a randomization
# test redraws assignments through the design).
DESIGN_FILES = {
    "atkinson_assign", "pocock_simon_assign", "binary_match_search", "compute_mahal_distances",
    "compute_weighted_distances", "kk21_weights", "greedy_pairwise_swap_engine",
    "rerandomization_helpers", "random_block_size_speedups", "spbr_speedups", "pair_dist_helpers",
    "optimal_blocks_distance", "optimal_design_search", "helper_matching", "helper_optimal_annealing",
    "helper_optimal_milp_solvers", "helper_optimal_shared",
}
# Resampling machinery: only the procedures section times it.
RESAMPLING_FILES = {
    "bootstrap_indices", "bootstrap_match_indices", "randomization_loop", "generate_permutations",
    "exchangeable_resampling_draws", "ols_distr_parallel", "rand_bootstrap_mean_diff_parallel",
    "rand_bootstrap_ols_parallel", "simple_mean_diff_parallel", "ridit_distr_parallel",
    "sample_bootstrap_distr_weighted_distances", "kk_compound_distr_parallel",
    "kk_bootstrap_reservoir_stats", "helper_bootstrap_ci", "contracts_resampling_draws",
    "helper_reused_worker_private_cache",
}
# Code no benchmark row runs, and generated files that only change together
# with the real change in another file.
NO_BENCH_FILES = {
    "RcppExports", "simulation_dgp", "simulation_framework_report", "simulations_framework",
    "test_smart_starts", "user_compiled_fn_shims", "user_compiled_fns", "helper_user_compiled_fn",
    "build_info", "helper_rcpp_doc_stubs",
}
# Leaf math headers every kernel includes, the utility section included.
MATH_HEADERS = {"fast_erfc", "fast_gamma_functions"}
BUILD_FILES = {"R/EDI/DESCRIPTION", "R/EDI/NAMESPACE", "R/EDI/configure", "R/EDI/configure.win",
               "R/EDI/src/Makevars", "R/EDI/src/Makevars.win"}
R_HARNESS = {"R/benchmark/benchmark_model_fits.R", "R/benchmark/benchmark_sections.R"}
PYTHON_HARNESS = "R/benchmark/benchmark_model_fits_python.py"
PYTHON_BUILD = ("python/cpp/", "python/src/", "python/CMakeLists.txt", "python/pyproject.toml")


def keyword_families(base):
    b = base.lower()
    if any(k in b for k in ORDINAL_KEYS):
        return ["ordinal"]
    return [fam for fam, keys in FAMILY_KEYS.items() if any(k in b for k in keys)]


def inference_file_family(base):
    """inference_<family>_*.R -> that family; other inference_* files -> None."""
    m = re.match(r"inference_([a-z]+)_", base)
    if not m:
        return None
    alias = {"contin": "continuous", "continuous": "continuous", "incidence": "incidence",
             "incid": "incidence", "indicidence": "incidence", "count": "count",
             "proportion": "proportion", "prop": "proportion", "ordinal": "ordinal",
             "survival": "survival"}
    return alias.get(m.group(1))


def r_targets(path):
    """The R benchmark jobs a functional change to `path` can affect."""
    if path in BUILD_FILES or path in R_HARNESS:
        return set(ALL_R)
    if path == "R/benchmark/fast_math_utils_bench.cpp":
        return {"utility"}
    if not (path.startswith("R/EDI/R/") or path.startswith("R/EDI/src/")):
        return set()
    base = os.path.splitext(os.path.basename(path))[0]
    # local_machine_tuning*: opt-in core-count tuning; the benchmarks run single-threaded.
    if base in NO_BENCH_FILES or base.startswith(("unity_", "local_machine_tuning")):
        return set()
    if base in MATH_HEADERS:
        return set(ALL_R)
    if base == "fast_math_utils":
        return {"utility"}
    if base.startswith("design_") or base in DESIGN_FILES:
        return {"designs", "procedures"}
    if base in RESAMPLING_FILES:
        # e.g. ridit_distr_parallel also feeds the ordinal Ridit rows
        return {"procedures"} | family_jobs(keyword_families(base))
    if path.startswith("R/EDI/R/") and base.startswith("inference_"):
        fam = inference_file_family(base)
        if fam:
            return family_jobs([fam]) | ({"procedures"} if fam in PROCEDURE_FAMILIES else set())
        return family_jobs(FAMILIES)  # inference_all_*, mixins, abstract bases: every family + procedures
    fams = keyword_families(base)
    if fams:
        return family_jobs(fams)
    return set(ALL_R)


def python_target(path, kernel_sources):
    if path == PYTHON_HARNESS or path.startswith(PYTHON_BUILD):
        return True
    if path.startswith("R/EDI/src/"):
        if path.endswith((".h", ".hpp")):
            return True
        return os.path.basename(path) in kernel_sources
    return False


def git(*args, check=True):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=check).stdout


def is_functional_change(base, head, path):
    """A build or harness file counts on any change; an R, C/C++ or Python source only when
    it differs in more than comments and whitespace (scripts/significant_changes.py)."""
    return significant_changes.is_functional_change(base, head, path)


def changed_files(base, head):
    out = git("diff", "--name-only", base, head)
    return [p for p in out.splitlines() if p]


def python_kernel_sources(head):
    try:
        text = git("show", f"{head}:python/CMakeLists.txt")
    except subprocess.CalledProcessError:
        return set()
    return set(re.findall(r"\$\{EDI_SRC_DIR\}/([A-Za-z0-9_]+\.cpp)", text))


def commit_known(sha):
    return bool(sha) and subprocess.run(["git", "cat-file", "-e", f"{sha}^{{commit}}"],
                                         capture_output=True).returncode == 0


def parse_time(s):
    try:
        t = dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
        return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)
    except (AttributeError, ValueError):
        return None


def decide(manifest, head, mode, max_age_days, now):
    """{job: (run?, reason)} for every R job and the Python job."""
    jobs = R_JOBS + [PYTHON_JOB]
    if mode == "all":
        return {j: (True, "all jobs requested") for j in jobs}
    if mode == "none":
        return {j: (False, "benchmarks turned off for this run") for j in jobs}
    entries = dict(manifest.get("jobs", {}))
    if "python" in manifest:
        entries[PYTHON_JOB] = manifest["python"]
    kernel_sources = python_kernel_sources(head)
    diff_cache = {}
    out = {}
    for job in jobs:
        e = entries.get(job)
        if not e:
            out[job] = (True, "no saved rows"); continue
        sha = e.get("commit", "")
        if not commit_known(sha):
            out[job] = (True, f"saved rows' commit {sha[:12] or '?'} is not in this repository's history"); continue
        t = parse_time(e.get("timed_at", ""))
        if t is None:
            out[job] = (True, "saved rows have no timestamp"); continue
        # A regression stays visible: a job whose last verdict failed reruns every night
        # until it passes, as the ungated benchmarks did.
        if e.get("verdict") == "failure":
            out[job] = (True, f"the run at {sha[:12]} found a regression; retiming until it passes"); continue
        age = (now - t).total_seconds() / 86400.0
        if age > max_age_days:
            out[job] = (True, f"saved rows are {age:.0f} days old (limit {max_age_days})"); continue
        if sha not in diff_cache:
            files = changed_files(sha, head)
            diff_cache[sha] = [p for p in files if is_functional_change(sha, head, p)]
        hits = [p for p in diff_cache[sha]
                if (python_target(p, kernel_sources) if job == PYTHON_JOB else job in r_targets(p))]
        if hits:
            shown = ", ".join(hits[:5]) + (f" and {len(hits) - 5} more" if len(hits) > 5 else "")
            out[job] = (True, f"changed since {sha[:12]}: {shown}")
        else:
            out[job] = (False, f"unchanged since {sha[:12]} (timed {t:%Y-%m-%d})")
    return out


def matrix_entry(job):
    if "-" in job:
        sec, fam = job.split("-", 1)
        return {"id": job, "section": sec, "families": fam}
    return {"id": job, "section": job, "families": ""}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default="")
    ap.add_argument("--head", default="HEAD")
    ap.add_argument("--mode", choices=["auto", "all", "none"], default="auto")
    ap.add_argument("--max-age-days", type=float, default=14.0)
    ap.add_argument("--now", default="")
    ap.add_argument("--github-output", default="")
    ap.add_argument("--summary", default="")
    ap.add_argument("--list-jobs", action="store_true")
    a = ap.parse_args(argv)
    if a.list_jobs:
        print("\n".join(R_JOBS)); return 0
    manifest = {}
    if a.manifest and os.path.exists(a.manifest):
        with open(a.manifest) as f:
            manifest = json.load(f)
    now = parse_time(a.now) if a.now else dt.datetime.now(dt.timezone.utc)
    head = git("rev-parse", a.head).strip()
    decisions = decide(manifest, head, a.mode, a.max_age_days, now)
    run_r = [j for j in R_JOBS if decisions[j][0]]
    lines = ["### Benchmark jobs", "", "| job | runs | why |", "|---|---|---|"]
    lines += [f"| {j} | {'yes' if decisions[j][0] else 'no'} | {decisions[j][1]} |" for j in R_JOBS + [PYTHON_JOB]]
    text = "\n".join(lines) + "\n"
    print(text)
    if a.summary:
        with open(a.summary, "a") as f:
            f.write(text + "\n")
    outputs = {
        "bench": "true" if run_r else "false",
        "bench_matrix": json.dumps({"include": [matrix_entry(j) for j in run_r]}, separators=(",", ":")),
        "python": "true" if decisions[PYTHON_JOB][0] else "false",
    }
    if a.github_output:
        with open(a.github_output, "a") as f:
            for k, v in outputs.items():
                f.write(f"{k}={v}\n")
    else:
        for k, v in outputs.items():
            print(f"{k}={v}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
