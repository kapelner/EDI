library(testthat)
library(EDI)

# InferenceOrdinalPropOddsRegr$compute_estimate_with_bootstrap_weights()
# (used by the Bayesian bootstrap and related weighted-resampling machinery)
# was fixed 2026-09-07 for two bugs: wrong treatment-coefficient column when
# covariates are present, and the weighted SE always discarded to NA. Existing
# coverage (migration-golden legacy-vs-migrated equivalence, smoke-level
# Bayesian-bootstrap wiring) never checked the fixed behavior against an
# independent reference fit, so verify it here.

prop_odds_fixture <- function(seed = 2026091802L, n = 150L) {
	set.seed(seed)
	x1 <- rnorm(n, sd = 0.6)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	lin <- 0.5 * w + 0.4 * x1
	thresh <- c(-1, 0.3, 1.4)
	p <- plogis(outer(lin, thresh, "-"))
	u <- runif(n)
	y <- 1L + rowSums(u > p)
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalPropOddsRegr$new(des, model_formula = ~x1, verbose = FALSE)
	private <- inf$.__enclos_env__$private
	private$current_bayesian_bootstrap_context <- private$build_bayesian_bootstrap_context()
	list(inf = inf, private = private, y = y, w = w, x1 = x1, n = n)
}

prop_odds_polr_reference <- function(y, w, x1, weights) {
	dat <- data.frame(y = ordered(y, levels = sort(unique(y))), treatment = w, x1 = x1)
	fit <- suppressWarnings(MASS::polr(y ~ treatment + x1, data = dat, weights = weights, Hess = TRUE))
	list(est = unname(coef(fit)["treatment"]), se = unname(sqrt(diag(vcov(fit)))["treatment"]))
}

test_that("weighted refit matches an independent MASS::polr fit, including the fixed treatment-column indexing and SE wiring", {
	f <- prop_odds_fixture()
	weights <- runif(f$n, 0.5, 1.5)

	est <- f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE)
	ref <- prop_odds_polr_reference(f$y, f$w, f$x1, weights)

	expect_equal(est, ref$est, tolerance = 1e-4)
	expect_equal(f$private$cached_values$beta_hat_T, ref$est, tolerance = 1e-4)
	expect_equal(f$private$cached_values$s_beta_hat_T, ref$se, tolerance = 1e-4)
})

test_that("estimate_only = TRUE skips the SE computation but keeps the point estimate", {
	f <- prop_odds_fixture()
	weights <- runif(f$n, 0.5, 1.5)

	est_only <- f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)
	ref <- prop_odds_polr_reference(f$y, f$w, f$x1, weights)

	expect_equal(est_only, ref$est, tolerance = 1e-4)
	expect_true(is.na(f$private$cached_values$s_beta_hat_T))
})

test_that("unit weights reproduce the unweighted compute_estimate() value", {
	f <- prop_odds_fixture()
	unweighted <- f$inf$compute_estimate(estimate_only = TRUE)

	f2 <- prop_odds_fixture()
	unit_weighted <- f2$inf$compute_estimate_with_bootstrap_weights(rep(1, f2$n), estimate_only = TRUE)

	expect_equal(unit_weighted, unweighted, tolerance = 1e-6)
})

test_that("missing bootstrap weights are rejected by the shared validation contract", {
	f <- prop_odds_fixture()
	w_bad <- rep(1, f$n)
	w_bad[1] <- NA_real_

	expect_error(
		f$inf$compute_estimate_with_bootstrap_weights(w_bad, estimate_only = FALSE),
		"missing values"
	)
})

test_that("scale of the weights does not change the point estimate", {
	f <- prop_odds_fixture()
	weights <- runif(f$n, 0.5, 1.5)

	est <- f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)

	f2 <- prop_odds_fixture()
	est_scaled <- f2$inf$compute_estimate_with_bootstrap_weights(7 * weights, estimate_only = TRUE)

	expect_equal(est_scaled, est, tolerance = 1e-4)
})
