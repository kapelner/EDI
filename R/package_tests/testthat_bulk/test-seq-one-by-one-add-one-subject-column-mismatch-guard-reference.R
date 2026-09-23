library(testthat)
library(EDI)

# design_seq_one_by_one_abstract.R's add_one_subject(x_new, allow_new_cols) rejects a new subject
# row whose columns don't match the existing dataset's columns when allow_new_cols = FALSE, with a
# message listing both column sets and the escape hatch. Zero test references anywhere; every
# existing add_one_subject test either keeps columns stable or uses the default allow_new_cols =
# TRUE.
#
# Source note (not fixed, per this job's scope): the sibling "Continuous covariates are not allowed
# for stratification in sequential designs..." stop() a few lines above this one in the same function
# is dead code -- add_one_subject() calls assertStrataClusterArgs(strata_cols_must_be_factor =
# !is.null(private$strata_cols)) at its very top, which already rejects any non-categorical
# strata_cols column with its own "strata_cols must refer to factor/categorical columns" error
# before this later, more specific check could ever run. Confirmed empirically: constructing
# DesignSeqOneByOneRandomBlockSize(strata_cols = "s1", ...) and adding a numeric "s1" column hits
# assertStrataClusterArgs's message, never this class's own.

test_that("add_one_subject(): a column-set mismatch with allow_new_cols = FALSE errors with the documented message", {
	des <- DesignSeqOneByOneBernoulli$new(n = 4L, response_type = "continuous", verbose = FALSE)
	des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1.5))
	expect_error(
		des$add_one_subject(data.frame(x1 = 2.5, x2 = 3.0), allow_new_cols = FALSE),
		"which are not the same as the current dataset's columns"
	)
})

test_that("add_one_subject(): a column-set mismatch with the default allow_new_cols = TRUE does not error", {
	des <- DesignSeqOneByOneBernoulli$new(n = 4L, response_type = "continuous", verbose = FALSE)
	des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1.5))
	expect_no_error(des$add_one_subject(data.frame(x1 = 2.5, x2 = 3.0)))
})
