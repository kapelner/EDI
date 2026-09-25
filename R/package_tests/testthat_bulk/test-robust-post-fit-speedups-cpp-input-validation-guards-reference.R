library(testthat)
library(EDI)

# robust_post_fit_speedups.cpp: input-guard stop() branches (registry file
# R/EDI/src/robust_post_fit_speedups.cpp, weighted_opportunity 68). ols_hc2_setup_cpp/
# ols_hc2_post_fit_precomputed_cpp/glm_sandwich_post_fit_cpp/glm_cluster_sandwich_post_fit_cpp are
# fully covered on their success path by the existing test-glm-sandwich-kernels-*/test-sandwich-hc2-*
# reference tests, but their upfront defensive stop() guards were never exercised from R. Each is
# reachable via a directly-constructed malformed input, not just theoretical:
#   - ols_hc2_setup_cpp: non-finite design matrix (line 180).
#   - ols_hc2_post_fit_precomputed_cpp: dimension mismatch (217, checked against coef_hat/bread/hat),
#     non-finite inputs (220, coef_hat/bread/hat only -- NOT y), non-finite residuals (225, reached via
#     a non-finite y that slips past the 220 guard since y isn't checked there directly, then produces
#     a non-finite y - X %*% coef_hat residual).
#   - glm_sandwich_post_fit_cpp: dimension mismatch (313), non-finite inputs (316, mu_hat), non-positive
#     working weights (321).
#   - glm_cluster_sandwich_post_fit_cpp: dimension mismatch (360), non-finite inputs (363, mu_hat),
#     non-positive working weights (368), plus the cluster_id-length guard inside the internal
#     cluster_meat_robust() helper (line 143, R-reachable only through this exported function, since
#     cluster_meat_robust itself is not exported) -- a cluster_id vector shorter than n reaches this
#     distinct guard rather than the function's own top-level dimension check at 360 (which only checks
#     X_fit/y/coef_hat/mu_hat/working_weights, not cluster_id).
# The `ols_hc2_setup_cpp` factorization-failure guards (186 "failed to factorize X'X", 190 "failed to
# invert X'X") were probed with a rank-deficient design matrix (a duplicated column) and did NOT
# trigger -- Eigen's LDLT handled the singular case gracefully (returning a bread matrix with a
# zero row/column for the degenerate direction rather than reporting factorization failure), so no
# test targets those two lines; they appear to be defensive-only guards with no R-reachable trigger
# found, matching the documented defensive-stop() pattern elsewhere in this codebase (not a bug, not
# pursued further here).

set.seed(1L)
n <- 20L; p <- 3L
X <- cbind(1, matrix(rnorm(n * (p - 1L)), n, p - 1L))
y <- rnorm(n)
coef_hat <- rep(0.1, p)
mu <- rep(0.5, n)
ww <- rep(1, n)
cl <- rep(1:5, each = 4L)
setup <- ols_hc2_setup_cpp(X)

test_that("ols_hc2_setup_cpp rejects a non-finite design matrix", {
	Xbad <- X; Xbad[1, 1] <- NaN
	expect_error(ols_hc2_setup_cpp(Xbad), "non-finite design matrix")
})

test_that("ols_hc2_post_fit_precomputed_cpp rejects mismatched dimensions and non-finite coef_hat/bread/hat", {
	expect_error(
		ols_hc2_post_fit_precomputed_cpp(X, y[1:5], coef_hat, setup$bread, setup$hat, 2L),
		"dimension mismatch in ols_hc2_post_fit_precomputed_cpp"
	)
	expect_error(
		ols_hc2_post_fit_precomputed_cpp(X, y, c(NaN, 0.1, 0.1), setup$bread, setup$hat, 2L),
		"non-finite inputs"
	)
})

test_that("ols_hc2_post_fit_precomputed_cpp rejects non-finite residuals arising from a non-finite y (not caught by the earlier coef_hat/bread/hat guard)", {
	expect_error(
		ols_hc2_post_fit_precomputed_cpp(X, c(NaN, y[-1]), coef_hat, setup$bread, setup$hat, 2L),
		"non-finite residuals"
	)
})

test_that("glm_sandwich_post_fit_cpp rejects mismatched dimensions, non-finite mu_hat, and non-positive working weights", {
	expect_error(
		glm_sandwich_post_fit_cpp(X, y[1:5], coef_hat, mu, ww, 2L),
		"dimension mismatch in glm_sandwich_post_fit_cpp"
	)
	expect_error(
		glm_sandwich_post_fit_cpp(X, y, coef_hat, c(NaN, mu[-1]), ww, 2L),
		"non-finite inputs"
	)
	expect_error(
		glm_sandwich_post_fit_cpp(X, y, coef_hat, mu, c(rep(1, n - 1L), -1), 2L),
		"non-positive working weights"
	)
})

test_that("glm_cluster_sandwich_post_fit_cpp rejects mismatched dimensions, non-finite mu_hat, non-positive weights, and a mismatched cluster_id length", {
	expect_error(
		glm_cluster_sandwich_post_fit_cpp(X, y[1:5], coef_hat, mu, ww, cl, 2L),
		"dimension mismatch in glm_cluster_sandwich_post_fit_cpp"
	)
	expect_error(
		glm_cluster_sandwich_post_fit_cpp(X, y, coef_hat, c(NaN, mu[-1]), ww, cl, 2L),
		"non-finite inputs"
	)
	expect_error(
		glm_cluster_sandwich_post_fit_cpp(X, y, coef_hat, mu, c(rep(1, n - 1L), -1), cl, 2L),
		"non-positive working weights"
	)
	expect_error(
		glm_cluster_sandwich_post_fit_cpp(X, y, coef_hat, mu, ww, cl[1:5], 2L),
		"dimension mismatch in cluster_meat"
	)
})
