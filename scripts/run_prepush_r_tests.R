#!/usr/bin/env Rscript
# Local pre-push-only R test runner. R CMD check (CI) still uses
# R/EDI/tests/testthat.R + testthat's CheckReporter unchanged -- this script
# is a separate entry point used only by .githooks/pre-push, so that a local
# push isn't stuck watching one line scroll by per test file (or, worse, one
# line per failing expectation via testthat's _problems/ extraction). It
# reports a fixed 4-line block that redraws in place instead.
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
		current_test = "",
		start_time = NULL,
		file_start_time = NULL,
		file_timings = list(),
		timings_path = NULL,
		errors_path = NULL,
		last_draw_time = 0,
		lines_drawn = 0L,

		initialize = function(...) {
			super$initialize(...)
			self$start_time <- Sys.time()
			# Resolved now, while cwd is still R/EDI/tests: test_dir() setwd()s
			# into testthat/ before end_reporter fires, so a relative path there
			# would land one directory too deep.
			self$timings_path <- file.path(getwd(), "prepush_test_timings.csv")
			self$errors_path <- file.path(getwd(), ".prepush_errors")
		},

		start_file = function(filename) {
			self$current_file <- filename
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
			self$write_errors()
			self$write_timings()
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
				return(invisible())
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
			cat(sprintf("Per-file timings (%d files, %.0fs total) written to %s\n",
				nrow(timings), total, self$timings_path))
			cat(sprintf("Slowest files (top %d = %.0f%% of total):\n",
				nrow(top), 100 * sum(top$elapsed_secs) / max(total, .Machine$double.eps)))
			cat(sprintf("  %8.1fs  %s\n", top$elapsed_secs, top$file), sep = "")
			cat("\n")
		},

		draw = function(force = FALSE) {
			# ANSI cursor-up + clear-line redraw-in-place only works when
			# something is actually interpreting the escape codes. When stdout
			# isn't a real tty (piped through a tool harness, redirected to a
			# log file, etc.) those bytes are printed literally and every
			# throttled draw() call becomes 4 new scrolling lines instead of
			# overwriting -- exactly the flood this reporter was meant to
			# avoid. Fall back to an infrequent, single-line, non-ANSI
			# heartbeat in that case.
			interactive_tty <- isatty(stdout())
			min_interval <- if (interactive_tty) 0.1 else 5
			now <- as.numeric(Sys.time())
			if (!force && (now - self$last_draw_time) < min_interval) {
				return(invisible())
			}
			self$last_draw_time <- now

			elapsed <- round(as.numeric(difftime(Sys.time(), self$start_time, units = "secs")))
			status <- if (force) "done" else "running"

			if (!interactive_tty) {
				cat(sprintf(
					"EDI R test suite -- %s (%ds elapsed) pass: %d fail: %d warn: %d skip: %d file: %s\n",
					status, elapsed, self$n_ok, self$n_fail, self$n_warn, self$n_skip, self$current_file
				))
				return(invisible())
			}

			lines <- c(
				sprintf("EDI R test suite -- %s (%ds elapsed)", status, elapsed),
				sprintf("  pass: %-6d fail: %-6d warn: %-6d skip: %-6d", self$n_ok, self$n_fail, self$n_warn, self$n_skip),
				sprintf("  file: %s", self$current_file),
				sprintf("  test: %s", self$current_test)
			)

			# Redraw the same fixed 4-line block in place via ANSI cursor-up +
			# clear-line.
			if (self$lines_drawn > 0) {
				cat(sprintf("\033[%dA", self$lines_drawn))
			}
			for (l in lines) cat("\033[2K", l, "\n", sep = "")
			self$lines_drawn <- length(lines)
		}
	)
)

reporter <- TallyReporter$new()
withr::local_envvar(TESTTHAT_IS_CHECKING = "true")
testthat::test_dir("testthat", package = "EDI", reporter = reporter, load_package = "installed", stop_on_failure = FALSE)

if (reporter$n_fail > 0) {
	quit(status = 1, save = "no")
}
quit(status = 0, save = "no")
