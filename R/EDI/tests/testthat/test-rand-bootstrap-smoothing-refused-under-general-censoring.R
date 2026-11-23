# v1.0.6-TODO-146: the smoothed bootstrap randomization test added its kernel noise to y only.
# Under left-/interval-censoring a censored subject's y is NA, so the noise never reached the
# censored subjects (y_L / y_R stayed put), the bandwidth came from the exact times alone (a
# fallback of 1.0 raw time units when every subject is censored), and on mixed data Weibull's
# smoothed p-value came back NA. Smoothing is now refused under general censoring, with a clear
# error, on every entry point; exact/right-censored survival data still smooth as before.

brt_smooth_censoring_design = function(n = 40L, kind = c("mixed", "interval", "right")){
	kind = match.arg(kind)
	set.seed(2)
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(response_type = "survival", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	t_true = rexp(n, exp(-1 - 0.8 * des$get_w() + 0.5 * X$x1))
	if (kind == "right") {
		dead = rbinom(n, 1L, 0.7)
		des$add_all_subject_responses(ys = ifelse(dead == 1, t_true, NA_real_),
			y_Ls = ifelse(dead == 1, NA_real_, t_true), y_Rs = ifelse(dead == 1, NA_real_, Inf))
		return(des)
	}
	k = if (kind == "interval") rep("interval", n) else sample(c("exact", "interval", "left"), n, replace = TRUE)
	y = ifelse(k == "exact", t_true, NA_real_)
	y_L = ifelse(k == "interval", t_true * 0.7, ifelse(k == "left", 0, NA_real_))
	y_R = ifelse(k == "interval", t_true * 1.3, ifelse(k == "left", t_true * 1.2, NA_real_))
	des$add_all_subject_responses(y, y_L, y_R)
	des
}

brt_smooth_classes = c("InferenceSurvivalWeibullRegr", "InferenceSurvivalLogRank", "InferenceSurvivalKMDiff",
	"InferenceSurvivalRestrictedMeanDiff", "InferenceSurvivalCoxPHRegr")

test_that("smoothed BRT p-value and CI are refused under left/interval censoring", {
	for (kind in c("mixed", "interval")) {
		des = brt_smooth_censoring_design(kind = kind)
		for (cls in brt_smooth_classes) {
			inf = suppressWarnings(get(cls)$new(des, verbose = FALSE))
			info = paste(cls, kind)
			expect_false("smoothed" %in% inf$get_supported_rand_bootstrap_pval_types(), info = info)
			expect_true("percentile" %in% inf$get_supported_rand_bootstrap_pval_types(), info = info)
			expect_error(
				inf$compute_rand_bootstrap_two_sided_pval(B = 11, type = "smoothed", show_progress = FALSE),
				"interval-censored", info = info
			)
			ci_types = if (is.function(inf$get_supported_rand_bootstrap_ci_types)) inf$get_supported_rand_bootstrap_ci_types() else character()
			expect_false("smoothed" %in% ci_types, info = info)
			# RMST disables the BRT CI altogether (log-time scale mismatch); skip it here.
			if (length(ci_types) > 0L && cls != "InferenceSurvivalRestrictedMeanDiff") {
				expect_error(
					inf$compute_rand_bootstrap_confidence_interval(B = 11, type = "smoothed", show_progress = FALSE),
					"interval-censored", info = info
				)
			}
		}
	}
})

test_that("pre-noised draws cannot sneak smoothing past the guard under general censoring", {
	des = brt_smooth_censoring_design(kind = "mixed")
	inf = suppressWarnings(InferenceSurvivalWeibullRegr$new(des, verbose = FALSE))
	p = inf$.__enclos_env__$private
	set.seed(1)
	draws = p$generate_rand_bootstrap_draws(3L, materialize_w = FALSE)
	for (b in seq_along(draws)) draws[[b]][["smooth_noise"]] = rnorm(40L, 0, 0.1)
	expect_error(
		inf$approximate_rand_bootstrap_distribution_beta_hat_T(B = 3, rand_bootstrap_draws = draws, show_progress = FALSE),
		"interval-censored"
	)
})

test_that("right-censored survival data still smooth, and unsmoothed BRT under interval censoring still runs", {
	des_r = brt_smooth_censoring_design(kind = "right")
	for (cls in brt_smooth_classes) {
		inf = suppressWarnings(get(cls)$new(des_r, verbose = FALSE))
		expect_true("smoothed" %in% inf$get_supported_rand_bootstrap_pval_types(), info = cls)
		set.seed(1)
		pv = suppressWarnings(inf$compute_rand_bootstrap_two_sided_pval(B = 11, type = "smoothed", show_progress = FALSE))
		expect_true(is.numeric(pv) && length(pv) == 1L, info = cls)
	}
	des_i = brt_smooth_censoring_design(kind = "mixed")
	skip_if_not_installed("interval")  # LogRank's interval-censored fit (v1.0.6-TODO-180)
	inf = suppressWarnings(InferenceSurvivalLogRank$new(des_i, verbose = FALSE))
	set.seed(1)
	pv = suppressWarnings(inf$compute_rand_bootstrap_two_sided_pval(B = 11, type = "percentile", show_progress = FALSE))
	expect_true(is.finite(pv))
})
