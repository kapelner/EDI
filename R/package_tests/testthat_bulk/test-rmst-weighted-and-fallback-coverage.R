library(testthat)
library(EDI)

rmst_weighted_coverage_design <- function(dead = c(1, 0, 1, 1, 1, 0)) {
  y <- c(1, 3, 5, 2, 4, 6)
  des <- DesignFixedBernoulli$new(n = 6L, response_type = "survival", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = seq_len(6L)))
  des$overwrite_all_subject_assignments(c(0, 0, 0, 1, 1, 1))
  des$add_all_subject_responses(ifelse(dead == 1, y, NA_real_),
                               ifelse(dead == 0, y, NA_real_),
                               ifelse(dead == 0, Inf, NA_real_))
  des
}

rmst_weighted_coverage_fit <- function(dead = c(1, 0, 1, 1, 1, 0)) {
  inf <- InferenceSurvivalRestrictedMeanDiff$new(rmst_weighted_coverage_design(dead), verbose = FALSE)
  private <- inf$.__enclos_env__$private
  # Install the same valid weighting context used by Bayesian-bootstrap workers.
  private$current_bayesian_bootstrap_context <- private$build_bayesian_bootstrap_context()
  inf
}

test_that("weighted RMST integrates the censored Kaplan-Meier steps", {
  inf <- rmst_weighted_coverage_fit()
  # Control survival is 1 before t=1 and 3/4 until t=5: area=4.
  # Treatment survival is 1 before t=2, 1/2 until t=4, 1/4 until t=6: area=3.5.
  weights <- c(1, 2, 1, 2, 1, 1)
  expect_equal(inf$compute_estimate_with_bootstrap_weights(weights), -0.5, tolerance = 1e-12)
  expect_equal(inf$compute_estimate_with_bootstrap_weights(7 * weights), -0.5, tolerance = 1e-12)
  expect_equal(inf$compute_estimate(estimate_only = TRUE), -0.5, tolerance = 1e-12)
  expect_true(is.na(inf$.__enclos_env__$private$cached_values$s_beta_hat_T))
})

test_that("uncensored weighted RMST equals the weighted arm-mean contrast", {
  inf <- rmst_weighted_coverage_fit(rep(1, 6L))
  weights <- c(1, 2, 1, 2, 1, 1)
  # Complete event observation makes KM area equal the weighted arithmetic mean.
  expect_equal(inf$compute_estimate_with_bootstrap_weights(weights), 0.5, tolerance = 1e-12)
  expect_equal(inf$compute_estimate_with_bootstrap_weights(rep(1, 6L)), 1, tolerance = 1e-12)
})

test_that("weighted RMST returns missing when an arm has no positive weight", {
  for (weights in list(c(1, 1, 1, 0, 0, 0), c(0, 0, 0, 1, 1, 1))) {
    inf <- rmst_weighted_coverage_fit()
    expect_true(is.na(inf$compute_estimate_with_bootstrap_weights(weights)))
  }
})

test_that("RMST routes unavailable Greenwood uncertainty to bootstrap inference", {
  # All observations censored is a reachable zero-Greenwood-information case.
  generator <- R6::R6Class("InferenceSurvivalRestrictedMeanDiff",
    inherit = InferenceSurvivalRestrictedMeanDiff, parent_env = asNamespace("EDI"),
    lock_objects = FALSE,
    public = list(
      compute_bootstrap_confidence_interval = function(alpha = 0.05, ...) {
        private$fallback_calls$alpha <- alpha
        c(-2, 3)
      },
      compute_bootstrap_two_sided_pval = function(delta = 0, na.rm = FALSE, ...) {
        private$fallback_calls$delta <- delta
        private$fallback_calls$na.rm <- na.rm
        0.25
      }
    ), private = list(fallback_calls = list()))
  inf <- generator$new(rmst_weighted_coverage_design(rep(0, 6L)), verbose = FALSE)
  expect_warning(ci <- inf$compute_asymp_confidence_interval(alpha = 0.2), "Restricted mean SE")
  expect_identical(ci, c(-2, 3))
  expect_identical(inf$compute_asymp_two_sided_pval(), 0.25)
  expect_identical(inf$.__enclos_env__$private$fallback_calls,
                   list(alpha = 0.2, delta = 0, na.rm = TRUE))
})
