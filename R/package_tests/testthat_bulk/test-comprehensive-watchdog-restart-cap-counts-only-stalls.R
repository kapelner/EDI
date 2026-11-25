# The comprehensive-tests watchdog's restart cap (COMPREHENSIVE_WATCHDOG_MAX_RESTARTS) counts only relaunches that
# make no progress. A long shard call whose methods time out on many reps records a new outcome on every relaunch, so
# it must run to completion; a call that dies again after its outcome was recorded must still give up. (v1.0.5
# release cut, wave 1, 2026-11-25: three 50-rep calls exited 1 with "giving up after 100 restarts".)

library(testthat)

source(test_path("..", "comprehensive_tests_watchdog.R"), local = TRUE)

# A stand-in worker: for each key it has no outcome for, it writes the in-flight marker and then either hangs past the
# limit or (with stall = TRUE) dies at once on the first key every time, outcome or not.
fake_worker = function(dir, keys, stall){
	path = file.path(dir, "worker.R")
	writeLines(c(
		sprintf("keys = c(%s); stall = %s", paste(sprintf("'%s'", keys), collapse = ", "), stall),
		"marker = Sys.getenv('COMPREHENSIVE_WATCHDOG_MARKER')",
		"out = file.path(dirname(marker), 'outcomes.rds'); outcomes = if (file.exists(out)) readRDS(out) else list()",
		"for (k in keys) {",
		"  if (!stall && !is.null(outcomes[[k]])) next",
		"  saveRDS(list(pid = Sys.getpid(), key = k, label = k, start_epoch = as.numeric(Sys.time())), marker)",
		"  if (stall) quit(status = 3L)",
		"  Sys.sleep(60)",
		"}",
		"quit(status = 0L)"
	), path)
	path
}

run_watchdog = function(script){
	withr::with_envvar(c(
		COMPREHENSIVE_FUNCTION_TIMEOUT_SEC = "1", COMPREHENSIVE_WATCHDOG_GRACE_SEC = "0",
		COMPREHENSIVE_WATCHDOG_MAX_RESTARTS = "2", COMPREHENSIVE_SUSPEND_GAP_SEC = "1000"
	), suppressMessages(run_comprehensive_tests_watchdog(script)))
}

test_that("timeouts on more distinct calls than the cap still run to completion", {
	skip_if_not_installed("processx")
	dir = withr::local_tempdir()
	expect_identical(run_watchdog(fake_worker(dir, paste0("call-", 1:4), stall = FALSE)), 0L)
})

test_that("a call that keeps dying after its outcome was recorded gives up after the cap", {
	skip_if_not_installed("processx")
	dir = withr::local_tempdir()
	expect_identical(run_watchdog(fake_worker(dir, "call-1", stall = TRUE)), 1L)
})
