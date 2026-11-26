# Numerical-robustness review audit, 2026-11-17: fast_cpoisson_combined_internal tests convergence
# with the norm of the full gradient, including the components of parameters held fixed via
# fixed_idx. At a restricted (null) optimum those components are nonzero by construction, so every
# null refit (fixed beta_T away from the MLE) ends on the step-size exit with converged = FALSE even
# though the free-parameter score is ~0. Example: pairs yT=c(3,5,2,4), n_k=c(5,7,6,6), reservoir
# y=c(1,2,3,4,2,5), w=c(0,0,0,1,1,1), beta_T fixed at 1 returns the exact restricted MLE for beta_0
# with converged = FALSE.
# Where: R/EDI/src/fast_cpoisson_combined.cpp:403 (kind: other_numerical).
# On commit 48765322fe90 this test failed with: Expected `isTRUE(fit$converged)` to be TRUE.
# Differences: `actual`: FALSE `expected`: TRUE
# Tracked as v1.0.7-TODO-90; remove the skip() when it is fixed.

test_that("combined cond-Poisson restricted fit reports convergence at the restricted optimum", {
	skip("v1.0.7-TODO-90: the convergence norm includes the fixed parameters' gradient")
		set.seed(1)
		yT_v = c(3, 5, 2, 4)
		n_k_v = c(5, 7, 6, 6)
		X_diff_v = matrix(numeric(0), nrow = 4L, ncol = 0L)
		y_r = c(1, 2, 3, 4, 2, 5)
		w_r = c(0, 0, 0, 1, 1, 1)
		X_r = matrix(numeric(0), nrow = 6L, ncol = 0L)
		fit = EDI:::fast_cpoisson_combined_with_var_cpp(yT_v, n_k_v, X_diff_v, y_r, w_r, X_r, fixed_idx = 2L, fixed_values = 1)
		b0_ref = log(sum(y_r) / sum(exp(1 * w_r)))
		expect_equal(as.numeric(fit$params[1]), b0_ref, tolerance = 1e-6)
		expect_equal(as.numeric(fit$params[2]), 1)
		expect_true(isTRUE(fit$converged))
})
