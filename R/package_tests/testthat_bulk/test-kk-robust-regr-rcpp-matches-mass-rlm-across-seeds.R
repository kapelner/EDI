# v1.0.6-TODO-15: the Rcpp robust-regression path of the KK robust-regression
# classes (use_rcpp = TRUE) must reproduce MASS::rlm (use_rcpp = FALSE) for
# method = "M", across seeds rather than on one lucky seed.
#
# Before the fix the C++ kernel fixed the MAD scale at the OLS residuals while
# rlm re-estimates it every IRLS iteration (a different estimator: the gap stayed
# at ~1e-2 even with both paths run to acc = 1e-10), its SE lacked
# summary.rlm's kappa correction (so the IVWC inverse-variance weights differed),
# and the default iteration cap (10-15) was below what rlm needed (up to 26), so
# the rlm path returned NA on some seeds while the C++ path returned a value.
#
# The two paths now run the same algorithm (same OLS start, same per-iteration
# MAD scale, same relative-residual-change stopping rule at the same acc), so
# they stop on the same iteration and differ only by floating-point roundoff in
# the weighted least-squares solve (LDLT vs QR), ~1e-15. Stopping one iteration
# apart would move the estimate by roughly acc = 1e-4 times its scale, so the
# 1e-6 tolerance below catches any algorithmic divergence while leaving many
# orders of magnitude for roundoff.

make_kk_robust_sweep_design <- function(seed, n_pairs = 40L, n_single = 20L) {
	set.seed(seed)
	n <- 2L * n_pairs + n_single
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	}
	priv <- des$.__enclos_env__$private
	priv$m <- c(rep(seq_len(n_pairs), each = 2L), rep(0L, n_single))
	# a KK match is one treated and one control subject
	priv$w[seq(2L, 2L * n_pairs, 2L)] <- 1 - priv$w[seq(1L, 2L * n_pairs, 2L)]
	w <- priv$w
	X <- as.data.frame(priv$X)
	y <- 0.4 - 0.5 * w + 0.3 * X[[1]] - 0.2 * X[[2]] + rt(n, df = 4) * 0.5
	y[1:3] <- y[1:3] + 15
	des$add_all_subject_responses(y)
	des
}

kk_robust_sweep_seeds <- c(20260729, 1:19)

test_that("KK robust IVWC: use_rcpp = TRUE matches MASS::rlm for method M across seeds", {
	skip_if_not_installed("MASS")
	for (seed in kk_robust_sweep_seeds) {
		des <- make_kk_robust_sweep_design(seed)
		fast <- InferenceContinKKRobustRegrIVWC$new(des, method = "M", use_rcpp = TRUE, verbose = FALSE)
		ref  <- InferenceContinKKRobustRegrIVWC$new(des, method = "M", use_rcpp = FALSE, verbose = FALSE)
		est_fast <- fast$compute_estimate()
		est_ref  <- ref$compute_estimate()
		expect_true(is.finite(est_fast), info = paste("seed", seed))
		expect_true(is.finite(est_ref), info = paste("seed", seed))
		expect_equal(est_fast, est_ref, tolerance = 1e-6, info = paste("seed", seed))
		cv_fast <- fast$.__enclos_env__$private$cached_values
		cv_ref  <- ref$.__enclos_env__$private$cached_values
		expect_equal(cv_fast$beta_T_reservoir, cv_ref$beta_T_reservoir, tolerance = 1e-6, info = paste("seed", seed))
		expect_equal(cv_fast$ssq_beta_T_matched, cv_ref$ssq_beta_T_matched, tolerance = 1e-6, info = paste("seed", seed))
		expect_equal(cv_fast$ssq_beta_T_reservoir, cv_ref$ssq_beta_T_reservoir, tolerance = 1e-6, info = paste("seed", seed))
	}
})

test_that("KK robust OneLik: use_rcpp = TRUE matches MASS::rlm for method M across seeds", {
	skip_if_not_installed("MASS")
	for (seed in kk_robust_sweep_seeds) {
		des <- make_kk_robust_sweep_design(seed)
		fast <- InferenceContinKKRobustRegrOneLik$new(des, method = "M", use_rcpp = TRUE, verbose = FALSE)
		ref  <- InferenceContinKKRobustRegrOneLik$new(des, method = "M", use_rcpp = FALSE, verbose = FALSE)
		est_fast <- fast$compute_estimate()
		est_ref  <- ref$compute_estimate()
		expect_true(is.finite(est_fast), info = paste("seed", seed))
		expect_true(is.finite(est_ref), info = paste("seed", seed))
		expect_equal(est_fast, est_ref, tolerance = 1e-6, info = paste("seed", seed))
		se_fast <- fast$.__enclos_env__$private$get_standard_error()
		se_ref  <- ref$.__enclos_env__$private$get_standard_error()
		expect_equal(se_fast, se_ref, tolerance = 1e-6, info = paste("seed", seed))
	}
})
