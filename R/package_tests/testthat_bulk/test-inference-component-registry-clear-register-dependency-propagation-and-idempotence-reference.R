library(testthat)
library(EDI)

# The lazy inference-component registry (EDI_INFERENCE_COMPONENTS, an environment loaded from EDI_COMPONENT_SPECS): clear_inference_component_registry() empties
# it, register_inference_component_from_spec(name) registers one component ON DEMAND -- recursively registering its spec$dependencies first -- is idempotent (a
# second call for an already-registered name returns the cached entry without re-registering), and errors by name for an unknown spec. ensure_inference_
# components_registered(names) registers a vector of names in one call. populate_inference_component_registry() restores every spec at once. Component
# registration is independent of already-defined inference classes: an object of a class defined before the registry was cleared still works correctly.
# The full registry is restored at the end regardless of outcome, since it is shared namespace-level state.

ns <- asNamespace("EDI")
clear <- get("clear_inference_component_registry", envir = ns)
as_list <- get("inference_component_registry_as_list", envir = ns)
get_component <- get("get_inference_component", envir = ns)
register_one <- get("register_inference_component_from_spec", envir = ns)
ensure <- get("ensure_inference_components_registered", envir = ns)
populate <- get("populate_inference_component_registry", envir = ns)
registry_env <- get("EDI_INFERENCE_COMPONENTS", envir = ns)
specs <- get("EDI_COMPONENT_SPECS", envir = ns)
before_names <- sort(ls(registry_env))
withr::defer(populate())

test_that("clear() empties the registry; a lookup on the empty registry errors by name", {
	clear()
	expect_length(ls(registry_env), 0L)
	expect_error(get_component("Wald"), "No inference component registered for Wald", fixed = TRUE)
	expect_length(as_list(), 0L)
})

test_that("register_inference_component_from_spec() registers on demand, recursively registering dependencies first; a dependency-free spec registers alone", {
	clear()
	dep_free <- Filter(function(nm) length(specs[[nm]]$dependencies %||% character()) == 0L, names(specs))
	nm0 <- dep_free[[1]]
	register_one(nm0)
	expect_setequal(ls(registry_env), nm0)
	clear()
	with_dep <- Find(function(nm) length(specs[[nm]]$dependencies %||% character()) > 0L, names(specs))
	deps <- specs[[with_dep]]$dependencies
	register_one(with_dep)
	expect_true(all(deps %in% ls(registry_env)))
	expect_true(with_dep %in% ls(registry_env))
})

test_that("registering an already-registered name returns the cached entry unchanged (idempotent); an unknown spec name errors by name", {
	clear(); register_one("Wald")
	comp <- get_component("Wald")
	expect_identical(register_one("Wald"), comp)
	expect_error(register_one("NotARealComponent"), "No inference component spec registered for NotARealComponent", fixed = TRUE)
})

test_that("ensure_inference_components_registered() registers a vector of names in one call; populate_inference_component_registry() restores every spec", {
	clear()
	ensure(c("Wald", "BayesianBootstrap"))
	expect_true(all(c("Wald", "BayesianBootstrap") %in% ls(registry_env)))
	populate()
	expect_setequal(ls(registry_env), before_names)
	expect_length(as_list(), length(before_names))
})

test_that("clearing the registry mid-session does not break an already-defined inference class's runtime behaviour", {
	clear()
	set.seed(1); n <- 20L
	d <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinOLS$new(d, verbose = FALSE)
	expect_true(is.finite(inf$compute_estimate()))
	populate()
})
