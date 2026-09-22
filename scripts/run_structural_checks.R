#!/usr/bin/env Rscript
# Fast structural gate run by .githooks/pre-push BEFORE the full R test suite.
# Five cheap checks for the bug families behind the 2026-09-19
# comprehensive_tests results audit:
#   * wiring completeness -- a method a component/capability promises is
#     silently NULL on the assembled class;
#   * registry drift -- the registry's component lists diverged from the real
#     define_inference_class() calls;
#   * adversarial data + injected SE faults -- pathological inputs must yield a
#     clean NA/error, never a wrong-looking number (~15 s);
#   * reference parity -- estimates/SEs match survival/quantreg/pscl/glm/...
#     fit to the same data (~10 s);
#   * reused-worker resampling non-degeneracy -- a per-draw cache the loader
#     forgets to reset turns a randomization distribution into r copies of
#     draw 1; sweeps every concrete class across the Bernoulli, KK-matching and
#     blocked design families (fix_stale_worker_cache_resampling.md, ~25 s).
# ~2 minutes total, so a break fails the push early instead of after the full
# ~10 minute suite. They also run again inside the full suite (they live in
# R/EDI/tests/testthat/), which is intentional: this pass exists purely for
# fast feedback.
#
# Must run with cwd = R/EDI/tests (test files resolve R/EDI/R relative to it),
# against the already-installed EDI, like scripts/run_prepush_r_tests.R.

suppressPackageStartupMessages({
	library(testthat)
	library(EDI)
})

files <- c(
	"testthat/test-inference-class-wiring-completeness.R",
	"testthat/test-registry-component-drift.R",
	"testthat/test-adversarial-and-fault-injection.R",
	"testthat/test-reference-parity.R",
	"testthat/test-reused-worker-resampling-nondegenerate.R"
)

failed <- FALSE
for (f in files) {
	if (!file.exists(f)) {
		cat("run_structural_checks: missing", f, "-- run from R/EDI/tests\n", file = stderr())
		quit(status = 2L)
	}
	res <- as.data.frame(testthat::test_file(f, reporter = "silent"))
	n_fail <- sum(res$failed > 0L, na.rm = TRUE)
	n_err <- sum(res$error, na.rm = TRUE)
	cat(sprintf("run_structural_checks: %-56s tests=%d failed=%d errors=%d\n", basename(f), nrow(res), n_fail, n_err))
	if (n_fail > 0L || n_err > 0L) {
		failed <- TRUE
		# Re-run verbosely so the unlisted gap / drift details are printed.
		testthat::test_file(f, reporter = "summary")
	}
}
quit(status = if (failed) 1L else 0L)
