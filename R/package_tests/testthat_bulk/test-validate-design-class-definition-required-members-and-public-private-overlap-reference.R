library(testthat)
library(EDI)

# validate_design_class_definition(): a design class must supply the public methods / private methods / private state
# its components require (counting inherited R6 members), and public and private names may not overlap unless declared.
# normalise_design_overrides() fills missing override slots with character(0). Hand-built components and R6 bases.

Z <- function(x) get(x, envir = asNamespace("EDI"))
validate <- Z("validate_design_class_definition")
mkc <- function(name, ...) Z("DesignComponent")(name = name, ...)
reg <- function(...) for (c in list(...)) Z("register_design_component")(c)
cleanup <- function() Z("populate_design_component_registry")()
f <- function() 1

test_that("normalise_design_overrides fills absent slots and preserves given ones", {
	n <- Z("normalise_design_overrides")
	expect_identical(n(), list(public = character(), private = character(), public_private = character()))
	expect_identical(n(NULL)$public, character())
	expect_identical(n(list(public = "a", public_private = c("x", "y"))),
		list(public = "a", private = character(), public_private = c("x", "y")))
})

test_that("a class with no components and no overlap validates", {
	expect_true(validate("Ok", public = list(a = f), private = list(b = f)))
	expect_true(validate("Ok", component_names = character()))
})

test_that("public/private name duplication is an error unless listed in overrides$public_private", {
	expect_error(validate("Dup", public = list(x = f), private = list(x = f)),
		"Dup has undeclared public/private name duplication: x")
	expect_true(validate("Dup", public = list(x = f), private = list(x = f), overrides = list(public_private = "x")))
	expect_error(validate("Dup", public = list(x = f, y = f), private = list(x = f, y = f), overrides = list(public_private = "x")),
		"duplication: y")
	# active bindings count as public names
	expect_error(validate("Dup", active = list(z = f), private = list(z = f)), "duplication: z")
})

test_that("inherited R6 public and private members satisfy component requirements and count toward overlap", {
	withr::defer(cleanup())
	reg(mkc("TmpV1", requires_public_methods = "pub_m", requires_private_methods = "priv_m", requires_state = "st",
		private = list(), public = list()))
	Base <- R6::R6Class("TmpBaseV", public = list(pub_m = f), private = list(priv_m = f, st = NULL))
	expect_true(validate("Child", inherit = Base, component_names = "TmpV1"))
	# grandparent members are collected too
	Mid <- R6::R6Class("TmpMidV", inherit = Base, public = list(other = f))
	expect_true(validate("Child", inherit = Mid, component_names = "TmpV1"))
	# an own member that collides with an inherited one from the other side is an overlap
	expect_error(validate("Child", inherit = Base, private = list(pub_m = f)), "duplication: pub_m")
})

test_that("each missing requirement is reported with class, component and member names", {
	withr::defer(cleanup())
	reg(mkc("TmpV2", requires_public_methods = c("a", "b"), requires_private_methods = "p", requires_state = "s"))
	expect_error(validate("Cls", component_names = "TmpV2"),
		"Cls is missing public method\\(s\\) required by TmpV2: a, b")
	expect_error(validate("Cls", component_names = "TmpV2", public = list(a = f, b = f)),
		"Cls is missing private method\\(s\\) required by TmpV2: p")
	expect_error(validate("Cls", component_names = "TmpV2", public = list(a = f, b = f), private = list(p = f)),
		"Cls is missing private state required by TmpV2: s")
	expect_true(validate("Cls", component_names = "TmpV2", public = list(a = f, b = f), private = list(p = f, s = NULL)))
})

test_that("requirements of dependency components are enforced when resolving; resolve_components = FALSE skips them", {
	withr::defer(cleanup())
	reg(mkc("TmpDepBase", requires_public_methods = "needs_base"),
		mkc("TmpDepTop", dependencies = "TmpDepBase"))
	expect_error(validate("Cls", component_names = "TmpDepTop"), "required by TmpDepBase: needs_base")
	expect_true(validate("Cls", component_names = "TmpDepTop", resolve_components = FALSE))
})

test_that("unknown components fail during resolution", {
	expect_error(validate("Cls", component_names = "NoSuchDesignComponentQrs"), "Unknown design component")
})
