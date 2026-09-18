library(testthat)
library(EDI)

test_that("weighted constrained-binomial derivatives match analytic Bernoulli likelihoods", {
  X <- cbind(1, c(-1, -.5, 0, .5, 1, 1.5))
  y <- c(0, 1, 0, 1, 1, 0)
  weights <- c(0, .5, 2, 1.5, 3, 1)
  for (link in c("log", "identity")) {
    beta <- if (link == "log") c(-1.2, .15) else c(.4, .08)
    eta <- drop(X %*% beta)
    mu <- if (link == "log") exp(eta) else eta
    if (link == "log") {
      scalar_score <- (y - mu) / (1 - mu)
      scalar_H <- -(1 - y) * mu / (1 - mu)^2
    } else {
      scalar_score <- y / mu - (1 - y) / (1 - mu)
      scalar_H <- -y / mu^2 - (1 - y) / (1 - mu)^2
    }
    expected_score <- drop(crossprod(X, weights * scalar_score))
    expected_H <- crossprod(X, X * (weights * scalar_H))
    score <- get(paste0("get_", link, "_binomial_regression_weighted_score_cpp"), asNamespace("EDI"))
    hessian <- get(paste0("get_", link, "_binomial_regression_weighted_hessian_cpp"), asNamespace("EDI"))
    actual_score <- score(X, y, weights, beta)
    actual_H <- hessian(X, y, weights, beta)
    expect_equal(as.numeric(actual_score), expected_score, tolerance = 1e-8)
    # Native Hessians use central differences with step 1e-4.
    expect_equal(actual_H, unname(expected_H), tolerance = 3e-6)
    expect_equal(actual_H, t(actual_H), tolerance = 1e-12)
    expect_true(all(eigen(actual_H, symmetric = TRUE, only.values = TRUE)$values < 0))
    expect_equal(as.numeric(score(X, y, 7 * weights, beta)), 7 * as.numeric(actual_score), tolerance = 1e-8)
    expect_equal(hessian(X, y, 7 * weights, beta), 7 * actual_H, tolerance = 3e-6)
    keep <- weights > 0
    expect_equal(score(X[keep, ], y[keep], weights[keep], beta), actual_score, tolerance = 1e-8)
    expect_equal(hessian(X[keep, ], y[keep], weights[keep], beta), actual_H, tolerance = 3e-6)
    order <- c(6, 3, 1, 5, 2, 4)
    expect_equal(score(X[order, ], y[order], weights[order], beta), actual_score, tolerance = 1e-8)
    expect_equal(hessian(X[order, ], y[order], weights[order], beta), actual_H, tolerance = 3e-6)
    expect_equal(as.numeric(score(X, y, rep(0, length(y)), beta)), c(0, 0))
    expect_equal(hessian(X, y, rep(0, length(y)), beta), matrix(0, 2L, 2L))
  }
})
