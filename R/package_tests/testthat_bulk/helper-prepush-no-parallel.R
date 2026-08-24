library(testthat)

# Shared skip guard for tests that spawn real multi-core/mirai parallel
# workers. .githooks/pre-push sets EDI_PREPUSH_NO_PARALLEL=true before
# running the local test suite -- worker-spawning tests are exactly the ones
# implicated in pre-push-specific problems traced in practice: Ctrl+C not
# reaching an orphaned worker process, worker stdout/stderr bypassing the
# hook's sink()-based noise suppression in scripts/run_prepush_r_tests.R
# (workers are separate R sessions -- sink() is per-process state and
# doesn't propagate to them), and a multi-hour hang. Skipped only for the
# local pre-push run; CI and an ordinary devtools::test()/R CMD check run
# are unaffected since the env var is unset there.
#
# This is NOT a gap in coverage: every test gated here already carries its
# own skip_on_cran(), which means CI's main matrix (R-CMD-check,
# R-CMD-check-no-suggests) never ran them either -- those jobs deliberately
# mimic a real CRAN check and never set NOT_CRAN=true. These tests have only
# ever run in two places: the local pre-push hook, and CI's
# R-CMD-check-sanitizers / R-CMD-check-valgrind jobs (both set
# NOT_CRAN: true, both still run on every push, both bounded by their own
# timeout-minutes -- see .github/workflows/R-CMD-check.yaml). Skipping them
# here just removes the local-pre-push copy of that coverage, not the only
# copy.
#
# To run these tests locally on demand (e.g. before/after touching parallel-
# or mirai-related code): either run the suite directly instead of through
# the hook (`devtools::test()`, or `Rscript scripts/run_prepush_r_tests.R`
# from R/EDI/tests with EDI_PREPUSH_NO_PARALLEL left unset), or override it
# explicitly for one push: `EDI_PREPUSH_NO_PARALLEL=false git push`.
skip_if_prepush_no_parallel <- function(){
	testthat::skip_if(
		identical(Sys.getenv("EDI_PREPUSH_NO_PARALLEL"), "true"),
		"real multi-core/mirai worker test skipped for the local pre-push run"
	)
}
