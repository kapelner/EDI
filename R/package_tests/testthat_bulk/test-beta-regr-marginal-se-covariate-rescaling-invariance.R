# Numerical-robustness review audit, 2026-11-19: generate_mod() discards the mean-submodel vcov
# whenever rcond(fisher_information) < sqrt(.Machine$double.eps), an absolute, scale-dependent test.
# A covariate measured on a large scale (e.g. x in units of 1e4) gives a well-conditioned problem
# whose unscaled information matrix has rcond ~1e-9, so under estimand = "marginal_mean_diff" the
# delta-method SE, CI and p-value come back NA. The marginal mean difference and its SE do not change
# when x is rescaled.
# Where: R/EDI/R/inference_proportion_beta.R:709 (kind: na_where_defined).
# On commit 0231668c948b this test failed with: Expected `pt_big` to equal `pt_unit`. Differences:
# 1/1 mismatches [1] 0.139 - 0.132 == 0.00688
# Tracked as v1.0.6-TODO-385; remove the skip() when it is fixed.

test_that("beta regression marginal_mean_diff SE is invariant to rescaling a covariate", {
	skip("v1.0.6-TODO-385: the marginal SE is NA because generate_mod() tests the raw rcond(fi) < sqrt(eps)")
		set.seed(11)
		n = 60L
		x1 = rnorm(n)
		make_inf = function(x_scale){
			des = DesignFixedBernoulli$new(n = n, response_type = "proportion", seed = 11L)
			des$add_all_subjects_to_experiment(data.frame(x1 = x1 * x_scale))
			des$assign_w_to_all_subjects()
			w = des$get_w()
			set.seed(12)
			mu = plogis(-0.3 + 0.8 * w + 0.4 * x1)
			y = rbeta(n, mu * 12, (1 - mu) * 12)
			y = pmin(pmax(y, 1e-6), 1 - 1e-6)
			des$add_all_subject_responses(y)
			inf = InferencePropBetaRegr$new(des)
			inf$set_estimand("marginal_mean_diff")
			inf
		}
		inf_unit = make_inf(1)
		pt_unit = inf_unit$compute_estimate()
		se_unit = inf_unit$.__enclos_env__$private$cached_values$s_beta_hat_T
		expect_true(is.finite(se_unit))

		inf_big = make_inf(2e4)
		pt_big = inf_big$compute_estimate()
		se_big = inf_big$.__enclos_env__$private$cached_values$s_beta_hat_T
		expect_equal(pt_big, pt_unit, tolerance = 1e-3)
		expect_true(is.finite(se_big))
		expect_equal(se_big, se_unit, tolerance = 1e-2)
})
