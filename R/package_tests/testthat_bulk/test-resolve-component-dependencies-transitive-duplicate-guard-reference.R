library(testthat)
library(EDI)

# contracts_mixins.R's resolve_component_dependencies() rejects a direct component list that also
# names one of its own components' transitive dependencies directly ("Direct component list
# duplicates transitive dependency component(s): ..."), distinct from the already-covered plain
# same-name-twice guard ("Duplicate direct component(s)",
# test-resolve-component-dependencies-duplicate-direct-guard-reference.R). The identically-shaped
# design-side sibling ("Direct design component list duplicates transitive dependency component(s)")
# is already covered, but this inference-side guard had zero test references anywhere. Reachable
# with Wald (a real component whose own dependencies include NonparametricBootstrap) supplied
# alongside NonparametricBootstrap directly.

# v1.0.5 TODO-97 (2026-10-22): the example edge was Wald -> Jackknife, a
# packaging-only dependency that was removed; Wald now depends on
# NonparametricBootstrap, the component whose helpers it calls.
test_that("resolve_component_dependencies(): naming a direct dependency's own transitive dependency errors with the documented message", {
	expect_identical(EDI:::get_inference_component("Wald")$dependencies, "NonparametricBootstrap")
	expect_error(
		EDI:::resolve_component_dependencies(c("Wald", "NonparametricBootstrap")),
		"Direct component list duplicates transitive dependency component\\(s\\): NonparametricBootstrap"
	)
})

test_that("resolve_component_dependencies(): Wald alone resolves NonparametricBootstrap and ResamplingCore transitively without error", {
	resolved <- EDI:::resolve_component_dependencies("Wald")
	expect_identical(resolved, c("ResamplingCore", "NonparametricBootstrap", "Wald"))
})
