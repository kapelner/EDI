#!/usr/bin/env Rscript
# Covariate balance backfill for a calibration-study campaign whose shards did not record it (owner, 2026-11-17).
# Campaigns pinned before calibration_study_balance.R existed have no stats/balance.csv.gz; this script recomputes
# the balance of every (design, n) null unit in the campaign's plan by re-running only the designs (no inference)
# on the campaign's own seeds: set.seed(cal_study_seed(rt, n, rep)), cal_study_gen_X(), the null potential
# outcomes, cal_study_run_design(), exactly as cal_study_run_rep() does. With --common-dir pointing at the
# campaign's pinned checkout and the pinned EDI installed, the assignments are the ones the campaign's null cells saw.
# Writes mergeable statistics (calibration_study_balance.R) to --out. Uses the INSTALLED EDI.
#
# Usage: Rscript R/package_tests/calibration/balance_calibration_study.R --plan PLAN.csv --out FILE \
#          [--common-dir DIR] [--response-types continuous] [--reps 1:500] [--cores 4]

suppressPackageStartupMessages(library(EDI))
args <- commandArgs(TRUE)
arg_value <- function(flag, default = NULL) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
own_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
script_dir <- normalizePath(arg_value("--common-dir", own_dir))
source(file.path(script_dir, "calibration_study_common.R"))
source(file.path(script_dir, "calibration_study_stats.R"))
# The metrics are this commit's, whatever --common-dir supplies the seeds and designs.
source(file.path(own_dir, "calibration_study_balance.R"))

plan_path <- arg_value("--plan")
out <- arg_value("--out")
if (is.null(plan_path) || is.null(out)) stop("--plan and --out are required")
rts <- strsplit(arg_value("--response-types", "continuous"), ",", fixed = TRUE)[[1L]]
r <- as.integer(strsplit(arg_value("--reps", "1:500"), ":", fixed = TRUE)[[1L]])
reps <- seq.int(r[[1L]], r[[length(r)]])
cores <- as.integer(arg_value("--cores", "1"))

plan <- read_csv_fast(plan_path, stringsAsFactors = FALSE)
units <- unique(plan[plan$effect == "null" & plan$response_type %in% rts, c("response_type", "design", "n")])
cat(sprintf("balance backfill: %d unit(s) x %d rep(s), %d core(s)\n", nrow(units), length(reps), cores))

one_unit <- function(i) {
	rt <- units$response_type[[i]]; lab <- units$design[[i]]; n_nom <- as.integer(units$n[[i]])
	entry <- cal_plan_entry(lab)
	n <- cal_study_effective_n(lab, n_nom)
	rows <- lapply(reps, function(rep) tryCatch({
		set.seed(cal_study_seed(rt, n, rep))
		X <- cal_study_gen_X(n)
		po <- cal_study_potential_outcomes(rt, X, 0)
		des <- suppressWarnings(suppressMessages(cal_study_run_design(lab, rt, X, po)))
		data.frame(response_type = rt, design = entry$design, prob_T = entry$prob_T, n = n, n_nominal = n_nom,
			effect_label = "null", rep = rep, cal_balance_metrics(X, des$get_w()), stringsAsFactors = FALSE)
	}, error = function(e) { message(sprintf("%s %s n=%d rep %d failed: %s", rt, lab, n_nom, rep, conditionMessage(e))); NULL }))
	cal_balance_stats(do.call(rbind, rows))
}
t0 <- proc.time()[["elapsed"]]
res <- if (cores > 1L) parallel::mclapply(seq_len(nrow(units)), one_unit, mc.cores = cores, mc.preschedule = FALSE) else
	lapply(seq_len(nrow(units)), one_unit)
bad <- vapply(res, inherits, logical(1L), "try-error")
if (any(bad)) stop(sprintf("balance backfill: %d unit(s) failed: %s", sum(bad), paste(vapply(res[bad], as.character, ""), collapse = "; ")))
st <- cal_balance_merge(res)
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
cal_stats_write(st, out)
cat(sprintf("balance backfill: %d unit(s) written to %s in %.0f s\n", if (is.null(st)) 0L else nrow(st), out, proc.time()[["elapsed"]] - t0))
