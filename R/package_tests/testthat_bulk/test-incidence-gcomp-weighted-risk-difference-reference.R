library(testthat)
library(EDI)

incid_weighted_rd_fixture <- function(generator = InferenceIncidGCompRiskDiff) {
  withr::local_seed(2217)
  n <- 80L
  x <- sin(seq_len(n))
  w <- rep(c(0, 1), n / 2)
  y <- rbinom(n, 1, plogis(-0.4 + 0.8 * w + 0.6 * x))
  des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = x))
  des$overwrite_all_subject_assignments(w)
  des$add_all_subject_responses(y)
  inf <- generator$new(des, model_formula = ~ x, verbose = FALSE)
  private <- inf$.__enclos_env__$private
  private$current_bayesian_bootstrap_context <- private$build_bayesian_bootstrap_context()
  list(inf = inf, X = cbind(1, w, x), y = y)
}

incid_weighted_rd_reference <- function(fixture, weights) {
  keep <- is.finite(weights) & weights > 0
  fit <- suppressWarnings(glm.fit(fixture$X[keep, , drop = FALSE], fixture$y[keep],
    weights = weights[keep], family = binomial(), control = glm.control(epsilon = 1e-12, maxit = 100)))
  X0 <- X1 <- fixture$X
  X0[, 2] <- 0; X1[, 2] <- 1
  risk0 <- mean(plogis(X0 %*% fit$coefficients))
  risk1 <- mean(plogis(X1 %*% fit$coefficients))
  # Weighted fitting and standardizing over the original observed cohort are
  # separate operations in the class's specified g-computation estimand.
  loss <- function(beta) -sum(weights[keep] *
    dbinom(fixture$y[keep], 1, plogis(fixture$X[keep, , drop = FALSE] %*% beta), log = TRUE))
  list(risk0 = risk0, risk1 = risk1, rd = risk1 - risk0,
       coefficients = unname(fit$coefficients), loss = loss)
}

test_that("weighted incidence RD matches independent logistic fitting and cohort standardization", {
  for (omit in c(FALSE, TRUE)) {
    for (scale in c(1, 1e-12, 1e-200)) {
      fixture <- incid_weighted_rd_fixture()
      weights <- rep(c(1, 2, 4, 7), 20)
      if (omit) weights[c(2, 5, 8, 11, 14)] <- 0
      expected <- incid_weighted_rd_reference(fixture, weights)
      actual <- fixture$inf$compute_estimate_with_bootstrap_weights(scale * weights,
                                                                  estimate_only = TRUE)
      cache <- fixture$inf$.__enclos_env__$private$cached_values
      expect_equal(actual, expected$rd, tolerance = 1e-7)
      expect_equal(cache$risk0, expected$risk0, tolerance = 1e-7)
      expect_equal(cache$risk1, expected$risk1, tolerance = 1e-7)
      expect_equal(unname(cache$full_coefficients), expected$coefficients, tolerance = 1e-6)
      expect_lt(expected$loss(cache$full_coefficients) - expected$loss(expected$coefficients), 1e-8)
      expect_true(is.na(cache$se_rd))
    }
  }
})

test_that("weighted incidence RD warm starts adapt to new relative weights", {
  fixture <- incid_weighted_rd_fixture()
  for (iteration in seq_len(3)) {
    weights <- rep(c(1, 2, 4, 7) + iteration, 20)
    expected <- incid_weighted_rd_reference(fixture, weights)
    scale <- c(1, 1e-200, 3)[iteration]
    actual <- fixture$inf$compute_estimate_with_bootstrap_weights(scale * weights)
    expect_equal(actual, expected$rd, tolerance = 1e-6)
    cache <- fixture$inf$.__enclos_env__$private$cached_values
    expect_lt(expected$loss(cache$full_coefficients) - expected$loss(expected$coefficients), 1e-8)
    expect_true(is.na(cache$se_rd))
  }
})

test_that("empty incidence RD draws clear the prior standardized treatment effect", {
  fixture <- incid_weighted_rd_fixture()
  weights <- rep(c(1, 2, 4, 7), 20)
  expect_true(is.finite(fixture$inf$compute_estimate_with_bootstrap_weights(weights)))
  expect_true(is.na(fixture$inf$compute_estimate_with_bootstrap_weights(0 * weights)))
  cache <- fixture$inf$.__enclos_env__$private$cached_values
  expect_true(is.na(cache$beta_hat_T))
  expect_true(is.na(cache$rd))
  expect_true(is.na(cache$se_rd))
  expect_null(cache$full_coefficients)
})

test_that("incidence RD refits a valid draw after an empty weighted fit", {
  fixture <- incid_weighted_rd_fixture()
  weights <- rep(c(1, 2, 4, 7), 20)
  expect_true(is.na(fixture$inf$compute_estimate_with_bootstrap_weights(0 * weights)))
  expected <- incid_weighted_rd_reference(fixture, weights)
  expect_equal(fixture$inf$compute_estimate_with_bootstrap_weights(1e-200 * weights),
               expected$rd, tolerance = 1e-7)
  cache <- fixture$inf$.__enclos_env__$private$cached_values
  expect_equal(cache$risk1 - cache$risk0, expected$rd, tolerance = 1e-7)
})

test_that("actual incidence risk-ratio weighted fits share scale-invariant standardized risks", {
  for (omit in c(FALSE, TRUE)) {
    for (scale in c(1, 1e-12, 1e-200)) {
      fixture <- incid_weighted_rd_fixture(InferenceIncidGCompRiskRatio)
      weights <- rep(c(1, 2, 4, 7), 20)
      if (omit) weights[c(2, 5, 8, 11, 14)] <- 0
      expected <- incid_weighted_rd_reference(fixture, weights)
      expected_rr <- expected$risk1 / expected$risk0
      actual <- fixture$inf$compute_estimate_with_bootstrap_weights(scale * weights)
      cache <- fixture$inf$.__enclos_env__$private$cached_values
      expect_equal(actual, expected_rr, tolerance = 1e-6)
      expect_equal(cache$rr, expected_rr, tolerance = 1e-6)
      expect_equal(cache$log_rr, log(expected_rr), tolerance = 1e-6)
      expect_equal(unname(cache$full_coefficients), expected$coefficients, tolerance = 1e-6)
      expect_true(is.na(cache$se_log_rr))
    }
  }
})

test_that("risk-ratio empty draws cannot poison subsequent full-model weighted fits", {
  fixture <- incid_weighted_rd_fixture(InferenceIncidGCompRiskRatio)
  weights <- rep(c(1, 2, 4, 7), 20)
  expected <- incid_weighted_rd_reference(fixture, weights)
  expect_true(is.finite(fixture$inf$compute_estimate_with_bootstrap_weights(weights)))
  expect_true(is.na(fixture$inf$compute_estimate_with_bootstrap_weights(0 * weights)))
  cache <- fixture$inf$.__enclos_env__$private$cached_values
  expect_true(is.na(cache$rr))
  expect_true(is.na(cache$log_rr))
  expect_true(is.na(cache$beta_hat_T))
  actual <- fixture$inf$compute_estimate_with_bootstrap_weights(1e-200 * weights)
  expect_equal(actual, expected$risk1 / expected$risk0, tolerance = 1e-6)
  expect_equal(unname(fixture$inf$.__enclos_env__$private$cached_values$full_coefficients),
               expected$coefficients, tolerance = 1e-6)
})
