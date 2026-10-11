library(testthat)
library(EDI)

# This file protects direct callers of the exported native kernels.  R6
# callers obtain starts through get_fit_warm_start_for_length(), but a short
# direct warm start used to resize an Eigen vector and could corrupt memory.

set.seed(105)
n <- 30L
X <- cbind(1, rnorm(n))
y_binary <- rbinom(n, 1, plogis(X[, 2]))
y_count <- rpois(n, exp(0.2 + 0.1 * X[, 2]))
y_prop <- pmin(pmax(rbeta(n, 2, 3), 1e-4), 1 - 1e-4)
y_time <- rexp(n)
y_dead <- rbinom(n, 1, 0.7)

bad_beta_starts <- list(numeric(1), numeric(ncol(X) + 1L))

test_that("affected exported kernels reject short and long coefficient starts", {

	for (start in bad_beta_starts) {
		expect_error(
			fast_logistic_regression_cpp(X, y_binary, warm_start_beta = start),
			"warm_start_beta must have length"
		)
		expect_error(
			fast_poisson_regression_cpp(X, y_count, warm_start_beta = start),
			"warm_start_beta must have length"
		)
		expect_error(
			fast_robust_regression_cpp(X, y_count, warm_start_beta = start),
			"warm_start_beta must have length"
		)
		expect_error(
			fast_beta_regression_cpp(X, y_prop, warm_start_beta = start),
			"warm_start_beta must have length"
		)
		expect_error(
			fast_coxph_regression_cpp(X, y_time, y_dead, warm_start_beta = start),
			"warm_start_beta must have length"
		)
	}

	# If an old regression writes past an Eigen allocation, this collection is
	# where ASAN/Valgrind detects it; with the boundary checks it is silent.
	expect_silent(gc())
})

test_that("working-weight and Fisher-information starts have the same boundary contract", {
	for (fun in list(
		function() fast_logistic_regression_cpp(X, y_binary, warm_start_weights = numeric(n - 1L)),
		function() fast_poisson_regression_cpp(X, y_count, warm_start_weights = numeric(n + 1L)),
		function() fast_robust_regression_cpp(X, y_count, warm_start_weights = numeric(n - 1L))
	)) {
		expect_error(fun(), "warm_start_weights must have length")
	}

	for (fun in list(
		function() fast_logistic_regression_cpp(X, y_binary, warm_start_fisher_info = diag(1, 1L)),
		function() fast_poisson_regression_cpp(X, y_count, warm_start_fisher_info = diag(1, 3L)),
		function() fast_robust_regression_cpp(X, y_count, warm_start_fisher_info = diag(1, 1L)),
		function() fast_beta_regression_cpp(X, y_prop, warm_start_fisher_info = diag(1, ncol(X))),
		function() fast_coxph_regression_cpp(X, y_time, y_dead, warm_start_fisher_info = diag(1, 1L)),
		function() fast_coxph_regression_cpp(
			X, y_time, y_dead, optimization_alg = "lbfgs",
			warm_start_fisher_info = diag(1, 1L)
		)
	)) {
		expect_error(fun(), "warm_start_fisher_info must have dimensions")
	}
})
