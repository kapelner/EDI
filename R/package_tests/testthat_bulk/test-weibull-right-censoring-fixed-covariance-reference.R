library(testthat)
library(EDI)

test_that("right-censored Weibull covariance conditions on fixed parameters", {
  X <- cbind(1, rep(0:1, each = 12))
  y <- rep(c(.35, .7, 1.2, 2.1, .55, 1.4, 2.8, .9, 1.8, .45, 3.2, 1.1), 2) *
    exp(.3 * X[, 2])
  dead <- rep(c(1, 0, 1, 1), 6)
  nll <- function(parameters) {
    scale <- exp(drop(X %*% parameters[1:2]))
    shape <- exp(-parameters[3])
    -sum(dweibull(y[dead == 1], shape, scale[dead == 1], log = TRUE)) -
      sum(pweibull(y[dead == 0], shape, scale[dead == 0], lower.tail = FALSE, log.p = TRUE))
  }
  for (constraint in list(list(index = integer(), value = numeric()),
                          list(index = 2L, value = .15),
                          list(index = 3L, value = log(.8)))) {
    free <- setdiff(1:3, constraint$index)
    expand <- function(values) {
      parameters <- numeric(3)
      parameters[free] <- values
      parameters[constraint$index] <- constraint$value
      parameters
    }
    reference <- optim(c(.5, .3, log(.8))[free], function(z) nll(expand(z)),
                       method = "BFGS", control = list(reltol = 1e-12, maxit = 2000L))
    expect_identical(reference$convergence, 0L)
    args <- list(X = X, y = y, dead = dead, maxit = 1000L, tol = 1e-10)
    if (length(constraint$index)) {
      args$fixed_idx <- constraint$index
      args$fixed_values <- constraint$value
    }
    actual <- do.call(EDI:::fast_weibull_regression_cpp, args)
    parameters <- as.numeric(actual$params)
    expect_true(actual$converged)
    expect_equal(parameters, expand(reference$par), tolerance = 1e-4)
    expect_lt(abs(actual$neg_loglik - reference$value), 1e-7)
    expect_equal(actual$neg_loglik, nll(parameters), tolerance = 1e-10)
    information <- optimHess(parameters, nll, control = list(ndeps = rep(1e-4, 3)))
    expect_equal(actual$observed_information, information, tolerance = 3e-5)
    # Full observed information remains available for score tests; the
    # covariance uses only parameters actually estimated in this fit.
    expect_equal(dim(actual$information), c(3L, 3L))
    expect_equal(actual$vcov[free, free], solve(information[free, free, drop = FALSE]),
                 tolerance = 3e-5)
    if (length(constraint$index)) {
      expect_equal(parameters[constraint$index], constraint$value, tolerance = 1e-12)
      expect_true(all(is.na(actual$vcov[constraint$index, ])))
      expect_true(all(is.na(actual$vcov[, constraint$index])))
    }
    estimate_args <- args
    estimate_args$estimate_only <- TRUE
    estimate_only <- do.call(EDI:::fast_weibull_regression_cpp, estimate_args)
    expect_equal(c(estimate_only$b, estimate_only$log_sigma), expand(reference$par), tolerance = 1e-4)
    expect_false("vcov" %in% names(estimate_only))
  }
})
