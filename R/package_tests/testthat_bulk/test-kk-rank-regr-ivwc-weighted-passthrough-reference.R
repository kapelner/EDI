library(testthat)
library(EDI)

# InferenceSurvivalKKRankRegrIVWC's compute_estimate_with_bootstrap_weights()
# was previously only ever referenced by name (method-name-inventory checks in
# test-mixin-contracts.R and the migration-golden's legacy/migrated output
# comparison, which does not exercise this specific method) -- never actually
# invoked with genuinely varying weights. This class defines no specialized
# compute_weighted_estimate_ivwc, so it falls through to the shared
# InferenceMixinKKPassThrough generic: a weighted combination of the matched-
# pair diff mean and the reservoir treatment/control mean-diff (globals.R's
# kk_pair_and_reservoir_bootstrap_weights() plus the inline combination logic
# in inference_mixin_kk_passthrough.R). This tests that generic fallback
# formula directly, reading the class's own cached KKstats as the ground truth
# for the match/reservoir partition (not re-deriving the C++ matching
# internals) and independently recomputing the weighted-combination formula
# from scratch.

# v1.0.6-TODO-217 (2026-11-19): that fallback averaged raw survival times
# (replicates near 2.3 for an estimate of 0.94 on one fixture), not this
# log-time-ratio estimator, and is gone. The class now reruns both aftsrr fits
# with the draw's case weights (weights = ), each with its ISMB variance, and
# pools them by inverse variance. The tests below check the halves' point
# estimates against aftgee::aftsrr(weights = ) directly (the rank estimating
# equation is deterministic; only the ISMB variance is a seeded Monte Carlo)
# and the pooling against the halves' recorded variances.

# v1.0.6-TODO-45 (2026-11-17): KK14's match test now uses the published
# T^2 = 1/2 d'S^-1 d (it was twice as strict), so at the default lambda = 0.1
# this seed formed 8 pairs, not the 4 pairs + 16 reservoir subjects (20 blocks)
# the tests below are written for. With two covariates the F(2, .) cutoff near
# 0 scales like lambda, so lambda = 0.05 reproduces the old allocation exactly.
survival_kk_rank_regr_ivwc_fixture <- function(n = 24L, seed = 20260817L, lambda = 0.05) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE, lambda = lambda)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		y_lat <- exp(0.8 - 0.3 * ((w_i + 1) / 2) + 0.15 * X$x1[i]) * stats::rexp(1L)
		cens <- stats::rexp(1L, rate = 0.15)
		if (y_lat <= cens) {
			des$add_one_subject_response(i, y = max(y_lat, 0.05))
		} else {
			des$add_one_subject_response(i, y_L = max(cens, 0.05), y_R = Inf)
		}
	}
	des
}

kk_rank_regr_aftsrr_weighted <- function(time, dead, w, row_weights, id = NULL) {
	dat <- data.frame(y = time, dead = dead, w = w, wt__ = row_weights)
	if (!is.null(id)) {
		dat$id <- id
		fit <- aftgee::aftsrr(survival::Surv(y, dead) ~ w, id = id, data = dat, se = "NULL", B = 0, weights = wt__)
	} else {
		fit <- aftgee::aftsrr(survival::Surv(y, dead) ~ w, data = dat, se = "NULL", B = 0, weights = wt__)
	}
	unname(stats::coef(fit)[["w"]])
}

test_that("a weighted replicate reruns both aftsrr fits with case weights and pools them by inverse variance", {
	skip_if_not_installed("aftgee")
	des <- survival_kk_rank_regr_ivwc_fixture()
	# Treatment only, so each half is a single aftsrr call with no covariate ladder.
	inf <- InferenceSurvivalKKRankRegrIVWC$new(des, model_formula = ~ 1)
	priv <- inf$.__enclos_env__$private
	ctx <- priv$build_bayesian_bootstrap_context()
	priv$current_bayesian_bootstrap_context <- ctx
	expect_identical(ncol(as.matrix(priv$get_X())), 0L)
	set.seed(1)
	wts <- runif(ctx$n_units, 0.5, 2)
	row_weights <- wts[ctx$row_to_unit]

	res <- suppressWarnings(inf$compute_estimate_with_bootstrap_weights(wts, estimate_only = TRUE))
	expect_true(is.finite(res))
	refit <- priv$last_weighted_refit$cached_values
	m <- priv$m
	i_m <- which(m > 0L)
	i_r <- which(m == 0L)
	expect_equal(refit$beta_T_matched,
		kk_rank_regr_aftsrr_weighted(priv$y[i_m], priv$dead[i_m], priv$w[i_m], row_weights[i_m], id = m[i_m]),
		tolerance = 1e-6)
	expect_equal(refit$beta_T_reservoir,
		kk_rank_regr_aftsrr_weighted(priv$y[i_r], priv$dead[i_r], priv$w[i_r], row_weights[i_r]),
		tolerance = 1e-6)
	ssq_m <- refit$ssq_beta_T_matched
	ssq_r <- refit$ssq_beta_T_reservoir
	expect_true(is.finite(ssq_m) && ssq_m > 0 && is.finite(ssq_r) && ssq_r > 0)
	w_star <- ssq_r / (ssq_r + ssq_m)
	expect_equal(res, w_star * refit$beta_T_matched + (1 - w_star) * refit$beta_T_reservoir, tolerance = 1e-10)
})

test_that("constant weights give the point estimate", {
	skip_if_not_installed("aftgee")
	des <- survival_kk_rank_regr_ivwc_fixture()
	inf <- InferenceSurvivalKKRankRegrIVWC$new(des)
	priv <- inf$.__enclos_env__$private
	ctx <- priv$build_bayesian_bootstrap_context()
	priv$current_bayesian_bootstrap_context <- ctx
	est <- suppressWarnings(inf$compute_estimate())
	expect_equal(suppressWarnings(inf$compute_estimate_with_bootstrap_weights(rep(1, ctx$n_units), estimate_only = TRUE)), est, tolerance = 1e-12)
	expect_equal(suppressWarnings(inf$compute_estimate_with_bootstrap_weights(rep(5, ctx$n_units), estimate_only = FALSE)), est, tolerance = 1e-12)
})
