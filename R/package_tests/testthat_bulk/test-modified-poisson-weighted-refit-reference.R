library(testthat)
library(EDI)

# inference_incidence_modified_poisson.R's compute_estimate_with_bootstrap_weights
# was previously only checked with unit weights (rep(1, n)) via the fast-vs-slow
# reusable-worker equivalence test in
# R/EDI/tests/testthat/test-incidence-modified-poisson-bootstrap-fast-path.R --
# never with genuinely varying weights against an independent reference. Verify
# the true weighted-refit numerics.

modified_poisson_fixture <- function(seed) {
	withr::local_seed(seed, .local_envir = parent.frame())
	n <- 80L
	x <- rnorm(n)
	w <- rep(0:1, n / 2)
	y <- rbinom(n, 1, plogis(-1.2 + 0.4 * w + 0.2 * x))
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidModifiedPoisson$new(des, model_formula = ~ x, verbose = FALSE)
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
	list(inf = inf, X = cbind("(Intercept)" = 1, treatment = w, x = x), y = y, n = n)
}

modified_poisson_weighted_ref <- function(f, weights) {
	fit <- suppressWarnings(glm.fit(f$X, f$y, weights = weights, family = poisson(link = "log")))
	unname(fit$coefficients[2])
}

test_that("weighted modified-Poisson refit matches an independent glm.fit(family=poisson(link='log')) reference", {
	f <- modified_poisson_fixture(30021)
	weights <- runif(f$n, 0.5, 2)

	est_pkg <- as.numeric(f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE))
	est_ref <- modified_poisson_weighted_ref(f, weights)
	expect_equal(est_pkg, est_ref, tolerance = 1e-4)
})

test_that("unit-weight refit reproduces compute_estimate()", {
	f <- modified_poisson_fixture(30022)
	unweighted <- as.numeric(f$inf$compute_estimate())
	f2 <- modified_poisson_fixture(30022)
	weighted_unit <- as.numeric(f2$inf$compute_estimate_with_bootstrap_weights(rep(1, f2$n), estimate_only = TRUE))
	expect_equal(weighted_unit, unweighted, tolerance = 1e-6)
})

test_that("weighted refit is scale-invariant to a common weight multiplier", {
	f <- modified_poisson_fixture(30023)
	weights <- runif(f$n, 0.3, 3)
	est1 <- as.numeric(f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE))
	f2 <- modified_poisson_fixture(30023)
	est2 <- as.numeric(f2$inf$compute_estimate_with_bootstrap_weights(5 * weights, estimate_only = TRUE))
	expect_equal(est2, est1, tolerance = 1e-4)
})

test_that("estimate_only=FALSE computes the weighted robust SE and TRUE skips it", {
	f <- modified_poisson_fixture(30024)
	weights <- runif(f$n, 0.6, 1.8)
	est_false <- as.numeric(f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE))
	se <- f$inf$.__enclos_env__$private$weighted_refit_se()
	mu <- exp(drop(f$X %*% coef(glm.fit(f$X, f$y, weights = weights, family = poisson(link = "log")))))
	bread <- solve(crossprod(f$X, f$X * (weights * mu)))
	meat <- crossprod(f$X, f$X * (weights * (f$y - mu)^2))
	se_ref <- sqrt((bread %*% meat %*% bread)[2L, 2L])
	expect_equal(se, se_ref, tolerance = 1e-6)

	f2 <- modified_poisson_fixture(30024)
	est_true <- as.numeric(f2$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE))
	expect_equal(est_false, est_true, tolerance = 1e-8)
	expect_true(is.na(f2$inf$.__enclos_env__$private$weighted_refit_se()))

	est_ref <- modified_poisson_weighted_ref(f, weights)
	expect_equal(est_false, est_ref, tolerance = 1e-4)
})

test_that("an all-zero-weight refit degenerates to a finite zero estimate rather than erroring or going nonestimable", {
	# The weighted Poisson working-likelihood with all-zero weights is flat at
	# beta = 0; fast_poisson_regression_weighted_cpp converges there rather than
	# failing the reasonableness check, unlike a genuinely unreasonable fit.
	f <- modified_poisson_fixture(30025)
	est <- f$inf$compute_estimate_with_bootstrap_weights(rep(0, f$n), estimate_only = TRUE)
	expect_equal(as.numeric(est), 0, tolerance = 1e-8)
	expect_false(f$inf$.__enclos_env__$private$weighted_refit_is_nonestimable())
})
