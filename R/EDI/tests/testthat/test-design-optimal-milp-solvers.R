# TODO-5/5b exactness tests (design_fixed_optimal.md): the "ompr" MILP solver
# layer for DesignFixedOptimal. Every solver is checked against brute-force
# enumeration of all choose(n, n_T) allocations on small instances (testing
# plan item 1): the MILP must return the true global minimum, not merely a
# good allocation. Ties (e.g. mirror optima at n_T = n/2) are handled by
# comparing objective values, never allocations.

skip_if_not_installed("ompr")
skip_if_not_installed("ompr.roi")
skip_if_not_installed("ROI.plugin.glpk")

all_allocations = function(n, n_T){
	cmb = utils::combn(n, n_T)
	w_mat = matrix(0, nrow = n, ncol = ncol(cmb))
	for (k in seq_len(ncol(cmb))) w_mat[cmb[, k], k] = 1
	w_mat
}

brute_min = function(w_mat, f){
	min(vapply(seq_len(ncol(w_mat)), function(k) f(w_mat[, k]), numeric(1)))
}

milp_test_X = function(n, p, seed){
	set.seed(seed)
	matrix(rnorm(n * p), n, p, dimnames = list(NULL, paste0("x", 1:p)))
}

test_that("prepare_optimal_objective_matrices: mahal_dist reduces to a quadratic matching the greedy kernel's criterion", {
	X_raw = milp_test_X(10, 3, 101)
	prep = EDI:::prepare_optimal_objective_matrices(X_raw, "mahal_dist")
	expect_identical(prep$kind, "quadratic")
	expect_false(prep$mahal_fell_back)
	# Greedy kernel definition: X centered, Sigma = X'X/(n-1), f = ||L^-1 X'(2w-1)/n||^2.
	n = nrow(X_raw)
	Xc = scale(X_raw, center = TRUE, scale = FALSE)
	Sigma = crossprod(Xc) / (n - 1)
	M = forwardsolve(t(chol(Sigma)), t(Xc)) / n
	w = c(rep(1, 5), rep(0, 5))
	f_greedy = sum((M %*% (2 * w - 1))^2)
	expect_equal(drop(t(w) %*% prep$Q %*% w), f_greedy, tolerance = 1e-12)
})

test_that("prepare_optimal_objective_matrices: abs_sum_diff reduces to an l1 form matching the greedy kernel's criterion", {
	X_raw = milp_test_X(10, 3, 102)
	prep = EDI:::prepare_optimal_objective_matrices(X_raw, "abs_sum_diff")
	expect_identical(prep$kind, "l1")
	n = nrow(X_raw)
	Xc = scale(X_raw, center = TRUE, scale = FALSE)
	inv_sd = 1 / sqrt(colSums(Xc^2) / (n - 1))
	X_std = sweep(Xc, 2, inv_sd, `*`)
	w = c(rep(1, 4), rep(0, 6))
	f_greedy = sum(abs(t(X_std) %*% (2 * w - 1) / n))
	expect_equal(sum(abs(prep$A %*% w)), f_greedy, tolerance = 1e-12)
})

test_that("prepare_optimal_objective_matrices: singular covariance falls back from mahal_dist to l1", {
	X_raw = milp_test_X(8, 2, 103)
	X_raw = cbind(X_raw, x3 = X_raw[, 1] + X_raw[, 2])  # exact collinearity
	prep = EDI:::prepare_optimal_objective_matrices(X_raw, "mahal_dist")
	expect_identical(prep$kind, "l1")
	expect_true(prep$mahal_fell_back)
})

test_that("milp_solve_l1 finds the brute-force global optimum (abs_sum_diff)", {
	X_raw = milp_test_X(10, 3, 104)
	prep = EDI:::prepare_optimal_objective_matrices(X_raw, "abs_sum_diff")
	res = EDI:::milp_solve_l1(prep$A, n_T = 5L)
	w_mat = all_allocations(10, 5)
	f = function(w) sum(abs(prep$A %*% w))
	expect_equal(res$objective_value, brute_min(w_mat, f), tolerance = 1e-9)
	expect_equal(f(res$w), res$objective_value, tolerance = 1e-9)
	expect_identical(sum(res$w), 5)
	expect_true(all(res$w %in% c(0, 1)))
})

test_that("milp_solve_l1 handles unbalanced n_T", {
	X_raw = milp_test_X(9, 2, 105)
	prep = EDI:::prepare_optimal_objective_matrices(X_raw, "abs_sum_diff")
	res = EDI:::milp_solve_l1(prep$A, n_T = 3L)
	w_mat = all_allocations(9, 3)
	f = function(w) sum(abs(prep$A %*% w))
	expect_equal(res$objective_value, brute_min(w_mat, f), tolerance = 1e-9)
	expect_identical(sum(res$w), 3)
})

