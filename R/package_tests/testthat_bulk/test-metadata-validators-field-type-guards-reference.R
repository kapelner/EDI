library(testthat)
library(EDI)

# design_class_registry.R's validate_design_class_metadata() and inference_class_registry.R's
# validate_inference_class_metadata() each carry a long run of per-field type/shape guards. Two of
# the design-side enum guards (`randomization_family`, `timing_family`) are already covered by
# test-design-class-registry.R, but the remaining sibling guards -- design-side `parent`, `abstract`,
# `exported`, `seed_reproducible_draw`; inference-side `parent`, `abstract`, `exported`,
# `response_types`, `design_families`, `compatibility` -- had zero test references anywhere, despite
# real metadata passing validation constantly (exercised at load time and via "every registered
# class" loop tests).

test_that("validate_design_class_metadata(): invalid parent/abstract/exported/seed_reproducible_draw each error with the documented message", {
	valid <- EDI:::get_design_class_metadata("DesignFixedBernoulli")

	bad_parent <- valid; bad_parent$parent <- 123
	expect_error(EDI:::validate_design_class_metadata(bad_parent), "invalid `parent`")

	bad_abstract <- valid; bad_abstract$abstract <- "not_logical"
	expect_error(EDI:::validate_design_class_metadata(bad_abstract), "invalid `abstract`")

	bad_exported <- valid; bad_exported$exported <- "not_logical"
	expect_error(EDI:::validate_design_class_metadata(bad_exported), "invalid `exported`")

	bad_seed <- valid; bad_seed$seed_reproducible_draw <- "not_logical"
	expect_error(EDI:::validate_design_class_metadata(bad_seed), "invalid `seed_reproducible_draw`")
})

test_that("validate_inference_class_metadata(): invalid parent/abstract/exported/response_types/design_families/compatibility each error with the documented message", {
	valid <- EDI:::get_inference_class_metadata("InferenceContinLin")

	bad_parent <- valid; bad_parent$parent <- 123
	expect_error(EDI:::validate_inference_class_metadata(bad_parent), "invalid `parent`")

	bad_abstract <- valid; bad_abstract$abstract <- "not_logical"
	expect_error(EDI:::validate_inference_class_metadata(bad_abstract), "invalid `abstract`")

	bad_exported <- valid; bad_exported$exported <- "not_logical"
	expect_error(EDI:::validate_inference_class_metadata(bad_exported), "invalid `exported`")

	bad_response_types <- valid; bad_response_types$response_types <- 123
	expect_error(EDI:::validate_inference_class_metadata(bad_response_types), "invalid `response_types`")

	bad_design_families <- valid; bad_design_families$design_families <- 123
	expect_error(EDI:::validate_inference_class_metadata(bad_design_families), "invalid `design_families`")

	bad_compatibility <- valid; bad_compatibility$compatibility <- "not_a_function"
	expect_error(EDI:::validate_inference_class_metadata(bad_compatibility), "invalid `compatibility`")
})
