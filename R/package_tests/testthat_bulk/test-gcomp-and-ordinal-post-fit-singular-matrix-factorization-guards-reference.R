library(testthat)
library(EDI)

# Siblings of the robust_post_fit_speedups.cpp singular-matrix guards closed last iteration
# (test-robust-post-fit-speedups-singular-matrix-factorization-guards-reference.R), in two other files:
#   - gcomp_logistic_post_fit_cpp() / gcomp_logistic_cluster_post_fit_cpp() (gcomp_speedups.cpp) share
#     the internal compute_gcomp_logistic_post_fit() helper's LDLT factorization of X'WX (W = mu(1-mu)
#     the logistic working-weight diagonal), stopping with "failed to factorize X'WX" when it fails.
#   - ordinal_gcomp_post_fit_cpp() (fast_ordinal_regression.cpp) instead factorizes the ordinal model's
#     Hessian via a full-pivot LU decomposition, stopping with "failed to invert ordinal Hessian" when
#     it's singular.
# A codebase-wide grep confirmed both exact messages had zero test references anywhere, despite all
# three functions being otherwise well-tested elsewhere (including their separate dimension-mismatch
# guards, closed two iterations ago in test-post-fit-speedup-kernels-dimension-mismatch-guards-
# reference.R) -- every existing reference fits on a well-conditioned design matrix. Reached the same
# way as the robust_post_fit_speedups.cpp siblings: a design matrix with an exactly collinear column,
# making X'WX (or, for the ordinal Hessian, the underlying X'X block) exactly singular.

test_that("gcomp_logistic_post_fit_cpp() rejects an exactly collinear design matrix with the documented X'WX factorization error", {
	n <- 5L
	X_singular <- cbind(1, c(1, 2, 3, 4, 5), c(2, 4, 6, 8, 10))
	y <- rbinom(n, 1, 0.5)
	expect_error(
		EDI:::gcomp_logistic_post_fit_cpp(X_singular, y, c(0, 0, 0), rep(0.5, n), j_treat = 2L),
		"failed to factorize X'WX",
		fixed = TRUE
	)
})

test_that("gcomp_logistic_cluster_post_fit_cpp() rejects the same collinear design matrix with the same documented error", {
	n <- 5L
	X_singular <- cbind(1, c(1, 2, 3, 4, 5), c(2, 4, 6, 8, 10))
	y <- rbinom(n, 1, 0.5)
	expect_error(
		EDI:::gcomp_logistic_cluster_post_fit_cpp(X_singular, y, c(0, 0, 0), rep(0.5, n), rep(1L, n), j_treat = 2L),
		"failed to factorize X'WX",
		fixed = TRUE
	)
})

test_that("ordinal_gcomp_post_fit_cpp() rejects a design matrix producing a singular ordinal-model Hessian with the documented error", {
	n <- 20L
	X_singular <- cbind(1, c(1:10, 1:10), c(2 * (1:10), 2 * (1:10)))
	y <- rep(1:3, length.out = n)
	expect_error(
		EDI:::ordinal_gcomp_post_fit_cpp(X_singular, y, c(0, 0, 0), c(-0.5, 0.5), j_treat = 2L),
		"failed to invert ordinal Hessian",
		fixed = TRUE
	)
})

test_that("a well-conditioned (non-singular) design matrix never triggers either guard", {
	n <- 5L
	X_ok <- cbind(1, c(1, 2, 3, 4, 5), c(3, 1, 4, 1, 5))
	y <- rbinom(n, 1, 0.5)
	expect_no_error(EDI:::gcomp_logistic_post_fit_cpp(X_ok, y, c(0, 0, 0), rep(0.5, n), j_treat = 2L))
})
