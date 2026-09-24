library(testthat)
library(EDI)

# InferenceContinKKRobustRegrIVWC's private shared() (inference_continuous_KK_robust_regr_ivwc.R)
# combines a robust-regression fit on the matched-pair differences (robust_for_matched_pairs()) and a
# robust-regression fit on the reservoir (robust_for_reservoir()) into an inverse-variance-weighted
# combination -- the identical 4-branch IVWC-combination structure already closed this stretch for
# InferenceIncidKKCondLogitIVWC's shared():
#   1. both m_ok and r_ok: IVWC combination, beta_hat_T = w_star*beta_m + (1-w_star)*beta_r with
#      w_star = ssq_r/(ssq_r+ssq_m), s_beta_hat_T = sqrt(ssq_m*ssq_r/(ssq_m+ssq_r)).
#   2. only m_ok: beta_hat_T = beta_m, s_beta_hat_T = sqrt(ssq_m).
#   3. only r_ok: beta_hat_T = beta_r, s_beta_hat_T = sqrt(ssq_r).
#   4. neither: beta_hat_T = s_beta_hat_T = NA_real_.
# The class's only 2 existing references (test-quasi-robust-migration-baseline.R, a golden migration-
# parity test, and test-mixin-contracts.R) only ever exercise the ordinary happy path where both
# pieces succeed on real data -- none of the 3 remaining branches had a direct test reference
# anywhere. Reached by directly replacing the private robust_for_matched_pairs()/robust_for_reservoir()
# methods (unlockBinding) with stubs that set exact beta/ssq cache values, independent of the real
# robust-regression machinery (already tested elsewhere).

mk_fixture <- function(seed, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rnorm(n) + 0.8 * w + 0.3 * X$x1
	des$add_all_subject_responses(y)
	inf <- InferenceContinKKRobustRegrIVWC$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

set_mocks <- function(priv, beta_m, ssq_m, beta_r, ssq_r) {
	unlockBinding("robust_for_matched_pairs", priv)
	priv$robust_for_matched_pairs <- function(estimate_only = FALSE) {
		priv$cached_values$beta_T_matched <- beta_m
		priv$cached_values$ssq_beta_T_matched <- ssq_m
	}
	unlockBinding("robust_for_reservoir", priv)
	priv$robust_for_reservoir <- function(estimate_only = FALSE) {
		priv$cached_values$beta_T_reservoir <- beta_r
		priv$cached_values$ssq_beta_T_reservoir <- ssq_r
	}
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
	set_mocks(f$priv, NA_real_, NA_real_, 0.9, 0.5)
	f$priv$shared()
	expect_equal(f$priv$cached_values$beta_hat_T, 0.9)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.5))
})

test_that("both pieces succeed: the IVWC combination matches the closed-form weighted formula exactly", {
	f <- mk_fixture(3L)
	set_mocks(f$priv, 1.2, 0.2, 0.9, 0.5)
	f$priv$shared()
	w_star <- 0.5 / (0.5 + 0.2)
	expect_equal(f$priv$cached_values$beta_hat_T, w_star * 1.2 + (1 - w_star) * 0.9)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.2 * 0.5 / (0.2 + 0.5)))
})

test_that("neither piece succeeds: beta_hat_T and s_beta_hat_T are NA_real_", {
	f <- mk_fixture(4L)
	set_mocks(f$priv, NA_real_, NA_real_, NA_real_, NA_real_)
	f$priv$shared()
	expect_true(is.na(f$priv$cached_values$beta_hat_T))
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
})
