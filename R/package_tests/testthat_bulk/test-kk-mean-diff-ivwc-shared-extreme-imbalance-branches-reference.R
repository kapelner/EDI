library(testthat)
library(EDI)

# InferenceAllKKMeanDiffIVWC's private shared() (inference_all_KK_mean_diff_IVWC.R) picks between 5
# distinct formulas for beta_hat_T depending on how usable the matched-pairs mean-difference (d_bar)
# and reservoir mean-difference (r_bar) pieces are, based on precomputed KKstats (nRT, nRC, m, d_bar,
# r_bar, w_star from compute_reservoir_and_match_statistics()):
#   1. reservoir_unusable (nRT <= 1 or nRC <= 1) and d_bar finite: beta_hat_T = d_bar.
#   2. no_matches (m <= 1) and r_bar finite: beta_hat_T = r_bar.
#   3. both finite (and neither degenerate): beta_hat_T = w_star*d_bar + (1-w_star)*r_bar.
#   4/5. one-sided fallbacks (only r_bar or only d_bar finite, without the extreme-imbalance
#      condition) -- structurally identical to branches 1/2's output.
#   else: NA_real_ when neither piece is finite.
# The class's 4 existing references (test-continuous-estimator-contracts.R, test-simple-mean-
# difference-migration-golden.R etc.) are all migration/golden/contract tests on ordinary,
# well-balanced KK designs where reservoir_unusable/no_matches never trigger -- none of the extreme-
# imbalance branches (nRT<=1, nRC<=1, m<=1) had a test reference anywhere (confirmed via grep; this
# matches the coverage registry's own note for the sibling inference_mixin_kk_passthrough_compound.R
# file's analogous only_matches/only_reservoir extreme-imbalance branches). Reached by directly
# overwriting the private KKstats cache after a real compute_reservoir_and_match_statistics() call,
# independent of the real matching/statistics machinery (already tested elsewhere).

mk_fixture <- function(seed, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rnorm(n) + 0.8 * w
	des$add_all_subject_responses(y)
	inf <- InferenceAllKKMeanDiffIVWC$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

set_KKstats <- function(priv, nRT, nRC, m, d_bar, r_bar, w_star) {
	priv$compute_basic_match_data()
	priv$compute_reservoir_and_match_statistics()
	priv$cached_values$KKstats$nRT <- nRT
	priv$cached_values$KKstats$nRC <- nRC
	priv$cached_values$KKstats$m <- m
	priv$cached_values$KKstats$d_bar <- d_bar
	priv$cached_values$KKstats$r_bar <- r_bar
	priv$cached_values$KKstats$w_star <- w_star
	priv$cached_values$beta_hat_T <- NULL
}

test_that("reservoir_unusable (nRC <= 1) with a usable matched-pairs estimate falls back to d_bar alone", {
	f <- mk_fixture(1L)
	set_KKstats(f$priv, nRT = 5L, nRC = 1L, m = 6L, d_bar = 0.5, r_bar = 0.9, w_star = 0.3)
	expect_equal(f$inf$compute_estimate(estimate_only = TRUE), 0.5)
})

test_that("no_matches (m <= 1) with a usable reservoir estimate falls back to r_bar alone", {
	f <- mk_fixture(2L)
	set_KKstats(f$priv, nRT = 5L, nRC = 5L, m = 1L, d_bar = 0.5, r_bar = 0.9, w_star = 0.3)
	expect_equal(f$inf$compute_estimate(estimate_only = TRUE), 0.9)
})

test_that("both pieces usable and neither degenerate: the weighted combination matches w_star*d_bar + (1-w_star)*r_bar exactly", {
	f <- mk_fixture(3L)
	set_KKstats(f$priv, nRT = 5L, nRC = 5L, m = 6L, d_bar = 0.5, r_bar = 0.9, w_star = 0.3)
	expect_equal(f$inf$compute_estimate(estimate_only = TRUE), 0.3 * 0.5 + 0.7 * 0.9)
})

test_that("neither piece is finite: the estimate is NA_real_", {
	f <- mk_fixture(4L)
	set_KKstats(f$priv, nRT = 5L, nRC = 5L, m = 6L, d_bar = NA_real_, r_bar = NA_real_, w_star = 0.3)
	expect_true(is.na(f$inf$compute_estimate(estimate_only = TRUE)))
})
