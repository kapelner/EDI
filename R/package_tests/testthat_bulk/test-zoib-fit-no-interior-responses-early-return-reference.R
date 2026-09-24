library(testthat)
library(EDI)

# .fit_zero_one_inflated_beta() (helper_zoib.R) returns NULL immediately -- before ever
# constructing a start vector or calling fast_zero_one_inflated_beta_cpp() -- when
# sum(y > 0 & y < 1) == 0L, i.e. every response is a boundary value (0 or 1) and none lie
# in the open (0, 1) interval the beta submodel needs to fit. A codebase-wide grep confirmed
# this early-return branch had zero test references anywhere (the existing
# test-zoib-fit-input-validation-guards-reference.R only covers row-count/range guards,
# never this all-boundary case). Deliberately does NOT probe the fast_zero_one_inflated_beta_cpp
# kernel itself (known intermittently crashing per this session's standing instructions) --
# this branch is reached and returns before that call is ever made, confirmed by reading the
# source: the `if (sum(y > 0 & y < 1) == 0L) return(NULL)` guard at line 102 precedes the
# `fast_zero_one_inflated_beta_cpp(...)` call at line 126.

test_that("all-zero responses return NULL without attempting a fit", {
	set.seed(1)
	X <- matrix(rnorm(20), ncol = 1)
	expect_null(EDI:::.fit_zero_one_inflated_beta(rep(0, 20), X))
})

test_that("all-one responses return NULL without attempting a fit", {
	set.seed(2)
	X <- matrix(rnorm(20), ncol = 1)
	expect_null(EDI:::.fit_zero_one_inflated_beta(rep(1, 20), X))
})

test_that("a mix of only 0s and 1s (no interior values) returns NULL without attempting a fit", {
	set.seed(3)
	n <- 20
	X <- matrix(rnorm(n), ncol = 1)
	y <- ifelse(rnorm(n) > 0, 0, 1)
	expect_true(sum(y > 0 & y < 1) == 0L)
	expect_null(EDI:::.fit_zero_one_inflated_beta(y, X))
})
