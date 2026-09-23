library(testthat)
library(EDI)

# inference_class_registry.R's validate_inference_class_registry() -- the whole-registry-level
# validator, as opposed to the per-record validate_inference_class_metadata() -- has three guards
# identically shaped to its already-tested design-side sibling
# (test-design-class-metadata-and-registry-remaining-guards-reference.R): the registry argument must
# be a list, each record's `name` must match its registry key, and each record's `parent` must
# itself be a registered key. None had any test references anywhere.

test_that("validate_inference_class_registry(): a non-list registry errors with the documented message", {
	expect_error(EDI:::validate_inference_class_registry(registry = "not_a_list"), "Inference class registry must be a list of metadata records\\.")
})

test_that("validate_inference_class_registry(): a record's name diverging from its registry key errors with the documented message", {
	registry <- EDI:::inference_class_registry_as_list()
	bad_registry <- registry
	bad_registry[["InferenceContinLin"]]$name <- "WrongName"
	expect_error(EDI:::validate_inference_class_registry(registry = bad_registry), "Inference metadata name mismatch for registry key InferenceContinLin\\.")
})

test_that("validate_inference_class_registry(): a record's parent not itself a registered key errors with the documented message", {
	registry <- EDI:::inference_class_registry_as_list()
	bad_registry <- registry
	bad_registry[["InferenceContinLin"]]$parent <- "NoSuchParentClass"
	expect_error(EDI:::validate_inference_class_registry(registry = bad_registry), "Inference metadata for InferenceContinLin has unregistered parent NoSuchParentClass\\.")
})

test_that("validate_inference_class_registry(): the real, live registry passes validation silently", {
	expect_true(isTRUE(EDI:::validate_inference_class_registry()))
})
