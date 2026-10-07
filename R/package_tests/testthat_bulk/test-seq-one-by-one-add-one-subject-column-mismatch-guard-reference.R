library(testthat)
library(EDI)

# design_seq_one_by_one_abstract.R's add_one_subject(x_new, allow_new_cols) rejects a new subject
# row whose columns don't match the existing dataset's columns when allow_new_cols = FALSE, with a
# message listing both column sets and the escape hatch. Zero test references anywhere; every
# existing add_one_subject test either keeps columns stable or uses the default allow_new_cols =
# TRUE.
#
# The former sibling "Continuous covariates are not allowed for stratification
# in sequential designs..." stop() was unreachable and has been removed.
# add_one_subject() now has one validation path: assertStrataClusterArgs() rejects
# non-categorical strata_cols before the subject is added. The regression below
# pins that shared guard as the sole user-facing contract.

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

test_that("add_one_subject(): numeric sequential strata use the shared categorical-strata guard", {
	des <- DesignSeqOneByOneSPBR$new(
		strata_cols = "stratum",
		response_type = "continuous",
		n = 4L,
		verbose = FALSE
	)
	expect_error(
		des$add_one_subject_to_experiment_and_assign(data.frame(stratum = 1)),
		"strata_cols.*non-categorical"
	)
})
