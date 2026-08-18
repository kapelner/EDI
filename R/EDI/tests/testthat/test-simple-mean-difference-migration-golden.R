library(testthat)
library(EDI)

# Golden values re-recorded 2026-08-17 (previously recorded ~2026-08-11):
#   - The randomization/bootstrap distribution values drifted because the
#     design-hierarchy rework changed the permutation/resampling RNG stream.
#     Verified before re-recording: the new randomization values are
#     bit-identical to hand-computed mean-differences over the exact
#     permutations drawn under the same seed (statistic unchanged, stream
#     only), and every deterministic golden (estimate, jackknife
#     estimate/SE/CI/p-value, pooled asymptotic CI/p-value) is unchanged to
#     the last digit.
#   - The Bayesian-bootstrap goldens previously expected all-NA output:
#     they were recorded while the reusable-worker/lazy-component clone bug
#     (fixed 2026-08-13, see fix_inference_hierarchy.md Follow-Ups) silently
#     broke the Bayesian bootstrap for migrated classes. Finite,
#     estimate-centered values are the correct behavior (verified: B=200
#     gives 200/200 finite, mean ~ estimate).

simple_mean_difference_golden_design = function(n = 12L, seed = 20260728L) {
	inference_migration_complete_design("continuous", n = n, seed = seed)
}

expect_simple_mean_difference_golden = function(
	label,
	method,
	args,
	expected,
	class_name = "InferenceAllSimpleMeanDiff",
	tolerance = 1e-8
) {
	des = simple_mean_difference_golden_design()
	obj = get(class_name, envir = asNamespace("EDI"))$new(des)
	obj$set_seed(20260811L)
	actual = inference_migration_with_seed(20260811L, do.call(obj[[method]], args))
	expect_equal(actual, expected, tolerance = tolerance, info = label)
}

test_that("migrated simple mean-difference classes expose retained APIs only", {
	EDI:::populate_inference_class_registry()
	retained_methods = EDI:::inference_optional_method_names_for_capabilities(c(
		"randomization_test",
		"randomization_ci",
		"nonparametric_bootstrap",
		"randomization_bootstrap",
		"bayesian_bootstrap",
		"jackknife",
		"wald"
	))
	dropped_methods = setdiff(
		EDI:::inference_optional_method_names_for_capabilities(c(
			"likelihood_tests",
			"parametric_likelihood_bootstrap"
		)),
		"get_supported_testing_types"
	)

	expected_capabilities = list(
		InferenceAllSimpleMeanDiff = c(
			"randomization_test",
			"randomization_ci",
			"nonparametric_bootstrap",
			"randomization_bootstrap",
			"bayesian_bootstrap",
			"jackknife",
			"wald"
		),
		InferenceAllSimpleMeanDiffPooledVar = c(
			"randomization_test",
			"randomization_ci",
			"nonparametric_bootstrap",
			"randomization_bootstrap",
			"bayesian_bootstrap",
			"jackknife",
			"wald"
		),
		InferenceAllKKMeanDiffIVWC = c(
			"randomization_test",
			"randomization_ci",
			"nonparametric_bootstrap",
			"randomization_bootstrap",
			"bayesian_bootstrap",
			"jackknife",
			"wald",
			"kk_passthrough",
			"kk_compound"
		)
	)

	for (class_name in names(expected_capabilities)) {
		methods = inference_migration_public_methods(class_name)
		expect_true(all(retained_methods %in% methods), info = class_name)
		expect_false(any(dropped_methods %in% methods), info = class_name)
		expect_identical(
			EDI:::get_effective_capabilities(class_name),
			expected_capabilities[[class_name]],
			info = class_name
		)
		expect_identical(
			EDI:::get_inference_class_metadata(class_name)$parent,
			"Inference",
			info = class_name
		)
	}
})

