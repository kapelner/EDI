library(testthat)
library(EDI)

# DesignFixedGreedy and DesignFixedMatchingGreedyPairSwitching each carry their own n_iter
# construction-time guard ("n_iter must be Inf or a positive integer"), distinct code sites from the
# already-tested DesignFixedGreedyDOptimal sibling (which additionally forbids any finite n_iter
# entirely -- these two classes instead genuinely support a finite iteration count and only reject a
# non-numeric/non-positive/non-integer value). Neither class's own guard site had any test
# references anywhere.

test_that("DesignFixedGreedy: a non-numeric n_iter errors with the documented message", {
	expect_error(
		DesignFixedGreedy$new(response_type = "continuous", n = 10, n_iter = "bogus", verbose = FALSE),
		"n_iter must be Inf or a positive integer"
	)
})

test_that("DesignFixedGreedy: a finite positive integer n_iter constructs without error", {
	expect_no_error(DesignFixedGreedy$new(response_type = "continuous", n = 10, n_iter = 50L, verbose = FALSE))
})

test_that("DesignFixedMatchingGreedyPairSwitching: a non-numeric n_iter errors with the documented message", {
	expect_error(
		DesignFixedMatchingGreedyPairSwitching$new(response_type = "continuous", n = 8, n_iter = "bogus", verbose = FALSE),
		"n_iter must be Inf or a positive integer"
	)
})

test_that("DesignFixedMatchingGreedyPairSwitching: a finite positive integer n_iter constructs without error", {
	expect_no_error(DesignFixedMatchingGreedyPairSwitching$new(response_type = "continuous", n = 8, n_iter = 50L, verbose = FALSE))
})
