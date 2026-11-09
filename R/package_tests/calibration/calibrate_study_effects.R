#!/usr/bin/env Rscript
# Writes calibration_study_effects.csv for the published calibration study
# (release_v1_2_0.md TODO-36): per response type, se_sqrt_n = SD of the baseline
# class's `~ .` estimate under the null x sqrt(n), on DesignFixedBernoulli with the
# study's p = 5 data. cal_study_effect() turns it into the local alternatives
# beta_T = ncp * se_sqrt_n / (slope * sqrt(n)) with about 20 / 50 / 80% power for
# that class at every n. `slope` is d(estimand) / d(effect) for the baseline
# class, fixed by the response models in calibration_fast_tier_common.R:
#   count: mu = exp(0.5 + 0.6 eta), so the log rate ratio moves 0.6 per unit
#          effect; every other baseline's estimand moves 1 per unit (Cox: the log
#          hazard ratio moves -1, and power is two-sided).
#
# Usage: Rscript R/package_tests/calibration/calibrate_study_effects.R [--n 1000] [--reps 300] [--cores 4]
# Uses the INSTALLED EDI. Re-run (and commit the CSV) only when a response model
# or the study's covariates change; a change resets every power cell's meaning.

suppressPackageStartupMessages(library(EDI))
script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
source(file.path(script_dir, "calibration_study_common.R"))
args <- commandArgs(TRUE)
arg_value <- function(flag, default) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
n <- as.integer(arg_value("--n", "1000"))
reps <- as.integer(arg_value("--reps", "300"))
cores <- as.integer(arg_value("--cores", "4"))

baselines <- data.frame(
	response_type = CAL_RESPONSE_TYPES,
	baseline_class = c("InferenceContinOLS", "InferenceIncidLogRegr", "InferencePropBetaRegr",
		"InferenceCountPoisson", "InferenceOrdinalPropOddsRegr", "InferenceSurvivalCoxPHRegr"),
	slope = c(1, 1, 1, 0.6, 1, 1), stringsAsFactors = FALSE)

baselines$se_sqrt_n <- vapply(seq_len(nrow(baselines)), function(i) {
	rt <- baselines$response_type[[i]]
	cls <- get(baselines$baseline_class[[i]], envir = asNamespace("EDI"))
	est <- unlist(parallel::mclapply(seq_len(reps), function(r) {
		set.seed(cal_study_seed(rt, n, r))
		X <- cal_study_gen_X(n)
		des <- cal_study_run_design("DesignFixedBernoulli", rt, X, cal_study_potential_outcomes(rt, X, 0))
		tryCatch(as.numeric(suppressWarnings(cls$new(des, model_formula = ~ .)$compute_estimate()))[1L],
			error = function(e) NA_real_)
	}, mc.cores = cores))
	est <- est[is.finite(est)]
	cat(sprintf("%-11s %-30s %d finite of %d, SD x sqrt(n) = %.4f\n", rt, baselines$baseline_class[[i]],
		length(est), reps, stats::sd(est) * sqrt(n)))
	stats::sd(est) * sqrt(n)
}, numeric(1L))
baselines$se_sqrt_n <- signif(baselines$se_sqrt_n, 4L)
baselines$calibrated <- sprintf("n = %d, %d null reps, %s", n, reps, format(Sys.Date()))
utils::write.csv(baselines, file.path(script_dir, "calibration_study_effects.csv"), row.names = FALSE)
