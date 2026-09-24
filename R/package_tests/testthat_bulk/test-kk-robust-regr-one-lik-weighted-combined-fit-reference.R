library(testthat)
library(EDI)

# InferenceContinKKRobustRegrOneLik's private fit_weighted_combined() (inference_continuous_KK_
# robust_regr_one_lik.R) had no test reference anywhere -- every existing test file that mentions the
# class targets rlm-control resolution, fit-unavailable guards, or the unweighted happy path, never
# compute_estimate_with_bootstrap_weights()/fit_weighted_combined() with genuinely varying weights.
# This is a three-tier cascade: (1) use_rcpp = TRUE uses a sqrt(weight)-transformed fast C++ M-
# estimator kernel, documented in source as reproducing MASS::rlm()'s default wt.method = "inv.var"
# weighting exactly; (2) use_rcpp = FALSE (or the fast path failing) falls back to MASS::rlm() itself;
# (3) if that also fails, a final stats::lm.wfit() fallback.
#   1. use_rcpp = FALSE matches an independently constructed MASS::rlm(weights = ...) call exactly,
#      built from the same matched-pair-difference + reservoir combined design the method itself uses.
#   2. use_rcpp = TRUE (the fast C++ path) closely approximates the same independent MASS::rlm()
#      reference (small numerical differences between the IRLS implementations, as already
#      established for this class's unweighted/randomization-inference paths elsewhere in this
#      session).
#   3. estimate_only = FALSE returns list(beta, se) matching summary(rlm_fit)'s own reported SE.
#   4. All-zero (or otherwise unusable) row weights return NA_real_.
#   5. When MASS::rlm() itself fails, the final stats::lm.wfit() fallback engages and matches an
#      independently constructed lm.wfit() call on the same combined design exactly.

robust_onelik_weighted_fixture <- function(seed, n = 60L, use_rcpp = TRUE) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKRobustRegrOneLik$new(des, use_rcpp = use_rcpp, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	invisible(inf$compute_estimate())
	list(inf = inf, priv = priv)
}

robust_combined_design <- function(priv, row_weights) {
	KKstats <- priv$cached_values$KKstats
	m <- KKstats$m; nRT <- KKstats$nRT; nRC <- KKstats$nRC; nR <- nRT + nRC
	kk_w <- EDI:::kk_pair_and_reservoir_bootstrap_weights(priv, row_weights)
	Xd_full <- as.matrix(KKstats$X_matched_diffs_full)
	X_comb <- rbind(
		cbind(0, 1, Xd_full),
		cbind(rep(1, nR), KKstats$w_reservoir, as.matrix(KKstats$X_reservoir))
	)
	y_comb <- c(KKstats$y_matched_diffs, KKstats$y_reservoir)
	w_comb <- c(kk_w$pair_weights, kk_w$reservoir_weights)
	list(X = X_comb, y = y_comb, w = w_comb, j_treat = 2L)
}

test_that("use_rcpp = FALSE matches an independently constructed MASS::rlm(weights = ...) call exactly", {
	f <- robust_onelik_weighted_fixture(1L, use_rcpp = FALSE)
	set.seed(2L); row_weights <- runif(f$priv$n, 0.3, 2)
	res <- f$priv$fit_weighted_combined(row_weights, estimate_only = TRUE)

	d <- robust_combined_design(f$priv, row_weights)
	ref <- MASS::rlm(x = d$X, y = d$y, weights = d$w, method = "M", maxit = 20, acc = 1e-4)
	expect_equal(res, unname(coef(ref)[d$j_treat]), tolerance = 1e-8)
})

test_that("use_rcpp = TRUE closely approximates the same independent MASS::rlm() reference", {
	f <- robust_onelik_weighted_fixture(1L, use_rcpp = TRUE)
	set.seed(2L); row_weights <- runif(f$priv$n, 0.3, 2)
	res <- f$priv$fit_weighted_combined(row_weights, estimate_only = TRUE)

	d <- robust_combined_design(f$priv, row_weights)
	ref <- MASS::rlm(x = d$X, y = d$y, weights = d$w, method = "M", maxit = 20, acc = 1e-4)
	expect_equal(res, unname(coef(ref)[d$j_treat]), tolerance = 0.01)
})

test_that("estimate_only = FALSE returns list(beta, se) matching summary(rlm_fit)'s own reported SE", {
	f <- robust_onelik_weighted_fixture(3L, use_rcpp = FALSE)
	set.seed(4L); row_weights <- runif(f$priv$n, 0.3, 2)
	res <- f$priv$fit_weighted_combined(row_weights, estimate_only = FALSE)

	d <- robust_combined_design(f$priv, row_weights)
	ref <- MASS::rlm(x = d$X, y = d$y, weights = d$w, method = "M", maxit = 20, acc = 1e-4)
	ref_ct <- summary(ref)$coefficients
	expect_equal(res$beta, unname(coef(ref)[d$j_treat]), tolerance = 1e-8)
	expect_equal(res$se, unname(ref_ct[d$j_treat, "Std. Error"]), tolerance = 1e-8)
})

test_that("all-zero row weights return NA_real_", {
	f <- robust_onelik_weighted_fixture(5L)
	res <- f$priv$fit_weighted_combined(rep(0, f$priv$n), estimate_only = TRUE)
	expect_true(is.na(res))
})

test_that("when MASS::rlm() itself fails, the final stats::lm.wfit() fallback engages and matches an independent lm.wfit() call exactly", {
	f <- robust_onelik_weighted_fixture(6L, use_rcpp = FALSE)
	set.seed(7L); row_weights <- runif(f$priv$n, 0.3, 2)
	d <- robust_combined_design(f$priv, row_weights)
	ref <- lm.wfit(x = d$X, y = d$y, w = d$w)

	local_mocked_bindings(rlm = function(...) stop("forced failure"), .package = "MASS")
	res <- f$priv$fit_weighted_combined(row_weights, estimate_only = TRUE)
	expect_equal(res, unname(coef(ref)[d$j_treat]), tolerance = 1e-8)
})
