library(testthat)
library(EDI)

# Continuing the singular-matrix-factorization guard sweep from the last two iterations, this file
# covers the sibling "non-finite input" guards on the same post-fit speedup kernels, each an
# early-exit check on a specific argument before any real linear-algebra work:
#   - ols_hc2_setup_cpp() (robust_post_fit_speedups.cpp): "non-finite design matrix" when X_fit itself
#     contains NA/NaN/Inf.
#   - ols_hc2_post_fit_precomputed_cpp() (same file): "non-finite residuals" -- y is NOT itself
#     finiteness-checked (only coef_hat/bread/hat are), so a non-finite y propagates through resid = y
#     - X_fit %*% coef_hat and is caught here instead.
#   - gcomp_logistic_post_fit_cpp() / gcomp_logistic_cluster_post_fit_cpp() (gcomp_speedups.cpp), both
#     sharing the internal compute_gcomp_logistic_post_fit() helper: "non-finite or boundary fitted
#     values" when any mu_hat entry is non-finite or outside the open interval (0, 1) -- exactly 0 or 1
#     counts as a boundary violation, not just NaN/Inf.
# A codebase-wide grep confirmed all 4 exact messages had zero test references anywhere, despite all 4
# functions being otherwise well-tested elsewhere (including their dimension-mismatch and singular-
# matrix guards, closed in the previous two iterations) -- every existing reference supplies clean,
# finite, in-range inputs.

test_that("ols_hc2_setup_cpp() rejects a design matrix containing a non-finite value", {
	X_bad <- cbind(1, c(1, 2, NA, 4, 5))
	expect_error(EDI:::ols_hc2_setup_cpp(X_bad), "non-finite design matrix", fixed = TRUE)
})

test_that("ols_hc2_post_fit_precomputed_cpp() rejects a y vector containing a non-finite value, via its residuals", {
	n <- 5L
	X_ok <- cbind(1, c(1, 2, 3, 4, 5))
	bread_ok <- solve(t(X_ok) %*% X_ok)
	hat_ok <- diag(X_ok %*% bread_ok %*% t(X_ok))
	y_bad <- c(1, 2, NA, 4, 5)
	expect_error(
		EDI:::ols_hc2_post_fit_precomputed_cpp(X_ok, y_bad, c(0, 0), bread_ok, hat_ok, j_treat = 2L),
		"non-finite residuals",
		fixed = TRUE
	)
})

test_that("gcomp_logistic_post_fit_cpp() and its cluster sibling both reject a boundary (exactly 0 or 1) or non-finite mu_hat entry", {
	n <- 5L
	X_ok <- cbind(1, c(1, 2, 3, 4, 5))
	y <- rbinom(n, 1, 0.5)
	mu_boundary <- c(0.5, 0.5, 0.5, 0.5, 1.0)
	mu_nonfinite <- c(0.5, 0.5, NA_real_, 0.5, 0.5)

	expect_error(
		EDI:::gcomp_logistic_post_fit_cpp(X_ok, y, c(0, 0), mu_boundary, j_treat = 2L),
		"non-finite or boundary fitted values",
		fixed = TRUE
	)
	expect_error(
		EDI:::gcomp_logistic_post_fit_cpp(X_ok, y, c(0, 0), mu_nonfinite, j_treat = 2L),
		"non-finite or boundary fitted values",
		fixed = TRUE
	)
	expect_error(
		EDI:::gcomp_logistic_cluster_post_fit_cpp(X_ok, y, c(0, 0), mu_boundary, rep(1L, n), j_treat = 2L),
		"non-finite or boundary fitted values",
		fixed = TRUE
	)
})

test_that("well-formed, finite, in-range inputs never trigger any of the four guards", {
	n <- 5L
	X_ok <- cbind(1, c(1, 2, 3, 4, 5))
	y <- rbinom(n, 1, 0.5)
	bread_ok <- solve(t(X_ok) %*% X_ok)
	hat_ok <- diag(X_ok %*% bread_ok %*% t(X_ok))
	expect_no_error(EDI:::ols_hc2_setup_cpp(X_ok))
	expect_no_error(EDI:::ols_hc2_post_fit_precomputed_cpp(X_ok, as.numeric(y), c(0, 0), bread_ok, hat_ok, j_treat = 2L))
	expect_no_error(EDI:::gcomp_logistic_post_fit_cpp(X_ok, y, c(0, 0), rep(0.5, n), j_treat = 2L))
})
