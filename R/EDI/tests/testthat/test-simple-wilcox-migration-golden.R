library(testthat)
library(EDI)

simple_wilcox_golden_design = function(n = 12L, seed = 20260728L) {
	inference_migration_complete_design("continuous", n = n, seed = seed)
}

kk_wilcox_golden_design = function(n = 12L, seed = 20260728L) {
	inference_migration_with_seed(seed, {
		p = 2L
		X = as.data.frame(matrix(rnorm(n * p), nrow = n, ncol = p))
		names(X) = c("x1", "x2")
		y = as.numeric(rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			des$add_one_subject_response(i, y[i] + 0.35 * ((w_i + 1) / 2))
		}
		des
	})
}

expect_simple_wilcox_golden = function(label, method, args, expected, tolerance = 1e-8) {
	des = simple_wilcox_golden_design()
	obj = InferenceAllSimpleWilcox$new(des)
	obj$set_seed(20260811L)
	actual = inference_migration_with_seed(20260811L, do.call(obj[[method]], args))
	expect_equal(actual, expected, tolerance = tolerance, info = label)
}

expect_kk_wilcox_golden = function(label, method, args, expected, tolerance = 1e-8) {
	des = kk_wilcox_golden_design()
	obj = InferenceAllKKWilcoxIVWC$new(des)
	obj$set_seed(20260811L)
	actual = suppressWarnings(inference_migration_with_seed(20260811L, do.call(obj[[method]], args)))
	expect_equal(actual, expected, tolerance = tolerance, info = label)
}

test_that("migrated simple Wilcoxon exposes retained APIs only", {
	EDI:::populate_inference_class_registry()
	methods = inference_migration_public_methods("InferenceAllSimpleWilcox")
	retained_methods = EDI:::inference_optional_method_names_for_capabilities(c(
		"randomization_test",
		"randomization_ci",
		"nonparametric_bootstrap",
		"randomization_bootstrap",
		"jackknife",
		"wald"
	))
	dropped_methods = setdiff(
		EDI:::inference_optional_method_names_for_capabilities(c(
			"bayesian_bootstrap",
			"likelihood_tests",
			"parametric_likelihood_bootstrap"
		)),
		"get_supported_testing_types"
	)

	expect_true(all(retained_methods %in% methods))
	expect_false(any(dropped_methods %in% methods))
	expect_identical(
		EDI:::get_effective_capabilities("InferenceAllSimpleWilcox"),
		c(
			"randomization_test",
			"randomization_ci",
			"nonparametric_bootstrap",
			"randomization_bootstrap",
			"jackknife",
			"wald"
		)
	)
	expect_identical(
		EDI:::get_inference_class_metadata("InferenceAllSimpleWilcox")$parent,
		"Inference"
	)
})

test_that("migrated KK Wilcoxon exposes retained APIs only", {
	EDI:::populate_inference_class_registry()
	methods = inference_migration_public_methods("InferenceAllKKWilcoxIVWC")
	retained_methods = EDI:::inference_optional_method_names_for_capabilities(c(
		"randomization_test",
		"randomization_ci",
		"nonparametric_bootstrap",
		"randomization_bootstrap",
		"jackknife",
		"wald"
	))
	dropped_methods = setdiff(
		EDI:::inference_optional_method_names_for_capabilities(c(
			"bayesian_bootstrap",
			"likelihood_tests",
			"parametric_likelihood_bootstrap"
		)),
		"get_supported_testing_types"
	)

	expect_true(all(retained_methods %in% methods))
	expect_false(any(dropped_methods %in% methods))
	expect_identical(
		EDI:::get_effective_capabilities("InferenceAllKKWilcoxIVWC"),
		c(
			"randomization_test",
			"randomization_ci",
			"nonparametric_bootstrap",
			"randomization_bootstrap",
			"jackknife",
			"wald",
			"kk_passthrough",
			"kk_compound"
		)
	)
	expect_identical(
		EDI:::get_inference_class_metadata("InferenceAllKKWilcoxIVWC")$parent,
		"Inference"
	)
})

