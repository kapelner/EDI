library(testthat)
library(EDI)

# design_component_registry.R's validate_design_component() and contracts_mixins.R's
# validate_inference_component() each have a sibling `name` field guard ("Design/Inference component
# field `name` must be a non-empty character scalar."), reached only when the missing-required-field
# check upstream passes but `name` itself is empty/non-scalar/non-character. The existing validator
# test suites (test-design-component-registry.R's "rejects missing fields, invalid status, and stale
# method metadata" test_that, test-inference-registry-capability-contracts.R and friends) exercise
# the missing-field, invalid-status, and stale-method-metadata branches on real registered
# components, but never this specific name-validity branch on either validator.

test_that("validate_design_component(): an empty or non-scalar name errors with the documented message", {
	valid <- EDI:::get_design_component("BatchWPregeneration")

	bad_empty <- valid
	bad_empty$name <- ""
	expect_error(EDI:::validate_design_component(bad_empty), "Design component field `name` must be a non-empty character scalar\\.")

	bad_vector <- valid
	bad_vector$name <- c("a", "b")
	expect_error(EDI:::validate_design_component(bad_vector), "Design component field `name` must be a non-empty character scalar\\.")

	bad_numeric <- valid
	bad_numeric$name <- 1
	expect_error(EDI:::validate_design_component(bad_numeric), "Design component field `name` must be a non-empty character scalar\\.")
})

test_that("validate_inference_component(): an empty or non-scalar name errors with the documented message", {
	valid <- EDI:::get_inference_component("Wald")

	bad_empty <- valid
	bad_empty$name <- ""
	expect_error(EDI:::validate_inference_component(bad_empty), "Inference component field `name` must be a non-empty character scalar\\.")

	bad_vector <- valid
	bad_vector$name <- c("a", "b")
	expect_error(EDI:::validate_inference_component(bad_vector), "Inference component field `name` must be a non-empty character scalar\\.")

	bad_numeric <- valid
	bad_numeric$name <- 1
	expect_error(EDI:::validate_inference_component(bad_numeric), "Inference component field `name` must be a non-empty character scalar\\.")
})
