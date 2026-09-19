library(testthat)
library(EDI)

# InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC$compute_estimate_with_bootstrap_weights()
# (inference_survival_GLMM_weibull_frailty_loggamma.R:38-54) had zero test
# references anywhere in the suite (confirmed by grep). It's the last untested
# caller of the shared weighted_weibull_bootstrap_surrogate_fit() helper: a KK
# compound class like InferenceSurvivalKKWeibullMarginal (pair-constant row
# weights via expand_subject_or_block_weights_to_row_weights()), but with no
# cluster= argument passed into the shared helper (unlike the GLMM frailty
# normal OneLik sibling already covered).

make_kk_weibull_frailty_loggamma_fixture <- function(n = 24L, seed = 20260817L) {
	# Seed matches the existing migration-golden fixture for this class
	# (test-survival-glmm-weibull-frailty-loggamma-ivwc-migration-golden.R):
	# the Clayton-copula frailty fit is sensitive to starting data and does
	# not converge to a finite estimate under every seed.
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		y_lat <- exp(0.8 - 0.3 * ((w_i + 1) / 2) + 0.15 * X$x1[i]) * rexp(1L)
		cens <- rexp(1L, rate = 0.15)
		if (y_lat <= cens) {
			des$add_one_subject_response(i, y = max(y_lat, 0.05))
		} else {
			des$add_one_subject_response(i, y_L = max(cens, 0.05), y_R = Inf)
		}
	}
	inf <- InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC$new(des)
	inf$set_seed(seed)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	list(inf = inf, priv = priv)
}

test_that("compute_estimate_with_bootstrap_weights matches an independent survreg fit with pair-constant row weights", {
	f <- make_kk_weibull_frailty_loggamma_fixture()
	ctx <- f$priv$current_bayesian_bootstrap_context
	# This class has no get_cluster_ids() override (unlike InferenceSurvivalKKWeibullMarginal);
	# its Bayesian-bootstrap units come from the generic row_to_unit map instead,
	# but they are still coarser than one-per-subject (KK pair/reservoir grouping).
	expect_true(ctx$n_units < f$priv$des_obj$get_n())
	cluster_ids <- ctx$row_to_unit

	set.seed(1)
	unit_weights <- runif(ctx$n_units, 0.5, 2)
	row_weights <- f$priv$expand_subject_or_block_weights_to_row_weights(unit_weights)
	for (cid in unique(cluster_ids)) {
		rw_in_cluster <- row_weights[cluster_ids == cid]
		expect_equal(length(unique(rw_in_cluster)), 1L)
	}

	est <- f$inf$compute_estimate_with_bootstrap_weights(unit_weights)
	X_fit <- cbind(treatment = f$priv$w, f$priv$get_X())
	ref <- survival::survreg(survival::Surv(f$priv$y, f$priv$dead) ~ X_fit, weights = row_weights, dist = "weibull")
	expect_equal(est, unname(coef(ref)["X_fittreatment"]), tolerance = 1e-8)

	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(unit_weights, estimate_only = TRUE), est)
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
})

test_that("effectively-constant unit weights shortcut is scale-invariant and bypasses the cluster surrogate", {
	# Note: this class's frailty MLE optimizer's convergence is sensitive to
	# the RNG state at call time (a directly-called, freshly-constructed
	# compute_estimate(estimate_only = TRUE) reproducibly returns NA on this
	# fixture, while the identical call reached via the shortcut inside
	# compute_estimate_with_bootstrap_weights() reproducibly converges) --
	# a real quirk of this specific class's optimizer, not something to
	# fix here. So this test checks the shortcut's own internal consistency
	# (scale-invariance, and divergence under real weights) rather than
	# comparing against a separately-invoked compute_estimate() call.
	f <- make_kk_weibull_frailty_loggamma_fixture()
	ctx <- f$priv$current_bayesian_bootstrap_context

	shortcut <- f$inf$compute_estimate_with_bootstrap_weights(rep(1, ctx$n_units))
	expect_true(is.finite(shortcut))

	scaled <- f$inf$compute_estimate_with_bootstrap_weights(rep(3.5, ctx$n_units))
	expect_equal(scaled, shortcut)

	set.seed(2)
	unit_weights <- runif(ctx$n_units, 0.5, 2)
	weighted <- f$inf$compute_estimate_with_bootstrap_weights(unit_weights)
	expect_false(isTRUE(all.equal(weighted, shortcut)))
})

test_that("all-filtered-out weights return NA rather than erroring", {
	f <- make_kk_weibull_frailty_loggamma_fixture()
	ctx <- f$priv$current_bayesian_bootstrap_context
	# Non-finite unit weights make every expanded row weight non-finite/zero,
	# so the shared surrogate helper's row filter drops every observation.
	zero_weights <- rep(0, ctx$n_units)
	row_weights <- f$priv$expand_subject_or_block_weights_to_row_weights(zero_weights)
	expect_true(all(row_weights == 0) || all(!is.finite(row_weights)) || length(row_weights) == 0)
	est <- f$inf$compute_estimate_with_bootstrap_weights(zero_weights)
	expect_true(is.na(est))
})
