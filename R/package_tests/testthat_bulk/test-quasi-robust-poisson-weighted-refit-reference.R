library(testthat)
library(EDI)

# InferenceCountQuasiPoisson and InferenceCountRobustPoisson's
# compute_estimate_with_bootstrap_weights() (weighted point estimate + a
# per-replicate SE fixed 2026-09-07, per each class's own doc comment) had no
# test anywhere checking the fixed variance formula against an independent
# reference -- test-quasi-robust-migration-baseline.R only exercises the
# unweighted compute_estimate() path via migration equivalence, and
# test-count-model-and-bootstrap-contracts.R only checks testing-type
# restrictions on these two classes.

make_quasi_robust_poisson_fixture <- function(seed = 20260918L, n = 60L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", seed = seed)
	w_actual <- numeric(n)
	for (i in seq_len(n)) {
		w_actual[i] <- des$add_one_subject_to_experiment_and_assign(data.frame(x = x[i]))
	}
	mu_true <- exp(0.5 + 0.4 * w_actual + 0.2 * x)
	y <- rpois(n, mu_true)
	des$add_all_subject_responses(as.integer(y))
	list(des = des, X = cbind(1, w_actual, x), y = y)
}

prime_bootstrap_context <- function(inf, n) {
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
	inf
}

test_that("InferenceCountQuasiPoisson weighted refit matches an independent weighted Pearson-dispersion-scaled fit", {
	f <- make_quasi_robust_poisson_fixture()
	n <- nrow(f$X)
	inf <- InferenceCountQuasiPoisson$new(f$des, model_formula = ~x, verbose = FALSE)
	prime_bootstrap_context(inf, n)

	weights <- sample(c(0.5, 1, 1.5, 2), n, replace = TRUE)
	est <- inf$compute_estimate_with_bootstrap_weights(weights)
	se <- inf$.__enclos_env__$private$weighted_refit_se()

	fit <- glm.fit(f$X, f$y, weights = weights, family = poisson())
	mu_hat <- fit$fitted.values
	df_resid <- n - ncol(f$X)
	dispersion <- sum(weights * (f$y - mu_hat)^2 / mu_hat) / df_resid
	XtWX <- t(f$X) %*% diag(weights * mu_hat) %*% f$X
	se_ref <- sqrt(dispersion * solve(XtWX)[2, 2])

	expect_equal(est, unname(fit$coefficients[2]), tolerance = 1e-6)
	expect_equal(se, se_ref, tolerance = 1e-6)

	# Unit weights reproduce the unweighted estimate.
	inf2 <- InferenceCountQuasiPoisson$new(f$des, model_formula = ~x, verbose = FALSE)
	prime_bootstrap_context(inf2, n)
	expect_equal(unname(inf2$compute_estimate_with_bootstrap_weights(rep(1, n))), unname(inf2$compute_estimate()), tolerance = 1e-8)

	# estimate_only skips the dispersion-correction computation.
	inf3 <- InferenceCountQuasiPoisson$new(f$des, model_formula = ~x, verbose = FALSE)
	prime_bootstrap_context(inf3, n)
	inf3$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)
	expect_true(is.na(inf3$.__enclos_env__$private$weighted_refit_se()))

	# The point estimate (not its dispersion-scaled SE) is invariant to a common weight scale.
	inf4 <- InferenceCountQuasiPoisson$new(f$des, model_formula = ~x, verbose = FALSE)
	prime_bootstrap_context(inf4, n)
	est_scaled <- inf4$compute_estimate_with_bootstrap_weights(7 * weights)
	expect_equal(est_scaled, est, tolerance = 1e-6)
})

test_that("InferenceCountRobustPoisson weighted refit matches an independent weighted Huber-White sandwich", {
	f <- make_quasi_robust_poisson_fixture()
	n <- nrow(f$X)
	inf <- InferenceCountRobustPoisson$new(f$des, model_formula = ~x, verbose = FALSE)
	prime_bootstrap_context(inf, n)

	weights <- sample(c(0.5, 1, 1.5, 2), n, replace = TRUE)
	est <- inf$compute_estimate_with_bootstrap_weights(weights)
	se <- inf$.__enclos_env__$private$weighted_refit_se()

	fit <- glm.fit(f$X, f$y, weights = weights, family = poisson())
	mu_hat <- fit$fitted.values
	XtWX <- t(f$X) %*% diag(weights * mu_hat) %*% f$X
	bread <- solve(XtWX)
	resid_w <- (f$y - mu_hat) * sqrt(weights)
	meat <- t(f$X) %*% diag(resid_w^2) %*% f$X
	se_ref <- sqrt((bread %*% meat %*% bread)[2, 2])

	expect_equal(est, unname(fit$coefficients[2]), tolerance = 1e-6)
	expect_equal(se, se_ref, tolerance = 1e-6)

	# Unit weights reproduce the unweighted estimate.
	inf2 <- InferenceCountRobustPoisson$new(f$des, model_formula = ~x, verbose = FALSE)
	prime_bootstrap_context(inf2, n)
	expect_equal(unname(inf2$compute_estimate_with_bootstrap_weights(rep(1, n))), unname(inf2$compute_estimate()), tolerance = 1e-8)

	# estimate_only skips the sandwich-variance computation.
	inf3 <- InferenceCountRobustPoisson$new(f$des, model_formula = ~x, verbose = FALSE)
	prime_bootstrap_context(inf3, n)
	inf3$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)
	expect_true(is.na(inf3$.__enclos_env__$private$weighted_refit_se()))

	# All-zero weights degenerate to a zero treatment coefficient rather than
	# NA -- fast_poisson_regression_weighted_cpp's IRLS still "converges"
	# trivially when every observation is dropped by a zero weight.
	inf4 <- InferenceCountRobustPoisson$new(f$des, model_formula = ~x, verbose = FALSE)
	prime_bootstrap_context(inf4, n)
	expect_equal(inf4$compute_estimate_with_bootstrap_weights(rep(0, n)), 0)
})
