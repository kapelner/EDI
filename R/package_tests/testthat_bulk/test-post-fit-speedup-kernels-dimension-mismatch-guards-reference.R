library(testthat)
library(EDI)

# Four sibling "post-fit" C++ speedup kernels each guard on their (y, coef_hat, [alpha_hat/bread/hat])
# arguments matching the fitted design matrix's row/column counts before doing any real work:
# gcomp_logistic_post_fit_cpp() (gcomp_speedups.cpp), gcomp_logistic_cluster_post_fit_cpp() (same
# file), ordinal_gcomp_post_fit_cpp() (fast_ordinal_regression.cpp), and
# ols_hc2_post_fit_precomputed_cpp() (robust_post_fit_speedups.cpp). A codebase-wide grep confirmed
# none of the four exact "dimension mismatch in <fn>" messages had any test reference anywhere,
# despite all 4 functions being otherwise well-tested (1-2 references each) -- every existing
# reference supplies correctly-sized arguments matching the design matrix, so this guard was never
# exercised on any of them. Reached by calling each exported kernel directly with a deliberately
# wrong-length y vector against a real design matrix, independent of the real model-fitting machinery
# each is normally invoked from.

test_that("gcomp_logistic_post_fit_cpp() rejects a y vector whose length doesn't match nrow(X_fit)", {
	X <- cbind(1, rnorm(10))
	y_bad <- rbinom(5, 1, 0.5)
	expect_error(
		EDI:::gcomp_logistic_post_fit_cpp(X, y_bad, c(0, 0), rep(0.5, 10), j_treat = 2L),
		"dimension mismatch in gcomp_logistic_post_fit_cpp",
		fixed = TRUE
	)
})

test_that("gcomp_logistic_cluster_post_fit_cpp() rejects a y vector whose length doesn't match nrow(X_fit)", {
	X <- cbind(1, rnorm(10))
	y_bad <- rbinom(5, 1, 0.5)
	expect_error(
		EDI:::gcomp_logistic_cluster_post_fit_cpp(X, y_bad, c(0, 0), rep(0.5, 10), cluster_id = rep(1L, 10), j_treat = 2L),
		"dimension mismatch in gcomp_logistic_cluster_post_fit_cpp",
		fixed = TRUE
	)
})

test_that("ordinal_gcomp_post_fit_cpp() rejects a y vector whose length doesn't match nrow(X_fit)", {
	X <- cbind(1, rnorm(10))
	y_bad <- rbinom(5, 1, 0.5)
	expect_error(
		EDI:::ordinal_gcomp_post_fit_cpp(X, y_bad, c(0, 0), c(0, 1), j_treat = 2L),
		"dimension mismatch in ordinal_gcomp_post_fit_cpp",
		fixed = TRUE
	)
})

test_that("ols_hc2_post_fit_precomputed_cpp() rejects a y vector whose length doesn't match nrow(X_fit)", {
	X <- cbind(1, rnorm(10))
	y_bad <- rbinom(5, 1, 0.5)
	expect_error(
		EDI:::ols_hc2_post_fit_precomputed_cpp(X, y_bad, c(0, 0), diag(2), rep(0.1, 10), j_treat = 2L),
		"dimension mismatch in ols_hc2_post_fit_precomputed_cpp",
		fixed = TRUE
	)
})
