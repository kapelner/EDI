library(testthat)
library(EDI)

# contracts_mixins.R's validate_inference_class_definition() has one more capability-requirement
# guard in the same capability_requires cross-check loop as the ones closed by
# test-validate-inference-class-definition-capability-requirement-guards-reference.R and its
# capability-dependency-and-metadata sibling: a capability that requires private STATE the class's
# own private fields don't declare ("without required private state"). No entry in the real,
# live capability_requires table currently declares a `private_state` requirement (confirmed by
# grep across contracts_mixins.R's capability_requires definition), so -- exactly like the sibling
# file's synthetic `metadata`-requirement case -- this guard is exercised via the validator's own
# capability_requires override parameter (a documented, real function argument, not private-state
# injection) with a hand-built synthetic requirement.

test_that("no entry in the real capability_requires table declares a private_state requirement", {
	capability_requires <- getFromNamespace("capability_requires", "EDI")
	has_private_state_req <- vapply(capability_requires, function(req) length(req$private_state %||% character()) > 0L, logical(1L))
	expect_false(any(has_private_state_req))
})

test_that("a capability requiring private state the class doesn't declare errors with the documented message", {
	validate <- getFromNamespace("validate_inference_class_definition", "EDI")
	custom_reqs <- list(fake_state_cap = list(private_state = "some_required_field"))

	expect_error(
		validate("Cls", metadata = list(capabilities = "fake_state_cap"), capability_requires = custom_reqs, public_methods_for_capability = list()),
		"Cls advertises capability fake_state_cap without required private state: some_required_field"
	)
	expect_true(validate(
		"Cls",
		private = list(some_required_field = NULL),
		metadata = list(capabilities = "fake_state_cap"),
		capability_requires = custom_reqs,
		public_methods_for_capability = list()
	))
})
