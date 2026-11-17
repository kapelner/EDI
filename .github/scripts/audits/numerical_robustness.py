"""Numerical-robustness review (monthly, 1st Saturday, PR, Opus).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4,
"Numerical-robustness review"; audit_jobs_framework.md TODO-18).

Looks for the numerical bug patterns that have actually happened in EDI: `converged = TRUE`
set without checking the convergence criterion, unguarded log(0) / exp overflow / division by
a near-zero information, NA returned where a value is defined, and a null refit with a single
cold start.

- Units: one C++ kernel file in R/EDI/src (.cpp or .h), or one R file in R/EDI/R with fitting
  code (an optimiser or model-fitting call, or a `converged` flag). Context, precomputed here
  because the agents have no shell: the file's Rcpp exports, the R files and R6 classes that
  call them (with line numbers), the test files that name them, the headers it includes, and
  its last commits.
- Selection: new or changed files, units with an open finding, and a 1/6 rotation over the
  monthly runs (SPEC period "month"), capped by max_batches.
- No mechanical stage: the patterns need reading, not grepping.
- A finding counts only with a testthat test that fails on the current code. The finish stage
  runs each test against EDI installed from this commit and keeps only the tests that fail an
  expectation for the reason claimed (_testthat_verify.py). Kept tests go into the PR under
  R/package_tests/testthat_bulk/, skipped until the owner opens a release TODO.
"""
import re

import audit_common as ac
from audits import _edi_index as ei
from audits import _testthat_verify as tv

SPEC = {
    "name": "numerical-robustness",
    "title": "Numerical-robustness review",
    "report": "pr",
    "claude": True,
    "model": ac.OPUS,
    "batch_size": 3,          # each unit is a whole kernel plus its callers, and each finding needs a test
    "max_batches": 10,        # at most 30 units a run; the rest roll to next month, oldest first
    "period": "month",        # the rotation counts this job's monthly runs
    "cycle_weeks": 6,         # 1/6 rotation: each unchanged unit re-read every 6th run
    "max_turns": 80,
    "tools": "Read,Glob,Grep",
}

# R files with fitting code: an optimiser or model-fitting call, or a convergence flag ...
FIT_R = re.compile(
    r"\b(optim|optimize|optimise|nlminb|nlm|uniroot|glm\.fit|glm|lm\.fit|polr|coxph|survreg|clm|clmm|"
    r"glmer|lmer|glmmTMB|betareg|zeroinfl|hurdle|vglm|multinom)\s*\(|\bconverged\b")
# ... or a call to a C++ fitting kernel.
FIT_KERNEL = re.compile(r"fast_|regression|_glm|glmm|_fit|newton|irls|optim|mle|likelihood|lik_", re.I)


def has_fitting_code(idx, f):
    return bool(FIT_R.search(idx.r[f]) or any(FIT_KERNEL.search(e) for e in idx.cpp_calls_in_r(f)))


def _cpp_context(idx, ctx, f):
    exports = idx.exports.get(f, [])
    included_by = idx.includers(f) if f.endswith((".h", ".hpp")) else []
    names = list(exports)
    if not names and included_by:
        for g in included_by[:15]:
            names += idx.exports.get(g, [])
    callers = idx.callers(names)
    classes = idx.classes_in([c["file"] for c in callers])
    return {
        "file": f,
        "language": "C++",
        "lines": idx.src[f].count("\n") + 1,
        "rcpp_exports": exports,
        "includes": idx.includes(f),
        "included_by": included_by[:30],
        "r_callers": callers,
        "r_classes": classes,
        "test_files": idx.tests_naming(names + classes),
        "recent_commits": ei.git_log(ctx.repo, f),
    }


def _r_context(idx, ctx, f):
    kernels = idx.cpp_calls_in_r(f)
    classes = idx.classes.get(f, [])
    return {
        "file": f,
        "language": "R",
        "lines": idx.r[f].count("\n") + 1,
        "r_classes": classes,
        "cpp_kernels_called": [{"export": e, "file": src} for e, src in sorted(kernels.items())],
        "test_files": idx.tests_naming(classes + list(kernels)),
        "recent_commits": ei.git_log(ctx.repo, f),
    }


def units(ctx):
    idx = ei.Index(ctx.repo)
    out = {}
    for f in idx.src:
        out[f] = {"hash": ac.text_hash(idx.src[f]), "context": _cpp_context(idx, ctx, f)}
    for f, text in idx.r.items():
        if not has_fitting_code(idx, f):
            continue
        kernels = idx.cpp_calls_in_r(f)
        # Re-read an R file when a kernel it calls changes its signature (not on every kernel edit:
        # the kernel file is its own unit).
        deps = ac.text_hash(*[ei.export_signature(idx.src[src], e) for e, src in sorted(kernels.items())])
        out[f] = {"hash": ac.text_hash(text), "deps": deps, "context": _r_context(idx, ctx, f)}
    return out


def apply(ctx, results, mech):
    return tv.apply_tests(ctx, results, SPEC["title"])
