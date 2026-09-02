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
# CORRECTION (2026-09-02): the paragraph this replaced claimed the main CI
# check matrix never ran these tests because it "never set NOT_CRAN=true".
# That was wrong -- r-lib/actions/check-r-package@v2 sets NOT_CRAN=true by
# default, so the main matrix DID run them, and they were the source of
# every intermittent multi-hour "checking tests" hang from 2026-08-28
# onward (random legs, any OS, any BLAS; see R-CMD-check.yaml's watchdog
# steps and the EDI_PREPUSH_NO_PARALLEL comment there -- final evidence
# was run 33599645202's gdb capture: main thread parked forever in a
# timeout-less pthread_cond_wait inside nanonext's C internals during
# daemon lifecycle churn). The main matrix jobs now set
# EDI_PREPUSH_NO_PARALLEL=true themselves, so this guard covers them the
# way it always covered the pre-push hook. Real-worker coverage remains in
# CI's R-CMD-check-sanitizers / R-CMD-check-valgrind jobs (both set
# NOT_CRAN: true, both run these tests on every push, both bounded by
# their own timeout-minutes -- and neither has ever hung). Skipping them
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
