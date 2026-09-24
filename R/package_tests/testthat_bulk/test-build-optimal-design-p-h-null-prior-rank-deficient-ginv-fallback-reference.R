library(testthat)
library(EDI)

# helper_optimal_shared.R's build_optimal_design_P_H() with prior_precision = NULL computes
# M = tryCatch(solve(t(R) %*% R), error = function(e) MASS::ginv(t(R) %*% R)) when building H --
# a Moore-Penrose pseudoinverse fallback for a rank-deficient design (R from the QR decomposition of
# Z0 = cbind(1, X), non-invertible when X has an exactly collinear covariate pair). Every existing
# reference to build_optimal_design_P_H() (this session's own null-prior/scalar-tau exact-value tests
# included) uses a full-rank X, so solve() always succeeds and this fallback -- confirmed via a
# zero-hit grep for "ginv" anywhere in the whole test suite -- had never actually been reached.
#   1. With an exactly collinear covariate pair, solve(t(R) %*% R) genuinely fails ("computationally
#      singular"), confirming the fallback's premise for this fixture.
#   2. MASS::ginv() is invoked exactly once (a call-count probe) when building H for that same
#      rank-deficient X, and P/H exactly match an independently reconstructed pseudoinverse-based
#      computation.
#   3. On an ordinary full-rank X, MASS::ginv() is never invoked (a negative control confirming the
#      fallback is genuinely conditional, not always taken).

test_that("with an exactly collinear covariate pair, solve(t(R) %*% R) genuinely fails, confirming the fallback's premise", {
	set.seed(1L)
	X <- cbind(x1 = rnorm(6), x2 = NA_real_)
	X[, 2] <- 2 * X[, 1]                                                            # exactly collinear
	Z0 <- cbind(1, X)
	R <- qr.R(qr(Z0))
	# 2026-09-24: the exact wording ("computationally singular" vs "system is
	# exactly singular: U[i,j] = 0") depends on which LAPACK backend base R's
	# solve() is linked against -- confirmed to differ between this session's
	# local environment and CI (run 35960688203 shard 45), an environment
	# detail entirely outside EDI's own code (the actual fast-optimal-design
	# fallback only cares that solve() throws SOME error, not its text).
	# Matching either known variant instead of pinning one exact message.
	expect_error(solve(t(R) %*% R), "computationally singular|exactly singular")
})

test_that("MASS::ginv() is invoked exactly once for a rank-deficient X, and P/H exactly match an independent pseudoinverse reconstruction", {
	set.seed(1L)
	X <- cbind(x1 = rnorm(6), x2 = NA_real_)
	X[, 2] <- 2 * X[, 1]

	ginv_calls <- 0L
	orig_ginv <- MASS::ginv
	local_mocked_bindings(ginv = function(...) { ginv_calls <<- ginv_calls + 1L; orig_ginv(...) }, .package = "MASS")
	ph <- EDI:::build_optimal_design_P_H(X, "all", NULL, TRUE, need_H = TRUE)
	expect_equal(ginv_calls, 1L)

	Z0 <- cbind(1, X)
	qrZ <- qr(Z0)
	Q <- qr.Q(qrZ); R <- qr.R(qrZ)
	M_ref <- MASS::ginv(t(R) %*% R)
	P_ref <- Q %*% t(Q)
	H_ref <- Z0 %*% (M_ref %*% M_ref) %*% t(Z0)
	expect_equal(ph$P, P_ref, tolerance = 1e-8, check.attributes = FALSE)
	expect_equal(ph$H, H_ref, tolerance = 1e-6, check.attributes = FALSE)
})

test_that("on an ordinary full-rank X, MASS::ginv() is never invoked", {
	X <- cbind(x1 = c(-1, 0, 1, 2), x2 = c(2, -1, 0, 1))
	ginv_calls <- 0L
	orig_ginv <- MASS::ginv
	local_mocked_bindings(ginv = function(...) { ginv_calls <<- ginv_calls + 1L; orig_ginv(...) }, .package = "MASS")
	EDI:::build_optimal_design_P_H(X, "all", NULL, TRUE, need_H = TRUE)
	expect_equal(ginv_calls, 0L)
})
