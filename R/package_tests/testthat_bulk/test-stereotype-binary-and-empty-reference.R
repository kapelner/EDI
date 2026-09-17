library(testthat)
library(EDI)

test_that("binary stereotype derivatives reduce to ordinary logistic regression", {
  X <- cbind(c(-2, 0, 1, 2, -1, 0.5), c(1, -1, 0, 2, 0.5, -2))
  y <- c(-7, 12, -7, 12, 12, -7)
  params <- c(-0.2, 0.4, -0.3)
  Z <- cbind(1, X)
  p <- plogis(drop(Z %*% params))
  expected_score <- drop(crossprod(Z, (y == 12) - p))
  expected_H <- -crossprod(Z, Z * (p * (1 - p)))
  expect_equal(as.numeric(EDI:::get_stereotype_logit_score_cpp(X, y, params)),
               expected_score, tolerance = 1e-12)
  expect_equal(EDI:::get_stereotype_logit_hessian_cpp(X, y, params),
               unname(expected_H), tolerance = 1e-12)
  expect_equal(EDI:::get_stereotype_logit_score_cpp(X, as.numeric(y == 12), params),
               EDI:::get_stereotype_logit_score_cpp(X, y, params))
})

test_that("binary stereotype fits without covariates recover empirical log odds", {
  y <- c(rep(-5, 4), rep(20, 7))
  X <- matrix(numeric(), length(y), 0)
  fit <- fast_stereotype_logit_cpp(X, y, estimate_only = TRUE, warm_start_params = 0)
  expect_true(fit$converged)
  expect_identical(as.numeric(fit$b), numeric())
  expect_identical(as.numeric(fit$scores_raw), numeric())
  expect_equal(as.numeric(fit$alpha), log(7 / 4), tolerance = 1e-6)
  expect_equal(fit$neg_loglik, -sum(c(4, 7) * log(c(4, 7) / 11)), tolerance = 1e-9)
})

test_that("multicategory stereotype fit without covariates leaves score nuisance fixed", {
  counts <- c(3L, 5L, 7L)
  y <- rep(c(-5, 2, 20), counts)
  X <- matrix(numeric(), length(y), 0)
  # The category score cannot affect a model with no linear predictor.
  fit <- fast_stereotype_logit_cpp(X, y, fixed_idx = 3L, fixed_values = 0,
                                   estimate_only = TRUE, optimization_alg = "lbfgs")
  expect_true(fit$converged)
  expect_identical(as.numeric(fit$b), numeric())
  expect_equal(as.numeric(fit$alpha), log(counts[2:3] / counts[1]), tolerance = 1e-6)
  expect_identical(as.numeric(fit$scores_raw), 0)
  expect_equal(fit$neg_loglik, -sum(counts * log(counts / sum(counts))), tolerance = 1e-9)
  expect_equal(as.numeric(EDI:::get_stereotype_logit_score_cpp(X, y, fit$params)),
               rep(0, 3), tolerance = 1e-5)
})
