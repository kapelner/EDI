library(testthat)
library(EDI)

# contracts_mixins.R's validate_inference_class_definition() has two more capability-requirement
# guards in the same capability_requires cross-check loop as the ones just closed
# (test-validate-inference-class-definition-capability-requirement-guards-reference.R): a capability
# that itself requires another capability the class doesn't advertise ("without required
# capability/capabilities"), and one that requires a metadata field the class's own metadata list
# doesn't supply ("without required metadata field(s)"). The capability-requires-capability guard is
# reachable directly with the real, live capability_requires table (randomization_ci requires
# randomization_test); no entry in the real table currently declares a `metadata` requirement, so the
# metadata guard is exercised via the validator's own capability_requires/public_methods_for_capability
# override parameters (documented, real function arguments -- not private-state injection) with a
# hand-built synthetic requirement, the same technique test-mixin-contracts.R uses for its own
# hand-registered InferenceComponent fixtures.

test_that("a capability requiring another capability the class doesn't advertise errors with the documented message", {
	validate <- getFromNamespace("validate_inference_class_definition", "EDI")
	expect_error(
		validate("Cls", metadata = list(capabilities = "randomization_ci")),
		"Cls advertises capability randomization_ci without required capability/capabilities: randomization_test"
	)
	expect_true(validate("Cls", metadata = list(capabilities = character())))
})

test_that("a capability requiring a metadata field the class doesn't supply errors with the documented message", {
	validate <- getFromNamespace("validate_inference_class_definition", "EDI")
	custom_reqs <- list(fake_cap = list(metadata = "some_required_field"))

	expect_error(
		validate("Cls", metadata = list(capabilities = "fake_cap"), capability_requires = custom_reqs, public_methods_for_capability = list()),
		"Cls advertises capability fake_cap without required metadata field\\(s\\): some_required_field"
	)
	expect_true(validate("Cls", metadata = list(capabilities = "fake_cap", some_required_field = "x"),
		capability_requires = custom_reqs, public_methods_for_capability = list()))
})
