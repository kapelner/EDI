library(testthat)
library(EDI)

# InferenceExtMinimumVolatilitySelector$select_optimal_resample_size() (inference_ext_
# minimum_volatility_selector.R), spliced into InferenceNonParamBootstrap and reachable
# via the public select_optimal_m_out_of_n_bootstrap()/select_optimal_prw_subsample_size()
# wrappers, validates its volatility_window argument past the upstream assertCount(positive
# = TRUE) check (which only rejects non-positive/non-integer values, not even numbers or
# values below 3): (1) volatility_window < 3 or even is rejected with "volatility_window
# must be an odd integer >= 3."; (2) a size_grid with fewer unique candidate sizes than
# volatility_window is rejected with "size_grid must have at least volatility_window unique
# values." A codebase-wide grep confirmed both exact messages had zero test references
# anywhere, despite this shared selector's happy path being exercised across many
# m-out-of-n-bootstrap and PRW-subsampling test files. Exercised via the public
# select_optimal_m_out_of_n_bootstrap() wrapper on a real InferenceAllSimpleAverageDiff
# instance, no mocking needed -- both guards fire before any resampling evaluator runs.

fx <- function(seed = 1L, n = 60L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + 0.5 * w)
	InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
}

test_that("an even volatility_window is rejected with the documented 'must be an odd integer >= 3' message", {
	inf <- fx()
	expect_error(
		inf$select_optimal_m_out_of_n_bootstrap(B = 21L, volatility_window = 2L, show_progress = FALSE),
		"volatility_window must be an odd integer >= 3.",
		fixed = TRUE
	)
})

test_that("volatility_window = 1 (odd but below 3) is rejected by the same guard", {
	inf <- fx(seed = 2L)
	expect_error(
		inf$select_optimal_m_out_of_n_bootstrap(B = 21L, volatility_window = 1L, show_progress = FALSE),
		"volatility_window must be an odd integer >= 3.",
		fixed = TRUE
	)
})

test_that("a volatility_window wider than the number of unique candidate sizes is rejected", {
	inf <- fx(seed = 3L)
	expect_error(
		inf$select_optimal_m_out_of_n_bootstrap(B = 21L, volatility_window = 51L, show_progress = FALSE),
		"size_grid must have at least volatility_window unique values.",
		fixed = TRUE
	)
})
