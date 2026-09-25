library(testthat)
library(EDI)

# InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC's private shared() (inference_survival_GLMM_
# weibull_frailty_loggamma.R) combines a Clayton-copula fit on the matched pairs and a Weibull fit on
# the reservoir via inverse-variance weighting w_star = ssq_r / (ssq_r + ssq_m). Under estimate_only =
# TRUE, both component fitters deliberately skip their variance computation for speed, leaving ssq_m/
# ssq_r as NA even when the point estimates (beta_m/beta_r) are perfectly finite -- a real bug (commit
# bcce1ded, 2026-09-23, fix_glmm_weibull_frailty_ivwc_estimate_only_na_pooling.md) made w_star =
# NA/NA = NA in that case, making beta_hat_T unconditionally NA on every resampling draw under
# estimate_only = TRUE even though both components were individually usable. The fix falls back to
# equal weighting (w_star = 0.5) whenever either ssq is non-finite. A codebase-wide grep confirmed
# zero test references anywhere for this exact class's shared()/w_star logic (the class's own existing
# tests only cover compute_estimate_with_bootstrap_weights(), a different code path that bypasses this
# combination entirely). Reached by unlockBinding-replacing the two component fitters (clayton_copula_
# for_matched_pairs()/weibull_for_reservoir()) with stubs setting exact cached beta/ssq values,
# independent of the real (documented-fragile) Clayton-copula/Weibull-frailty MLE machinery -- the
# same technique already established for this file's sibling IVWC classes.

fx <- function(seed, n = 24L) {
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
	priv <- inf$.__enclos_env__$private
	priv$compute_basic_match_data()
	stopifnot(priv$cached_values$KKstats$m > 0, priv$cached_values$KKstats$nRT > 0, priv$cached_values$KKstats$nRC > 0)  # both components reachable
	list(inf = inf, priv = priv)
}

stub_components <- function(priv, beta_m, beta_r) {
	unlockBinding("clayton_copula_for_matched_pairs", priv)
	priv$clayton_copula_for_matched_pairs <- function(estimate_only = FALSE) {
		priv$cached_values$beta_T_matched <- beta_m
		priv$cached_values$ssq_beta_T_matched <- if (estimate_only) NA_real_ else 0.1
	}
	unlockBinding("weibull_for_reservoir", priv)
	priv$weibull_for_reservoir <- function(estimate_only = FALSE) {
		priv$cached_values$beta_T_reservoir <- beta_r
		priv$cached_values$ssq_beta_T_reservoir <- if (estimate_only) NA_real_ else 0.2
	}
}

test_that("estimate_only = TRUE with both finite component betas falls back to equal weighting (w_star = 0.5), not NA", {
	f <- fx(1L)
	stub_components(f$priv, beta_m = 0.5, beta_r = 0.9)
	est <- f$inf$compute_estimate(estimate_only = TRUE)
	expect_equal(est, 0.5 * 0.5 + 0.5 * 0.9)
	expect_true(is.finite(est))
})

test_that("the full (non-estimate-only) path still uses the real inverse-variance weighting, unaffected by the fix", {
	f <- fx(2L)
	stub_components(f$priv, beta_m = 0.5, beta_r = 0.9)
	est <- f$inf$compute_estimate(estimate_only = FALSE)
	w_star_ref <- 0.2 / (0.2 + 0.1)
	expect_equal(est, w_star_ref * 0.5 + (1 - w_star_ref) * 0.9, tolerance = 1e-12)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.1 * 0.2 / (0.1 + 0.2)), tolerance = 1e-12)
})

test_that("estimate_only = TRUE with equal-weighting fallback averages symmetrically regardless of which component is 'larger'", {
	f <- fx(3L)
	stub_components(f$priv, beta_m = 2.0, beta_r = -1.0)
	est <- f$inf$compute_estimate(estimate_only = TRUE)
	expect_equal(est, mean(c(2.0, -1.0)))
})
