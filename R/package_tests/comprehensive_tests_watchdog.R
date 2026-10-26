# Watchdog for comprehensive_tests.R with fork=FALSE.
#
# With fork=FALSE, safe_call() runs each call in the worker process itself
# instead of a forked child (see the header of comprehensive_tests.R). That
# loses the two things the fork gave: a hard timeout (setTimeLimit() cannot
# interrupt a long compiled call) and crash isolation. This supervisor puts
# them back at the process level:
#
#   - comprehensive_tests.R, run as a script with fork=FALSE (the default), calls
#     run_comprehensive_tests_watchdog(), which relaunches the script as a
#     worker with the same arguments and COMPREHENSIVE_WATCHDOG_MARKER set.
#   - Before each call the worker writes an in-flight marker (its PID, the
#     call's result key and start time) and deletes it afterwards.
#   - If a call runs past COMPREHENSIVE_FUNCTION_TIMEOUT_SEC plus
#     COMPREHENSIVE_WATCHDOG_GRACE_SEC, the supervisor SIGKILLs the worker and
#     adds a "timeout" outcome for that call to the outcomes file. If the
#     worker dies while a marker is live, it adds a "crash" outcome ("timeout"
#     if the call was already past the limit: setTimeLimit()'s error can
#     escape every tryCatch and end the process). Either
#     way it relaunches the worker. Only the supervisor writes the outcomes
#     file, and only while no worker is running.
#   - The relaunched worker resumes from the results CSV (completed rows are
#     skipped, as on any resume). When it reaches a call with an outcome, it
#     records the timeout or crash through safe_call()'s own handle_timeout()
#     / handle_error() instead of running the call again.
#   - A worker that exits non-zero outside any call (e.g. a setup error) is
#     not relaunched; its exit status is returned.
#   - If two polls are more than COMPREHENSIVE_SUSPEND_GAP_SEC (default 10)
#     apart while a call is in flight, the machine was suspended. The
#     supervisor kills the worker and relaunches it without recording an
#     outcome, so the call is rerun rather than counted as a timeout.
#
# The supervisor needs the processx package. Without it,
# comprehensive_tests.R warns "watchdog recommended for autorestarts" and
# runs fork=FALSE unsupervised: calls still run in-process, but a hung
# compiled call blocks the run and a native crash ends it.
#
# Under the watchdog each result row is written as soon as it is recorded,
# so a kill loses nothing. A restarted worker's results match an
# uninterrupted run exactly: the Monte Carlo coverage truth is simulated
# under its own seed (get_coverage_truth()), so resuming does not shift the
# main random stream.

comprehensive_watchdog_read_rds = function(path){
	if (!nzchar(path) || !file.exists(path)) return(NULL)
	tryCatch(readRDS(path), error = function(e) NULL)
}

comprehensive_watchdog_write_rds = function(value, path){
	# Write then rename, so the other process never reads a partial file.
	tmp = paste0(path, ".tmp", Sys.getpid())
	saveRDS(value, tmp)
	file.rename(tmp, path)
}

comprehensive_watchdog_outcomes_path = function(marker){
	file.path(dirname(marker), "outcomes.rds")
}

comprehensive_watchdog_read_outcomes = function(marker){
	outcomes = comprehensive_watchdog_read_rds(comprehensive_watchdog_outcomes_path(marker))
	if (is.null(outcomes)) list() else outcomes
}

