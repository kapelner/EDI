library(testthat)
library(EDI)

# InferenceContinKKOLSOneLik's private fit_combined() (inference_continuous_KK_ols_one_lik.R) has
# three distinct design-construction branches depending on which of matched pairs and reservoir
# subjects are present -- the same three-way structure as InferenceContinKKRobustRegrOneLik's own
# fit_combined(), whose two single-source branches were closed last iteration
# (test-kk-robust-regr-one-lik-fit-combined-pairs-and-reservoir-only-branches-reference.R). The
# combined (both present) branch is already exercised via compute_estimate() against an independent
# reference (test-continuous-kk-one-likelihood-classes-match-stacked-fits-and-lmer-reference.R), and
# the neither-present guard is covered (test-kk-onelik-no-usable-matched-or-reservoir-data-guard-
# reference.R), but the matched-pairs-only and reservoir-only branches had no reference anywhere.
# Forced here by mutating the class's own already-cached KKstats partition to zero out the other
# source, same technique as the robust-regr sibling. Unlike the robust (M-estimator) sibling, OLS is
# closed-form, so both branches match an independent stats::lm.fit() call EXACTLY (no rcpp-vs-
# reference numerical gap to account for).
#   1. Matched-pairs-only (nRT forced to 0): the design is the pair-difference matrix with no
#      reservoir rows, matching an independent lm.fit(cbind(1, X_matched_diffs), ...) exactly.
#   2. Reservoir-only (m forced to 0): the design is the reservoir treatment+covariate matrix, matching
#      an independent lm.fit(cbind(1, w_reservoir, X_reservoir), ...) exactly.

ols_onelik_fixture <- function(seed, n = 40L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKOLSOneLik$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$compute_basic_match_data()
	list(inf = inf, priv = priv, KKstats = priv$cached_values$KKstats)
}

test_that("matched-pairs-only (no reservoir) matches an independent lm.fit() on the pair-difference design exactly", {
	f <- ols_onelik_fixture(1L)
	expect_gt(f$KKstats$m, 0L)
	f$priv$cached_values$KKstats$nRT <- 0L                                         # force the pairs-only branch

	f$priv$fit_combined(estimate_only = TRUE)
	Xd <- as.matrix(f$KKstats$X_matched_diffs)
	ref <- lm.fit(x = cbind(1, Xd), y = f$KKstats$y_matched_diffs)
	expect_equal(f$priv$cached_values$beta_hat_T, unname(coef(ref)[1]), tolerance = 1e-10)
})

test_that("reservoir-only (no matched pairs) matches an independent lm.fit() on the reservoir design exactly", {
	f <- ols_onelik_fixture(2L)
	expect_gt(f$KKstats$nRT, 0L)
	expect_gt(f$KKstats$nRC, 0L)
	f$priv$cached_values$KKstats$m <- 0L                                           # force the reservoir-only branch

	f$priv$fit_combined(estimate_only = TRUE)
	X_r <- as.matrix(f$KKstats$X_reservoir)
	ref <- lm.fit(x = cbind(1, f$KKstats$w_reservoir, X_r), y = f$KKstats$y_reservoir)
	expect_equal(f$priv$cached_values$beta_hat_T, unname(coef(ref)[2]), tolerance = 1e-10)
})