test_that("migrated simple Wilcoxon golden outputs are stable", {
	expect_simple_wilcox_golden(
		"estimate",
		"compute_estimate",
		list(),
		0.426363636363637
	)
	expect_simple_wilcox_golden(
		"asymptotic confidence interval",
		"compute_asymp_confidence_interval",
		list(alpha = 0.2),
		c(-0.196295551995044, 1.17361173335524)
	)
	expect_simple_wilcox_golden(
		"asymptotic p-value",
		"compute_asymp_two_sided_pval",
		list(delta = 0),
		0.255623107546413
	)
	expect_simple_wilcox_golden(
		"randomization distribution",
		"approximate_randomization_distribution_beta_hat_T",
		list(r = 9L, show_progress = FALSE),
		rep(NA_real_, 9L)
	)
	expect_simple_wilcox_golden(
		"randomization p-value",
		"compute_rand_two_sided_pval",
		list(delta = 0, r = 9L, show_progress = FALSE),
		NA_real_
	)
	expect_simple_wilcox_golden(
		"bootstrap distribution",
		"approximate_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		c(
			0.277272727272727, -0.0472727272727272, 0.215,
			0.426363636363637, 0.301818181818182, 0.426363636363637,
			0.450909090909091, 0.426363636363637, -0.0227272727272723
		)
	)
	expect_simple_wilcox_golden(
		"bootstrap confidence interval",
		"compute_bootstrap_confidence_interval",
		list(alpha = 0.2, B = 9L, show_progress = FALSE),
		c(`10%` = -0.0407272727272725, `90%` = 0.444363636363637)
	)
	expect_simple_wilcox_golden(
		"bootstrap p-value",
		"compute_bootstrap_two_sided_pval",
		list(delta = 0, B = 9L, show_progress = FALSE),
		0.222222222222222
	)
	expect_simple_wilcox_golden(
		"randomization bootstrap distribution",
		"approximate_rand_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		c(
			0.449090909090909, -0.086818181818182, 0.111363636363636,
			-0.498181818181818, 0.226363636363637, 0.498181818181818,
			0.124545454545455, 0, 0
		)
	)
	expect_simple_wilcox_golden(
		"randomization bootstrap p-value",
		"compute_rand_bootstrap_two_sided_pval",
		list(delta = 0, B = 9L, show_progress = FALSE),
		NA_real_
	)
	expect_simple_wilcox_golden(
		"jackknife estimate",
		"compute_jackknife_estimate",
		list(),
		NA_real_
	)
	expect_simple_wilcox_golden(
		"jackknife standard error",
		"compute_jackknife_std_error",
		list(),
		NA_real_
	)
	expect_simple_wilcox_golden(
		"jackknife confidence interval",
		"compute_jackknife_wald_confidence_interval",
		list(alpha = 0.2),
		c(NA_real_, NA_real_)
	)
	expect_simple_wilcox_golden(
		"jackknife p-value",
		"compute_jackknife_wald_two_sided_pval",
		list(delta = 0),
		NA_real_
	)
})

test_that("migrated KK Wilcoxon golden outputs are stable", {
	expect_kk_wilcox_golden(
		"estimate",
		"compute_estimate",
		list(),
		0.162770443726146
	)
	expect_kk_wilcox_golden(
		"asymptotic confidence interval",
		"compute_asymp_confidence_interval",
		list(alpha = 0.2),
		c(`10%` = 0.157787853101872, `90%` = 0.167753034350421)
	)
	expect_kk_wilcox_golden(
		"asymptotic p-value",
		"compute_asymp_two_sided_pval",
		list(delta = 0),
		0
	)
	expect_kk_wilcox_golden(
		"randomization distribution",
		"approximate_randomization_distribution_beta_hat_T",
		list(r = 9L, show_progress = FALSE),
		rep(NA_real_, 9L)
	)
	expect_kk_wilcox_golden(
		"randomization p-value",
		"compute_rand_two_sided_pval",
		list(delta = 0, r = 9L, show_progress = FALSE),
		NA_real_
	)
	expect_kk_wilcox_golden(
		"bootstrap distribution",
		"approximate_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		c(
			0.162770443726146, 0.168268815719947, 0.162770443726146,
			0.233661806927101, 0.163126525345601, 0.168268815719947, NA_real_,
			-0.070932487658478, 0.162770443726146
		)
	)
	expect_kk_wilcox_golden(
		"bootstrap confidence interval",
		"compute_bootstrap_confidence_interval",
		list(alpha = 0.2, B = 9L, show_progress = FALSE),
		c(`10%` = 0.157787853101872, `90%` = 0.167753034350421)
	)
	expect_kk_wilcox_golden(
		"bootstrap p-value",
		"compute_bootstrap_two_sided_pval",
		list(delta = 0, B = 9L, show_progress = FALSE),
		NA_real_
	)
	expect_kk_wilcox_golden(
		"randomization bootstrap distribution",
		"approximate_rand_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		rep(NA_real_, 9L)
	)
	expect_kk_wilcox_golden(
		"randomization bootstrap p-value",
		"compute_rand_bootstrap_two_sided_pval",
		list(delta = 0, B = 9L, show_progress = FALSE),
		NA_real_
	)
	expect_kk_wilcox_golden(
		"jackknife estimate",
		"compute_jackknife_estimate",
		list(),
		NA_real_
	)
	expect_kk_wilcox_golden(
		"jackknife standard error",
		"compute_jackknife_std_error",
		list(),
		NA_real_
	)
	expect_kk_wilcox_golden(
		"jackknife confidence interval",
		"compute_jackknife_wald_confidence_interval",
		list(alpha = 0.2),
		c(NA_real_, NA_real_)
	)
	expect_kk_wilcox_golden(
		"jackknife p-value",
		"compute_jackknife_wald_two_sided_pval",
		list(delta = 0),
		NA_real_
	)
})
