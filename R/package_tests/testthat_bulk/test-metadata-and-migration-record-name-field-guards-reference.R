library(testthat)
library(EDI)

# design_class_registry.R's validate_design_class_metadata(), inference_class_registry.R's
# validate_inference_class_metadata(), and its sibling validate_inference_hierarchy_migration_record()
# each carry an identically-shaped `name` field guard, reached only when the upstream missing-
# required-field check passes but `name` itself is empty/non-scalar/non-character. These are the
# metadata/migration-record siblings of the already-tested component-level name guards
# (test-component-validator-name-field-guards-reference.R). Every registered class's real metadata
# passes validation constantly (exercised at load time and via "every registered class" loop tests),
# but the name-guard's actual error branch had zero test references anywhere for all three
# validators.

test_that("validate_design_class_metadata(): an empty or non-scalar name errors with the documented message", {
	valid <- EDI:::get_design_class_metadata("DesignFixedBernoulli")

	bad_empty <- valid; bad_empty$name <- ""
	expect_error(EDI:::validate_design_class_metadata(bad_empty), "Design metadata field `name` must be a non-empty character scalar\\.")

	bad_vector <- valid; bad_vector$name <- c("a", "b")
	expect_error(EDI:::validate_design_class_metadata(bad_vector), "Design metadata field `name` must be a non-empty character scalar\\.")
})

test_that("validate_inference_class_metadata(): an empty or non-scalar name errors with the documented message", {
	valid <- EDI:::get_inference_class_metadata("InferenceContinLin")

	bad_empty <- valid; bad_empty$name <- ""
	expect_error(EDI:::validate_inference_class_metadata(bad_empty), "Inference metadata field `name` must be a non-empty character scalar\\.")

	bad_vector <- valid; bad_vector$name <- c("a", "b")
	expect_error(EDI:::validate_inference_class_metadata(bad_vector), "Inference metadata field `name` must be a non-empty character scalar\\.")
})

test_that("validate_inference_hierarchy_migration_record(): an empty or non-scalar name errors with the documented message", {
	valid <- EDI:::get_inference_hierarchy_migration_record("InferenceContinLin")

	bad_empty <- valid; bad_empty$name <- ""
	expect_error(EDI:::validate_inference_hierarchy_migration_record(bad_empty), "Migration record `name` must be a non-empty character scalar\\.")

	bad_vector <- valid; bad_vector$name <- c("a", "b")
	expect_error(EDI:::validate_inference_hierarchy_migration_record(bad_vector), "Migration record `name` must be a non-empty character scalar\\.")
})
