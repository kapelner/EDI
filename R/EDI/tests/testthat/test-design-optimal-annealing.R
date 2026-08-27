# TODO-6 tests (design_fixed_optimal.md): the dedicated native C++
# simulated-annealing solver for DesignFixedOptimal -- swap neighborhood,
# Metropolis acceptance, geometric cooling, n_chains independent BCRD-started
# chains with argmin selection. Per testing-plan item 2: best-of-chains
# dominance, seed determinism, and a bounded (not zero) miss rate against the
# certified global optimum on brute-forceable instances. Also covers the
# "auto" solver dispatch: MILP within EDI_OPTIMAL_DEFAULT_LINEARIZATION_MAX_N,
# annealing beyond it.

annealing_test_X = function(n, p, seed){
	set.seed(seed)
	matrix(rnorm(n * p), n, p, dimnames = list(NULL, paste0("x", 1:p)))
}

test_that("annealing_solve_quadratic returns a valid, seed-deterministic allocation", {
	X = annealing_test_X(12, 3, 201)
	P = EDI:::build_optimal_design_P_H(X, interest = "treatment", prior_precision = NULL,
		standardize_covariates = TRUE, need_H = FALSE)$P
	set.seed(5)
	res1 = EDI:::annealing_solve_quadratic(P, n_T = 6L, n_chains = 3L, max_iter = 2000L)
	set.seed(5)
	res2 = EDI:::annealing_solve_quadratic(P, n_T = 6L, n_chains = 3L, max_iter = 2000L)
	expect_identical(res1$w, res2$w)
	expect_identical(res1$objective_value, res2$objective_value)
	expect_identical(sum(res1$w), 6)
	expect_true(all(res1$w %in% c(0, 1)))
	expect_identical(res1$certificate, "annealing_converged")
	expect_length(res1$chain_values, 3L)
})

test_that("annealing best-of-chains objective <= every individual chain value", {
	X = annealing_test_X(14, 4, 202)
	P = EDI:::build_optimal_design_P_H(X, interest = "treatment", prior_precision = NULL,
		standardize_covariates = TRUE, need_H = FALSE)$P
	set.seed(6)
	res = EDI:::annealing_solve_quadratic(P, n_T = 7L, n_chains = 5L, max_iter = 3000L)
	expect_true(all(res$objective_value <= res$chain_values + 1e-12))
	expect_equal(res$objective_value, min(res$chain_values), tolerance = 1e-12)
	# The incremental delta bookkeeping must agree with a from-scratch evaluation.
	expect_equal(drop(t(res$w) %*% P %*% res$w), res$objective_value, tolerance = 1e-9)
})

test_that("annealing finds the certified global optimum with high frequency (quadratic, brute-forceable n)", {
	skip_on_cran()
	skip_if_not_installed("ompr"); skip_if_not_installed("ompr.roi"); skip_if_not_installed("ROI.plugin.glpk")
	X = annealing_test_X(10, 2, 203)
	prep = EDI:::prepare_optimal_objective_matrices(X, "mahal_dist")
	exact = EDI:::milp_solve_quadratic(prep$Q, n_T = 5L)
	hits = 0L; trials = 20L
	for (k in seq_len(trials)) {
		set.seed(300 + k)
		res = EDI:::annealing_solve_quadratic(prep$Q, n_T = 5L, n_chains = 4L, max_iter = 4000L)
		if (res$objective_value <= exact$objective_value + 1e-9) hits = hits + 1L
	}
	# Asymptotic method: bound the miss rate, don't require zero misses.
	expect_gte(hits, ceiling(0.8 * trials))
})

test_that("annealing_solve_l1 matches the MILP global optimum on small instances", {
	skip_if_not_installed("ompr"); skip_if_not_installed("ompr.roi"); skip_if_not_installed("ROI.plugin.glpk")
	X = annealing_test_X(10, 3, 204)
	prep = EDI:::prepare_optimal_objective_matrices(X, "abs_sum_diff")
	exact = EDI:::milp_solve_l1(prep$A, n_T = 5L)
	set.seed(7)
	res = EDI:::annealing_solve_l1(prep$A, n_T = 5L, n_chains = 6L, max_iter = 4000L)
	expect_identical(sum(res$w), 5)
	expect_equal(sum(abs(prep$A %*% res$w)), res$objective_value, tolerance = 1e-9)
	expect_lte(res$objective_value, exact$objective_value + 1e-6)
})

test_that("annealing_solve_A_ratio matches the Dinkelbach global optimum on small instances", {
	skip_if_not_installed("ompr"); skip_if_not_installed("ompr.roi"); skip_if_not_installed("ROI.plugin.glpk")
	X = annealing_test_X(10, 2, 205)
	PH = EDI:::build_optimal_design_P_H(X, interest = "all", prior_precision = NULL,
		standardize_covariates = TRUE, need_H = TRUE)
	exact = EDI:::milp_solve_A_dinkelbach(PH$P, PH$H, n_T = 5L)
	set.seed(8)
	res = EDI:::annealing_solve_A_ratio(PH$P, PH$H, n_T = 5L, n_chains = 6L, max_iter = 4000L)
	f = function(w) (drop(t(w) %*% PH$H %*% w) + 1) / (5 - drop(t(w) %*% PH$P %*% w))
	expect_equal(f(res$w), res$objective_value, tolerance = 1e-9)
	expect_lte(res$objective_value, exact$objective_value + 1e-6)
})

