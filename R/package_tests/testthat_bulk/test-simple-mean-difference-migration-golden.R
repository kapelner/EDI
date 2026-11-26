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

# v1.0.6-TODO-145 (2026-11-19): every golden below that reads the shared
# continuous fixture was re-recorded after the fixture gained a small seeded
# noise term (inference_migration_complete_design(); its old
# seq(-0.3, 0.3) noise was collinear with x, so y was an exact linear function
# of w, x and z). The values moved only because the data did: before the change
# this file passed unchanged against the old fixture. Unchanged goldens (NA
# results, and values that depend only on ranks or on draw counts) were not
# touched.

simple_mean_difference_golden_design = function(n = 12L, seed = 20260728L) {
	inference_migration_complete_design("continuous", n = n, seed = seed)
}

expect_simple_mean_difference_golden = function(
	label,
	method,
	args,
	expected,
	class_name = "InferenceAllSimpleAverageDiff",
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
		c("get_supported_testing_types", "set_testing_type")
	)

	expected_capabilities = list(
		InferenceAllSimpleAverageDiff = c(
			"randomization_test",
			"randomization_ci",
			"nonparametric_bootstrap",
			"randomization_bootstrap",
			# 2026-08-19 (RandomizationBootstrapCI capability TODO): the CI side
			# of the randomization-bootstrap component now advertises its own
			# capability distinct from the pval side (see contracts_mixins.R).
			"randomization_bootstrap_ci",
			"bayesian_bootstrap",
			"jackknife",
			"wald"
		),
		InferenceAllSimpleMeanDiffPooledVar = c(
			"randomization_test",
			"randomization_ci",
			"nonparametric_bootstrap",
			"randomization_bootstrap",
			"randomization_bootstrap_ci",
			"bayesian_bootstrap",
			"jackknife",
			"wald"
		),
		InferenceAllKKMeanDiffIVWC = c(
			"randomization_test",
			"randomization_ci",
			"nonparametric_bootstrap",
			"randomization_bootstrap",
			"randomization_bootstrap_ci",
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
		0.42050624252614888
	)
	expect_simple_mean_difference_golden(
		"randomization distribution",
		"approximate_randomization_distribution_beta_hat_T",
		list(r = 9L, show_progress = FALSE),
		c(
			0.072735792459449833, 0.3930559530075351, -0.1364814376192634,
			0.12837532708727445, 0.034327893455332159, 0.85831290889699074,
			0.37279231506616317, -0.38952274210802718, -0.28368538920388575
		)
	)
	expect_simple_mean_difference_golden(
		"randomization p-value",
		"compute_rand_two_sided_pval",
		# v1.0.6-TODO-153: r = 12, not 9. With r = 9 the p-value is NA (fewer
		# than the 10 finite draws the randomization p-value needs), so the
		# golden compared NA with NA and could not catch a regression.
		list(delta = 0, r = 12L, show_progress = FALSE),
		# v1.2.0-TODO-207: 2 * (1 + 1) / 13 (smaller tail 1 of 12 draws); was 2 * 1 / 12.
		4 / 13
	)
	expect_simple_mean_difference_golden(
		"bootstrap distribution",
		"approximate_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		c(
			0.7952276101125102, 0.90218796127342848, 0.21965224291348445,
			0.31823731933660682, 0.2989926246826895, 1.0172347539923074,
			0.59177730586700505, 0.92032441339853421, 0.3358196593222379
		)
	)
	expect_simple_mean_difference_golden(
		"bootstrap confidence interval",
		"compute_bootstrap_confidence_interval",
		# v1.0.6-TODO-153: B = 99, not 9. The default type is BCa, which returns
		# NA when its adjusted tail lands within two order statistics of the ends
		# (edi_bootstrap_bca_boundary_warning); at B = 9 the CI and the p-value
		# were NA, and on this fixture the CI first comes back finite at B = 29
		# and the p-value only at B = 99.
		list(alpha = 0.2, B = 99L, show_progress = FALSE),
		c(`10%` = 0.017572753681162796, `90%` = 0.90080356557028407)
	)
	expect_simple_mean_difference_golden(
		"bootstrap p-value",
		"compute_bootstrap_two_sided_pval",
		list(delta = 0, B = 99L, show_progress = FALSE),
		0.1486897851656834
	)
	expect_simple_mean_difference_golden(
		"bayesian bootstrap distribution",
		"approximate_bayesian_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		c(
			0.083783448816805883, 0.45864145032444487, 0.2894626465301765,
			0.69025051365341028, 0.43524150164751307, 0.13009862737703409,
			0.45352305457886721, 0.48295323825027192, 0.49281732552413926
		)
	)
	expect_simple_mean_difference_golden(
		"bayesian bootstrap confidence interval",
		"compute_bayesian_bootstrap_confidence_interval",
		list(alpha = 0.2, B = 9L, show_progress = FALSE),
		c(`10%` = 0.096134163099533404, `90%` = 0.63760166348560454)
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
		0.42050624252614888
	)
	expect_simple_mean_difference_golden(
		"jackknife standard error",
		"compute_jackknife_std_error",
		list(),
		0.3279561961985531
	)
	expect_simple_mean_difference_golden(
		"jackknife confidence interval",
		"compute_jackknife_wald_confidence_interval",
		list(alpha = 0.2),
		c(`10%` = 0.0002134658578409887, `90%` = 0.84079901919445676)
	)
	expect_simple_mean_difference_golden(
		"jackknife p-value",
		"compute_jackknife_wald_two_sided_pval",
		list(delta = 0),
		0.19977163243684684
	)
})

