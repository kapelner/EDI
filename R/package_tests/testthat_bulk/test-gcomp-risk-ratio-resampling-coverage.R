library(testthat)
library(EDI)

gcomp_rr_coverage_fit <- function(draw_factors = NULL) {
  des <- DesignFixedBernoulli$new(n = 20L, response_type = "incidence", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = seq_len(20L)))
  des$overwrite_all_subject_assignments(rep(c(0L, 1L), each = 10L))
  des$add_all_subject_responses(c(rep(1, 4), rep(0, 6), rep(1, 7), rep(0, 3)))
  generator <- InferenceIncidGCompRiskRatio
  if (!is.null(draw_factors)) {
    generator <- R6::R6Class("InferenceIncidGCompRiskRatio", inherit = InferenceIncidGCompRiskRatio,
      parent_env = asNamespace("EDI"),
      lock_objects = FALSE,
      public = list(
        approximate_bootstrap_distribution_beta_hat_T = function(...) {
          private$coverage_draw_factors * self$compute_estimate()
        },
        approximate_bayesian_bootstrap_distribution_beta_hat_T = function(...) {
          private$coverage_draw_factors * self$compute_estimate()
        }
      ), private = list(coverage_draw_factors = draw_factors))
  }
  generator$new(des, model_formula = ~ 1, verbose = FALSE)
}

test_that("treatment-only gcomp risk ratio agrees with empirical arm risks", {
  inf <- gcomp_rr_coverage_fit()
  expect_equal(inf$compute_estimate(estimate_only = TRUE), 0.7 / 0.4, tolerance = 1e-6)
  expect_equal(inf$compute_estimate(), 0.7 / 0.4, tolerance = 1e-6)
  ci <- inf$compute_asymp_confidence_interval(alpha = 0.2)
  expect_true(all(is.finite(ci) & ci > 0))
  expect_equal(prod(ci), (0.7 / 0.4)^2, tolerance = 1e-5)
  expect_equal(inf$compute_asymp_two_sided_pval(delta = 0.7 / 0.4), 1, tolerance = 1e-5)
  expect_error(inf$compute_asymp_two_sided_pval(delta = 0), "strictly positive")
})

test_that("risk ratio basic bootstrap limits use multiplicative reflection", {
  inf <- gcomp_rr_coverage_fit(exp(c(-0.4, -0.2, 0, 0.2, 0.4)))
  est <- inf$compute_estimate()
  ci <- inf$compute_bootstrap_confidence_interval(alpha = 0.2, B = 5L,
                                                 type = "BASIC", show_progress = FALSE)
  expect_equal(unname(ci), est * exp(c(-0.4, 0.4)), tolerance = 1e-10)
  expect_identical(names(ci), c("10%", "90%"))
  expect_equal(prod(ci), est^2, tolerance = 1e-10)
})

test_that("risk ratio Bayesian bootstrap basic and Wald limits stay on log scale", {
  for (type in c("basic", "wald")) {
    inf <- gcomp_rr_coverage_fit(exp(c(-0.4, -0.2, 0, 0.2, 0.4)))
    est <- inf$compute_estimate()
    ci <- inf$compute_bayesian_bootstrap_confidence_interval(alpha = 0.2, B = 5L,
                                                           type = type, show_progress = FALSE)
    radius <- if (type == "basic") 0.4 else stats::qnorm(0.9) * sqrt(0.1)
    expect_equal(unname(ci), est * exp(c(-radius, radius)), tolerance = 1e-10)
    expect_equal(prod(ci), est^2, tolerance = 1e-10)
  }
})

test_that("risk ratio resampling removes invalid draws only when requested", {
  for (bayesian in c(FALSE, TRUE)) {
    inf <- gcomp_rr_coverage_fit(c(exp(c(-0.4, -0.2, 0, 0.2, 0.4)),
                                  0, -1, NA_real_, Inf))
    est <- inf$compute_estimate()
    if (bayesian) {
      compute_ci <- inf$compute_bayesian_bootstrap_confidence_interval
    } else {
      compute_ci <- inf$compute_bootstrap_confidence_interval
    }
    expect_true(all(is.na(compute_ci(alpha = 0.2, B = 9L, type = "basic",
                                     na.rm = FALSE, show_progress = FALSE))))
    expect_equal(unname(compute_ci(alpha = 0.2, B = 9L, type = "basic",
                                   na.rm = TRUE, show_progress = FALSE)),
                 est * exp(c(-0.4, 0.4)), tolerance = 1e-10)
    expect_true(all(is.na(compute_ci(B = 9L, type = "basic", na.rm = TRUE,
                                     min_number_usable_samples = 6L, show_progress = FALSE))))
  }
})

test_that("risk ratio jackknife limits agree with deleting one subject from arm risks", {
  inf <- gcomp_rr_coverage_fit()
  # Four control events, six control nonevents, seven treatment events,
  # and three treatment nonevents yield these four leave-one-out ratios.
  log_jack <- log(rep(c(0.7 / (3 / 9), 0.7 / (4 / 9), (6 / 9) / 0.4,
                         (7 / 9) / 0.4), times = c(4L, 6L, 7L, 3L)))
  se <- sqrt(19 / 20 * sum((log_jack - mean(log_jack))^2))
  est <- 0.7 / 0.4
  ci <- inf$compute_jackknife_wald_confidence_interval(alpha = 0.2, unit = "observation")
  expect_equal(unname(ci), est * exp(c(-1, 1) * stats::qnorm(0.9) * se), tolerance = 1e-5)
  expect_equal(inf$compute_jackknife_wald_two_sided_pval(unit = "observation"),
               2 * stats::pnorm(-abs(log(est) / se)), tolerance = 1e-5)
  expect_true(is.na(inf$compute_jackknife_wald_two_sided_pval(delta = 0, unit = "observation")))
})
