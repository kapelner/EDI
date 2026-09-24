library(testthat)
library(EDI)

# InferenceExtCIInversion's invert_test_pval_confidence_interval() (inference_ext_ci_inversion.R)
# caches a dynamic "<testing_type>_test_unavailable" reason when the test p-value at the fitted
# estimate is non-finite. test-likelihood-ci-inversion-profile-references.R's own "an unavailable test
# at the estimate" test already exercises this for testing_type = "score" ("score_test_unavailable"),
# but the Bartlett-corrected likelihood-ratio variants -- "lik_ratio_bartlett_approx" and "lik_ratio_
# bartlett_exact", both explicitly named in this function's own `bartlett_types` vector alongside
# "score"/"gradient"/"lik_ratio" -- had never been exercised (confirmed via a zero-hit grep for both
# resulting literal reason strings). Reached with the exact same technique the existing test already
# uses: mocking get_memoized_likelihood_test_pval() (private, unlockBinding) to return NA_real_ and
# calling invert_test_pval_confidence_interval() directly with each Bartlett testing_type.

logit_ci_fixture <- function(n = 80L, seed = 2L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(-0.3 + 0.9 * w + 0.4 * x))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("an unavailable Bartlett-approx test at the estimate caches 'lik_ratio_bartlett_approx_test_unavailable' and returns NA", {
	f <- logit_ci_fixture()
	unlockBinding("get_memoized_likelihood_test_pval", f$priv)
	f$priv$get_memoized_likelihood_test_pval <- function(...) NA_real_

	ci <- f$priv$invert_test_pval_confidence_interval(0.05, "lik_ratio_bartlett_approx")
	expect_equal(ci, c(NA_real_, NA_real_))
	expect_true(f$inf$is_nonestimable("se"))
	expect_identical(f$inf$get_nonestimable_reason(), "lik_ratio_bartlett_approx_test_unavailable")
})

test_that("an unavailable Bartlett-exact test at the estimate caches 'lik_ratio_bartlett_exact_test_unavailable' and returns NA", {
	f <- logit_ci_fixture(seed = 3L)
	unlockBinding("get_memoized_likelihood_test_pval", f$priv)
	f$priv$get_memoized_likelihood_test_pval <- function(...) NA_real_

	ci <- f$priv$invert_test_pval_confidence_interval(0.05, "lik_ratio_bartlett_exact")
	expect_equal(ci, c(NA_real_, NA_real_))
	expect_true(f$inf$is_nonestimable("se"))
	expect_identical(f$inf$get_nonestimable_reason(), "lik_ratio_bartlett_exact_test_unavailable")
})
