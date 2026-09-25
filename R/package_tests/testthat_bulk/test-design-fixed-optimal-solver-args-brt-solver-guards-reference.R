library(testthat)
library(EDI)

# DesignFixedOptimal$new()'s solver_args$brt_solver validation (design_fixed_optimal.R:287-293) has
# two guards beyond the already-covered "Unknown solver_args" allowlist check:
#   1. solver_args$brt_solver, if supplied, must be "annealing" or "ompr" -- 'solver_args$brt_solver
#      must be "annealing" or "ompr".'
#   2. objective = "custom" combined with solver_args$brt_solver = "ompr" is rejected (there's no
#      structure to linearize for ompr's MILP path) -- 'objective = "custom" cannot use
#      solver_args$brt_solver = "ompr" (no structure to linearize).'
# A codebase-wide grep confirmed both exact messages had zero test references anywhere. Exercised
# via the plain public constructor; the second case uses a real, trivial RcppXPtrUtils::cppXPtr()
# compile (fast, isolated -- not EDI's own package build) to supply a valid custom_objective, since
# the guard sits downstream of custom_objective's own normalization.

test_that("an unrecognized solver_args$brt_solver value is rejected", {
	skip_if_not_installed("RcppXPtrUtils")
	expect_error(
		DesignFixedOptimal$new(response_type = "continuous", n = 10L, objective = "mahal_dist", solver_args = list(brt_solver = "bogus"), verbose = FALSE),
		'solver_args\\$brt_solver must be "annealing" or "ompr"\\.',
	)
})

test_that("objective = 'custom' combined with solver_args$brt_solver = 'ompr' is rejected", {
	skip_if_not_installed("RcppXPtrUtils")
	fobj <- "double f(const Eigen::MatrixXd& X, const Eigen::VectorXd& w) { return 0.0; }"
	expect_error(
		DesignFixedOptimal$new(
			response_type = "continuous", n = 10L, objective = "custom", custom_objective = fobj,
			solver_args = list(brt_solver = "ompr"), verbose = FALSE
		),
		'objective = "custom" cannot use solver_args\\$brt_solver = "ompr" \\(no structure to linearize\\)\\.',
	)
})
