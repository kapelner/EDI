library(testthat)
library(EDI)

# fast_ordinal_probit_regression_cpp, fast_ordinal_cauchit_regression_cpp and
# fast_ordinal_cloglog_regression_cpp (fast_ordinal_probit_regression.cpp,
# fast_ordinal_cauchit_regression.cpp, fast_ordinal_cloglog_regression.cpp) each independently
# validate warm_start_params's length against n_params = (K - 1) thresholds + p covariates, with the
# identical guard/message pattern already closed this stretch for fast_ordinal_regression_cpp
# (proportional-odds logit): `if (params.size() != n_params) throw std::invalid_argument(
# "warm_start_params must have length equal to the number of model parameters")`. A codebase-wide
# grep across testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/ confirms zero
# references to warm_start_params for any of these three kernels -- their existing reference test
# files (score/hessian/fit, with-var, and randomization-estimate-refit files) never pass
# warm_start_params.

set.seed(31); n <- 80L
X <- cbind(rnorm(n))
y <- as.numeric(cut(X[, 1] + rnorm(n), c(-Inf, -0.5, 0.5, Inf)))   # 3 categories: K - 1 = 2 thresholds + p = 1 covariate = 3 params

for (fn in c("fast_ordinal_probit_regression_cpp", "fast_ordinal_cauchit_regression_cpp", "fast_ordinal_cloglog_regression_cpp")) {
	local({
		fn <- fn
		f <- get(fn, envir = asNamespace("EDI"))

		test_that(paste0(fn, ": a warm_start_params shorter than n_params throws the length-mismatch error"), {
			expect_error(
				f(X, y, warm_start_params = c(0.1, 0.2)),
				"warm_start_params must have length equal to the number of model parameters"
			)
		})

		test_that(paste0(fn, ": a warm_start_params longer than n_params throws the same length-mismatch error"), {
			expect_error(
				f(X, y, warm_start_params = c(0.1, 0.2, 0.3, 0.4)),
				"warm_start_params must have length equal to the number of model parameters"
			)
		})

		test_that(paste0(fn, ": a correctly-sized warm_start_params (n_alpha + p) does not trigger the guard and fits normally"), {
			r <- f(X, y, warm_start_params = c(-0.5, 0.5, 0))
			expect_true(r$converged)
			expect_length(r$params, 3L)
		})
	})
}
