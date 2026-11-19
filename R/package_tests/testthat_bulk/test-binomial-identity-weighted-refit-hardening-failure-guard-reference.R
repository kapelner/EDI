library(testthat)
library(EDI)

# InferenceIncidBinomialIdentityRiskDiff's compute_estimate_with_bootstrap_weights()
# (IncidenceBinomialIdentityLikelihoodSource, inference_incidence_binomial_identity.R) drives
# fit_with_hardened_qr_column_dropping() with a fit_ok() predicate that rejects any refit whose
# fitted probabilities is_identity_binomial_fit_reasonable() judges unreasonable (non-finite
# coefficients, non-convergence, or a fitted mu outside [0, 1]). If hardening exhausts every column
# subset without ever satisfying fit_ok(), the method caches "binomial_identity_weighted_fit_
# unavailable" and returns NA. The existing weighted-refit reference test only exercises the normal
# success path (a well-conditioned covariate-adjusted fit); this hardening-exhaustion branch had no
# test reference anywhere.
#
# The public compute_estimate_with_bootstrap_weights() method runs isolated (the same
# isolation-wrapper mechanism documented in inference_all_abstract.R and already used by the
# InferenceContinLin weighted-refit reference tests), so private$cached_values isn't populated on
# the object the caller holds; private$weighted_refit_impl() -- the pre-wrap implementation, the
# same technique those Lin tests use -- is called directly instead, to inspect the cache it fills.
#
# The guard is driven by mocking the identity-binomial kernels to return a non-converged fit, which
# is_identity_binomial_fit_reasonable() rejects for every column subset. Until 2026-11-18 an
# all-ones response did this for real (the cold start sat outside the mean support and IRLS never
# converged); since v1.0.6-TODO-142 pulls such a start into the support, that fit converges to the
# correct boundary MLE (intercept 1, risk difference 0), checked by the first and last tests below.
mock_unconverged_identity_binomial <- function() {
	bad <- function(X, ...) list(b = rep(0, NCOL(X)), converged = FALSE, ssq_b_j = NA_real_)
	local_mocked_bindings(
		fast_identity_binomial_regression_cpp = bad,
		fast_identity_binomial_regression_with_var_cpp = bad,
		fast_identity_binomial_regression_weighted_cpp = bad,
		.package = "EDI", .env = parent.frame()
	)
}

all_ones_design <- function(n = 30L) {
	set.seed(1)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rep(1L, n))
	des
}

test_that("fast_identity_binomial_regression_weighted_cpp converges to the boundary MLE against an all-ones response (v1.0.6-TODO-142)", {
	set.seed(1); n <- 30L
	X <- cbind(`(Intercept)` = 1, treatment = rep(0:1, n / 2))
	y <- rep(1, n)
	wt <- rexp(n)
	fit <- EDI:::fast_identity_binomial_regression_weighted_cpp(
		X = X, y = y, weights = wt, warm_start_beta = NULL, warm_start_fisher_info = NULL
	)
	expect_true(isTRUE(fit$converged))
	expect_equal(as.numeric(fit$b), c(1, 0), tolerance = 1e-6)
})

test_that("compute_estimate_with_bootstrap_weights caches 'binomial_identity_weighted_fit_unavailable' and returns NA when hardening exhausts every column subset", {
	des <- all_ones_design()
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	mock_unconverged_identity_binomial()

	set.seed(2); wt <- rexp(30L)
	res <- p$weighted_refit_impl(wt)
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "binomial_identity_weighted_fit_unavailable")
	expect_true(is.na(p$cached_values$beta_hat_T))
})

test_that("an all-ones weighted refit now fits: risk difference 0, not nonestimable (v1.0.6-TODO-142)", {
	des <- all_ones_design()
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()

	set.seed(2); wt <- rexp(30L)
	res <- p$weighted_refit_impl(wt)
	expect_equal(res, 0, tolerance = 1e-8)
	expect_null(p$cached_values$nonestimable_reason)
})
