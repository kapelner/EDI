library(testthat)
library(EDI)

# fast_neg_bin_weighted_cpp() (fast_negbin_regression.cpp) and fast_beta_regression_weighted_cpp()
# (fast_beta_regression.cpp) each guard their weights argument identically, before any fitting work:
# "weights_vec_coerced length must equal nrow(X)" for a wrong-length weights vector, and
# "weights_vec_coerced must be finite, nonnegative, and have positive sum" for a weights vector that's
# the right length but contains a negative entry, a non-finite entry, or sums to <= 0 (including
# all-zero weights). A codebase-wide grep confirmed neither exact message had any test reference
# anywhere, despite both functions being otherwise well-tested elsewhere (3-4 references each) -- every
# existing reference supplies a well-formed, correctly-sized, positive-sum weights vector.

test_that("fast_neg_bin_weighted_cpp() rejects a wrong-length, a negative-entry, and an all-zero weights vector", {
	X <- matrix(rnorm(20), 10, 2)
	y <- rpois(10, 2)

	expect_error(
		EDI:::fast_neg_bin_weighted_cpp(X, y, weights = rep(1, 5)),
		"weights_vec_coerced length must equal nrow(X)",
		fixed = TRUE
	)
	expect_error(
		EDI:::fast_neg_bin_weighted_cpp(X, y, weights = c(rep(1, 9), -1)),
		"weights_vec_coerced must be finite, nonnegative, and have positive sum",
		fixed = TRUE
	)
	expect_error(
		EDI:::fast_neg_bin_weighted_cpp(X, y, weights = rep(0, 10)),
		"weights_vec_coerced must be finite, nonnegative, and have positive sum",
		fixed = TRUE
	)
})

test_that("fast_beta_regression_weighted_cpp() rejects a wrong-length and a non-finite-entry weights vector", {
	X <- matrix(rnorm(20), 10, 2)
	y <- runif(10)

	expect_error(
		EDI:::fast_beta_regression_weighted_cpp(X, y, weights = rep(1, 5)),
		"weights_vec_coerced length must equal nrow(X)",
		fixed = TRUE
	)
	expect_error(
		EDI:::fast_beta_regression_weighted_cpp(X, y, weights = c(rep(1, 9), NA_real_)),
		"weights_vec_coerced must be finite, nonnegative, and have positive sum",
		fixed = TRUE
	)
})

test_that("well-formed, correctly-sized, positive-sum weights never trigger either guard", {
	X <- matrix(rnorm(20), 10, 2)
	y_count <- rpois(10, 2)
	expect_no_error(EDI:::fast_neg_bin_weighted_cpp(X, y_count, weights = rep(1, 10)))
})
