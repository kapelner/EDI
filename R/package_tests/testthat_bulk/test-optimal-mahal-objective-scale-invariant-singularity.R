# v1.0.6-TODO-18: prepare_optimal_objective_matrices() judged Sigma singular with rcond(Sigma), which is
# not invariant to column scaling, so full-rank covariates on very different scales silently dropped
# the mahal_dist objective for l1. Singularity is now tested on the correlation matrix.

test_that("mahal_dist stays quadratic and is invariant to rescaling a covariate column", {
	set.seed(54)
	n = 10
	X = cbind(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	ref = EDI:::prepare_optimal_objective_matrices(X, "mahal_dist")
	expect_identical(ref$kind, "quadratic")
	for (s in c(1e-9, 1e-7, 1e7, 1e9)) {
		Xs = X
		Xs[, 2] = Xs[, 2] * s
		prep = EDI:::prepare_optimal_objective_matrices(Xs, "mahal_dist")
		expect_identical(prep$kind, "quadratic")
		expect_false(prep$mahal_fell_back)
		expect_equal(prep$Q, ref$Q, tolerance = 1e-7)
	}
})

test_that("mahal_dist still falls back for collinear, constant and near-constant columns at any scale", {
	set.seed(55)
	n = 10
	x1 = rnorm(n) * 1e-7
	x2 = rnorm(n)
	cases = list(
		collinear = cbind(x1, x2, x3 = x1 * 1e7 + x2),
		constant = cbind(x1, x2, x3 = rep(3, n)),
		near_constant = cbind(x1, x2, x3 = 1e6 + rnorm(n) * 1e-12)
	)
	for (nm in names(cases)) {
		prep = EDI:::prepare_optimal_objective_matrices(cases[[nm]], "mahal_dist")
		expect_identical(prep$kind, "l1", info = nm)
		expect_true(prep$mahal_fell_back, info = nm)
	}
})

test_that("badly scaled mahal_dist MILP picks the same allocation as the standardized covariates", {
	skip_if_not_installed("ompr")
	skip_if_not_installed("ompr.roi")
	skip_if_not_installed("ROI.plugin.glpk")
	set.seed(56)
	n = 8
	X = cbind(x1 = rnorm(n) * 1e-7, x2 = rnorm(n))
	prep = EDI:::prepare_optimal_objective_matrices(X, "mahal_dist")
	prep_std = EDI:::prepare_optimal_objective_matrices(scale(X), "mahal_dist")
	expect_identical(prep$kind, "quadratic")
	res = EDI:::milp_solve_quadratic(prep$Q, n_T = 4L)
	res_std = EDI:::milp_solve_quadratic(prep_std$Q, n_T = 4L)
	expect_equal(res$objective_value, res_std$objective_value, tolerance = 1e-8)
})
