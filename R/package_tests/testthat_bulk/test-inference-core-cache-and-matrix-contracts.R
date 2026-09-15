library(testthat)
library(EDI)

make_core_probe = function(n = 18L, seed = 970L, ols = TRUE) {
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(0.6 * des$get_w() + rnorm(n))
	if (ols) InferenceContinOLS$new(des) else InferenceAllSimpleAverageDiff$new(des)
}

test_that("inference-core warm starts and likelihood caches normalize keys", {
	inf = make_core_probe()
	p = inf$.__enclos_env__$private
	expect_identical(p$normalize_likelihood_test_delta(-0), 0)
	expect_identical(p$likelihood_test_delta_key("score", 0.25), "score::0.25")
	expect_null(p$get_likelihood_test_eval_entry("score", 0.25))
	p$set_likelihood_test_eval_entry("score", 0.25, list(pval = 0.4))
	expect_equal(p$get_likelihood_test_eval_entry("score", 0.25)$pval, 0.4)
	expect_true(length(p$get_likelihood_test_eval_cache()) == 1L)
	p$clear_likelihood_test_eval_cache()
	expect_identical(p$get_likelihood_test_eval_cache(), list())

	p$fit_warm_start_enabled = TRUE
	p$set_fit_warm_start(c(1, 2), type = "beta", fisher = diag(2), weights = 1:18)
	expect_identical(p$get_fit_warm_start("beta"), c(1, 2))
	expect_identical(p$get_fit_warm_start_for_length("beta", 2L), c(1, 2))
	expect_null(p$get_fit_warm_start_for_length("beta", 3L))
	expect_equal(p$get_fit_warm_start_fisher(2L), diag(2))
	expect_null(p$get_fit_warm_start_fisher(3L))
	expect_identical(p$get_fit_warm_start_weights(18L), 1:18)
	expect_null(p$get_fit_warm_start_weights(2L))
	p$clear_fit_warm_start()
	expect_null(p$get_fit_warm_start("beta"))
})

test_that("information-matrix helpers invert regular and singular inputs safely", {
	p = make_core_probe()$.__enclos_env__$private
	info = diag(c(4, 9))
	expect_equal(p$compute_variance_from_information_matrix(info, 2L), 1 / 9)
	expect_true(is.na(p$compute_variance_from_information_matrix(info, 3L)))
	expect_true(is.na(p$compute_variance_from_information_matrix(matrix(NA_real_, 2, 2), 1L)))

	score = c(2, 3)
	regular = p$score_test_with_ridge_fallback(score, info, 2L)
	expect_true(is.finite(regular))
	expect_true(regular >= 0 && regular <= 1)

	singular = p$score_test_with_ridge_fallback(score, matrix(c(1, 1, 1, 1), 2), 2L)
	expect_true(is.finite(singular))
	expect_true(singular >= 0 && singular <= 1)
})

test_that("CI inversion finalization orders finite bounds and falls back predictably", {
	p = make_core_probe()$.__enclos_env__$private
	ci = p$finalize_inverted_ci(c(2, -1), 0.05, est = 0.5, wald_ci = c(-2, 3), unavailable_reason = "probe")
	expect_equal(unname(ci), c(-1, 2))
	expect_identical(names(ci), c("2.5%", "97.5%"))

	fallback = p$finalize_inverted_ci(c(NA, NA), 0.05, est = 0.5, wald_ci = c(-2, 3), unavailable_reason = "probe")
	expect_equal(unname(fallback), c(-2, 3))
})

test_that("jackknife unit normalization and cache keys are canonical", {
	p = make_core_probe(ols = FALSE)$.__enclos_env__$private
	expect_identical(p$normalize_jackknife_unit("AUTO"), "auto")
	expect_identical(p$normalize_jackknife_unit("observation"), "observation")
	expect_error(p$normalize_jackknife_unit("subject"), "unit")
	expect_identical(p$resolve_jackknife_unit("auto"), "observation")
	expect_identical(p$jackknife_cache_key("observation"), "observation")
})

test_that("standard-model and KK mixin contracts retain required hooks", {
	expect_true("compute_estimate" %in% names(EDI:::InferenceAsympLikStdModCache$public_methods))
	expect_true("shared" %in% names(EDI:::InferenceAsympLikStdModCache$private_methods))
	kk = EDI:::get_inference_component("KKPassThrough")
	compound = EDI:::get_inference_component("KKCompound")
	expect_true("approximate_bootstrap_distribution_beta_hat_T" %in% EDI:::component_public_names(kk))
	expect_true("compute_basic_kk_match_data_impl" %in% EDI:::component_private_names(kk))
	expect_true("compute_estimate_from_matched_and_reservoir" %in% EDI:::component_private_names(compound))
	expect_true("reduce_design_matrix_once" %in% EDI:::component_private_names(compound))
})
