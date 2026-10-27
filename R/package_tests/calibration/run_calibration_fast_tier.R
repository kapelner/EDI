#!/usr/bin/env Rscript
# One shard of the scheduled CI calibration fast tier (design:
# R/package_metadata/new_feature_plans/calibration_gates.md). Runs null
# replicates (sharp null, see calibration_fast_tier_common.R) for one response
# type at one n, and writes one row per (replicate, class, formula, method) to
# <out-dir>/rows.csv. analyze_calibration_fast_tier.R merges the shards and
# applies the size/coverage tests.
#
# Usage: Rscript R/package_tests/calibration/run_calibration_fast_tier.R \
#          --response-type count --n 200 --reps 1:250 --out-dir DIR \
#          [--cores 4] [--only InferenceCountKKGLMM] [--exclude InferenceCountKKGLMM]
#
# --only / --exclude take comma-separated class names; plan_calibration_fast_tier.R
# uses them to give a slow class its own shards. Uses the INSTALLED EDI.

suppressPackageStartupMessages(library(EDI))

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
source(file.path(script_dir, "calibration_fast_tier_common.R"))

args <- commandArgs(TRUE)
arg_value <- function(flag, default = NULL) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
split_csv <- function(x) if (is.null(x) || !nzchar(x)) character() else trimws(strsplit(x, ",", fixed = TRUE)[[1L]])

response_type <- arg_value("--response-type")
n <- as.integer(arg_value("--n", "200"))
rep_range <- as.integer(strsplit(arg_value("--reps", "1:10"), ":", fixed = TRUE)[[1L]])
reps <- seq.int(rep_range[[1L]], rep_range[[length(rep_range)]])
out_dir <- arg_value("--out-dir")
cores <- as.integer(arg_value("--cores", "1"))
only <- split_csv(arg_value("--only"))
exclude <- split_csv(arg_value("--exclude"))
if (is.null(response_type) || !response_type %in% CAL_RESPONSE_TYPES) stop("--response-type must be one of ", paste(CAL_RESPONSE_TYPES, collapse = ", "))
if (is.null(out_dir)) stop("--out-dir is required")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

plan <- cal_class_plan(response_type, n)
plan <- lapply(plan, function(cls) {
	cls <- setdiff(cls, exclude)
	if (length(only)) intersect(cls, only) else cls
})
cat(sprintf("calibration fast tier: %s n=%d reps %d:%d, %d class(es), %d core(s)\n", response_type, n,
	min(reps), max(reps), length(unlist(plan)), cores))

t0 <- proc.time()[["elapsed"]]
run_one <- function(r) {
	tryCatch(cal_run_rep(response_type, n, r, plan, effect = 0, endpoints = FALSE), error = function(e) {
		message(sprintf("rep %d failed: %s", r, conditionMessage(e)))
		NULL
	})
}
# Forked workers, one replicate each; each worker is single-threaded (the
# workflow sets OMP/BLAS thread counts to 1).
res <- if (cores > 1L) parallel::mclapply(reps, run_one, mc.cores = cores, mc.preschedule = FALSE) else lapply(reps, run_one)
rows <- do.call(rbind, Filter(function(x) is.data.frame(x) && nrow(x), res))
elapsed <- proc.time()[["elapsed"]] - t0
if (is.null(rows)) stop("no rows produced")
utils::write.csv(rows, file.path(out_dir, "rows.csv"), row.names = FALSE)
writeLines(sprintf("response_type,n,only,reps,cores,elapsed_sec\n%s,%d,%s,%d,%d,%.1f", response_type, n,
	paste(only, collapse = ";"), length(reps), cores, elapsed), file.path(out_dir, "timing.csv"))
cat(sprintf("calibration fast tier: %d rows in %.0f s (%.1f s per replicate per core)\n", nrow(rows), elapsed,
	elapsed * cores / length(reps)))
