library(testthat)
library(EDI)

test_that("weighted hurdle GLMM uses mean positive weight per retained group", {
  skip_if_not_installed("numDeriv")
  X <- cbind(1, c(-1, 0, 1, 0.5, -0.5, 0.25, 0.75))
  y <- c(2, 0, 3, 1, 4, 2, 1)
  groups <- c(8L, 8L, 8L, 2L, 2L, 4L, 4L)
  weights <- c(2, 9, 4, 0.5, 1.5, 0, -1)
  params <- c(log(2), 0.2, log(0.3))
  n_gh <- 15L
  jacobi <- matrix(0, n_gh, n_gh)
  for (i in seq_len(n_gh - 1L)) {
    jacobi[i, i + 1L] <- sqrt(i / 2)
    jacobi[i + 1L, i] <- sqrt(i / 2)
  }
  rule <- eigen(jacobi, symmetric = TRUE)
  reference <- function(par) {
    kept <- which(y > 0 & weights > 0)
    total <- 0
    for (g in unique(groups[kept])) {
      rows <- kept[groups[kept] == g]
      eta <- drop(X[rows, , drop = FALSE] %*% par[1:2])
      log_terms <- vapply(seq_len(n_gh), function(k) {
        predictor <- eta + sqrt(2) * exp(par[3]) * rule$values[k]
        lambda <- exp(predictor)
        log(rule$vectors[1, k]^2) + sum(
          dpois(y[rows], lambda, log = TRUE) - log(-expm1(-lambda)))
      }, numeric(1))
      largest <- max(log_terms)
      total <- total - mean(weights[rows]) * (largest + log(sum(exp(log_terms - largest))))
    }
    total
  }
  expect_equal(EDI:::get_hurdle_poisson_glmm_weighted_neg_loglik_cpp(
    X, y, groups, weights, params, n_gh), reference(params), tolerance = 1e-11)
  expect_equal(as.numeric(EDI:::get_hurdle_poisson_glmm_weighted_score_cpp(
    X, y, groups, weights, params, n_gh)), -numDeriv::grad(reference, params), tolerance = 1e-7)
  expect_equal(EDI:::get_hurdle_poisson_glmm_weighted_hessian_cpp(
    X, y, groups, weights, params, n_gh), -numDeriv::hessian(reference, params), tolerance = 1e-5)
  kept <- which(y > 0 & weights > 0)
  expect_equal(EDI:::get_hurdle_poisson_glmm_weighted_neg_loglik_cpp(
    X[kept, , drop = FALSE], y[kept], groups[kept], weights[kept], params, n_gh), reference(params))
})

test_that("weighted hurdle GLMM returns zero contributions with no eligible rows", {
  X <- matrix(1, 3, 1)
  params <- c(log(2), log(0.5))
  expect_equal(EDI:::get_hurdle_poisson_glmm_weighted_neg_loglik_cpp(
    X, c(0, 1, 2), 1:3, c(1, 0, -1), params), 0)
  expect_equal(EDI:::get_hurdle_poisson_glmm_weighted_score_cpp(
    X, c(0, 1, 2), 1:3, c(1, 0, -1), params), c(0, 0))
  expect_equal(EDI:::get_hurdle_poisson_glmm_weighted_hessian_cpp(
    X, c(0, 1, 2), 1:3, c(1, 0, -1), params), matrix(0, 2, 2))
})

test_that("weighted hurdle GLMM accessors reject incorrect weights and parameter lengths", {
  accessors <- list(EDI:::get_hurdle_poisson_glmm_weighted_neg_loglik_cpp,
                    EDI:::get_hurdle_poisson_glmm_weighted_score_cpp,
                    EDI:::get_hurdle_poisson_glmm_weighted_hessian_cpp)
  for (accessor in accessors) {
    expect_error(accessor(matrix(1, 2, 1), c(1, 2), 1:2, 1, c(0, -1)), "Dimension mismatch")
    expect_error(accessor(matrix(1, 2, 1), c(1, 2), 1:2, c(1, 1), 0), "params must have length")
  }
})
