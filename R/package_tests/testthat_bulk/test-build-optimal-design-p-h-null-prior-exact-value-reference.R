library(testthat)
library(EDI)

# helper_optimal_shared.R's build_optimal_design_P_H() with prior_precision = NULL (the non-Bayesian,
# QR-based D/A-optimal construction -- documented in source as "identical construction to the former
# DesignFixedDOptimal/DesignFixedAOptimal classes") only ever had its P/H matrices checked for
# STRUCTURAL properties (symmetry, idempotency P%*%P == P, dimensions --
# test-design-core-helper-contracts.R) or, separately, exact-value checks for the prior_precision !=
# NULL (Bayesian/ridge) branch (test-optimal-search-runtime-references.R). The NULL-prior branch's
# exact numeric output was never compared to an independent formula.
#   1. P exactly matches the classical OLS hat matrix Z0(Z0'Z0)^-1 Z0', Z0 = cbind(1, X).
#   2. need_H = TRUE, interest = "all": H exactly matches Z0(Z0'Z0)^-2 Z0'.
#   3. need_H = TRUE, a subset interest: H exactly matches the sub-formula (Z0 M)[, idx] (Z0 M)[, idx]'
#      with M = (Z0'Z0)^-1 -- a materially different code path from the "all" case (subset_interest
#      branch), independently un-tested for the null-prior case until now.
#   4. need_H = FALSE: H is NULL, and P is unaffected by the need_H flag.

test_that("P exactly matches the classical OLS hat matrix Z0(Z0'Z0)^-1 Z0'", {
	X <- cbind(x1 = c(-1, 0, 1, 2), x2 = c(2, -1, 0, 1))
	Z0 <- cbind(1, X)
	P_ref <- Z0 %*% solve(t(Z0) %*% Z0) %*% t(Z0)
	ph <- EDI:::build_optimal_design_P_H(X, "all", NULL, TRUE, need_H = TRUE)
	expect_equal(ph$P, P_ref, tolerance = 1e-10, check.attributes = FALSE)
})

test_that("need_H = TRUE, interest = 'all': H exactly matches Z0(Z0'Z0)^-2 Z0'", {
	X <- cbind(x1 = c(-1, 0, 1, 2), x2 = c(2, -1, 0, 1))
	Z0 <- cbind(1, X)
	M <- solve(t(Z0) %*% Z0)
	H_ref <- Z0 %*% M %*% M %*% t(Z0)
	ph <- EDI:::build_optimal_design_P_H(X, "all", NULL, TRUE, need_H = TRUE)
	expect_equal(ph$H, H_ref, tolerance = 1e-8, check.attributes = FALSE)
})

test_that("need_H = TRUE, a subset interest: H exactly matches the sub-formula, a distinct code path from 'all'", {
	X <- cbind(x1 = c(-1, 0, 1, 2), x2 = c(2, -1, 0, 1))
	Z0 <- cbind(1, X)
	M <- solve(t(Z0) %*% Z0)
	idx0 <- EDI:::resolve_optimal_interest_z0_columns(X, "x1")
	H_ref <- tcrossprod((Z0 %*% M)[, idx0, drop = FALSE])
	ph <- EDI:::build_optimal_design_P_H(X, "x1", NULL, TRUE, need_H = TRUE)
	expect_equal(ph$H, H_ref, tolerance = 1e-8, check.attributes = FALSE)
})

test_that("need_H = FALSE: H is NULL, and P is unaffected by the need_H flag", {
	X <- cbind(x1 = c(-1, 0, 1, 2), x2 = c(2, -1, 0, 1))
	Z0 <- cbind(1, X)
	P_ref <- Z0 %*% solve(t(Z0) %*% Z0) %*% t(Z0)
	ph <- EDI:::build_optimal_design_P_H(X, "all", NULL, TRUE, need_H = FALSE)
	expect_null(ph$H)
	expect_equal(ph$P, P_ref, tolerance = 1e-10, check.attributes = FALSE)
})
