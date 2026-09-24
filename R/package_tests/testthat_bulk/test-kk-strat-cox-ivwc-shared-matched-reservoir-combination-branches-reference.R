library(testthat)
library(EDI)

# InferenceSurvivalKKStratCoxPHIVWC's private shared() (inference_survival_KK_strat_cox.R) combines a
# stratified-Cox fit on the matched pairs (fast_stratified_coxph_regression_cpp) and a standard-Cox
# fit on the reservoir (fast_coxph_regression_cpp) via inverse-variance weighting -- the same
# IVWC-combination pattern already closed this stretch for 3 sibling classes (InferenceIncidKKCond
# LogitIVWC, InferenceContinKKRobustRegrIVWC, InferenceSurvivalGLMMWeibullFrailtyNormalIVWC), but
# unlike those, the "neither succeeds" branch here calls cache_nonestimable_estimate("kk_strat_cox_
# ivwc_both_failed") instead of raw NA assignment -- its own distinct, testable contract. Unlike the
# sibling classes' component-fitting private methods (frailty_for_matched_pairs() etc.), this class
# calls the C++ Cox fitters directly inline inside shared(), so the branches are reached by mocking
# the two package-level kernels (fast_stratified_coxph_regression_cpp/fast_coxph_regression_cpp)
# rather than unlockBinding-replacing a named component method. The class's only 2 existing
# references (test-partial-likelihood-migration-baseline.R, test-survival-kk-strat-cox-ivwc-
# migration-golden.R) are both golden migration-parity tests exercising only the ordinary happy path.

mk_fixture <- function(seed, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rexp(n, exp(0.3 * w))
	des$add_all_subject_responses(y)
	InferenceSurvivalKKStratCoxPHIVWC$new(des, verbose = FALSE)
}

fake_strat_ok <- list(coefficients = c(1.2), vcov = matrix(0.2, 1, 1), converged = TRUE)
fake_res_ok <- list(coefficients = c(0.9), vcov = matrix(0.5, 1, 1), converged = TRUE)

test_that("only the stratified-Cox (matched-pairs) piece succeeds: beta_hat_T = beta_m, s_beta_hat_T = sqrt(ssq_m)", {
	inf <- mk_fixture(1L)
	priv <- inf$.__enclos_env__$private
	local_mocked_bindings(fast_stratified_coxph_regression_cpp = function(...) fake_strat_ok, .package = "EDI")
	local_mocked_bindings(fast_coxph_regression_cpp = function(...) NULL, .package = "EDI")
	est <- inf$compute_estimate()
	expect_equal(est, 1.2)
	expect_equal(priv$cached_values$s_beta_hat_T, sqrt(0.2))
})

test_that("only the standard-Cox (reservoir) piece succeeds: beta_hat_T = beta_r, s_beta_hat_T = sqrt(ssq_r)", {
	inf <- mk_fixture(2L)
	priv <- inf$.__enclos_env__$private
	local_mocked_bindings(fast_stratified_coxph_regression_cpp = function(...) NULL, .package = "EDI")
	local_mocked_bindings(fast_coxph_regression_cpp = function(...) fake_res_ok, .package = "EDI")
	est <- inf$compute_estimate()
	expect_equal(est, 0.9)
	expect_equal(priv$cached_values$s_beta_hat_T, sqrt(0.5))
})

test_that("both pieces succeed: the IVWC combination matches the closed-form weighted formula exactly", {
	inf <- mk_fixture(3L)
	priv <- inf$.__enclos_env__$private
	local_mocked_bindings(fast_stratified_coxph_regression_cpp = function(...) fake_strat_ok, .package = "EDI")
	local_mocked_bindings(fast_coxph_regression_cpp = function(...) fake_res_ok, .package = "EDI")
	est <- inf$compute_estimate()
	w_star <- 0.5 / (0.5 + 0.2)
	expect_equal(est, w_star * 1.2 + (1 - w_star) * 0.9)
	expect_equal(priv$cached_values$s_beta_hat_T, sqrt(0.2 * 0.5 / (0.2 + 0.5)))
})

test_that("neither piece succeeds: the estimate is nonestimable with the exact documented reason", {
	inf <- mk_fixture(4L)
	local_mocked_bindings(fast_stratified_coxph_regression_cpp = function(...) NULL, .package = "EDI")
	local_mocked_bindings(fast_coxph_regression_cpp = function(...) NULL, .package = "EDI")
	est <- inf$compute_estimate()
	expect_true(is.na(est))
	expect_true(inf$is_nonestimable("estimate"))
	expect_equal(inf$get_nonestimable_reason(), "kk_strat_cox_ivwc_both_failed")
})
