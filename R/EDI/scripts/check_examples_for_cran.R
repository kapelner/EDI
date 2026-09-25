#!/usr/bin/env Rscript
# Pre-submission check of every Rd example, for the CRAN reviewer comments
# R CMD check itself does not fail on:
#   - any \dontrun{} (CRAN: only for code that genuinely cannot run, e.g.
#     missing API keys; otherwise unwrap it or use \donttest{}),
#   - "Unexecutable code in man/X.Rd" (e.g. a \donttest{} nested inside a
#     \dontrun{}), which is only a WARNING in R CMD check,
#   - examples that are slow: CRAN wants each Rd file's examples to run in
#     < 5 s, and the NOTE they trigger is not an ERROR in R CMD check.
#
# Usage:
#   Rscript check_examples_for_cran.R <pkg_dir> --static-only
#   Rscript check_examples_for_cran.R <pkg_dir> [--lib <library containing the EDI build to test>]
#   Rscript check_examples_for_cran.R <pkg_dir> --load-all   (dev: test the source tree via
#     pkgload::load_all(compile = FALSE) -- never compiles; needs an already-built src/*.so)
#
# --static-only does only the \dontrun / parse checks (no package needed, a few
# seconds). Otherwise every Rd file's examples are also run, in one R session
# in alphabetical order the way R CMD check runs them, twice:
#   1. without \donttest{} code (what CRAN times): must not error, and must
#      stay under EDI_EXAMPLE_TIME_LIMIT seconds (default 2.5 -- deliberately
#      well under CRAN's 5 s, since CRAN's machines are slower than a dev box)
#      in both elapsed and CPU (user + system) time, and must not use more than
#      2.5x as much CPU as elapsed time (CRAN's parallelism NOTE);
#   2. with \donttest{} code (what --as-cran's --run-donttest pass runs):
#      must not error; the time is reported but not limited, since running
#      longer is exactly what \donttest{} is for.
# In both runs an example must also leave options(), the working directory and
# the objects in .GlobalEnv unchanged (CRAN policy; see also
# check_global_state_for_cran.R).
# Exits non-zero, listing every problem, if anything fails.

args = commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) stop("usage: check_examples_for_cran.R <pkg_dir> [--static-only] [--lib <path>]")
pkg_dir = args[1]
static_only = "--static-only" %in% args
lib = if ("--lib" %in% args) args[which(args == "--lib") + 1L] else NULL
load_all = "--load-all" %in% args
time_limit = as.numeric(Sys.getenv("EDI_EXAMPLE_TIME_LIMIT", "2.5"))
cpu_to_elapsed_limit = 2.5

rd_files = sort(list.files(file.path(pkg_dir, "man"), pattern = "\\.Rd$", full.names = TRUE))
if (!length(rd_files)) stop("no Rd files found under ", file.path(pkg_dir, "man"))
problems = character()

rd_tags = function(x) {
	c(attr(x, "Rd_tag"), if (is.list(x)) unlist(lapply(x, rd_tags), use.names = FALSE))
}
example_file = function(rd, run_donttest) {
	tf = tempfile(fileext = ".R")
	# commentDontrun = FALSE so the parse check sees \dontrun{} code too, the way
	# R CMD check's "Unexecutable code" check does
	tools::Rd2ex(rd, tf, commentDontrun = FALSE, commentDonttest = !run_donttest)
	if (file.exists(tf)) tf else NULL
}

## ---- static checks ----------------------------------------------------------
cat("Static checks of", length(rd_files), "Rd files: no \\dontrun{}, all example code parses\n")
rds = list()
for (f in rd_files) {
	rd = tools::parse_Rd(f)
	rds[[f]] = rd
	if ("\\dontrun" %in% rd_tags(rd)) {
		problems = c(problems, sprintf("%s: uses \\dontrun{} -- unwrap it if it runs in < 5 s, else use \\donttest{}", basename(f)))
	}
	for (run_donttest in c(FALSE, TRUE)) {
		tf = example_file(rd, run_donttest)
		if (is.null(tf)) next
		err = tryCatch({parse(tf); NULL}, error = conditionMessage)
		if (!is.null(err)) {
			problems = c(problems, sprintf("%s: unparseable example code%s (\"Unexecutable code\" on CRAN): %s",
				basename(f), if (run_donttest) " with \\donttest{} included" else "", err))
			break
		}
	}
}
# the Rd files are generated -- also catch a \dontrun{} that a stale man/ hides
src = list.files(file.path(pkg_dir, "R"), pattern = "\\.[Rr]$", full.names = TRUE)
for (f in src) {
	hits = grep("^\\s*#'.*\\\\dontrun\\{", readLines(f, warn = FALSE))
	for (h in hits) problems = c(problems, sprintf("R/%s:%d: roxygen @examples uses \\dontrun{}", basename(f), h))
}

