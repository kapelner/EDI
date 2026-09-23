library(testthat)
library(EDI)

# InferenceSurvivalCoxPHRegr$generate_mod() (inference_survival_coxph.R) has 3 call sites -- the
# use_rcpp = TRUE fast path, and the survival::coxph() R fallback's estimate_only = TRUE and
# estimate_only = FALSE branches -- that each cache "coxph_extreme_coefficients" when
# cox_coefficients_extreme() judges the fitted coefficients unreasonable. The predicate itself
# (cox_coefficients_extreme()) is already thoroughly unit-tested in isolation, and the sibling
# weighted-refit guard ("coxph_weighted_extreme_coefficients") is already covered, but this
# unweighted generate_mod() wiring -- actually reaching the reason through the fitting path, at all
# 3 call sites -- had no test reference anywhere. Reached by overriding the private predicate
# (unlockBinding) to always report "extreme", the same technique already used elsewhere in this
# suite for analogous unreachable-in-practice failure paths.

coxph_fixture <- function(seed = 1L, n = 40L, use_rcpp = TRUE) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(response_type = "survival", n = n, seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	add_all_subject_responses_seq(des, rexp(n, exp(0.3 * rnorm(n))), deads = rbinom(n, 1, 0.8))
	InferenceSurvivalCoxPHRegr$new(des, use_rcpp = use_rcpp, verbose = FALSE)
}

test_that("the use_rcpp = TRUE fast path caches 'coxph_extreme_coefficients' when the predicate rejects the fit", {
	inf <- coxph_fixture(1L, use_rcpp = TRUE)
	p <- inf$.__enclos_env__$private
	unlockBinding("cox_coefficients_extreme", p)
	p$cox_coefficients_extreme <- function(coefs) TRUE

	res <- p$generate_mod(estimate_only = TRUE)
	expect_identical(inf$get_nonestimable_reason(), "coxph_extreme_coefficients")
})

test_that("the survival::coxph() R-fallback path caches the same reason for both estimate_only values", {
	for (estimate_only in c(TRUE, FALSE)) {
		inf <- coxph_fixture(2L, use_rcpp = FALSE)
		p <- inf$.__enclos_env__$private
		unlockBinding("cox_coefficients_extreme", p)
		p$cox_coefficients_extreme <- function(coefs) TRUE

		res <- p$generate_mod(estimate_only = estimate_only)
		expect_identical(inf$get_nonestimable_reason(), "coxph_extreme_coefficients", info = estimate_only)
	}
})
