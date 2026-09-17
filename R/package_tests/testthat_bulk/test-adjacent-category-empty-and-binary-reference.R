library(testthat)
library(EDI)

test_that("adjacent-category fits without covariates recover empirical category odds", {
  counts <- c(3L, 5L, 7L)
  y <- rep(c(-8, 2, 19), counts)
  X <- matrix(numeric(), length(y), 0)
  fit <- fast_adjacent_category_logit_with_var_cpp(X, y, smart_cold_start = FALSE,
                                                 tol = 1e-10)
  expect_true(fit$converged)
  expect_identical(as.numeric(fit$b), numeric())
  expect_equal(as.numeric(fit$alpha), log(counts[1:2] / counts[2:3]), tolerance = 1e-6)
  expect_equal(fit$neg_loglik, -sum(counts * log(counts / sum(counts))), tolerance = 1e-9)
  expect_true(is.na(fit$ssq_b_1))
  expect_equal(as.numeric(EDI:::get_adjacent_category_logit_score_cpp(X, y, fit$params)),
               rep(0, 2), tolerance = 1e-5)
})

test_that("binary adjacent-category derivatives equal a Bernoulli model", {
  x <- c(-2, -1, 0, 0.5, 1, 3)
  X <- matrix(x, ncol = 1)
  y <- c(-4, 20, -4, 20, -4, 20)
  params <- c(0.35, -0.4)
  # The first-category logit is alpha - beta*x.
  Z <- cbind(1, -x)
  p <- plogis(drop(Z %*% params))
  expected_score <- drop(crossprod(Z, (y == -4) - p))
  expected_H <- -crossprod(Z, Z * (p * (1 - p)))
  expect_equal(as.numeric(EDI:::get_adjacent_category_logit_score_cpp(X, y, params)),
               expected_score, tolerance = 1e-12)
  expect_equal(EDI:::get_adjacent_category_logit_hessian_cpp(X, y, params),
               unname(expected_H), tolerance = 1e-12)
  # Labels are category identifiers, not quantitative responses.
  expect_equal(EDI:::get_adjacent_category_logit_score_cpp(X, as.numeric(y == 20), params),
               EDI:::get_adjacent_category_logit_score_cpp(X, y, params))
})

test_that("constrained adjacent-category fit agrees with a one-dimensional likelihood", {
  X <- matrix(c(-1, 0, 1, 2, -2, 0.5), ncol = 1)
  y <- rep(c(2, 7, 11), 2)
  params <- c(0.2, -0.3, 0.4)
  probabilities_at <- function(beta) {
    eta <- drop(X * beta)
    logits <- cbind(params[1] + params[2] - 2 * eta, params[2] - eta, 0)
    probabilities <- exp(logits - apply(logits, 1, max))
    probabilities / rowSums(probabilities)
  }
  neg_loglik <- function(beta) {
    -sum(log(probabilities_at(beta)[cbind(seq_along(y), match(y, sort(unique(y))))]))
  }
  reference <- optimize(neg_loglik, c(-4, 4), tol = 1e-10)
  fit <- fast_adjacent_category_logit_with_var_cpp(
    X, y, fixed_idx = 1:2, fixed_values = params[1:2], tol = 1e-10)
  expect_equal(as.numeric(fit$alpha), params[1:2])
  expect_equal(as.numeric(fit$b), reference$minimum, tolerance = 1e-6)
  expect_equal(fit$neg_loglik, reference$objective, tolerance = 1e-10)
  p <- probabilities_at(reference$minimum)
  mean_category <- drop(p %*% 1:3)
  category_variance <- drop(p %*% (1:3)^2) - mean_category^2
  expect_equal(fit$ssq_b_1, 1 / sum(X[, 1]^2 * category_variance), tolerance = 1e-6)
})
