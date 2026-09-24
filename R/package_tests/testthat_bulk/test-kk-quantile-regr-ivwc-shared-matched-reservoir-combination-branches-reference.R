library(testthat)
library(EDI)

# The shared abstract source behind InferencePropKKQuantileRegrIVWC and InferenceContinKKQuantileRegrIVWC
# (inference_all_KK_quantile_regr_ivwc_abstract.R) combines a quantile-regression fit on the matched
# pairs (quantile_for_matched_pairs(), returning list(beta=, ssq=)) and a quantile-regression fit on
# the reservoir (quantile_for_reservoir()) via inverse-variance weighting -- the same IVWC-combination
# pattern already closed this stretch for several sibling classes. Its "neither succeeds" branch
# leaves beta_hat_T/s_beta_hat_T as raw NA_real_ (no cache_nonestimable_estimate() call, unlike the
# richer LWA-Cox/rank-regr siblings). None of shared()'s 4 branches had a test reference anywhere
# (confirmed via grep for quantile_for_matched_pairs/quantile_for_reservoir across both concrete
# classes' reference files, all of which target compute_estimate_with_bootstrap_weights() or
# migration parity instead). Reached via InferencePropKKQuantileRegrIVWC (which has fewer existing
# references than its Contin sibling) by unlockBinding-replacing quantile_for_matched_pairs()/
# quantile_for_reservoir() with stubs returning exact beta/ssq values, independent of the real
# quantile-regression machinery (already tested elsewhere) -- this exercises the shared abstract
# source both concrete classes compose.

mk_fixture <- function(seed, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "proportion", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- plogis(rnorm(n) + 0.5 * w)
	des$add_all_subject_responses(y)
	inf <- InferencePropKKQuantileRegrIVWC$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

set_mocks <- function(priv, beta_m, ssq_m, beta_r, ssq_r) {
	unlockBinding("quantile_for_matched_pairs", priv)
	priv$quantile_for_matched_pairs <- function() list(beta = beta_m, ssq = ssq_m)
	unlockBinding("quantile_for_reservoir", priv)
	priv$quantile_for_reservoir <- function() list(beta = beta_r, ssq = ssq_r)
}

test_that("only the matched-pairs piece succeeds: beta_hat_T = beta_m, s_beta_hat_T = sqrt(ssq_m)", {
	f <- mk_fixture(1L)
	set_mocks(f$priv, 1.2, 0.2, NA_real_, NA_real_)
	f$priv$shared()
	expect_equal(f$priv$cached_values$beta_hat_T, 1.2)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.2))
})

test_that("only the reservoir piece succeeds: beta_hat_T = beta_r, s_beta_hat_T = sqrt(ssq_r)", {
	f <- mk_fixture(2L)
	set_mocks(f$priv, NA_real_, NA_real_, 0.8, 0.5)
	f$priv$shared()
	expect_equal(f$priv$cached_values$beta_hat_T, 0.8)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.5))
})

test_that("both pieces succeed: the IVWC combination matches the closed-form weighted formula exactly", {
	f <- mk_fixture(3L)
	set_mocks(f$priv, 1.2, 0.2, 0.8, 0.5)
	f$priv$shared()
	w_star <- 0.5 / (0.5 + 0.2)
	expect_equal(f$priv$cached_values$beta_hat_T, w_star * 1.2 + (1 - w_star) * 0.8)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.2 * 0.5 / (0.2 + 0.5)))
})

test_that("neither piece succeeds: beta_hat_T and s_beta_hat_T are NA_real_", {
	f <- mk_fixture(4L)
	set_mocks(f$priv, NA_real_, NA_real_, NA_real_, NA_real_)
	f$priv$shared()
	expect_true(is.na(f$priv$cached_values$beta_hat_T))
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
})
