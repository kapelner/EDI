library(testthat)
library(EDI)

# InferenceSurvivalKKLWACoxPHIVWC's private shared() (inference_survival_KK_lwa_cox_ivwc_abstract.R)
# combines a Lee-Wei-Amato cluster-robust Cox fit on the matched pairs (lwa_cox_for_matched_pairs())
# and a standard Cox fit on the reservoir (cox_for_reservoir()) via inverse-variance weighting, the
# same IVWC-combination pattern already closed this stretch for several sibling classes -- but this
# class layers 3 distinct nonestimable-reason guards on top of the point-estimate/variance
# combination, none of which had a test reference anywhere (confirmed via grep for each exact reason
# string; the class's 3 existing references are all golden/migration-parity tests on the ordinary
# happy path):
#   1. `cache_nonestimable_estimate("kk_lwa_cox_ivwc_no_usable_component")` when neither the matched-
#      pairs nor the reservoir piece produces a usable (finite, positive-variance) fit.
#   2. `cache_nonestimable_estimate("kk_lwa_cox_ivwc_extreme_estimate")` when the (otherwise usable)
#      combined beta_hat_T exceeds max_abs_reasonable_coef in absolute value.
#   3. `cache_nonestimable_se("kk_lwa_cox_ivwc_standard_error_unavailable")` when the combined
#      s_beta_hat_T is non-finite, non-positive, or itself exceeds max_abs_reasonable_coef (reached
#      here via a component whose OWN variance is finite-and-positive -- satisfying m_ok/r_ok -- but
#      whose square root is nonetheless unreasonably large).
# Reached by unlockBinding-replacing lwa_cox_for_matched_pairs()/cox_for_reservoir() with stubs that
# set exact beta/ssq cache values, independent of the real Cox-fitting machinery (already tested
# elsewhere).

mk_fixture <- function(seed, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rexp(n, exp(0.3 * w))
	des$add_all_subject_responses(y)
	inf <- InferenceSurvivalKKLWACoxPHIVWC$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

set_mocks <- function(priv, beta_m, ssq_m, beta_r, ssq_r) {
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

test_that("neither piece produces a usable fit: 'kk_lwa_cox_ivwc_no_usable_component'", {
	f <- mk_fixture(1L)
	set_mocks(f$priv, NA_real_, NA_real_, NA_real_, NA_real_)
	f$priv$shared()
	expect_true(f$inf$is_nonestimable("estimate"))
	expect_equal(f$inf$get_nonestimable_reason(), "kk_lwa_cox_ivwc_no_usable_component")
})

test_that("a usable but unreasonably extreme combined estimate: 'kk_lwa_cox_ivwc_extreme_estimate'", {
	f <- mk_fixture(2L)
	set_mocks(f$priv, f$priv$max_abs_reasonable_coef * 10, 0.2, NA_real_, NA_real_)
	f$priv$shared()
	expect_true(f$inf$is_nonestimable("estimate"))
	expect_equal(f$inf$get_nonestimable_reason(), "kk_lwa_cox_ivwc_extreme_estimate")
})

test_that("a usable estimate but an unreasonably large combined SE: 'kk_lwa_cox_ivwc_standard_error_unavailable'", {
	f <- mk_fixture(3L)
	huge_finite_ssq <- (f$priv$max_abs_reasonable_coef * 10)^2   # finite and > 0 (passes m_ok), but sqrt() is extreme
	set_mocks(f$priv, 1.2, huge_finite_ssq, NA_real_, NA_real_)
	f$priv$shared()
	expect_equal(f$priv$cached_values$beta_hat_T, 1.2)   # the point estimate itself was usable
	expect_equal(f$inf$get_nonestimable_reason(), "kk_lwa_cox_ivwc_standard_error_unavailable")
})

test_that("both pieces succeed within reasonable bounds: the IVWC combination matches the closed-form weighted formula exactly, and clears any prior nonestimable state", {
	f <- mk_fixture(4L)
	set_mocks(f$priv, 1.2, 0.2, 0.8, 0.5)
	f$priv$shared()
	w_star <- 0.5 / (0.5 + 0.2)
	expect_equal(f$priv$cached_values$beta_hat_T, w_star * 1.2 + (1 - w_star) * 0.8)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.2 * 0.5 / (0.2 + 0.5)))
	expect_false(f$inf$is_nonestimable("estimate"))
})
