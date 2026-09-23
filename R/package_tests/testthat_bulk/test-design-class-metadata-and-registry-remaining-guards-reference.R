library(testthat)
library(EDI)

# design_class_registry.R's validate_design_class_metadata() has more sibling field-type guards
# beyond the ones already tested (test-metadata-validators-field-type-guards-reference.R covered
# parent/abstract/exported/seed_reproducible_draw; test-design-class-registry.R covers the
# randomization_family/timing_family enum guards): seed_reproducible_draw_requires_single_thread's
# own type guard plus its cross-field consistency check ("only meaningful when
# seed_reproducible_draw is TRUE"), and direct_components/supports_batch_w_pregeneration/
# required_packages. Separately, validate_design_class_registry() (the whole-registry-level
# validator, as opposed to the per-record validator) has its own three guards -- registry must be a
# list, each record's name must match its registry key, and each record's parent must itself be a
# registered key -- none of which had any test references anywhere.

test_that("validate_design_class_metadata(): the remaining field-type and cross-field guards each error with the documented message", {
	valid <- EDI:::get_design_class_metadata("DesignFixedBernoulli")

	bad_single_thread_type <- valid; bad_single_thread_type$seed_reproducible_draw_requires_single_thread <- "not_logical"
	expect_error(EDI:::validate_design_class_metadata(bad_single_thread_type), "invalid `seed_reproducible_draw_requires_single_thread`")

	bad_single_thread_consistency <- valid
	bad_single_thread_consistency$seed_reproducible_draw <- FALSE
	bad_single_thread_consistency$seed_reproducible_draw_requires_single_thread <- TRUE
	expect_error(EDI:::validate_design_class_metadata(bad_single_thread_consistency), "only meaningful when `seed_reproducible_draw` is TRUE")

	bad_direct_components <- valid; bad_direct_components$direct_components <- 123
	expect_error(EDI:::validate_design_class_metadata(bad_direct_components), "invalid `direct_components`")

	bad_batch_w <- valid; bad_batch_w$supports_batch_w_pregeneration <- "not_logical"
	expect_error(EDI:::validate_design_class_metadata(bad_batch_w), "invalid `supports_batch_w_pregeneration`")

	bad_required_packages <- valid; bad_required_packages$required_packages <- 123
	expect_error(EDI:::validate_design_class_metadata(bad_required_packages), "invalid `required_packages`")
})

test_that("validate_design_class_registry(): a non-list registry errors with the documented message", {
	expect_error(EDI:::validate_design_class_registry(registry = "not_a_list"), "Design class registry must be a list of metadata records\\.")
})

test_that("validate_design_class_registry(): a record's name diverging from its registry key errors with the documented message", {
	registry <- EDI:::design_class_registry_as_list()
	bad_registry <- registry
	bad_registry[["DesignFixedBernoulli"]]$name <- "WrongName"
	expect_error(EDI:::validate_design_class_registry(registry = bad_registry), "Design metadata name mismatch for registry key DesignFixedBernoulli\\.")
})

test_that("validate_design_class_registry(): a record's parent not itself a registered key errors with the documented message", {
	registry <- EDI:::design_class_registry_as_list()
	bad_registry <- registry
	bad_registry[["DesignFixedBernoulli"]]$parent <- "NoSuchParentClass"
	expect_error(EDI:::validate_design_class_registry(registry = bad_registry), "Design metadata for DesignFixedBernoulli has unregistered parent NoSuchParentClass\\.")
})

test_that("validate_design_class_registry(): the real, live registry passes validation silently", {
	expect_true(isTRUE(EDI:::validate_design_class_registry()))
})
