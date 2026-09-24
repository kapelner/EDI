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
