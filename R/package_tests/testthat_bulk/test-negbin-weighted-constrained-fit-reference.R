library(testthat)
library(EDI)

test_that("weighted negative-binomial constrained fits recover independent density optima", {
  X <- cbind(1, rep(0:1, each = 12))
  y <- c(0L, 1L, 0L, 8L, 2L, 12L, 1L, 6L, 0L, 4L, 15L, 3L,
         1L, 0L, 13L, 3L, 18L, 2L, 7L, 0L, 9L, 21L, 4L, 1L)
  weights <- c(0, 1, 2, .5, 3, 1, 1.5, 2, 1, 3, .5, 1,
               2, 1, 0, 3, .5, 2, 1, 1.5, 2, 1, .5, 3)
  nll <- function(parameters) {
    mu <- exp(drop(X %*% parameters[1:2]))
    -sum(weights * dnbinom(y, size = exp(parameters[3]), mu = mu, log = TRUE))
  }
  for (constraint in list(list(index = integer(), value = numeric()),
                          list(index = 2L, value = .2),
                          list(index = 3L, value = log(1.5)))) {
    free <- setdiff(1:3, constraint$index)
    expand <- function(values) {
      parameters <- numeric(3)
      parameters[free] <- values
      parameters[constraint$index] <- constraint$value
      parameters
    }
    reference <- optim(c(log(4), .3, log(1))[free], function(z) nll(expand(z)),
                       method = "BFGS", control = list(reltol = 1e-12, maxit = 2000L))
    expect_identical(reference$convergence, 0L)
    expected <- expand(reference$par)
    args <- list(X = X, y = y, weights = weights, maxit = 1000L, eps_g = 1e-10)
    if (length(constraint$index)) {
      args$fixed_idx <- constraint$index
      args$fixed_values <- constraint$value
    }
    for (smart in c(FALSE, TRUE)) {
      args$smart_cold_start <- smart
      actual <- do.call(EDI:::fast_neg_bin_weighted_cpp, args)
      parameters <- c(actual$b, log(actual$theta_hat))
      expect_true(actual$converged)
      expect_false(actual$dispersion_at_poisson_boundary)
      expect_equal(parameters, expected, tolerance = 1e-4)
      expect_lt(abs(-actual$logLik - reference$value), 1e-7)
      expect_equal(actual$logLik, -nll(parameters), tolerance = 1e-10)
      information <- optimHess(parameters, nll, control = list(ndeps = rep(1e-4, 3)))
      expect_equal(actual$fisher_information, information, tolerance = 3e-5)
      if (length(constraint$index)) {
        expect_equal(parameters[constraint$index], constraint$value, tolerance = 1e-12)
      }
    }
    warm_args <- args
    warm_args$warm_start_params <- expected
    warm_args$warm_start_fisher_info <- optimHess(expected, nll, control = list(ndeps = rep(1e-4, 3)))
    warm <- do.call(EDI:::fast_neg_bin_weighted_cpp, warm_args)
    expect_equal(c(warm$b, log(warm$theta_hat)), expected, tolerance = 1e-4)
    expect_equal(warm$logLik, -reference$value, tolerance = 1e-8)
    scaled_args <- warm_args
    scaled_args$weights <- 7 * weights
    scaled_args$warm_start_fisher_info <- 7 * warm_args$warm_start_fisher_info
    scaled <- do.call(EDI:::fast_neg_bin_weighted_cpp, scaled_args)
    scaled_parameters <- c(scaled$b, log(scaled$theta_hat))
    expect_equal(scaled_parameters, expected, tolerance = 1e-4)
    expect_equal(scaled$logLik, -7 * nll(scaled_parameters), tolerance = 1e-10)
    expect_equal(scaled$fisher_information,
                 7 * optimHess(scaled_parameters, nll, control = list(ndeps = rep(1e-4, 3))),
                 tolerance = 3e-5)
    keep <- weights > 0
    omitted_args <- warm_args
    omitted_args$X <- X[keep, ]
    omitted_args$y <- y[keep]
    omitted_args$weights <- weights[keep]
    omitted <- do.call(EDI:::fast_neg_bin_weighted_cpp, omitted_args)
    expect_equal(c(omitted$b, log(omitted$theta_hat)), expected, tolerance = 1e-4)
    expect_equal(omitted$logLik, warm$logLik, tolerance = 1e-10)
    expect_equal(omitted$fisher_information, warm$fisher_information, tolerance = 1e-8)
    warm_args$estimate_only <- TRUE
    estimate_only <- do.call(EDI:::fast_neg_bin_weighted_cpp, warm_args)
    expect_equal(c(estimate_only$b, log(estimate_only$theta_hat)), expected, tolerance = 1e-4)
    expect_equal(estimate_only$logLik, -nll(c(estimate_only$b, log(estimate_only$theta_hat))),
                 tolerance = 1e-10)
    expect_identical(estimate_only$fisher_information, matrix(0, 3L, 3L))
  }
})
