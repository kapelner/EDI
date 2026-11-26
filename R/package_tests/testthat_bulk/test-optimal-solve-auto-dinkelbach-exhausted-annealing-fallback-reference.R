library(testthat)
library(EDI)

# helper_optimal_annealing.R's optimal_solve_auto() has a distinct branch, for the "ratio" (A-
# optimality) kind within linearization_max_n, that had no test reference anywhere: when
# milp_solve_A_dinkelbach() exhausts max_dinkelbach_iter without converging, it falls back to
# annealing_solve_A_ratio() and keeps whichever of the two allocations has the LOWER objective_value
# (not unconditionally the annealing result), downgrading the certificate from "global" to
# "annealing_converged" either way. test-design-fixed-optimal.R's "objective A with interest 'all'
# routes through Dinkelbach to a global certificate" only exercises the CONVERGED (converged = TRUE)
# case; the exhausted-then-compare fallback was never reached. Verified here by mocking
# milp_solve_A_dinkelbach()/annealing_solve_A_ratio() directly (local_mocked_bindings), which also
# sidesteps needing a real MILP instance that reliably fails to converge within a tiny
# max_dinkelbach_iter (fragile/solver-dependent) -- the thing under test is optimal_solve_auto()'s own
# comparison/dispatch logic, not either solver's own correctness (each independently tested
# elsewhere).
#   1. A message naming "Dinkelbach exhausted" is emitted.
#   2. When the exhausted MILP's own objective_value is LOWER than annealing's, that allocation (not
#      annealing's) is kept, with its own objective_value -- certificate/solver are still overwritten
#      to the annealing-fallback values.
#   3. When the exhausted MILP's objective_value is NOT lower, annealing's own allocation and
#      objective_value pass through unchanged.

optimal_solve_auto <- getFromNamespace("optimal_solve_auto", "EDI")

test_that("a message naming 'Dinkelbach exhausted' is emitted when the MILP solve doesn't converge", {
	P <- diag(4); H <- diag(4)
	local_mocked_bindings(
		milp_solve_A_dinkelbach = function(P, H, n_T, roi_solver, max_dinkelbach_iter, verbose) list(w = c(1, 1, 0, 0), objective_value = 5, converged = FALSE),
		annealing_solve_A_ratio = function(P, H, n_T, n_chains, max_iter, initial_temp, cooling_rate) list(w = c(0, 1, 1, 0), objective_value = 10, certificate = "annealing_converged"),
		.package = "EDI"
	)
	expect_message(optimal_solve_auto(kind = "ratio", P = P, H = H, n_T = 2L), "Dinkelbach exhausted")
})

test_that("when the exhausted MILP's objective_value is lower than annealing's, that allocation is kept instead", {
	P <- diag(4); H <- diag(4)
	local_mocked_bindings(
		milp_solve_A_dinkelbach = function(P, H, n_T, roi_solver, max_dinkelbach_iter, verbose) list(w = c(1, 1, 0, 0), objective_value = 5, converged = FALSE),
		annealing_solve_A_ratio = function(P, H, n_T, n_chains, max_iter, initial_temp, cooling_rate) list(w = c(0, 1, 1, 0), objective_value = 10, certificate = "annealing_converged"),
		.package = "EDI"
	)
	res <- suppressMessages(optimal_solve_auto(kind = "ratio", P = P, H = H, n_T = 2L))
	expect_equal(res$w, c(1, 1, 0, 0))                                               # the exhausted MILP's own (better) allocation
	expect_equal(res$objective_value, 5)
	expect_equal(res$solver, "annealing")                                            # still relabeled as the annealing fallback
})

test_that("when the exhausted MILP's objective_value is NOT lower, annealing's own allocation passes through unchanged", {
	P <- diag(4); H <- diag(4)
	local_mocked_bindings(
		milp_solve_A_dinkelbach = function(P, H, n_T, roi_solver, max_dinkelbach_iter, verbose) list(w = c(1, 1, 0, 0), objective_value = 20, converged = FALSE),
		annealing_solve_A_ratio = function(P, H, n_T, n_chains, max_iter, initial_temp, cooling_rate) list(w = c(0, 1, 1, 0), objective_value = 10, certificate = "annealing_converged"),
		.package = "EDI"
	)
	res <- suppressMessages(optimal_solve_auto(kind = "ratio", P = P, H = H, n_T = 2L))
	expect_equal(res$w, c(0, 1, 1, 0))                                               # annealing's own allocation, untouched
	expect_equal(res$objective_value, 10)
	expect_equal(res$certificate, "annealing_converged")
	expect_equal(res$solver, "annealing")
})

# v1.0.6-TODO-183 (docs-scenarios fixed-designs F4): solver = "auto" sent abs_sum_diff to the exact
# MILP with no time limit; at n = 40 it had not returned after 400 s. It now gets
# solver_args$milp_time_limit seconds (GLPK) and then falls back to annealing with a message.
test_that("abs_sum_diff under solver = 'auto' falls back to annealing when the MILP hits milp_time_limit", {
	skip_if_not_installed("ompr"); skip_if_not_installed("ompr.roi"); skip_if_not_installed("ROI.plugin.glpk")
	set.seed(20261118)
	n = 40
	X = data.frame(weight = round(rnorm(n, 25, 3), 1), age = sample(6:12, n, replace = TRUE))
	o = DesignFixedOptimal$new(response_type = "continuous", n = n, objective = "abs_sum_diff", prob_T = 0.3,
		seed = 3, verbose = FALSE, solver_args = list(milp_time_limit = 2))
	o$add_all_subjects_to_experiment(X)
	elapsed = system.time(expect_message(o$assign_w_to_all_subjects(), "milp_time_limit"))[["elapsed"]]
	expect_lt(elapsed, 60)
	dg = o$get_optimization_diagnostics()
	expect_identical(dg$solver, "annealing")
	expect_identical(dg$optimum_certificate, "annealing_converged")
	expect_true(isTRUE(dg$milp_timed_out))
	expect_equal(sum(o$get_w()), round(0.3 * n))

	# a small instance still finishes inside the default limit with a certified optimum
	o16 = DesignFixedOptimal$new(response_type = "continuous", n = 16, objective = "abs_sum_diff", seed = 3, verbose = FALSE)
	o16$add_all_subjects_to_experiment(X[1:16, ])
	o16$assign_w_to_all_subjects()
	expect_identical(o16$get_optimization_diagnostics()$optimum_certificate, "global")

	for (bad in list(0, -1, NA_real_, "30", c(1, 2))) {
		expect_error(DesignFixedOptimal$new(response_type = "continuous", n = n, objective = "abs_sum_diff",
			solver_args = list(milp_time_limit = bad)), "milp_time_limit")
	}
})
