library(testthat)
library(EDI)

# InferenceContinKKRobustRegrOneLik's private fit_combined() (inference_continuous_KK_robust_regr_
# one_lik.R) has three distinct design-construction branches depending on which of matched pairs and
# reservoir subjects are present. The combined (both present) branch is already exercised via
# compute_estimate() against an independent reference (test-continuous-kk-one-likelihood-classes-
# match-stacked-fits-and-lmer-reference.R), and the neither-present guard is covered
# (test-kk-onelik-no-usable-matched-or-reservoir-data-guard-reference.R), but the two single-source
# branches -- matched pairs only (no reservoir) and reservoir only (no matched pairs) -- had no
# reference anywhere. Forced here by mutating the class's own already-cached KKstats partition (a
# legitimate ground truth, same technique already used for the sibling CondPoisson cascade tests) to
# zero out the other source, with use_rcpp = FALSE so the reference matches exactly (the use_rcpp =
# TRUE fast path's own small numerical gap from MASS::rlm() is already established/tested elsewhere
# in this session for this class's weighted-refit sibling).
#   1. Matched-pairs-only (nRT or nRC forced to 0): the design is the pair-difference matrix with no
#      reservoir rows, matching an independent MASS::rlm(x = cbind(1, X_matched_diffs), ...) exactly.
#   2. Reservoir-only (m forced to 0): the design is the reservoir treatment+covariate matrix, matching
#      an independent MASS::rlm(x = cbind(1, w_reservoir, X_reservoir), ...) exactly.

robust_onelik_fixture <- function(seed, n = 40L, use_rcpp = FALSE) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKRobustRegrOneLik$new(des, use_rcpp = use_rcpp, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$compute_basic_match_data()
	list(inf = inf, priv = priv, KKstats = priv$cached_values$KKstats)
}

test_that("matched-pairs-only (no reservoir) matches an independent MASS::rlm() fit on the pair-difference design exactly", {
	f <- robust_onelik_fixture(1L)
	expect_gt(f$KKstats$m, 0L)
	f$priv$cached_values$KKstats$nRT <- 0L                                         # force the pairs-only branch

	f$priv$fit_combined(estimate_only = TRUE)
	Xd <- as.matrix(f$KKstats$X_matched_diffs)
	ref <- MASS::rlm(x = cbind(1, Xd), y = f$KKstats$y_matched_diffs, method = "M", maxit = 20, acc = 1e-4)
	expect_equal(f$priv$cached_values$beta_hat_T, unname(coef(ref)[1]), tolerance = 1e-8)
})

test_that("reservoir-only (no matched pairs) matches an independent MASS::rlm() fit on the reservoir design exactly", {
	f <- robust_onelik_fixture(2L)
	expect_gt(f$KKstats$nRT, 0L)
	expect_gt(f$KKstats$nRC, 0L)
	f$priv$cached_values$KKstats$m <- 0L                                           # force the reservoir-only branch

	f$priv$fit_combined(estimate_only = TRUE)
	X_r <- as.matrix(f$KKstats$X_reservoir)
	ref <- MASS::rlm(x = cbind(1, f$KKstats$w_reservoir, X_r), y = f$KKstats$y_reservoir, method = "M", maxit = 20, acc = 1e-4)
	expect_equal(f$priv$cached_values$beta_hat_T, unname(coef(ref)[2]), tolerance = 1e-8)
})
