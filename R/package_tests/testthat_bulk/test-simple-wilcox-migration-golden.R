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

# v1.0.6-TODO-45 (2026-11-17): KK14's match test now uses the published
# T^2 = 1/2 d'S^-1 d (it was twice as strict), which changed this seed's
# allocation. With two covariates the F(2, .) cutoff near 0 scales like lambda,
# so lambda = 0.05 (default 0.1) reproduces the allocation the goldens below
# were recorded on.
kk_wilcox_golden_design = function(n = 12L, seed = 20260728L, lambda = 0.05) {
	inference_migration_with_seed(seed, {
		p = 2L
		X = as.data.frame(matrix(rnorm(n * p), nrow = n, ncol = p))
		names(X) = c("x1", "x2")
		y = as.numeric(rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE, lambda = lambda)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			des$add_one_subject_response(i, y[i] + 0.35 * ((w_i + 1) / 2))
		}
		des
	})
}

# Same seeded covariates and responses as kk_wilcox_golden_design(), on a fixed
# binary-match design (pairs 1-2, 3-4, ...; one treated per pair). The
# randomization bootstrap refuses KK14 since 2026-11-14, so its KK Wilcoxon
# golden lives on this design.
kk_wilcox_binary_match_golden_design = function(n = 12L, seed = 20260728L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		y = as.numeric(rnorm(n))
		des = DesignFixedBinaryMatch$new(response_type = "continuous", n = n, m = rep(seq_len(n / 2L), each = 2L), verbose = FALSE)
		des$add_all_subjects_to_experiment(X)
		w = as.vector(replicate(n / 2L, sample(0:1)))
		des$assign_w_to_all_subjects(w)
		des$add_all_subject_responses(y + 0.35 * w)
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
	# Tolerance 1e-4 for this column only (2026-10-22, release_v1_0_5.md G6 #15,
	# owner decision: loosen the affected column). The interval is
	# stats::wilcox.test()'s own, found by uniroot() at its default
	# tol.root = 1e-4, so its last digits move with the R build: under R-devel
	# (2026-10-13 r90668) EDI and a direct wilcox.test() call agree exactly but
	# differ from the pinned values by a mean relative 4.4e-5. Every other
	# column stays at 1e-8.
	expect_simple_wilcox_golden(
		"asymptotic confidence interval",
		"compute_asymp_confidence_interval",
		list(alpha = 0.2),
		c(-0.0226825070361196, 0.8491562829742763),
		tolerance = 1e-4
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
	# sequential designs, and since 2026-11-14 so is the randomization bootstrap;
	# the randomization test remains supported.
	obj = InferenceAllKKWilcoxIVWC$new(kk_wilcox_golden_design())
	expect_false(obj$supports("nonparametric_bootstrap"))
	expect_error(obj$approximate_bootstrap_distribution_beta_hat_T(B = 9L, show_progress = FALSE),
		"This method is not supported for DesignSeqOneByOne designs.", fixed = TRUE)
	expect_error(obj$compute_bootstrap_confidence_interval(alpha = 0.2, B = 9L, show_progress = FALSE),
		"This method is not supported for DesignSeqOneByOne designs.", fixed = TRUE)
	expect_error(obj$compute_bootstrap_two_sided_pval(delta = 0, B = 9L, show_progress = FALSE),
		"This method is not supported for DesignSeqOneByOne designs.", fixed = TRUE)
	# The randomization bootstrap distribution golden (re-recorded 2026-10-12 for
	# the W-statistic worker fix) lived here. Since 2026-11-14 (owner ruling: the
	# bootstrap is unproven on KK designs) the randomization bootstrap refuses the
	# sequential KK14 design, like the nonparametric bootstrap; its golden is now
	# the binary-match test at the end of this file.
	expect_false(obj$supports("randomization_bootstrap"))
	expect_error(obj$approximate_rand_bootstrap_distribution_beta_hat_T(B = 9L, show_progress = FALSE),
		"This method is not supported for DesignSeqOneByOne designs.", fixed = TRUE)
	# The p-value golden was NA_real_; same refusal now.
	expect_error(
		InferenceAllKKWilcoxIVWC$new(kk_wilcox_golden_design())$compute_rand_bootstrap_two_sided_pval(delta = 0, B = 9L, show_progress = FALSE),
		"not supported for DesignSeqOneByOne designs"
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

test_that("KK Wilcoxon randomization bootstrap golden on a binary-match design", {
	skip_on_cran()
	# Recorded 2026-11-15 on kk_wilcox_binary_match_golden_design(); replaces the
	# KK14 golden of 2026-10-12. The draws use the randomization statistic (the
	# standardized W sum, z-score scale) as the randomization distribution does,
	# and equal the debug = TRUE (pure R) path exactly. At B = r = 199 on this
	# fixture the BRT p-value is 0.26 and the randomization p-value 0.34.
	new_obj = function() {
		obj = InferenceAllKKWilcoxIVWC$new(kk_wilcox_binary_match_golden_design())
		obj$set_seed(20260811L)
		obj
	}
	expect_true(new_obj()$supports("randomization_bootstrap"))
	expected = c(
		0.83862786937753464, -1.5724272550828775, 1.1531133203941102,
		0.83862786937753464, 1.3627702877384937, 0.10482848367219183,
		0.94345635304972653, 2.2013981571160284, 1.3627702877384937
	)
	obj = new_obj()
	actual = suppressWarnings(inference_migration_with_seed(20260811L,
		obj$approximate_rand_bootstrap_distribution_beta_hat_T(B = 9L, show_progress = FALSE)))
	expect_equal(actual, expected, tolerance = 1e-8)
	obj = new_obj()
	dbg = suppressWarnings(inference_migration_with_seed(20260811L,
		obj$approximate_rand_bootstrap_distribution_beta_hat_T(B = 9L, show_progress = FALSE, debug = TRUE)))
	expect_equal(dbg$values, expected, tolerance = 1e-8)
})
