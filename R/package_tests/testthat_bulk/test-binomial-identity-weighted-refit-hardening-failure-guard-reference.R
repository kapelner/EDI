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
# A design with an all-ones response and no censoring drives every candidate fit's mu_hat to
# (numerically) exactly 1: is_identity_binomial_fit_reasonable() rejects it on non-convergence
# (fast_identity_binomial_regression_weighted_cpp's IRLS never reports converged = TRUE against a
# response with zero residual variance), verified directly below, and hardening finds no rescue.

test_that("fast_identity_binomial_regression_weighted_cpp reports non-convergence against an all-ones response", {
	set.seed(1); n <- 30L
	X <- cbind(`(Intercept)` = 1, treatment = rep(0:1, n / 2))
	y <- rep(1, n)
	wt <- rexp(n)
	fit <- EDI:::fast_identity_binomial_regression_weighted_cpp(
		X = X, y = y, weights = wt, warm_start_beta = NULL, warm_start_fisher_info = NULL
	)
	expect_false(isTRUE(fit$converged))
})

test_that("compute_estimate_with_bootstrap_weights caches 'binomial_identity_weighted_fit_unavailable' and returns NA when hardening exhausts every column subset", {
	set.seed(1); n <- 30L
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rep(1L, n))

	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()

	set.seed(2); wt <- rexp(n)
	res <- p$weighted_refit_impl(wt)
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "binomial_identity_weighted_fit_unavailable")
	expect_true(is.na(p$cached_values$beta_hat_T))
})
