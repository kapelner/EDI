library(testthat)
library(EDI)

test_that("weighted constrained-binomial fits recover weighted arm proportions", {
  X <- cbind(1, rep(0:1, each = 8))
  y <- rep(c(0, 1, 0, 1, 1, 0, 0, 1), 2)
  weights <- c(1, 2, 0, 1, 4, 1, 2, 3, 3, 1, 1, 4, 2, 0, 1, 2)
  proportions <- vapply(0:1, function(arm) {
    rows <- X[, 2] == arm
    sum(weights[rows] * y[rows]) / sum(weights[rows])
  }, numeric(1))
  for (link in c("log", "identity")) {
    fit <- get(paste0("fast_", link, "_binomial_regression_weighted_cpp"),
               asNamespace("EDI"))
    transformed <- if (link == "log") log(proportions) else proportions
    expected_beta <- c(transformed[1], diff(transformed))
    expected_mu <- proportions[X[, 2] + 1]
    expected_working <- if (link == "log") {
      expected_mu / (1 - expected_mu)
    } else 1 / (expected_mu * (1 - expected_mu))
    expected_information <- crossprod(X, X * (weights * expected_working))
    actual <- fit(X, y, weights, maxit = 500L, tol = 1e-10)
    expect_true(actual$converged, info = link)
    expect_equal(as.numeric(actual$b), expected_beta, tolerance = 1e-7)
    expect_equal(as.numeric(actual$mu_hat), expected_mu, tolerance = 1e-7)
    expect_equal(as.numeric(actual$working_weights), expected_working, tolerance = 1e-7)
    expect_equal(actual$fisher_information, unname(expected_information), tolerance = 1e-7)
    # Each arm is a saturated Bernoulli model: the weighted mean is its
    # likelihood maximizer, independently of the regression optimizer.
    expected_ll <- sum(weights * dbinom(y, 1, expected_mu, log = TRUE))
    expect_equal(sum(weights * dbinom(y, 1, actual$mu_hat, log = TRUE)),
                 expected_ll, tolerance = 1e-10)

    keep <- weights > 0
    omitted <- fit(X[keep, ], y[keep], weights[keep], maxit = 500L, tol = 1e-10)
    expect_equal(as.numeric(omitted$b), expected_beta, tolerance = 1e-7)
    expect_equal(omitted$fisher_information, unname(expected_information), tolerance = 1e-7)
    scaled <- fit(X, y, 7 * weights, maxit = 500L, tol = 1e-10)
    expect_equal(as.numeric(scaled$b), expected_beta, tolerance = 1e-7)
    expect_equal(scaled$fisher_information, 7 * unname(expected_information), tolerance = 1e-7)

    start <- if (link == "log") c(log(.45), .1) else c(.45, .1)
    start_mu <- if (link == "log") exp(drop(X %*% start)) else drop(X %*% start)
    start_working <- if (link == "log") start_mu / (1 - start_mu) else 1 / (start_mu * (1 - start_mu))
    start_information <- crossprod(X, X * (weights * start_working))
    warm <- fit(X, y, weights, maxit = 500L, tol = 1e-10,
                warm_start_beta = start, warm_start_weights = start_working,
                warm_start_fisher_info = start_information)
    expect_true(warm$converged, info = link)
    expect_equal(as.numeric(warm$b), expected_beta, tolerance = 1e-7)
    expect_equal(warm$fisher_information, unname(expected_information), tolerance = 1e-7)
    estimate_only <- fit(X, y, weights, maxit = 500L, tol = 1e-10,
                         estimate_only = TRUE)
    expect_equal(as.numeric(estimate_only$b), expected_beta, tolerance = 1e-7)
    expect_true(estimate_only$converged)
    expect_false(any(c("fisher_information", "mu_hat", "working_weights") %in%
                       names(estimate_only)))
  }
})

test_that("fixed zero treatment coefficients recover pooled weighted Bernoulli fits", {
  X <- cbind(1, rep(0:1, each = 8))
  y <- rep(c(0, 1, 0, 1, 1, 0, 0, 1), 2)
  weights <- c(1, 2, 0, 1, 4, 1, 2, 3, 3, 1, 1, 4, 2, 0, 1, 2)
  pooled <- weighted.mean(y, weights)
  for (link in c("log", "identity")) {
    fit <- get(paste0("fast_", link, "_binomial_regression_weighted_cpp"),
               asNamespace("EDI"))
    expected <- c(if (link == "log") log(pooled) else pooled, 0)
    actual <- fit(X, y, weights, fixed_idx = 2L, fixed_values = 0,
                  maxit = 500L, tol = 1e-10)
    expect_true(actual$converged, info = link)
    expect_equal(as.numeric(actual$b), expected, tolerance = 1e-7)
    expect_identical(actual$b[2], 0)
    expect_equal(as.numeric(actual$mu_hat), rep(pooled, length(y)), tolerance = 1e-7)
    scalar_information <- if (link == "log") pooled / (1 - pooled) else 1 / (pooled * (1 - pooled))
    expect_equal(actual$fisher_information,
                 unname(crossprod(X, X * (weights * scalar_information))), tolerance = 1e-7)
    warm <- fit(X, y, weights, fixed_idx = 2L, fixed_values = 0,
                warm_start_beta = expected,
                warm_start_fisher_info = actual$fisher_information,
                maxit = 500L, tol = 1e-10)
    expect_equal(as.numeric(warm$b), expected, tolerance = 1e-7)
    expect_true(warm$converged, info = link)
  }
})

test_that("fixed nonzero treatment coefficients preserve offsets in weighted scoring", {
  X <- cbind(1, rep(0:1, each = 8))
  y <- rep(c(0, 1, 0, 1, 1, 0, 0, 1), 2)
  weights <- c(1, 2, 0, 1, 4, 1, 2, 3, 3, 1, 1, 4, 2, 0, 1, 2)
  for (link in c("log", "identity")) {
    offset <- if (link == "log") .2 else .15
    probability <- function(intercept) {
      eta <- intercept + X[, 2] * offset
      if (link == "log") exp(eta) else eta
    }
    nll <- function(intercept) {
      -sum(weights * dbinom(y, 1, probability(intercept), log = TRUE))
    }
    interval <- if (link == "log") c(-3, -.21) else c(.01, .84)
    reference <- optimize(nll, interval, tol = 1e-12)
    fit <- get(paste0("fast_", link, "_binomial_regression_weighted_cpp"),
               asNamespace("EDI"))
    actual <- fit(X, y, weights, fixed_idx = 2L, fixed_values = offset,
                  maxit = 500L, tol = 1e-10)
    expect_true(actual$converged, info = link)
    expect_equal(as.numeric(actual$b), c(reference$minimum, offset), tolerance = 1e-7)
    expect_identical(actual$b[2], offset)
    expect_equal(as.numeric(actual$mu_hat), probability(reference$minimum), tolerance = 1e-7)
    expect_equal(nll(actual$b[1]), reference$objective, tolerance = 1e-10)
    mu <- probability(reference$minimum)
    working <- if (link == "log") mu / (1 - mu) else 1 / (mu * (1 - mu))
    expect_equal(actual$fisher_information, unname(crossprod(X, X * (weights * working))),
                 tolerance = 1e-7)
  }
})
