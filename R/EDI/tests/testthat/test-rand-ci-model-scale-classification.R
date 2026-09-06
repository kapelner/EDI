make_model_scale_classification_probe = function(capabilities = character(), classes = "ModelScaleProbe") {
	structure(
		list(capabilities = function() capabilities),
		class = classes
	)
}

test_that("randomization CI model-scale classification uses capabilities", {
	model_scale_capabilities = c(
		"standard_model_cache",
		"count_likelihood_plumbing",
		"kk_gee",
		"kk_glmm",
		"kk_passthrough"
	)
	for (capability in model_scale_capabilities) {
		expect_true(EDI:::inference_uses_model_scale_randomization_transform(
			make_model_scale_classification_probe(capability)
		))
	}
	expect_false(EDI:::inference_uses_model_scale_randomization_transform(
		make_model_scale_classification_probe(c("wald", "bayesian_bootstrap"))
	))
})

test_that("randomization CI retains explicit non-component model-scale families", {
	for (classname in c(
		"InferencePropQuantileRegr",
		"InferencePropGCompMeanDiff",
		"InferenceCountHurdleNegBin"
	)) {
		expect_true(EDI:::inference_uses_model_scale_randomization_transform(
			make_model_scale_classification_probe(classes = c(classname, "ModelScaleProbe"))
		))
	}
})

make_fixed_pval_rand_ci_probe <- function(des, pval_l, pval_u) {
	ext_env = new.env(parent = globalenv())
	ext_env$R6Class = R6::R6Class
	ext_env$InferenceContinLin = InferenceContinLin
	ext_env$.pval_l = pval_l
	ext_env$.pval_u = pval_u
	evalq({
		FixedPvalRandCIProbe = R6Class(
			"FixedPvalRandCIProbe",
			inherit = InferenceContinLin,
			private = list(
				# Both ends of the search always report the same fixed,
				# non-significant p-value, forcing high_precision_confirm_and_
				# refine_ci_bound() into its "no verified crossing" branch.
				compute_randomization_ci_pval_cached = function(inf_obj, r, delta, transform_responses, permutations, ci_search_control, ci_pval_cache) {
					if (delta <= 0) .pval_l else .pval_u
				}
			)
		)
	}, envir = ext_env)
	ext_env$FixedPvalRandCIProbe$new(des, verbose = FALSE)
}

test_that("high_precision_confirm_and_refine_ci_bound picks the outer end by search direction, not by which p-value is non-significant", {
	# Regression for the 2026-09-06 randomization-CI coverage bug: when the
	# high-precision confirmation pass finds no verified sign change (both
	# ends of the range are non-significant, the expected outcome for a
	# genuinely conservative bound), it used to return whichever end had
	# pval_l >= pval_th -- correct for a LOWER-bound search (l really is the
	# outer end there) but wrong for an UPPER-bound search, where l = est
	# (the point estimate) is essentially always non-significant, silently
	# collapsing the returned upper bound to the estimate. Empirically this
	# produced ~51-61% coverage instead of ~95% for InferenceContinLin/OLS/
	# QuantileRegr and the KK OneLik classes.
	set.seed(21L)
	des = DesignFixedTestFixture$new(n = 100L, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(100)))
	des$overwrite_all_subject_assignments(rep(c(1, 0), length.out = 100))
	des$add_all_subject_responses(rnorm(100))
	# Both p-values are non-significant (0.5 >= pval_th = 0.025) at every delta,
	# so the confirmation pass must fall into the "no verified crossing" branch.
	probe = make_fixed_pval_rand_ci_probe(des, pval_l = 0.5, pval_u = 0.5)
	priv = probe$.__enclos_env__$private
	control = list(high_precision_confirm = TRUE, mc_enable = FALSE)

	lower_bound = priv$high_precision_confirm_and_refine_ci_bound(
		l = -3, u = 3, lower = TRUE, r = 1, transform_responses = "none",
		permutations = NULL, ci_search_control = control, pval_th = 0.025, tol = 1e-3
	)
	upper_bound = priv$high_precision_confirm_and_refine_ci_bound(
		l = -3, u = 3, lower = FALSE, r = 1, transform_responses = "none",
		permutations = NULL, ci_search_control = control, pval_th = 0.025, tol = 1e-3
	)

	expect_equal(lower_bound, -3)
	expect_equal(upper_bound, 3)
})
