library(testthat)
library(EDI)

# InferenceNonParamBootstrap$approximate_subsampling_distribution_beta_hat_T(): when b is passed as a LIST
# (data-adaptive mode), it delegates to select_optimal_b_subsampling() and asserts the chosen b_optimal is
# finite before using it, erroring with "PRW subsampling b selection failed." otherwise rather than passing a
# non-finite subsample size downstream. No test anywhere called this method with b as a list at all (existing
# coverage only passes b as a fixed count, NULL, or the string "auto"), so neither the list-b dispatch itself
# nor this specific failure guard were exercised.

fx <- function(seed = 1L, n = 60L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rnorm(n) + 0.5 * w)
	InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
}

test_that("a non-finite b_optimal from select_optimal_b_subsampling() errors with the documented message", {
	inf <- fx()
	unlockBinding("select_optimal_b_subsampling", inf)
	inf$select_optimal_b_subsampling <- function(...) list(b_optimal = NA_real_)
	expect_error(
		inf$approximate_subsampling_distribution_beta_hat_T(B = 10, b = list(), show_progress = FALSE),
		"PRW subsampling b selection failed\\."
	)

	inf2 <- fx()
	unlockBinding("select_optimal_b_subsampling", inf2)
	inf2$select_optimal_b_subsampling <- function(...) list(b_optimal = Inf)
	expect_error(
		inf2$approximate_subsampling_distribution_beta_hat_T(B = 10, b = list(), show_progress = FALSE),
		"PRW subsampling b selection failed\\."
	)
})

test_that("select_optimal_b_subsampling() is called with the list's own B/alpha overrides, not the defaults", {
	inf <- fx()
	captured <- NULL
	unlockBinding("select_optimal_b_subsampling", inf)
	inf$select_optimal_b_subsampling <- function(...) { captured <<- list(...); list(b_optimal = 8L) }
	inf$approximate_subsampling_distribution_beta_hat_T(B = 30, b = list(B = 77L, alpha = 0.2), show_progress = FALSE)
	expect_equal(captured$B, 77L)
	expect_equal(captured$alpha, 0.2)
})

test_that("a real (unstubbed) list-b call succeeds end to end and returns B finite draws", {
	inf <- fx()
	d <- inf$approximate_subsampling_distribution_beta_hat_T(B = 15, b = list(B = 15, alpha = 0.1), show_progress = FALSE)
	expect_length(d, 15L)
	expect_true(all(is.finite(d)))
})
