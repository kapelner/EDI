library(testthat)
library(EDI)

# InferenceSurvivalKKStratCoxPHIVWC's private rcpp_cox_fit_is_usable(fit, estimate_only) (inference_
# survival_KK_strat_cox.R) is the pure acceptance predicate shared()'s inline C++ Cox fitters (fast_
# stratified_coxph_regression_cpp/fast_coxph_regression_cpp) are checked against before a fit is
# trusted: NULL/non-converged -> FALSE, a non-finite or too-extreme coefficient -> FALSE, and (unless
# estimate_only) a non-finite, non-positive or too-extreme standard error -> FALSE. The class's existing
# reference tests (test-kk-strat-cox-ivwc-shared-matched-reservoir-combination-branches-reference.R,
# migration-golden files) all mock the two C++ kernels directly to return already-known-good fit
# objects, so they exercise shared()'s combination logic but never this predicate's own individual
# branches. A codebase-wide grep confirmed zero test references anywhere. Exercised via direct
# private-method calls with hand-built fit lists on a real KK14 instance.

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rexp(n, exp(0.3 * w)))
	inf <- InferenceSurvivalKKStratCoxPHIVWC$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

ok_fit <- function() list(coefficients = 1.2, vcov = matrix(0.2, 1, 1), converged = TRUE)

test_that("a well-formed, converged fit with a finite coefficient and finite positive SE is usable", {
	priv <- fx(1L)
	expect_true(priv$rcpp_cox_fit_is_usable(ok_fit()))
	expect_equal(priv$max_abs_reasonable_coef, 1e4)
})

test_that("NULL or a non-converged fit is never usable, regardless of estimate_only", {
	priv <- fx(2L)
	expect_false(priv$rcpp_cox_fit_is_usable(NULL))
	expect_false(priv$rcpp_cox_fit_is_usable(NULL, estimate_only = TRUE))
	not_converged <- ok_fit(); not_converged$converged <- FALSE
	expect_false(priv$rcpp_cox_fit_is_usable(not_converged))
})

test_that("a non-finite or too-extreme coefficient is never usable, regardless of estimate_only", {
	priv <- fx(3L)
	nonfinite_coef <- ok_fit(); nonfinite_coef$coefficients <- NA_real_
	expect_false(priv$rcpp_cox_fit_is_usable(nonfinite_coef))
	extreme_coef <- ok_fit(); extreme_coef$coefficients <- 1e5  # exceeds max_abs_reasonable_coef = 1e4
	expect_false(priv$rcpp_cox_fit_is_usable(extreme_coef))
	expect_false(priv$rcpp_cox_fit_is_usable(extreme_coef, estimate_only = TRUE))
})

test_that("estimate_only = TRUE skips the standard-error check entirely: an otherwise-usable fit with a broken SE still passes", {
	priv <- fx(4L)
	broken_se <- ok_fit(); broken_se$vcov <- matrix(-1, 1, 1)  # sqrt(-1) -> NaN
	expect_true(suppressWarnings(priv$rcpp_cox_fit_is_usable(broken_se, estimate_only = TRUE)))
})

test_that("with estimate_only = FALSE (the default), a non-finite, zero, or too-extreme standard error is never usable", {
	priv <- fx(5L)
	nonfinite_se <- ok_fit(); nonfinite_se$vcov <- matrix(-1, 1, 1)
	expect_false(suppressWarnings(priv$rcpp_cox_fit_is_usable(nonfinite_se)))
	zero_se <- ok_fit(); zero_se$vcov <- matrix(0, 1, 1)
	expect_false(priv$rcpp_cox_fit_is_usable(zero_se))
	huge_se <- ok_fit(); huge_se$vcov <- matrix(1e10, 1, 1)  # sqrt(1e10) exceeds max_abs_reasonable_coef
	expect_false(priv$rcpp_cox_fit_is_usable(huge_se))
})
