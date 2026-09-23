library(testthat)
library(EDI)

# kk21_continuous_weights_cpp (kk21_weights.cpp) has a distinct degenerate branch from the already-
# tested "constant column" (varx <= eps) case: when the univariate OLS fit of y on column j is
# EXACTLY perfect (sse <= 0.0, i.e. every residual is exactly zero in floating point), sigma2/se_b1
# are never computed and the column gets the minimal eps weight instead of a (nonsensical,
# division-by-zero) infinite t-statistic. The existing reference test
# (test-kk21-univariate-weight-kernels-continuous-logistic-ordinal-references-and-ordinal-ssq-key-
# bug.R) only exercises the constant-column and tiny-n degenerate branches; this "perfectly fitting
# column" branch had no test reference anywhere. A column that is an exact integer-arithmetic affine
# function of an integer y reliably drives the accumulated sum-of-squares to exact floating-point
# zero (verified directly below); a column with real-valued noise-free correlation does NOT reliably
# hit this branch, since floating-point rounding in the running sums usually leaves a tiny positive
# residual instead of an exact zero.

K <- function(x) get(x, envir = asNamespace("EDI"))
eps <- .Machine$double.eps

test_that("an inexact (non-integer) perfect linear relationship does not reliably zero out sse, and gets a large finite weight instead", {
	set.seed(1); n <- 20L
	x1 <- rnorm(n)
	y <- 3 + 2 * x1
	w <- K("kk21_continuous_weights_cpp")(cbind(x1), y)
	expect_true(is.finite(w))
	expect_gt(w, 1e6)  # a near-perfect (but not exactly-zero-residual) fit gives a huge, not eps, weight
})

test_that("an exact integer-arithmetic perfect fit drives sse to exactly zero and returns the eps weight", {
	n <- 20L
	x2 <- 1:n
	y2 <- 3 + 2 * x2
	w2 <- K("kk21_continuous_weights_cpp")(cbind(x2), y2)
	expect_equal(w2, eps)

	# a second, unrelated column in the same call is unaffected
	set.seed(2); x3 <- rnorm(n)
	W <- K("kk21_continuous_weights_cpp")(cbind(x2, x3), y2)
	expect_equal(W[1], eps)
	expect_true(is.finite(W[2]) && W[2] != eps)
})
