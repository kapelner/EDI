library(testthat)
library(EDI)

# v1.1.0 TODO-48 (2): thread- and worker-count invariance, mirai backend
# (cross_platform_reproducibility.md TODO-2). The fork half is
# test-aa-fork-worker-count-invariance-registry.R; the shared machinery and the
# list of cases are in helper-worker-count-invariance.R.
#
# Same seed, set_num_cores(1, 2, 4, force_mirai = TRUE): estimates, SEs/CIs
# and p-values of each resampling family (nonparametric bootstrap, Bayesian
# bootstrap, randomization p-value and CI, randomization bootstrap,
# parametric bootstrap) must be identical(), not merely tolerance-equal, to
# the serial run. The OpenMP design-draw kernels are checked the same way off
# Linux (on Linux the fork file covers them; they run in the main process).
#
# By default this runs one representative registry class per response type,
# each with the resampling families that dispatch to workers for it (see the
# helper for the list and why). EDI_EXHAUSTIVE_WORKER_TESTS=true sweeps every
# concrete, exported, non-IVWC, non-KK registry class instead (over 10 minutes).
# KK (matched-design) and IVWC classes are not covered here.
#
# 4 daemons only with NOT_CRAN=true and without _R_CHECK_LIMIT_CORES_ (CRAN
# allows 2). Skipped on CRAN, for the lean pre-push run and the R-CMD-check
# matrix (EDI_PREPUSH_NO_PARALLEL=true: the nanonext daemon hang), under covr,
# and when mirai is not installed. Runs on every OS, nightly via the repro
# job's "worker-count-invariance" filter.
#
# Starting mirai daemons rules out fork clusters for the rest of the R
# session, so this file must sort after every test that needs fork workers
# that is not already behind test-bayesian-bootstrap.R's mirai test (the
# fork half is named test-aa-* for that reason).
#
# Set EDI_WORKER_INVARIANCE_VERBOSE=true to print the per-run table, whose
# dispatched_cores column shows whether a run reached the workers or fell back
# to serial.

skip_mirai_worker_invariance = function() {
	skip_on_cran()
	skip_if_prepush_no_parallel()
	skip_if_not_installed("mirai")
	skip_if(identical(Sys.getenv("R_COVR"), "true"),
		"avoid spawning real mirai daemons under covr's gcov-instrumented build")
	skip_if(length(worker_invariance_core_counts()) < 2L, "fewer than 2 logical cores available")
}

test_that("registry inference resampling is identical at 1, 2 and 4 mirai workers", {
	skip_mirai_worker_invariance()
	on.exit(unset_num_cores(), add = TRUE)
	rows = worker_invariance_sweep("mirai")
	expect_true(!is.null(rows) && nrow(rows) > 0L)
	expect_true(any(!is.na(rows$dispatched_cores) & rows$dispatched_cores > 1L),
		info = "no procedure dispatched to mirai workers")
	worker_invariance_report(rows)
})

test_that("OpenMP design draws are identical under set_num_cores(1, 2, 4) on the mirai backend", {
	skip_mirai_worker_invariance()
	# The draw kernels run in the main process whichever backend holds the
	# workers, so on Linux the fork file's copy of this test already covers it.
	skip_if(identical(Sys.info()[["sysname"]], "Linux"),
		"design draws are covered by the fork backend's test on Linux")
	on.exit(unset_num_cores(), add = TRUE)
	worker_invariance_design_draws("mirai")
})
