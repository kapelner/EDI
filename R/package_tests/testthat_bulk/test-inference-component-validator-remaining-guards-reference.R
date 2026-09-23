library(testthat)
library(EDI)

# contracts_mixins.R's validate_inference_component() -- the inference-side sibling of
# design_component_registry.R's validate_design_component() (whose analogous remaining guards were
# just closed in test-design-component-validator-remaining-guards-reference.R) -- has invalid-status,
# public/private-must-be-lists, component_loader-must-be-a-list, invalid-load-policy,
# non-character-field, invalid-likelihood-tier, stale-public-method, and stale-private-method
# guards, plus register_inference_component()'s own already-registered guard. Only the `name` field
# guard (test-component-validator-name-field-guards-reference.R) had been tested before; none of
# these had any test references anywhere.

test_that("validate_inference_component(): an invalid status errors with the documented message", {
	valid <- EDI:::get_inference_component("Wald")
	bad <- valid; bad$status <- "not_a_real_status"
	expect_error(EDI:::validate_inference_component(bad), "Inference component Wald has invalid status\\.")
})

test_that("validate_inference_component(): public/private must be lists", {
	valid <- EDI:::get_inference_component("Wald")
	bad <- valid; bad$public <- "not_a_list"
	expect_error(EDI:::validate_inference_component(bad), "must provide public/private lists")
})

test_that("validate_inference_component(): component_loader must itself be a list", {
	valid <- EDI:::get_inference_component("Wald")
	bad <- valid; bad$component_loader <- "not_a_list"
	expect_error(EDI:::validate_inference_component(bad), "must provide `component_loader` metadata")
})

test_that("validate_inference_component(): an invalid load_policy errors with the documented message", {
	valid <- EDI:::get_inference_component("Wald")
	bad <- valid; bad$component_loader <- list(load_policy = "not_a_real_policy")
	expect_error(EDI:::validate_inference_component(bad), "has invalid load policy")
})

test_that("validate_inference_component(): a non-character required field errors with the documented message", {
	valid <- EDI:::get_inference_component("Wald")
	bad <- valid; bad$dependencies <- 123
	expect_error(EDI:::validate_inference_component(bad), "has non-character `dependencies`")
})

test_that("validate_inference_component(): an invalid allowed_likelihood_tiers entry errors with the documented message", {
	valid <- EDI:::get_inference_component("Wald")
	bad <- valid; bad$allowed_likelihood_tiers <- "not_a_real_tier"
	expect_error(EDI:::validate_inference_component(bad), "has invalid likelihood tier")
})

test_that("validate_inference_component(): stale public/private method metadata each error with the documented message", {
	valid <- EDI:::get_inference_component("Wald")

	bad_public <- valid; bad_public$provides_public_methods <- c(bad_public$provides_public_methods, "phantom_public_method")
	expect_error(EDI:::validate_inference_component(bad_public), "has stale public method metadata")

	bad_private <- valid; bad_private$provides_private_methods <- c(bad_private$provides_private_methods, "phantom_private_method")
	expect_error(EDI:::validate_inference_component(bad_private), "has stale private method metadata")
})

test_that("register_inference_component(): registering the same name twice errors with the documented message", {
	valid <- EDI:::get_inference_component("Wald")
	name <- "WaldTestOnlyDuplicateProbe"
	on.exit(
		if (exists(name, envir = EDI:::EDI_INFERENCE_COMPONENTS, inherits = FALSE)) {
			rm(list = name, envir = EDI:::EDI_INFERENCE_COMPONENTS)
		},
		add = TRUE
	)

	dup <- valid; dup$name <- name
	expect_false(exists(name, envir = EDI:::EDI_INFERENCE_COMPONENTS, inherits = FALSE))
	EDI:::register_inference_component(dup)
	expect_true(exists(name, envir = EDI:::EDI_INFERENCE_COMPONENTS, inherits = FALSE))

	expect_error(
		EDI:::register_inference_component(dup),
		"Inference component already registered for WaldTestOnlyDuplicateProbe\\."
	)
})
