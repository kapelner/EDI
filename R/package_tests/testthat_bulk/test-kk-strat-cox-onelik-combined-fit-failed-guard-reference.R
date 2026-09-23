library(testthat)
library(EDI)

# InferenceSurvivalKKStratCoxPHOneLik's private shared_combined_likelihood()
# (inference_survival_KK_strat_cox.R) drives fit_with_hardened_qr_column_dropping() around
# fast_stratified_coxph_regression_cpp(); if hardening never finds a fit that satisfies fit_ok()
# across every column subset, it caches "kk_strat_cox_combined_fit_failed". This had no test
# reference anywhere. Reached via InferenceSurvivalKKStratCoxPHOneLik, a non-IVWC concrete class (the
# IVWC compound estimators are out of scope for this suite), by mocking
# fast_stratified_coxph_regression_cpp itself to always return NULL -- the same
# local_mocked_bindings(..., .package = "EDI") technique already used elsewhere in this suite for
# analogous unreachable-in-practice failure paths.

test_that("shared_combined_likelihood caches 'kk_strat_cox_combined_fit_failed' when the stratified Cox kernel always fails", {
	set.seed(1); n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	add_all_subject_responses_seq(des, rexp(n, exp(0.3 * X$x1 + 0.2 * w)), deads = rbinom(n, 1, 0.8))

	inf <- InferenceSurvivalKKStratCoxPHOneLik$new(des, verbose = FALSE)
	local_mocked_bindings(fast_stratified_coxph_regression_cpp = function(...) NULL, .package = "EDI")

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "kk_strat_cox_combined_fit_failed")
})
