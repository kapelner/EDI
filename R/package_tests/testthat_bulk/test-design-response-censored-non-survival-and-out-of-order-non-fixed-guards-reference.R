library(testthat)
library(EDI)

# Two more response-recording guards from the same family as the last two iterations' exclusive-or/partial-bounds
# guards, still on add_one_subject_response()/add_all_subject_responses() (design_abstract.R, design_fixed_abstract.R):
# (1) censoring bounds (y_L/y_R or y_Ls/y_Rs) are rejected outright for any non-"survival" response_type, on all
# three response-recording methods; (2) for a design with an unknown-in-advance sample size (n = NULL,
# is_fixed_sample_size() = FALSE), add_one_subject_response() refuses to record a response for an already-arrived
# subject whose index skips ahead of the next not-yet-recorded subject (a gap in the response sequence) -- a
# guard genuinely distinct from the "subject hasn't arrived at all yet" check that fires first for indices beyond
# the arrived count. None of these four branches had any test triggering them.

test_that("censoring bounds are rejected on a non-survival response_type, on all three response-recording methods", {
	des1 <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "continuous", verbose = FALSE)
	for (i in 1:3) des1$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_error(des1$add_one_subject_response(1, y_L = 1, y_R = 2), "censored observations are only available for survival response types")

	des2 <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "continuous", verbose = FALSE)
	for (i in 1:3) des2$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_error(
		des2$add_all_subject_responses(ys = c(NA, NA, NA), y_Ls = c(1, 1, 1), y_Rs = c(2, 2, 2)),
		"censored observations are only available for survival response types"
	)

	des3 <- DesignFixedBernoulli$new(n = 3L, response_type = "continuous", verbose = FALSE)
	des3$add_all_subjects_to_experiment(data.frame(x1 = rnorm(3))); des3$assign_w_to_all_subjects()
	expect_error(
		des3$add_all_subject_responses(ys = c(NA, NA, NA), y_Ls = c(1, 1, 1), y_Rs = c(2, 2, 2)),
		"censored observations are only available for survival response types"
	)
})

test_that("censoring bounds still work normally on a survival response_type (guard is response-type-specific)", {
	des <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	for (i in 1:3) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_no_error(des$add_one_subject_response(1, y_L = 1, y_R = 2))
})

test_that("for a non-fixed-sample-size design, a response for an already-arrived subject that skips ahead of the next unrecorded index is rejected", {
	des <- DesignSeqOneByOneBernoulli$new(n = NULL, response_type = "continuous", verbose = FALSE)
	expect_false(des$is_fixed_sample_size())
	for (i in 1:3) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_one_subject_response(1, y = 1.0)
	expect_error(
		des$add_one_subject_response(3, y = 3.0),                          # subject 2 never got a response: skips ahead
		"You cannot add a response for a subject that has not yet arrived when the sample size is not fixed in advance\\."
	)
})

test_that("the same skip-ahead scenario is fine in order (subject 2, then subject 3)", {
	des <- DesignSeqOneByOneBernoulli$new(n = NULL, response_type = "continuous", verbose = FALSE)
	for (i in 1:3) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_one_subject_response(1, y = 1.0)
	des$add_one_subject_response(2, y = 2.0)
	des$add_one_subject_response(3, y = 3.0)
	expect_equal(des$get_y(), c(1, 2, 3))
})
