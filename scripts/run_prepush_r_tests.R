#!/usr/bin/env Rscript
# Local pre-push-only R test runner. R CMD check (CI) still uses
# R/EDI/tests/testthat.R + testthat's CheckReporter unchanged -- this script
# is a separate entry point used only by .githooks/pre-push, so that a local
# push isn't stuck watching one line scroll by per test file (or, worse, one
# line per failing expectation via testthat's _problems/ extraction). It
# redraws a single status line in place instead, and diverts any other
# stdout/message() noise from test bodies or package code to a log file so
# it can't interleave with that line (see the sink() setup near the bottom).
#
# Must run with cwd = R/EDI/tests (same requirement test_check() has
# internally): test_dir("testthat", ...) below is relative to the CWD.

suppressPackageStartupMessages({
	library(R6)
	library(testthat)
	library(EDI)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

TallyReporter <- R6::R6Class("TallyReporter",
	inherit = testthat::Reporter,
	public = list(
		n_ok = 0L, n_fail = 0L, n_warn = 0L, n_skip = 0L,
		failures = list(),
		warnings = list(),
		skips = list(),
		current_file = "",
		current_file_n_tests = 0L,
		current_test = "",
		start_time = NULL,
		file_start_time = NULL,
		file_timings = list(),
		timings_path = NULL,
		errors_path = NULL,
		last_draw_time = 0,
		interactive_tty = FALSE,
		out_con = NULL,

		initialize = function(interactive_tty = FALSE, out_con = stderr(), ...) {
			super$initialize(...)
			self$start_time <- Sys.time()
			self$interactive_tty <- interactive_tty
			self$out_con <- out_con
			# Resolved now, while cwd is still R/EDI/tests: test_dir() setwd()s
			# into testthat/ before end_reporter fires, so a relative path there
			# would land one directory too deep.
			self$timings_path <- file.path(getwd(), "prepush_test_timings.csv")
			self$errors_path <- file.path(getwd(), ".prepush_errors")
		},

		# A manually opened file() connection (self$out_con may be one -- see
		# the /dev/stderr setup near the bottom of this script) is buffered
		# and only flushes on its own schedule (buffer-full, or close()),
		# unlike the special stdout()/stderr() connections. Left unflushed,
		# writes here can sit in that buffer and surface later, out of order
		# relative to whatever else is writing to the same underlying fd --
		# confirmed in practice: an unflushed first status line showed up
		# truncated and out of sequence. Flush after every write so this
		# reporter's own output reaches the terminal immediately, in order.
		write_out = function(...) {
			cat(..., file = self$out_con)
			flush(self$out_con)
		},

		start_file = function(filename) {
			self$current_file <- filename
			self$current_file_n_tests <- 0L
			self$current_test <- ""
			self$file_start_time <- Sys.time()
			self$draw()
		},

		end_file = function() {
			self$file_timings[[length(self$file_timings) + 1L]] <- list(
				file = self$current_file,
				elapsed_secs = round(as.numeric(difftime(Sys.time(), self$file_start_time, units = "secs")), 3)
			)
		},

		start_test = function(context, test) {
			self$current_test <- test %||% ""
			self$current_file_n_tests <- self$current_file_n_tests + 1L
			self$draw()
		},

		add_result = function(context, test, result) {
			# Mirrors testthat's own ProgressReporter$add_result() classification order.
			if (testthat:::expectation_broken(result)) {
				self$n_fail <- self$n_fail + 1L
				self$failures[[length(self$failures) + 1L]] <- list(
					file = self$current_file,
					test = test %||% self$current_test,
					message = conditionMessage(result)
				)
			} else if (testthat:::expectation_skip(result)) {
				self$n_skip <- self$n_skip + 1L
				self$skips[[length(self$skips) + 1L]] <- list(
					file = self$current_file,
					test = test %||% self$current_test,
					message = conditionMessage(result)
				)
			} else if (testthat:::expectation_warning(result)) {
				self$n_warn <- self$n_warn + 1L
				self$warnings[[length(self$warnings) + 1L]] <- list(
					file = self$current_file,
					test = test %||% self$current_test,
					message = conditionMessage(result)
				)
			} else {
				self$n_ok <- self$n_ok + 1L
			}
			self$draw()
		},

		end_reporter = function() {
			self$draw(force = TRUE)
			had_issues <- self$write_errors()
			self$write_timings()
			if (had_issues) {
				self$write_out(sprintf("test output can be found in %s\n", self$errors_path))
			}
		},

		# Full detail on every failure/warning/skip goes to a gitignored file,
		# not the screen -- the screen only ever shows the live pass/fail/warn/
		# skip tally (see draw()), so a run with many issues doesn't flood the
		# terminal with per-expectation messages the way testthat's own
		# reporters do.
		write_errors = function() {
			has_issues <- length(self$failures) > 0 || length(self$warnings) > 0 || length(self$skips) > 0
			if (!has_issues) {
				if (file.exists(self$errors_path)) file.remove(self$errors_path)
				return(invisible(FALSE))
			}
			con <- file(self$errors_path, open = "w")
			on.exit(close(con))
			write_section <- function(title, items) {
				if (length(items) == 0) return(invisible())
				cat(sprintf("%s (%d):\n", title, length(items)), file = con)
				for (item in items) {
					cat(sprintf("  [%s] %s\n", item$file, item$test), file = con)
					cat(sprintf("    %s\n", gsub("\n", "\n    ", item$message)), file = con)
				}
				cat("\n", file = con)
			}
			write_section("Failures", self$failures)
			write_section("Warnings", self$warnings)
			write_section("Skips", self$skips)
			cat(sprintf(
				"EDI R test suite -- %s (%ds elapsed) pass: %d fail: %d warn: %d skip: %d\n",
				format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
				round(as.numeric(difftime(Sys.time(), self$start_time, units = "secs"))),
				self$n_ok, self$n_fail, self$n_warn, self$n_skip
			), file = con)
			invisible(TRUE)
		},

		# Per-file wall-clock timings, slowest first. This is the data source for
		# drawing a fast/slow tier line in the pre-push suite: run once, then see
		# which files dominate the total. Written to the CWD (= R/EDI/tests, per
		# the header comment above); gitignored, never committed.
		write_timings = function() {
			if (length(self$file_timings) == 0) {
				return(invisible())
			}
			timings <- data.frame(
				file = vapply(self$file_timings, function(t) t$file, character(1)),
				elapsed_secs = vapply(self$file_timings, function(t) t$elapsed_secs, numeric(1))
			)
			timings <- timings[order(-timings$elapsed_secs), ]
			write.csv(timings, self$timings_path, row.names = FALSE)
			total <- sum(timings$elapsed_secs)
			top <- head(timings, 10)
			self$write_out(sprintf("Per-file timings (%d files, %.0fs total) written to %s\n",
				nrow(timings), total, self$timings_path))
			self$write_out(sprintf("Slowest files (top %d = %.0f%% of total):\n",
				nrow(top), 100 * sum(top$elapsed_secs) / max(total, .Machine$double.eps)))
			self$write_out(sprintf("  %8.1fs  %s\n", top$elapsed_secs, top$file), sep = "")
			self$write_out("\n")
		},

		draw = function(force = FALSE) {
			# A multi-line ANSI cursor-up + clear-line block was tried here
			# first, redrawing a fixed 4-line status in place. It depends on
			# nothing else writing to stdout between redraws and on
			# self$lines_drawn staying exactly in sync with what's on screen --
			# in practice (confirmed against a real interactive terminal, not
			# just a piped/non-tty context) it still desynced and produced new
			# scrolling lines instead of overwriting. Then switched to a
			# single line rewritten in place with a bare carriage return +
			# clear-line -- but that still broke, because test bodies and
			# package code (e.g. inference constructors' verbose=TRUE logging,
			# WIP test-helper debug cat()/print() calls, and
			# simulations_framework.R's own progress-bar/status helpers, which
			# write straight to stderr via cat(file = stderr())) share the
			# same streams and have no coordination with this reporter:
			# whatever they print lands wherever our cursor happens to be.
			# The actual fix is upstream of draw() -- the top-level script
			# sinks BOTH stdout and the message stream (which also redirects
			# explicit cat(file = stderr()) calls, not just message()/
			# warning()) to a log file for the run. Since that means even
			# stderr() itself is no longer safe for this reporter's own
			# output, self$out_con is a connection opened directly against
			# the OS-level stderr device before any sinking started (see the
			# bottom of this script), which sink() cannot redirect.
			# self$interactive_tty is likewise captured before sinking, since
			# sink() would otherwise make isatty(stdout()) report the log
			# file's tty-ness instead of the real terminal's.
			min_interval <- if (self$interactive_tty) 0.1 else 5
			now <- as.numeric(Sys.time())
			if (!force && (now - self$last_draw_time) < min_interval) {
				return(invisible())
			}
			self$last_draw_time <- now

			elapsed <- round(as.numeric(difftime(Sys.time(), self$start_time, units = "secs")))
			elapsed_fmt <- sprintf("%02d:%02d:%02d", elapsed %/% 3600, (elapsed %% 3600) %/% 60, elapsed %% 60)
			status <- if (force) "done" else "running"
			line <- sprintf(
				"EDI R test suite -- %s (%s elapsed) pass: %-6d fail: %-6d warn: %-6d skip: %-6d file: %s (i_test = %d)",
				status, elapsed_fmt, self$n_ok, self$n_fail, self$n_warn, self$n_skip, self$current_file, self$current_file_n_tests
			)
			if (self$interactive_tty) {
				self$write_out("\r\033[2K", line, if (force) "\n" else "", sep = "")
			} else {
				self$write_out(line, "\n", sep = "")
			}
		}
	)
)

# Captured before sinking starts: once stdout is sunk to a file connection,
# isatty(stdout()) would report the log file's tty-ness (always FALSE), not
# the real terminal's.
#
# isatty(stderr()) alone is not a reliable signal that "\r\033[2K"-based
# single-line redraws will actually render correctly: some terminal
# emulators/multiplexers/IDE-integrated terminals report a real tty but
# don't honor a bare trailing "\r" with no "\n" the way a raw pty does, so
# every intermediate "running" draw (which relies entirely on "\r" to reset
# the cursor for the next draw -- see draw() above, only the final "done"
# line gets a trailing "\n") ends up glued onto the next one with no visual
# separation at all instead of overwriting in place (seen in practice
# 2026-08-27: EDI_PREPUSH_PLAIN_PROGRESS wasn't needed to reproduce -- a
# real interactive shell still rendered every "running" update concatenated
# on one unbroken line). EDI_PREPUSH_PLAIN_PROGRESS=1 forces the safe
# newline-per-update fallback (the same path already used for genuinely
# non-interactive/CI output) regardless of what isatty() reports, for
# terminals where the "\r"-only redraw doesn't work.
interactive_tty <- isatty(stderr()) && Sys.getenv("EDI_PREPUSH_PLAIN_PROGRESS", "0") != "1"

# Test bodies and package code write chatter to stdout (cat()/print()),
# message()/warning(), and in simulations_framework.R's case, straight to
# stderr via cat(file = stderr()) for its own progress bars -- all with no
# coordination with this reporter's live status line, so left alone it lands
# wherever the reporter's cursor happens to be and breaks the
# single-line-in-place redraw (confirmed in practice: a first pass only
# sinking type="output" still let simulations_framework.R's stderr-targeted
# "Compressing results into a bz2 file..." messages through). Divert
# everything -- both sink types -- to a gitignored log file for the
# duration of the run. That also means stderr() itself is no longer a safe
# channel for this reporter's OWN output (a type="message" sink redirects
# explicit cat(file = stderr()) calls too, not just message()/warning()), so
# open a direct connection to the OS-level stderr device first, before any
# sinking starts -- sink() has no way to redirect that, since it isn't going
# through R's stdout()/stderr() connection objects at all.
stdout_log_path <- file.path(getwd(), ".prepush_test_stdout.log")
stdout_log_con <- file(stdout_log_path, open = "wt")
real_stderr_con <- tryCatch(file("/dev/stderr", open = "wt", raw = TRUE), error = function(e) NULL)
using_direct_stderr <- !is.null(real_stderr_con)
if (!using_direct_stderr) {
	# No /dev/stderr (e.g. native Windows R, not WSL) -- fall back to
	# stderr() itself. This reporter's output will then be vulnerable to the
	# same message-sink interaction described above, so skip sinking
	# type="message" in that case; type="output" alone (this reporter's own
	# writes are unaffected by that one) still covers plain cat()/print().
	real_stderr_con <- stderr()
}
reporter <- TallyReporter$new(interactive_tty = interactive_tty, out_con = real_stderr_con)
withr::local_envvar(TESTTHAT_IS_CHECKING = "true")

sink(stdout_log_con, type = "output")
if (using_direct_stderr) {
	sink(stdout_log_con, type = "message")
}

run_error <- tryCatch({
	testthat::test_dir("testthat", package = "EDI", reporter = reporter, load_package = "installed", stop_on_failure = FALSE)
	NULL
}, error = function(e) e)

if (using_direct_stderr) {
	sink(type = "message")
}
sink(type = "output")
close(stdout_log_con)
if (using_direct_stderr) {
	close(real_stderr_con)
}

if (!is.null(run_error)) {
	cat(sprintf(
		"EDI R test suite -- errored: %s (see %s for any diverted output)\n",
		conditionMessage(run_error), stdout_log_path
	), file = stderr())
	quit(status = 1, save = "no")
}

if (reporter$n_fail > 0) {
	quit(status = 1, save = "no")
}
quit(status = 0, save = "no")
