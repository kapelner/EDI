library(testthat)
library(EDI)

# Callback budgets make a nonterminating native search fail promptly, including
# when this regression file runs against an older installed package.
bisection_budget_callback <- function(pvalue, limit = 128L) {
  calls <- 0L
  function(r, delta, transform_responses, num_cores = 1L) {
    calls <<- calls + 1L
    if (calls > limit) stop("Bisection exceeded callback budget")
    pvalue(delta)
  }
}

# bisection_ci_loop_cpp and bisection_ci_single_bound_cpp were deleted
# 2026-10-22 (TODO-3) as unused; they and the retained
# bisection_ci_parallel_cpp shim all ran the same edi::bisection_ci_search.
# One-tail regressions now run through the shim, with the other tail given a
# degenerate [x, x] interval that returns x immediately.
one_tail_via_parallel <- function(callback, l, u, cutoff, tol, lower) {
  if (lower) {
    EDI:::bisection_ci_parallel_cpp(callback, 1L, l, u, u, u, cutoff, tol, "none", 1L)[1L]
  } else {
    EDI:::bisection_ci_parallel_cpp(callback, 1L, l, l, l, u, cutoff, tol, "none", 1L)[2L]
  }
}

test_that("native bisection inverts decreasing upper tails", {
  callback <- bisection_budget_callback(function(delta) 1 - delta)
  expect_equal(one_tail_via_parallel(callback, 0, 1, .25, .001, FALSE), .75, tolerance = .002)
  callback <- bisection_budget_callback(function(delta) exp(-delta^2))
  expect_equal(EDI:::bisection_ci_parallel_cpp(callback, 1L, -3, 0, 0, 3, .25, .0001, "none", 1L),
               c(-1, 1) * sqrt(-log(.25)), tolerance = .002)
})

test_that("missing rejection-boundary midpoints terminate for both tails", {
  for (lower in c(TRUE, FALSE)) {
    pvalue <- function(delta) {
      if (delta == .5) return(NA_real_)
      if (lower) delta else 1 - delta
    }
    callback <- bisection_budget_callback(pvalue)
    expect_equal(one_tail_via_parallel(callback, 0, 1, .5, .01, lower), .5, tolerance = 1e-12)
  }
})

test_that("discrete p-value jumps converge in response space", {
  for (lower in c(TRUE, FALSE)) {
    pvalue <- if (lower) function(delta) as.numeric(delta >= .3) else
      function(delta) as.numeric(delta <= .7)
    expected <- if (lower) .3 else .7
    callback <- bisection_budget_callback(pvalue)
    expect_equal(one_tail_via_parallel(callback, 0, 1, .5, .001, lower), expected, tolerance = 1e-12)
  }
})

test_that("native bisection validates inputs and propagates callback failures", {
  callback <- function(...) .5
  expect_error(EDI:::bisection_ci_parallel_cpp(callback, 1L, 1, 0, 1, 1, .5, .01, "none", 1L), "finite and ordered")
  expect_error(EDI:::bisection_ci_parallel_cpp(callback, 1L, 0, 0, 0, Inf, .5, .01, "none", 1L), "finite and ordered")
  expect_error(EDI:::bisection_ci_parallel_cpp(callback, 1L, 0, 1, 1, 1, .5, 0, "none", 1L), "finite and positive")
  expect_error(EDI:::bisection_ci_parallel_cpp(callback, 1L, 0, 1, 1, 1, NA, .01, "none", 1L), "threshold must be finite")
  expect_error(EDI:::bisection_ci_parallel_cpp(function(...) stop("callback failed"),
                                             1L, 0, 1, 1, 1, .5, .01, "none", 1L), "callback failed")
})

test_that("bisection keeps precision on tiny scales and avoids midpoint overflow", {
  callback <- bisection_budget_callback(function(delta) delta / 1e-300)
  tiny <- one_tail_via_parallel(callback, 0, 1e-300, .3, .0001, TRUE)
  expect_equal(tiny / 1e-300, .3, tolerance = .0002)
  callback <- bisection_budget_callback(function(delta) (delta / 1e308 + 1) / 2)
  huge <- one_tail_via_parallel(callback, -1e308, 1e308, .75, .0001, TRUE)
  expect_equal(huge / 1e308, .5, tolerance = .0003)
})
