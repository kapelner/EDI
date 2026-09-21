library(testthat)
library(EDI)

# Parser-backed body-reference contract: component_body_references / component_declared_reference_names (inference,
# contracts_mixins.R) and their design_component_* twins (design_component_registry.R). Hand-built components with
# known private$/self$/super$ references are compared with hand-listed expectations.

Z <- function(x) get(x, envir = asNamespace("EDI"))

comp <- list(
	name = "demo",
	public = list(
		run = function() { self$helper(); private$state <- 1; invisible(private$cache) },
		helper = function() super$base_method()
	),
	private = list(
		compute = function(x) { private$cache <- x; private$other(x); self$run(); super$deep$inner },
		other = function(x) if (x) private$flag else self$helper()
	)
)

test_that("inference parser collects private$/self$/super$ references from public and private bodies, sorted and unique", {
	r <- Z("component_body_references")(comp)
	expect_named(r, c("private", "self", "super"))
	expect_identical(r$private, c("cache", "flag", "other", "state"))
	expect_identical(r$self, c("helper", "run"))
	expect_identical(r$super, c("base_method", "deep"))
})

test_that("design parser tracks only private and self receivers", {
	r <- Z("design_component_body_references")(comp)
	expect_named(r, c("private", "self"))
	expect_identical(r$private, c("cache", "flag", "other", "state"))
	expect_identical(r$self, c("helper", "run"))
})

test_that("non-function slots, empty components, and unrelated receivers are ignored", {
	empty <- list(name = "e", public = list(), private = list())
	expect_identical(Z("component_body_references")(empty), list(private = character(), self = character(), super = character()))
	odd <- list(public = list(x = 5, f = function() other$thing + private$real), private = NULL)
	r <- Z("component_body_references")(odd)
	expect_identical(r$private, "real"); expect_identical(r$self, character())
})

test_that("bracket access private[['x']] is not detected (parser only sees the $ form)", {
	c2 <- list(public = list(f = function() private[["hidden"]]), private = list())
	expect_identical(Z("component_body_references")(c2)$private, character())
})

test_that("declared-name collectors merge every contract field per receiver, sorted and unique", {
	spec <- list(
		provides_private_methods = c("other", "compute"), owns_state = c("cache", "state"),
		requires_state = "flag", requires_private_methods = "compute", optional_private_methods = "zz",
		forbidden_refs = list(private = "banned_p", self = "banned_s", super = "banned_u"),
		provides_public_methods = "run", requires_public_methods = c("helper", "run"), optional_public_methods = "opt",
		requires_super_methods = c("base_method", "deep"))
	d <- Z("component_declared_reference_names")(spec)
	expect_identical(d$private, c("banned_p", "cache", "compute", "flag", "other", "state", "zz"))
	expect_identical(d$self, c("banned_s", "helper", "opt", "run"))
	expect_identical(d$super, c("banned_u", "base_method", "deep"))
	dd <- Z("design_component_declared_reference_names")(spec)
	expect_named(dd, c("private", "self"))
	expect_identical(dd$private, c("cache", "compute", "flag", "other", "state", "zz"))   # no forbidden_refs in designs
	expect_identical(dd$self, c("helper", "opt", "run"))
	e <- Z("component_declared_reference_names")(list())
	expect_identical(e, list(private = character(), self = character(), super = character()))
})

test_that("design validator passes when every reference is declared and lists offenders otherwise", {
	v <- Z("validate_design_component_body_references")
	ok <- c(comp, list(provides_private_methods = c("other", "compute"), owns_state = c("cache", "state", "flag"),
		provides_public_methods = c("run", "helper")))
	ok$name <- "demo"
	expect_true(v(ok))
	bad <- ok; bad$owns_state <- "cache"; bad$provides_public_methods <- "run"
	expect_error(v(bad), "demo has undeclared private reference\\(s\\): flag, state")
	expect_error(v(bad), "demo has undeclared self reference\\(s\\): helper")
})
