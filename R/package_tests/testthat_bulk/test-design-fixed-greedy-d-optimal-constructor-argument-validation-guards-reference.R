library(testthat)
library(EDI)

# DesignFixedGreedyDOptimal$new() has three always-on construction-time guards (design_fixed_greedy_
# d_optimal.R, ~line 206-225), none previously exercised for THIS class: prob_T outside (0, 1) (same
# message text as the already-tested DesignFixedOptimal sibling, but a distinct guard site on a
# distinct class), a non-numeric-scalar n_iter, and a finite n_iter (the not-yet-implemented
# stochastic swap mode -- this class currently only supports n_iter = Inf).

test_that("prob_T outside (0, 1) errors with the documented message", {
	expect_error(
		DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 10, prob_T = 1.5, verbose = FALSE),
		"prob_T must be a single number strictly between 0 and 1\\."
	)
})

test_that("a non-numeric-scalar n_iter errors with the documented message", {
	expect_error(
		DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 10, n_iter = "bogus", verbose = FALSE),
		"n_iter must be Inf or a positive integer\\."
	)
})

test_that("a finite n_iter (unimplemented stochastic swap mode) errors with the documented message", {
	expect_error(
		DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 10, n_iter = 100L, verbose = FALSE),
		"Finite n_iter \\(the stochastic swap mode\\) arrives with the Stage-2 shared search engine"
	)
})

test_that("n_iter = Inf (the default) does not error", {
	expect_no_error(DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 10, n_iter = Inf, verbose = FALSE))
})
