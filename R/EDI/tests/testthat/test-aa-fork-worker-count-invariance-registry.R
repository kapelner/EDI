library(testthat)
library(EDI)

# v1.1.0 TODO-48 (2): thread- and worker-count invariance, fork backend
# (cross_platform_reproducibility.md TODO-2). The mirai half is
# test-zz-mirai-worker-count-invariance-registry.R; the shared machinery and the
# list of cases are in helper-worker-count-invariance.R.
#
# Same seed, set_num_cores(1, 2, 4) on fork workers: estimates, SEs/CIs and
# p-values of each resampling family (nonparametric bootstrap, Bayesian
# bootstrap, randomization p-value and CI, randomization bootstrap,
# parametric bootstrap) must be identical(), not merely tolerance-equal, to
# the serial run. The OpenMP design-draw kernels are checked the same way.
#
# By default this runs one representative registry class per response type,
# each with the resampling families that dispatch to workers for it (see the
# helper for the list and why). EDI_EXHAUSTIVE_WORKER_TESTS=true sweeps every
# concrete, exported, non-IVWC, non-KK registry class instead (over 10 minutes).
# KK (matched-design) and IVWC classes are not covered here.
#
# 4 workers only with NOT_CRAN=true and without _R_CHECK_LIMIT_CORES_ (CRAN
# allows 2). Skipped on CRAN, for the lean pre-push run and the R-CMD-check
# matrix (EDI_PREPUSH_NO_PARALLEL=true), under covr, and off Linux (fork
# workers with Accelerate/libomp on macOS are not exercised here; Windows has
# no fork). Runs nightly via the repro job's "worker-count-invariance" filter.
# Named test-aa-* so it runs before any test that starts mirai, after which
# fork clusters cannot be started in the same session.
#
# Set EDI_WORKER_INVARIANCE_VERBOSE=true to print the per-run table, whose
# dispatched_cores column shows whether a run reached the workers or fell back
# to serial.

skip_fork_worker_invariance = function() {
	skip_on_cran()
	skip_if_prepush_no_parallel()
	skip_if_not(identical(Sys.info()[["sysname"]], "Linux"), "fork worker invariance is tested on Linux")
	skip_if(identical(Sys.getenv("R_COVR"), "true"),
		"avoid spawning a real fork cluster under covr's gcov-instrumented build")
	skip_if(isTRUE(EDI:::edi_env$mirai_has_been_used),
		"fork clusters cannot be started safely after mirai has been used in this R session")
	skip_if(length(worker_invariance_core_counts()) < 2L, "fewer than 2 logical cores available")
}

test_that("registry inference resampling is identical at 1, 2 and 4 fork workers", {
	skip_fork_worker_invariance()
	on.exit(unset_num_cores(), add = TRUE)
	rows = worker_invariance_sweep("fork")
	expect_true(!is.null(rows) && nrow(rows) > 0L)
	expect_true(any(!is.na(rows$dispatched_cores) & rows$dispatched_cores > 1L),
		info = "no procedure dispatched to fork workers")
	worker_invariance_report(rows)
})

test_that("OpenMP design draws are identical under set_num_cores(1, 2, 4) on the fork backend", {
	skip_fork_worker_invariance()
	on.exit(unset_num_cores(), add = TRUE)
	worker_invariance_design_draws("fork")
})
