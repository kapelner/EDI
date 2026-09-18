library(testthat)
library(EDI)

test_that("weighted beta fits and constrained fits maximize independent beta densities", {
  X <- cbind(1, rep(0:1, each = 12))
  y <- c(.12, .25, .41, .31, .56, .22, .48, .63, .36, .18, .52, .44,
         .29, .61, .45, .73, .38, .56, .66, .49, .81, .34, .58, .69)
  weights <- c(0, 1, 2, .5, 3, 1, 1.5, 2, 1, 3, .5, 1,
               2, 1, 0, 3, .5, 2, 1, 1.5, 2, 1, .5, 3)
  nll <- function(parameters, rows = seq_along(y), row_weights = weights[rows]) {
    mu <- plogis(drop(X[rows, , drop = FALSE] %*% parameters[1:2]))
    phi <- exp(parameters[3])
    -sum(row_weights * dbeta(y[rows], mu * phi, (1 - mu) * phi, log = TRUE))
  }
  # The final parameter is log precision, so constraints may apply to a
  # regression coefficient or to precision without changing the density.
  cases <- list(list(index = integer(), value = numeric()),
                list(index = 2L, value = .25),
                list(index = 3L, value = log(6)))
  for (constraint in cases) {
    free <- setdiff(1:3, constraint$index)
    expand <- function(free_values) {
      parameters <- numeric(3)
      parameters[free] <- free_values
      parameters[constraint$index] <- constraint$value
      parameters
    }
    reference <- optim(c(-.3, .7, log(8))[free], function(z) nll(expand(z)),
                       method = "BFGS", control = list(reltol = 1e-12, maxit = 2000L))
    expect_identical(reference$convergence, 0L)
    expected <- expand(reference$par)
    args <- list(X = X, y = y, weights = weights)
    if (length(constraint$index)) {
      args$fixed_idx <- constraint$index
      args$fixed_values <- constraint$value
    }
    actual <- do.call(EDI:::fast_beta_regression_weighted_cpp, args)
    parameters <- c(actual$coefficients, log(actual$phi))
    expect_true(actual$converged)
    # Native fits stop on relative likelihood improvement. Compare both
    # coefficients and likelihood loss rather than requiring exact iterates.
    expect_equal(as.numeric(parameters), expected, tolerance = 5e-4)
    expect_lt(abs(nll(parameters) - reference$value), 1e-5)
    expect_equal(actual$neg_loglik, nll(parameters), tolerance = 1e-10)
    if (length(constraint$index)) {
      expect_equal(as.numeric(parameters[constraint$index]), constraint$value, tolerance = 1e-12)
    }
    # optimHess differentiates the independent dbeta objective, including
    # beta/precision cross terms and observation weights.
    information <- optimHess(parameters, nll, control = list(ndeps = rep(1e-4, 3)))
    expect_equal(actual$fisher_information, information, tolerance = 2e-5)
    expect_true(all(eigen(actual$fisher_information, symmetric = TRUE)$values > 0))

    keep <- which(weights > 0)
    omitted_args <- args
    omitted_args$X <- X[keep, ]
    omitted_args$y <- y[keep]
    omitted_args$weights <- weights[keep]
    omitted <- do.call(EDI:::fast_beta_regression_weighted_cpp, omitted_args)
    expect_equal(c(omitted$coefficients, log(omitted$phi)), expected, tolerance = 5e-4)
    expect_lt(abs(omitted$neg_loglik - reference$value), 1e-5)

    scaled_args <- args
    scaled_args$weights <- 7 * weights
    scaled_args$warm_start_beta <- expected[1:2]
    scaled_args$start_phi <- exp(expected[3])
    scaled <- do.call(EDI:::fast_beta_regression_weighted_cpp, scaled_args)
    scaled_parameters <- c(scaled$coefficients, log(scaled$phi))
    expect_equal(scaled_parameters, expected, tolerance = 5e-4)
    expect_equal(scaled$neg_loglik, 7 * nll(scaled_parameters), tolerance = 1e-10)
    expect_equal(scaled$fisher_information,
                 7 * optimHess(scaled_parameters, nll, control = list(ndeps = rep(1e-4, 3))),
                 tolerance = 2e-5)

    estimate_args <- args
    estimate_args$estimate_only <- TRUE
    estimate_only <- do.call(EDI:::fast_beta_regression_weighted_cpp, estimate_args)
    expect_equal(c(estimate_only$coefficients, log(estimate_only$phi)), expected, tolerance = 5e-4)
    expect_equal(estimate_only$neg_loglik, nll(c(estimate_only$coefficients, log(estimate_only$phi))),
                 tolerance = 1e-10)
    expect_identical(estimate_only$fisher_information, matrix(0, 3L, 3L))
  }
})
