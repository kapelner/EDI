library(testthat)
library(EDI)

# resolve_design_components / get_effective_design_components / get_effective_design_capabilities: a class's effective
# components are its parents' (root first) followed by its own dependency-resolved direct components; re-listing an
# inherited component (directly or transitively) is an error; capabilities are the de-duplicated union of the
# effective components' provides_capabilities; both effective lookups are cached until cleared.
# Temporary components and probe classes are registered and the registries repopulated on exit.

Z <- function(x) get(x, envir = asNamespace("EDI"))
comp <- function(name, deps = character(), caps = character()) Z("DesignComponent")(name = name, dependencies = deps, provides_capabilities = caps)
regc <- function(...) for (c in list(...)) Z("register_design_component")(c)
regk <- function(name, parent = NULL, comps = character()) {
	Z("register_design_class")(name, parent = parent, direct_components = comps,
		metadata = list(abstract = FALSE, timing_family = "fixed", randomization_family = "bernoulli", seed_reproducible_draw = TRUE))
}
cleanup <- function() { Z("populate_design_component_registry")(); Z("populate_design_class_registry")(); Z("clear_design_effective_metadata_cache")() }

test_that("effective components are parent components first, then own, with dependencies resolved before dependents", {
	withr::defer(cleanup())
	regc(comp("TmpEa"), comp("TmpEb", deps = "TmpEa"), comp("TmpEc"))
	regk("TmpRoot", comps = "TmpEc")
	regk("TmpLeaf", parent = "TmpRoot", comps = "TmpEb")
	expect_identical(Z("resolve_design_components")("TmpRoot"), "TmpEc")
	expect_identical(Z("resolve_design_components")("TmpLeaf"), c("TmpEc", "TmpEa", "TmpEb"))
	expect_identical(Z("get_effective_design_components")("TmpLeaf"), c("TmpEc", "TmpEa", "TmpEb"))
})

test_that("a class with no components (and no parent components) has an empty effective set and no capabilities", {
	withr::defer(cleanup())
	regk("TmpEmpty")
	expect_identical(Z("resolve_design_components")("TmpEmpty"), character())
	expect_identical(Z("get_effective_design_capabilities")("TmpEmpty"), character())
})

test_that("re-listing an inherited component directly is rejected with the class name", {
	withr::defer(cleanup())
	regc(comp("TmpDupA"))
	regk("TmpDupRoot", comps = "TmpDupA"); regk("TmpDupLeaf", parent = "TmpDupRoot", comps = "TmpDupA")
	expect_error(Z("resolve_design_components")("TmpDupLeaf"), "TmpDupLeaf re-lists inherited component\\(s\\): TmpDupA")
})

test_that("a dependency already supplied by the parent is treated as satisfied, not duplicated", {
	withr::defer(cleanup())
	regc(comp("TmpTa"), comp("TmpTb", deps = "TmpTa"))
	regk("TmpTRoot", comps = "TmpTa"); regk("TmpTLeaf", parent = "TmpTRoot", comps = "TmpTb")
	# TmpTb depends on TmpTa which the parent already supplies: the dependency is satisfied, not duplicated
	expect_identical(Z("resolve_design_components")("TmpTLeaf"), c("TmpTa", "TmpTb"))
})

test_that("unknown direct components surface as an error prefixed by the class name", {
	withr::defer(cleanup())
	regk("TmpBadComp", comps = "NoSuchDesignComponentZzz")
	expect_error(Z("resolve_design_components")("TmpBadComp"), "TmpBadComp: Unknown design component")
	expect_error(Z("resolve_design_components")("NoSuchDesignClassZzz"), "No design class metadata registered")
})

test_that("capabilities are the de-duplicated union over effective components, in component order", {
	withr::defer(cleanup())
	regc(comp("TmpCa", caps = c("blocking", "matching")), comp("TmpCb", caps = c("matching", "strata")), comp("TmpCc"))
	regk("TmpCapRoot", comps = "TmpCa"); regk("TmpCapLeaf", parent = "TmpCapRoot", comps = c("TmpCb", "TmpCc"))
	expect_identical(Z("get_effective_design_capabilities")("TmpCapLeaf"), c("blocking", "matching", "strata"))
	expect_identical(Z("get_effective_design_capabilities")("TmpCapRoot"), c("blocking", "matching"))
})

test_that("effective lookups are cached until the cache is cleared", {
	withr::defer(cleanup())
	regc(comp("TmpCache1"), comp("TmpCache2"))
	regk("TmpCacheCls", comps = "TmpCache1")
	first <- Z("get_effective_design_components")("TmpCacheCls")
	env <- Z("EDI_DESIGN_CLASS_REGISTRY")
	rec <- get("TmpCacheCls", envir = env); rec$direct_components <- "TmpCache2"; assign("TmpCacheCls", rec, envir = env)
	expect_identical(Z("get_effective_design_components")("TmpCacheCls"), first)          # stale by design (cached)
	Z("clear_design_effective_metadata_cache")()
	expect_identical(Z("get_effective_design_components")("TmpCacheCls"), "TmpCache2")
})
