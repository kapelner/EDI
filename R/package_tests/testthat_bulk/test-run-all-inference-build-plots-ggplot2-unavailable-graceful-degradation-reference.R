library(testthat)
library(EDI)

# inference_suite.R's run_all_inference_build_plots(results_table, alpha) is the free function
# InferenceSuite$run_all_inference() delegates plot-building to. When 'ggplot2' is unavailable, it
# does NOT error -- it warns ("InferenceSuite$run_all_inference: the 'ggplot2' package is not
# installed -- skipping plots (CI forest). Install 'ggplot2' to enable them.") and gracefully
# returns list(ci_forest = list()) so the rest of the pipeline can proceed without plots. A
# codebase-wide grep confirmed this exact warning message had zero test references anywhere,
# despite InferenceSuite's render layer being otherwise well covered ("closed already" per this
# session's standing list -- that closure covered the render layer's OTHER guards, not this one).
# Since the guard calls requireNamespace() directly (not check_package_installed()), it is mocked
# with .package = "base", the same technique established earlier this session for the analogous
# RcppXPtrUtils/ompr/ROI.plugin package-required guards.

test_that("run_all_inference_build_plots() warns and returns an empty ci_forest list when ggplot2 is (mocked as) unavailable", {
	f <- getFromNamespace("run_all_inference_build_plots", "EDI")
	res <- with_mocked_bindings(
		requireNamespace = function(pkg, ...) FALSE,
		.package = "base",
		{
			expect_warning(
				out <- f(data.frame(), 0.05),
				"the 'ggplot2' package is not installed -- skipping plots \\(CI forest\\)\\. Install 'ggplot2' to enable them\\."
			)
			out
		}
	)
	expect_identical(res, list(ci_forest = list()))
})
