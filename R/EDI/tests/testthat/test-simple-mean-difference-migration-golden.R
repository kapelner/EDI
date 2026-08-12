library(testthat)
library(EDI)

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
			0.279948051948052, -0.470077922077922, -0.00666666666666682,
			-0.337171717171717, -0.0694545454545454, -0.0993939393939394,
			0.331688311688312, 0.0953246753246751, 0.192424242424242
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
			0.193636363636364, 0.0980303030303032, 0.31,
			0.384, 0.237676767676768, 0.478787878787879,
			0.540363636363637, 0.50375, 0.0980303030303032
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
		rep(NA_real_, 9L)
	)
	expect_simple_mean_difference_golden(
		"bayesian bootstrap confidence interval",
		"compute_bayesian_bootstrap_confidence_interval",
		list(alpha = 0.2, B = 9L, show_progress = FALSE),
		c(`10%` = NA_real_, `90%` = NA_real_)
	)
	expect_simple_mean_difference_golden(
		"bayesian bootstrap p-value",
		"compute_bayesian_bootstrap_two_sided_pval",
		list(delta = 0, B = 9L, show_progress = FALSE),
		NA_real_
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
			0.279948051948052, -0.470077922077922, -0.00666666666666682,
			-0.337171717171717, -0.0694545454545454, -0.0993939393939394,
			0.331688311688312, 0.0953246753246751, 0.192424242424242
		),
		class_name = class_name
	)
	expect_simple_mean_difference_golden(
		"pooled bootstrap distribution",
		"approximate_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		c(
			0.193636363636364, 0.0980303030303032, 0.31,
			0.384, 0.237676767676768, 0.478787878787879,
			0.540363636363637, 0.50375, 0.0980303030303032
		),
		class_name = class_name
	)
	expect_simple_mean_difference_golden(
		"pooled bayesian bootstrap distribution",
		"approximate_bayesian_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		rep(NA_real_, 9L),
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
