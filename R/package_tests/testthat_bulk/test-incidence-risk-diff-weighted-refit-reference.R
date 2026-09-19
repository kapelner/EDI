library(testthat)
library(EDI)

# inference_incidence_risk_diff.R's compute_estimate_with_bootstrap_weights
# (the hardened-QR weighted linear-probability refit via stats::lm.wfit()) is
# only ever exercised in R/EDI/tests/testthat/test-incid-risk-diff-migration-golden.R
# as a byte-for-byte legacy-body copy inside a generator -- never actually
# called with genuinely varying weights and checked against an independent
# reference. Verify the true weighted-refit numerics here.

risk_diff_fixture <- function(seed) {
	withr::local_seed(seed, .local_envir = parent.frame())
	n <- 60L
	x <- rnorm(n)
	w <- rep(0:1, n / 2)
	y <- as.numeric(0.4 + 0.15 * w + 0.1 * x + rnorm(n, sd = 0.2) > 0.5)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidRiskDiff$new(des, model_formula = ~ x, verbose = FALSE)
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
	list(inf = inf, X = cbind("(Intercept)" = 1, treatment = w, x = x), y = y, n = n)
}

test_that("weighted linear-probability refit matches an independent lm.wfit() reference", {
	f <- risk_diff_fixture(101)
	weights <- runif(f$n, 0.5, 2)

	est_pkg <- as.numeric(f$inf$compute_estimate_with_bootstrap_weights(weights))
	ref <- stats::lm.wfit(f$X, f$y, w = weights)
	est_ref <- unname(ref$coefficients[2])
	expect_equal(est_pkg, est_ref, tolerance = 1e-8)

	# Documented contract: no SE is ever cached for a single bootstrap replicate.
	expect_true(is.na(f$inf$.__enclos_env__$private$cached_values$s_beta_hat_T))
})

test_that("unit weights reproduce the unweighted compute_estimate()", {
	f <- risk_diff_fixture(102)
	unweighted <- as.numeric(f$inf$compute_estimate())
	est_unit <- as.numeric(f$inf$compute_estimate_with_bootstrap_weights(rep(1, f$n)))
	expect_equal(est_unit, unweighted, tolerance = 1e-8)
})

test_that("weighted refit is invariant to a common weight scale multiplier", {
	f <- risk_diff_fixture(103)
	weights <- runif(f$n, 0.3, 3)
	est <- as.numeric(f$inf$compute_estimate_with_bootstrap_weights(weights))
	est_scaled <- as.numeric(f$inf$compute_estimate_with_bootstrap_weights(7 * weights))
	expect_equal(est_scaled, est, tolerance = 1e-8)
})

test_that("all-zero weights leave no positive-weight rows and return NA", {
	f <- risk_diff_fixture(104)
	est <- f$inf$compute_estimate_with_bootstrap_weights(rep(0, f$n))
	expect_true(is.na(est))
})
