library(testthat)
library(EDI)

fractional_weighted_reference_fixture <- function(harden = TRUE) {
  n <- 32L
  x <- sin(seq_len(n)); w <- rep(c(0, 1), n / 2)
  y <- plogis(-0.4 + 0.8 * w + 0.6 * x + 0.5 * cos(seq_len(n)))
  des <- DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = x, duplicate = x, constant = 1))
  des$overwrite_all_subject_assignments(w)
  des$add_all_subject_responses(y)
  inf <- InferencePropFractionalLogit$new(des, harden = harden,
    model_formula = if (harden) ~ x + duplicate + constant else ~ x, verbose = FALSE)
  private <- inf$.__enclos_env__$private
  private$current_bayesian_bootstrap_context <- private$build_bayesian_bootstrap_context()
  list(inf = inf, X = cbind(1, w, x), y = y)
}

fractional_weighted_coefficient_reference <- function(fixture, weights) {
  keep <- is.finite(weights) & weights > 0
  fit <- glm.fit(fixture$X[keep, , drop = FALSE], fixture$y[keep], weights = weights[keep],
    family = quasibinomial(), control = glm.control(epsilon = 1e-12, maxit = 100))
  loss <- function(beta) {
    eta <- as.numeric(fixture$X[keep, , drop = FALSE] %*% beta)
    sum(weights[keep] * (log1p(exp(eta)) - fixture$y[keep] * eta))
  }
  list(coefficient = unname(fit$coefficients[2]), coefficients = unname(fit$coefficients), loss = loss)
}

test_that("weighted fractional logit treatment coefficients match independent quasi-likelihood fits", {
  for (harden in c(FALSE, TRUE)) {
    for (omit in c(FALSE, TRUE)) {
      for (scale in c(1, 1e-12, 1e-200)) {
        fixture <- fractional_weighted_reference_fixture(harden)
        weights <- rep(c(1, 2, 4, 7), 8)
        if (omit) weights[c(2, 5, 8, 11)] <- 0
        expected <- fractional_weighted_coefficient_reference(fixture, weights)
        actual <- fixture$inf$compute_estimate_with_bootstrap_weights(scale * weights)
        private <- fixture$inf$.__enclos_env__$private
        expect_equal(actual, expected$coefficient, tolerance = 1e-6)
        # QR hardening must leave only the independent intercept, treatment,
        # and x columns from the deliberately duplicated fixture.
        expect_length(private$cached_mod$b, 3)
        expect_lt(expected$loss(private$cached_mod$b) - expected$loss(expected$coefficients), 1e-8)
        expect_true(is.na(private$cached_values$s_beta_hat_T))
      }
    }
  }
})

test_that("fractional logit weighted warm starts recover from empty draws with changed weights", {
  for (harden in c(FALSE, TRUE)) {
    fixture <- fractional_weighted_reference_fixture(harden)
    weights <- rep(c(1, 2, 4, 7), 8)
    expect_true(is.finite(fixture$inf$compute_estimate_with_bootstrap_weights(weights)))
    expect_true(is.na(fixture$inf$compute_estimate_with_bootstrap_weights(0 * weights)))
    private <- fixture$inf$.__enclos_env__$private
    expect_null(private$cached_mod)
    expect_true(is.na(private$cached_values$beta_hat_T))
    expect_true(is.na(private$cached_values$s_beta_hat_T))
    weights <- weights + rep(c(2, 0, 1, 3), 8)
    expected <- fractional_weighted_coefficient_reference(fixture, weights)
    actual <- fixture$inf$compute_estimate_with_bootstrap_weights(1e-200 * weights, estimate_only = TRUE)
    expect_equal(actual, expected$coefficient, tolerance = 1e-6)
    expect_lt(expected$loss(private$cached_mod$b) - expected$loss(expected$coefficients), 1e-8)
  }
})
