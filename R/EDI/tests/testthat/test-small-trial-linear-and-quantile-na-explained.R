# v1.0.7-TODO-181: on real trials of 4 to 20 subjects (the real-data crash corpus,
# R/package_tests/real_data_crash_corpus.R) InferenceContinLin, InferenceContinOLS and
# InferenceContinQuantileRegr returned NA estimates / Wald results with no warning. A
# saturated fit cannot do better, but every call that returns the NA must say why
# (edi_procedure_na_warning), as InferenceSurvivalKMDiff does (v1.0.7-TODO-182).

small_trial_design = function(n_levels) {
	# Shaped like asbio::potash: 6 plots in 3 blocks, a block factor as the only covariate.
	X = data.frame(block = factor(rep(seq_len(n_levels), each = 2L)))
	y = c(7.6, 7.9, 8.1, 7.4, 8.4, 7.3)[seq_len(nrow(X))]
	des = DesignFixedBernoulli$new(n = nrow(X), response_type = "continuous")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects(w_precomputed = rep(c(0, 1), length.out = nrow(X)))
	des$add_all_subject_responses(ys = y)
	des
}

test_that("InferenceContinLin explains an NA estimate and NA Wald results on a saturated trial", {
	des = small_trial_design(3L)
	inf = InferenceContinLin$new(des)
	expect_warning(est <- inf$compute_estimate(), class = "edi_estimate_unavailable_warning")
	expect_true(is.na(est))
	expect_identical(inf$get_nonestimable_reason(), "linear_model_design_unusable")
	expect_warning(pv <- inf$compute_asymp_two_sided_pval(), class = "edi_wald_unavailable_warning")
	expect_true(is.na(pv))
})

test_that("InferenceContinLin warns on every call that returns the NA, with the fit's reason", {
	inf = InferenceContinLin$new(small_trial_design(3L))
	expect_warning(ci <- inf$compute_asymp_confidence_interval(), "linear_model_design_unusable",
		class = "edi_wald_unavailable_warning")
	expect_true(all(is.na(ci)))
	# A second call is not silent (the corpus calls estimate, p-value and CI on one object).
	expect_warning(inf$compute_asymp_confidence_interval(), class = "edi_wald_unavailable_warning")
	expect_warning(inf$compute_asymp_two_sided_pval(), class = "edi_wald_unavailable_warning")
	expect_warning(inf$compute_estimate(), class = "edi_estimate_unavailable_warning")
	expect_warning(inf$compute_estimate(), class = "edi_estimate_unavailable_warning")
})

test_that("InferenceContinOLS explains an NA Wald result when no residual degrees of freedom remain", {
	# 6 subjects, intercept + treatment + 4 block dummies = 6 columns: the estimate exists, the SE does not.
	X = data.frame(block = factor(1:6))
	des = DesignFixedBernoulli$new(n = 6L, response_type = "continuous")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects(w_precomputed = c(0, 1, 0, 1, 0, 1))
	des$add_all_subject_responses(ys = c(7.6, 7.9, 8.1, 7.4, 8.4, 7.3))
	inf = InferenceContinOLS$new(des)
	expect_true(is.finite(inf$compute_estimate()))
	expect_warning(pv <- inf$compute_asymp_two_sided_pval(), "no_residual_degrees_of_freedom",
		class = "edi_wald_unavailable_warning")
	expect_true(is.na(pv))
})

test_that("InferenceContinQuantileRegr explains an NA estimate on a saturated trial", {
	X = data.frame(block = factor(1:6))
	des = DesignFixedBernoulli$new(n = 6L, response_type = "continuous")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects(w_precomputed = c(0, 1, 0, 1, 0, 1))
	des$add_all_subject_responses(ys = c(7.6, 7.9, 8.1, 7.4, 8.4, 7.3))
	inf = InferenceContinQuantileRegr$new(des)
	expect_warning(est <- inf$compute_estimate(), class = "edi_estimate_unavailable_warning")
	expect_true(is.na(est))
	expect_warning(ci <- inf$compute_asymp_confidence_interval(), class = "edi_wald_unavailable_warning")
	expect_true(all(is.na(ci)))
})

test_that("the warnings stay quiet on a well-posed fit", {
	set.seed(1)
	n = 40L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects(w_precomputed = rep(c(0, 1), n / 2))
	des$add_all_subject_responses(ys = X$x1 + rnorm(n))
	for (cls in list(InferenceContinLin, InferenceContinOLS, InferenceContinQuantileRegr)) {
		inf = cls$new(des)
		expect_no_warning(inf$compute_estimate())
		expect_no_warning(inf$compute_asymp_two_sided_pval())
		expect_no_warning(inf$compute_asymp_confidence_interval())
	}
})
