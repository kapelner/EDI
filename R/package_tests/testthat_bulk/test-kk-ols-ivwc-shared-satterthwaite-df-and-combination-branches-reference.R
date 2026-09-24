library(testthat)
library(EDI)

# InferenceContinKKOLSIVWC's private shared() (inference_continuous_KK_ols_ivwc.R) combines an OLS
# fit on the matched-pair differences (ols_for_matched_pairs()) and an OLS fit on the reservoir
# (ols_for_reservoir()) via inverse-variance weighting -- the same IVWC-combination pattern already
# closed this stretch for several sibling classes -- but additionally computes a Satterthwaite-
# approximation degrees-of-freedom for the combined estimate via its own private satterthwaite_df()
# helper, which had no test reference anywhere (confirmed via grep), nor did any of shared()'s own
# combination branches: the class's 3 existing references (test-kk-ols-ivwc-weighted-passthrough-
# reference.R, test-full-likelihood-migration-baseline.R, test-mixin-contracts.R) exercise
# compute_estimate_with_bootstrap_weights() and migration parity, never shared()'s own branches or
# satterthwaite_df() directly.
#   satterthwaite_df(var_terms, dfs) = (sum var_terms)^2 / sum(var_terms^2 / dfs), restricted to the
#   finite-and-positive (var_terms, dfs) pairs; NA if none remain.
# Reached by unlockBinding-replacing ols_for_matched_pairs()/ols_for_reservoir() with stubs that set
# exact beta/ssq/df cache values, independent of the real OLS-fitting machinery (already tested
# elsewhere).

mk_fixture <- function(seed, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rnorm(n) + 0.8 * w + 0.3 * X$x1
	des$add_all_subject_responses(y)
	inf <- InferenceContinKKOLSIVWC$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

set_mocks <- function(priv, beta_m, ssq_m, df_m, beta_r, ssq_r, df_r) {
	unlockBinding("ols_for_matched_pairs", priv)
	priv$ols_for_matched_pairs <- function(estimate_only = FALSE) {
		priv$cached_values$beta_T_matched <- beta_m
		priv$cached_values$ssq_beta_T_matched <- ssq_m
		priv$cached_values$df_beta_T_matched <- df_m
	}
	unlockBinding("ols_for_reservoir", priv)
	priv$ols_for_reservoir <- function(estimate_only = FALSE) {
		priv$cached_values$beta_T_reservoir <- beta_r
		priv$cached_values$ssq_beta_T_reservoir <- ssq_r
		priv$cached_values$df_beta_T_reservoir <- df_r
	}
}

test_that("satterthwaite_df() matches the closed-form formula, restricted to finite-and-positive pairs, and is NA when none remain", {
	f <- mk_fixture(1L)
	sw <- f$priv$satterthwaite_df(c(2, 3), c(5, 8))
	ref <- (2 + 3)^2 / (2^2 / 5 + 3^2 / 8)
	expect_equal(sw, ref)

	sw_one_na <- f$priv$satterthwaite_df(c(2, 3), c(5, NA))
	expect_equal(sw_one_na, 5)   # only the (2, 5) term is finite/positive, so it collapses to df_m alone

	sw_all_na <- f$priv$satterthwaite_df(c(NA, NA), c(5, 8))
	expect_true(is.na(sw_all_na))
})

test_that("both pieces succeed: beta_hat_T/s_beta_hat_T match the closed-form IVWC formula, and df matches satterthwaite_df() on the combination's own variance terms", {
	f <- mk_fixture(2L)
	set_mocks(f$priv, 1.2, 0.2, 10, 0.8, 0.5, 15)
	f$priv$shared(estimate_only = FALSE)
	w_star <- 0.5 / (0.5 + 0.2)
	expect_equal(f$priv$cached_values$beta_hat_T, w_star * 1.2 + (1 - w_star) * 0.8)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.2 * 0.5 / (0.2 + 0.5)))
	ref_df <- f$priv$satterthwaite_df(c(w_star^2 * 0.2, (1 - w_star)^2 * 0.5), c(10, 15))
	expect_equal(f$priv$cached_values$df, ref_df)
})

test_that("only the matched-pairs piece succeeds: beta_hat_T = beta_m, s_beta_hat_T = sqrt(ssq_m), df = df_m", {
	f <- mk_fixture(3L)
	set_mocks(f$priv, 1.2, 0.2, 10, NA_real_, NA_real_, NA_real_)
	f$priv$shared(estimate_only = FALSE)
	expect_equal(f$priv$cached_values$beta_hat_T, 1.2)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.2))
	expect_equal(f$priv$cached_values$df, 10)
})

test_that("only the reservoir piece succeeds: beta_hat_T = beta_r, s_beta_hat_T = sqrt(ssq_r), df = df_r", {
	f <- mk_fixture(4L)
	set_mocks(f$priv, NA_real_, NA_real_, NA_real_, 0.8, 0.5, 15)
	f$priv$shared(estimate_only = FALSE)
	expect_equal(f$priv$cached_values$beta_hat_T, 0.8)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.5))
	expect_equal(f$priv$cached_values$df, 15)
})

test_that("neither piece succeeds: beta_hat_T, s_beta_hat_T and df are all NA_real_", {
	f <- mk_fixture(5L)
	set_mocks(f$priv, NA_real_, NA_real_, NA_real_, NA_real_, NA_real_, NA_real_)
	f$priv$shared(estimate_only = FALSE)
	expect_true(is.na(f$priv$cached_values$beta_hat_T))
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
	expect_true(is.na(f$priv$cached_values$df))
})
