library(testthat)
library(EDI)

# contracts_mixins.R's resolve_component_dependencies() rejects a direct component list that also
# names one of its own components' transitive dependencies directly ("Direct component list
# duplicates transitive dependency component(s): ..."), distinct from the already-covered plain
# same-name-twice guard ("Duplicate direct component(s)",
# test-resolve-component-dependencies-duplicate-direct-guard-reference.R). The identically-shaped
# design-side sibling ("Direct design component list duplicates transitive dependency component(s)")
# is already covered, but this inference-side guard had zero test references anywhere. Reachable
# with Wald (a real component whose own dependencies include Jackknife) supplied alongside Jackknife
# directly.

test_that("resolve_component_dependencies(): naming a direct dependency's own transitive dependency errors with the documented message", {
	expect_identical(EDI:::get_inference_component("Wald")$dependencies, "Jackknife")
	expect_error(
		EDI:::resolve_component_dependencies(c("Wald", "Jackknife")),
		"Direct component list duplicates transitive dependency component\\(s\\): Jackknife"
	)
})

test_that("resolve_component_dependencies(): Wald alone resolves Jackknife transitively without error", {
	resolved <- EDI:::resolve_component_dependencies("Wald")
	expect_true(all(c("Wald", "Jackknife") %in% resolved))
})
