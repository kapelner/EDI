# Numerical-robustness review audit, 2026-11-17: prepare_optimal_objective_matrices() decides whether
# Sigma is singular with rcond(Sigma) < 1e-12. rcond is not invariant to column scaling, so a
# full-rank covariate matrix whose columns are on very different scales (for example one covariate
# around 1e-7 and another around 1) is treated as singular. The function then silently drops
# mahal_dist and uses the abs_sum_diff l1 objective (mahal_fell_back = TRUE). The Mahalanobis
# objective is scale-invariant and well defined here, and the greedy kernel's Eigen LLT succeeds on
# the same Sigma.
# Where: R/EDI/R/helper_optimal_milp_solvers.R:106 (kind: other_numerical).
# On commit 4fc58cd063bc this test failed with: Expected `prep$kind` to be identical to "quadratic".
# Differences: 1/1 mismatches x[1]: "l1" y[1]: "quadratic"
# Tracked by v1.0.6-TODO-54; remove the skip() when that fix lands.

test_that("mahal_dist objective is not dropped for a full-rank but badly scaled covariate matrix", {
	skip("known bug, v1.0.6-TODO-54")
		set.seed(1)
		n = 12
		X_raw = cbind(x1 = rnorm(n) * 1e-7, x2 = rnorm(n))
		prep = EDI:::prepare_optimal_objective_matrices(X_raw, "mahal_dist")
		expect_identical(prep$kind, "quadratic")
		expect_false(isTRUE(prep$mahal_fell_back))
		# Mahalanobis is invariant to column scaling: reference from standardized columns
		Xs = scale(X_raw, center = TRUE, scale = TRUE)
		Ss = crossprod(Xs) / (n - 1)
		Q_ref = 4 * Xs %*% solve(Ss) %*% t(Xs) / n^2
		w = c(rep(1, 6), rep(0, 6))
		f_ref = drop(t(w) %*% Q_ref %*% w)
		f_got = if (identical(prep$kind, "quadratic")) drop(t(w) %*% prep$Q %*% w) else NA_real_
		expect_equal(f_got, f_ref, tolerance = 1e-8)
})
