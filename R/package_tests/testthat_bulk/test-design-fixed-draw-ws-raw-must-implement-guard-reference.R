library(testthat)
library(EDI)

# design_fixed_abstract.R's DesignFixed has a private draw_ws_raw() stub ("draw_ws_raw must be
# implemented by a concrete design subclass.") that every real concrete fixed design overrides. Since
# DesignFixed itself refuses direct instantiation (test-design-abstract-base-class-direct-
# instantiation-guard-reference.R), the stub can't be reached on DesignFixed directly -- but a
# concrete R6 subclass that inherits DesignFixed without overriding draw_ws_raw bypasses the
# class-name-keyed abstract-instantiation check (which only matches the exact registered abstract
# class name) while still exercising the unimplemented stub through assign_w_to_all_subjects(). Zero
# test references anywhere.

test_that("a DesignFixed subclass that never overrides draw_ws_raw() errors with the documented message when drawing assignments", {
	DesignFixed <- getFromNamespace("DesignFixed", "EDI")
	TmpNoDrawFixed <- R6::R6Class("TmpNoDrawFixed", inherit = DesignFixed, lock_objects = FALSE)

	d <- TmpNoDrawFixed$new(response_type = "continuous", n = 6L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(6L)))
	expect_error(
		d$assign_w_to_all_subjects(),
		"draw_ws_raw must be implemented by a concrete design subclass\\."
	)
})

test_that("a real concrete fixed design overrides draw_ws_raw and assigns without error", {
	des <- DesignFixedBernoulli$new(response_type = "continuous", n = 6L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(6L)))
	expect_no_error(des$assign_w_to_all_subjects())
})
