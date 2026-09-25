library(testthat)
library(EDI)

# inference_public_method_names() (inference_class_registry.R:1773-1791) has two lookup guards
# identical in shape to inference_private_owner_names()'s own copy of the same two guards (already
# covered in test-inference-class-registry-infer-functions-and-design-exclusions-reference.R):
#   1. A nonexistent class name (with no generator supplied) errors -- "No R6 generator found for
#      inference class <name>."
#   2. An explicitly-supplied generator that isn't an R6ClassGenerator errors -- "Object for <name>
#      is not an R6 generator."
# Despite the sibling function's guards being tested, inference_public_method_names() itself is
# only ever called elsewhere with valid real class names, confirmed via a codebase-wide grep of its
# own call sites -- neither of its guards had ever actually been triggered. Exercised via a direct
# namespace call.

test_that("a nonexistent inference class name (no generator supplied) is rejected", {
	f <- getFromNamespace("inference_public_method_names", "EDI")
	expect_error(
		f("NoSuchInferenceClass"),
		"No R6 generator found for inference class NoSuchInferenceClass\\.",
	)
})

test_that("an explicitly-supplied generator that isn't an R6ClassGenerator is rejected", {
	f <- getFromNamespace("inference_public_method_names", "EDI")
	expect_error(
		f("InferenceContinOLS", generator = list()),
		"Object for InferenceContinOLS is not an R6 generator\\.",
	)
})

test_that("a real class name resolves normally, as a contrast against the guards above", {
	f <- getFromNamespace("inference_public_method_names", "EDI")
	res <- f("InferenceContinOLS")
	expect_true(is.character(res))
	expect_true("compute_estimate" %in% res)
})
