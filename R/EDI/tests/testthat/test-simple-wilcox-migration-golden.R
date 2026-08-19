library(testthat)
library(EDI)

# Golden values re-recorded 2026-08-17 -- same two causes as
# test-simple-mean-difference-migration-golden.R (see its header note):
# the design-hierarchy rework changed the permutation/resampling RNG stream
# (verified: the new simple-Wilcox randomization values are bit-identical to
# front-door compute_estimate() recomputation on the same drawn
# permutations), and the previously-baked all-NA randomization /
# randomization-bootstrap distributions recorded the pre-2026-08-13
# clone-bug era. Deterministic goldens (estimates, asymptotic CIs/p-values,
# KK bootstrap distribution/CI) are unchanged to the last digit.

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
			# 2026-08-19 (RandomizationBootstrapCI capability TODO): CI side
			# of the randomization-bootstrap component now advertises its own
			# capability distinct from the pval side (see contracts_mixins.R).
			"randomization_bootstrap_ci",
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
			"randomization_bootstrap_ci",
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
		c(
			0.049090909090908963, 0.4263636363636365, -0.11136363636363622,
			0.196363636363636185, -0.124545454545454515, 0.84909090909090934,
			0.1999999999999999, -0.49818181818181817, -0.449090909090908985
		)
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
			0.84909090909090923, 0.924545454545455, 0.35090909090909139,
			0.32636363636363647, 0.30181818181818199, 1.17363636363636381,
			0.57545454545454566, 0.84909090909090945, 0.38863636363636372
		)
	)
	expect_simple_wilcox_golden(
		"bootstrap confidence interval",
		"compute_bootstrap_confidence_interval",
		list(alpha = 0.2, B = 9L, show_progress = FALSE),
		c(`10%` = 0.30836363636363651, `90%` = 1.10721212121212131)
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
			0, 0.23954545454545473, 0.30181818181818199,
			0, 0.07545454545454533, -0.42272727272727267,
			0, -0.13590909090909081, -0.4490909090909091
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
	skip_on_cran()
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
		c(
			-0.1626663432174322577, -0.162704310549257769, -0.0094121383485589252,
			-0.0075523376223692144, -0.1627451388585888503, -0.16275512552050167,
			-0.0054983719938008768, 0.1626228617150562161, 0.1628147845278387906
		)
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
		c(
			-0.162856120731504211, -0.066998567187538299, -0.040537058306785882,
			0, -0.01407192206605286, 0.571452644844059554,
			-0.16359567953864429, 0.053228717594146359, 0
		)
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