test_that("annealing handles unbalanced n_T", {
	X = annealing_test_X(11, 2, 206)
	P = EDI:::build_optimal_design_P_H(X, interest = "treatment", prior_precision = NULL,
		standardize_covariates = TRUE, need_H = FALSE)$P
	set.seed(9)
	res = EDI:::annealing_solve_quadratic(P, n_T = 3L, n_chains = 2L, max_iter = 1000L)
	expect_identical(sum(res$w), 3)
})

test_that("annealing validates its arguments", {
	X = annealing_test_X(8, 2, 207)
	P = EDI:::build_optimal_design_P_H(X, interest = "treatment", prior_precision = NULL,
		standardize_covariates = TRUE, need_H = FALSE)$P
	expect_error(EDI:::annealing_solve_quadratic(P, n_T = 0L), "n_T")
	expect_error(EDI:::annealing_solve_quadratic(P, n_T = 4L, n_chains = 0L), "n_chains")
	expect_error(EDI:::annealing_solve_quadratic(P, n_T = 4L, max_iter = 0L), "max_iter")
	expect_error(EDI:::annealing_solve_quadratic(P, n_T = 4L, cooling_rate = 1.5), "cooling_rate")
	expect_error(EDI:::annealing_solve_quadratic(P, n_T = 4L, initial_temp = -1), "initial_temp")
})

test_that("optimal_solve_auto dispatches to the exact MILP within linearization_max_n", {
	skip_if_not_installed("ompr"); skip_if_not_installed("ompr.roi"); skip_if_not_installed("ROI.plugin.glpk")
	X = annealing_test_X(10, 2, 208)
	prep = EDI:::prepare_optimal_objective_matrices(X, "mahal_dist")
	set.seed(10)
	res = EDI:::optimal_solve_auto(kind = "quadratic", Q = prep$Q, n_T = 5L)
	expect_identical(res$solver, "ompr")
	expect_identical(res$certificate, "global")
	exact = EDI:::milp_solve_quadratic(prep$Q, n_T = 5L)
	expect_equal(res$objective_value, exact$objective_value, tolerance = 1e-9)
})

test_that("optimal_solve_auto falls back to annealing past linearization_max_n, with a message", {
	n = EDI:::EDI_OPTIMAL_DEFAULT_LINEARIZATION_MAX_N + 2L
	X = annealing_test_X(n, 3, 209)
	prep = EDI:::prepare_optimal_objective_matrices(X, "mahal_dist")
	set.seed(11)
	expect_message(
		res <- EDI:::optimal_solve_auto(kind = "quadratic", Q = prep$Q, n_T = n %/% 2L, max_iter = 1000L),
		"annealing"
	)
	expect_identical(res$solver, "annealing")
	expect_identical(res$certificate, "annealing_converged")
	expect_identical(sum(res$w), n %/% 2L + 0)
})

test_that("optimal_solve_auto: l1 always uses the exact MILP regardless of n (no linearization blowup)", {
	skip_if_not_installed("ompr"); skip_if_not_installed("ompr.roi"); skip_if_not_installed("ROI.plugin.glpk")
	n = EDI:::EDI_OPTIMAL_DEFAULT_LINEARIZATION_MAX_N + 4L
	X = annealing_test_X(n, 2, 210)
	prep = EDI:::prepare_optimal_objective_matrices(X, "abs_sum_diff")
	res = EDI:::optimal_solve_auto(kind = "l1", A = prep$A, n_T = n %/% 2L)
	expect_identical(res$solver, "ompr")
	expect_identical(res$certificate, "global")
})

test_that("optimal_solve_auto: ratio dispatches Dinkelbach within the cutoff, annealing beyond it", {
	skip_if_not_installed("ompr"); skip_if_not_installed("ompr.roi"); skip_if_not_installed("ROI.plugin.glpk")
	X = annealing_test_X(10, 2, 211)
	PH = EDI:::build_optimal_design_P_H(X, interest = "all", prior_precision = NULL,
		standardize_covariates = TRUE, need_H = TRUE)
	res = EDI:::optimal_solve_auto(kind = "ratio", P = PH$P, H = PH$H, n_T = 5L)
	expect_identical(res$solver, "ompr")
	expect_identical(res$certificate, "global")

	n = EDI:::EDI_OPTIMAL_DEFAULT_LINEARIZATION_MAX_N + 2L
	X_big = annealing_test_X(n, 3, 212)
	PH_big = EDI:::build_optimal_design_P_H(X_big, interest = "all", prior_precision = NULL,
		standardize_covariates = TRUE, need_H = TRUE)
	set.seed(12)
	expect_message(
		res_big <- EDI:::optimal_solve_auto(kind = "ratio", P = PH_big$P, H = PH_big$H,
			n_T = n %/% 2L, max_iter = 1000L),
		"annealing"
	)
	expect_identical(res_big$solver, "annealing")
})
