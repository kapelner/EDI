library(testthat)
library(EDI)

# DesignBlockingAbstract's public summarize_blocks(block_ids) (design_blocking_abstract.R:124-137)
# warns, rather than erroring or silently returning an empty entry, when a requested block_id has
# no matching subjects in the design -- warning(paste("Block ID", bid, "not found in the design.")).
# A codebase-wide grep confirmed this exact message had zero test references anywhere, despite
# summarize_blocks() and the blocking machinery it composes being otherwise well exercised.
# Exercised via a real DesignFixedBlocking instance, requesting a block_ids vector that includes a
# genuinely nonexistent block id.

test_that("summarize_blocks() warns when a requested block_id doesn't exist in the design", {
	set.seed(1)
	n <- 12L
	des <- DesignFixedBlocking$new(n = n, B_target = 3L, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))

	real_block <- des$get_block_ids()[1]
	expect_warning(
		res <- des$summarize_blocks(block_ids = c(real_block, 9999)),
		"Block ID 9999 not found in the design.",
		fixed = TRUE
	)
	# the unmatched block_id is silently skipped (not added to the result), after warning
	expect_length(res, 1L)
})

test_that("summarize_blocks() with only real block_ids does not warn", {
	set.seed(2)
	n <- 12L
	des <- DesignFixedBlocking$new(n = n, B_target = 3L, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	expect_no_warning(des$summarize_blocks())
})
