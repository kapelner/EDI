library(testthat)
library(EDI)

# DesignFixedBlocking's own call site to the shared private assert_min_block_size()
# (design_blocking_abstract.R, DESIGN_BLOCKING_STRUCTURE_PRIVATE, also used by
# DesignFixedOptimalBlocks) had no test reference anywhere -- confirmed via a zero-hit grep for the
# function's own name across the whole test suite, and via grep for the exact guard message ("Minimum
# block size is 2") only ever appearing paired with DesignFixedOptimalBlocks
# (test-fixed-optimal-blocks-feasibility-draws-and-uneven-sizes-reference.R), never with
# DesignFixedBlocking. DesignFixedBlocking reaches this guard via a materially different code path
# (strata-based, explicit B_target at construction, gated specifically on equal_block_sizes = TRUE --
# unlike DesignFixedOptimalBlocks' covariate-clustering B) that had never been exercised.
#   1. n and B_target that produce a block size below 2 (floor(n / B_target) < 2), with the default
#      equal_block_sizes = TRUE, errors with the documented message at construction time.
#   2. Exactly 2 subjects per block (the boundary case) does NOT error.
#   3. The SAME n/B_target combination that would fail under equal_block_sizes = TRUE does NOT reach
#      this guard at all when equal_block_sizes = FALSE (assert_min_block_size() is nested inside
#      that condition specifically, a distinct branch from DesignFixedOptimalBlocks' own unconditional
#      call).

test_that("n and B_target giving a block size below 2, with equal_block_sizes = TRUE, errors with the documented message", {
	expect_error(
		DesignFixedBlocking$new(n = 10, response_type = "continuous", B_target = 10L, equal_block_sizes = TRUE, verbose = FALSE),
		"Cannot use B = 10 with n = 10: floor\\(n / B\\) = 1 < 2\\. Minimum block size is 2\\."
	)
})

test_that("exactly 2 subjects per block (the boundary case) does NOT error", {
	des <- DesignFixedBlocking$new(n = 10, response_type = "continuous", B_target = 5L, equal_block_sizes = TRUE, verbose = FALSE)
	expect_s3_class(des, "DesignFixedBlocking")
})

test_that("the same n/B_target combination does not reach this guard at all when equal_block_sizes = FALSE", {
	des <- DesignFixedBlocking$new(n = 10, response_type = "continuous", B_target = 10L, equal_block_sizes = FALSE, verbose = FALSE)
	expect_s3_class(des, "DesignFixedBlocking")
})
