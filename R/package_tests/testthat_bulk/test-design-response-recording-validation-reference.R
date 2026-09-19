library(testthat)
library(EDI)

# Design's response-recording validation and storage:
# add_one_subject_response() / add_all_subject_responses() (exact vs
# left-/interval-/right-censored bounds, always-enforced shape checks, overwrite
# warning, zero-survival clamp, ordinal-factor coding) and
# check_experiment_completed(). None of the stop() messages guarding the
# y / y_L / y_R contract had a direct test reference.

response_design <- function(response_type, n = 6L) {
	des <- DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(n)))
	des$assign_w_to_all_subjects()
	des
}

test_that("add_one_subject_response enforces the y XOR (y_L, y_R) contract with specific errors", {
	des <- response_design("survival")
	expect_error(des$add_one_subject_response(1, y_L = 1), "y_L was supplied without y_R")
	expect_error(des$add_one_subject_response(1, y_R = 2), "y_R was supplied without y_L")
	expect_error(des$add_one_subject_response(1, y = 1, y_L = 1, y_R = 2), "not both")
	expect_error(des$add_one_subject_response(1), "You must supply either y")
	expect_error(des$add_one_subject_response(1, y_L = -1, y_R = 2), "y_L must be finite and >= 0")
	expect_error(des$add_one_subject_response(1, y_L = Inf, y_R = 2), "y_L must be finite and >= 0")
	expect_error(des$add_one_subject_response(1, y_L = 2, y_R = 2), "strictly greater")
	expect_error(des$add_one_subject_response(1, y_L = 3, y_R = 2), "strictly greater")
	# Nothing was recorded by any of the rejected calls.
	expect_true(all(is.na(des$get_y())))
	expect_true(all(is.na(des$get_y_L())))
})

test_that("censored bounds are only allowed for survival responses", {
	des <- response_design("continuous")
	expect_error(des$add_one_subject_response(1, y_L = 1, y_R = 2), "only available for survival")
	expect_error(des$add_all_subject_responses(y_Ls = rep(1, 6), y_Rs = rep(2, 6)), "only available for survival")
})

test_that("valid exact and bounded responses are stored in the right slots", {
	des <- response_design("survival")
	des$add_one_subject_response(1, y = 2.5)
	des$add_one_subject_response(2, y_L = 1, y_R = 3)          # interval censored
	des$add_one_subject_response(3, y_L = 4, y_R = Inf)        # right censored
	des$add_one_subject_response(4, y_L = 0, y_R = 2)          # left censored
	expect_equal(des$get_y()[1:4], c(2.5, NA, NA, NA))
	expect_equal(des$get_y_L()[1:4], c(NA, 1, 4, 0))
	expect_equal(des$get_y_R()[1:4], c(NA, 3, Inf, 2))
	expect_false(des$check_experiment_completed())
})

test_that("overwriting a recorded response warns, and a zero survival time is clamped with a warning", {
	des <- response_design("survival")
	des$add_one_subject_response(1, y = 2)
	expect_warning(des$add_one_subject_response(1, y = 3), "Overwriting previous response")
	expect_equal(des$get_y()[1], 3)

	expect_warning(des$add_one_subject_response(2, y = 0), "0 survival responses not allowed")
	expect_equal(des$get_y()[2], .Machine$double.eps)
})

test_that("a response cannot be added for a subject that has not arrived", {
	des <- DesignSeqOneByOneBernoulli$new(n = 6L, response_type = "continuous", verbose = FALSE)
	for (i in 1:3) des$add_one_subject_to_experiment_and_assign(data.frame(x = i))
	expect_error(des$add_one_subject_response(5, y = 1), "You cannot add response for subject 5")
})

test_that("add_all_subject_responses enforces the same contract vector-wise", {
	des <- response_design("survival")
	n <- 6L
	ys <- c(1, NA, 3, NA, 5, NA)
	yL <- c(NA, 1, NA, 2, NA, 4)
	yR <- c(NA, 2, NA, Inf, NA, 5)

	expect_error(des$add_all_subject_responses(ys, y_Ls = replace(yL, 2, NA), y_Rs = yR), "must be supplied together")
	expect_error(des$add_all_subject_responses(replace(ys, 2, 9), yL, yR), "not both")
	expect_error(des$add_all_subject_responses(replace(ys, 1, NA), yL, yR), "Each subject needs either")
	expect_error(des$add_all_subject_responses(ys, replace(yL, 2, -1), yR), "y_L must be finite and >= 0")
	expect_error(des$add_all_subject_responses(ys, replace(yL, 2, 9), yR), "strictly greater")

	des$add_all_subject_responses(ys, yL, yR)
	expect_equal(des$get_y(), ys)
	expect_equal(des$get_y_L(), yL)
	expect_equal(des$get_y_R(), yR)
	expect_true(des$check_experiment_completed())
})

test_that("ordinal factor responses are rejected while assertions are on and recorded as integer codes with them off (real source bug, not fixed)", {
	# SOURCE BUG (noted, not fixed): both add_one_subject_response() and
	# add_all_subject_responses() have a branch that converts an ordered factor to
	# integer codes and remembers its levels, but each runs an assertion on the
	# still-uncoded factor first (assertNumeric(y, ...) for the single-subject
	# method, private$assert_y(ys[has_y], ...) requiring integerish for the bulk
	# one), so the factor branch is only reachable with assertions disabled.
	ys <- factor(c("lo", "mid", "hi", "mid", "lo", "hi"), levels = c("lo", "mid", "hi"), ordered = TRUE)
	expect_error(response_design("ordinal")$add_all_subject_responses(ys), "integerish")
	expect_error(response_design("ordinal")$add_one_subject_response(1, y = ys[2]), "numeric")

	old <- options(edi.run_asserts = FALSE)
	on.exit(options(old), add = TRUE)
	des_all <- response_design("ordinal")
	des_all$add_all_subject_responses(ys)
	expect_equal(des_all$get_y(), as.numeric(as.integer(ys)))
	expect_equal(des_all$.__enclos_env__$private$ordinal_levels, c("lo", "mid", "hi"))

	des_one <- response_design("ordinal")
	des_one$add_one_subject_response(1, y = ys[2])
	expect_equal(des_one$get_y()[1], 2)
	expect_equal(des_one$.__enclos_env__$private$ordinal_levels, c("lo", "mid", "hi"))
})

test_that("check_experiment_completed needs every subject and every response", {
	des <- DesignFixedBernoulli$new(n = 4L, response_type = "continuous", verbose = FALSE)
	expect_false(des$check_experiment_completed())
	des$add_all_subjects_to_experiment(data.frame(x = 1:4))
	des$assign_w_to_all_subjects()
	expect_false(des$check_experiment_completed())
	des$add_one_subject_response(1, y = 1)
	expect_false(des$check_experiment_completed())
	des$add_all_subject_responses(c(1, 2, 3, 4))
	expect_true(des$check_experiment_completed())
})
