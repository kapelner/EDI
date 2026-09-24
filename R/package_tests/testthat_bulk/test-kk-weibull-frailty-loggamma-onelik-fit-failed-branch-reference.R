library(testthat)
library(EDI)

# InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik's private shared() (inference_survival_GLMM_
# weibull_frailty_loggamma.R) has an "every covariate-subset candidate's .fit_clayton_weibull_aft()
# call fails" fallback path -- unreachable in practice (mocked here via local_mocked_bindings(),
# the same technique already used for the sibling InferenceSurvivalGLMMWeibullFrailtyNormalOneLik's
# analogous 'kk_weibull_frailty_combined_fit_failed' guard, closed in test-kk-weibull-frailty-onelik-
# no-events-and-fit-failed-guards-reference.R) -- had no test reference anywhere for this class.
# Previously (until 2026-09-24), unlike its normal-frailty sibling, this class's fallback did NOT call
# cache_nonestimable_estimate() with a reason string; it only set beta_hat_T/s_beta_hat_T to NA_real_
# directly. FIXED 2026-09-24 to call cache_nonestimable_estimate("kk_weibull_frailty_loggamma_fit_failed"),
# matching the sibling's richer contract.
#   1. compute_estimate() returns NA_real_ when every fit attempt fails.
#   2. get_nonestimable_reason()/is_nonestimable("estimate") now DO flag this failure, matching the
#      normal-frailty sibling's contract.
#   3. compute_asymp_confidence_interval() also degrades to c(NA, NA) rather than erroring.
#   4. get_likelihood_test_spec() returns NULL (its own guard on cached_mod/likelihood_test_context
#      being unset) rather than erroring.

fit_failed_loggamma_fixture <- function(seed) {
	set.seed(seed)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y_lat <- rexp(n, exp(0.3 * X$x1 + 0.2 * w))
	for (i in seq_len(n)) {
		if (i %% 5 != 0) des$add_one_subject_response(i, y = y_lat[i])
		else des$add_one_subject_response(i, y_L = y_lat[i], y_R = Inf)
	}
	InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik$new(des, verbose = FALSE)
}

test_that("compute_estimate() returns NA_real_ when every covariate-candidate fit fails", {
	inf <- fit_failed_loggamma_fixture(101L)
	local_mocked_bindings(.fit_clayton_weibull_aft = function(...) NULL, .package = "EDI")
	est <- inf$compute_estimate()
	expect_true(is.na(est))
	expect_type(est, "double")
})

test_that("the failure IS recorded via the nonestimable-reason API, matching the normal-frailty sibling", {
	inf <- fit_failed_loggamma_fixture(102L)
	local_mocked_bindings(.fit_clayton_weibull_aft = function(...) NULL, .package = "EDI")
	inf$compute_estimate()
	expect_true(inf$is_nonestimable("estimate"))
	expect_equal(inf$get_nonestimable_reason(), "kk_weibull_frailty_loggamma_fit_failed")
})

test_that("compute_asymp_confidence_interval() degrades to c(NA, NA) without erroring", {
	inf <- fit_failed_loggamma_fixture(103L)
	local_mocked_bindings(.fit_clayton_weibull_aft = function(...) NULL, .package = "EDI")
	ci <- inf$compute_asymp_confidence_interval()
	expect_length(ci, 2L)
	expect_true(all(is.na(ci)))
})

test_that("get_likelihood_test_spec() returns NULL when the fit never succeeded", {
	inf <- fit_failed_loggamma_fixture(104L)
	priv <- inf$.__enclos_env__$private
	local_mocked_bindings(.fit_clayton_weibull_aft = function(...) NULL, .package = "EDI")
	spec <- priv$get_likelihood_test_spec()
	expect_null(spec)
})
