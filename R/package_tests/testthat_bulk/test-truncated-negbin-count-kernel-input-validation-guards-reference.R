library(testthat)
library(EDI)

# fast_truncated_negbin_count_cpp (fast_hurdle_negbin.cpp) -- the zero-truncated negative-binomial
# count-part fitter used by 4 call sites in inference_count_hurdle.R -- dispatches through
# validate_truncated_negbin_inputs(), which independently checks 6 distinct conditions before
# fitting:
#   1. `if (X.rows() != y.size()) throw ("X and y must have compatible dimensions")`.
#   2. `if (!X.allFinite()) throw ("X must contain only finite values")`.
#   3. `if (!y.allFinite()) throw ("y must contain only finite values")`.
#   4. `if (y[i] <= 0) throw ("y must contain only positive counts for truncated negative binomial
#      regression")` -- the model is zero-truncated, so a non-positive count is structurally invalid.
#   5. `if (y[i] is non-integer) throw ("y must contain only integer-valued counts for truncated
#      negative binomial regression")`.
#   6. `if (warm_start_params.size() != ncol(X) + 1) throw ("warm_start_params must have length
#      ncol(X) + 1")`.
# A codebase-wide grep across testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/
# confirms ZERO test references of any kind for this exported kernel, despite its real, heavy
# production usage as the count-part fitter inside the hurdle negative-binomial Inference classes.

f <- get("fast_truncated_negbin_count_cpp", envir = asNamespace("EDI"))

fx <- function(seed = 31L, n = 60L) {
	set.seed(seed)
	X <- cbind(1, rnorm(n))
	y <- rpois(n, 3) + 1   # positive (zero-truncated) counts
	list(X = X, y = y)
}

test_that("mismatched X/y row counts throws the dimension-mismatch error", {
	d <- fx()
	expect_error(f(d$X, d$y[1:10]), "X and y must have compatible dimensions")
})

test_that("a non-finite value in X throws the X-finite error", {
	d <- fx(seed = 32L)
	X_bad <- d$X
	X_bad[1, 1] <- NaN
	expect_error(f(X_bad, d$y), "X must contain only finite values")
})

test_that("a non-finite value in y throws the y-finite error", {
	d <- fx(seed = 33L)
	y_bad <- d$y
	y_bad[1] <- NaN
	expect_error(f(d$X, y_bad), "y must contain only finite values")
})

test_that("a non-positive count in y throws the positive-counts error (the model is zero-truncated)", {
	d <- fx(seed = 34L)
	y_bad <- d$y
	y_bad[1] <- 0
	expect_error(f(d$X, y_bad), "y must contain only positive counts for truncated negative binomial regression")
})

test_that("a non-integer count in y throws the integer-valued error", {
	d <- fx(seed = 35L)
	y_bad <- d$y
	y_bad[1] <- 2.5
	expect_error(f(d$X, y_bad), "y must contain only integer-valued counts for truncated negative binomial regression")
})

test_that("a warm_start_params of the wrong length throws the length error", {
	d <- fx(seed = 36L)
	expect_error(f(d$X, d$y, warm_start_params = c(0.1, 0.2)), "warm_start_params must have length ncol\\(X\\) \\+ 1")
})

test_that("well-formed inputs do not trigger any guard and the fit converges", {
	d <- fx(seed = 37L)
	r <- f(d$X, d$y)
	expect_true(r$converged)
})
