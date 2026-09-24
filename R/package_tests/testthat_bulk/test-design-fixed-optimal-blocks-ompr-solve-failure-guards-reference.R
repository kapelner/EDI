library(testthat)
library(EDI)

# DesignFixedOptimalBlocks$solve_optimal_blocks() (design_fixed_optimal_blocks.R, method = "ompr"
# path) validates ompr::get_solution()'s returned assignment matrix with two guards: an empty solution
# ("ompr failed to produce a block assignment solution.") and a solution whose selected (value > 0.5)
# rows don't cover all n subjects ("ompr returned an incomplete block assignment."). A codebase-wide
# grep confirmed neither exact message had any test reference anywhere -- the only existing ompr-method
# reference (test-design-fixed-optimal-blocks-ompr-dist-argument-type-guard-reference.R) exercises a
# different, upstream dist-argument guard, never the solver's own solution-validation. Reached by
# mocking ompr::get_solution() (the only call whose return value these guards inspect) via
# with_mocked_bindings(), independent of the real MIP-solve machinery (which is exercised by the
# uncontrolled real-solve success case below).

test_that("an empty ompr solution (0 rows) raises 'ompr failed to produce a block assignment solution.'", {
	set.seed(1L)
	n <- 8L
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))

	with_mocked_bindings(
		get_solution = function(...) data.frame(),
		.package = "ompr",
		code = {
			des <- DesignFixedOptimalBlocks$new(response_type = "continuous", method = "ompr", B = 2L, n = n, verbose = FALSE)
			des$add_all_subjects_to_experiment(X)
			expect_error(
				des$.__enclos_env__$private$get_or_compute_block_ids(),
				"ompr failed to produce a block assignment solution.",
				fixed = TRUE
			)
		}
	)
})

test_that("an ompr solution whose selected rows don't cover all n subjects raises 'ompr returned an incomplete block assignment.'", {
	set.seed(2L)
	n <- 8L
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))

	with_mocked_bindings(
		get_solution = function(...) data.frame(i = 1:3, k = c(1, 1, 2), value = c(1, 1, 1)),
		.package = "ompr",
		code = {
			des <- DesignFixedOptimalBlocks$new(response_type = "continuous", method = "ompr", B = 2L, n = n, verbose = FALSE)
			des$add_all_subjects_to_experiment(X)
			expect_error(
				des$.__enclos_env__$private$get_or_compute_block_ids(),
				"ompr returned an incomplete block assignment.",
				fixed = TRUE
			)
		}
	)
})

test_that("a genuine (unmocked) ompr solve succeeds and produces a complete block assignment", {
	skip_if_not_installed("ompr")
	skip_if_not_installed("ompr.roi")
	skip_if_not_installed("ROI.plugin.glpk")
	set.seed(3L)
	n <- 8L
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignFixedOptimalBlocks$new(response_type = "continuous", method = "ompr", B = 2L, n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	ids <- des$.__enclos_env__$private$get_or_compute_block_ids()
	expect_length(ids, n)
	expect_true(all(is.finite(ids)))
})
