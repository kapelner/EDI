library(testthat)
library(EDI)

# inference_incidence_log_binomial.R's compute_estimate_with_bootstrap_weights
# was previously only checked with unit weights (rep(1, n)) against the
# class's own compute_estimate() cache -- never with actually-varying weights
# against an independent reference (R/EDI/tests/testthat/test-bayesian-bootstrap.R
# only exercises the rep(1, n) path). Verify the true weighted-refit numerics.

log_binomial_fixture <- function(seed) {
	withr::local_seed(seed, .local_envir = parent.frame())
	n <- 80L
	x <- rnorm(n)
	w <- rep(0:1, n / 2)
	y <- rbinom(n, 1, plogis(-1.2 + 0.4 * w + 0.2 * x))
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidLogBinomial$new(des, model_formula = ~ x, verbose = FALSE)
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
	list(inf = inf, X = cbind("(Intercept)" = 1, treatment = w, x = x), y = y, n = n)
}

log_binomial_weighted_ref <- function(f, weights) {
	fit <- suppressWarnings(glm.fit(
		f$X, f$y, weights = weights, family = binomial(link = "log"),
		mustart = rep(mean(f$y), f$n)
	))
	unname(fit$coefficients[2])
}

test_that("weighted log-binomial refit matches an independent glm.fit(family=binomial(link='log')) reference", {
	f <- log_binomial_fixture(30011)
	weights <- runif(f$n, 0.5, 2)

	est_pkg <- as.numeric(f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE))
	est_ref <- log_binomial_weighted_ref(f, weights)
	expect_equal(est_pkg, est_ref, tolerance = 1e-4)
})

test_that("unit-weight refit reproduces compute_estimate()", {
	f <- log_binomial_fixture(30012)
	unweighted <- as.numeric(f$inf$compute_estimate())
	f2 <- log_binomial_fixture(30012)
	weighted_unit <- as.numeric(f2$inf$compute_estimate_with_bootstrap_weights(rep(1, f2$n), estimate_only = TRUE))
	expect_equal(weighted_unit, unweighted, tolerance = 1e-6)
})

test_that("weighted refit is scale-invariant to a common weight multiplier", {
	f <- log_binomial_fixture(30013)
	weights <- runif(f$n, 0.3, 3)
	est1 <- as.numeric(f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE))
	f2 <- log_binomial_fixture(30013)
	est2 <- as.numeric(f2$inf$compute_estimate_with_bootstrap_weights(5 * weights, estimate_only = TRUE))
	expect_equal(est2, est1, tolerance = 1e-4)
})

test_that("estimate_only=FALSE populates a finite SE matching the reference sandwich-free Fisher-information inverse", {
	f <- log_binomial_fixture(30014)
	weights <- runif(f$n, 0.6, 1.8)
	est <- as.numeric(f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE))
	se <- f$inf$.__enclos_env__$private$cached_values$s_beta_hat_T
	expect_true(is.finite(se))
	expect_true(se > 0)

	ref_fit <- suppressWarnings(glm.fit(
		f$X, f$y, weights = weights, family = binomial(link = "log"),
		mustart = rep(mean(f$y), f$n)
	))
	# Independent Fisher-information-based SE via the IRLS working weights,
	# a distinct derivation from the package's own fast_log_binomial_regression_weighted_cpp.
	mu <- ref_fit$fitted.values
	W <- weights * mu^2 / (mu * (1 - mu))
	fisher <- t(f$X) %*% diag(W) %*% f$X
	se_ref <- unname(sqrt(diag(solve(fisher)))[2])
	expect_equal(unname(se), se_ref, tolerance = 1e-3)
	expect_equal(est, unname(ref_fit$coefficients[2]), tolerance = 1e-4)
})
