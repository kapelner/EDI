library(testthat)
library(EDI)

# design_component_registry.R's clear_design_component_registry() (EDI_DESIGN_COMPONENTS, the
# design-side sibling of contracts_mixins.R's clear_inference_component_registry(), already
# covered by test-inference-component-registry-clear-register-dependency-propagation-and-
# idempotence-reference.R) had zero test references anywhere. Simpler than its inference-side
# counterpart: no lazy loading, no on-demand per-spec registration, and
# populate_design_component_registry() itself calls clear() first before re-registering
# everything, so there's no separate "register one on demand" API to exercise here. The full
# registry is restored at the end regardless of outcome, since it is shared namespace-level state.

ns <- asNamespace("EDI")
clear <- get("clear_design_component_registry", envir = ns)
as_list <- get("design_component_registry_as_list", envir = ns)
get_component <- get("get_design_component", envir = ns)
populate <- get("populate_design_component_registry", envir = ns)
registry_env <- get("EDI_DESIGN_COMPONENTS", envir = ns)
before_names <- sort(ls(registry_env))
withr::defer(populate())

test_that("clear() empties the registry; a lookup on the empty registry errors by name; as-list is empty", {
	expect_gt(length(before_names), 0L)                                    # sanity: the real registry starts non-empty
	clear()
	expect_length(ls(registry_env), 0L)
	expect_error(get_component("BlockingStructure"), "No design component registered for BlockingStructure", fixed = TRUE)
	expect_length(as_list(), 0L)
})

test_that("populate_design_component_registry() restores exactly the original set of component names after a clear", {
	clear()
	expect_length(ls(registry_env), 0L)
	populate()
	expect_setequal(ls(registry_env), before_names)
	expect_length(as_list(), length(before_names))
	expect_identical(sort(names(as_list())), before_names)
})

test_that("clearing the registry mid-session does not break an already-defined design class's runtime behaviour", {
	clear()
	set.seed(1); n <- 20L
	d <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	d$assign_w_to_all_subjects()
	expect_equal(length(d$get_w()), n)
	populate()
})
