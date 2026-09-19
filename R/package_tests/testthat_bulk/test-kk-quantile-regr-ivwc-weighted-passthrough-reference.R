library(testthat)
library(EDI)

# InferenceContinKKQuantileRegrIVWC's compute_estimate_with_bootstrap_weights()
# was previously only referenced in a migration-golden legacy/migrated output
# comparison that never exercises this specific method (grep confirms zero
# hits for compute_estimate_with_bootstrap_weights in
# test-kk-quantile-regr-ivwc-migration-golden.R). No registered class defines
# a specialized private$compute_weighted_estimate_ivwc anywhere in the
# package (confirmed via repo-wide grep), so this class falls through to the
# shared generic fallback in inference_all_abstract_KK_passthrough_compound.R:
# a weighted combination of the matched-pair diff mean and the reservoir
# treatment/control mean-diff, using the fixed w_star from the original
# (unweighted) quantile-regression fit -- not a re-fit quantreg::rq() call.
# This tests that generic fallback formula directly, reading the class's own
# cached KKstats as ground truth for the match/reservoir partition.

kk_quantile_regr_ivwc_fixture <- function(n = 24L, seed = 20260918L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	y <- numeric(n)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		y[i] <- 0.8 - 0.3 * ((w_i + 1) / 2) + 0.15 * X$x1[i] + rnorm(1)
	}
	des$add_all_subject_responses(y)
	des
}

kk_quantile_regr_weighted_reference <- function(priv, row_weights) {
	m <- priv$m
	stats <- priv$cached_values$KKstats
	pair_ids <- sort(unique(m[m > 0L]))
	pair_w <- vapply(pair_ids, function(pid) mean(row_weights[which(m == pid)]), numeric(1))
	d_bar_w <- if (length(pair_w) > 0) sum(stats$y_matched_diffs * pair_w) / sum(pair_w) else NA_real_
	res_idx <- which(m == 0L)
	yr <- stats$y_reservoir
	wr <- stats$w_reservoir
	rw <- row_weights[res_idx]
	num_t <- sum(yr[wr == 1] * rw[wr == 1], na.rm = TRUE)
	den_t <- sum(rw[wr == 1], na.rm = TRUE)
	num_c <- sum(yr[wr == 0] * rw[wr == 0], na.rm = TRUE)
	den_c <- sum(rw[wr == 0], na.rm = TRUE)
	r_bar_w <- if (is.finite(den_t) && den_t > 0 && is.finite(den_c) && den_c > 0) {
		num_t / den_t - num_c / den_c
	} else NA_real_
	w_star <- stats$w_star
	if (is.null(w_star) || is.na(w_star)) {
		if (!is.na(d_bar_w)) return(d_bar_w)
		return(r_bar_w)
	}
	w_star * d_bar_w + (1 - w_star) * r_bar_w
}

test_that("compute_estimate_with_bootstrap_weights matches the from-scratch weighted passthrough formula", {
	des <- kk_quantile_regr_ivwc_fixture()
	inf <- InferenceContinKKQuantileRegrIVWC$new(des)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	priv$compute_basic_match_data()

	n_pairs <- length(unique(priv$m[priv$m > 0L]))
	n_reservoir <- sum(priv$m == 0L)
	total_units <- n_pairs + n_reservoir

	set.seed(1)
	wts_block <- runif(total_units, 0.5, 2)
	row_weights <- priv$expand_subject_or_block_weights_to_row_weights(wts_block)
	expect_length(row_weights, 24L)

	res <- inf$compute_estimate_with_bootstrap_weights(wts_block, estimate_only = TRUE)
	expected <- kk_quantile_regr_weighted_reference(priv, row_weights)
	expect_equal(res, expected, tolerance = 1e-10)
	expect_true(is.finite(res))
})

test_that("constant weights are scale-invariant and estimate_only has no effect on this fallback path", {
	des <- kk_quantile_regr_ivwc_fixture()
	inf <- InferenceContinKKQuantileRegrIVWC$new(des)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	priv$compute_basic_match_data()
	total_units <- length(unique(priv$m[priv$m > 0L])) + sum(priv$m == 0L)

	res_unit <- inf$compute_estimate_with_bootstrap_weights(rep(1, total_units), estimate_only = TRUE)
	res_scaled <- inf$compute_estimate_with_bootstrap_weights(rep(5, total_units), estimate_only = TRUE)
	expect_equal(res_scaled, res_unit, tolerance = 1e-10)

	# Documented note, not a bug: this generic passthrough fallback never
	# reads its estimate_only argument, matching the pattern already
	# confirmed on the analogous KK-RankRegr-IVWC survival sibling.
	res_true <- inf$compute_estimate_with_bootstrap_weights(rep(1, total_units), estimate_only = TRUE)
	res_false <- inf$compute_estimate_with_bootstrap_weights(rep(1, total_units), estimate_only = FALSE)
	expect_identical(res_true, res_false)
})

test_that("all-zero weights degrade gracefully to a non-finite result rather than erroring", {
	des <- kk_quantile_regr_ivwc_fixture()
	inf <- InferenceContinKKQuantileRegrIVWC$new(des)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	priv$compute_basic_match_data()
	total_units <- length(unique(priv$m[priv$m > 0L])) + sum(priv$m == 0L)

	res <- inf$compute_estimate_with_bootstrap_weights(rep(0, total_units), estimate_only = TRUE)
	expect_false(is.finite(res))
})

test_that("reweighting only the reservoir arm changes the estimate while leaving pair weights untouched", {
	des <- kk_quantile_regr_ivwc_fixture()
	inf <- InferenceContinKKQuantileRegrIVWC$new(des)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	priv$compute_basic_match_data()

	m <- priv$m
	pair_ids <- sort(unique(m[m > 0L]))
	n_pairs <- length(pair_ids)
	n_reservoir <- sum(m == 0L)

	base_wts <- rep(1, n_pairs + n_reservoir)
	skewed_wts <- base_wts
	skewed_wts[(n_pairs + 1):length(skewed_wts)] <- runif(n_reservoir, 3, 5)

	res_base <- inf$compute_estimate_with_bootstrap_weights(base_wts, estimate_only = TRUE)
	res_skewed <- inf$compute_estimate_with_bootstrap_weights(skewed_wts, estimate_only = TRUE)
	row_weights_skewed <- priv$expand_subject_or_block_weights_to_row_weights(skewed_wts)
	expected_skewed <- kk_quantile_regr_weighted_reference(priv, row_weights_skewed)

	expect_equal(res_skewed, expected_skewed, tolerance = 1e-10)
	expect_false(isTRUE(all.equal(res_skewed, res_base, tolerance = 1e-8)))
})
