#!/usr/bin/env Rscript
# Writes calibration_study_truths.csv for the published calibration study
# (release_v1_2_0.md TODO-36): the true value of every class's own estimand at
# each power effect, so coverage and bias can be checked away from the null.
#
# Under the null every class's estimand is its null value, so no truth is needed;
# at beta_T != 0 each class estimates something different (a marginal log odds
# ratio under `~1` is not the conditional beta_T; a mean difference on counts is
# not a log rate ratio). The truth is the class's own estimate on --k large
# samples (--n-big subjects each) from the study's data generator at that effect,
# on DesignFixedBernoulli at the cell's allocation: the probability limit
# ("least false" value) of its estimator, the same idea as comprehensive_tests.R's
# get_coverage_truth() MC specs. The median of the --k fits is kept, with their
# SD, so a degenerate fit (the 2026-09-22 QuantileRegr case there) cannot set it.
#
# Keyed by (response type, n_nominal, effect_label, prob_T, inf_class, formula):
# the effect is a local alternative, so it differs by n; prob_T matters because a
# misspecified estimand (e.g. a `~1` Cox hazard ratio) depends on the allocation.
# The same truth serves every design at that prob_T: under each design the
# assignment becomes independent of X with P(T) = prob_T as n grows, so the
# estimator's limit is the same. Classes that apply only to matched designs (the
# KK classes) are not here: their estimand depends on the pairing, which has no
# large-sample limit independent of n, so their non-null cells report "no truth".
#
# Usage: Rscript R/package_tests/calibration/calibrate_study_truths.R [--n-big 20000] [--k 8]
#          [--cores 10] [--power-ns 50,200] [--response-types all] [--out FILE]
# Uses the INSTALLED EDI. Re-run (and commit the CSV) whenever
# calibration_study_effects.csv, a response model, the covariates or an
# estimator's definition changes.

suppressPackageStartupMessages(library(EDI))
script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
source(file.path(script_dir, "calibration_study_common.R"))
args <- commandArgs(TRUE)
arg_value <- function(flag, default) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
split_csv <- function(x) trimws(strsplit(x, ",", fixed = TRUE)[[1L]])
n_big <- as.integer(arg_value("--n-big", "20000"))
k <- as.integer(arg_value("--k", "8"))
cores <- as.integer(arg_value("--cores", "4"))
power_ns <- as.integer(split_csv(arg_value("--power-ns", "50,200")))
rts <- arg_value("--response-types", "all")
rts <- if (identical(rts, "all")) CAL_RESPONSE_TYPES else split_csv(rts)
out_path <- arg_value("--out", file.path(script_dir, "calibration_study_truths.csv"))
effects <- cal_study_effects_table()
power_labels <- setdiff(names(CAL_STUDY_EFFECT_NCP), "null")
allocations <- c("DesignFixedBernoulli" = 0.5, "DesignFixedBernoulli@prob_T=0.2" = 0.2)

# (class, formula) pairs that tier 1 runs on the Bernoulli design, per response type.
pairs_for <- function(rt) {
	classes <- cal_study_classes(rt, "DesignFixedBernoulli", 200L)
	set.seed(1L)
	X <- cal_study_gen_X(200L)
	des <- cal_study_run_design("DesignFixedBernoulli", rt, X, cal_study_potential_outcomes(rt, X, 0))
	tasks <- EDI:::run_all_inference_build_tasks(classes, CAL_FORMULAS, CAL_STUDY_TIER1_METHODS, des_obj = des)
	tasks <- Filter(function(t) !is.na(t$method), tasks)
	p <- unique(data.frame(inf_class = vapply(tasks, `[[`, "", "cls_name"),
		formula = vapply(tasks, function(t) if (is.null(t$model_formula)) "" else deparse1(t$model_formula), ""),
		stringsAsFactors = FALSE))
	p$dgp <- cal_class_dgp(p$inf_class)
	p
}

# Seeds apart from the study's (cal_study_seed() < 1.3e9).
truth_seed <- function(rt, n_nominal, effect_label, prob_T, kk) {
	as.integer(1.4e9 + cal_study_rt_index(rt) * 1e8 + n_nominal * 1e5 +
		match(effect_label, power_labels) * 1e4 + (prob_T == 0.2) * 1e3 + kk)
}

jobs <- do.call(rbind, lapply(rts, function(rt) expand.grid(response_type = rt, n_nominal = power_ns,
	effect_label = power_labels, design = names(allocations), kk = seq_len(k), stringsAsFactors = FALSE)))
pairs <- setNames(lapply(rts, pairs_for), rts)
cat(sprintf("%d fit jobs (n_big = %d), %d (class, formula) pairs\n", nrow(jobs), n_big, sum(vapply(pairs, nrow, 1L))))

fit_job <- function(j) {
	job <- jobs[j, ]
	rt <- job$response_type
	effect <- cal_study_effect(rt, job$n_nominal, job$effect_label, effects)
	prob_T <- allocations[[job$design]]
	p <- pairs[[rt]]
	p$estimate <- NA_real_
	p$fit_secs <- NA_real_
	for (dgp in unique(p$dgp)) {
		set.seed(truth_seed(rt, job$n_nominal, job$effect_label, prob_T, job$kk))
		X <- cal_study_gen_X(n_big)
		po <- cal_study_potential_outcomes(rt, X, cal_dgp_effect(effect, dgp), dgp = dgp)
		des <- cal_study_run_design(job$design, rt, X, po)
		for (i in which(p$dgp == dgp)) {
			t0 <- proc.time()[["elapsed"]]
			params <- if (nzchar(p$formula[[i]])) list(model_formula = stats::as.formula(p$formula[[i]])) else list()
			p$estimate[[i]] <- tryCatch(suppressWarnings(as.numeric(do.call(
				get(p$inf_class[[i]], envir = asNamespace("EDI"))$new, c(list(des_obj = des), params))$compute_estimate())[1L]),
				error = function(e) NA_real_)
			p$fit_secs[[i]] <- proc.time()[["elapsed"]] - t0
		}
	}
	cbind(job[c("response_type", "n_nominal", "effect_label")], prob_T = prob_T, beta_T = effect, kk = job$kk,
		p[c("inf_class", "formula", "estimate", "fit_secs")])
}
t0 <- proc.time()[["elapsed"]]
res <- do.call(rbind, parallel::mclapply(seq_len(nrow(jobs)), fit_job, mc.cores = cores, mc.preschedule = FALSE))
cat(sprintf("fits done in %.0f s\n", proc.time()[["elapsed"]] - t0))

key <- c("response_type", "n_nominal", "effect_label", "prob_T", "inf_class", "formula")
g <- do.call(paste, c(res[key], sep = "\r"))
truths <- do.call(rbind, lapply(split(seq_len(nrow(res)), g), function(idx) {
	x <- res[idx, ]
	e <- x$estimate[is.finite(x$estimate)]
	data.frame(x[1L, c(key, "beta_T")], estimand_true = if (length(e)) signif(stats::median(e), 7L) else NA_real_,
		mc_sd = if (length(e) > 1L) signif(stats::sd(e), 4L) else NA_real_, k_ok = length(e), k = nrow(x),
		n_big = n_big, mean_fit_secs = round(mean(x$fit_secs), 2L), stringsAsFactors = FALSE)
}))
truths <- truths[do.call(order, truths[key]), ]
truths$calibrated <- format(Sys.Date())
utils::write.csv(truths, out_path, row.names = FALSE)
cat(sprintf("wrote %d truths (%d with no finite fit) to %s\n", nrow(truths), sum(!is.finite(truths$estimand_true)), out_path))
