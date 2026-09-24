library(testthat)
library(EDI)

# InferenceAsympLik's compute_likelihood_test_two_sided_pval() (inference_all_abstract_asymp_lik_std_
# mod_cache.R) caches a dynamic reason ("<testing_type>_test_unavailable") via cache_nonestimable_se()
# when get_memoized_likelihood_test_pval() returns a non-finite p-value and the estimate itself isn't
# already flagged nonestimable. "score_test_unavailable" and "gradient_test_unavailable" already have
# test references (through other call sites -- test-likelihood-ci-inversion-profile-references.R and
# InferenceExtCIInversion's invert_gradient_ci_uniroot() respectively), but "lik_ratio_test_unavailable"
# -- reached through THIS exact dispatcher with testing_type = "lik_ratio" -- had never been exercised
# anywhere (confirmed via a zero-hit grep for the literal string). Reached by mocking get_memoized_
# likelihood_test_pval() (private, unlockBinding) to return NA_real_, the same technique the sibling
# gradient-guard test already uses. score/gradient are re-verified here too, through this exact
# function (not just their other call sites), for completeness on the shared testing_type-parameterized
# reason-formatting logic.

lik_priv <- function(n = 40L, seed = 2L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("compute_likelihood_test_two_sided_pval() caches '<testing_type>_test_unavailable' for lik_ratio/score/gradient when the memoized p-value is non-finite", {
	for (testing_type in c("lik_ratio", "score", "gradient")) {
		f <- lik_priv()
		unlockBinding("get_memoized_likelihood_test_pval", f$priv)
		f$priv$get_memoized_likelihood_test_pval <- function(...) NA_real_

		pv <- f$priv$compute_likelihood_test_two_sided_pval(0, testing_type)
		expect_true(is.na(pv), info = testing_type)
		expect_identical(f$inf$get_nonestimable_reason(), paste0(testing_type, "_test_unavailable"), info = testing_type)
	}
})
