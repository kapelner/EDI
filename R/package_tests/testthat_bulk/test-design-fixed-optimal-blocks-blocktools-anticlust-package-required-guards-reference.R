library(testthat)
library(EDI)

# DesignFixedOptimalBlocks$new() guards each non-"ompr" method choice on its own optional-package
# dependency (helper_package_checks.R): method = "greedy" requires blockTools
# (assert_blocktools_installed("DesignFixedOptimalBlocks with method='greedy'")) and method = "K-way"
# requires anticlust (assert_anticlust_installed("DesignFixedOptimalBlocks with method='K-way'")). Both
# fire at construction time, before any block-formation work. test-fixed-optimal-blocks-method-
# branches-reference.R already thoroughly covers both methods' actual block-formation arithmetic
# against an independent reference, but always with skip_if_not_installed("blockTools")/
# skip_if_not_installed("anticlust") -- a codebase-wide grep confirmed neither guard's own message had
# a test reference anywhere, so the "package unavailable" branch itself was never exercised for either
# method. Reached via with_mocked_bindings(check_package_installed = function(...) FALSE, .package =
# "EDI"), the same established pattern used for the nbpMatching/quantreg/geepack/icenReg "package
# unavailable" guards elsewhere in this suite.

test_that("method = 'greedy' errors with the documented message when blockTools is (mocked as) unavailable", {
	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			expect_error(
				DesignFixedOptimalBlocks$new(response_type = "continuous", method = "greedy", B = 2L, n = 8L, verbose = FALSE),
				"Package 'blockTools' is required for DesignFixedOptimalBlocks with method='greedy'.",
				fixed = TRUE
			)
		}
	)
})

test_that("method = 'K-way' errors with the documented message when anticlust is (mocked as) unavailable", {
	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			expect_error(
				DesignFixedOptimalBlocks$new(response_type = "continuous", method = "K-way", B = 2L, n = 8L, verbose = FALSE),
				"Package 'anticlust' is required for DesignFixedOptimalBlocks with method='K-way'.",
				fixed = TRUE
			)
		}
	)
})

test_that("method = 'ompr' never reaches either guard, even with both packages mocked as unavailable", {
	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			expect_error(
				DesignFixedOptimalBlocks$new(response_type = "continuous", method = "ompr", B = 2L, n = 8L, verbose = FALSE),
				"DesignFixedOptimalBlocks with method='ompr'",
				fixed = TRUE
			)
		}
	)
})
