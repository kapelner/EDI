library(testthat)
library(EDI)

# randomization_loop_cpp(r, duplicate_design_fn, duplicate_inference_fn, run_iteration_fn, num_cores): builds one design and
# one inference copy up front, then calls run_iteration_fn(list(design =, inference =)) r times in order, keeping the first
# element of each result. Reference: an R closure counting calls and recording arguments.

K <- get("randomization_loop_cpp", envir = asNamespace("EDI"))

test_that("duplicators run exactly once; the iteration callback runs r times, in order, on the same object pair", {
	calls <- character(); seen <- list()
	dd <- function() { calls <<- c(calls, "design"); "DES" }
	di <- function() { calls <<- c(calls, "inference"); "INF" }
	k <- 0
	it <- function(objs) { k <<- k + 1; seen[[k]] <<- objs; k * 10 }
	out <- K(5L, dd, di, it)
	expect_identical(out, c(10, 20, 30, 40, 50))
	expect_identical(calls, c("design", "inference"))                  # design first, inference second, once each
	expect_length(seen, 5L)
	for (s in seen) { expect_named(s, c("design", "inference")); expect_identical(s$design, "DES"); expect_identical(s$inference, "INF") }
})

test_that("only the first element of each callback result is kept; integer / longer results coerce to double", {
	expect_identical(K(3L, function() 1, function() 2, function(o) c(7L, 8L, 9L)), c(7, 7, 7))
	i <- 0; expect_identical(K(4L, function() 1, function() 2, function(o) { i <<- i + 1; c(i, -i) }), c(1, 2, 3, 4))
})

test_that("r = 0 returns an empty numeric vector without calling the callback (duplicators are still called)", {
	n_dup <- 0; n_it <- 0
	out <- K(0L, function() { n_dup <<- n_dup + 1; 1 }, function() { n_dup <<- n_dup + 1; 2 }, function(o) { n_it <<- n_it + 1; 1 })
	expect_identical(out, numeric(0)); expect_identical(n_it, 0); expect_identical(n_dup, 2)
})

test_that("state changes made by the callback on the shared objects persist across iterations (environments)", {
	e <- new.env(); e$count <- 0
	out <- K(4L, function() e, function() "inf", function(o) { o$design$count <- o$design$count + 1; o$design$count })
	expect_identical(out, c(1, 2, 3, 4)); expect_identical(e$count, 4)
})

test_that("errors from a duplicator or from an iteration propagate and stop the loop", {
	n <- 0
	expect_error(K(3L, function() stop("no design"), function() 1, function(o) 1), "no design")
	expect_error(K(3L, function() 1, function() stop("no inference"), function(o) 1), "no inference")
	expect_error(K(5L, function() 1, function() 1, function(o) { n <<- n + 1; if (n == 3) stop("boom at 3"); 1 }), "boom at 3")
	expect_identical(n, 3)
})

test_that("callback result contract: a non-numeric result is an error, but an EMPTY numeric result is not (unchecked result[0])", {
	expect_error(K(2L, function() 1, function() 1, function(o) "text"))
	# ROBUSTNESS GAP (not fixed here): `result[0]` on a length-0 vector is read without a length check; Rcpp only warns
	# ("subscript out of bounds") and the loop continues, so the entry is undefined instead of the call failing.
	out <- NULL
	expect_warning(out <- K(2L, function() 1, function() 1, function(o) numeric(0)), "subscript out of bounds")
	expect_length(out, 2L)
})

test_that("num_cores is accepted and does not change the (serial) result", {
	f1 <- function(o) 1
	expect_identical(K(3L, function() 1, function() 1, f1, num_cores = 1L), K(3L, function() 1, function() 1, f1, num_cores = 4L))
})