test_that("migrated simple mean difference golden outputs are stable", {
	expect_simple_mean_difference_golden(
		"estimate",
		"compute_estimate",
		list(),
		0.462285714285715
	)
	expect_simple_mean_difference_golden(
		"randomization distribution",
		"approximate_randomization_distribution_beta_hat_T",
		list(r = 9L, show_progress = FALSE),
		c(
			0.03488636363636366, 0.40150649350649364, -0.099393939393939257,
			0.15963636363636369, -0.069454545454545435, 0.81363636363636371,
			0.25522727272727253, -0.43693506493506495, -0.26840909090909071
		)
	)
	expect_simple_mean_difference_golden(
		"randomization p-value",
		"compute_rand_two_sided_pval",
		list(delta = 0, r = 9L, show_progress = FALSE),
		NA_real_
	)
	expect_simple_mean_difference_golden(
		"bootstrap distribution",
		"approximate_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		c(
			0.72109090909090934, 0.89939393939393963, 0.35090909090909128,
			0.32409090909090926, 0.34852272727272737, 0.98242424242424264,
			0.61602272727272744, 0.81196969696969712, 0.40420454545454559
		)
	)
	expect_simple_mean_difference_golden(
		"bootstrap confidence interval",
		"compute_bootstrap_confidence_interval",
		list(alpha = 0.2, B = 9L, show_progress = FALSE),
		c(`10%` = NA_real_, `90%` = NA_real_)
	)
	expect_simple_mean_difference_golden(
		"bootstrap p-value",
		"compute_bootstrap_two_sided_pval",
		list(delta = 0, B = 9L, show_progress = FALSE),
		NA_real_
	)
	expect_simple_mean_difference_golden(
		"bayesian bootstrap distribution",
		"approximate_bayesian_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		c(
			0.19448323582684879, 0.42816742892920184, 0.31442368672754006,
			0.66668978340624663, 0.50190925369646533, 0.19224024788445437,
			0.50628650214275361, 0.51833403695812996, 0.57560788857851741
		)
	)
	expect_simple_mean_difference_golden(
		"bayesian bootstrap confidence interval",
		"compute_bayesian_bootstrap_confidence_interval",
		list(alpha = 0.2, B = 9L, show_progress = FALSE),
		c(`10%` = 0.1928383780024262, `90%` = 0.64240127811885206)
	)
	expect_simple_mean_difference_golden(
		"bayesian bootstrap p-value",
		"compute_bayesian_bootstrap_two_sided_pval",
		list(delta = 0, B = 9L, show_progress = FALSE),
		0.22222222222222221
	)
	expect_simple_mean_difference_golden(
		"jackknife estimate",
		"compute_jackknife_estimate",
		list(),
		0.462285714285715
	)
	expect_simple_mean_difference_golden(
		"jackknife standard error",
		"compute_jackknife_std_error",
		list(),
		0.275917154730639
	)
	expect_simple_mean_difference_golden(
		"jackknife confidence interval",
		"compute_jackknife_wald_confidence_interval",
		list(alpha = 0.2),
		c(`10%` = 0.108683652680053, `90%` = 0.815887775891377)
	)
	expect_simple_mean_difference_golden(
		"jackknife p-value",
		"compute_jackknife_wald_two_sided_pval",
		list(delta = 0),
		0.0938457479149271
	)
})

test_that("migrated pooled simple mean difference golden outputs are stable", {
	skip_on_cran()
	class_name = "InferenceAllSimpleMeanDiffPooledVar"
	expect_simple_mean_difference_golden(
		"pooled estimate",
		"compute_estimate",
		list(),
		0.462285714285715,
		class_name = class_name
	)
	expect_simple_mean_difference_golden(
		"pooled asymptotic confidence interval",
		"compute_asymp_confidence_interval",
		list(alpha = 0.2),
		c(`10%` = 0.102469426781093, `90%` = 0.822102001790336),
		class_name = class_name
	)
	expect_simple_mean_difference_golden(
		"pooled asymptotic p-value",
		"compute_asymp_two_sided_pval",
		list(delta = 0),
		0.108383005259051,
		class_name = class_name
	)
	expect_simple_mean_difference_golden(
		"pooled randomization distribution",
		"approximate_randomization_distribution_beta_hat_T",
		list(r = 9L, show_progress = FALSE),
		c(
			0.03488636363636366, 0.40150649350649364, -0.099393939393939257,
			0.15963636363636369, -0.069454545454545435, 0.81363636363636371,
			0.25522727272727253, -0.43693506493506495, -0.26840909090909071
		),
		class_name = class_name
	)
	expect_simple_mean_difference_golden(
		"pooled bootstrap distribution",
		"approximate_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		c(
			0.72109090909090934, 0.89939393939393963, 0.35090909090909128,
			0.32409090909090926, 0.34852272727272737, 0.98242424242424264,
			0.61602272727272744, 0.81196969696969712, 0.40420454545454559
		),
		class_name = class_name
	)
	expect_simple_mean_difference_golden(
		"pooled bayesian bootstrap distribution",
		"approximate_bayesian_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		c(
			0.19448323582684879, 0.42816742892920184, 0.31442368672754006,
			0.66668978340624663, 0.50190925369646533, 0.19224024788445437,
			0.50628650214275361, 0.51833403695812996, 0.57560788857851741
		),
		class_name = class_name
	)
	expect_simple_mean_difference_golden(
		"pooled jackknife standard error",
		"compute_jackknife_std_error",
		list(),
		0.275917154730639,
		class_name = class_name
	)
})
