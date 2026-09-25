library(testthat)
library(EDI)

# InferenceContinQuantileRegr/InferencePropQuantileRegr store tau/fit_warm_keep as bare NULL-defaulted
# private fields, which combine_component_slot()'s utils::modifyList(combined, host_entries)
# (mixin_contracts.R, no keep.null = TRUE) used to silently drop from the assembled class -- R6 then
# treated them as never-declared fields, invisible for direct instantiation of the migrated class
# itself (define_inference_class() forces lock_objects = FALSE) but real for any EXTERNAL subclass
# built the normal way (plain R6::R6Class(inherit = InferenceContinQuantileRegr), whose lock_objects
# defaults TRUE like every ordinary R6 class): even the first assignment to that field inside
# initialize() would be "adding a new binding to a locked environment" (fix_inference_hierarchy.md,
# InferenceContinQuantileRegr entry). The existing reused-worker fixture that DOES subclass this class
# (R/EDI/tests/testthat/test-bootstrap-reused-worker-families.R) explicitly passes lock_objects = FALSE
# itself, deliberately sidestepping the exact scenario the fix is about -- a codebase-wide grep
# confirmed no test constructs a genuinely default (lock_objects = TRUE) external subclass of either
# class. This file closes that gap directly: builds an ordinary external R6 subclass with default
# locking, confirms construction succeeds, tau/fit_warm_keep are genuinely present and writable
# (bindingIsLocked() == FALSE) rather than merely present-but-frozen, and a normal estimate computes.

test_that("an ordinary external R6 subclass (default lock_objects = TRUE) of InferenceContinQuantileRegr constructs successfully and its tau/fit_warm_keep fields are genuinely writable, not locked", {
	MySubclass <- R6::R6Class("MyContinQuantileRegrSubclass",
		inherit = InferenceContinQuantileRegr,
		public = list(
			initialize = function(des_obj, ...) super$initialize(des_obj, ...)
		)
	)

	set.seed(1L); n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))

	inf <- MySubclass$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	expect_true("tau" %in% names(priv))
	expect_equal(priv$tau, 0.5)  # the documented default, present rather than silently dropped
	expect_false(bindingIsLocked("tau", priv))
	expect_false(bindingIsLocked("fit_warm_keep", priv))

	priv$tau <- 0.7  # mutation must not error ("adding a new binding to a locked environment")
	expect_equal(priv$tau, 0.7)

	expect_true(is.finite(inf$compute_estimate()))
})

test_that("the same is true for InferencePropQuantileRegr's byte-for-byte-identical external-subclass shape", {
	MySubclass <- R6::R6Class("MyPropQuantileRegrSubclass",
		inherit = InferencePropQuantileRegr,
		public = list(
			initialize = function(des_obj, ...) super$initialize(des_obj, ...)
		)
	)

	set.seed(2L); n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(plogis(rnorm(n)))

	inf <- MySubclass$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	expect_true("tau" %in% names(priv))
	expect_equal(priv$tau, 0.5)
	expect_false(bindingIsLocked("tau", priv))

	priv$tau <- 0.3
	expect_equal(priv$tau, 0.3)

	expect_true(is.finite(inf$compute_estimate()))
})