run_comprehensive_tests_watchdog = function(script_path){
	timeout_sec = as.numeric(Sys.getenv("COMPREHENSIVE_FUNCTION_TIMEOUT_SEC", "120"))
	grace_sec = as.numeric(Sys.getenv("COMPREHENSIVE_WATCHDOG_GRACE_SEC", "15"))
	max_restarts = as.integer(Sys.getenv("COMPREHENSIVE_WATCHDOG_MAX_RESTARTS", "100"))
	# A gap this long between two 1 s polls means the machine was suspended
	# (same setting as SUSPEND_GAP_SEC in comprehensive_tests.R).
	suspend_gap_sec = as.numeric(Sys.getenv("COMPREHENSIVE_SUSPEND_GAP_SEC", "10"))
	run_dir = tempfile("comprehensive_tests_watchdog_")
	dir.create(run_dir)
	on.exit(unlink(run_dir, recursive = TRUE), add = TRUE)
	marker = file.path(run_dir, "inflight.rds")
	worker_args = c(
		"--no-echo", "--no-restore", paste0("--file=", script_path),
		"--args", commandArgs(trailingOnly = TRUE)
	)
	worker_env = c(
		"current",
		COMPREHENSIVE_WATCHDOG_MARKER = marker,
		COMPREHENSIVE_WATCHDOG_SUPERVISOR_PID = as.character(Sys.getpid())
	)
	message(sprintf(
		"fork=FALSE: running calls in-process under a watchdog (hard limit %gs + %gs grace, at most %d restarts).",
		timeout_sec, grace_sec, max_restarts
	))
	add_outcome = function(info){
		outcomes = comprehensive_watchdog_read_outcomes(marker)
		outcomes[[info$key]] = info
		comprehensive_watchdog_write_rds(outcomes, comprehensive_watchdog_outcomes_path(marker))
		unlink(marker)
	}
	restarts = 0L
	suspend_restarts = 0L
	launches = 0L
	repeat {
		# A relaunched worker appends to the attempt manifest its predecessor
		# created instead of refusing it as another run's ledger.
		launch_env = c(worker_env, COMPREHENSIVE_ATTEMPT_MANIFEST_RESUME = if (launches > 0L) "1" else "0")
		launches = launches + 1L
		# supervise = TRUE: processx's own helper kills the worker if this
		# process dies by any means (e.g. SIGKILL, or a system2() timeout in
		# run_comprehensive_suite.R), so a worker stuck in compiled code is
		# not orphaned.
		worker = processx::process$new(
			file.path(R.home("bin"), "R"), worker_args,
			env = launch_env, stdout = "", stderr = "", cleanup = TRUE,
			supervise = TRUE
		)
		worker_pid = worker$get_pid()
		timed_out = NULL
		suspended = NULL
		t_prev = as.numeric(Sys.time())
		while (worker$is_alive()) {
			worker$wait(1000)
			t_now = as.numeric(Sys.time())
			gap = t_now - t_prev
			t_prev = t_now
			info = comprehensive_watchdog_read_rds(marker)
			if (is.null(info) || !identical(info$pid, worker_pid)) next
			if (gap > suspend_gap_sec) {
				worker$kill()
				worker$wait()
				suspended = c(info, list(gap = gap))
				break
			}
			elapsed = t_now - info$start_epoch
			if (elapsed > timeout_sec + grace_sec) {
				worker$kill()
				worker$wait()
				timed_out = c(info, list(outcome = "timeout", duration = elapsed))
			}
		}
		status = worker$get_exit_status()
		if (!is.null(suspended)) {
			# The machine was suspended during this call: record nothing, so
			# the relaunched worker resumes from the CSV and reruns it. Not
			# counted against max_restarts.
			unlink(marker)
			suspend_restarts = suspend_restarts + 1L
			if (suspend_restarts > max_restarts) {
				message(sprintf("Watchdog: giving up after %d suspend restarts.", max_restarts))
				return(1L)
			}
			message(sprintf(
				"Watchdog: machine suspended for %.0fs during %s; restarted worker %d to rerun the call.",
				suspended$gap, suspended$label, worker_pid
			))
			next
		}
		if (!is.null(timed_out)) {
			add_outcome(timed_out)
			message(sprintf(
				"Watchdog: %s ran %.0fs (limit %gs); killed worker %d and restarting.",
				timed_out$label, timed_out$duration, timeout_sec, worker_pid
			))
		} else {
			if (identical(status, 0L)) return(0L)
			info = comprehensive_watchdog_read_rds(marker)
			if (is.null(info) || !identical(info$pid, worker_pid)) {
				message(sprintf("Watchdog: worker %d exited with status %s outside any call; not restarting.", worker_pid, status))
				return(if (is.na(status) || status == 0L) 1L else abs(as.integer(status)))
			}
			detail = if (!is.na(status) && status < 0L) sprintf("killed by signal %d", -status) else sprintf("exit status %s", status)
			duration = as.numeric(Sys.time()) - info$start_epoch
			# setTimeLimit()'s "reached elapsed time limit" error can escape
			# every tryCatch and end the process; a death past the limit is
			# a timeout, as fork=TRUE would have recorded it.
			outcome = if (duration >= timeout_sec) "timeout" else "crash"
			add_outcome(c(info, list(outcome = outcome, detail = detail, duration = duration)))
			message(sprintf("Watchdog: worker %d died during %s after %.0fs (%s), recorded as %s; restarting.", worker_pid, info$label, duration, detail, outcome))
		}
		restarts = restarts + 1L
		if (restarts > max_restarts) {
			message(sprintf("Watchdog: giving up after %d restarts.", max_restarts))
			return(1L)
		}
	}
}
