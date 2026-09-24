library(testthat)
library(EDI)

# DesignFixedOptimal$ensure_custom_objective_xptr_live() (design_fixed_optimal.R:400-436), when
# the probed custom_objective pointer is dead AND its C++ source was retained, tries to recompile
# it via RcppXPtrUtils::cppXPtr() -- but only after checking requireNamespace("RcppXPtrUtils",
# quietly = TRUE). The sibling test file test-fixed-optimal-custom-objective-xptr-liveness-check-
# and-recompile-reference.R covers the recompile-succeeds path (mocking RcppXPtrUtils::cppXPtr
# itself, gated behind skip_if_not_installed("RcppXPtrUtils")) and the no-retained-source path, but
# never the case where RcppXPtrUtils itself is unavailable: "Package 'RcppXPtrUtils' is required to
# recompile this design's custom_objective after a saveRDS()/readRDS() reload; please install it."
# A codebase-wide grep confirmed this exact message had zero test references anywhere. Since
# requireNamespace() is a base function called unqualified (not via check_package_installed(), the
# pattern this suite's other package-required guards use), it isn't mockable via the usual
# .package = "EDI" local_mocked_bindings target -- mocked here instead with .package = "base",
# alongside the same eval_custom_design_objective_cpp-mocked-dead-pointer technique the sibling file
# already established, so nothing is ever actually compiled.

mk <- function() {
	des <- DesignFixedOptimal$new(response_type = "continuous", n = 8L, objective = "mahal_dist",
		solver = "ompr", verbose = FALSE, seed = 1L)
	list(des = des, p = des$.__enclos_env__$private)
}
X8 <- matrix(seq_len(16), 8, 2)

test_that("a dead pointer with retained source, but RcppXPtrUtils unavailable, raises the documented package-required message", {
	f <- mk()
	f$p$custom_objective_normalized <- list(xptr = "OLD", src = "double f() { return 0; }")

	expect_error(
		with_mocked_bindings(
			requireNamespace = function(...) FALSE,
			.package = "base",
			{
				local_mocked_bindings(
					eval_custom_design_objective_cpp = function(...) stop("External pointer is not valid"),
					.package = "EDI"
				)
				f$p$ensure_custom_objective_xptr_live(X8, 2L)
			}
		),
		"Package 'RcppXPtrUtils' is required to recompile this design's custom_objective",
		fixed = TRUE
	)
})
