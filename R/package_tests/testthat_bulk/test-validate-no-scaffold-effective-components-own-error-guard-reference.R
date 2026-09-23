library(testthat)
library(EDI)

# validate_no_scaffold_effective_components() (contracts_mixins.R) has its own
# "%s uses scaffold component(s): %s" stop() branch, distinct from the
# "Scaffold component(s) cannot be resolved" error raised inside
# resolve_component_dependencies()/get_effective_components(). The existing
# scaffold-component reference test (test-mixin-contracts.R) only exercises
# the resolve-time error: registering a class that directly composes a
# scaffold component fails during get_effective_components() itself, before
# validate_no_scaffold_effective_components() ever gets to inspect the
# resolved set and find a scaffold entry in it. That means this function's own
# check -- "did the (already successfully resolved) effective-components set
# end up containing a scaffold component anyway" -- had no test reference
# anywhere in the tree.
#
# get_effective_components() serves cached entries straight out of
# EDI_INFERENCE_EFFECTIVE_COMPONENTS_CACHE without re-running any scaffold
# check, so seeding that cache directly for a synthetic class name reaches
# validate_no_scaffold_effective_components()'s own branch without needing to
# route through (and get intercepted by) the resolver's check.

test_that("validate_no_scaffold_effective_components errors when the effective-components cache holds a scaffold component", {
	EDI:::populate_inference_component_registry()
	on.exit(EDI:::populate_inference_component_registry(), add = TRUE)
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "TemporaryScaffoldComponentForCacheProbe",
		status = "scaffold",
		file = "test"
	))

	fake_class_name = "InferenceTemporaryScaffoldCacheProbeHost"
	on.exit(
		rm(list = fake_class_name, envir = EDI:::EDI_INFERENCE_EFFECTIVE_COMPONENTS_CACHE),
		add = TRUE
	)
	assign(
		fake_class_name,
		"TemporaryScaffoldComponentForCacheProbe",
		envir = EDI:::EDI_INFERENCE_EFFECTIVE_COMPONENTS_CACHE
	)

	expect_error(
		EDI:::validate_no_scaffold_effective_components(class_names = fake_class_name),
		"uses scaffold component\\(s\\)"
	)
})
