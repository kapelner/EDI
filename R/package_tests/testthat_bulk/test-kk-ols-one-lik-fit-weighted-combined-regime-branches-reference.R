library(testthat)
library(EDI)

# InferenceContinKKOLSOneLik's private fit_weighted_combined() (inference_continuous_KK_ols_one_lik.R)
# had zero test coverage anywhere for its own regime-dispatch logic: a codebase-wide grep for
# fit_weighted_combined/kk_ols_combined_reduced_design_weighted found only one hit
# (test-kk-robust-regr-one-lik-weighted-combined-fit-reference.R), which is the ROBUST-regression
# sibling class's OWN separate fit_weighted_combined() (a different file,
# inference_continuous_KK_robust_regr_one_lik.R) -- not this plain-OLS class. The only existing
# weighted-bootstrap test for this class (test-bootstrap-uniform-weight-scale-regressions.R) only
# exercises estimate_only = TRUE on the "both usable" combined regime. This file closes the gap:
# fit_weighted_combined() dispatches on the same three usability regimes as the unweighted
# fit_combined() (m>0 && nRT>0 && nRC>0 combined; m>0-only matched-pairs; nRT>0 && nRC>0-only
# reservoir), plus a "neither usable" NA branch and an all-non-positive-weights NA branch, and (with
# estimate_only = FALSE) computes an HC2 sandwich SE via ols_hc2_post_fit_cpp on the weight-
# transformed design. Point estimates are verified against an independent from-scratch
# lm(weights = ...) reference built from the same matched-pair-difference + reservoir combined design
# the method itself constructs; SEs are checked for finiteness/positivity (the point-estimate cross-
# check already confirms the regime dispatch delivers the correctly-shaped weighted design to the
# separately-tested HC2 kernel). Reached via direct KKstats private-cache injection (the same
# technique already established in this session's sibling IVWC/passthrough-compound tests),
# independent of the real matching/statistics machinery (already tested elsewhere).

mk_fixture <- function(seed = 1L, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rnorm(n) + 0.8 * w
	des$add_all_subject_responses(y)
	inf <- InferenceContinKKOLSOneLik$new(des, model_formula = ~1, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- list(row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n)
	invisible(priv$compute_basic_match_data())
	list(inf = inf, priv = priv, n = n)
}

ref_weighted_beta <- function(priv, weights, regime) {
	kk_w <- EDI:::kk_pair_and_reservoir_bootstrap_weights(priv, weights)
	KK <- priv$cached_values$KKstats
	m <- KK$m; nRT <- KK$nRT; nRC <- KK$nRC; nR <- nRT + nRC
	if (regime == "combined") {
		X_comb <- rbind(cbind(matrix(0, m, 1), rep(1, m)), cbind(rep(1, nR), KK$w_reservoir))
		y_comb <- c(KK$y_matched_diffs, KK$y_reservoir)
		w_comb <- c(kk_w$pair_weights, kk_w$reservoir_weights)
		j <- 2L
	} else if (regime == "matched") {
		X_comb <- matrix(1, m, 1)
		y_comb <- KK$y_matched_diffs
		w_comb <- kk_w$pair_weights
		j <- 1L
	} else {
		X_comb <- cbind(rep(1, nR), KK$w_reservoir)
		y_comb <- KK$y_reservoir
		w_comb <- kk_w$reservoir_weights
		j <- 2L
	}
	fit <- stats::lm.wfit(x = X_comb, y = y_comb, w = w_comb)
	unname(fit$coefficients[j])
}

test_that("combined regime (m>0, nRT>0, nRC>0): the weighted estimate matches an independent lm.wfit reference exactly", {
	f <- mk_fixture(1L)
	weights <- runif(f$n, 0.5, 2)
	est <- f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE)
	expect_equal(as.numeric(est), ref_weighted_beta(f$priv, weights, "combined"), tolerance = 1e-8)
	se <- f$priv$last_weighted_refit$s_beta_hat_T
	expect_true(is.finite(se) && se > 0)
})

test_that("matched-pairs-only regime (nRT=nRC=0): the weighted estimate matches an independent lm.wfit reference on matched diffs alone", {
	f <- mk_fixture(2L)
	weights <- runif(f$n, 0.5, 2)
	f$priv$cached_values$KKstats$nRT <- 0L
	f$priv$cached_values$KKstats$nRC <- 0L
	est <- f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE)
	expect_equal(as.numeric(est), ref_weighted_beta(f$priv, weights, "matched"), tolerance = 1e-8)
	se <- f$priv$last_weighted_refit$s_beta_hat_T
	expect_true(is.finite(se) && se > 0)
})

test_that("reservoir-only regime (m=0): the weighted estimate matches an independent lm.wfit reference on reservoir subjects alone", {
	f <- mk_fixture(3L)
	weights <- runif(f$n, 0.5, 2)
	f$priv$cached_values$KKstats$m <- 0L
	est <- f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE)
	expect_equal(as.numeric(est), ref_weighted_beta(f$priv, weights, "reservoir"), tolerance = 1e-8)
	se <- f$priv$last_weighted_refit$s_beta_hat_T
	expect_true(is.finite(se) && se > 0)
})

test_that("neither regime usable (m=0, nRT=0, nRC=0): returns NA for both estimate and SE", {
	f <- mk_fixture(4L)
	weights <- runif(f$n, 0.5, 2)
	f$priv$cached_values$KKstats$m <- 0L
	f$priv$cached_values$KKstats$nRT <- 0L
	f$priv$cached_values$KKstats$nRC <- 0L
	est <- f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE)
	expect_true(is.na(est))
	expect_true(is.na(f$priv$last_weighted_refit$s_beta_hat_T))
})

test_that("all-zero weights (no positive-finite weighted rows): returns NA even in the otherwise-usable combined regime", {
	f <- mk_fixture(5L)
	est <- f$inf$compute_estimate_with_bootstrap_weights(rep(0, f$n), estimate_only = FALSE)
	expect_true(is.na(est))
})
