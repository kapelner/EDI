library(testthat)
library(EDI)

# helper_optimal_shared.R's build_optimal_design_P_H() with a Bayesian prior_precision has TWO
# materially different sub-branches, gated on is.matrix(prior_precision): a MATRIX prior (R0 =
# prior_precision directly, standardize_covariates ignored) -- already exactly verified
# (test-optimal-search-runtime-references.R's "Bayesian optimal matrices match ridge inverse
# references without scaling") -- and a SCALAR tau (R0 = diag(c(0, rep(tau, p))), with
# standardize_covariates optionally scale()-ing X first, and a documented constant-column-scales-to-
# NaN-then-dropped-to-0 special case). The scalar-tau branch had never been reached by any existing
# test at all (every existing call site passes either prior_precision = NULL or an explicit matrix).
#   1. Scalar tau, standardize_covariates = FALSE: P and H exactly match the ridge formula on the
#      raw (unscaled) X.
#   2. Scalar tau, standardize_covariates = TRUE: P exactly matches the same ridge formula computed
#      on scale(X) instead of raw X.
#   3. A constant covariate column under standardize_covariates = TRUE: scale() produces a NaN column
#      (zero scale), which the documented special case then zeroes out before building Z0 -- P exactly
#      matches that same zeroed-NaN construction done independently.
#   4. A subset interest with scalar tau exactly matches its own distinct sub-formula (the same
#      subset_interest branch already verified for the matrix-prior and null-prior cases, now for
#      scalar tau).

test_that("scalar tau, standardize_covariates = FALSE: P and H exactly match the ridge formula on raw X", {
	X <- cbind(x1 = c(-1, 0, 1, 2), x2 = c(2, -1, 0, 1))
	tau <- 0.5
	Z0 <- cbind(1, X)
	pz <- ncol(Z0)
	R0 <- diag(c(0, rep(tau, pz - 1)), nrow = pz)
	V_ref <- solve(crossprod(Z0) + R0)
	P_ref <- Z0 %*% V_ref %*% t(Z0)
	H_ref <- Z0 %*% V_ref %*% V_ref %*% t(Z0)

	ph <- EDI:::build_optimal_design_P_H(X, "all", tau, FALSE, need_H = TRUE)
	expect_equal(ph$P, P_ref, tolerance = 1e-10, check.attributes = FALSE)
	expect_equal(ph$H, H_ref, tolerance = 1e-8, check.attributes = FALSE)
})

test_that("scalar tau, standardize_covariates = TRUE: P exactly matches the ridge formula computed on scale(X)", {
	X <- cbind(x1 = c(-1, 0, 1, 2), x2 = c(2, -1, 0, 1))
	tau <- 0.5
	Xs <- scale(X)
	Z0s <- cbind(1, Xs)
	pz <- ncol(Z0s)
	R0 <- diag(c(0, rep(tau, pz - 1)), nrow = pz)
	V_ref <- solve(crossprod(Z0s) + R0)
	P_ref <- Z0s %*% V_ref %*% t(Z0s)

	ph <- EDI:::build_optimal_design_P_H(X, "all", tau, TRUE, need_H = FALSE)
	expect_equal(ph$P, P_ref, tolerance = 1e-10, check.attributes = FALSE)
})

test_that("a constant covariate column under standardize_covariates = TRUE: the NaN-from-scale() special case zeroes the column before building Z0", {
	X <- cbind(x1 = c(-1, 0, 1, 2), x2 = rep(5, 4))                                 # x2 is constant
	tau <- 0.5
	Xs <- scale(X)
	expect_true(all(!is.finite(Xs[, "x2"])))                                        # confirms the NaN premise
	Xs[!is.finite(Xs)] <- 0
	Z0s <- cbind(1, Xs)
	pz <- ncol(Z0s)
	R0 <- diag(c(0, rep(tau, pz - 1)), nrow = pz)
	V_ref <- solve(crossprod(Z0s) + R0)
	P_ref <- Z0s %*% V_ref %*% t(Z0s)

	ph <- EDI:::build_optimal_design_P_H(X, "all", tau, TRUE, need_H = FALSE)
	expect_equal(ph$P, P_ref, tolerance = 1e-10, check.attributes = FALSE)
})

test_that("a subset interest with scalar tau exactly matches its own distinct sub-formula", {
	X <- cbind(x1 = c(-1, 0, 1, 2), x2 = c(2, -1, 0, 1))
	tau <- 0.5
	Z0 <- cbind(1, X)
	pz <- ncol(Z0)
	R0 <- diag(c(0, rep(tau, pz - 1)), nrow = pz)
	V_ref <- solve(crossprod(Z0) + R0)
	idx0 <- EDI:::resolve_optimal_interest_z0_columns(X, "x1")
	H_ref <- tcrossprod((Z0 %*% V_ref)[, idx0, drop = FALSE])

	ph <- EDI:::build_optimal_design_P_H(X, "x1", tau, FALSE, need_H = TRUE)
	expect_equal(ph$H, H_ref, tolerance = 1e-8, check.attributes = FALSE)
})
