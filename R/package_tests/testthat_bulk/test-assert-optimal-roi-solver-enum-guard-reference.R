library(testthat)
library(EDI)

# helper_optimal_milp_solvers.R's assert_optimal_roi_solver() -- the closed-set validator shared by
# every exact "ompr" MILP solver entry point (milp_solve_l1/_quadratic/_A_dinkelbach) -- rejects any
# roi_solver value outside c("glpk", "gurobi", "cplex") with 'roi_solver must be one of "glpk",
# "gurobi", "cplex" (got: ...).', checked before any requireNamespace() lookup or solve attempt. Zero
# test references anywhere.

test_that("assert_optimal_roi_solver(): an unrecognized solver name errors with the documented message", {
	f <- getFromNamespace("assert_optimal_roi_solver", "EDI")
	expect_error(
		f("not_a_real_solver"),
		'roi_solver must be one of "glpk", "gurobi", "cplex" \\(got: "not_a_real_solver"\\)\\.'
	)
})

test_that("assert_optimal_roi_solver(): a non-character solver value errors with the documented message", {
	f <- getFromNamespace("assert_optimal_roi_solver", "EDI")
	expect_error(
		f(123),
		'roi_solver must be one of "glpk", "gurobi", "cplex" \\(got: 123\\)\\.'
	)
})
