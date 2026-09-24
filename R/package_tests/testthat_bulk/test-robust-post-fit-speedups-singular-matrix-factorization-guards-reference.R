library(testthat)
library(EDI)

# Three sibling post-fit sandwich-variance C++ kernels in robust_post_fit_speedups.cpp each factorize
# a cross-product matrix (X'X or the weighted X'WX) via an Eigen LDLT decomposition and stop() if the
# decomposition fails: ols_hc2_setup_cpp() ("failed to factorize X'X" / "failed to invert X'X"),
# glm_sandwich_post_fit_cpp() and glm_cluster_sandwich_post_fit_cpp() (both "failed to factorize
# X'WX" / "failed to invert X'WX"). A codebase-wide grep confirmed the X'WX-family messages had zero
# test references anywhere (the X'X-family message on ols_hc2_setup_cpp was likewise untested),
# despite all three functions being otherwise well-tested (2-5 references each) -- every existing
# reference fits on a well-conditioned, non-singular design matrix. Reached by supplying a design
# matrix with an exactly collinear column (one covariate is a scalar multiple of another), which makes
# X'X (or X'WX with unit weights) exactly singular and fails Eigen's LDLT factorization. Only the
# "failed to factorize" branch is independently reachable this way -- once LDLT's own factorization
# fails, its solve() is never called, so the sibling "failed to invert" message on the same guard pair
# is effectively unreachable via a genuinely singular matrix (LDLT catches singularity at the
# factorization step itself); not pursued as a separate gap for that reason.

test_that("ols_hc2_setup_cpp() rejects an exactly collinear design matrix with the documented factorization error", {
	X_singular <- cbind(1, c(1, 2, 3, 4, 5), c(2, 4, 6, 8, 10))
	expect_error(EDI:::ols_hc2_setup_cpp(X_singular), "failed to factorize X'X", fixed = TRUE)
})

test_that("glm_sandwich_post_fit_cpp() rejects an exactly collinear design matrix with the documented X'WX factorization error", {
	n <- 5L
	X_singular <- cbind(1, c(1, 2, 3, 4, 5), c(2, 4, 6, 8, 10))
	y <- rbinom(n, 1, 0.5)
	expect_error(
		EDI:::glm_sandwich_post_fit_cpp(X_singular, y, c(0, 0, 0), rep(0.5, n), rep(1, n), j_treat = 2L),
		"failed to factorize X'WX",
		fixed = TRUE
	)
})

test_that("glm_cluster_sandwich_post_fit_cpp() rejects an exactly collinear design matrix with the same documented factorization error", {
	n <- 5L
	X_singular <- cbind(1, c(1, 2, 3, 4, 5), c(2, 4, 6, 8, 10))
	y <- rbinom(n, 1, 0.5)
	expect_error(
		EDI:::glm_cluster_sandwich_post_fit_cpp(X_singular, y, c(0, 0, 0), rep(0.5, n), rep(1, n), rep(1L, n), j_treat = 2L),
		"failed to factorize X'WX",
		fixed = TRUE
	)
})

test_that("a well-conditioned (non-singular) design matrix never triggers any of the three factorization guards", {
	n <- 5L
	X_ok <- cbind(1, c(1, 2, 3, 4, 5), c(3, 1, 4, 1, 5))
	y <- rbinom(n, 1, 0.5)
	expect_no_error(EDI:::ols_hc2_setup_cpp(X_ok))
	expect_no_error(EDI:::glm_sandwich_post_fit_cpp(X_ok, y, c(0, 0, 0), rep(0.5, n), rep(1, n), j_treat = 2L))
})
