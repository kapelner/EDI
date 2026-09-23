library(testthat)
library(EDI)

# fast_probit_regression.cpp's shared fitting implementation (called by fast_probit_regression_cpp,
# fast_probit_regression_weighted_cpp and fast_probit_regression_with_var_cpp alike) throws
# std::invalid_argument("warm_start_beta must have length equal to ncol(X)") when a caller-supplied
# warm_start_beta doesn't match ncol(X), before any optimizer branch runs. The existing kernel
# reference test (test-probit-regression-kernel-optimizers-fixed-coefficients-and-output-fields-glm-
# reference.R) only ever passes a correctly-sized warm start; this length guard had no test
# reference anywhere, for any optimizer.

f <- get("fast_probit_regression_cpp", envir = asNamespace("EDI"))

test_that("a warm_start_beta shorter or longer than ncol(X) errors with the documented message, for every optimizer", {
	set.seed(1); n <- 50L
	X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
	y <- rbinom(n, 1, pnorm(X %*% c(-0.2, 0.7, 0.4)))
	for (alg in c("irls", "newton", "bfgs", "lbfgs")) {
		expect_error(f(X, y, optimization_alg = alg, warm_start_beta = c(0, 0)),
			"warm_start_beta must have length equal to ncol\\(X\\)", info = alg)
		expect_error(f(X, y, optimization_alg = alg, warm_start_beta = c(0, 0, 0, 0)),
			"warm_start_beta must have length equal to ncol\\(X\\)", info = alg)
	}
	# a correctly-sized warm start still fits without error
	expect_no_error(f(X, y, warm_start_beta = c(0, 0, 0)))
})

test_that("the same length guard fires through the weighted and with-var entry points", {
	set.seed(2); n <- 40L
	X <- cbind(1, rnorm(n))
	y <- rbinom(n, 1, pnorm(X %*% c(0.1, 0.5)))
	wt <- runif(n, 0.5, 2)
	fw <- get("fast_probit_regression_weighted_cpp", envir = asNamespace("EDI"))
	fv <- get("fast_probit_regression_with_var_cpp", envir = asNamespace("EDI"))
	expect_error(fw(X, y, wt, warm_start_beta = c(0, 0, 0)), "warm_start_beta must have length equal to ncol\\(X\\)")
	expect_error(fv(X, y, warm_start_beta = c(0, 0, 0)), "warm_start_beta must have length equal to ncol\\(X\\)")
})
