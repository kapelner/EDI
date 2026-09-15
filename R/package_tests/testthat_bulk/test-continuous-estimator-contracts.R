library(testthat)
library(EDI)

make_continuous_estimator_design = function(n = 20L, seed = 980L) {
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = seq(-1, 1, length.out = n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = 2 + 1.5 * w + seq_len(n) / n
	des$add_all_subject_responses(y)
	list(des = des, w = w, y = y)
}

test_that("simple average difference matches direct estimates and weighted refits", {
	d = make_continuous_estimator_design()
	inf = InferenceAllSimpleAverageDiff$new(d$des)
	expected = mean(d$y[d$w == 1]) - mean(d$y[d$w == 0])
	expect_equal(inf$compute_estimate(), expected)
	expect_equal(inf$compute_estimate(estimate_only = TRUE), expected)
	expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
	ci = inf$compute_asymp_confidence_interval()
	expect_length(ci, 2L)
	expect_true(all(is.finite(ci)))

	expect_error(
		inf$compute_estimate_with_bootstrap_weights(rep(1, length(d$y))),
		"No Bayesian-bootstrap context"
	)
})

test_that("simple Wilcoxon Hodges-Lehmann helper handles weights and empty arms", {
	d = make_continuous_estimator_design(seed = 981L)
	inf = InferenceAllSimpleWilcox$new(d$des)
	p = inf$.__enclos_env__$private
	pair_diffs = as.vector(outer(d$y[d$w == 1], d$y[d$w == 0], "-"))
	expect_equal(p$hl_point_estimate(d$y, d$w), median(pair_diffs))
	expect_equal(p$hl_point_estimate(d$y, d$w, rep(1, length(d$y))), median(pair_diffs))
	expect_true(is.na(p$hl_point_estimate(d$y, rep(1, length(d$w)))))
	expect_true(is.na(p$hl_point_estimate(d$y, d$w, rep(0, length(d$w)))))
	expect_equal(inf$compute_estimate(), median(pair_diffs))
	expect_identical(inf$get_supported_testing_types(), "wald")
	expect_false(inf$supports("bayesian_bootstrap"))
})

test_that("average-difference affine bootstrap coefficients have draw-aligned shape", {
	d = make_continuous_estimator_design(seed = 982L)
	inf = InferenceAllSimpleAverageDiff$new(d$des)
	p = inf$.__enclos_env__$private
	draws = list(
		list(i_b = seq_along(d$y), w_b = d$w),
		list(i_b = rev(seq_along(d$y)), w_b = rev(d$w))
	)
	affine = p$compute_rand_bootstrap_ci_affine_coefs(draws)
	expect_named(affine, c("A", "c"))
	expect_length(affine$A, 2L)
	expect_length(affine$c, 2L)
	expect_true(all(is.finite(affine$A)))
	expect_true(all(is.finite(affine$c)))
})

test_that("continuous KK class generators retain their estimator-specific contracts", {
	expect_true("glmm_response_type" %in% names(InferenceContinKKGLMM$private_methods))
	expect_true("weighted_rcpp_estimate" %in% names(InferenceContinKKGLMM$private_methods))
	expect_true("compute_fast_bootstrap_distr" %in% names(EDI:::InferenceAllKKMeanDiffIVWC$private_methods))
	expect_true("rank_for_matched_pairs" %in% names(EDI:::InferenceAllKKWilcoxIVWC$private_methods))
	expect_true("rank_for_reservoir" %in% names(EDI:::InferenceAllKKWilcoxIVWC$private_methods))
	expect_true("tau" %in% names(InferenceContinKKQuantileRegrIVWC$private_fields))
	expect_true("tau" %in% names(InferenceContinKKQuantileRegrOneLik$private_fields))
	expect_true("compute_estimate_with_bootstrap_weights" %in% names(InferenceContinKKQuantileRegrIVWC$public_methods))
	expect_true("compute_estimate_with_bootstrap_weights" %in% names(InferenceContinKKQuantileRegrOneLik$public_methods))
})
