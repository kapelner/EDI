library(testthat)
library(EDI)

# helper_optimal_annealing.R's optimal_solve_auto() -- the "auto" solver-resolution policy shared by
# DesignFixedOptimal's solver dispatch -- validates its `kind` argument first, before any solving:
# 'kind must be "quadratic", "l1", "ratio", or "custom".' The sibling assert_annealing_args() guards
# on the same file (n_chains/max_iter/initial_temp/cooling_rate) are already covered
# (test-annealing-solve-kernel-brute-force-optimum-metadata-and-argument-plumbing-reference.R), but
# this specific `kind` guard had zero test references anywhere.

test_that("optimal_solve_auto(): an unrecognized kind errors with the documented message", {
	f <- getFromNamespace("optimal_solve_auto", "EDI")
	expect_error(
		f(kind = "not_a_real_kind", n_T = 2),
		'kind must be "quadratic", "l1", "ratio", or "custom"\\.'
	)
})
