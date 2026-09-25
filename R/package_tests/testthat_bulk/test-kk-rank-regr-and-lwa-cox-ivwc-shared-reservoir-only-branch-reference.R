library(testthat)
library(EDI)

# InferenceSurvivalKKRankRegrIVWC and InferenceSurvivalKKLWACoxPHIVWC's private shared() methods
# (inference_survival_KK_rank_regr_ivwc_abstract.R / inference_survival_KK_lwa_cox_ivwc_abstract.R)
# each have a 3-branch fallback ladder (m_ok && r_ok combined / m_ok-only / r_ok-only) before the
# nonestimable-reason guards. This session's own sibling test files
# (test-kk-rank-regr-ivwc-shared-nonestimable-branches-reference.R,
# test-kk-lwa-cox-ivwc-shared-nonestimable-branches-reference.R) already close the "neither usable",
# "combined", and (as a side effect of hitting the extreme-estimate/SE-unavailable guards) the
# m_ok-only branch for both classes -- but every one of their fixtures sets beta_r/ssq_r to
# NA_real_, so the r_ok-only branch (`else if (r_ok)`: beta_hat_T = beta_r, s_beta_hat_T =
# sqrt(ssq_r), with the matched-pairs piece itself unusable) was never actually reached by either
# file (confirmed via reading both test files in full). This file closes that one remaining branch
# for both classes, using the identical unlockBinding-replacement mocking technique already
# established for these two files.

set_mocks_rank <- function(priv, beta_m, ssq_m, beta_r, ssq_r) {
	unlockBinding("aftsrr_for_matched_pairs", priv)
	priv$aftsrr_for_matched_pairs <- function(estimate_only = FALSE) {
		priv$cached_values$beta_T_matched <- beta_m
		priv$cached_values$ssq_beta_T_matched <- ssq_m
	}
	unlockBinding("aftsrr_for_reservoir", priv)
	priv$aftsrr_for_reservoir <- function(estimate_only = FALSE) {
		priv$cached_values$beta_T_reservoir <- beta_r
		priv$cached_values$ssq_beta_T_reservoir <- ssq_r
	}
}

set_mocks_lwa <- function(priv, beta_m, ssq_m, beta_r, ssq_r) {
	unlockBinding("lwa_cox_for_matched_pairs", priv)
	priv$lwa_cox_for_matched_pairs <- function() {
		priv$cached_values$beta_T_matched <- beta_m
		priv$cached_values$ssq_beta_T_matched <- ssq_m
	}
	unlockBinding("cox_for_reservoir", priv)
	priv$cox_for_reservoir <- function() {
		priv$cached_values$beta_T_reservoir <- beta_r
		priv$cached_values$ssq_beta_T_reservoir <- ssq_r
	}
}

mk_fixture <- function(cls, seed, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rexp(n, exp(0.3 * w))
	des$add_all_subject_responses(y)
	inf <- get(cls)$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("InferenceSurvivalKKRankRegrIVWC: reservoir-only (m_ok = FALSE, r_ok = TRUE) falls back to beta_r/sqrt(ssq_r) directly, not nonestimable", {
	f <- mk_fixture("InferenceSurvivalKKRankRegrIVWC", 1L)
	set_mocks_rank(f$priv, NA_real_, NA_real_, 0.7, 0.3)
	f$priv$shared()
	expect_equal(f$priv$cached_values$beta_hat_T, 0.7)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.3))
	expect_false(f$inf$is_nonestimable("estimate"))
})

test_that("InferenceSurvivalKKLWACoxPHIVWC: reservoir-only (m_ok = FALSE, r_ok = TRUE) falls back to beta_r/sqrt(ssq_r) directly, not nonestimable", {
	f <- mk_fixture("InferenceSurvivalKKLWACoxPHIVWC", 2L)
	set_mocks_lwa(f$priv, NA_real_, NA_real_, 0.7, 0.3)
	f$priv$shared()
	expect_equal(f$priv$cached_values$beta_hat_T, 0.7)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.3))
	expect_false(f$inf$is_nonestimable("estimate"))
})
