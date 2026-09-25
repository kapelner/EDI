library(testthat)
library(EDI)

# InferenceAllKKMeanDiffIVWC's private shared() (inference_all_KK_mean_diff_IVWC.R, registry
# weighted_opportunity 70) has a separate SE-side (s_beta_hat_T) fallback ladder mirroring its
# already-tested beta_hat_T ladder (test-kk-mean-diff-ivwc-shared-extreme-imbalance-branches-
# reference.R covers only the estimate_only = TRUE branches, which return before this code runs):
#   - reservoir_unusable (nRT<=1 or nRC<=1): sqrt(ssqD_bar) if finite/positive, else sqrt(ssqR) if
#     finite/positive, else NA.
#   - no_matches (m<=1): sqrt(ssqR) if finite/positive, else NA.
#   - combined (both usable): if ssqD_bar is not finite/positive, fall back to sqrt(ssqR) (or NA);
#     else if ssqR is not finite/positive, sqrt(ssqD_bar); else the proper inverse-variance-combined
#     sqrt(ssqR * ssqD_bar / (ssqR + ssqD_bar)).
# None of the 8 distinct (usability-regime x ssqD_bar/ssqR-degeneracy) combinations had a test
# reference anywhere (confirmed via grep for ssqD/ssqR/KKMeanDiff together): the sibling reservoir-
# statistics test (test-kk-compound-reservoir-match-statistics-pooled-variance-reference.R) checks
# compute_reservoir_and_match_statistics()'s own ssqD_bar/ssqR/w_star computation, not shared()'s
# downstream dispatch over them. Reached the same way as the sibling extreme-imbalance test: directly
# overwriting the private KKstats cache (including ssqD_bar/ssqR) after a real
# compute_reservoir_and_match_statistics() call, independent of the real matching/statistics
# machinery (already tested elsewhere), then calling compute_estimate(estimate_only = FALSE) to run
# the full (non-estimate_only) shared() path.

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

set_KKstats <- function(priv, nRT, nRC, m, d_bar, r_bar, w_star, ssqD_bar, ssqR) {
	priv$compute_basic_match_data()
	priv$compute_reservoir_and_match_statistics()
	priv$cached_values$KKstats$nRT <- nRT
	priv$cached_values$KKstats$nRC <- nRC
	priv$cached_values$KKstats$m <- m
	priv$cached_values$KKstats$d_bar <- d_bar
	priv$cached_values$KKstats$r_bar <- r_bar
	priv$cached_values$KKstats$w_star <- w_star
	priv$cached_values$KKstats$ssqD_bar <- ssqD_bar
	priv$cached_values$KKstats$ssqR <- ssqR
	priv$cached_values$beta_hat_T <- NULL
	priv$cached_values$s_beta_hat_T <- NULL
}

se_after_full_shared <- function(seed, ...) {
	f <- mk_fixture(seed)
	set_KKstats(f$priv, ...)
	f$inf$compute_estimate(estimate_only = FALSE)
	f$priv$cached_values$s_beta_hat_T
}

test_that("reservoir_unusable (nRC <= 1): a usable ssqD_bar gives sqrt(ssqD_bar)", {
	se <- se_after_full_shared(1L, nRT = 5L, nRC = 1L, m = 6L, d_bar = 0.5, r_bar = 0.9, w_star = 0.3, ssqD_bar = 0.04, ssqR = 0.09)
	expect_equal(se, sqrt(0.04))
})

test_that("reservoir_unusable (nRC <= 1): a degenerate ssqD_bar falls back to sqrt(ssqR)", {
	se <- se_after_full_shared(2L, nRT = 5L, nRC = 1L, m = 6L, d_bar = 0.5, r_bar = 0.9, w_star = 0.3, ssqD_bar = NA_real_, ssqR = 0.09)
	expect_equal(se, sqrt(0.09))
})

test_that("reservoir_unusable (nRC <= 1): both ssqD_bar and ssqR degenerate gives NA", {
	se <- se_after_full_shared(3L, nRT = 5L, nRC = 1L, m = 6L, d_bar = 0.5, r_bar = 0.9, w_star = 0.3, ssqD_bar = NA_real_, ssqR = NA_real_)
	expect_true(is.na(se))
})

test_that("no_matches (m <= 1): a usable ssqR gives sqrt(ssqR)", {
	se <- se_after_full_shared(4L, nRT = 5L, nRC = 5L, m = 1L, d_bar = 0.5, r_bar = 0.9, w_star = 0.3, ssqD_bar = 0.04, ssqR = 0.09)
	expect_equal(se, sqrt(0.09))
})

test_that("no_matches (m <= 1): a degenerate ssqR gives NA (no fallback available)", {
	se <- se_after_full_shared(5L, nRT = 5L, nRC = 5L, m = 1L, d_bar = 0.5, r_bar = 0.9, w_star = 0.3, ssqD_bar = 0.04, ssqR = NA_real_)
	expect_true(is.na(se))
})

test_that("combined regime: a degenerate ssqD_bar with a usable ssqR falls back to sqrt(ssqR)", {
	se <- se_after_full_shared(6L, nRT = 5L, nRC = 5L, m = 6L, d_bar = 0.5, r_bar = 0.9, w_star = 0.3, ssqD_bar = NA_real_, ssqR = 0.09)
	expect_equal(se, sqrt(0.09))
})

test_that("combined regime: a usable ssqD_bar with a degenerate ssqR falls back to sqrt(ssqD_bar)", {
	se <- se_after_full_shared(7L, nRT = 5L, nRC = 5L, m = 6L, d_bar = 0.5, r_bar = 0.9, w_star = 0.3, ssqD_bar = 0.04, ssqR = NA_real_)
	expect_equal(se, sqrt(0.04))
})

test_that("combined regime: both usable gives the proper inverse-variance-combined sqrt(ssqR*ssqD_bar/(ssqR+ssqD_bar))", {
	se <- se_after_full_shared(8L, nRT = 5L, nRC = 5L, m = 6L, d_bar = 0.5, r_bar = 0.9, w_star = 0.3, ssqD_bar = 0.04, ssqR = 0.09)
	expect_equal(se, sqrt(0.09 * 0.04 / 0.13), tolerance = 1e-10)
})
