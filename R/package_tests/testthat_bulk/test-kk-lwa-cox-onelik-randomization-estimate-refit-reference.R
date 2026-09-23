library(testthat)
library(EDI)

# InferenceSurvivalKKLWACoxPHOneLik's compute_treatment_estimate_during_randomization_inference()
# (inference_survival_KK_lwa_cox_one_lik_abstract.R) had no test reference anywhere.
#
# REAL BUG FOUND AND FIXED while writing this test (2026-09-23): the method's first three lines
# re-derived w/y/dead for randomization as
#   private$w = private$des_obj_priv_int$w
#   private$y = private$des_obj_priv_int$y
#   private$dead = as.numeric(!is.na(private$y))
# but private$des_obj_priv_int$y uses the Design's own post-migration convention (NA encodes a
# censored observation, with the true time in y_L/y_R), while private$y on every inference class --
# per InferenceAll's own initialize() -- holds the fully-observed time (event or censoring time,
# NEVER NA) with dead as a separate 0/1 indicator. Re-reading des_obj_priv_int$y directly silently
# fed real NAs into fast_coxph_regression_cpp() for every censored subject, on every call (including
# the very first, unpermuted observed-statistic evaluation). Confirmed via the PUBLIC API with a
# before/after contrast on simulated data carrying a strong known true effect (identical data except
# for censoring status): compute_rand_two_sided_pval() reported 0.0198 (correct) with no censoring
# vs. 0.97 (silently wrong -- reads as "no evidence of an effect" on data with a strong true effect)
# with ~20% censoring. Fixed to re-derive y/dead the same way Design$get_effective_time()/
# $get_effective_dead() do (matching InferenceAll's initialize() exactly) -- see the fix's own
# comment in the source for the full account. The identical buggy snippet was also found and fixed
# in InferenceSurvivalGLMMWeibullFrailtyNormalOneLik and InferenceSurvivalGLMMWeibullFrailtyLoggamma
# OneLik/IVWC (inference_survival_GLMM_weibull_frailty_normal.R / _loggamma.R) the same day.
#
# A second gotcha (not a bug -- the method's own first line does this by design "to survive
# duplicate()"): because private$w is unconditionally reassigned from private$des_obj_priv_int$w on
# every call, permuting private$w directly on the inference object (the pattern used for every other
# class in this session's randomization-estimate series) has NO effect -- the permutation must be
# injected into private$des_obj_priv_int$w instead, which this file does explicitly.
#
#   1. On the same w it matches compute_estimate()'s own value; with a permutation correctly injected
#      into des_obj_priv_int$w, it differs and stays finite -- now genuinely exercised with real
#      censored data (deads = rbinom(n, 1, 0.8)), since the bug above no longer corrupts it.
#   2. Both best_X_colnames unavailable after shared_combined_likelihood() -> NA_real_ directly (no
#      compute_estimate() fallback, matching the class's own explicit design).
#   3. A fitter failure (fast_coxph_regression_cpp() returns NULL or a non-finite coefficient)
#      returns NA.

kk_lwa_cox_fixture <- function(seed = 1L, n = 60L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	add_all_subject_responses_seq(des, rexp(n, exp(0.3 * X$x1 + 0.2 * w)), deads = rbinom(n, 1, 0.8))
	inf <- InferenceSurvivalKKLWACoxPHOneLik$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w)
}

test_that("on the same w it matches compute_estimate()'s own value; on a permuted w (injected via des_obj_priv_int$w) it differs and stays finite, with real censored data", {
	f <- kk_lwa_cox_fixture()
	main_est <- f$inf$compute_estimate()
	expect_true(is.finite(main_est))

	same_w_est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_equal(same_w_est, main_est, tolerance = 1e-8)

	set.seed(9)
	w2 <- sample(f$w)
	f$priv$des_obj_priv_int$w <- w2
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_true(is.finite(est2))
	expect_false(isTRUE(all.equal(main_est, est2, tolerance = 1e-3)))
})

test_that("returns NA_real_ directly when best_X_colnames stays unavailable after shared_combined_likelihood()", {
	f <- kk_lwa_cox_fixture(seed = 2L)
	p <- f$priv
	unlockBinding("shared_combined_likelihood", p)
	p$shared_combined_likelihood <- function(...) invisible(NULL)  # never populates best_X_colnames

	res <- p$compute_treatment_estimate_during_randomization_inference()
	expect_true(is.na(res))
})

test_that("a fitter failure (NULL or non-finite coefficient) returns NA", {
	f <- kk_lwa_cox_fixture(seed = 3L)
	f$inf$compute_estimate()
	local_mocked_bindings(fast_coxph_regression_cpp = function(...) NULL, .package = "EDI")
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))

	local_mocked_bindings(
		fast_coxph_regression_cpp = function(...) list(coefficients = c(NA_real_, 0)),
		.package = "EDI"
	)
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))
})
