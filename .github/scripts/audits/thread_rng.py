"""Thread and random-number review (monthly, 3rd Sunday, PR, Opus).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4, "Thread and
random-number review"; audit_jobs_framework.md TODO-18).

Looks for random streams seeded per thread instead of per draw index, shared mutable state
inside parallel loops, R's RNG or R API called from worker threads, and results that depend on
the worker count or on the order of draws.

- Units: one C++ file in R/EDI/src or one R file in R/EDI/R with parallel loops or RNG use,
  found by grep: OpenMP pragmas, RcppParallel, std::thread, R's RNG entry points
  (unif_rand, norm_rand, R::r*), C++ <random> engines and EDI's RRng (RNG.h) on the C++ side;
  par_lapply, mirai, future, parallel::, fork clusters, set_num_cores / num_cores, set.seed,
  .Random.seed and RNGkind on the R side. Context: the matching lines, the file's Rcpp
  exports and their R callers, the classes, the test files that name them, its last commits,
  and the existing worker-count invariance tests (bulk tests that call set_num_cores) as
  templates.
- Selection: new or changed files, open findings, and a 1/6 rotation over the monthly runs, capped by
  max_batches.
- A finding counts only with a testthat test showing a result that changes with
  set_num_cores() (or with the order of draws). The finish stage runs each test against EDI
  installed from this commit and keeps only those that fail as claimed (_testthat_verify.py);
  kept tests go into the PR, skipped until the owner opens a release TODO.
"""
import re

import audit_common as ac
from audits import _edi_index as ei
from audits import _testthat_verify as tv

SPEC = {
    "name": "thread-rng",
    "title": "Thread and random-number review",
    "report": "pr",
    "claude": True,
    "model": ac.OPUS,
    "batch_size": 3,
    "max_batches": 8,         # at most 24 units a run
    "period": "month",        # the rotation counts this job's monthly runs
    "cycle_weeks": 6,         # 1/6 rotation: each unchanged unit re-read every 6th run
    "max_turns": 80,
    "tools": "Read,Glob,Grep",
}
MAX_HITS = 40

CPP_PAT = re.compile(
    r"#\s*pragma\s+omp|RcppParallel|std::thread|std::async|\btbb::|\bunif_rand\s*\(|\bnorm_rand\s*\(|"
    r"\bexp_rand\s*\(|\bR::r[a-z]+\s*\(|std::mt19937|std::random_device|std::(?:uniform|normal|bernoulli|"
    r"discrete|binomial|poisson)_\w*distribution|\bRRng\b|GetRNGstate|PutRNGstate|#\s*include\s+\"RNG\.h\"|"
    r"omp_get_thread_num|omp_set_num_threads")
R_PAT = re.compile(
    r"\bpar_lapply\b|\bmirai\b|\bfuture(?:::|_lapply|\.apply)|\bparallel::|\bmclapply\b|\bparLapply\b|"
    r"makeForkCluster|makeCluster|%dopar%|\bforeach\s*\(|\bset_num_cores\b|\bget_num_cores\b|\bnum_cores\b|"
    r"\bset\.seed\s*\(|\.Random\.seed|\bRNGkind\s*\(|set_package_threads")


def matching_lines(text, pat, limit=MAX_HITS):
    out = []
    for i, line in enumerate(text.splitlines(), 1):
        s = line.strip()
        if s.startswith(("#'", "//")) and "pragma" not in s:
            continue
        if pat.search(line):
            out.append([i, s[:200]])
            if len(out) >= limit:
                break
    return out


def invariance_templates(idx):
    """Existing bulk tests that call set_num_cores(): the template for a worker-count test."""
    return sorted(f for f, ids in idx.tests.items() if "set_num_cores" in ids and "testthat_bulk" in f)


def units(ctx):
    idx = ei.Index(ctx.repo)
    templates = invariance_templates(idx)
    out = {}
    for f, text in idx.src.items():
        hits = matching_lines(text, CPP_PAT)
        if not hits:
            continue
        exports = idx.exports.get(f, [])
        names = list(exports)
        if not names and f.endswith((".h", ".hpp")):
            for g in idx.includers(f)[:15]:
                names += idx.exports.get(g, [])
        callers = idx.callers(names)
        classes = idx.classes_in([c["file"] for c in callers])
        out[f] = {"hash": ac.text_hash(text), "context": {
            "file": f, "language": "C++", "lines": text.count("\n") + 1,
            "parallel_or_rng_lines": hits, "rcpp_exports": exports,
            "included_by": idx.includers(f)[:30] if f.endswith((".h", ".hpp")) else [],
            "r_callers": callers, "r_classes": classes,
            "test_files": idx.tests_naming(names + classes),
            "invariance_test_templates": templates,
            "recent_commits": ei.git_log(ctx.repo, f)}}
    for f, text in idx.r.items():
        hits = matching_lines(text, R_PAT)
        if not hits:
            continue
        kernels = idx.cpp_calls_in_r(f)
        classes = idx.classes.get(f, [])
        out[f] = {"hash": ac.text_hash(text), "context": {
            "file": f, "language": "R", "lines": text.count("\n") + 1,
            "parallel_or_rng_lines": hits, "r_classes": classes,
            "cpp_kernels_called": [{"export": e, "file": s} for e, s in sorted(kernels.items())],
            "test_files": idx.tests_naming(classes + list(kernels)),
            "invariance_test_templates": templates,
            "recent_commits": ei.git_log(ctx.repo, f)}}
    return out


def apply(ctx, results, mech):
    # Worker-count tests start a second worker set, so they get a longer limit than the
    # numerical tests.
    return tv.apply_tests(ctx, results, SPEC["title"], per_test_timeout=300, total_budget=1800)
