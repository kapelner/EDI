library(testthat)
library(EDI)

# InferenceSurvivalCoxPHRegr$generate_mod_icen() (inference_survival_coxph.R) has its own
# "coxph_icenreg_extreme_coefficients" nonestimable guard -- fired when icenReg::ic_sp() returns a
# finite fit whose coefficients cox_coefficients_extreme() judges unreasonable -- distinct from, and
# reached differently than, the already-covered "failed fit entirely" branch
# (test-coxph-icen-fit-failure-nonfinite-variance-and-bootstrap-budget-reference.R) and the sibling
# unweighted generate_mod() (exact/right-censored path)'s own "coxph_extreme_coefficients" guard
# (test-coxph-generate-mod-extreme-coefficients-guard-reference.R, which does not exercise this
# interval-censored code path at all). Confirmed via a zero-hit grep for the exact reason string.
# Reached by mocking icenReg::ic_sp() to return a finite fit with an extreme coefficient, the same
# local_mocked_bindings(..., .package = "icenReg") technique the sibling icen file already uses.

skip_if_not_installed("icenReg")

des_icen <- function() {
	ys   <- c(1,  NA, NA, 2.5, NA, NA)
	y_Ls <- c(NA, 3,  2,  NA,  4,  3)
	y_Rs <- c(NA, Inf, 5, NA,  Inf, 6)
	des <- DesignFixedBernoulli$new(n = 6L, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(6L)))
	des$overwrite_all_subject_assignments(c(0, 0, 0, 1, 1, 1))
	des$add_all_subject_responses(ys, y_Ls, y_Rs)
	des
}
mk <- function() {
	inf <- InferenceSurvivalCoxPHRegr$new(des_icen(), model_formula = ~1, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}
fake_fit <- function(coef) {
	structure(
		list(coefficients = c(treatment = coef), var = matrix(0.09, 1, 1, dimnames = list("treatment", "treatment")), llk = -7.5),
		class = "fake_ic"
	)
}

test_that("a finite but extreme-coefficient ic_sp fit caches 'coxph_icenreg_extreme_coefficients' and returns an all-NA result", {
	f <- mk()
	extreme_coef <- f$priv$cox_extreme_coef_threshold + 5
	expect_true(f$priv$cox_coefficients_extreme(extreme_coef))                       # sanity: the real predicate agrees it's extreme
	f$priv$cached_values$likelihood_test_context <- list(stale = TRUE)
	local_mocked_bindings(ic_sp = function(...) fake_fit(extreme_coef), .package = "icenReg")

	out <- f$priv$generate_mod_icen()
	expect_identical(f$inf$get_nonestimable_reason(), "coxph_icenreg_extreme_coefficients")
	expect_null(f$priv$cached_values$likelihood_test_context)
	expect_true(is.na(out$beta_hat_T))
	expect_true(is.na(out$ssq_b_2))
})

test_that("a finite, well-behaved coefficient does NOT trigger the extreme-coefficients guard", {
	f <- mk()
	ok_coef <- min(f$priv$cox_extreme_coef_threshold - 5, 5)
	expect_false(f$priv$cox_coefficients_extreme(ok_coef))
	local_mocked_bindings(ic_sp = function(...) fake_fit(ok_coef), .package = "icenReg")

	out <- f$priv$generate_mod_icen()
	expect_null(f$inf$get_nonestimable_reason())
	expect_equal(out$beta_hat_T, ok_coef)
})
