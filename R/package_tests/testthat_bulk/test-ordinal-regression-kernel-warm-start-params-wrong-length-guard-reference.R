library(testthat)
library(EDI)

# fast_ordinal_regression_cpp (fast_ordinal_regression.cpp, the proportional-odds ordinal logistic
# kernel) validates warm_start_params's length against n_params = (K - 1) thresholds + p covariates
# before using it as the optimizer's starting point: `if (params.size() != n_params) throw
# std::invalid_argument("warm_start_params must have length equal to the number of model
# parameters")`. A codebase-wide grep across testthat_bulk/, R/package_tests/testthat/ and
# R/EDI/tests/testthat/ confirms zero references to warm_start_params for this specific kernel
# anywhere -- the 6 existing files that call fast_ordinal_regression_cpp never pass
# warm_start_params, and the 2 files matching "warm_start_params" target the unrelated
# fast_ordinal_clmm_cpp/fast_ordinal_glmm_cpp kernels. A sibling gap to the same
# wrong-length-warm-start pattern already closed this stretch for fast_probit_regression_cpp,
# fast_weibull_regression_cpp, and fast_log_binomial_regression_cpp/fast_identity_binomial_
# regression_cpp.

f <- get("fast_ordinal_regression_cpp", envir = asNamespace("EDI"))
set.seed(23); n <- 80L
X <- cbind(rnorm(n))
y <- as.numeric(cut(X[, 1] + rnorm(n), c(-Inf, -0.5, 0.5, Inf)))   # 3 categories: K - 1 = 2 thresholds + p = 1 covariate = 3 params

test_that("a warm_start_params shorter than n_params throws the length-mismatch error", {
	expect_error(
		f(X, y, warm_start_params = c(0.1, 0.2)),
		"warm_start_params must have length equal to the number of model parameters"
	)
})

test_that("a warm_start_params longer than n_params throws the same length-mismatch error", {
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

test_that("a correctly-sized warm_start_params (n_alpha + p) does not trigger the guard and fits normally", {
	r <- f(X, y, warm_start_params = c(-0.5, 0.5, 0))
	expect_true(r$converged)
	expect_equal(r$n_params, 3L)
	expect_length(r$params, 3L)
})
