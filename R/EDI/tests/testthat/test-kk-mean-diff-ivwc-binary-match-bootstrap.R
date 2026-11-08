# TODO-130 (2026-10-22): InferenceAllKKMeanDiffIVWC's fast compound bootstrap
# errored "Wrong R type for mapped matrix" on DesignFixedBinaryMatch, whose
# assignment vector is double-stored: w[i_b] promoted the integer w_mat to
# double before the Eigen::MatrixXi map in
# compute_matching_compound_bootstrap_parallel_cpp().

make_binary_match_ivwc_design = function(response_type = "continuous"){
	set.seed(1)
	n = 40L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedBinaryMatch$new(n = n, response_type = response_type, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = if (response_type == "count") rpois(n, 2 + w) else rnorm(n) + w
	des$add_all_subject_responses(y)
	des
}

test_that("KK mean-diff IVWC bootstrap runs on DesignFixedBinaryMatch (double-stored w)", {
	des = make_binary_match_ivwc_design()
	expect_identical(storage.mode(des$get_w()), "double")  # the trigger
	inf = InferenceAllKKMeanDiffIVWC$new(des, verbose = FALSE)
	inf$set_seed(5)
	boot = inf$approximate_bootstrap_distribution_beta_hat_T(B = 51)
	expect_length(boot, 51L)
	expect_true(all(is.finite(boot)))
	ci = inf$compute_bootstrap_confidence_interval(B = 201, type = "percentile")
	expect_true(all(is.finite(ci)))
	expect_lt(ci[1], inf$compute_estimate())
	expect_gt(ci[2], inf$compute_estimate())
})

test_that("KK mean-diff IVWC fast bootstrap agrees in distribution with the slow per-draw path", {
	skip_on_cran()
	des = make_binary_match_ivwc_design()
	inf_fast = InferenceAllKKMeanDiffIVWC$new(des, verbose = FALSE)
	inf_fast$set_seed(5)
	fast = inf_fast$approximate_bootstrap_distribution_beta_hat_T(B = 1000)
	inf_slow = InferenceAllKKMeanDiffIVWC$new(des, verbose = FALSE)
	inf_slow$set_seed(5)
	slow = inf_slow$approximate_bootstrap_distribution_beta_hat_T(B = 1000, debug = TRUE)
	slow = vapply(slow, function(z) as.numeric(z$val), numeric(1))
	expect_true(all(is.finite(fast)))
	expect_equal(mean(fast), mean(slow), tolerance = 0.05)
	expect_equal(stats::sd(fast), stats::sd(slow), tolerance = 0.15)
})

test_that("KK mean-diff IVWC bootstrap runs on DesignFixedBinaryMatch for count responses", {
	des = make_binary_match_ivwc_design("count")
	inf = InferenceAllKKMeanDiffIVWC$new(des, verbose = FALSE)
	inf$set_seed(5)
	boot = inf$approximate_bootstrap_distribution_beta_hat_T(B = 31)
	expect_true(all(is.finite(boot)))
})
