library(testthat)
library(EDI)

# InferenceContinOLS$shared() (inference_continuous_ols.R), harden = TRUE path, drives
# fit_with_hardened_qr_column_dropping() with a fit_ok() predicate requiring a finite treatment
# coefficient. If fast_ols_with_var_cpp()/fast_ols_cpp() never produce a usable fit across every
# column subset hardening tries, beta_hat_T/s_beta_hat_T/df are all set to NA. InferenceContinOLS is
# extremely widely tested (50+ reference files), but every located fixture exercises a well-
# conditioned design, so this hardening-exhaustion branch had no test reference anywhere -- distinct
# from the harden = FALSE path, which has no such guard at all (an unhardened fit error propagates
# uncaught by design, not a gap).
#
# Reached by mocking fast_ols_with_var_cpp() to always fail, the same local_mocked_bindings(...,
# .package = "EDI") technique already used elsewhere in this suite for analogous
# unreachable-in-practice failure paths (e.g. InferenceContinLin's/InferenceCountNegBin's own
# mocked-backend-failure reference tests).

test_that("harden = TRUE: if fast_ols_with_var_cpp fails on every hardening attempt, the estimate/SE/df are all NA", {
	set.seed(21); n <- 40L
	X <- data.frame(x1 = rnorm(n), x2 = runif(n))
	des <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 5L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + 1.5 * des$get_w() + X$x1)

	inf <- InferenceContinOLS$new(des, harden = TRUE, verbose = FALSE)
	local_mocked_bindings(fast_ols_with_var_cpp = function(...) stop("forced failure"), .package = "EDI")

	est <- inf$compute_estimate()
	priv <- inf$.__enclos_env__$private
	expect_true(is.na(est))
	expect_true(is.na(priv$cached_values$beta_hat_T))
	expect_true(is.na(priv$cached_values$s_beta_hat_T))
	expect_true(is.na(priv$cached_values$df))
})

test_that("harden = FALSE: a fast_ols_with_var_cpp failure propagates uncaught (no hardening guard exists on this path)", {
	set.seed(22); n <- 40L
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 6L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())

	inf <- InferenceContinOLS$new(des, harden = FALSE, verbose = FALSE)
	local_mocked_bindings(fast_ols_with_var_cpp = function(...) stop("forced failure"), .package = "EDI")
	expect_error(inf$compute_estimate(), "forced failure")
})
