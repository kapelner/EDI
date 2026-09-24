library(testthat)
library(EDI)

# ObservationalDesign's private draw_ws_raw() (design_observational.R), reached via the public
# draw_ws_according_to_design(), unconditionally rejects any attempt to draw a treatment assignment
# vector -- observational designs have no randomization mechanism; w is supplied externally, never
# generated. A codebase-wide grep confirmed the exact message "This operation is not supported.
# Observational designs are not controlled designs based on randomized allocations." had zero test
# references anywhere. Every existing ObservationalDesign* reference in the suite constructs the
# concrete ObservationalDesignMatching subclass, never the base ObservationalDesign class directly, and
# none call draw_ws_according_to_design()/draw_ws_raw() on either. Reached by constructing the base
# class directly (a real, registered, directly-instantiable class -- confirmed via
# ObservationalDesign$new()) and calling both the public entry point and the private method directly.

test_that("draw_ws_according_to_design() on a real ObservationalDesign instance raises the documented unsupported-operation error", {
	des <- ObservationalDesign$new(response_type = "continuous", n = 10L, verbose = FALSE)
	expect_error(
		des$draw_ws_according_to_design(1L),
		"This operation is not supported. Observational designs are not controlled designs based on randomized allocations.",
		fixed = TRUE
	)
})

test_that("the private draw_ws_raw() method raises the identical error directly", {
	des <- ObservationalDesign$new(response_type = "continuous", n = 10L, verbose = FALSE)
	priv <- des$.__enclos_env__$private
	expect_error(
		priv$draw_ws_raw(1L),
		"This operation is not supported. Observational designs are not controlled designs based on randomized allocations.",
		fixed = TRUE
	)
})
