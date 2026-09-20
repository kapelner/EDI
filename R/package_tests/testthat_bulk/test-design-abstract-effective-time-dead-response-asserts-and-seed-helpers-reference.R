library(testthat)
library(EDI)

# Design (design_abstract.R) helpers with no or indirect direct tests:
# get_effective_time()/get_effective_dead() over exact, right-censored and
# interval-censored rows, assert_y() per response type, assert_even_allocation(),
# check_experiment_completed() across partial states, assign_wt_Bernoulli(),
# maybe_set_seed(), has_private_method() and the get_X_imp / get_X_raw / get_X accessors.

surv_design <- function() {
	des <- DesignFixedBernoulli$new(n = 6L, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = c(3, 1, 4, 1, 5, 9)))
	des$overwrite_all_subject_assignments(c(0, 0, 0, 1, 1, 1))
	des
}

test_that("effective time/dead: exact rows give (y, 1); censored rows give (lower bound, 0)", {
	des <- surv_design()
	# exact, right-censored (y_L = t, y_R = Inf), interval-censored, exact, right-censored, interval-censored
	des$add_all_subject_responses(
		c(2, NA, NA, 5, NA, NA),
		c(NA, 3, 2, NA, 4, 1),
		c(NA, Inf, 5, NA, Inf, 6))
	expect_equal(des$get_effective_time(), c(2, 3, 2, 5, 4, 1))
	expect_identical(des$get_effective_dead(), c(1L, 0L, 0L, 1L, 0L, 0L))
	expect_type(des$get_effective_dead(), "integer")
	expect_true(des$has_general_censoring())
	# All-exact data is all-event.
	e <- surv_design()
	e$add_all_subject_responses(c(1, 2, 3, 4, 5, 6))
	expect_equal(e$get_effective_time(), 1:6)
	expect_identical(e$get_effective_dead(), rep(1L, 6L))
	# Non-survival responses are trivially all events.
	c1 <- DesignFixedBernoulli$new(n = 4L, response_type = "continuous", verbose = FALSE)
	c1$add_all_subjects_to_experiment(data.frame(x = 1:4)); c1$assign_w_to_all_subjects()
	c1$add_all_subject_responses(c(0.5, -1, 2, 3))
	expect_identical(c1$get_effective_dead(), rep(1L, 4L))
})

test_that("assert_y enforces each response type's domain (and is skipped when assertions are off)", {
	p <- surv_design()$.__enclos_env__$private
	expect_silent(p$assert_y(c(0, 1, 1), "incidence"))
	expect_error(p$assert_y(c(0, 2), "incidence"))
	expect_error(p$assert_y(c(0, NA), "incidence"))
	expect_silent(p$assert_y(c(0, 0.4, 1), "proportion"))
	expect_error(p$assert_y(c(0.2, 1.1), "proportion"))
	expect_silent(p$assert_y(c(0, 3, 10), "count"))
	expect_error(p$assert_y(c(-1, 3), "count"))
	expect_error(p$assert_y(c(1.5, 3), "count"))
	expect_silent(p$assert_y(c(0, 2.5), "survival"))
	expect_error(p$assert_y(c(-0.1, 2.5), "survival"))
	expect_silent(p$assert_y(c(1, 2, 4), "ordinal"))
	expect_error(p$assert_y(c(0, 2), "ordinal"))
	expect_silent(p$assert_y(c(-5, 2.2, NA), "continuous"))          # no domain check for continuous
	withr::local_options(edi.run_asserts = FALSE)
	expect_silent(p$assert_y(c(-1, 9), "incidence"))
})

test_that("assert_even_allocation only accepts prob_T = 0.5", {
	even <- DesignFixedBernoulli$new(n = 6L, response_type = "continuous", verbose = FALSE)
	expect_silent(even$assert_even_allocation())
	uneven <- DesignFixedBernoulli$new(n = 6L, response_type = "continuous", prob_T = 0.3, verbose = FALSE)
	expect_error(uneven$assert_even_allocation(), "even treatment allocation")
	withr::local_options(edi.run_asserts = FALSE)
	expect_silent(uneven$assert_even_allocation())
})

test_that("check_experiment_completed tracks arrival and response recording", {
	seq_des <- DesignSeqOneByOneBernoulli$new(n = 4L, response_type = "continuous", verbose = FALSE)
	expect_false(seq_des$check_experiment_completed())
	for (i in 1:4) seq_des$add_one_subject_to_experiment_and_assign(data.frame(x = i))
	expect_false(seq_des$check_experiment_completed())               # all arrived, none responded
	for (i in 1:3) seq_des$add_one_subject_response(i, i * 1.5)
	expect_false(seq_des$check_experiment_completed())
	seq_des$add_one_subject_response(4, 6)
	expect_true(seq_des$check_experiment_completed())

	fixed <- DesignFixedBernoulli$new(n = 4L, response_type = "continuous", verbose = FALSE)
	expect_false(fixed$check_experiment_completed())
	fixed$add_all_subjects_to_experiment(data.frame(x = 1:4)); fixed$assign_w_to_all_subjects()
	expect_false(fixed$check_experiment_completed())
	fixed$add_all_subject_responses(c(1, 2, 3, 4))
	expect_true(fixed$check_experiment_completed())
})

test_that("assign_wt_Bernoulli is a Bernoulli(prob_T) draw and maybe_set_seed reseeds only when a seed is stored", {
	des <- DesignFixedBernoulli$new(n = 6L, response_type = "continuous", prob_T = 0.8, seed = 5L, verbose = FALSE)
	p <- des$.__enclos_env__$private
	set.seed(1); draws <- vapply(1:2000, function(i) p$assign_wt_Bernoulli(), numeric(1))
	expect_true(all(draws %in% c(0, 1)))
	expect_equal(mean(draws), 0.8, tolerance = 0.03)
	set.seed(1); ref <- rbinom(2000, 1, 0.8)
	expect_equal(draws, ref)

	p$seed <- 42L
	set.seed(1); p$maybe_set_seed(); a <- runif(3)
	set.seed(99); p$maybe_set_seed(); b <- runif(3)
	expect_equal(a, b)
	set.seed(42); expect_equal(a, runif(3))
	p$seed <- NULL
	set.seed(7); before <- .Random.seed
	p$maybe_set_seed()
	expect_identical(.Random.seed, before)                              # no-op without a seed
})

test_that("has_private_method and covariate accessors", {
	des <- DesignFixedBernoulli$new(n = 4L, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = c(1, 2, 3, 4), g = c("a", "b", "a", "b")))
	des$assign_w_to_all_subjects()
	p <- des$.__enclos_env__$private
	expect_true(p$has_private_method("maybe_set_seed"))
	expect_false(p$has_private_method("definitely_not_here"))
	expect_equal(nrow(des$get_X_raw()), 4L)
	expect_equal(names(des$get_X_raw()), c("x", "g"))
	expect_equal(nrow(des$get_X_imp()), 4L)
	expect_equal(nrow(des$get_X()), 4L)
	expect_true(is.numeric(as.matrix(des$get_X())))
	expect_equal(des$get_prob_T(), 0.5)
})
