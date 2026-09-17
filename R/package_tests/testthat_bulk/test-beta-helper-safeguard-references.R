library(testthat)
library(EDI)

# TODO-3: boundary means occur during optimization even with interior responses.
test_that("beta helpers apply finite shape safeguards to boundary means", {
  y <- c(0.25, 0.75, 0.4)
  mu <- c(0, 1, 0.5)
  phi <- 7
  wt <- c(1, 0.5, 0)
  shape1 <- c(1e-12, phi, phi / 2)
  shape2 <- c(phi, 1e-12, phi / 2)
  # The likelihood's normalization uses lgamma(phi) at safeguarded means.
  ll <- lgamma(phi) - lgamma(shape1) - lgamma(shape2) +
    (shape1 - 1) * log(y) + (shape2 - 1) * log1p(-y)
  expect_equal(EDI:::beta_loglik_cpp(y, mu, phi, wt), sum(wt * ll), tolerance = 1e-10)
  expect_equal(EDI:::beta_dev_resids_cpp(y, mu, phi, wt),
               -2 * wt * dbeta(y, shape1, shape2, log = TRUE), tolerance = 1e-10)
  expect_equal(EDI:::beta_aic_cpp(y, mu, phi, wt),
               -2 * sum(wt * ll) + 2 * (length(mu) + 1), tolerance = 1e-10)
})

test_that("beta AIC skips endpoint responses while retaining interior contributions", {
  y <- c(0, 0.2, 1, 0.6)
  mu <- c(0.3, 0.4, 0.7, 0.5)
  wt <- c(9, 2, 8, 0.5)
  phi <- 5
  interior <- c(2L, 4L)
  expected_ll <- sum(wt[interior] * dbeta(y[interior], mu[interior] * phi,
                                         (1 - mu[interior]) * phi, log = TRUE))
  expect_equal(EDI:::beta_aic_cpp(y, mu, phi, wt),
               -2 * expected_ll + 2 * (length(mu) + 1), tolerance = 1e-10)
  dev <- EDI:::beta_dev_resids_cpp(y, mu, phi, wt)
  expect_true(all(is.nan(dev[c(1, 3)])))
  expect_equal(dev[interior], -2 * wt[interior] * dbeta(y[interior], mu[interior] * phi,
                                                     (1 - mu[interior]) * phi, log = TRUE))
  expect_equal(EDI:::beta_loglik_cpp(numeric(), numeric(), phi, numeric()), 0)
  expect_identical(EDI:::beta_dev_resids_cpp(numeric(), numeric(), phi, numeric()), numeric())
  expect_equal(EDI:::beta_aic_cpp(numeric(), numeric(), phi, numeric()), 2)
})
