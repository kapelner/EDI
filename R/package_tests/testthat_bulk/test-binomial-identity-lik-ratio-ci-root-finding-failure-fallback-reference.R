library(testthat)
library(EDI)

# InferenceIncidBinomialIdentityRiskDiff's compute_lik_ratio_confidence_interval()
# (inference_incidence_binomial_identity.R, registry weighted_opportunity 35 -- the second of two
# gaps this file's registry entry named, the first being the weighted-refit hardening-failure path
# closed in test-binomial-identity-weighted-refit-hardening-failure-nonestimable-reference.R) wraps
# its call to private$compute_lik_ratio_confidence_interval_impl(alpha) (the shared Newton-inversion
# root-finder in inference_ext_ci_inversion.R) in a tryCatch: on any error from that root-finding
# machinery, it caches a nonestimable SE ("lik_ratio_confidence_interval_unavailable") and returns an
# NA/NA interval rather than propagating the error. No R-constructible dataset was found that makes
# the shared Newton root-finder itself throw (it degrades gracefully via its own internal fallbacks),
# so this exercises the class's own tryCatch/fallback wiring directly: a deliberately monkey-patched
# private$compute_lik_ratio_confidence_interval_impl that throws, confirming the outer method catches
# it and produces the documented fallback result, independent of whether the underlying root-finder
# can currently be driven into throwing.

test_that("a forced error from compute_lik_ratio_confidence_interval_impl() is caught and produces the documented NA/NA fallback interval", {
	set.seed(5L); n <- 40L
	x1 <- rnorm(n, sd = 0.3)
	w <- rep(0:1, n / 2)
	y <- rbinom(n, 1, pmin(pmax(0.3 + 0.15 * w + 0.1 * x1, 0.02), 0.98))
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, model_formula = ~x1, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	unlockBinding("compute_lik_ratio_confidence_interval_impl", priv)
	priv$compute_lik_ratio_confidence_interval_impl <- function(alpha) stop("forced root-finding failure for coverage")

	ci <- inf$compute_lik_ratio_confidence_interval(alpha = 0.05)
	expect_true(all(is.na(ci)))
	expect_length(ci, 2L)
	expect_identical(names(ci), c("2.5%", "97.5%"))
	expect_identical(priv$cached_values$nonestimable_reason, "lik_ratio_confidence_interval_unavailable")
})

test_that("without the forced failure, the same fixture's lik-ratio CI computes normally (sanity check the mocked test above isn't masking something already broken)", {
	set.seed(5L); n <- 40L
	x1 <- rnorm(n, sd = 0.3)
	w <- rep(0:1, n / 2)
	y <- rbinom(n, 1, pmin(pmax(0.3 + 0.15 * w + 0.1 * x1, 0.02), 0.98))
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, model_formula = ~x1, verbose = FALSE)

	ci <- inf$compute_lik_ratio_confidence_interval(alpha = 0.05)
	expect_true(all(is.finite(ci)))
})
