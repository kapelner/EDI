library(testthat)
library(EDI)

# zero_augmented_fit_is_degenerate(vcov, params): TRUE when the model-based covariance is empty / non-finite, has a
# non-positive diagonal, is ill-conditioned (rcond < 1e-10), or the first (conditional-intercept) parameter is
# at the lambda ~ 0 boundary (< -15). Reference: each rule stated independently with hand-built matrices.

D <- get("zero_augmented_fit_is_degenerate", asNamespace("EDI"))
good <- matrix(c(0.5, 0.1, 0.1, 0.3), 2)
ok_params <- c(0.4, -0.2)

test_that("a well-conditioned positive-definite covariance with an interior intercept is not degenerate", {
	expect_false(D(good, ok_params))
	expect_false(D(diag(3), c(0, 1, 2)))
	expect_false(D(matrix(0.04), 1.5))                      # 1x1
	expect_false(D(good, NULL))                            # no params -> only the covariance rules apply
})

test_that("empty and non-finite covariances are degenerate", {
	expect_true(D(matrix(numeric(0), 0, 0), ok_params))
	expect_true(D(matrix(NA_real_, 2, 2), ok_params))
	expect_true(D(replace(good, 2, Inf), ok_params))
	expect_true(D(replace(good, 4, NaN), ok_params))
})

test_that("non-positive or numerically zero variances are degenerate", {
	expect_true(D(diag(c(1, 0)), ok_params))
	expect_true(D(diag(c(1, -0.5)), ok_params))
	expect_true(D(matrix(.Machine$double.eps), ok_params))             # exactly at the eps threshold (<=)
	expect_false(D(matrix(10 * .Machine$double.eps), ok_params))       # 1x1 has rcond 1, so only the diagonal rule applies
})

test_that("ill-conditioned covariances (rcond < 1e-10) are degenerate; just above the threshold is not", {
	bad <- diag(c(1, 1e-11)); expect_lt(rcond(bad), 1e-10)
	expect_true(D(bad, ok_params))
	fine <- diag(c(1, 1e-9)); expect_gt(rcond(fine), 1e-10)
	expect_false(D(fine, ok_params))
	near_sing <- matrix(c(1, 1 - 1e-12, 1 - 1e-12, 1), 2)
	expect_true(D(near_sing, ok_params))
})

test_that("intercept boundary: only params[1] < -15 flags degeneracy; NA, later params and the boundary itself do not", {
	expect_true(D(good, c(-15.0001, 1)))
	expect_false(D(good, c(-15, 1)))
	expect_false(D(good, c(NA_real_, 1)))
	expect_false(D(good, c(1, -100)))
	expect_false(D(good, numeric(0)))
})

test_that("a data.frame or base-matrix input is coerced; the answer matches the matrix form", {
	expect_identical(D(as.data.frame(good), ok_params), D(good, ok_params))
	expect_identical(D(as.data.frame(diag(c(1, 0))), ok_params), TRUE)
})

test_that("a healthy genuine pscl hurdle fit is not flagged degenerate", {
	skip_if_not_installed("pscl")
	set.seed(1); n <- 80L; x <- rnorm(n)
	y_ok <- rpois(n, exp(0.5 + 0.3 * x)); y_ok[sample(n, 20)] <- 0L
	f <- pscl::hurdle(y_ok ~ x | x, dist = "poisson")
	expect_false(D(vcov(f), coef(f)))
})
