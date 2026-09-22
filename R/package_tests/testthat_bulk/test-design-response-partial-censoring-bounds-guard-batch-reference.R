library(testthat)
library(EDI)

# add_all_subject_responses()'s partial-censoring-bounds guard (base Design, used by sequential designs, and
# DesignFixed's own override): y_Ls and y_Rs must be supplied together (both finite or both NA) for every
# subject -- a subject with exactly one of the two bounds present is rejected before the exclusive-or check
# (y vs. y_L/y_R) is even reached. Explicitly documented as always enforced, never gated behind
# should_run_asserts(), for the same silent-downstream-misread reason as the exclusive-or guard covered last
# iteration (test-design-response-supply-exclusive-or-guards-single-and-batch-reference.R) -- but this specific
# partial-bounds branch, distinct from that exclusive-or check, had no test triggering it on either method.

test_that("Design$add_all_subject_responses() (sequential base): a subject with only one of y_L/y_R present is rejected", {
	des <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	for (i in 1:3) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_error(
		des$add_all_subject_responses(ys = c(NA, NA, NA), y_Ls = c(1, NA, 3), y_Rs = c(2, 3, NA)),
		"y_Ls and y_Rs must be supplied together \\(both or neither\\) for every subject\\."
	)
})

test_that("DesignFixed's own add_all_subject_responses(): the identical partial-bounds guard", {
	des <- DesignFixedBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(3))); des$assign_w_to_all_subjects()
	expect_error(
		des$add_all_subject_responses(ys = c(NA, NA, NA), y_Ls = c(1, NA, 3), y_Rs = c(2, 3, NA)),
		"y_Ls and y_Rs must be supplied together \\(both or neither\\) for every subject\\."
	)
})

test_that("the partial-bounds guard fires even when only one subject in the batch is affected", {
	des <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	for (i in 1:3) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_error(
		des$add_all_subject_responses(ys = c(1, NA, 3), y_Ls = c(NA, 1, NA), y_Rs = c(NA, NA, NA)),   # subject 2: y_L present, y_R missing
		"y_Ls and y_Rs must be supplied together"
	)
})

test_that("fully-paired bounds (both present or both absent for every subject) are accepted", {
	des <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	for (i in 1:3) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(ys = c(1, NA, 3), y_Ls = c(NA, 1, NA), y_Rs = c(NA, 2, NA))
	expect_equal(des$get_y(), c(1, NA_real_, 3))
})
