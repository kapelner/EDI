library(testthat)
library(EDI)

# edi_unlock_binding_cpp(name, env): the C-level R_unLockBinding. Reference: base R's bindingIsLocked / lockBinding.

U <- get("edi_unlock_binding_cpp", asNamespace("EDI"))

test_that("unlocks a locked binding so it can be reassigned, and leaves the value intact", {
	e <- new.env(); assign("x", 1, e); lockBinding("x", e)
	expect_true(bindingIsLocked("x", e))
	expect_error(assign("x", 2, e), "cannot change value of locked binding")
	expect_null(U("x", e))
	expect_false(bindingIsLocked("x", e))
	expect_equal(get("x", e), 1)
	assign("x", 2, e); expect_equal(get("x", e), 2)
})

test_that("only the named binding is unlocked; the environment lock is untouched", {
	e <- new.env(); assign("a", 1, e); assign("b", 2, e)
	lockBinding("a", e); lockBinding("b", e); lockEnvironment(e)
	U("a", e)
	expect_false(bindingIsLocked("a", e)); expect_true(bindingIsLocked("b", e))
	expect_true(environmentIsLocked(e))
	assign("a", 10, e); expect_equal(get("a", e), 10)
	expect_error(assign("new", 1, e), "cannot add binding")
})

test_that("unlocking an already-unlocked binding is a harmless no-op", {
	e <- new.env(); assign("x", 1, e)
	expect_no_error(U("x", e)); expect_false(bindingIsLocked("x", e))
})

test_that("a missing binding errors in R (no silent creation)", {
	e <- new.env()
	expect_error(U("nope", e))
	expect_false(exists("nope", e, inherits = FALSE))
})

test_that("works on R6 public bindings locked by the class (the package's actual use)", {
	Gen <- R6::R6Class("T", public = list(f = function() 1), lock_objects = TRUE)
	o <- Gen$new(); env <- as.environment(o)
	expect_true(bindingIsLocked("f", env))
	U("f", env)
	expect_false(bindingIsLocked("f", env))
	env$f <- function() 2
	expect_equal(o$f(), 2)
})