## ---- timed runs --------------------------------------------------------------
if (!static_only && !length(problems)) {
	if (!is.null(lib)) .libPaths(c(lib, .libPaths()))
	if (load_all) {
		suppressMessages(pkgload::load_all(pkg_dir, compile = FALSE, quiet = TRUE))
	} else {
		suppressPackageStartupMessages(library(EDI))
	}
	cat("Running examples with EDI", format(packageVersion("EDI")), "from", dirname(find.package("EDI")), "\n")
	grDevices::pdf(NULL)
	run_one = function(tf) {
		env = new.env(parent = globalenv())
		# examples' printed output, messages and progress bars are noise here;
		# only errors and timings matter
		msg_sink = file(nullfile(), open = "wt")
		sink(msg_sink, type = "message")
		on.exit({sink(type = "message"); close(msg_sink)})
		opts0 = options(); wd0 = getwd(); globals0 = ls(globalenv(), all.names = TRUE)
		t0 = proc.time()
		err = tryCatch({
			utils::capture.output(source(tf, local = env, echo = FALSE, print.eval = TRUE))
			NULL
		}, error = conditionMessage)
		dt = proc.time() - t0
		opts1 = options()
		# 2026-09-25: options set as an unavoidable side effect of loading a Suggests
		# package for the FIRST time in this session -- not something any example's own
		# code sets or could clean up (confirmed: `requireNamespace("nbpMatching", quietly
		# = TRUE)` alone, with no EDI code involved at all, sets callr.condition_handler_
		# cli_message on first load, via nbpMatching's own dependency chain). Whichever
		# Rd file happens to be the first alphabetically to touch such a package in this
		# run's single R session is where the diff would otherwise land, which is a
		# false positive about EDI's own example code, not a real CRAN global-state
		# policy violation (that policy targets an example's own options(...) calls that
		# it forgets to restore, not a dependency's internal namespace-load bootstrap).
		known_benign_package_load_options = c("callr.condition_handler_cli_message")
		changed = c(
			setdiff(union(setdiff(names(opts1), names(opts0)), names(opts0)[!mapply(identical, opts0, opts1[names(opts0)])]), known_benign_package_load_options),
			if (!identical(getwd(), wd0)) "the working directory",
			setdiff(union(globals0, ls(globalenv(), all.names = TRUE)), intersect(globals0, ls(globalenv(), all.names = TRUE)))
		)
		# undo it so one offending example doesn't cascade into the rest of the run
		options(opts0); setwd(wd0)
		list(err = err, changed = changed, elapsed = dt[["elapsed"]], cpu = sum(dt[c(1L, 2L, 4L, 5L)], na.rm = TRUE))
	}
	timings = data.frame(rd = character(), elapsed = numeric(), cpu = numeric(), donttest_elapsed = numeric())
	for (f in rd_files) {
		tf = example_file(rds[[f]], run_donttest = FALSE)
		if (is.null(tf)) next
		name = basename(f)
		# progress line, so a crash or hang shows which Rd file it happened in
		cat(sprintf("  %-55s", name)); flush(stdout())
		r = run_one(tf)
		if (length(r$changed)) {
			problems = c(problems, sprintf("%s: example changes the user's global state (options()/working directory/.GlobalEnv): %s",
				name, paste(r$changed, collapse = ", ")))
		}
		if (!is.null(r$err)) {
			problems = c(problems, sprintf("%s: example errors: %s", name, r$err))
		} else {
			if (r$elapsed > time_limit || r$cpu > time_limit) {
				problems = c(problems, sprintf("%s: examples take %.2fs elapsed / %.2fs CPU (limit %.1fs) -- shrink them or move the slow part into \\donttest{}",
					name, r$elapsed, r$cpu, time_limit))
			}
			if (r$cpu >= 1 && r$cpu > cpu_to_elapsed_limit * r$elapsed) {
				problems = c(problems, sprintf("%s: examples use %.2fs CPU in %.2fs elapsed (> %.1fx) -- too much parallelism for CRAN",
					name, r$cpu, r$elapsed, cpu_to_elapsed_limit))
			}
		}
		dt_elapsed = NA_real_
		if ("\\donttest" %in% rd_tags(rds[[f]])) {
			d = run_one(example_file(rds[[f]], run_donttest = TRUE))
			if (!is.null(d$err)) problems = c(problems, sprintf("%s: example errors with \\donttest{} included: %s", name, d$err))
			if (length(d$changed)) {
				problems = c(problems, sprintf("%s: example (with \\donttest{} included) changes the user's global state: %s",
					name, paste(d$changed, collapse = ", ")))
			}
			dt_elapsed = d$elapsed
		}
		timings[nrow(timings) + 1L, ] = list(name, r$elapsed, r$cpu, dt_elapsed)
		cat(sprintf("%6.2fs%s%s\n", r$elapsed,
			if (is.na(dt_elapsed)) "" else sprintf("  (with \\donttest{}: %.2fs)", dt_elapsed),
			if (!is.null(r$err)) "  ERROR" else if (length(r$changed)) "  CHANGES GLOBAL STATE" else if (max(r$elapsed, r$cpu) > time_limit) "  TOO SLOW" else ""))
	}
	grDevices::dev.off()
	cat(sprintf("\nRan examples of %d Rd files; slowest (seconds; limit %.1f, donttest_elapsed = with \\donttest{} code, unlimited):\n",
		nrow(timings), time_limit))
	print(utils::head(timings[order(-pmax(timings$elapsed, timings$cpu)), ], 15L), row.names = FALSE, digits = 3)
}

if (length(problems)) {
	cat("\nERROR: ", length(problems), " example problem(s) that CRAN will flag:\n", sep = "", file = stderr())
	cat(paste0("  - ", problems, "\n"), sep = "", file = stderr())
	quit(status = 1L)
}
cat("\nOK: no \\dontrun{}, all example code parses",
	if (!static_only) sprintf(", and every Rd file's examples run under %.1fs", time_limit), "\n", sep = "")
