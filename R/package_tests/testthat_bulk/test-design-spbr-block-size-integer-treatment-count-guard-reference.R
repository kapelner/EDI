library(testthat)
library(EDI)

# DesignSeqOneByOneSPBR$new() has an always-on construction-time guard: block_size * prob_T must be
# (approximately) an integer, i.e. every block must have a whole number of treatment slots; if not,
# it errors "block_size must result in an integer number of treatment assignments (block_size *
# prob_T)." Zero test references anywhere despite this class being otherwise well-tested (test-
# designs.R, test-design-sequential-strata-bootstrap-golden.R, and others all use a compatible
# block_size/prob_T pair).

test_that("a block_size incompatible with prob_T errors with the documented message", {
	expect_error(
		DesignSeqOneByOneSPBR$new(response_type = "continuous", strata_cols = "stratum", block_size = 3L, prob_T = 0.5, n = 8, verbose = FALSE),
		"block_size must result in an integer number of treatment assignments \\(block_size \\* prob_T\\)\\."
	)
})

test_that("a compatible block_size/prob_T pair constructs without error", {
	expect_no_error(DesignSeqOneByOneSPBR$new(response_type = "continuous", strata_cols = "stratum", block_size = 4L, prob_T = 0.5, n = 8, verbose = FALSE))
})
