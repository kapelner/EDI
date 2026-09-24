library(testthat)
library(EDI)

# fast_weibull_regression_cpp (fast_weibull_regression.cpp, the exact/right-censored fast path)
# validates warm_start_params's length against ncol(X) + 1 (the p covariate coefficients plus the
# log-scale/shape parameter) before using it as the optimizer's starting point:
# `if (params.size() != p + 1) throw std::invalid_argument("warm_start_params must have length equal
# to ncol(X) + 1")`. A codebase-wide grep across testthat_bulk/, R/package_tests/testthat/ and
# R/EDI/tests/testthat/ confirms zero references to warm_start_params for this specific kernel
# anywhere (the many other weibull reference/golden test files never pass warm_start_params at all) --
# a sibling gap to the same wrong-length-warm-start pattern already closed for
# fast_probit_regression_cpp in the immediately preceding iteration.

f <- get("fast_weibull_regression_cpp", envir = asNamespace("EDI"))
set.seed(13); n <- 60L
X <- cbind(1, rnorm(n))
y <- rexp(n, 1)
dead <- rep(1, n)

test_that("a warm_start_params shorter than ncol(X) + 1 throws the length-mismatch error", {
	expect_error(
		f(X, y, dead, warm_start_params = c(0.1, 0.2)),
		"warm_start_params must have length equal to ncol\\(X\\) \\+ 1"
	)
})

test_that("a warm_start_params longer than ncol(X) + 1 throws the same length-mismatch error", {
	expect_error(
		f(X, y, dead, warm_start_params = c(0.1, 0.2, 0.3, 0.4)),
		"warm_start_params must have length equal to ncol\\(X\\) \\+ 1"
	)
})

test_that("the guard fires identically under every optimization_alg", {
	for (alg in c("lbfgs", "newton", "bfgs")) {
		expect_error(
			f(X, y, dead, warm_start_params = c(0.1, 0.2), optimization_alg = alg),
			"warm_start_params must have length equal to ncol\\(X\\) \\+ 1",
			info = alg
		)
	}
})

test_that("a correctly-sized warm_start_params (ncol(X) + 1) does not trigger the guard and fits normally", {
	r <- f(X, y, dead, warm_start_params = c(0, 0, 0))
	expect_true(r$converged)
	expect_length(r$params, 3L)
})
