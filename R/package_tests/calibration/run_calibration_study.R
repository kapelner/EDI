#!/usr/bin/env Rscript
# One shard of the published monthly calibration study (release_v1_2_0.md
# TODO-36; .github/workflows/calibration-study.yml). Runs replicates of one unit
# = (response type, design, n, effect) and writes one row per (replicate, inf_class,
# formula, inf_procedure) to <out-dir>/rows.csv.gz (the publish step merges a wave's into one
# xz-compressed CSV, kept as a 60-day artifact for deep
# dives), the shard's mergeable statistics to <out-dir>/tests.csv.gz and
# est.csv.gz (calibration_study_stats.R; what the publish step adds to the
# campaign's totals), and <out-dir>/shard.csv with the replicates actually
# finished and their cost.
#
# Time-boxed: a replicate starts only if --secs-per-rep (the planner's estimate)
# still fits before --deadline-minutes, except each worker's first one, so a
# shard never runs much past its slot and push CI waits at most one
# shard behind the study. Replicates not reached are left for the next wave
# (plan_calibration_study.R re-plans every replicate missing from shard.csv).
#
# Usage: Rscript R/package_tests/calibration/run_calibration_study.R \
#          --response-type count --design DesignSeqOneByOneKK21 --n 200 --effect null \
#          --reps 1:40,77:90 --out-dir DIR [--cores 4] [--deadline-minutes 25] \
#          [--only CLS,...] [--exclude CLS,...] [--secs-per-rep 60]
# Uses the INSTALLED EDI.

suppressPackageStartupMessages(library(EDI))
script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
source(file.path(script_dir, "calibration_study_common.R"))
source(file.path(script_dir, "calibration_study_stats.R"))

args <- commandArgs(TRUE)
arg_value <- function(flag, default = NULL) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
split_csv <- function(x) if (is.null(x) || !nzchar(x)) character() else trimws(strsplit(x, ",", fixed = TRUE)[[1L]])
parse_reps <- function(x) {
	unlist(lapply(split_csv(x), function(r) {
		b <- as.integer(strsplit(r, ":", fixed = TRUE)[[1L]])
		seq.int(b[[1L]], b[[length(b)]])
	}))
}

response_type <- arg_value("--response-type")
design_label <- arg_value("--design")
n_nominal <- as.integer(arg_value("--n", "200"))
effect_label <- arg_value("--effect", "null")
reps <- parse_reps(arg_value("--reps", "1:10"))
out_dir <- arg_value("--out-dir")
cores <- as.integer(arg_value("--cores", "1"))
start <- Sys.time()
deadline <- start + 60 * as.numeric(arg_value("--deadline-minutes", "25"))
secs_per_rep <- as.numeric(arg_value("--secs-per-rep", "0"))
only <- split_csv(arg_value("--only"))
exclude <- split_csv(arg_value("--exclude"))
if (!response_type %in% CAL_RESPONSE_TYPES) stop("--response-type must be one of ", paste(CAL_RESPONSE_TYPES, collapse = ", "))
if (!design_label %in% cal_study_designs()) stop("--design must be one of the discovered designs: ", paste(cal_study_designs(), collapse = ", "))
if (!effect_label %in% names(CAL_STUDY_EFFECT_NCP)) stop("--effect must be one of ", paste(names(CAL_STUDY_EFFECT_NCP), collapse = ", "))
if (is.null(out_dir)) stop("--out-dir is required")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

classes <- setdiff(cal_study_classes(response_type, design_label, n_nominal), exclude)
if (length(only)) classes <- intersect(classes, only)
effects <- cal_study_effects_table()
truths <- cal_study_truths_table()
cat(sprintf("calibration study: %s %s n=%d %s, %d rep(s), %d class(es), %d core(s)\n", response_type, design_label,
	n_nominal, effect_label, length(reps), length(classes), cores))

