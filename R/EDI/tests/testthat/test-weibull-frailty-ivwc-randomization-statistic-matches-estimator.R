# v1.0.6-TODO-158 (4): the Weibull frailty IVWC classes' randomization statistic
# (compute_treatment_estimate_during_randomization_inference) refits each half with the
# frailty / sigma parameters fixed at their observed values. Three defects:
# * the reservoir refit fixed parameter p_r (one-based) instead of log sigma at p_r + 1,
#   pinning the last coefficient (the treatment coefficient without covariates) to the
#   value of log sigma (reservoir beta -0.03 vs 1.03);
# * the halves were pooled with the observed data's variances read from cached_values, or
#   50/50 when that cache was empty (a duplicate, or a reused worker after its per-draw
#   reset), so the observed statistic and the permuted ones were different functions of
#   the data. The weights now come from the draw's own fits (v1.0.6-TODO-86 rule);
# * Loggamma's best_X_colnames_reservoir was c("w", "", ...) (KKstats$X_reservoir has no
#   column names), so the reservoir refit dropped every covariate.

kk_frailty_design = function(seed = 1L, n = 80L, covariates = TRUE){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), b = rbinom(n, 1, 0.4))
	des = if (covariates) {
		DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE, design_formula = ~ x1 + x2 + b)
	} else {
		DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	}
	for (i in seq_len(n)) {
		w = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		eta = 0.5 * w + 0.6 * X$x1[i] - 0.3 * X$x2[i] + 0.4 * X$b[i]
		des$add_one_subject_response(i, rexp(1, exp(-eta)))
	}
	des
}

for (generator_name in c("InferenceSurvivalGLMMWeibullFrailtyNormalIVWC", "InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC")) {
	local({
		gen_name = generator_name
		test_that(paste0(gen_name, ": the randomization statistic is the IVW estimate and does not depend on cached state"), {
			for (seed in 1:2) {
				inf = get(gen_name)$new(kk_frailty_design(seed = seed), verbose = FALSE)
				est = suppressWarnings(inf$compute_estimate())
				p = inf$.__enclos_env__$private
				t_obs = p$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE)
				dup = inf$duplicate()
				dp = dup$.__enclos_env__$private
				dp$cached_values = list()
				t_dup = dp$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE)
				expect_equal(t_dup, t_obs, tolerance = 1e-10)
				# Fixed frailty/sigma at their MLEs give the same halves; the Normal class's
				# matched variance at fixed variance components is slightly smaller than the
				# full one, so the pooled value moves a little (was off by up to 0.33).
				expect_equal(t_obs, est, tolerance = 0.01)
			}
		})
		test_that(paste0(gen_name, ": without covariates the reservoir refit estimates the treatment coefficient"), {
			inf = get(gen_name)$new(kk_frailty_design(seed = 1L, covariates = FALSE), verbose = FALSE)
			est = suppressWarnings(inf$compute_estimate())
			p = inf$.__enclos_env__$private
			t_obs = p$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE)
			expect_equal(t_obs, est, tolerance = 0.01)
		})
	})
}
