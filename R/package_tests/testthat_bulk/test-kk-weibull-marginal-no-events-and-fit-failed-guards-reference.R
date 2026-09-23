library(testthat)
library(EDI)

# InferenceSurvivalKKWeibullMarginal$shared() (inference_survival_KK_weibull_marginal.R) has two
# distinct nonestimable guards, neither of which had a test reference anywhere:
#   1. "kk_weibull_marginal_no_events": sum(private$dead) == 0, i.e. every subject is censored --
#      checked before any fitting is attempted.
#   2. "kk_weibull_marginal_fit_failed": the hardened column-dropping search never finds a usable
#      fit from either backend (fit_weibull_marginal_cpp, then its survreg fallback).
# Branch 1 is reached with a genuinely all-censored KK design (deterministic, no mocking needed);
# branch 2 is reached by mocking both private fitters to always fail, the same technique already
# used elsewhere in this suite for analogous unreachable-in-practice failure paths.

test_that("'kk_weibull_marginal_no_events' fires when every subject is censored", {
	set.seed(1); n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	add_all_subject_responses_seq(des, rexp(n, 1), deads = rep(0L, n))

	inf <- InferenceSurvivalKKWeibullMarginal$new(des, verbose = FALSE)
	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "kk_weibull_marginal_no_events")
})

test_that("'kk_weibull_marginal_fit_failed' fires when both fit backends fail", {
	set.seed(2); n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	add_all_subject_responses_seq(des, rexp(n, exp(0.3 * X$x1 + 0.2 * w)), deads = rbinom(n, 1, 0.8))

	inf <- InferenceSurvivalKKWeibullMarginal$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	unlockBinding("fit_weibull_marginal_cpp", p)
	unlockBinding("fit_weibull_marginal_survreg", p)
	p$fit_weibull_marginal_cpp <- function(...) NULL
	p$fit_weibull_marginal_survreg <- function(...) NULL

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "kk_weibull_marginal_fit_failed")
})
