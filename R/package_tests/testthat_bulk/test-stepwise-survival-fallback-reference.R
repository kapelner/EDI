library(testthat)
library(EDI)

# TODO-3: fewer than two events forces the documented OLS-on-log-time fallback.
test_that("survival stepwise fallback agrees with sequential partial OLS t statistics", {
  set.seed(892)
  n <- 30L
  w <- rep(c(0, 1), n / 2)
  X <- cbind(rnorm(n), rnorm(n), rnorm(n))
  log_y <- 1 + 0.4 * w + X %*% c(0.7, -0.3, 0.2) + rnorm(n, sd = 0.5)
  y <- as.numeric(exp(log_y))
  expected <- rep(NA_real_, ncol(X))
  selected <- integer()
  for (step in seq_len(ncol(X))) {
    remaining <- setdiff(seq_len(ncol(X)), selected)
    statistics <- vapply(remaining, function(j) {
      model <- lm(as.numeric(log_y) ~ w + X[, c(selected, j), drop = FALSE])
      abs(tail(coef(summary(model))[, "t value"], 1))
    }, numeric(1))
    j <- remaining[which.max(statistics)]
    expected[j] <- max(statistics)
    selected <- c(selected, j)
  }
  for (delta in list(rep(0, n), c(1, rep(0, n - 1)))) {
    got <- EDI:::kk21_stepwise_survival_weights_cpp(X, y, delta, w)
    expect_equal(got, expected, tolerance = 1e-9)
  }
  expect_identical(EDI:::kk21_stepwise_survival_weights_cpp(
    matrix(numeric(), n, 0), y, rep(0, n), w), numeric())
})

test_that("survival fallback leaves collinear candidates unselected", {
  set.seed(893)
  w <- rep(c(0, 1), 10)
  x <- rnorm(20)
  log_y <- 0.4 * w + 0.5 * x + rnorm(20)
  X <- cbind(x, constant = 1, treatment = w)
  got <- EDI:::kk21_stepwise_survival_weights_cpp(X, exp(log_y), rep(0, 20), w)
  expected <- abs(coef(summary(lm(log_y ~ w + x)))["x", "t value"])
  expect_equal(got[1], unname(expected), tolerance = 1e-9)
  expect_true(all(is.na(got[2:3])))
  # No residual degrees of freedom is another legitimate early-exit path.
  expect_true(is.na(EDI:::kk21_stepwise_survival_weights_cpp(
    matrix(c(1, 2), 2, 1), c(1, 2), c(0, 0), c(0, 1))))
})
