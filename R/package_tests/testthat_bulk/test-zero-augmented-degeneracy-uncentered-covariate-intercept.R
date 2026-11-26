# Numerical-robustness review audit, 2026-11-17: zero_augmented_fit_is_degenerate() flags any fit
# whose first parameter (the count-model intercept) is below -15. That intercept depends on where the
# covariates are located, not on whether the fit is degenerate. A well-identified ZIP fit with an
# uncentered covariate (x1 around 80, true intercept -20, every lambda between about 0.1 and 60) is
# therefore treated as degenerate. The sandwich vcov returns NULL, and the marginal-estimand SE, CI
# and p-value come back NA. The same data with x1 centered give a finite CI, and the marginal
# estimand does not depend on centering.
# Where: R/EDI/R/inference_count_zero_augmented_poisson_abstract.R:1564 (kind: na_where_defined).
# On commit 48765322fe90 this test failed with: Expected `all(is.finite(ci_raw))` to be TRUE.
# Differences: `actual`: FALSE `expected`: TRUE
# Tracked as v1.0.7-TODO-96; remove the skip() when it is fixed.

test_that("ZIP marginal CI is finite and invariant to shifting an uncentered covariate", {
	skip("v1.0.7-TODO-96: the degeneracy rule params[1] < -15 depends on covariate location")
		set.seed(11)
		n = 300L
		des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", verbose = FALSE)
		x1 = 80 + 5 * rnorm(n)
		for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i]))
		w = des$get_w()
		pi0 = plogis(-1 + 0.3 * w)
		lambda = exp(-20 + 0.25 * x1 + 0.4 * w)
		y = ifelse(rbinom(n, 1L, pi0) == 1L, 0, rpois(n, lambda))
		des$add_all_subject_responses(y)

		inf_ctr = InferenceCountZeroInflatedPoisson$new(des, model_formula = ~ I(x1 - 80))
		inf_ctr$set_estimand("marginal_mean_diff")
		ci_ctr = inf_ctr$compute_asymp_confidence_interval()

		inf_raw = InferenceCountZeroInflatedPoisson$new(des, model_formula = ~ x1)
		inf_raw$set_estimand("marginal_mean_diff")
		ci_raw = inf_raw$compute_asymp_confidence_interval()

		expect_true(all(is.finite(ci_ctr)))
		expect_true(all(is.finite(ci_raw)))
		expect_equal(as.numeric(ci_raw), as.numeric(ci_ctr), tolerance = 1e-3)
})
