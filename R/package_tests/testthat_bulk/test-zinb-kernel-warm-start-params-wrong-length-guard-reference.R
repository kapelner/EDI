library(testthat)
library(EDI)

# fast_zinb_cpp (fast_zinb.cpp, the zero-inflated negative binomial kernel) validates
# warm_start_params's length against n_par = ncol(X) count-model coefficients + ncol(Xzi)
# zero-inflation-model coefficients + 1 (log-theta) before using it as the optimizer's starting
# point: `if (par.size() != n_par) throw std::invalid_argument("warm_start_params must have length
# equal to the number of model parameters")`. A codebase-wide grep across testthat_bulk/,
# R/package_tests/testthat/ and R/EDI/tests/testthat/ confirms warm_start_params IS already used by
# test-zinb-operator-workspace.R and test-zinb-std-lgamma.R, but only ever with a correctly-sized
# vector (either a hand-built start or a previous fit's own params) -- the length-mismatch guard
# itself had no test reference anywhere. A sibling gap to the same wrong-length-warm-start pattern
# already closed this stretch for fast_probit_regression_cpp, fast_weibull_regression_cpp,
# fast_log_binomial_regression_cpp/fast_identity_binomial_regression_cpp, fast_ordinal_regression_cpp,
# fast_neg_bin_cpp, and fast_ordinal_probit/cauchit/cloglog_regression_cpp.

f <- get("fast_zinb_cpp", envir = asNamespace("EDI"))
set.seed(37); n <- 150L
X <- cbind(1, rnorm(n))
Xzi <- cbind(1, rnorm(n))
mu <- exp(0.5 + 0.3 * X[, 2])
y <- ifelse(rbinom(n, 1, plogis(0.2 * Xzi[, 2])) == 1, 0, rnbinom(n, size = 3, mu = mu))
# n_par = ncol(X) + ncol(Xzi) + 1 = 2 + 2 + 1 = 5

test_that("a warm_start_params shorter than n_par throws the length-mismatch error", {
	expect_error(
		f(X, Xzi, y, warm_start_params = c(0.1, 0.2)),
		"warm_start_params must have length equal to the number of model parameters"
	)
})

test_that("a warm_start_params longer than n_par throws the same length-mismatch error", {
	expect_error(
		f(X, Xzi, y, warm_start_params = c(0.1, 0.2, 0.3, 0.4, 0.5, 0.6)),
		"warm_start_params must have length equal to the number of model parameters"
	)
})

test_that("the guard fires identically under every optimization_alg", {
	for (alg in c("lbfgs", "newton", "bfgs")) {
		expect_error(
			f(X, Xzi, y, warm_start_params = c(0.1, 0.2), optimization_alg = alg),
			"warm_start_params must have length equal to the number of model parameters",
			info = alg
		)
	}
})

test_that("a correctly-sized warm_start_params (ncol(X) + ncol(Xzi) + 1) does not trigger the guard and fits normally", {
	r <- f(X, Xzi, y, warm_start_params = c(0.5, 0.3, -1, 0, log(3)))
	expect_true(r$converged)
	expect_length(r$params, 5L)
})
