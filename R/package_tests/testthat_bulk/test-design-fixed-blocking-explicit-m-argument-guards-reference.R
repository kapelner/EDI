library(testthat)
library(EDI)

# DesignFixedBlocking$new()'s explicit-m constructor path (an alternative to covariate-derived strata): supplying
# m requires n to also be supplied, and length(m) must equal n -- the same argument-consistency shape as
# DesignFixedBinaryMatch's explicit-m guards (test-design-fixed-binary-match-explicit-m-and-prob-t-argument-guards-reference.R),
# but this class's own copy had no test calling either guard; existing coverage of this well-tested class only
# exercises the normal covariate-derived strata construction path.

test_that("supplying m without n is rejected", {
	expect_error(
		DesignFixedBlocking$new(response_type = "continuous", m = c(1, 1, 2, 2), verbose = FALSE, equal_block_sizes = FALSE),
		"When supplying m to DesignFixedBlocking\\$new\\(\\), n must also be supplied\\."
	)
})

test_that("length(m) not equal to n is rejected", {
	expect_error(
		DesignFixedBlocking$new(response_type = "continuous", m = c(1, 1, 2, 2), n = 6L, verbose = FALSE, equal_block_sizes = FALSE),
		"When supplying m to DesignFixedBlocking\\$new\\(\\), length\\(m\\) must equal n\\."
	)
})

test_that("a valid explicit m (n supplied, matching length) constructs and immediately records the given blocking structure, bypassing covariate-derived strata", {
	des <- DesignFixedBlocking$new(response_type = "continuous", m = c(1, 1, 2, 2), n = 4L, verbose = FALSE, equal_block_sizes = FALSE)
	expect_identical(des$.__enclos_env__$private$m, c(1L, 1L, 2L, 2L))
})
