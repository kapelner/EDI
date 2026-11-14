#!/usr/bin/env Rscript
# Local pre-push-only R test runner. R CMD check (CI) still uses
# R/EDI/tests/testthat.R + testthat's CheckReporter unchanged -- this script
# is a separate entry point used only by scripts/pre-push, so that a local
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
		# Lane mode only (see "Parallel lanes" below): where this lane's running
		# tally goes for the coordinator to sum.
		status_path = NULL,
		n_files_done = 0L,
		last_status_time = 0,

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
			self$n_files_done <- self$n_files_done + 1L
			self$write_status(force = TRUE)
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

		write_status = function(force = FALSE) {
			if (is.null(self$status_path)) return(invisible())
			now <- as.numeric(Sys.time())
			if (!force && (now - self$last_status_time) < 1) return(invisible())
			self$last_status_time <- now
			tmp <- paste0(self$status_path, ".tmp")
			writeLines(paste(self$n_ok, self$n_fail, self$n_warn, self$n_skip, self$n_files_done), tmp)
			file.rename(tmp, self$status_path)
			invisible()
		},

		draw = function(force = FALSE) {
			self$write_status()
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
				# "\r\033[2K" only resets/clears the CURRENT physical terminal
				# row. This line easily runs 150+ characters (file names get
				# long) -- if it ever exceeds the terminal's actual column
				# width it wraps onto a second physical row, "\r" only
				# returns the cursor to the start of THAT second row (not the
				# true start of the logical line), and the next draw's
				# clear-and-redraw then only ever touches the second row,
				# permanently leaving a stale fragment of the first row's old
				# content sitting above it -- confirmed in practice
				# 2026-08-27: every redraw left a visible tail like "(i_tes"
				# glued in front of the next update. Truncating fixed it, but
				# NOT because the real terminal was too narrow -- it was 170
				# columns, wider than the ~160-character line, so a naive
				# "line exceeds the real terminal width" story doesn't fully
				# hold up on its own. What actually matters here is
				# getOption("width"): unlike an interactive R session,
				# Rscript never probes the tty's real column count and just
				# defaults this to 80 -- confirmed separately, same terminal,
				# same run -- so truncating to *that* (deliberately
				# conservative, always well under any real terminal width
				# worth supporting) rather than the tty's true width is the
				# actual fix, whatever R-level or terminal-level mechanism
				# was keying off the narrower number. One column of margin
				# avoids a same-width line still triggering auto-wrap on
				# some terminals.
				term_width <- getOption("width", 80L)
				if (nchar(line) > term_width - 1L) {
					line <- substr(line, 1L, term_width - 1L)
				}
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
# History (2026-08-27): "\r\033[2K"-based single-line redraws appeared to
# glue every "running" update onto the next one with no visual separation,
# even in a plain, verified-\r-capable interactive shell (isatty(stderr())
# TRUE). Root-caused via a minimal /dev/stderr-connection repro (ruled out
# the write mechanism/race) plus close reading of the glued text itself: a
# stray fragment like "(i_tes" from the END of one draw's line was showing
# up glued in FRONT of the next draw. "\r\033[2K" only resets/clears the
# CURRENT physical terminal row -- this line runs 150+ characters (file
# names get long), so once it exceeds the terminal's actual column width it
# wraps onto a second physical row, and the next draw's "\r"+clear then only
# ever touches that second row, permanently stranding the first row's old
# content above it. Real fix (see draw() above): truncate the line to the
# terminal's actual detected width so it can never wrap in the first place
# -- confirmed fixed in practice against the terminal that originally
# reproduced this. isatty(stderr()) is a fine signal once that's in place;
# no env var override needed.
interactive_tty <- isatty(stderr())

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
# --- Parallel lanes (2026-11-14) -------------------------------------------
# The suite's files are independent across processes (CI already runs them in
# 9-110 separate shard processes; none writes outside a tempfile or touches the
# network), so by default this script is a coordinator: it splits the files
# into EDI_PREPUSH_TEST_WORKERS lanes (default 4), runs each lane as its own
# Rscript of this same script (EDI_PREPUSH_TEST_LANE_DIR/_ID set), and merges
# their tallies into the usual live line, .prepush_errors and timings CSV.
#   * Files that start real workers (fork clusters, mirai daemons,
#     set_num_cores(), num_cores >= 2) all run in lane 1, in the usual
#     alphabetical order: test-aa-fork-* must start fork clusters before any
#     file starts mirai in that process, and fork/mirai inside several
#     concurrent lanes would oversubscribe the machine.
#   * Every other file is placed by longest-first scheduling on the previous
#     run's prepush_test_timings.csv.
#   * Lanes keep EDI's default threading: set_package_threads(1) also sets
#     OMP_THREAD_LIMIT, which caps every later OpenMP team in that process and
#     broke test-omp-kernel-thread-count-scoped.R and the warm-start dispatch
#     test (tried 2026-11-14).
#   * A file that should never share a run with others can opt into lane 1
#     with a "# prepush-lane: worker" line.
# EDI_PREPUSH_TEST_WORKERS=1 runs everything in this one process, as before.
`%||%` <- function(x, y) if (is.null(x)) y else x
lane_dir <- Sys.getenv("EDI_PREPUSH_TEST_LANE_DIR", "")
lane_id <- Sys.getenv("EDI_PREPUSH_TEST_LANE_ID", "")
is_lane <- nzchar(lane_dir) && nzchar(lane_id)
# Default: 4 lanes, but never more than the machine's physical cores, and one
# (the old single-process run) without processx, which launches the lanes.
default_workers <- min(4L, max(1L, suppressWarnings(parallel::detectCores(logical = FALSE)), na.rm = TRUE))
n_workers <- suppressWarnings(as.integer(Sys.getenv("EDI_PREPUSH_TEST_WORKERS", as.character(default_workers))))
if (is.na(n_workers) || n_workers < 1L) n_workers <- 1L
if (n_workers > 1L && !requireNamespace("processx", quietly = TRUE)) {
	message(sprintf(paste0(
		"run_prepush_r_tests: processx is not installed, so the R suite runs in one process.\n",
		"run_prepush_r_tests: install it to run it in %d parallel lanes (about 2-3x faster): ",
		"install.packages(\"processx\")"), n_workers))
	n_workers <- 1L
}
script_path <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))

