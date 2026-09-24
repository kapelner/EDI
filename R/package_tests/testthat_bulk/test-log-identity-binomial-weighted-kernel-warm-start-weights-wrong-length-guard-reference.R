library(testthat)
library(EDI)

# fast_log_binomial_regression_weighted_cpp and fast_identity_binomial_regression_weighted_cpp
# (fast_log_binomial_regression.cpp) both dispatch to the shared
# fit_constrained_binomial_weighted_cpp_impl(), which -- separately from the observation-weight
# length check ("weights length mismatch...") and the warm_start_beta length check -- validates
# warm_start_weights's length against nrow(X) before seeding the first IRLS iteration's working
# weights: `if (warm_weights_vec.size() != n) throw std::invalid_argument("warm_start_weights must
# have length equal to nrow(X)")`. A codebase-wide grep across testthat_bulk/,
# R/package_tests/testthat/ and R/EDI/tests/testthat/ confirms zero references to warm_start_weights
# for either kernel -- the 4 existing reference files that call these weighted variants only ever
# pass the required observation weights, never warm_start_weights. Last unchecked sibling of the
# wrong-length-warm-start pattern closed this stretch (after fast_probit_regression_cpp,
# fast_weibull_regression_cpp, fast_log_binomial_regression_cpp/fast_identity_binomial_regression_cpp
# (warm_start_beta), fast_ordinal_regression_cpp (warm_start_params and weights),
# fast_neg_bin_cpp, fast_ordinal_probit/cauchit/cloglog_regression_cpp, fast_zinb_cpp, and
# fast_robust_regression_cpp).

f_log <- get("fast_log_binomial_regression_weighted_cpp", envir = asNamespace("EDI"))
f_identity <- get("fast_identity_binomial_regression_weighted_cpp", envir = asNamespace("EDI"))
set.seed(47); n <- 60L
X <- cbind(1, rnorm(n))
y <- rbinom(n, 1, 0.3)
w <- runif(n, 0.3, 3)

test_that("fast_log_binomial_regression_weighted_cpp: warm_start_weights of the wrong length throws the length-mismatch error", {
	expect_error(f_log(X, y, w, warm_start_weights = rep(1, 10)), "warm_start_weights must have length equal to nrow\\(X\\)")
	expect_error(f_log(X, y, w, warm_start_weights = rep(1, n + 5)), "warm_start_weights must have length equal to nrow\\(X\\)")
})

test_that("fast_identity_binomial_regression_weighted_cpp: warm_start_weights of the wrong length throws the same error", {
	expect_error(f_identity(X, y, w, warm_start_weights = rep(1, 10)), "warm_start_weights must have length equal to nrow\\(X\\)")
	expect_error(f_identity(X, y, w, warm_start_weights = rep(1, n + 5)), "warm_start_weights must have length equal to nrow\\(X\\)")
})

test_that("correctly-sized warm_start_weights do not trigger the guard and both kernels fit normally", {
	r_log <- f_log(X, y, w, warm_start_weights = rep(1, n))
	expect_true(r_log$converged)
	expect_length(r_log$b, 2L)

	r_identity <- f_identity(X, y, w, warm_start_weights = rep(1, n))
	expect_length(r_identity$b, 2L)
	expect_true(all(is.finite(r_identity$b)))
})