t0 <- proc.time()[["elapsed"]]
run_one <- function(r) {
	now <- Sys.time()
	first_round <- as.numeric(difftime(now, loop_start, units = "secs")) < 30
	if (!first_round && now + secs_per_rep > deadline) return("skipped")
	tryCatch(cal_study_run_rep(response_type, design_label, n_nominal, effect_label, r, classes,
		effects = effects, truths = truths),
		error = function(e) {
			message(sprintf("rep %d failed: %s", r, conditionMessage(e)))
			"failed"
		})
}
# Forked workers, one replicate each; each worker is single-threaded (the
# workflow sets OMP/BLAS thread counts to 1).
loop_start <- Sys.time()
res <- if (cores > 1L) parallel::mclapply(reps, run_one, mc.cores = cores, mc.preschedule = FALSE) else lapply(reps, run_one)
elapsed <- proc.time()[["elapsed"]] - t0
skipped <- vapply(res, identical, logical(1L), "skipped")
failed <- vapply(res, function(x) identical(x, "failed") || inherits(x, "try-error"), logical(1L))
rows <- do.call(rbind, Filter(function(x) is.data.frame(x) && nrow(x), res))
if (!is.null(rows)) {
	# The raw-row file (a deep-dive artifact only) rounds the result columns to 7
	# significant digits: full-precision doubles were most of its bytes, and rounding
	# cut the publish step's xz -9e output by a third (measured 2026-11-09). The
	# shard's statistics below use the unrounded rows, so nothing published changes.
	# p_at_ci_a / p_at_ci_b (and ci_fallback) are the fast tier's CI-endpoint check,
	# which the study does not run (cal_run_tasks(endpoints = FALSE)): always NA, so
	# they are dropped from the file.
	raw <- rows[setdiff(names(rows), c("p_at_ci_a", "p_at_ci_b", "ci_fallback"))]
	round_cols <- intersect(c("beta_T_hat", "ci_beta_T_a", "ci_beta_T_b", "pval", "fit_secs", "estimand_true"), names(raw))
	raw[round_cols] <- lapply(raw[round_cols], function(v) if (is.double(v)) signif(v, 7) else v)
	cal_stats_write(raw, file.path(out_dir, "rows.csv.gz"))
	st <- cal_stats_from_rows(rows)
	cal_stats_write(st$tests, file.path(out_dir, "tests.csv.gz"))
	cal_stats_write(st$est, file.path(out_dir, "est.csv.gz"))
}

# A replicate counts as done when it ran to the end, even if every fit in it was
# non-estimable (that is yield, reported by the analysis); a failed replicate (an
# error outside the per-fit tryCatch, e.g. data generation) counts as done too, so
# a deterministic failure is not retried forever. Only skipped ones are re-planned.
done <- reps[!skipped]
compress <- function(x) {
	if (!length(x)) return("")
	x <- sort(x)
	brk <- c(0L, which(diff(x) != 1L), length(x))
	paste(vapply(seq_len(length(brk) - 1L), function(k) {
		a <- x[[brk[[k]] + 1L]]; b <- x[[brk[[k + 1L]]]]
		if (a == b) as.character(a) else sprintf("%d:%d", a, b)
	}, character(1L)), collapse = ",")
}
utils::write.csv(data.frame(response_type = response_type, design = design_label, n = n_nominal, effect = effect_label,
	only = paste(only, collapse = ";"), exclude = paste(exclude, collapse = ";"),
	reps_done = compress(done), n_done = length(done), n_failed = sum(failed), n_skipped = sum(skipped),
	cores = cores, elapsed_sec = round(elapsed, 1),
	secs_per_rep = if (length(done)) round(elapsed * cores / length(done), 2) else NA_real_),
	file.path(out_dir, "shard.csv"), row.names = FALSE)
cat(sprintf("calibration study: %d done (%d failed), %d skipped by the deadline, %.0f s\n",
	length(done), sum(failed), sum(skipped), elapsed))
# Failure contract (v1.0.5 TODO-200): only the analyze job's Gate verdict fails for a
# statistical reason. A failed replicate errored outside the per-fit tryCatch (data
# generation, the harness), so it is a bug in the check: fail the shard, after the rows,
# stats and shard.csv above are written (the workflow uploads them with if: always()).
if (any(failed)) {
	cat(sprintf("::error title=Calibration CI bug::%d of %d replicates failed outside the per-fit error handling (see 'rep N failed' messages above): a bug in the calibration harness, not a calibration result.\n",
		sum(failed), length(done)))
	quit(status = 1L, save = "no")
}
