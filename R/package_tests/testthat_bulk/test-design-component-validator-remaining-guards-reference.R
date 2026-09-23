library(testthat)
library(EDI)

# design_component_registry.R's validate_design_component() has more sibling guards beyond `name`
# (already tested in test-component-validator-name-field-guards-reference.R) and beyond
# missing-field/invalid-status/stale-public-method-metadata (already tested in
# test-design-component-registry.R): a public/private-must-be-lists guard, a non-character-field
# guard, a stale-private-method-metadata guard (the private-side sibling of the already-tested
# stale-public-method guard), an owned-state-declared-as-a-method guard, an invalid
# allowed_host_overrides guard, and register_design_component()'s own already-registered guard. None
# had any test references anywhere.

test_that("validate_design_component(): public/private must be lists", {
	valid <- EDI:::get_design_component("BatchWPregeneration")
	bad <- valid; bad$public <- "not_a_list"
	expect_error(EDI:::validate_design_component(bad), "must provide public/private lists")
})

test_that("validate_design_component(): a non-character required field errors with the documented message", {
	valid <- EDI:::get_design_component("BatchWPregeneration")
	bad <- valid; bad$dependencies <- 123
	expect_error(EDI:::validate_design_component(bad), "has non-character `dependencies`")
})

test_that("validate_design_component(): stale private method metadata errors with the documented message", {
	valid <- EDI:::get_design_component("BatchWPregeneration")
	bad <- valid; bad$provides_private_methods <- c(bad$provides_private_methods, "phantom_private_method")
	expect_error(EDI:::validate_design_component(bad), "stale private method metadata")
})

test_that("validate_design_component(): declaring a real private method name as owned state errors with the documented message", {
	valid <- EDI:::get_design_component("BlockingStructure")
	fn_names <- names(Filter(is.function, valid$private))
	expect_gt(length(fn_names), 0L)
	bad <- valid; bad$owns_state <- c(bad$owns_state, fn_names[1])
	expect_error(EDI:::validate_design_component(bad), sprintf("declares method\\(s\\) as owned state: %s", fn_names[1]))
})

test_that("validate_design_component(): an invalid allowed_host_overrides errors with the documented message", {
	valid <- EDI:::get_design_component("BatchWPregeneration")
	bad <- valid; bad$allowed_host_overrides <- list(public = character())
	expect_error(EDI:::validate_design_component(bad), "invalid `allowed_host_overrides`")
})

test_that("register_design_component(): registering the same name twice errors with the documented message", {
	valid <- EDI:::get_design_component("BatchWPregeneration")
	name <- "BatchWPregenerationTestOnlyDuplicateProbe"
	on.exit(
		if (exists(name, envir = EDI:::EDI_DESIGN_COMPONENTS, inherits = FALSE)) {
			rm(list = name, envir = EDI:::EDI_DESIGN_COMPONENTS)
		},
		add = TRUE
	)

	dup <- valid; dup$name <- name
	expect_false(exists(name, envir = EDI:::EDI_DESIGN_COMPONENTS, inherits = FALSE))
	EDI:::register_design_component(dup)
	expect_true(exists(name, envir = EDI:::EDI_DESIGN_COMPONENTS, inherits = FALSE))

	expect_error(
		EDI:::register_design_component(dup),
		"Design component already registered for BatchWPregenerationTestOnlyDuplicateProbe\\."
	)
})