# pre-push already ran scripts/run_structural_checks.R and it passed: skip
# those files here instead of running them twice (~75 s).
skip_structural <- identical(Sys.getenv("EDI_PREPUSH_STRUCTURAL_PASSED"), "1")
structural_files <- character()
if (skip_structural) {
	source(file.path(dirname(script_path), "structural_check_files.R"))
	structural_files <- basename(structural_check_files)
}
files_filter <- function(names) {
	if (!length(names)) return("^$")
	stems <- sub("^test[-_]", "", sub("[.][Rr]$", "", basename(names)))
	paste0("(^|/)(test[-_])?(", paste(gsub("([.\\\\+*?^$()|{}\\[\\]])", "\\\\\\1", stems), collapse = "|"), ")$")
}
worker_lane_rx <- "set_num_cores\\(|num_cores\\s*=\\s*[2-9]|mirai|daemons\\(|mclapply|makeCluster|makeForkCluster|parLapply|fork|callr::|future::|prepush-lane:\\s*worker"
needs_worker_lane <- function(path) {
	lines <- readLines(path, warn = FALSE)
	if (any(grepl("^\\s*#\\s*prepush-lane:\\s*worker", lines))) return(TRUE)
	grepl(worker_lane_rx, paste(lines[!grepl("^\\s*#", lines)], collapse = "\n"), perl = TRUE)
}

withr::local_envvar(TESTTHAT_IS_CHECKING = "true")

