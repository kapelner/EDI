library(testthat)
library(EDI)

# fast_robust_regression_cpp (fast_robust_regression.cpp) validates warm_start_weights's length
# up front via the shared require_length() helper (_helper_functions_core.h), before the IRLS loop
# even starts: "warm_start_weights must have length <nrow(X)>". The function's own later, hand-rolled
# check at the first IRLS iteration ("...must have length equal to nrow(X)") is unreachable dead code
# now that require_length() always fires first -- this test's expectations follow the message
# actually thrown. A codebase-wide grep across testthat_bulk/, R/package_tests/testthat/ and
# R/EDI/tests/testthat/ confirms zero references to warm_start_weights anywhere for this kernel --
# the two existing reference files that call fast_robust_regression_cpp never pass it. A sibling gap
# to the same wrong-length-warm-start pattern already closed this stretch for the other kernels'
# warm_start_beta/warm_start_params guards.

f <- get("fast_robust_regression_cpp", envir = asNamespace("EDI"))
set.seed(43); n <- 60L
X <- cbind(1, rnorm(n))
y <- 1 + 0.5 * X[, 2] + rnorm(n)

test_that("warm_start_weights shorter than nrow(X) throws the length-mismatch error, under both method = 'MM' and 'M'", {
	expect_error(f(X, y, warm_start_weights = rep(1, 10)), "warm_start_weights must have length")
	expect_error(f(X, y, warm_start_weights = rep(1, 10), method = "M"), "warm_start_weights must have length")
})

test_that("warm_start_weights longer than nrow(X) throws the same length-mismatch error", {
	expect_error(f(X, y, warm_start_weights = rep(1, n + 5)), "warm_start_weights must have length")
})

test_that("correctly-sized warm_start_weights do not trigger the guard and the fit converges", {
	r <- f(X, y, warm_start_weights = rep(1, n))
	expect_true(r$converged)
	expect_length(r$coefficients, 2L)
})
