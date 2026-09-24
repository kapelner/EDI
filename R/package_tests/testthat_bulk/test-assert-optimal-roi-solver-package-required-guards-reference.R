library(testthat)
library(EDI)

# helper_optimal_milp_solvers.R's assert_optimal_roi_solver() has two package-required guards
# beyond the already-covered roi_solver enum guard (test-assert-optimal-roi-solver-enum-guard-
# reference.R): a loop checking BOTH "ompr" and "ompr.roi" are installed ("Package '<pkg>' is
# required for the \"ompr\" solver path; please install it."), and a plugin-specific check for
# whichever ROI.plugin.<backend> the requested roi_solver needs ("Package '<plugin>' is required
# for roi_solver = \"<solver>\"; please install it. ..."). A codebase-wide grep confirmed both
# exact messages had zero test references anywhere. Since these guards call requireNamespace()
# directly (not this codebase's check_package_installed() helper), they are mocked with
# .package = "base" -- the same technique established in test-fixed-optimal-custom-objective-
# rcppxptrutils-required-recompile-guard-reference.R for the same reason.

test_that("the 'ompr'/'ompr.roi' package-required guard fires first, before the plugin-specific check", {
	f <- getFromNamespace("assert_optimal_roi_solver", "EDI")
	expect_error(
		with_mocked_bindings(
			requireNamespace = function(pkg, ...) FALSE,
			.package = "base",
			f("glpk")
		),
		"Package 'ompr' is required for the \"ompr\" solver path",
		fixed = TRUE
	)
})

test_that("the ROI-plugin-specific guard fires once ompr/ompr.roi are available but the plugin is not, naming the right plugin per solver", {
	f <- getFromNamespace("assert_optimal_roi_solver", "EDI")
	ompr_available <- function(pkg, ...) pkg %in% c("ompr", "ompr.roi")

	expect_error(
		with_mocked_bindings(requireNamespace = ompr_available, .package = "base", f("glpk")),
		"Package 'ROI.plugin.glpk' is required for roi_solver = \"glpk\"",
		fixed = TRUE
	)
	expect_error(
		with_mocked_bindings(requireNamespace = ompr_available, .package = "base", f("gurobi")),
		"Package 'ROI.plugin.gurobi' is required for roi_solver = \"gurobi\"",
		fixed = TRUE
	)
	expect_error(
		with_mocked_bindings(requireNamespace = ompr_available, .package = "base", f("cplex")),
		"Package 'ROI.plugin.cplex' is required for roi_solver = \"cplex\"",
		fixed = TRUE
	)
})
