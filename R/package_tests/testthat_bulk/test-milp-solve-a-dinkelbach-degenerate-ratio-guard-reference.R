library(testthat)
library(EDI)

# helper_optimal_milp_solvers.R's milp_solve_A_dinkelbach() computes an internal A-optimality ratio
# g(w)/s(w) where s(w) = n_T - w'Pw; if s(w) <= 0 for the starting allocation (the treatment
# indicator lies in P's covariate span, a degenerate design case), it stop()s "Degenerate allocation
# in the A-optimality ratio: n_T - w'Pw <= 0 (the treatment indicator is in the covariate span)."
# before any MILP solve is attempted (the check runs on the fixed starting w = c(rep(1, n_T),
# rep(0, n - n_T)) before the Dinkelbach iteration loop begins). The sibling n_T-range guard
# (assert_optimal_milp_n_T(), shared across the MILP solver family) is already covered, but this
# guard had zero test references anywhere.

test_that("milp_solve_A_dinkelbach(): a P matrix that makes the starting allocation degenerate errors with the documented message", {
	f <- getFromNamespace("milp_solve_A_dinkelbach", "EDI")
	n <- 4L
	P <- diag(rep(10, n))
	H <- diag(rep(1, n))
	expect_error(
		f(P, H, n_T = 2L, roi_solver = "glpk"),
		"Degenerate allocation in the A-optimality ratio: n_T - w'Pw <= 0"
	)
})
