library(testthat)
library(EDI)

# TODO-181 (b) (v1.0.5): InferenceIncidBinomialIdentityRiskDiff, incidence calibration rep 5, `~.`:
# the null refit at delta = 0 ran the IRLS in src/fast_log_binomial_regression.cpp into the
# 100-iteration cap (hit_iteration_cap = TRUE) with interior fitted mu (0.083 .. 0.765). Not a
# boundary: the identity-link Fisher-scoring step overshot with a near -1 contraction factor, so
# the iterates zigzagged around the MLE, every full step was accepted by the line search (the
# log-likelihood rose a little each time), and the relative change was still ~1e-4 at iteration
# 100. The score p-value at 0 was NA on a fresh object. Fix: from iteration 20 on, a step that
# reverses the previous accepted step keeps being halved while the log-likelihood strictly
# improves (cycle guard). Fits that converge within 20 iterations are bit-identical.

todo181_incidence_calibration_rep <- function(r) {
	# Seed formula of cal_run_rep() in R/package_tests/calibration/calibration_fast_tier_common.R
	# (cal_rt_index("incidence") = 2, n = 200, null effect, DesignFixedBernoulli).
	set.seed(1e6 * 2L + 7L * 200L + r)
	X <- data.frame(x1 = stats::rnorm(200), x2 = stats::rbinom(200, 1L, 0.5))
	des <- DesignFixedBernoulli$new(n = 200, response_type = "incidence")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(ys = stats::rbinom(200, 1L, stats::plogis(-0.5 + 0.5 * X$x1 + 0.5 * X$x2)))
	des
}

identity_binomial_free_score <- function(X, y, b, free) {
	mu <- as.numeric(X %*% b)
	as.numeric(crossprod(X[, free, drop = FALSE], (y - mu) / (mu * (1 - mu))))
}

test_that("rep 5 `~.`: the null refit at delta = 0 converges at an interior MLE instead of cycling into the cap", {
	o <- InferenceIncidBinomialIdentityRiskDiff$new(todo181_incidence_calibration_rep(5L))
	spec <- o$.__enclos_env__$private$get_likelihood_test_spec()
	X <- spec$X; y <- spec$y; j <- spec$j
	free <- setdiff(seq_len(ncol(X)), j)
	fits <- list(
		cold = fast_identity_binomial_regression_cpp(X = X, y = y, fixed_idx = j, fixed_values = 0),
		warm = fast_identity_binomial_regression_cpp(X = X, y = y, warm_start_beta = as.numeric(spec$full_fit$b), fixed_idx = j, fixed_values = 0),
		weighted = fast_identity_binomial_regression_weighted_cpp(X = X, y = y, weights = rep(1, length(y)), fixed_idx = j, fixed_values = 0)
	)
	for (nm in names(fits)) {
		f <- fits[[nm]]
		expect_true(f$converged, info = nm)
		expect_false(f$hit_iteration_cap, info = nm)
		expect_lt(f$num_iter, 100L)
		expect_identical(as.integer(f$n_active_bounds), 0L)
		mu <- as.numeric(X %*% f$b)
		expect_true(all(mu > 0.05 & mu < 0.95), info = nm)
		# a genuine interior stationary point: the free-parameter score vanishes
		expect_lt(max(abs(identity_binomial_free_score(X, y, f$b, free))), 1e-3)
	}
	expect_equal(as.numeric(fits$cold$b), as.numeric(fits$warm$b), tolerance = 1e-5)
})

test_that("rep 5 `~.`: the score p-value at 0 is finite on a fresh object (was NA)", {
	o <- InferenceIncidBinomialIdentityRiskDiff$new(todo181_incidence_calibration_rep(5L))
	p <- o$compute_score_two_sided_pval(0)
	expect_true(is.finite(p))
	expect_equal(p, 0.5732743, tolerance = 1e-4)
})

test_that("the full-data fit converges within the first 20 iterations, before the cycle guard can engage", {
	o <- InferenceIncidBinomialIdentityRiskDiff$new(todo181_incidence_calibration_rep(5L))
	spec <- o$.__enclos_env__$private$get_likelihood_test_spec()
	f <- fast_identity_binomial_regression_cpp(X = spec$X, y = spec$y)
	expect_true(f$converged)
	expect_lte(f$num_iter, 20L)
})