test_that("migrated pooled simple mean difference golden outputs are stable", {
	skip_on_cran()
	class_name = "InferenceAllSimpleMeanDiffPooledVar"
	expect_simple_mean_difference_golden(
		"pooled estimate",
		"compute_estimate",
		list(),
		0.42050624252614888,
		class_name = class_name
	)
	expect_simple_mean_difference_golden(
		"pooled asymptotic confidence interval",
		"compute_asymp_confidence_interval",
		list(alpha = 0.2),
		c(`10%` = 0.0062125631167174178, `90%` = 0.83479992193558039),
		class_name = class_name
	)
	expect_simple_mean_difference_golden(
		"pooled asymptotic p-value",
		"compute_asymp_two_sided_pval",
		list(delta = 0),
		0.19388041594393407,
		class_name = class_name
	)
	expect_simple_mean_difference_golden(
		"pooled randomization distribution",
		"approximate_randomization_distribution_beta_hat_T",
		list(r = 9L, show_progress = FALSE),
		c(
			0.072735792459449833, 0.3930559530075351, -0.1364814376192634,
			0.12837532708727445, 0.034327893455332159, 0.85831290889699074,
			0.37279231506616317, -0.38952274210802718, -0.28368538920388575
		),
		class_name = class_name
	)
	expect_simple_mean_difference_golden(
		"pooled bootstrap distribution",
		"approximate_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		c(
			0.7952276101125102, 0.90218796127342848, 0.21965224291348445,
			0.31823731933660682, 0.2989926246826895, 1.0172347539923074,
			0.59177730586700505, 0.92032441339853421, 0.3358196593222379
		),
		class_name = class_name
	)
	expect_simple_mean_difference_golden(
		"pooled bayesian bootstrap distribution",
		"approximate_bayesian_bootstrap_distribution_beta_hat_T",
		list(B = 9L, show_progress = FALSE),
		c(
			0.083783448816805883, 0.45864145032444487, 0.2894626465301765,
			0.69025051365341028, 0.43524150164751307, 0.13009862737703409,
			0.45352305457886721, 0.48295323825027192, 0.49281732552413926
		),
		class_name = class_name
	)
	expect_simple_mean_difference_golden(
		"pooled jackknife standard error",
		"compute_jackknife_std_error",
		list(),
		0.3279561961985531,
		class_name = class_name
	)
})
