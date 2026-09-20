library(testthat)
library(EDI)

# contracts_mixins.R lazy-component plumbing: is_lazy_inference_component(), the expensive-validation
# switch, lazy_component_public_stub() / lazy_component_private_stub() (marker attribute and
# install-then-delegate body), lazy_component_entries() (public stubs, private state placeholders vs
# private method stubs), the per-class component cache environments, cache clearing, and
# r6_root_private_state_names().

Z <- function(x) get(x, envir = asNamespace("EDI"))

test_that("a component is lazy only when its loader policy says so", {
	f <- Z("is_lazy_inference_component")
	expect_true(f(list(component_loader = list(load_policy = "lazy"))))
	expect_false(f(list(component_loader = list(load_policy = "eager"))))
	expect_false(f(list(component_loader = list())))
	expect_false(f(list()))
})

test_that("expensive contract validation is switched on by the option or the environment variable", {
	f <- Z("should_run_expensive_inference_contract_validation")
	withr::local_options(EDI.validate_inference_contracts = NULL)
	withr::local_envvar(EDI_VALIDATE_INFERENCE_CONTRACTS = NA_character_)
	expect_false(f())
	withr::local_options(EDI.validate_inference_contracts = TRUE); expect_true(f())
	withr::local_options(EDI.validate_inference_contracts = FALSE); expect_false(f())
	withr::local_envvar(EDI_VALIDATE_INFERENCE_CONTRACTS = "true"); expect_true(f())
	withr::local_envvar(EDI_VALIDATE_INFERENCE_CONTRACTS = "yes"); expect_false(f())        # only the exact string "true"
})

run_stub <- function(stub, self_env, private_env) {
	calls <- list()
	env <- new.env(parent = asNamespace("EDI"))
	env$self <- self_env; env$private <- private_env
	env$install_lazy_inference_component <- function(self, private, class_name, component_name) {
		calls[[length(calls) + 1L]] <<- list(class = class_name, component = component_name)
		invisible(NULL)
	}
	environment(stub) <- env
	list(run = function(...) stub(...), calls = function() calls)
}

test_that("public and private stubs carry the marker attribute and install the component before delegating", {
	pub <- Z("lazy_component_public_stub")("CompX", "do_thing")
	prv <- Z("lazy_component_private_stub")("CompX", "helper")
	expect_identical(attr(pub, "inference_lazy_component_stub"), "CompX")
	expect_identical(attr(prv, "inference_lazy_component_stub"), "CompX")
	self_env <- new.env(); self_env[["do_thing"]] <- function(...) paste("public", ...)
	class(self_env) <- c("SomeLeaf")
	private_env <- new.env(); private_env[["helper"]] <- function(...) paste("private", ...)
	p <- run_stub(pub, self_env, private_env)
	expect_equal(p$run("a", "b"), "public a b")
	expect_equal(p$calls(), list(list(class = "SomeLeaf", component = "CompX")))
	q <- run_stub(prv, self_env, private_env)
	expect_equal(q$run(1), "private 1")
	expect_equal(q$calls()[[1]]$component, "CompX")
})

test_that("lazy entries: one stub per provided public method; private state stays a NULL placeholder, private methods get stubs", {
	comp <- list(name = "CompY", provides_public_methods = c("a", "b"),
		provides_private_methods = c("m1", "state1", "m2"), owns_state = c("state1", "other"))
	pub <- Z("lazy_component_entries")(comp, "public")
	expect_named(pub, c("a", "b"))
	expect_true(all(vapply(pub, function(x) is.function(x) && identical(attr(x, "inference_lazy_component_stub"), "CompY"), logical(1))))
	prv <- Z("lazy_component_entries")(comp, "private")
	expect_setequal(names(prv), c("state1", "m1", "m2"))
	expect_null(prv$state1)
	expect_true(is.function(prv$m1) && is.function(prv$m2))
	expect_identical(attr(prv$m1, "inference_lazy_component_stub"), "CompY")
	empty <- list(name = "E", provides_public_methods = character(0), provides_private_methods = character(0), owns_state = character(0))
	expect_length(Z("lazy_component_entries")(empty, "public"), 0L)
	expect_length(Z("lazy_component_entries")(empty, "private"), 0L)
})

test_that("component cache environments are created once per class name and are independent", {
	g <- Z("get_inference_component_cache_env")
	nm1 <- paste0("CacheTestClass", sample.int(1e6, 1)); nm2 <- paste0(nm1, "b")
	a <- g(nm1)
	expect_true(is.environment(a)); expect_identical(g(nm1), a)
	expect_false(identical(g(nm2), a))
	assign("k", 1, envir = a)
	expect_equal(get("k", envir = g(nm1)), 1)
	expect_false(exists("k", envir = g(nm2), inherits = FALSE))
	expect_identical(g(NULL), g("<global>"))                                              # NULL means the global bucket
	expect_identical(emptyenv(), parent.env(a))
	cache <- Z("EDI_INFERENCE_COMPONENT_IMPLEMENTATION_CACHE")
	rm(list = c(nm1, nm2), envir = cache)
})

test_that("clearing the implementation caches empties all four registries and is repeatable", {
	Z("get_inference_component_cache_env")("ClearTestClass")
	Z("get_inference_component_dispatch_cache_env")("ClearTestClass")
	expect_true(Z("clear_inference_component_implementation_cache")())
	for (nm in c("EDI_INFERENCE_COMPONENT_IMPLEMENTATION_CACHE", "EDI_INFERENCE_LAZY_DISPATCH_CACHE", "EDI_INFERENCE_COMPONENT_LOAD_TRACE", "EDI_OPTIONAL_PACKAGE_AVAILABILITY_CACHE"))
		expect_length(ls(Z(nm)), 0L)
	expect_true(Z("clear_inference_component_implementation_cache")())
	expect_identical(Z("inference_component_load_trace")("ClearTestClass"), character())
	# Caches repopulate lazily afterwards: a lazily-loaded class still works.
	set.seed(1); n <- 20L
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects(); des$add_all_subject_responses(rpois(n, 3))
	expect_true(is.finite(InferenceCountPoisson$new(des, verbose = FALSE)$compute_estimate()))
})

test_that("root private state names come from the root of the inheritance chain (Inference)", {
	f <- Z("r6_root_private_state_names")
	expect_identical(f(NULL), character())
	root <- names(Z("Inference")$private_fields)
	expect_gt(length(root), 5L)
	expect_true(all(c("des_obj", "cached_values", "harden") %in% root))
	expect_identical(f(Z("Inference")), root)
	expect_identical(f(Z("InferenceContinOLS")), root)                                   # any descendant resolves to the same root
	expect_identical(f(Z("InferenceCountPoisson")), root)
	Mid <- R6::R6Class("MidX", inherit = Z("InferenceContinOLS"))
	expect_identical(f(Mid), root)
})