test_that("milp_solve_quadratic finds the brute-force global optimum for w'Pw (objective D)", {
	X_raw = milp_test_X(10, 3, 106)
	P = EDI:::build_optimal_design_P_H(X_raw, interest = "treatment", prior_precision = NULL,
		standardize_covariates = TRUE, need_H = FALSE)$P
	res = EDI:::milp_solve_quadratic(P, n_T = 5L)
	w_mat = all_allocations(10, 5)
	f = function(w) drop(t(w) %*% P %*% w)
	expect_equal(res$objective_value, brute_min(w_mat, f), tolerance = 1e-9)
	expect_equal(f(res$w), res$objective_value, tolerance = 1e-9)
	expect_identical(sum(res$w), 5)
})

test_that("milp_solve_quadratic finds the brute-force global optimum for the Mahalanobis quadratic", {
	X_raw = milp_test_X(10, 2, 107)
	prep = EDI:::prepare_optimal_objective_matrices(X_raw, "mahal_dist")
	res = EDI:::milp_solve_quadratic(prep$Q, n_T = 5L)
	w_mat = all_allocations(10, 5)
	f = function(w) drop(t(w) %*% prep$Q %*% w)
	expect_equal(res$objective_value, brute_min(w_mat, f), tolerance = 1e-9)
})

test_that("milp_solve_quadratic composes with the Bayesian P_B", {
	X_raw = milp_test_X(8, 2, 108)
	P_B = EDI:::build_optimal_design_P_H(X_raw, interest = "treatment", prior_precision = 2.0,
		standardize_covariates = TRUE, need_H = FALSE)$P
	res = EDI:::milp_solve_quadratic(P_B, n_T = 4L)
	w_mat = all_allocations(8, 4)
	f = function(w) drop(t(w) %*% P_B %*% w)
	expect_equal(res$objective_value, brute_min(w_mat, f), tolerance = 1e-9)
})

test_that("milp_solve_A_dinkelbach finds the brute-force global optimum of the A ratio (interest 'all')", {
	X_raw = milp_test_X(10, 2, 109)
	PH = EDI:::build_optimal_design_P_H(X_raw, interest = "all", prior_precision = NULL,
		standardize_covariates = TRUE, need_H = TRUE)
	res = EDI:::milp_solve_A_dinkelbach(PH$P, PH$H, n_T = 5L)
	w_mat = all_allocations(10, 5)
	f = function(w) (drop(t(w) %*% PH$H %*% w) + 1) / (5 - drop(t(w) %*% PH$P %*% w))
	expect_equal(res$objective_value, brute_min(w_mat, f), tolerance = 1e-8)
	expect_equal(f(res$w), res$objective_value, tolerance = 1e-8)
	expect_true(res$converged)
	# Finite-termination sanity (testing plan item 1): report and bound the
	# outer-iteration count -- a large count on tiny n is a red flag.
	expect_lte(res$iterations, 10L)
})

test_that("milp_solve_A_dinkelbach composes with subset H_S and Bayesian H_B", {
	X_raw = milp_test_X(9, 3, 110)
	PH = EDI:::build_optimal_design_P_H(X_raw, interest = c("x1", "x3"), prior_precision = NULL,
		standardize_covariates = TRUE, need_H = TRUE)
	res = EDI:::milp_solve_A_dinkelbach(PH$P, PH$H, n_T = 4L)
	w_mat = all_allocations(9, 4)
	f = function(w) (drop(t(w) %*% PH$H %*% w) + 1) / (4 - drop(t(w) %*% PH$P %*% w))
	expect_equal(res$objective_value, brute_min(w_mat, f), tolerance = 1e-8)

	PH_B = EDI:::build_optimal_design_P_H(X_raw, interest = "all", prior_precision = 1.5,
		standardize_covariates = TRUE, need_H = TRUE)
	res_B = EDI:::milp_solve_A_dinkelbach(PH_B$P, PH_B$H, n_T = 4L)
	f_B = function(w) (drop(t(w) %*% PH_B$H %*% w) + 1) / (4 - drop(t(w) %*% PH_B$P %*% w))
	expect_equal(res_B$objective_value, brute_min(w_mat, f_B), tolerance = 1e-8)
})

test_that("assert_optimal_roi_solver enforces the closed solver set, fast-failing on typos", {
	expect_silent(EDI:::assert_optimal_roi_solver("glpk"))
	expect_error(EDI:::assert_optimal_roi_solver("gplk"), '"glpk", "gurobi", "cplex"')
	expect_error(EDI:::assert_optimal_roi_solver("cbc"), 'roi_solver')
	expect_error(EDI:::assert_optimal_roi_solver(c("glpk", "gurobi")), "roi_solver")
})

test_that("solvers reject a mirror-infeasible or degenerate n_T", {
	X_raw = milp_test_X(8, 2, 111)
	prep = EDI:::prepare_optimal_objective_matrices(X_raw, "abs_sum_diff")
	expect_error(EDI:::milp_solve_l1(prep$A, n_T = 0L), "n_T")
	expect_error(EDI:::milp_solve_l1(prep$A, n_T = 8L), "n_T")
})
