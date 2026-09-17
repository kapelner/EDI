library(testthat)
library(EDI)

test_that("negative-binomial likelihood handles no covariates and empty samples", {
  y <- c(0L, 1L, 4L, 12L)
  X <- matrix(numeric(), nrow = length(y), ncol = 0L)
  for (theta in c(0.05, 1, 40)) {
    expect_equal(EDI:::neg_loglik_nb_cpp(theta, numeric(), X, y),
                 -sum(dnbinom(y, size = theta, mu = 1, log = TRUE)), tolerance = 1e-10)
  }
  expect_equal(EDI:::neg_loglik_nb_cpp(2, numeric(), matrix(numeric(), 0, 0), integer()), 0)
  expect_equal(EDI:::neg_loglik_nb_cpp(2, c(1, 2), matrix(numeric(), 0, 2), integer()), 0)
})

test_that("negative-binomial dispersion profiling agrees with the R density", {
  X <- cbind(1, c(-2, -1, 0, 1, 2, 3))
  beta <- c(log(3), 0.1)
  y <- c(0L, 0L, 2L, 3L, 9L, 15L)
  mu <- drop(exp(X %*% beta))
  cpp <- function(log_theta) EDI:::neg_loglik_nb_cpp(exp(log_theta), beta, X, y)
  reference <- function(log_theta) -sum(dnbinom(y, size = exp(log_theta), mu = mu, log = TRUE))
  actual <- optimize(cpp, c(-6, 6), tol = 1e-8)
  expected <- optimize(reference, c(-6, 6), tol = 1e-8)
  expect_equal(actual$minimum, expected$minimum, tolerance = 1e-6)
  expect_equal(actual$objective, expected$objective, tolerance = 1e-10)
  expect_lt(actual$minimum, 5.9)
  expect_gt(actual$minimum, -5.9)
  order <- c(6, 2, 5, 1, 4, 3)
  expect_equal(EDI:::neg_loglik_nb_cpp(exp(actual$minimum), beta, X[order, ], y[order]),
               actual$objective, tolerance = 1e-10)
})
