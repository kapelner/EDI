library(testthat)
library(EDI)

test_that("binary stereotype profiles agree with offset logistic likelihoods", {
  i <- seq_len(36L)
  y <- rep(c(-4, 9), each = 18L)
  for (X in list(matrix(sin(i), ncol = 1L), cbind(sin(i), cos(i)))) {
    for (fixed in c(-0.75, 0, 0.5)) {
      nuisance <- cbind(1, X[, -1L, drop = FALSE])
      reference <- glm.fit(nuisance, as.numeric(y == 9), family = binomial(),
                           offset = X[, 1L] * fixed)
      loglik <- sum(dbinom(as.integer(y == 9), 1L, reference$fitted.values, log = TRUE))
      actual <- EDI:::fast_stereotype_profile_loglik_cpp(X, y, fixed)
      expect_equal(actual, loglik, tolerance = 1e-7)
      expect_equal(EDI:::fast_stereotype_profile_loglik_cpp(
        X, y, fixed, warm_start_params = rep(0, 1L + ncol(X))), actual, tolerance = 1e-7)
      expect_equal(EDI:::fast_stereotype_profile_loglik_cpp(
        X, y, fixed, warm_start_beta = rep(0.1, ncol(X))), actual, tolerance = 1e-7)
    }
  }
  expect_error(EDI:::fast_stereotype_profile_loglik_cpp(matrix(i, ncol = 1L), rep(1, 36L), 0),
               "at least two")
  expect_error(EDI:::fast_stereotype_profile_loglik_cpp(matrix(sin(i), ncol = 1L), y, 0,
                                                       warm_start_params = 0), "size mismatch")
})

test_that("binary stereotype randomization draws equal independent logistic fits", {
  i <- seq_len(36L)
  y <- rep(c(-4, 9), each = 18L)
  draws <- cbind(as.integer(i %% 2L == 0L), as.integer(i %% 5L < 2L),
                 as.integer((i + 1L) %% 7L < 3L))
  for (X in list(matrix(numeric(), 36L, 0L), matrix(sin(i), ncol = 1L))) {
    expected <- apply(draws, 2L, function(w) {
      reference <- glm.fit(cbind(1, w, X), as.numeric(y == 9), family = binomial(),
                           control = glm.control(epsilon = 1e-12))
      unname(reference$coefficients[2L])
    })
    actual <- EDI:::compute_stereotype_logit_distr_parallel_cpp(X, y, draws, 0, 1L)
    expect_true(all(is.finite(actual)))
    # The legacy draw solver accepts a score tolerance sqrt(1e-8) = 1e-4.
    expect_equal(as.numeric(actual), expected, tolerance = 1e-5)
    for (j in seq_len(ncol(draws))) {
      unrestricted <- glm.fit(cbind(1, draws[, j], X), as.numeric(y == 9),
                              family = binomial(), control = glm.control(epsilon = 1e-12))
      profiled <- glm.fit(cbind(1, X), as.numeric(y == 9), family = binomial(),
                          offset = draws[, j] * actual[j], control = glm.control(epsilon = 1e-12))
      expect_lt(abs(profiled$deviance - unrestricted$deviance), 1e-8)
    }
    expect_equal(EDI:::compute_stereotype_logit_distr_parallel_cpp(X, y + 20, draws, 0, 1L), actual)
    expect_equal(as.numeric(EDI:::compute_stereotype_logit_distr_parallel_cpp(
      X, y, draws[, 3:1, drop = FALSE], 0, 1L)), rev(as.numeric(actual)))
  }
  expect_true(all(is.na(EDI:::compute_stereotype_logit_distr_parallel_cpp(
    matrix(numeric(), 36L, 0L), rep(4, 36L), draws, 0, 1L))))
  expect_identical(as.numeric(EDI:::compute_stereotype_logit_distr_parallel_cpp(
    matrix(numeric(), 36L, 0L), y, matrix(integer(), 36L, 0L), 0, 1L)), numeric())
})
