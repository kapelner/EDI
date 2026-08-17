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
		current_file = "",
		current_test = "",
		start_time = NULL,
		file_start_time = NULL,
		file_timings = list(),
		timings_path = NULL,
		last_draw_time = 0,
		lines_drawn = 0L,
		dynamic = TRUE,

		initialize = function(...) {
			super$initialize(...)
			self$start_time <- Sys.time()
			self$dynamic <- isTRUE(isatty(stdout()))
			# Resolved now, while cwd is still R/EDI/tests: test_dir() setwd()s
			# into testthat/ before end_reporter fires, so a relative path there
			# would land one directory too deep.
			self$timings_path <- file.path(getwd(), "prepush_test_timings.csv")
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
			} else if (testthat:::expectation_warning(result)) {
				self$n_warn <- self$n_warn + 1L
			} else {
				self$n_ok <- self$n_ok + 1L
			}
			self$draw()
		},

		end_reporter = function() {
			self$draw(force = TRUE)
			if (length(self$failures) > 0) {
				cat("\nFailures:\n")
				for (f in self$failures) {
					cat(sprintf("  [%s] %s\n", f$file, f$test))
					cat(sprintf("    %s\n", gsub("\n", "\n    ", f$message)))
				}
			}
			cat("\n")
			self$write_timings()
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
			now <- as.numeric(Sys.time())
			# Throttle redraws to ~10/sec so the terminal isn't hammered on a
			# fast-passing suite; always draw on the final (force) call.
			if (!force && (now - self$last_draw_time) < 0.1) {
				return(invisible())
			}
			self$last_draw_time <- now

			elapsed <- round(as.numeric(difftime(Sys.time(), self$start_time, units = "secs")))
			status <- if (force) "done" else "running"
			lines <- c(
				sprintf("EDI R test suite -- %s (%ds elapsed)", status, elapsed),
				sprintf("  pass: %-6d fail: %-6d warn: %-6d skip: %-6d", self$n_ok, self$n_fail, self$n_warn, self$n_skip),
				sprintf("  file: %s", self$current_file),
				sprintf("  test: %s", self$current_test)
			)

			if (self$dynamic) {
				if (self$lines_drawn > 0) {
					cat(sprintf("\033[%dA", self$lines_drawn))
				}
				for (l in lines) cat("\033[2K", l, "\n", sep = "")
				self$lines_drawn <- length(lines)
			} else {
				# Non-tty output (e.g. redirected to a log file): a fresh block
				# every ~2s instead of per-test/per-file lines.
				if (force || (now - private$last_static_draw) >= 2) {
					cat(paste(lines, collapse = "\n"), "\n\n", sep = "")
					private$last_static_draw <- now
				}
			}
		}
	),
	private = list(
		last_static_draw = 0
	)
)

reporter <- TallyReporter$new()
withr::local_envvar(TESTTHAT_IS_CHECKING = "true")
testthat::test_dir("testthat", package = "EDI", reporter = reporter, load_package = "installed", stop_on_failure = FALSE)

if (reporter$n_fail > 0) {
	quit(status = 1, save = "no")
}
quit(status = 0, save = "no")
