library(testthat)
library(EDI)

# fast_continuation_ratio_regression_weighted_cpp (fast_continuation_ratio_regression.cpp) is the
# only exported kernel that reaches build_continuation_ratio_augmented_data()'s subject-weight
# validation branch, which independently checks three distinct conditions before fitting:
#   1. `if (weights.size() != n) throw std::invalid_argument("weights length must equal nrow(X)")`.
#   2. `if (!isfinite(w_i) || w_i < 0) throw std::invalid_argument("weights must be finite and
#      nonnegative")` (checked per element).
#   3. `if (!(weight_sum > 0)) throw std::invalid_argument("weights must contain at least one
#      positive value")` (all-zero/all-nonpositive weights).
# A codebase-wide grep across testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/
# confirms the 2 existing reference files that call this kernel only ever pass well-formed, positive
# weight vectors -- none of these three guards had a test reference anywhere.

f <- get("fast_continuation_ratio_regression_weighted_cpp", envir = asNamespace("EDI"))
set.seed(101); n <- 60L
X <- cbind(1, rnorm(n))
y <- as.numeric(cut(X[, 2] + rnorm(n), c(-Inf, -0.5, 0.5, Inf)))
w <- runif(n, 0.3, 3)

test_that("weights of the wrong length throws the length-mismatch error", {
	expect_error(f(X, y, w[1:10]), "weights length must equal nrow\\(X\\)")
	expect_error(f(X, y, c(w, 1)), "weights length must equal nrow\\(X\\)")
})

test_that("a negative weight throws the finite-and-nonnegative error", {
	w_neg <- w
	w_neg[1] <- -1
	expect_error(f(X, y, w_neg), "weights must be finite and nonnegative")
})

test_that("a non-finite weight (NaN or Inf) throws the same finite-and-nonnegative error", {
	w_nan <- w
	w_nan[1] <- NaN
	expect_error(f(X, y, w_nan), "weights must be finite and nonnegative")
	w_inf <- w
	w_inf[1] <- Inf
	expect_error(f(X, y, w_inf), "weights must be finite and nonnegative")
})

test_that("all-zero weights throw the no-positive-weight error", {
	expect_error(f(X, y, rep(0, n)), "weights must contain at least one positive value")
})

test_that("well-formed positive weights do not trigger any guard and the fit converges", {
	r <- f(X, y, w)
	expect_true(r$converged)
})
