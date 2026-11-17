# Numerical-robustness review audit, 2026-11-17: When the covariates are linearly independent but
# become collinear once the intercept is added (e.g. x2 = x1 + 1, or two 0/1 indicators that sum to
# 1), the non-Bayesian criterion matrix is built as P = Q Q' from qr.Q(qr(cbind(1, X))) without
# truncating to the QR rank. P then projects onto a rank(Z0)+1 dimensional space that includes an
# arbitrary Householder direction, rather than onto col(Z0). The D/A search therefore optimizes the
# wrong criterion: trace(P) is 3 instead of 2 for X = [x1, x1 + 1].
# Where: R/EDI/R/helper_optimal_shared.R:107 (kind: other_numerical).
# On commit 4fc58cd063bc this test failed with: Expected `sum(diag(P))` to equal 2. Differences: 1/1
# mismatches [1] 3 - 2 == 1
# Tracked by v1.0.6-TODO-57; remove the skip() when that fix lands.

test_that("D-optimal projection P is the hat matrix of [1, X] when a covariate is an affine shift of another", {
	skip("known bug, v1.0.6-TODO-57")
		set.seed(1)
		n = 30L
		x1 = rnorm(n)
		X = data.frame(x1 = x1, x2 = x1 + 1)
		des = DesignFixedGreedyDOptimal$new(response_type = "continuous", n = n, verbose = FALSE, seed = 1L)
		des$add_all_subjects_to_experiment(X)
		W = des$draw_ws_according_to_design(r = 2L)
		expect_equal(dim(W), c(n, 2L))
		P = des$.__enclos_env__$private$P
		Z0 = cbind(1, x1)
		P_true = Z0 %*% solve(crossprod(Z0)) %*% t(Z0)
		expect_equal(sum(diag(P)), 2, tolerance = 1e-8)
		expect_equal(unname(P), unname(P_true), tolerance = 1e-8)
})
