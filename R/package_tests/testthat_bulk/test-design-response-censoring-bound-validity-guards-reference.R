library(testthat)
library(EDI)

# Censoring-bound VALIDITY checks (distinct from the "supplied together"/"exclusive with y" shape checks covered
# the last two iterations): y_L must be finite and >= 0, and y_R must be strictly greater than y_L, on all three
# response-recording methods (add_one_subject_response(), and both add_all_subject_responses() variants). Always
# enforced regardless of should_run_asserts(). Only add_one_subject_response()'s "y_L must be finite and >= 0"
# branch had prior coverage; its own "y_R > y_L" branch, and BOTH batch methods' copies of both checks, had none.

test_that("add_one_subject_response(): y_R must be strictly greater than y_L (y_L's own finite/>=0 check is covered elsewhere)", {
	des <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	for (i in 1:3) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_error(des$add_one_subject_response(1, y_L = 3, y_R = 2), "y_R must be strictly greater than y_L\\.")
	des2 <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	for (i in 1:3) des2$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_error(des2$add_one_subject_response(1, y_L = 2, y_R = 2), "y_R must be strictly greater than y_L\\.")   # equal bounds also rejected
})

test_that("Design$add_all_subject_responses() (sequential base): both bound-validity checks", {
	des1 <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	for (i in 1:3) des1$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_error(
		des1$add_all_subject_responses(ys = c(NA, NA, NA), y_Ls = c(-1, 1, 1), y_Rs = c(2, 2, 2)),
		"y_L must be finite and >= 0 for every censored subject\\."
	)
	des2 <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	for (i in 1:3) des2$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_error(
		des2$add_all_subject_responses(ys = c(NA, NA, NA), y_Ls = c(1, 3, 1), y_Rs = c(2, 2, 2)),
		"y_R must be strictly greater than y_L for every censored subject\\."
	)
})

test_that("DesignFixed's own add_all_subject_responses(): the identical bound-validity checks", {
	des1 <- DesignFixedBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	des1$add_all_subjects_to_experiment(data.frame(x1 = rnorm(3))); des1$assign_w_to_all_subjects()
	expect_error(
		des1$add_all_subject_responses(ys = c(NA, NA, NA), y_Ls = c(-1, 1, 1), y_Rs = c(2, 2, 2)),
		"y_L must be finite and >= 0 for every censored subject\\."
	)
	des2 <- DesignFixedBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	des2$add_all_subjects_to_experiment(data.frame(x1 = rnorm(3))); des2$assign_w_to_all_subjects()
	expect_error(
		des2$add_all_subject_responses(ys = c(NA, NA, NA), y_Ls = c(1, 3, 1), y_Rs = c(2, 2, 2)),
		"y_R must be strictly greater than y_L for every censored subject\\."
	)
})

test_that("valid censoring bounds (y_L finite >= 0, y_R strictly greater) are accepted on all methods", {
	des1 <- DesignSeqOneByOneBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	for (i in 1:3) des1$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des1$add_one_subject_response(1, y_L = 0, y_R = 1)
	expect_true(is.na(des1$get_y()[1]))

	des2 <- DesignFixedBernoulli$new(n = 3L, response_type = "survival", verbose = FALSE)
	des2$add_all_subjects_to_experiment(data.frame(x1 = rnorm(3))); des2$assign_w_to_all_subjects()
	des2$add_all_subject_responses(ys = c(NA, NA, NA), y_Ls = c(0, 1, 2), y_Rs = c(1, 2, 3))
	expect_true(all(is.na(des2$get_y())))
})
