library(testthat)
library(EDI)

# InferenceSurvivalGLMMWeibullFrailtyNormalIVWC's private shared() (inference_survival_GLMM_
# weibull_frailty_normal.R) combines a matched-pairs frailty fit (frailty_for_matched_pairs()) and a
# reservoir Weibull fit (weibull_for_reservoir()) via inverse-variance weighting, with a richer branch
# structure than the plain IVWC-combination pattern already closed this stretch (InferenceIncidKK
# CondLogitIVWC, InferenceContinKKRobustRegrIVWC): under estimate_only = TRUE, m_ok/r_ok only require
# a finite point estimate (not a finite variance), so when BOTH point estimates are available but
# their variances are NOT (a real scenario the class's own estimate_only contract deliberately skips
# variance computation for), shared() falls back to EQUAL 0.5/0.5 weighting rather than w_star = ssq_r
# / (ssq_r + ssq_m) -- this exact branch was the site of a real, now-fixed bug this session (w_star
# was previously NA/NA = NA under estimate_only = TRUE even with two finite point estimates, per
# glmm_weibull_frailty_ivwc_estimate_only_na_pooling.md), but had no dedicated regression test
# anywhere (confirmed via grep for "estimate_only_na_pooling"/"w_star"). This file closes both that
# specific regression and the file's other IVWC-combination branches (full-variance weighting,
# matched-only, reservoir-only, neither) via unlockBinding stubs on the two component-fitting private
# methods, independent of the real frailty/Weibull-fitting machinery (already tested elsewhere).

mk_fixture <- function(seed, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rexp(n, exp(0.3 * w))
	des$add_all_subject_responses(y)
	inf <- InferenceSurvivalGLMMWeibullFrailtyNormalIVWC$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

set_mocks <- function(priv, beta_m, ssq_m, beta_r, ssq_r) {
	unlockBinding("frailty_for_matched_pairs", priv)
	priv$frailty_for_matched_pairs <- function(estimate_only = FALSE) {
		priv$cached_values$beta_T_matched <- beta_m
		priv$cached_values$ssq_beta_T_matched <- ssq_m
	}
	unlockBinding("weibull_for_reservoir", priv)
	priv$weibull_for_reservoir <- function(estimate_only = FALSE) {
		priv$cached_values$beta_T_reservoir <- beta_r
		priv$cached_values$ssq_beta_T_reservoir <- ssq_r
	}
}

test_that("estimate_only = TRUE with both point estimates finite but both variances NA falls back to equal 0.5/0.5 weighting (the fixed bug's regression case)", {
	f <- mk_fixture(1L)
	set_mocks(f$priv, 1.2, NA_real_, 0.8, NA_real_)
	f$priv$shared(estimate_only = TRUE)
	expect_equal(f$priv$cached_values$beta_hat_T, 0.5 * 1.2 + 0.5 * 0.8)
})

test_that("estimate_only = TRUE with both variances finite still uses inverse-variance weighting (not equal weights)", {
	f <- mk_fixture(2L)
	set_mocks(f$priv, 1.2, 0.2, 0.8, 0.5)
	f$priv$shared(estimate_only = TRUE)
	w_star <- 0.5 / (0.5 + 0.2)
	expect_equal(f$priv$cached_values$beta_hat_T, w_star * 1.2 + (1 - w_star) * 0.8)
})

test_that("estimate_only = FALSE with both pieces available: full IVWC combination with SE matches the closed-form formula", {
	f <- mk_fixture(3L)
	set_mocks(f$priv, 1.2, 0.2, 0.8, 0.5)
	f$priv$shared(estimate_only = FALSE)
	w_star <- 0.5 / (0.5 + 0.2)
	expect_equal(f$priv$cached_values$beta_hat_T, w_star * 1.2 + (1 - w_star) * 0.8)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.2 * 0.5 / (0.2 + 0.5)))
})

test_that("only the matched-pairs piece succeeds: beta_hat_T = beta_m, s_beta_hat_T = sqrt(ssq_m)", {
	f <- mk_fixture(4L)
	set_mocks(f$priv, 1.2, 0.2, NA_real_, NA_real_)
	f$priv$shared(estimate_only = FALSE)
	expect_equal(f$priv$cached_values$beta_hat_T, 1.2)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.2))
})

test_that("neither piece succeeds: beta_hat_T and s_beta_hat_T are NA_real_", {
	f <- mk_fixture(5L)
	set_mocks(f$priv, NA_real_, NA_real_, NA_real_, NA_real_)
	f$priv$shared(estimate_only = FALSE)
	expect_true(is.na(f$priv$cached_values$beta_hat_T))
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
})
