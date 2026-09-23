library(testthat)
library(EDI)

# contracts_mixins.R's resolve_component_dependencies() rejects duplicate direct component names
# ("Duplicate direct component(s): ...") before resolving dependencies. The identically-shaped
# design-side sibling (resolve_design_component_dependencies()'s own "Duplicate direct design
# component(s)" guard) is already covered (test-design-component-registry.R,
# test-combine-design-component-slot-merge-order-collisions-and-host-override-rules-reference.R),
# and this function's own "Unknown component" guard is covered
# (test-inference-registry-capability-contracts.R), but the duplicate-direct-name guard itself had
# zero test references anywhere.

test_that("resolve_component_dependencies(): a duplicated direct component name errors with the documented message", {
	expect_error(
		EDI:::resolve_component_dependencies(c("Wald", "Wald")),
		"Duplicate direct component\\(s\\): Wald"
	)
})

test_that("resolve_component_dependencies(): distinct direct component names resolve without error", {
	resolved <- EDI:::resolve_component_dependencies(c("Wald", "RandomizationTest"))
	expect_true(is.character(resolved))
	expect_true(all(c("Wald", "RandomizationTest") %in% resolved))
})
