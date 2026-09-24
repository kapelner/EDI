library(testthat)
library(EDI)

# fast_log_binomial_regression_cpp and fast_identity_binomial_regression_cpp
# (fast_log_binomial_regression.cpp) both dispatch to the shared
# fit_constrained_binomial_cpp_impl(), which validates warm_start_beta's length against ncol(X)
# before using it as the optimizer's starting point: `if (beta.size() != p) throw
# std::invalid_argument("warm_start_beta must have length equal to ncol(X)")`. A codebase-wide grep
# across testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/ confirms zero references
# to warm_start_beta anywhere for either kernel (the existing log/identity-binomial reference test
# only exercises fixed coefficients, working weights and the iteration cap, never warm_start_beta) --
# a sibling gap to the same wrong-length-warm-start pattern already closed this stretch for
# fast_probit_regression_cpp and fast_weibull_regression_cpp.

f_log <- get("fast_log_binomial_regression_cpp", envir = asNamespace("EDI"))
f_identity <- get("fast_identity_binomial_regression_cpp", envir = asNamespace("EDI"))
set.seed(17); n <- 60L
X <- cbind(1, rnorm(n))
y <- rbinom(n, 1, 0.3)

test_that("fast_log_binomial_regression_cpp: a warm_start_beta of the wrong length throws the length-mismatch error", {
	expect_error(f_log(X, y, warm_start_beta = c(0.1, 0.2, 0.3)), "warm_start_beta must have length equal to ncol\\(X\\)")
	expect_error(f_log(X, y, warm_start_beta = 0.1), "warm_start_beta must have length equal to ncol\\(X\\)")
})

test_that("fast_identity_binomial_regression_cpp: a warm_start_beta of the wrong length throws the same error", {
	expect_error(f_identity(X, y, warm_start_beta = c(0.1, 0.2, 0.3)), "warm_start_beta must have length equal to ncol\\(X\\)")
	expect_error(f_identity(X, y, warm_start_beta = 0.1), "warm_start_beta must have length equal to ncol\\(X\\)")
})

test_that("a correctly-sized warm_start_beta does not trigger the guard and both kernels fit normally", {
	r_log <- f_log(X, y, warm_start_beta = c(-1, 0))
	expect_true(r_log$converged)
	expect_length(r_log$b, 2L)

	r_identity <- f_identity(X, y, warm_start_beta = c(0.3, 0))
	expect_length(r_identity$b, 2L)
	expect_true(all(is.finite(r_identity$b)))
})
