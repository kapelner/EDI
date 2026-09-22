library(testthat)
library(EDI)

# DesignFixedBlocking with exact_num_blocks = TRUE: the greedy strata-key construction (get_strata_keys(),
# design_blocking_abstract.R) must land on EXACTLY B_target blocks or it hard-errors -- the binning search that
# tries to hit the target only adjusts NUMERIC covariate columns' bin count; a non-numeric (factor/character)
# strata column is used as-is regardless of B_target, so a categorical column whose own cardinality doesn't match
# B_target deterministically trips this guard. Reached lazily (not at construction, but the first time strata are
# actually needed, e.g. assign_w_to_all_subjects()). No test anywhere triggered it; existing exact_num_blocks
# coverage only exercises the (different) "B_target missing" guard.

test_that("a non-numeric strata column whose cardinality doesn't match B_target errors with the documented message, first surfacing at assignment time", {
	set.seed(1); n <- 30L
	g <- factor(rep(c("a", "b"), each = n / 2))                          # only 2 distinct groups
	des <- DesignFixedBlocking$new(
		strata_cols = "g", response_type = "continuous", n = n, seed = 1, verbose = FALSE,
		exact_num_blocks = TRUE, B_target = 7L, equal_block_sizes = FALSE
	)
	expect_no_error(des$add_all_subjects_to_experiment(data.frame(g = g, x = rnorm(n))))   # not yet needed at construction/enrollment
	expect_error(
		des$assign_w_to_all_subjects(),
		"exact_num_blocks = TRUE but the greedy blocking key construction produced 2 blocks instead of the requested 7\\."
	)
})

test_that("when the strata column's cardinality matches B_target exactly, no error is raised", {
	set.seed(1); n <- 30L
	g <- factor(rep(c("a", "b"), each = n / 2))
	des <- DesignFixedBlocking$new(
		strata_cols = "g", response_type = "continuous", n = n, seed = 1, verbose = FALSE,
		exact_num_blocks = TRUE, B_target = 2L, equal_block_sizes = FALSE
	)
	des$add_all_subjects_to_experiment(data.frame(g = g, x = rnorm(n)))
	expect_no_error(des$assign_w_to_all_subjects())
	expect_equal(length(unique(des$.__enclos_env__$private$get_strata_keys())), 2L)
})

test_that("exact_num_blocks = FALSE (the default) never trips this guard even with a mismatched cardinality", {
	set.seed(1); n <- 30L
	g <- factor(rep(c("a", "b"), each = n / 2))
	des <- DesignFixedBlocking$new(
		strata_cols = "g", response_type = "continuous", n = n, seed = 1, verbose = FALSE,
		exact_num_blocks = FALSE, B_target = 7L, equal_block_sizes = FALSE
	)
	des$add_all_subjects_to_experiment(data.frame(g = g, x = rnorm(n)))
	expect_no_error(des$assign_w_to_all_subjects())
})
