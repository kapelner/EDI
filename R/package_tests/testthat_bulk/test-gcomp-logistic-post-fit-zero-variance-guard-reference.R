library(testthat)
library(EDI)

# gcomp_logistic_post_fit_cpp() / gcomp_logistic_cluster_post_fit_cpp()'s shared internal
# compute_gcomp_logistic_post_fit() helper (gcomp_speedups.cpp) has a final sandwich-variance sanity
# check: after computing the robust covariance vcov_robust = bread * meat * bread, it stops with
# "non-positive treatment variance" if the diagonal entry for the treatment coefficient isn't strictly
# positive. A codebase-wide grep confirmed this exact message had zero test references anywhere,
# despite both functions being otherwise well-tested elsewhere (including the sibling non-finite-input
# and singular-matrix guards closed in the last two iterations). Reached with a genuinely degenerate
# but well-conditioned input: when y is passed in EXACTLY equal to mu_hat (a "perfect fit" with zero
# residuals for every observation), the meat matrix meat = X' diag(resid^2) X is the exact zero matrix,
# so vcov_robust is exactly zero and every diagonal entry -- including the treatment coefficient's --
# is 0, not merely small; this is qualitatively different from the sibling "non-finite or boundary
# fitted values" guard closed last iteration (that one checks mu_hat's own range, this one checks the
# DERIVED variance after a successful factorization).

test_that("gcomp_logistic_post_fit_cpp() rejects a perfect-fit input (y == mu_hat, zero residuals) with the documented zero-variance error", {
	n <- 5L
	X_ok <- cbind(1, c(1, 2, 3, 4, 5))
	mu_hat <- rep(0.5, n)
	expect_error(
		EDI:::gcomp_logistic_post_fit_cpp(X_ok, mu_hat, c(0, 0), mu_hat, j_treat = 2L),
		"non-positive treatment variance",
		fixed = TRUE
	)
})

test_that("gcomp_logistic_cluster_post_fit_cpp() rejects the same perfect-fit input with the same documented error", {
	n <- 5L
	X_ok <- cbind(1, c(1, 2, 3, 4, 5))
	mu_hat <- rep(0.5, n)
	expect_error(
		EDI:::gcomp_logistic_cluster_post_fit_cpp(X_ok, mu_hat, c(0, 0), mu_hat, rep(1L, n), j_treat = 2L),
		"non-positive treatment variance",
		fixed = TRUE
	)
})

test_that("genuine residual variation (y != mu_hat) never triggers the guard", {
	n <- 5L
	X_ok <- cbind(1, c(1, 2, 3, 4, 5))
	y <- c(0, 1, 0, 1, 1)
	mu_hat <- rep(0.5, n)
	expect_no_error(EDI:::gcomp_logistic_post_fit_cpp(X_ok, y, c(0, 0), mu_hat, j_treat = 2L))
})
