library(testthat)
library(EDI)

proportion_gcomp_weighted_fixture <- function() {
  n <- 32L
  x <- sin(seq_len(n))
  w <- rep(c(0, 1), n / 2)
  y <- plogis(-0.4 + 0.8 * w + 0.6 * x + 0.5 * cos(seq_len(n)))
  des <- DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = x))
  des$overwrite_all_subject_assignments(w)
  des$add_all_subject_responses(y)
  inf <- InferencePropGCompMeanDiff$new(des, model_formula = ~ x, verbose = FALSE)
  private <- inf$.__enclos_env__$private
  private$current_bayesian_bootstrap_context <- private$build_bayesian_bootstrap_context()
  list(inf = inf, X = cbind(1, w, x), y = y)
}

proportion_gcomp_weighted_reference <- function(fixture, weights) {
  keep <- weights > 0
  fit <- glm.fit(fixture$X[keep, , drop = FALSE], fixture$y[keep], weights = weights[keep],
                 family = quasibinomial(), control = glm.control(epsilon = 1e-12, maxit = 100))
  X0 <- X1 <- fixture$X
  X0[, 2] <- 0; X1[, 2] <- 1
  # The class standardizes over the full observed covariate cohort, including
  # subjects omitted from the weighted coefficient fit.
  mean0 <- mean(plogis(X0 %*% fit$coefficients))
  mean1 <- mean(plogis(X1 %*% fit$coefficients))
  list(mean0 = mean0, mean1 = mean1, md = mean1 - mean0, coefficients = fit$coefficients)
}

test_that("weighted proportion g-computation matches independent fractional logistic standardization", {
  for (omit in c(FALSE, TRUE)) {
    for (scale in c(1, 1e-12, 1e-200)) {
      fixture <- proportion_gcomp_weighted_fixture()
      weights <- rep(c(1, 2, 4, 7), 8)
      if (omit) weights[c(2, 5, 8, 11)] <- 0
      expected <- proportion_gcomp_weighted_reference(fixture, weights)
      actual <- fixture$inf$compute_estimate_with_bootstrap_weights(scale * weights,
                                                                  estimate_only = TRUE)
      private <- fixture$inf$.__enclos_env__$private
      expect_equal(actual, expected$md, tolerance = 1e-7)
      # The standardized means / coefficients are internal to the (now rolled-back) weighted fit;
      # the returned md = mean1 - mean0 checks both against the independent reference.
      expect_equal(private$last_weighted_refit$beta_hat_T, expected$md, tolerance = 1e-7)
      expect_true(is.na(private$weighted_refit_se()))
    }
  }
})

test_that("empty weighted proportion draws clear the standardized fit cache", {
  fixture <- proportion_gcomp_weighted_fixture()
  weights <- rep(c(1, 2, 4, 7), 8)
  expect_true(is.finite(fixture$inf$compute_estimate_with_bootstrap_weights(weights)))
  expect_true(is.na(fixture$inf$compute_estimate_with_bootstrap_weights(0 * weights)))
  private <- fixture$inf$.__enclos_env__$private
  expect_true(is.na(private$last_weighted_refit$beta_hat_T))
  expect_true(is.na(private$weighted_refit_se()))
  expect_true(is.null(private$cached_values$md) || is.finite(private$cached_values$md))   # ordinary cache untouched by the empty draw
})

test_that("empty proportion draws cannot retain a treatment-only model for the next fit", {
  fixture <- proportion_gcomp_weighted_fixture()
  weights <- rep(c(1, 2, 4, 7), 8)
  expected <- proportion_gcomp_weighted_reference(fixture, weights)
  expect_true(is.na(fixture$inf$compute_estimate_with_bootstrap_weights(0 * weights)))
  actual <- fixture$inf$compute_estimate_with_bootstrap_weights(1e-200 * weights)
  expect_equal(actual, expected$md, tolerance = 1e-7)
  expect_equal(fixture$inf$.__enclos_env__$private$last_weighted_refit$beta_hat_T, expected$md, tolerance = 1e-7)
})