if (is_lane) {
	# ---- One lane: run its files, save the tallies for the coordinator. ----
	lane_files <- readLines(file.path(lane_dir, sprintf("lane_%s.files", lane_id)))
	progress_con <- file(file.path(lane_dir, sprintf("lane_%s.progress", lane_id)), open = "wt")
	reporter <- TallyReporter$new(interactive_tty = FALSE, out_con = progress_con)
	reporter$timings_path <- file.path(lane_dir, sprintf("lane_%s_timings.csv", lane_id))
	reporter$errors_path <- file.path(lane_dir, sprintf("lane_%s_errors", lane_id))
	reporter$status_path <- file.path(lane_dir, sprintf("lane_%s.status", lane_id))
	run_error <- tryCatch({
		testthat::test_dir("testthat", package = "EDI", reporter = reporter, load_package = "installed",
			stop_on_failure = FALSE, filter = files_filter(lane_files))
		NULL
	}, error = function(e) e)
	reporter$write_status(force = TRUE)
	saveRDS(list(
		n_ok = reporter$n_ok, n_fail = reporter$n_fail, n_warn = reporter$n_warn, n_skip = reporter$n_skip,
		failures = reporter$failures, warnings = reporter$warnings, skips = reporter$skips,
		file_timings = reporter$file_timings,
		error = if (is.null(run_error)) NULL else conditionMessage(run_error)
	), file.path(lane_dir, sprintf("lane_%s.rds", lane_id)))
	close(progress_con)
	quit(status = 0, save = "no")
}

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

sink(stdout_log_con, type = "output")
if (using_direct_stderr) {
	sink(stdout_log_con, type = "message")
}

all_files <- basename(testthat:::find_test_scripts("testthat"))
run_files <- setdiff(all_files, structural_files)

run_serial <- function() {
	tryCatch({
		testthat::test_dir("testthat", package = "EDI", reporter = reporter, load_package = "installed", stop_on_failure = FALSE,
			filter = if (length(structural_files)) files_filter(structural_files) else NULL, invert = length(structural_files) > 0L)
		NULL
	}, error = function(e) e)
}

# Lanes start from this process's environment as it was at launch, not as it
# is now: library(EDI) above ran set_package_threads(), which exported
# OMP_THREAD_LIMIT=1/OMP_NUM_THREADS=1 here, and lanes inheriting those could
# not start a 2-thread OpenMP team (test-omp-kernel-thread-count-scoped.R
# failed only in lanes, 2026-11-14). /proc/self/environ holds the launch-time
# environment on Linux; elsewhere fall back to the current one.
lane_base_env <- function() {
	raw <- tryCatch(readBin("/proc/self/environ", "raw", 1e7), error = function(e) raw())
	if (!length(raw)) return(c("current"))
	ends <- which(raw == as.raw(0))
	starts <- c(1L, utils::head(ends, -1L) + 1L)
	kv <- vapply(seq_along(ends), function(k) rawToChar(raw[starts[k]:(ends[k] - 1L)]), character(1))
	kv <- kv[grepl("=", kv, fixed = TRUE)]
	stats::setNames(sub("^[^=]*=", "", kv), sub("=.*$", "", kv))
}

