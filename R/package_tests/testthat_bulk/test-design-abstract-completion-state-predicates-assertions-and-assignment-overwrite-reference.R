library(testthat)
library(EDI)

# Design state predicates and assertions: is_fixed_sample_size, assert_all_subjects_arrived, assert_all_responses_recorded,
# check_experiment_completed, assert_even_allocation, assert_fixed_sample, any_censoring, has_general_censoring,
# overwrite_all_subject_assignments. Sequential designs (added one subject at a time) walk the state machine
# incomplete -> arrived -> responses recorded -> completed.

n <- 6L
xrow <- function(i) data.frame(x = i / 10)

test_that("sequential fixed-n design: completion needs every arrival AND every response", {
	d <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	expect_true(d$is_fixed_sample_size())
	expect_false(d$check_experiment_completed())
	expect_error(d$assert_all_subjects_arrived(), "haven't arrived yet")
	for (i in 1:(n - 1L)) d$add_one_subject_to_experiment_and_assign(xrow(i))
	expect_false(d$check_experiment_completed())
	expect_error(d$assert_all_subjects_arrived(), "haven't arrived yet")
	d$add_one_subject_to_experiment_and_assign(xrow(n))
	expect_null(d$assert_all_subjects_arrived())
	expect_false(d$check_experiment_completed())                                  # arrived but no responses
	expect_error(d$assert_all_responses_recorded(), "responses aren't recorded yet")
	for (i in 1:(n - 1L)) d$add_one_subject_response(i, i / 3)
	expect_false(d$check_experiment_completed())
	expect_error(d$assert_all_responses_recorded(), "responses aren't recorded yet")
	d$add_one_subject_response(n, 2)
	expect_true(d$check_experiment_completed())
	expect_null(d$assert_all_responses_recorded())
})

test_that("assertions are silenced when asserts are off (state predicate still reports incompleteness)", {
	withr::local_options(edi.run_asserts = FALSE)
	d <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	expect_silent(d$assert_all_subjects_arrived()); expect_silent(d$assert_all_responses_recorded())
	expect_false(d$check_experiment_completed())
})

test_that("censored right-censored survival responses: any_censoring TRUE, has_general_censoring FALSE; interval-censored flips the latter", {
	d <- DesignFixedBernoulli$new(response_type = "survival", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = seq_len(n))); d$assign_w_to_all_subjects()
	d$add_all_subject_responses(ys = c(1, 2, 3, 4, NA, NA), y_Ls = c(NA, NA, NA, NA, 5, 6), y_Rs = c(NA, NA, NA, NA, Inf, Inf))
	expect_true(d$any_censoring()); expect_false(d$has_general_censoring()); expect_true(d$check_experiment_completed())
	e <- DesignFixedBernoulli$new(response_type = "survival", n = n, seed = 1L, verbose = FALSE)
	e$add_all_subjects_to_experiment(data.frame(x = seq_len(n))); e$assign_w_to_all_subjects()
	e$add_all_subject_responses(ys = c(1, 2, 3, 4, NA, NA), y_Ls = c(NA, NA, NA, NA, 5, 6), y_Rs = c(NA, NA, NA, NA, Inf, 8))
	expect_true(e$has_general_censoring())
	f <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	f$add_all_subjects_to_experiment(data.frame(x = seq_len(n))); f$assign_w_to_all_subjects(); f$add_all_subject_responses(rnorm(n))
	expect_false(f$any_censoring()); expect_false(f$has_general_censoring())
})

test_that("even-allocation and fixed-sample assertions", {
	d1 <- DesignFixedBernoulli$new(response_type = "continuous", n = n, prob_T = 0.3, seed = 1L, verbose = FALSE)
	expect_error(d1$assert_even_allocation(), "only works with even treatment allocation")
	d2 <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	expect_null(d2$assert_even_allocation())
	expect_null(d2$assert_fixed_sample())
	s <- DesignSeqOneByOneBernoulli$new(response_type = "continuous", verbose = FALSE)              # no n: open-ended sample
	expect_false(s$is_fixed_sample_size())
	expect_error(s$assert_fixed_sample(), "must specify n upon initialization")
})

test_that("overwrite_all_subject_assignments validates length and 0/1 values, stores numeric assignments", {
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = seq_len(n))); d$assign_w_to_all_subjects()
	new_w <- c(1L, 0L, 1L, 0L, 1L, 0L)
	d$overwrite_all_subject_assignments(new_w)
	expect_identical(d$get_w(), as.numeric(new_w))
	expect_error(d$overwrite_all_subject_assignments(c(1, 0, 1)))                 # wrong length
	expect_error(d$overwrite_all_subject_assignments(c(1, 0, 1, 0, 1, 2)))       # not 0/1
	expect_error(d$overwrite_all_subject_assignments(c(1, 0, 1, 0, 1, NA)))
	expect_identical(d$get_w(), as.numeric(new_w))                                  # failed overwrites leave it unchanged
})
