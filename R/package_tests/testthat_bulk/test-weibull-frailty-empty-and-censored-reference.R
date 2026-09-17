library(testthat)
library(EDI)

frailty_integrated_reference <- function(X, y, dead, groups, params) {
  p <- ncol(X)
  eta <- if (p) drop(X %*% params[seq_len(p)]) else rep(0, length(y))
  scale_error <- exp(params[p + 1L])
  scale_frailty <- exp(params[p + 2L])
  contributions <- vapply(unique(groups), function(g) {
    rows <- which(groups == g)
    integrand <- function(z) {
      joint <- rep(1, length(z))
      for (i in rows) {
        scale <- exp(eta[i] + scale_frailty * z)
        term <- if (dead[i] == 1) {
          dweibull(y[i], shape = 1 / scale_error, scale = scale)
        } else {
          pweibull(y[i], shape = 1 / scale_error, scale = scale, lower.tail = FALSE)
        }
        joint <- joint * term
      }
      joint * dnorm(z)
    }
    # The omitted normal tail beyond twelve SD is negligible for these fixtures.
    integrate(integrand, -12, 12, rel.tol = 1e-10)$value
  }, numeric(1))
  -sum(log(contributions))
}

test_that("frailty likelihood derivatives integrate exact and censored groups independently", {
  skip_if_not_installed("numDeriv")
  X <- cbind(1, c(-1, 0, 1, -0.5, 0.5, 1.5))
  y <- c(0.8, 1.5, 2.1, 1.2, 0.9, 2.4)
  groups <- c(11L, 2L, 11L, 2L, 90L, 90L)
  params <- c(0.2, -0.15, log(1.2), log(0.35))
  for (dead in list(rep(0, 6), rep(1, 6), c(1, 0, 0, 1, 1, 0))) {
    reference <- function(par) frailty_integrated_reference(X, y, dead, groups, par)
    expect_equal(EDI:::get_weibull_frailty_neg_loglik_cpp(X, y, dead, groups, params, n_gh = 40L),
                 reference(params), tolerance = 1e-9)
    expect_equal(as.numeric(EDI:::get_weibull_frailty_score_cpp(X, y, dead, groups, params, n_gh = 40L)),
                 -numDeriv::grad(reference, params), tolerance = 1e-6)
    expect_equal(EDI:::get_weibull_frailty_hessian_cpp(X, y, dead, groups, params, n_gh = 40L),
                 -numDeriv::hessian(reference, params), tolerance = 2e-4)
  }
})

test_that("frailty grouping is independent of arrival order and group labels", {
  X <- matrix(c(-1, 0, 1, 2, -2, 0.5), ncol = 1)
  y <- c(0.8, 1.5, 2.1, 1.2, 0.9, 2.4)
  dead <- c(1, 0, 0, 1, 1, 0)
  groups <- c(11L, 2L, 11L, 2L, 90L, 90L)
  params <- c(0.2, log(1.2), log(0.35))
  perm <- c(6, 3, 1, 5, 2, 4)
  renamed <- c(3L, 1L, 3L, 1L, 2L, 2L)
  for (accessor in list(EDI:::get_weibull_frailty_neg_loglik_cpp,
                        EDI:::get_weibull_frailty_score_cpp,
                        EDI:::get_weibull_frailty_hessian_cpp)) {
    expect_equal(accessor(X[perm, , drop = FALSE], y[perm], dead[perm], renamed[perm], params),
                 accessor(X, y, dead, groups, params), tolerance = 1e-8)
  }
})

test_that("frailty likelihood supports zero covariates and an empty group collection", {
  X <- matrix(numeric(), 4, 0)
  y <- c(1, 2, 1.5, 0.8)
  dead <- c(1, 0, 0, 1)
  groups <- c(5L, 2L, 5L, 2L)
  params <- c(log(1.2), log(0.35))
  expect_equal(EDI:::get_weibull_frailty_neg_loglik_cpp(X, y, dead, groups, params, n_gh = 40L),
               frailty_integrated_reference(X, y, dead, groups, params), tolerance = 1e-9)
  empty <- matrix(numeric(), 0, 0)
  expect_equal(EDI:::get_weibull_frailty_neg_loglik_cpp(empty, numeric(), numeric(), integer(), params), 0)
  expect_equal(as.numeric(EDI:::get_weibull_frailty_score_cpp(empty, numeric(), numeric(), integer(), params)), c(0, 0))
  expect_equal(EDI:::get_weibull_frailty_hessian_cpp(empty, numeric(), numeric(), integer(), params), matrix(0, 2, 2))
})
