#!/usr/bin/env Rscript
# Runs one job of a cloud comprehensive-study wave (.github/workflows/comprehensive-study.yml,
# release_v1_1_0.md TODO-194): the job's processes in parallel, each running its calls of
# comprehensive_tests.R in order, one Rscript per call. Each call writes into its own
# <out-dir>/<call_id>/ (EDI_COMPREHENSIVE_RESULTS_DIR) and, if the runner exits 0, a DONE file
# (call_id, seconds, exit status); analyze takes rows only from calls with DONE. A process
# starts no new call after --deadline-minutes, so the job ends near the planned length; calls
# not started stay undone and are re-planned next wave.
#
# A class, method, dataset and design that has hit the per-call timeout --skip-after-timeouts
# times (default 3) is skipped for its remaining reps, across every call of the wave: the counts
# live in <out-dir>/../timeout_counts/ (COMPREHENSIVE_TIMEOUT_COUNTS_DIR, comprehensive_tests.R).
# 0 turns the skip off.
#
# Usage: run_comprehensive_shard.R --plan plan.csv --job <k> --out-dir <dir> --reps <R> \
#          [--deadline-minutes 30] [--repo <checkout root>] [--skip-after-timeouts 3]

suppressPackageStartupMessages(library(data.table))
args = commandArgs(trailingOnly = TRUE)
opt = list(plan = NULL, job = NULL, out_dir = NULL, reps = NULL, deadline_minutes = "30", repo = ".", skip_after_timeouts = "3")
for (i in seq(1L, length(args), by = 2L)) opt[[gsub("-", "_", sub("^--", "", args[[i]]))]] = args[[i + 1L]]
if (is.null(opt$plan) || is.null(opt$job) || is.null(opt$out_dir) || is.null(opt$reps)) stop("--plan, --job, --out-dir and --reps are required")
plan = fread(opt$plan, colClasses = c(reps = "character", class_regex = "character", exclude_regex = "character"))
plan = plan[job == as.integer(opt$job)]
if (!nrow(plan)) { cat("job", opt$job, "has no calls\n"); quit(status = 0L) }
dir.create(opt$out_dir, recursive = TRUE, showWarnings = FALSE)
runner = file.path(normalizePath(opt$repo), "R", "package_tests", "comprehensive_tests.R")
deadline = Sys.time() + as.numeric(opt$deadline_minutes) * 60
timeout_counts_dir = file.path(dirname(normalizePath(opt$out_dir)), "timeout_counts")

run_proc = function(calls) {
	for (i in seq_len(nrow(calls))) {
		cl = calls[i]
		if (Sys.time() > deadline) { cat(sprintf("deadline: %s not started\n", cl$call_id)); next }
		d = file.path(opt$out_dir, cl$call_id); dir.create(d, recursive = TRUE, showWarnings = FALSE)
		# system2() puts env entries on a shell command line: quote the values (the regexes hold ( | ) ).
		env = c(sprintf("EDI_COMPREHENSIVE_RESULTS_DIR=%s", shQuote(normalizePath(d))), "EDI_COMPREHENSIVE_SKIP_PRUNE_CHECK=1",
			sprintf("COMPREHENSIVE_INFERENCE_CLASS_EXCLUDE=%s", shQuote(if (is.na(cl$exclude_regex)) "" else cl$exclude_regex)),
			sprintf("COMPREHENSIVE_SKIP_REPEAT_AFTER_TIMEOUT=%s", shQuote(opt$skip_after_timeouts)),
			sprintf("COMPREHENSIVE_TIMEOUT_COUNTS_DIR=%s", shQuote(timeout_counts_dir)))
		cargs = c(runner, opt$reps, "1", cl$response_type, cl$design, if (is.na(cl$class_regex)) "NA" else cl$class_regex,
			cl$dataset, format(cl$beta_T), cl$reps)
		t0 = Sys.time()
		st = system2("Rscript", shQuote(cargs), env = env, stdout = file.path(d, "log.txt"), stderr = file.path(d, "log.txt"))
		secs = round(as.numeric(difftime(Sys.time(), t0, units = "secs")))
		cat(sprintf("%s: exit %d after %d s\n", cl$call_id, st, secs))
		if (identical(as.integer(st), 0L)) {
			writeLines(sprintf("call_id=%s\nseconds=%d\nexit=0", cl$call_id, secs), file.path(d, "DONE"))
		}
	}
	invisible(TRUE)
}

procs = split(plan[order(proc, seq)], by = "proc")
jobs = lapply(procs, function(calls) parallel::mcparallel(run_proc(calls)))
invisible(parallel::mccollect(jobs))
done = length(Sys.glob(file.path(opt$out_dir, "*", "DONE")))
cat(sprintf("job %s: %d of %d calls done\n", opt$job, done, nrow(plan)))
