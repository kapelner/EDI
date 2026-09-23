library(testthat)
library(EDI)

# contracts_mixins.R's load_inference_component() has two more sibling guards beyond the ones
# already covered in test-mixin-contracts.R's "lazy loader reports deterministic source, package,
# object, and contract failures" (missing source file, missing optional package, non-R6/list
# source object, public method contract mismatch): "source object `<name>` was not created by
# `<file>`." (the sourced file runs successfully but never defines an object under the expected
# source_name -- distinct from the already-tested case where the file DOES define the object but as
# the wrong shape) and "private method contract mismatch after load." (the private-side sibling of
# the already-tested public-side contract-mismatch guard). Both reachable with the same
# hand-registered lazy-loading InferenceComponent + tempfile technique the existing test uses.

test_that("load_inference_component(): a source file that never defines the expected object errors with the documented message", {
	on.exit(EDI:::populate_inference_component_registry(), add = TRUE)
	on.exit(EDI:::clear_inference_component_implementation_cache(), add = TRUE)

	notcreated_file <- tempfile(fileext = ".R")
	writeLines("SomethingElseEntirely = list(public = list(), private = list())", notcreated_file)
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "TemporaryLazyNotCreatedProbe",
		status = "active",
		source_name = "NeverDefinedSource",
		file = notcreated_file,
		component_loader = list(load_policy = "lazy"),
		provides_public_methods = "x",
		provides_private_methods = character()
	))
	expect_error(
		EDI:::load_inference_component("TemporaryLazyNotCreatedProbe", class_name = "LoaderErrorHostProbe"),
		"source object `NeverDefinedSource` was not created by"
	)
})

test_that("load_inference_component(): a private method name mismatch after load errors with the documented message", {
	on.exit(EDI:::populate_inference_component_registry(), add = TRUE)
	on.exit(EDI:::clear_inference_component_implementation_cache(), add = TRUE)

	privmismatch_file <- tempfile(fileext = ".R")
	writeLines(
		"PrivMismatchSource = list(public = list(x = function() TRUE), private = list(wrongname = function() TRUE))",
		privmismatch_file
	)
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "TemporaryLazyPrivateMismatchProbe",
		status = "active",
		source_name = "PrivMismatchSource",
		file = privmismatch_file,
		component_loader = list(load_policy = "lazy"),
		provides_public_methods = "x",
		provides_private_methods = "rightname"
	))
	expect_error(
		EDI:::load_inference_component("TemporaryLazyPrivateMismatchProbe", class_name = "LoaderErrorHostProbe"),
		"private method contract mismatch after load\\."
	)
})
