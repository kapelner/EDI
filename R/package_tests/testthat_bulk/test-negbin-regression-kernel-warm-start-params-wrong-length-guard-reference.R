library(testthat)
library(EDI)

# fast_neg_bin_cpp (fast_negbin_regression.cpp) validates warm_start_params's length against
# p + 1 (the p covariate coefficients plus log-theta, the dispersion parameter) before using it as
# the optimizer's starting point: `if (params.size() != p + 1) throw std::invalid_argument(
# "warm_start_params must have length equal to the number of model parameters")`. A codebase-wide
# grep across testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/ confirms zero
# references to warm_start_params anywhere for fast_neg_bin_cpp -- the 5 existing files that call it
# never pass warm_start_params, only fixed_idx/fixed_values and default cold starts. A sibling gap to
# the same wrong-length-warm-start pattern already closed this stretch for fast_probit_regression_cpp,
# fast_weibull_regression_cpp, fast_log_binomial_regression_cpp/fast_identity_binomial_regression_cpp,
# and fast_ordinal_regression_cpp.

f <- get("fast_neg_bin_cpp", envir = asNamespace("EDI"))
set.seed(29); n <- 80L
X <- cbind(1, rnorm(n))
y <- rnbinom(n, size = 3, mu = exp(0.5 + 0.3 * X[, 2]))

test_that("a warm_start_params shorter than p + 1 throws the length-mismatch error", {
	expect_error(
		f(X, y, warm_start_params = c(0.1, 0.2)),
		"warm_start_params must have length equal to the number of model parameters"
	)
})

test_that("a warm_start_params longer than p + 1 throws the same length-mismatch error", {
	expect_error(
		f(X, y, warm_start_params = c(0.1, 0.2, 0.3, 0.4)),
		"warm_start_params must have length equal to the number of model parameters"
	)
})

test_that("the guard fires identically under every optimization_alg", {
	for (alg in c("lbfgs", "newton", "bfgs")) {
		expect_error(
			f(X, y, warm_start_params = c(0.1, 0.2), optimization_alg = alg),
			"warm_start_params must have length equal to the number of model parameters",
			info = alg
		)
	}
})

test_that("a correctly-sized warm_start_params (p + 1, covariates plus log-theta) does not trigger the guard and fits normally", {
	r <- f(X, y, warm_start_params = c(0.5, 0.3, log(3)))
	expect_true(r$converged)
	expect_length(r$b, 2L)
	expect_true(is.finite(r$theta_hat))
})
