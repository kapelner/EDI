library(testthat)
library(EDI)

# Design's response-recording methods -- add_one_subject_response() (design_abstract.R, per-subject), the base
# Design$add_all_subject_responses() (used by sequential designs), and DesignFixed's own
# add_all_subject_responses() override -- each enforce the same exclusive-or invariant per subject: supply EITHER
# an exact response (y/ys) OR both censoring bounds (y_L+y_R / y_Ls+y_Rs), never both and never neither. These
# checks are explicitly documented as ALWAYS enforced, never gated behind should_run_asserts() (a censored row
# that slipped through would be silently misread downstream as ordinary right-censoring) -- but no test anywhere
# triggered any of the six "both supplied" / "neither supplied" branches across the three methods; existing
# coverage only exercises valid response supply.

test_that("add_one_subject_response(): supplying both y and y_L/y_R, or neither, is rejected", {
	des <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	for (i in 1:3) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_error(
		des$add_one_subject_response(1, y = 1.5, y_L = 1, y_R = 2),
		"Supply either y \\(exact response\\) or both y_L and y_R \\(censored response\\), not both\\."
	)
	expect_error(
		des$add_one_subject_response(1),
		"You must supply either y \\(exact response\\) or both y_L and y_R \\(censored response\\)\\."
	)
})

test_that("add_one_subject_response(): a mix of exact and censored responses across different subjects is valid", {
	des <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	for (i in 1:3) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_one_subject_response(1, y = 1.5)
	des$add_one_subject_response(2, y_L = 1, y_R = 2)
	des$add_one_subject_response(3, y = 2.0)
	expect_equal(des$get_y(), c(1.5, NA_real_, 2))
})

test_that("Design$add_all_subject_responses() (sequential base): the same exclusive-or guard, per subject, over the whole batch", {
	des <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	for (i in 1:3) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_error(
		des$add_all_subject_responses(ys = c(1, 2, 3), y_Ls = c(NA, 1, NA), y_Rs = c(NA, 2, NA)),
		"Supply either ys or \\(y_Ls, y_Rs\\) for each subject, not both\\."
	)
	des2 <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	for (i in 1:3) des2$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_error(
		des2$add_all_subject_responses(ys = c(1, NA, 3)),
		"Each subject needs either ys or both y_Ls and y_Rs\\."
	)
})

test_that("DesignFixed's own add_all_subject_responses(): the identical exclusive-or guard", {
	des <- DesignFixedBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(3))); des$assign_w_to_all_subjects()
	expect_error(
		des$add_all_subject_responses(ys = c(1, 2, 3), y_Ls = c(NA, 1, NA), y_Rs = c(NA, 2, NA)),
		"Supply either ys or \\(y_Ls, y_Rs\\) for each subject, not both\\."
	)
	des2 <- DesignFixedBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	des2$add_all_subjects_to_experiment(data.frame(x1 = rnorm(3))); des2$assign_w_to_all_subjects()
	expect_error(
		des2$add_all_subject_responses(ys = c(1, NA, 3)),
		"Each subject needs either ys or both y_Ls and y_Rs\\."
	)
})

test_that("a valid all-exact or all-censored batch is accepted by both add_all_subject_responses() variants", {
	des <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	for (i in 1:3) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(ys = c(1, NA, 3), y_Ls = c(NA, 1, NA), y_Rs = c(NA, 2, NA))
	expect_equal(des$get_y(), c(1, NA_real_, 3))

	des2 <- DesignFixedBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	des2$add_all_subjects_to_experiment(data.frame(x1 = rnorm(3))); des2$assign_w_to_all_subjects()
	des2$add_all_subject_responses(ys = c(1, NA, 3), y_Ls = c(NA, 1, NA), y_Rs = c(NA, 2, NA))
	expect_equal(des2$get_y(), c(1, NA_real_, 3))
})
