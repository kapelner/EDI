library(testthat)
library(EDI)

# validate_design_component() (design_component_registry.R), called by DesignComponent()'s own
# constructor, has two distinct structural-validity guards beyond the already-covered name-field/
# status/public-private-list/non-character/stale-metadata/dependency-cycle family:
#   1. allowed_host_overrides must be a list with exactly {public, private} names -- "Design
#      component <name> has invalid `allowed_host_overrides`."
#   2. owns_state must name only non-function (data) fields of private -- a function accidentally
#      listed in owns_state is rejected: "Design component <name> declares method(s) as owned
#      state: <names>."
# A codebase-wide grep confirmed both exact messages had zero test references anywhere, despite
# DesignComponent()/validate_design_component() being exercised by several other guard-focused
# test files. Exercised via the public (though unexported) EDI:::DesignComponent() constructor
# directly, no design/inference fixture needed.

test_that("a malformed allowed_host_overrides (missing the 'private' name) is rejected with the documented message", {
	expect_error(
		EDI:::DesignComponent(name = "TmpAllowedOverridesBad", allowed_host_overrides = list(public = character())),
		"Design component TmpAllowedOverridesBad has invalid `allowed_host_overrides`\\.",
	)
})

test_that("a well-formed allowed_host_overrides (both names present) passes", {
	comp <- EDI:::DesignComponent(name = "TmpAllowedOverridesOk", allowed_host_overrides = list(public = character(), private = character()))
	expect_identical(comp$name, "TmpAllowedOverridesOk")
})

test_that("owns_state naming a private FUNCTION (rather than a data field) is rejected with the documented message", {
	expect_error(
		EDI:::DesignComponent(name = "TmpOwnedStateFn", owns_state = "foo", private = list(foo = function() 1)),
		"Design component TmpOwnedStateFn declares method\\(s\\) as owned state: foo",
	)
})

test_that("owns_state naming a private DATA field (not a function) passes", {
	comp <- EDI:::DesignComponent(name = "TmpOwnedStateData", owns_state = "foo", private = list(foo = NULL))
	expect_identical(comp$owns_state, "foo")
})
