library(testthat)
library(EDI)

# InferenceIncidRiskDiff's own shared() (inference_incidence_risk_diff.R) has a guard distinct from
# the sibling "model_fit_unavailable" guard (generate_mod() returns NULL entirely): when generate_mod()
# returns a non-NULL model_output but its beta_hat_T (or, absent that field, b[2]) is non-finite,
# shared() caches "model_treatment_estimate_unavailable". This had no test reference anywhere. This
# class deliberately does NOT compose the shared StandardModelCache component (its OLS
# linear-probability objective is a misspecified working model, so it can't declare likelihood
# tests -- see the source-level comment directly above shared()), owning an identical copy of this
# state machine directly instead; the sibling test for the composed-component version is
# test-asymp-lik-std-mod-cache-model-treatment-estimate-unavailable-guard-reference.R (InferenceProp-
# FractionalLogit). Reached the same way: mocking generate_mod() (unlockBinding, private) to return a
# well-formed-looking model_output list whose treatment coefficient is explicitly non-finite.

risk_diff_fixture <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	x <- rnorm(n)
	w <- rep(0:1, n / 2)
	y <- as.numeric(0.4 + 0.15 * w + 0.1 * x + rnorm(n, sd = 0.2) > 0.5)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	InferenceIncidRiskDiff$new(des, verbose = FALSE)
}

test_that("shared() caches 'model_treatment_estimate_unavailable' when generate_mod()'s beta_hat_T/b[2] is non-finite", {
	inf <- risk_diff_fixture()
	p <- inf$.__enclos_env__$private
	unlockBinding("generate_mod", p)
	p$generate_mod <- function(estimate_only = FALSE) {
		list(b = c(0.4, NA_real_), fisher_information = diag(2))
	}

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "model_treatment_estimate_unavailable")
	expect_true(is.na(p$cached_values$df))
})

test_that("shared() also fires when beta_hat_T is explicitly non-finite despite a finite b[2]", {
	inf <- risk_diff_fixture(seed = 2L)
	p <- inf$.__enclos_env__$private
	unlockBinding("generate_mod", p)
	p$generate_mod <- function(estimate_only = FALSE) {
		list(beta_hat_T = NaN, b = c(0.4, 0.15), fisher_information = diag(2))
	}

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "model_treatment_estimate_unavailable")
})
