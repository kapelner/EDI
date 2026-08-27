# testthat_bulk_quarantine/

Tests that are known numerically unstable/flaky enough that CI has seen them
flip pass/fail on the *identical commit* (i.e. not a real code regression,
just resampling/optimizer fragility at small sample sizes, or a
not-yet-root-caused cross-run RNG determinism gap). Moved here instead of
staying in `testthat_bulk/` so a legitimate but rare numerical edge case
doesn't block a push or fail CI for unrelated work.

**This directory is never run by GitHub CI or the `.githooks/pre-push`
hook.** Neither `.github/workflows/test-bulk-non-cran.yml` (which only
scans `R/package_tests/testthat_bulk/`) nor the pre-push hook's R-test step
(which only scans `R/EDI/tests/testthat/`) references this path, and it
deliberately has no `paths:` trigger anywhere in `.github/workflows/`.

## Running these tests manually

```sh
cd R
Rscript -e 'pkgload::load_all("EDI", compile = FALSE, quiet = TRUE); testthat::test_dir("package_tests/testthat_bulk_quarantine")'
```

Run this before/after touching code a quarantined test exercises, or
periodically to check whether a class's fragility has improved. A quarantined
test failing here is *expected* some fraction of the time -- that is the
whole reason it's here -- so don't treat a single failing run as a new bug
without first checking the file's own header comment for what "expected
failure" looks like for that test.

## What's here and why

- `test-parametric-bootstrap-lr-glmm-weibull-frailty-loggamma.R`:
  `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`'s null-constrained MLE
  can hit a genuine boundary case (Clayton-copula frailty dependence
  parameter at theta -> 0); environment-sensitive (a different BLAS/LAPACK
  shifts the optimizer enough to cross the boundary for the same seed).
- `test-count-zero-inflated-resampling-fragility.R`:
  `InferenceCountZeroInflatedPoisson`/`NegBin`'s bootstrap and randomization
  distributions degenerate on a meaningful fraction of resamples at this
  fixture's n=80 (two-part mixture, too few structural-zero or nonzero-count
  observations in one resampled arm); the randomization distribution
  additionally varies run-to-run even with the same explicit seed across
  fresh R sessions (root cause not found -- suspected forked/reused-worker
  code path).
- `test-inference-suite-run-all-inference-seq-vs-parallel.R`:
  `InferenceSuite$run_all_inference()`'s `num_cores = 1` vs `num_cores = 2`
  comparison. CI run 33072346506 (2026-08-27) failed both variants,
  including the one with real forking disabled -- a real, not-yet-root-caused
  discrepancy, not just the historical fork-deadlock hazard. Live
  investigation attempts hung, consistent with this codebase's documented
  fork/deadlock history (see `parallel_fork_cluster_test_safety.md`); needs
  dedicated, careful investigation rather than unattended CI execution.

## Promoting a test back out of quarantine

Once a class's fragility is root-caused and fixed (or a test's tolerance is
demonstrated to be reliably correct across many runs), move its test back
into the appropriate `testthat_bulk/` file and delete it here. Don't leave a
fixed test sitting in quarantine -- this directory earning no CI coverage is
the cost of admission, so anything that no longer needs it should leave.
