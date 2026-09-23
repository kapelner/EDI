library(testthat)
library(EDI)

# InferenceSurvivalGLMMWeibullFrailtyNormalOneLik's private shared_combined_likelihood()
# (inference_survival_GLMM_weibull_frailty_normal.R) has two distinct nonestimable guards, neither
# of which had a test reference anywhere:
#   1. "kk_weibull_frailty_no_events": sum(private$dead) == 0, i.e. every subject is censored --
#      checked before any fitting is attempted.
#   2. "kk_weibull_frailty_combined_fit_failed": the hardened column-dropping search around
#      fast_weibull_frailty_cpp() never finds a usable fit.
# Branch 1 is reached with a genuinely all-censored KK design (deterministic, no mocking needed);
# branch 2 is reached by mocking fast_weibull_frailty_cpp() to always return NULL, the same
# local_mocked_bindings(..., .package = "EDI") technique already used elsewhere in this suite
# (including this session's identically-shaped InferenceSurvivalKKWeibullMarginal reference test)
# for analogous unreachable-in-practice failure paths.

test_that("'kk_weibull_frailty_no_events' fires when every subject is censored", {
	set.seed(1); n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	add_all_subject_responses_seq(des, rexp(n, 1), deads = rep(0L, n))

	inf <- InferenceSurvivalGLMMWeibullFrailtyNormalOneLik$new(des, verbose = FALSE)
	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "kk_weibull_frailty_no_events")
})

test_that("'kk_weibull_frailty_combined_fit_failed' fires when fast_weibull_frailty_cpp always fails", {
	set.seed(2); n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	add_all_subject_responses_seq(des, rexp(n, exp(0.3 * X$x1 + 0.2 * w)), deads = rbinom(n, 1, 0.8))

	inf <- InferenceSurvivalGLMMWeibullFrailtyNormalOneLik$new(des, verbose = FALSE)
	local_mocked_bindings(fast_weibull_frailty_cpp = function(...) NULL, .package = "EDI")

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "kk_weibull_frailty_combined_fit_failed")
})
