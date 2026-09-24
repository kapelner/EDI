library(testthat)
library(EDI)

# fast_probit_regression_cpp (fast_probit_regression.cpp) validates warm_start_beta's length against
# ncol(X) before using it as the optimizer's starting point: `if (beta_start.size() != p) throw
# std::invalid_argument("warm_start_beta must have length equal to ncol(X)")`. The existing kernel
# reference test (test-probit-regression-kernel-optimizers-fixed-coefficients-and-output-fields-glm-
# reference.R) only ever passes a correctly-sized warm_start_beta (or none); this length-mismatch
# guard had no test reference anywhere for this function (confirmed via grep). Reached directly via
# the exported Rcpp kernel, independent of any Inference class.

f <- get("fast_probit_regression_cpp", envir = asNamespace("EDI"))
set.seed(11); n <- 50L
X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
y <- rbinom(n, 1, pnorm(X %*% c(-0.2, 0.7, 0.4)))

test_that("a warm_start_beta shorter than ncol(X) throws the length-mismatch error", {
	expect_error(f(X, y, warm_start_beta = c(0.1, 0.2)), "warm_start_beta must have length equal to ncol\\(X\\)")
})

test_that("a warm_start_beta longer than ncol(X) throws the same length-mismatch error", {
	expect_error(f(X, y, warm_start_beta = c(0.1, 0.2, 0.3, 0.4)), "warm_start_beta must have length equal to ncol\\(X\\)")
})

test_that("the guard fires identically under every optimization_alg (irls, newton, bfgs, lbfgs)", {
	for (alg in c("irls", "newton", "bfgs", "lbfgs")) {
		expect_error(
			f(X, y, warm_start_beta = c(1, 2), optimization_alg = alg),
			"warm_start_beta must have length equal to ncol\\(X\\)",
			info = alg
		)
	}
})

test_that("a correctly-sized warm_start_beta does not trigger the guard and fits normally", {
	r <- f(X, y, warm_start_beta = c(0, 0, 0))
	expect_true(r$converged)
	expect_length(r$b, 3L)
})
