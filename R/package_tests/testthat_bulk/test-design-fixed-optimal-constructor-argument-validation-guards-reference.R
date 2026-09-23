library(testthat)
library(EDI)

# DesignFixedOptimal$new()'s always-on construction-time argument validation (design_fixed_optimal.R,
# ~line 234-304) has 13 sibling guards, none gated behind should_run_asserts() and all checked before
# super$initialize() runs -- cheap, no solving or compilation involved. None had any test
# references anywhere despite the class being otherwise extensively tested elsewhere (test-design-
# fixed-optimal.R, test-fixed-optimal-solver-inputs-and-exact-allocation-reference.R, and others,
# none of which exercise the constructor's own bad-argument paths).

test_that("prob_T outside (0, 1) errors with the documented message", {
	expect_error(
		DesignFixedOptimal$new(response_type = "continuous", n = 10, prob_T = 1.5, verbose = FALSE),
		"prob_T must be a single number strictly between 0 and 1\\."
	)
})

test_that("an unrecognized objective errors with the documented message", {
	expect_error(
		DesignFixedOptimal$new(response_type = "continuous", n = 10, objective = "bogus", verbose = FALSE),
		'objective must be one of "D", "A", "mahal_dist", "abs_sum_diff", or "custom"\\.'
	)
})

test_that("interest is rejected for non-D/A objectives", {
	expect_error(
		DesignFixedOptimal$new(response_type = "continuous", n = 10, objective = "mahal_dist", interest = "x1", verbose = FALSE),
		'interest is only meaningful for objective = "D"/"A"\\.'
	)
})

test_that("prior_precision is rejected for non-D/A objectives", {
	expect_error(
		DesignFixedOptimal$new(response_type = "continuous", n = 10, objective = "mahal_dist", prior_precision = 1, verbose = FALSE),
		'prior_precision is only meaningful for objective = "D"/"A"\\.'
	)
})

test_that("a non-logical standardize_covariates errors with the documented message for non-D/A objectives", {
	expect_error(
		DesignFixedOptimal$new(response_type = "continuous", n = 10, objective = "mahal_dist", standardize_covariates = NA, verbose = FALSE),
		"standardize_covariates must be TRUE or FALSE\\."
	)
})

test_that("an unrecognized solver errors with the documented message", {
	expect_error(
		DesignFixedOptimal$new(response_type = "continuous", n = 10, solver = "bogus", verbose = FALSE),
		'solver must be "auto", "ompr", or "annealing"\\.'
	)
})

test_that("objective = custom with solver = ompr errors with the documented message", {
	expect_error(
		DesignFixedOptimal$new(response_type = "continuous", n = 10, objective = "custom", solver = "ompr", verbose = FALSE),
		'objective = "custom" cannot be solved by the "ompr" MILP path'
	)
})

test_that("custom_objective supplied without objective = custom errors with the documented message", {
	expect_error(
		DesignFixedOptimal$new(response_type = "continuous", n = 10, custom_objective = 1, verbose = FALSE),
		"custom_objective may only be supplied with objective = \"custom\"\\."
	)
})

test_that("a non-named-list solver_args errors with the documented message", {
	expect_error(
		DesignFixedOptimal$new(response_type = "continuous", n = 10, solver_args = list(1, 2), verbose = FALSE),
		"solver_args must be a named list\\."
	)
})

test_that("an unknown solver_args name errors with the documented message", {
	expect_error(
		DesignFixedOptimal$new(response_type = "continuous", n = 10, solver_args = list(bogus_key = 1), verbose = FALSE),
		"Unknown solver_args: bogus_key\\. Supported:"
	)
})

test_that("an unrecognized solver_args$brt_solver errors with the documented message", {
	expect_error(
		DesignFixedOptimal$new(response_type = "continuous", n = 10, solver_args = list(brt_solver = "bogus"), verbose = FALSE),
		'solver_args\\$brt_solver must be "annealing" or "ompr"\\.'
	)
})

test_that("an unrecognized solver_args$roi_solver errors with the documented message", {
	expect_error(
		DesignFixedOptimal$new(response_type = "continuous", n = 10, solver_args = list(roi_solver = "bogus"), verbose = FALSE),
		'solver_args\\$roi_solver must be one of "glpk", "gurobi", "cplex"\\.'
	)
})

test_that("a non-logical mirror_coin errors with the documented message", {
	expect_error(
		DesignFixedOptimal$new(response_type = "continuous", n = 10, mirror_coin = NA, verbose = FALSE),
		"mirror_coin must be TRUE or FALSE\\."
	)
})
