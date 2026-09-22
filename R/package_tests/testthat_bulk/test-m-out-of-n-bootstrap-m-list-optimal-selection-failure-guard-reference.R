library(testthat)
library(EDI)

# InferenceNonParamBootstrap$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(): when m is passed as a
# LIST (data-adaptive mode), it delegates to select_optimal_m_out_of_n_bootstrap() and asserts the chosen
# m_optimal is finite before using it, erroring with "m-out-of-n bootstrap m selection failed." otherwise --
# the exact same shape as the already-tested PRW subsampling b-as-list guard
# (test-prw-subsampling-b-list-optimal-selection-failure-guard-reference.R), but this m-out-of-n sibling had no
# test calling it with m as a list at all.

fx <- function(seed = 1L, n = 60L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rnorm(n) + 0.5 * w)
	InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
}

test_that("a non-finite m_optimal from select_optimal_m_out_of_n_bootstrap() errors with the documented message", {
	inf <- fx()
	unlockBinding("select_optimal_m_out_of_n_bootstrap", inf)
	inf$select_optimal_m_out_of_n_bootstrap <- function(...) list(m_optimal = NA_real_)
	expect_error(
		inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = 10, m = list(), show_progress = FALSE),
		"m-out-of-n bootstrap m selection failed\\."
	)

	inf2 <- fx()
	unlockBinding("select_optimal_m_out_of_n_bootstrap", inf2)
	inf2$select_optimal_m_out_of_n_bootstrap <- function(...) list(m_optimal = Inf)
	expect_error(
		inf2$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = 10, m = list(), show_progress = FALSE),
		"m-out-of-n bootstrap m selection failed\\."
	)
})

test_that("select_optimal_m_out_of_n_bootstrap() is called with the list's own B/alpha overrides, not the defaults", {
	inf <- fx()
	captured <- NULL
	unlockBinding("select_optimal_m_out_of_n_bootstrap", inf)
	inf$select_optimal_m_out_of_n_bootstrap <- function(...) { captured <<- list(...); list(m_optimal = 8L) }
	inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = 30, m = list(B = 77L, alpha = 0.2), show_progress = FALSE)
	expect_equal(captured$B, 77L)
	expect_equal(captured$alpha, 0.2)
})

test_that("a real (unstubbed) list-m call succeeds end to end and returns B finite draws", {
	inf <- fx()
	d <- inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = 15, m = list(B = 15, alpha = 0.1), show_progress = FALSE)
	expect_length(d, 15L)
	expect_true(all(is.finite(d)))
})
