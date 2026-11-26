library(testthat)
library(EDI)

# InferenceContinKKOLSIVWC's compute_estimate_with_bootstrap_weights() was
# previously only ever referenced by name (method-name-inventory checks in
# test-mixin-contracts.R and the migration-golden's legacy/migrated output
# comparison, which does not exercise this specific method) -- never actually
# invoked with genuinely varying weights. This class defines no specialized
# compute_weighted_estimate_ivwc, so it falls through to the shared
# InferenceMixinKKPassThrough generic: a weighted combination of the matched-
# pair diff mean and the reservoir treatment/control mean-diff. This tests
# that generic fallback formula directly, reading the class's own cached
# KKstats as the ground truth for the match/reservoir partition and
# independently recomputing the weighted-combination formula from scratch --
# same pattern as the already-covered KKRankRegrIVWC/KKQuantileRegrIVWC
# siblings.
#
# v1.0.6-TODO-158 (2026-11-19): that fallback was an unadjusted mean
# difference pooled with the observed w_star, not this covariate-adjusted
# estimator, and is gone. The class now refits both halves by weighted least
# squares (HC2 variances) and pools them by inverse variance. The tests below
# check the halves against stats::lm.wfit() and the pooling against the
# halves' own variances.

# v1.0.6-TODO-10 (2026-11-17): KK14's match test now uses the published
# T^2 = 1/2 d'S^-1 d (it was twice as strict), so at the default lambda = 0.1
# this seed formed 8 pairs, not the 4 pairs + 16 reservoir subjects (20 blocks)
# the tests below are written for. With two covariates the F(2, .) cutoff near
# 0 scales like lambda, so lambda = 0.05 reproduces the old allocation exactly.
contin_kk_ols_ivwc_fixture <- function(n = 24L, seed = 20260817L, lambda = 0.05) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE, lambda = lambda)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		des$add_one_subject_response(i, 0.6 * ((w_i + 1) / 2) + 0.3 * X$x1[i] + rnorm(1L, sd = 0.8))
	}
	des
}

kk_ols_ivwc_weighted_halves_reference <- function(priv, row_weights) {
	m <- priv$m
	stats <- priv$cached_values$KKstats
	pair_ids <- sort(unique(m[m > 0L]))
	pair_w <- vapply(pair_ids, function(pid) mean(row_weights[which(m == pid)]), numeric(1))
	Xd <- as.matrix(stats$X_matched_diffs)
	beta_m <- stats::lm.wfit(cbind(1, Xd), stats$y_matched_diffs, w = pair_w)$coefficients[[1L]]
	res_idx <- which(m == 0L)
	beta_r <- stats::lm.wfit(cbind(1, stats$w_reservoir, as.matrix(stats$X_reservoir)), stats$y_reservoir,
		w = row_weights[res_idx])$coefficients[[2L]]
	c(beta_m = beta_m, beta_r = beta_r)
}

test_that("a weighted replicate refits both halves by weighted least squares and pools them by inverse variance", {
	des <- contin_kk_ols_ivwc_fixture()
	inf <- InferenceContinKKOLSIVWC$new(des)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	priv$compute_basic_match_data()

	# 4 matched pairs + 16 reservoir singletons in this fixture -> 20 bootstrap units.
	set.seed(1)
	wts_block <- runif(20, 0.5, 2)
	row_weights <- priv$expand_subject_or_block_weights_to_row_weights(wts_block)
	expect_length(row_weights, 24L)

	res <- inf$compute_estimate_with_bootstrap_weights(wts_block, estimate_only = TRUE)
	expect_true(is.finite(res))
	refit <- priv$last_weighted_refit$cached_values
	ref <- kk_ols_ivwc_weighted_halves_reference(priv, row_weights)
	expect_equal(refit$beta_T_matched, ref[["beta_m"]], tolerance = 1e-8)
	expect_equal(refit$beta_T_reservoir, ref[["beta_r"]], tolerance = 1e-8)
	ssq_m <- refit$ssq_beta_T_matched
	ssq_r <- refit$ssq_beta_T_reservoir
	expect_true(is.finite(ssq_m) && ssq_m > 0 && is.finite(ssq_r) && ssq_r > 0)
	w_star <- ssq_r / (ssq_r + ssq_m)
	expect_equal(res, w_star * ref[["beta_m"]] + (1 - w_star) * ref[["beta_r"]], tolerance = 1e-8)
})

test_that("constant weights give the point estimate, and the refit is scale-invariant", {
	des <- contin_kk_ols_ivwc_fixture()
	inf <- InferenceContinKKOLSIVWC$new(des)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()

	est <- inf$compute_estimate()
	expect_equal(inf$compute_estimate_with_bootstrap_weights(rep(1, 20), estimate_only = TRUE), est, tolerance = 1e-12)
	expect_equal(inf$compute_estimate_with_bootstrap_weights(rep(5, 20), estimate_only = FALSE), est, tolerance = 1e-12)
	set.seed(2)
	w <- runif(20, 0.5, 2)
	expect_equal(inf$compute_estimate_with_bootstrap_weights(5 * w, estimate_only = TRUE),
		inf$compute_estimate_with_bootstrap_weights(w, estimate_only = TRUE), tolerance = 1e-10)
	# Near-uniform weights take the weighted path and still reproduce the estimate.
	expect_equal(inf$compute_estimate_with_bootstrap_weights(1 + 1e-8 * w, estimate_only = TRUE), est, tolerance = 1e-6)
})

test_that("all-zero weights degrade gracefully to a non-finite result rather than erroring", {
	des <- contin_kk_ols_ivwc_fixture()
	inf <- InferenceContinKKOLSIVWC$new(des)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()

	res <- suppressWarnings(inf$compute_estimate_with_bootstrap_weights(rep(0, 20), estimate_only = TRUE))
	expect_false(is.finite(res))
})

test_that("reweighting only the reservoir arm moves only the reservoir half", {
	des <- contin_kk_ols_ivwc_fixture()
	inf <- InferenceContinKKOLSIVWC$new(des)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	priv$compute_basic_match_data()

	m <- priv$m
	n_pairs <- length(unique(m[m > 0L]))
	n_reservoir <- sum(m == 0L)
	expect_equal(n_pairs, 4L)
	expect_equal(n_reservoir, 16L)

	# Units are numbered in order of first appearance, so find the reservoir units.
	ctx <- priv$current_bayesian_bootstrap_context
	reservoir_units <- unique(ctx$row_to_unit[m == 0L])
	expect_length(reservoir_units, n_reservoir)
	set.seed(4)
	skewed_wts <- rep(1, ctx$n_units)
	skewed_wts[reservoir_units] <- runif(n_reservoir, 3, 5)
	res_skewed <- inf$compute_estimate_with_bootstrap_weights(skewed_wts, estimate_only = TRUE)
	refit <- priv$last_weighted_refit$cached_values
	inf$compute_estimate()
	observed <- priv$cached_values
	expect_equal(refit$beta_T_matched, observed$beta_T_matched, tolerance = 1e-10)
	expect_false(isTRUE(all.equal(refit$beta_T_reservoir, observed$beta_T_reservoir, tolerance = 1e-8)))
	expect_false(isTRUE(all.equal(res_skewed, inf$compute_estimate(), tolerance = 1e-8)))
})
