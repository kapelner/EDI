library(testthat)
library(EDI)

# InferenceExtLikelihoodTestMemoization's compute_likelihood_test_two_sided_pval() (inference_ext_
# likelihood_test_memoization.R, spliced into InferenceAsympLik and composed into every likelihood-
# ratio-capable class) has a guard right at the top: `spec = private$get_likelihood_test_spec(); if
# (is.null(spec)) { if (!isTRUE(self$is_nonestimable())) private$cache_nonestimable_estimate(
# "likelihood_test_spec_unavailable"); return(NA_real_) }`. This is deliberately idempotent: it does
# NOT overwrite an already-cached nonestimable reason from an earlier, more specific failure. A
# codebase-wide grep confirms this exact base reason string ("likelihood_test_spec_unavailable", as
# opposed to class-specific variants such as "kk_clogit_combined_likelihood_test_spec_unavailable",
# already covered elsewhere) had no test reference anywhere. Reached on InferenceIncidLogRegr (a
# simple, likelihood-ratio-capable logistic-regression class) by unlockBinding-replacing
# get_likelihood_test_spec() with a stub returning NULL, independent of the real likelihood-test-spec
# machinery (already tested elsewhere).

fx <- function(seed = 1L, n = 30L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(-0.3 + 0.9 * w + 0.4 * X$x1))
	des$add_all_subject_responses(y)
	des
}

test_that("a NULL likelihood-test spec caches the documented nonestimable reason and returns NA", {
	inf <- InferenceIncidLogRegr$new(fx(1L), verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	unlockBinding("get_likelihood_test_spec", priv)
	priv$get_likelihood_test_spec <- function(...) NULL

	pv <- priv$compute_likelihood_test_two_sided_pval(delta = 0, testing_type = "lik_ratio_bartlett_exact")
	expect_true(is.na(pv))
	# 2026-10-22 (TODO-116 lik-test stage): on a valid Wald fit a NULL spec is a failure of this
	# likelihood test only -- recorded under procedure_failure_reason[[testing_type]]; the Wald
	# estimate/SE stay and the object stays estimable. (A NULL spec on an already-failed primary fit
	# keeps the old nonestimable path -- see the next test.)
	expect_false(inf$is_nonestimable())
	expect_true(is.finite(inf$compute_estimate()))
	expect_equal(priv$cached_values$procedure_failure_reason$lik_ratio_bartlett_exact, "likelihood_test_spec_unavailable")
})

test_that("an already-cached nonestimable reason from an earlier failure is NOT overwritten by this guard", {
	inf <- InferenceIncidLogRegr$new(fx(2L), verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$cache_nonestimable_estimate("some_other_reason")
	unlockBinding("get_likelihood_test_spec", priv)
	priv$get_likelihood_test_spec <- function(...) NULL

	pv <- priv$compute_likelihood_test_two_sided_pval(delta = 0, testing_type = "lik_ratio_bartlett_exact")
	expect_true(is.na(pv))
	expect_equal(inf$get_nonestimable_reason(), "some_other_reason")
})

test_that("a real, well-formed fit does not trigger the spec-unavailable guard", {
	inf <- InferenceIncidLogRegr$new(fx(3L), verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$compute_likelihood_test_two_sided_pval(delta = 0, testing_type = "lik_ratio_bartlett_exact")
	expect_false(isTRUE(identical(inf$get_nonestimable_reason(), "likelihood_test_spec_unavailable")))
})
