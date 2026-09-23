library(testthat)
library(EDI)

# InferenceIncidBinomialIdentityRiskDiff's compute_treatment_estimate_during_randomization_inference()
# (inference_incidence_binomial_identity.R) had no test reference anywhere -- the same gap pattern
# already closed this session on several sibling incidence classes.
#   1. The covariate-adjusted refit on the current (and then a permuted) w matches an independent
#      glm(family = binomial(link = "identity")) fit (started near the true generating coefficients,
#      since the unconstrained identity-link binomial IRLS is prone to non-convergence from a naive
#      start, the same reason InferenceIncidLogBinomial's sibling test seeds start values).
#   2. With no prior column selection (best_X_colnames still NULL), it calls shared() first.
#   3. With no covariates selected (model_formula = ~1), X = cbind(1, w) rather than
#      cbind(1, treatment = w, X_cov).
#   4. A fitter failure (res NULL or non-finite res$b[2]) returns NA.

binid_fixture <- function(seed = 1L, n = 80L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(-1.2 + 0.5 * w + 0.3 * X$x1))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, x = X$x1, y = y, w = w)
}

binid_no_cov_fixture <- function(seed = 2L, n = 80L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(-1.2 + 0.5 * w))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, y = y, w = w)
}

test_that("the randomization-time estimate refits the treatment coefficient for a permuted assignment, matching glm(binomial(identity))", {
	f <- binid_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, "x1")

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref <- unname(coef(glm(f$y ~ f$w + f$x, family = binomial(link = "identity"), start = c(0.3, 0.1, 0.05)))[2])
	expect_equal(est, ref, tolerance = 0.01)

	set.seed(9)
	w2 <- sample(f$w)
	f$priv$w <- w2
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref2 <- unname(coef(glm(f$y ~ w2 + f$x, family = binomial(link = "identity"), start = c(0.3, 0.1, 0.05)))[2])
	expect_equal(est2, ref2, tolerance = 0.01)
	expect_false(isTRUE(all.equal(est, est2, tolerance = 1e-3)))
})

test_that("without prior column selection it calls shared() first", {
	f <- binid_fixture(seed = 3L)
	expect_null(f$priv$best_X_colnames)
	expect_true(is.finite(f$priv$compute_treatment_estimate_during_randomization_inference()))
	expect_false(is.null(f$priv$best_X_colnames))
})

test_that("with no covariates selected, the refit uses X = cbind(1, w) and matches glm(y ~ w, binomial(identity))", {
	f <- binid_no_cov_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, character(0))

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref <- unname(coef(glm(f$y ~ f$w, family = binomial(link = "identity"), start = c(0.3, 0.1)))[2])
	expect_equal(est, ref, tolerance = 0.01)
})

test_that("a fitter failure (res NULL or non-finite res$b[2]) returns NA", {
	f <- binid_fixture(seed = 4L)
	f$inf$compute_estimate()
	local_mocked_bindings(fast_identity_binomial_regression_cpp = function(...) NULL, .package = "EDI")
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))

	local_mocked_bindings(
		fast_identity_binomial_regression_cpp = function(X, ...) list(b = c(0, NA_real_, rep(0, ncol(X) - 2L))),
		.package = "EDI"
	)
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))
})
