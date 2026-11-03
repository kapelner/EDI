library(testthat)
library(EDI)

# Three small, otherwise well-tested fixed-design constructors each carry a self-contained
# validation guard with zero test references anywhere (confirmed via codebase-wide grep):
#   1. DesignFixedBlocking$new(equal_block_sizes = TRUE, n, B_target): rejects an n not
#      divisible by B_target with "equal_block_sizes = TRUE requires n to be divisible by
#      B_target, but n = ... is not divisible by B_target = ...". The sibling guards on the
#      same `if (!is.null(m))` block (n/m-supplied-together, length(m) == n) are already
#      covered; this third, independent equal_block_sizes branch was not.
#   2. DesignFixedGreedy$new(prob_T != 0.5): originally rejected because the C++ kernel
#      hardcoded nt = n / 2 (fix_design_hierarchy.md TODO-33). Since 2026-11-03 the kernel
#      takes n_T = round(n * prob_T), so the test now asserts acceptance.
#   3. DesignFixedFactorial$new(factors): rejects any `factors` combination that doesn't
#      imply exactly 2 total combinations (two-arm only) -- "DesignFixedFactorial currently
#      only supports exactly two total factor-level combinations...".
# All three exercised via the plain public constructor, no mocking needed.

test_that("DesignFixedBlocking rejects equal_block_sizes = TRUE when n is not divisible by B_target", {
	expect_error(
		DesignFixedBlocking$new(n = 10L, B_target = 3L, equal_block_sizes = TRUE, response_type = "continuous", verbose = FALSE),
		"equal_block_sizes = TRUE requires n to be divisible by B_target",
		fixed = TRUE
	)
})

test_that("DesignFixedBlocking accepts equal_block_sizes = TRUE when n IS divisible by B_target", {
	expect_silent(DesignFixedBlocking$new(n = 12L, B_target = 3L, equal_block_sizes = TRUE, response_type = "continuous", verbose = FALSE))
})

test_that("DesignFixedGreedy accepts a non-0.5 prob_T (unequal-arm support, 2026-11-03; registry supports_unequal_allocation = TRUE)", {
	des <- DesignFixedGreedy$new(n = 10L, prob_T = 0.6, response_type = "continuous", verbose = FALSE)
	expect_equal(des$get_prob_T(), 0.6)
})

test_that("DesignFixedFactorial rejects a factors argument implying more than 2 total combinations", {
	expect_error(
		DesignFixedFactorial$new(n = 12L, factors = list(2, 3), response_type = "continuous", verbose = FALSE),
		"DesignFixedFactorial currently only supports exactly two total factor-level combinations",
		fixed = TRUE
	)
})

test_that("DesignFixedFactorial accepts a single two-level factor (implies exactly 2 combinations)", {
	expect_silent(DesignFixedFactorial$new(n = 12L, factors = list(2), response_type = "continuous", verbose = FALSE))
})
