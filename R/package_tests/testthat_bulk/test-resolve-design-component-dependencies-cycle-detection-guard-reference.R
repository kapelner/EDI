library(testthat)
library(EDI)

# design_component_registry.R's resolve_design_component_dependencies() has its own dependency-cycle
# detection guard ("Design component dependency cycle detected: A -> B -> A"), the design-side
# sibling of the already-tested inference-side cycle guard on load_inference_component()/
# resolve_component_dependencies() ("Component dependency cycle detected",
# test-mixin-contracts.R's "lazy loader reports transitive dependency order and detects cycles").
# Had zero test references anywhere. Exercised with two hand-registered design components that
# depend on each other, cleaned up via populate_design_component_registry() on exit.

test_that("resolve_design_component_dependencies(): a two-component dependency cycle errors with the documented message", {
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)

	for (spec in list(
		list(name = "TmpDesignCycleA", deps = "TmpDesignCycleB"),
		list(name = "TmpDesignCycleB", deps = "TmpDesignCycleA")
	)) {
		EDI:::register_design_component(EDI:::DesignComponent(name = spec$name, dependencies = spec$deps))
	}

	expect_error(
		EDI:::resolve_design_component_dependencies("TmpDesignCycleA"),
		"Design component dependency cycle detected: TmpDesignCycleA -> TmpDesignCycleB -> TmpDesignCycleA"
	)
})

test_that("resolve_design_component_dependencies(): an acyclic dependency chain resolves without error", {
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)

	EDI:::register_design_component(EDI:::DesignComponent(name = "TmpDesignChainA"))
	EDI:::register_design_component(EDI:::DesignComponent(name = "TmpDesignChainB", dependencies = "TmpDesignChainA"))

	resolved <- EDI:::resolve_design_component_dependencies("TmpDesignChainB")
	expect_identical(resolved, c("TmpDesignChainA", "TmpDesignChainB"))
})
