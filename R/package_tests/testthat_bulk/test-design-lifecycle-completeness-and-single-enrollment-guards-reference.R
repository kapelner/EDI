library(testthat)
library(EDI)

# Four foundational design-lifecycle guards, each reached from every concrete design class (fixed and sequential
# alike) but never directly triggered by any existing test -- normal test fixtures always complete enrollment
# correctly, so these misuse-detection paths were never exercised: assert_all_subjects_arrived() (design_abstract.R)
# errors if called before a fixed-size design's n subjects have all arrived; assert_all_responses_recorded()
# additionally errors if some arrived subjects still lack a recorded response; add_all_subjects_to_experiment()
# (design_fixed_abstract.R) refuses a second batch enrollment call; add_one_subject_to_experiment_and_assign()
# (design_seq_one_by_one_abstract.R) refuses a multi-row data.frame (only one subject at a time).

test_that("assert_all_subjects_arrived() errors on an incomplete sequential design and passes once complete", {
	des <- DesignSeqOneByOneBernoulli$new(n = 10L, response_type = "continuous", verbose = FALSE)
	for (i in 1:5) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_error(des$assert_all_subjects_arrived(), "This experiment is incomplete as all n subjects haven't arrived yet\\.")

	for (i in 6:10) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_null(des$assert_all_subjects_arrived())
})

test_that("assert_all_responses_recorded() errors when responses are missing, even after all subjects have arrived", {
	des <- DesignSeqOneByOneBernoulli$new(n = 5L, response_type = "continuous", verbose = FALSE)
	for (i in 1:5) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	for (i in 1:3) des$add_one_subject_response(i, rnorm(1))
	expect_error(des$assert_all_responses_recorded(), "This experiment is incomplete as all responses aren't recorded yet\\.")

	for (i in 4:5) des$add_one_subject_response(i, rnorm(1))
	expect_null(des$assert_all_responses_recorded())
})

test_that("assert_all_responses_recorded() also propagates the subjects-not-arrived error (checks arrival first)", {
	des <- DesignSeqOneByOneBernoulli$new(n = 10L, response_type = "continuous", verbose = FALSE)
	for (i in 1:5) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_error(des$assert_all_responses_recorded(), "This experiment is incomplete as all n subjects haven't arrived yet\\.")
})

test_that("a fixed design refuses a second add_all_subjects_to_experiment() batch enrollment call", {
	des <- DesignFixedBernoulli$new(n = 5L, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(5)))
	expect_error(
		des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(5))),
		"Subjects have already been added to this design\\."
	)
})

test_that("a sequential design's add_one_subject_to_experiment_and_assign() refuses a multi-row data.frame", {
	des <- DesignSeqOneByOneBernoulli$new(n = 5L, response_type = "continuous", verbose = FALSE)
	expect_error(
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(2))),
		"You can only add one subject at a time\\."
	)
})
