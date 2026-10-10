library(testthat)
library(EDI)

# InferenceAll's shared compute_fast_randomization_distr_via_reused_worker() (inference_all_abstract_
# rand.R) -- the duplicate-worker-per-chunk kernel behind approximate_randomization_distribution_
# beta_hat_T() for any class with a compute_fast_randomization_distr() override (OLS/robust-regr/LIN/
# quantile-regr OneLik and IVWC classes, hurdle/cond-Poisson count classes) -- had zero direct test
# reference anywhere: confirmed via grep, no test file mentions the function by name, and no existing
# test compares InferenceContinKKOLSOneLik's randomization distribution against an independently
# reconstructed permutation refit. Verified here by generating a small, explicit permutation matrix,
# calling the public entry point with it, and independently reproducing each permutation's point
# estimate via a fresh self$duplicate() worker with its own w/KKstats mutated directly and refit via
# the already-well-tested fit_combined() -- the same "duplicate a fresh worker per permutation"
# technique the function itself uses internally, just assembled by hand here.
#   1. Each value in the r-length randomization distribution (delta = 0, the sharp-null case used by
#      compute_rand_two_sided_pval()) exactly matches an independently reconstructed refit on the
#      same permuted treatment assignment, across two different (n, p) configurations.

kk_ols_onelik_rand_fixture <- function(seed, n, x_df) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(x_df[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKOLSOneLik$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	inf
}

independent_permutation_refit <- function(inf, w_mat) {
	r <- ncol(w_mat)
	ref <- numeric(r)
	for (i in seq_len(r)) {
		dup <- inf$duplicate()
		dpriv <- dup$.__enclos_env__$private
		w_i <- as.integer(w_mat[, i])
		dpriv$des_obj_priv_int$w <- w_i
		dpriv$w <- w_i
		dpriv$cached_values$KKstats <- NULL                                        # force the match-structure/design-diff cache to rebuild for this w
		invisible(dpriv$fit_combined(estimate_only = TRUE))
		ref[i] <- dpriv$cached_values$beta_hat_T
	}
	ref
}

test_that("each randomization-distribution value exactly matches an independently reconstructed permutation refit (n = 30, one covariate)", {
	inf <- kk_ols_onelik_rand_fixture(1L, 30L, data.frame(x1 = rnorm(30L)))
	priv <- inf$.__enclos_env__$private
	perms <- priv$generate_permutations(5L)

	distr <- inf$approximate_randomization_distribution_beta_hat_T(r = 5L, delta = 0, permutations = perms, show_progress = FALSE)
	ref <- independent_permutation_refit(inf, perms$w_mat)
	expect_equal(distr, ref, tolerance = 1e-10)
})

test_that("each randomization-distribution value exactly matches an independently reconstructed permutation refit (n = 40, two covariates)", {
	inf <- kk_ols_onelik_rand_fixture(5L, 40L, data.frame(x1 = rnorm(40L), x2 = rnorm(40L)))
	priv <- inf$.__enclos_env__$private
	perms <- priv$generate_permutations(6L)

	distr <- inf$approximate_randomization_distribution_beta_hat_T(r = 6L, delta = 0, permutations = perms, show_progress = FALSE)
	ref <- independent_permutation_refit(inf, perms$w_mat)
	expect_equal(distr, ref, tolerance = 1e-10)
})

test_that("KK OLS one-likelihood is affine across null shifts and is the only verified tier-2 opt-in", {
	inf <- kk_ols_onelik_rand_fixture(7L, 30L, data.frame(x1 = rnorm(30L), x2 = rnorm(30L)))
	p <- inf$.__enclos_env__$private
	perms <- p$generate_permutations(11L)
	t0 <- inf$approximate_randomization_distribution_beta_hat_T(11L, 0, permutations = perms, show_progress = FALSE)
	t1 <- inf$approximate_randomization_distribution_beta_hat_T(11L, 0.1, permutations = perms, show_progress = FALSE)
	t5 <- inf$approximate_randomization_distribution_beta_hat_T(11L, 0.5, permutations = perms, show_progress = FALSE)
	expect_equal((t1 - t0) / 0.1, (t5 - t0) / 0.5, tolerance = 1e-10)
	invisible(inf$compute_rand_two_sided_pval(11L, 0, show_progress = FALSE, permutations = perms))
	expect_true(p$supports_additive_delta_shift("none"))
	expect_equal(p$cached_values$t0s_rand + 0.5 * p$cached_values$t0s_rand_slopes, t5, tolerance = 1e-10)
	expect_true(EDI:::get_inference_class_metadata("InferenceContinKKOLSOneLik")$supports_additive_delta_shift)
	expect_false(isTRUE(EDI:::get_inference_class_metadata("InferenceContinKKOLSIVWC")$supports_additive_delta_shift))
	expect_false(isTRUE(EDI:::get_inference_class_metadata("InferenceAllKKMeanDiffIVWC")$supports_additive_delta_shift))
})
