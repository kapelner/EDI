library(testthat)
library(EDI)

# inference_incidence_logit.R's compute_estimate_with_bootstrap_weights (the
# hardened-QR weighted logistic refit) has never been checked against an
# independent reference at all -- grep across testthat_bulk/, testthat/, and
# R/EDI/tests/testthat/ finds zero calls to it for this class (unlike the
# sibling incidence-g-comp classes, whose weighted paths were only
# unit-weight-checked). Verify the true weighted-refit numerics, including
# the real Fisher-information-derived SE this method computes.

logit_fixture <- function(seed) {
	withr::local_seed(seed, .local_envir = parent.frame())
	n <- 100L
	x <- rnorm(n)
	w <- rep(0:1, n / 2)
	y <- rbinom(n, 1, plogis(-0.5 + 0.6 * w + 0.3 * x))
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidLogRegr$new(des, model_formula = ~ x, verbose = FALSE)
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
	list(inf = inf, X = cbind("(Intercept)" = 1, treatment = w, x = x), y = y, n = n)
}

logit_weighted_ref <- function(f, weights) {
	suppressWarnings(glm.fit(f$X, f$y, weights = weights, family = binomial(link = "logit")))
}

test_that("weighted logistic refit matches an independent glm.fit(family=binomial()) reference, including SE", {
	f <- logit_fixture(41011)
	weights <- runif(f$n, 0.5, 2)

	est_pkg <- as.numeric(f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE))
	ref <- logit_weighted_ref(f, weights)
	est_ref <- unname(ref$coefficients[2])
	expect_equal(est_pkg, est_ref, tolerance = 1e-5)

	se_pkg <- as.numeric(f$inf$.__enclos_env__$private$cached_values$s_beta_hat_T)
	fi <- crossprod(f$X, weights * ref$weights / ref$prior.weights * f$X)
	# ref$weights are the IRLS working weights at convergence; recompute the
	# standard Fisher information (X' W X) directly from the fitted probabilities
	# instead, to keep this an independent derivation.
	p_hat <- plogis(f$X %*% ref$coefficients)
	fisher_info <- crossprod(f$X, as.numeric(weights * p_hat * (1 - p_hat)) * f$X)
	se_ref <- sqrt(solve(fisher_info)[2, 2])
	expect_equal(se_pkg, se_ref, tolerance = 1e-4)
})

test_that("estimate_only=TRUE skips the SE computation", {
	f <- logit_fixture(41012)
	weights <- runif(f$n, 0.5, 2)
	f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)
	expect_true(is.na(f$inf$.__enclos_env__$private$cached_values$s_beta_hat_T))
})

test_that("unit-weight refit reproduces compute_estimate()", {
	f <- logit_fixture(41013)
	unweighted <- as.numeric(f$inf$compute_estimate())
	f2 <- logit_fixture(41013)
	weighted_unit <- as.numeric(f2$inf$compute_estimate_with_bootstrap_weights(rep(1, f2$n), estimate_only = TRUE))
	expect_equal(weighted_unit, unweighted, tolerance = 1e-6)
})

test_that("weighted refit is scale-invariant to a common weight multiplier", {
	f <- logit_fixture(41014)
	weights <- runif(f$n, 0.3, 3)
	est1 <- as.numeric(f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE))
	f2 <- logit_fixture(41014)
	est2 <- as.numeric(f2$inf$compute_estimate_with_bootstrap_weights(4 * weights, estimate_only = TRUE))
	expect_equal(est2, est1, tolerance = 1e-4)
})

test_that("near-perfect separation under resampled weights is caught as nonestimable", {
	withr::local_seed(41015, .local_envir = parent.frame())
	n <- 60L
	x <- rnorm(n)
	w <- rep(0:1, n / 2)
	# y perfectly determined by treatment -> any nonzero weight on these rows
	# alone drives near-perfect separation.
	y <- w
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidLogRegr$new(des, model_formula = ~ x, verbose = FALSE, max_abs_reasonable_coef = 10)
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
	est <- inf$compute_estimate_with_bootstrap_weights(rep(1, n), estimate_only = TRUE)
	expect_true(is.na(est))
	expect_true(inf$is_nonestimable())
})