run_lanes <- function() {
	timings_csv <- file.path(getwd(), "prepush_test_timings.csv")
	est <- setNames(rep(NA_real_, length(run_files)), run_files)
	if (file.exists(timings_csv)) {
		prev <- tryCatch(utils::read.csv(timings_csv, stringsAsFactors = FALSE), error = function(e) NULL)
		if (!is.null(prev)) est[] <- prev$elapsed_secs[match(run_files, prev$file)]
	}
	est[is.na(est)] <- if (any(!is.na(est))) stats::median(est, na.rm = TRUE) else 1
	worker <- run_files[vapply(file.path("testthat", run_files), needs_worker_lane, logical(1))]
	others <- setdiff(run_files, worker)
	n_lanes <- max(1L, min(n_workers, length(others) + 1L))
	lanes <- vector("list", n_lanes); lanes[[1]] <- worker
	load <- numeric(n_lanes); load[1] <- sum(est[worker])
	for (f in others[order(-est[others])]) {
		i <- which.min(load)
		lanes[[i]] <- c(lanes[[i]], f)
		load[i] <- load[i] + est[[f]]
	}
	dir <- tempfile("edi-prepush-lanes-"); dir.create(dir)
	procs <- list()
	for (i in seq_len(n_lanes)) {
		writeLines(sort(lanes[[i]]), file.path(dir, sprintf("lane_%d.files", i)))
		procs[[i]] <- processx::process$new(
			file.path(R.home("bin"), "Rscript"), script_path,
			env = c(lane_base_env(), EDI_PREPUSH_TEST_LANE_DIR = dir, EDI_PREPUSH_TEST_LANE_ID = as.character(i)),
			stdout = file.path(dir, sprintf("lane_%d.stdout", i)), stderr = "2>&1",
			cleanup = TRUE, cleanup_tree = TRUE, supervise = TRUE
		)
	}
	reporter$write_out(sprintf("EDI R test suite: %d files in %d parallel lanes (lane 1 = %d worker-starting files; estimated %s s)\n",
		length(run_files), n_lanes, length(worker), paste(round(load), collapse = "/")))
	read_status <- function(i) {
		p <- file.path(dir, sprintf("lane_%d.status", i))
		v <- if (file.exists(p)) suppressWarnings(as.integer(strsplit(readLines(p, warn = FALSE)[1] %||% "", " ")[[1]])) else integer()
		if (length(v) == 5L && !anyNA(v)) v else c(0L, 0L, 0L, 0L, 0L)
	}
	repeat {
		alive <- vapply(procs, function(p) p$is_alive(), logical(1))
		st <- Reduce(`+`, lapply(seq_len(n_lanes), read_status))
		reporter$n_ok <- st[1]; reporter$n_fail <- st[2]; reporter$n_warn <- st[3]; reporter$n_skip <- st[4]
		reporter$current_file <- sprintf("%d/%d files, %d/%d lanes running", st[5], length(run_files), sum(alive), n_lanes)
		reporter$current_file_n_tests <- 0L
		reporter$draw()
		if (!any(alive)) break
		Sys.sleep(0.25)
	}
	merged <- list(n_ok = 0L, n_fail = 0L, n_warn = 0L, n_skip = 0L, failures = list(), warnings = list(), skips = list(), file_timings = list())
	for (i in seq_len(n_lanes)) {
		rds <- file.path(dir, sprintf("lane_%d.rds", i))
		res <- if (file.exists(rds)) readRDS(rds) else NULL
		if (is.null(res) || !is.null(res$error)) {
			done <- if (is.null(res)) character() else vapply(res$file_timings, function(t) t$file, character(1))
			out <- file.path(dir, sprintf("lane_%d.stdout", i))
			tail_txt <- if (file.exists(out)) paste(utils::tail(readLines(out, warn = FALSE), 15), collapse = "\n") else ""
			merged$failures[[length(merged$failures) + 1L]] <- list(
				file = sprintf("lane %d", i),
				test = if (is.null(res)) sprintf("lane process exited (status %s) before reporting", procs[[i]]$get_exit_status()) else "test_dir() errored",
				message = paste0(res$error %||% "", "\nfiles not completed: ", paste(setdiff(lanes[[i]], done), collapse = ", "), "\n", tail_txt)
			)
			merged$n_fail <- merged$n_fail + 1L
		}
		if (is.null(res)) next
		for (k in c("n_ok", "n_fail", "n_warn", "n_skip")) merged[[k]] <- merged[[k]] + res[[k]]
		for (k in c("failures", "warnings", "skips", "file_timings")) merged[[k]] <- c(merged[[k]], res[[k]])
	}
	by_file <- function(items) items[order(vapply(items, function(x) x$file, character(1)))]
	reporter$n_ok <- merged$n_ok; reporter$n_fail <- merged$n_fail; reporter$n_warn <- merged$n_warn; reporter$n_skip <- merged$n_skip
	reporter$failures <- by_file(merged$failures); reporter$warnings <- by_file(merged$warnings); reporter$skips <- by_file(merged$skips)
	reporter$file_timings <- merged$file_timings
	reporter$current_file <- sprintf("%d files, %d lanes", length(merged$file_timings), n_lanes)
	# One combined diverted-output log, lane by lane, like the serial run's.
	for (i in seq_len(n_lanes)) {
		out <- file.path(dir, sprintf("lane_%d.stdout", i))
		cat(sprintf("===== lane %d: %s\n", i, paste(sort(lanes[[i]]), collapse = " ")), file = stdout_log_con)
		if (file.exists(out)) writeLines(readLines(out, warn = FALSE), stdout_log_con)
	}
	unlink(dir, recursive = TRUE)
	reporter$end_reporter()
	NULL
}

run_error <- if (n_workers > 1L) tryCatch(run_lanes(), error = function(e) e) else run_serial()

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
