library(testthat)
library(EDI)

count_composite_weighted_fixture <- function(generator) {
  y <- c(1, 3, 0, 2, 4, 2, 2, 4, 3, 6, 1, 5)
  des <- DesignFixedBernoulli$new(n = length(y), response_type = "count", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = seq_along(y)))
  des$overwrite_all_subject_assignments(rep(c(0, 1), each = 6))
  des$add_all_subject_responses(y)
  inf <- generator$new(des, model_formula = ~ 1, verbose = FALSE)
  private <- inf$.__enclos_env__$private
  private$current_bayesian_bootstrap_context <- private$build_bayesian_bootstrap_context()
  list(inf = inf, y = y)
}

count_composite_arm_se_reference <- function(y, weights, robust) {
  control_mean <- weighted.mean(y[1:6], weights[1:6])
  treat_mean <- weighted.mean(y[7:12], weights[7:12])
  control_mass <- sum(weights[1:6]) * control_mean
  treat_mass <- sum(weights[7:12]) * treat_mean
  control_ss <- sum(weights[1:6] * (y[1:6] - control_mean)^2)
  treat_ss <- sum(weights[7:12] * (y[7:12] - treat_mean)^2)
  if (robust) {
    # Independent arm-mean HC0 delta-method variances add on the log-ratio scale.
    sqrt(control_ss / control_mass^2 + treat_ss / treat_mass^2)
  } else {
    dispersion <- (control_ss / control_mean + treat_ss / treat_mean) / (length(y) - 2)
    sqrt(dispersion * (1 / control_mass + 1 / treat_mass))
  }
}

test_that("weighted quasi and robust Poisson estimates equal weighted arm log ratios", {
  weights <- c(1, 2, 3, 1, 2, 1, 2, 1, 1, 3, 2, 1)
  for (generator in list(InferenceCountQuasiPoisson, InferenceCountRobustPoisson)) {
    fixture <- count_composite_weighted_fixture(generator)
    inf <- fixture$inf
    expected <- log(weighted.mean(fixture$y[7:12], weights[7:12]) /
                      weighted.mean(fixture$y[1:6], weights[1:6]))
    robust <- identical(generator, InferenceCountRobustPoisson)
    expect_equal(inf$compute_estimate_with_bootstrap_weights(weights), expected, tolerance = 1e-7)
    expect_equal(inf$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T,
                 count_composite_arm_se_reference(fixture$y, weights, robust), tolerance = 1e-7)
    expect_equal(inf$compute_estimate_with_bootstrap_weights(5 * weights), expected, tolerance = 1e-7)
    expect_equal(inf$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T,
                 count_composite_arm_se_reference(fixture$y, 5 * weights, robust), tolerance = 1e-7)
    # A weighted refit must not leak into the ordinary estimate.
    expect_equal(unname(inf$compute_estimate(estimate_only = TRUE)),
                 log(mean(fixture$y[7:12]) / mean(fixture$y[1:6])), tolerance = 1e-7)
  }
})

test_that("weighted count re-estimation omits zero-weight subjects from each risk set", {
  weights <- c(1, 0, 2, 3, 1, 0, 1, 2, 0, 2, 1, 3)
  for (generator in list(InferenceCountQuasiPoisson, InferenceCountRobustPoisson)) {
    fixture <- count_composite_weighted_fixture(generator)
    expected <- log(weighted.mean(fixture$y[7:12], weights[7:12]) /
                      weighted.mean(fixture$y[1:6], weights[1:6]))
    expect_equal(fixture$inf$compute_estimate_with_bootstrap_weights(weights), expected, tolerance = 1e-7)
  }
})

test_that("estimate-only weighted count fits retain the estimate and clear uncertainty", {
  for (generator in list(InferenceCountQuasiPoisson, InferenceCountRobustPoisson)) {
    fixture <- count_composite_weighted_fixture(generator)
    inf <- fixture$inf
    original <- inf$compute_estimate()
    expect_true(is.finite(inf$.__enclos_env__$private$cached_values$s_beta_hat_T))
    expect_equal(inf$compute_estimate_with_bootstrap_weights(rep(3, 12), estimate_only = TRUE),
                 as.numeric(original), tolerance = 1e-7)
    expect_true(is.na(inf$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T))
    expect_true(is.finite(inf$.__enclos_env__$private$cached_values$s_beta_hat_T))   # the ordinary SE is untouched
  }
})
