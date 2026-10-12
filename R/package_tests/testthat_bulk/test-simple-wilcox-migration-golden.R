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
		c("get_supported_testing_types", "set_testing_type")
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
		c("get_supported_testing_types", "set_testing_type")
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
	# Re-recorded 2026-09-22: the previous value was the 95% CI, silently
	# returned regardless of the requested alpha by a caching bug in
	# compute_asymp_confidence_interval() (see that method's own comment on
	# the fix) -- confirmed by hand: wilcox.test(yT, yC, conf.level = 0.95)
	# on this design's data reproduces the old value exactly. This is the
	# actual 80% interval (conf.level = 0.8).
	expect_simple_wilcox_golden(
		"asymptotic confidence interval",
		"compute_asymp_confidence_interval",
		list(alpha = 0.2),
		c(-0.0226825070361196, 0.8491562829742763)
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
		# Re-recorded 2026-10-11, same cause as the 2026-08-17 note at the top
		# of this file: another change to the permutation-generation RNG
		# consumption shifted which B=9 permutations get drawn. Every
		# sibling check in this same test_that block (bootstrap CI, bootstrap
		# p-value, asymptotic values, all non-permutation-dependent) still
		# matches its old golden exactly -- only this permutation-consuming
		# value drifted, isolating the cause to the permutation stream, not
		# a broader regression. Re-verified finite and well-formed before
		# recording.
		c(
			-0.04909090909090913, 0, -0.02272727272727283,
			-0.02272727272727283, 0.47545454545454531, -0.43590909090909083,
			0.02272727272727283, -0.97363636363636353, -0.27181818181818175
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
		# Re-recorded 2026-10-12 after the signed-rank/rank-sum HL variance
		# recalibration (2*pi/3 and pi*(n_t+n_c)/(6 n_t n_c) factors) widened
		# the asymptotic interval; the point estimate above is unchanged.
		c(`10%` = 0.15555962607279547, `90%` = 0.16998126137949679)
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
		# Re-recorded 2026-10-12. The per-permutation statistic is the sum of
		# the standardized signed-rank and rank-sum W statistics
		# (compute_treatment_estimate_during_randomization_inference() and
		# fast_kk_wilcox_parallel.cpp since 597ff617, 2026-08-31), not the HL
		# estimate the 2026-08-24 golden was recorded from; the values are on a
		# z-score scale.
		c(
			0.29814239699997191, -0.34164078649987384, 0.15853846090514501,
			-0.44721359549995793, -0.89442719099991597, -1.1925695879998879,
			-1.1018672662079352, -0.59628479399994383, 2.0083074531665406
		)
	)
	expect_kk_wilcox_golden(
		"randomization p-value",
		"compute_rand_two_sided_pval",
		list(delta = 0, r = 9L, show_progress = FALSE),
		NA_real_
	)
	# Ordinary nonparametric bootstrap was intentionally disabled for adaptive
	# sequential designs; randomization/bootstrap-randomization remain supported.
	obj = InferenceAllKKWilcoxIVWC$new(kk_wilcox_golden_design())
	expect_false(obj$supports("nonparametric_bootstrap"))
	expect_error(obj$approximate_bootstrap_distribution_beta_hat_T(B = 9L, show_progress = FALSE),
		"This method is not supported for DesignSeqOneByOne designs.", fixed = TRUE)
	expect_error(obj$compute_bootstrap_confidence_interval(alpha = 0.2, B = 9L, show_progress = FALSE),
		"This method is not supported for DesignSeqOneByOne designs.", fixed = TRUE)
	expect_error(obj$compute_bootstrap_two_sided_pval(delta = 0, B = 9L, show_progress = FALSE),
		"This method is not supported for DesignSeqOneByOne designs.", fixed = TRUE)
	expect_kk_wilcox_golden(
		"randomization bootstrap distribution",
		"approximate_rand_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		# Re-recorded 2026-10-12. Same statistic as the randomization
		# distribution above (standardized W sum, z-score scale): the
		# reused-worker BRT path used to shortcut to the HL estimate while the
		# observed value was the W statistic, so the BRT p-value compared
		# incompatible scales (0.02 vs the randomization test's 0.31 on this
		# fixture). KKWilcoxIVWCSource$compute_bootstrap_worker_estimate now
		# routes workers through the W statistic; these values are identical
		# to the debug = TRUE (pure R) path.
		c(
			-0.89442719099991597, 0.032333445083919443, -2,
			0.59628479399994394, -2.3851391759997753, -1.1666666666666667,
			0, -1.6019141338792096, 2.352003757581719
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
