library(testthat)
library(EDI)

make_dep_cens_contract_design <- function() {
	y <- c(2, 4, 5, 8, 3, 7, 9, 10, 4, 11, 6, 12)
	n <- length(y)
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = seq(-1, 1, length.out = n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
	des$add_all_subject_responses(y)
	des
}

test_that("dependent-censoring CI predicates classify sign exclusion and unstable width", {
	inf <- InferenceSurvivalDepCensTransformRegr$new(make_dep_cens_contract_design(), verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_true(priv$dep_cens_ci_excludes_zero(c(0.1, 1)))
	expect_true(priv$dep_cens_ci_excludes_zero(c(-2, -0.1)))
	expect_false(priv$dep_cens_ci_excludes_zero(c(-0.1, 0.2)))
	expect_false(priv$dep_cens_ci_excludes_zero(c(NA, 1)))
	expect_true(priv$dep_cens_ci_too_wide(c(NA, 1)))
	expect_false(priv$dep_cens_ci_too_wide(c(-1, 1)))
})

test_that("KK survival rank helpers extract named estimates and standard errors", {
	mod <- lm(c(1, 2.3, 4, 5.7, 7.2, 8.1) ~ w + x,
		data = data.frame(w = c(0, 1, 0, 1, 0, 1), x = seq(-1, 1, length.out = 6)))
	priv <- EDI:::SurvivalKKRankRegrIVWCSource$private
	expect_equal(priv$extract_term_estimate(mod, "w"), unname(coef(mod)[["w"]]))
	# Base lm uses "Std. Error", while the AFT backends use one of the
	# explicitly supported compact spellings; an unknown spelling is unavailable.
	expect_true(is.na(priv$extract_term_se(mod, "w")))
	expect_true(is.na(priv$extract_term_estimate(mod, "missing")))
	expect_true(is.na(priv$extract_term_se(mod, "missing")))
})

test_that("KK survival likelihood leaves advertise their intended inference surfaces", {
	ivwc <- EDI:::KKLWACoxIVWCPartialLikelihoodSource$private
	one_lik <- EDI:::KKLWACoxOneLikPartialLikelihoodSource$private
	expect_true(ivwc$is_a_kk_lwa_cox_ivwc())
	expect_true(one_lik$is_a_kk_lwa_cox_one_lik())
	expect_true(one_lik$supports_likelihood_tests())
	expect_true(one_lik$supports_lik_ratio_param_bootstrap())
	expect_identical(one_lik$get_degrees_of_freedom(), Inf)
})

test_that("concrete KK survival leaves retain their expected inheritance contracts", {
	expect_true(R6::is.R6Class(InferenceSurvivalKKLWACoxPHIVWC))
	expect_true(R6::is.R6Class(InferenceSurvivalKKLWACoxPHOneLik))
	expect_true(R6::is.R6Class(InferenceSurvivalKKRankRegrIVWC))
	expect_true(R6::is.R6Class(InferenceSurvivalKKWeibullMarginal))
})
