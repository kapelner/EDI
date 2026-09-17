library(testthat)
library(EDI)

# The migration goldens exercise a mixed KK fit. These unit fixtures isolate
# inversion from quantile fitting so each reservoir/matching and bracket branch
# has a deterministic statistical reference rather than another implementation.
quantile_ci_coverage_fixture <- function(m = 4L, nRT = 0L, nRC = 0L,
                                         estimate = 1.25, asym_ci = c(-3, 6),
                                         se = 1, asym_error = FALSE,
                                         estimate_error = FALSE) {
  component <- EDI:::InferenceExtQuantileRandCI
  public <- component$public
  public$compute_estimate <- function() {
    if (private$fixture$estimate_error) stop("fit failed")
    private$fixture$estimate
  }
  public$compute_asymp_confidence_interval <- function(alpha) {
    if (private$fixture$asym_error) stop("variance unavailable")
    private$fixture$asym_ci
  }
  private <- component$private
  private$fixture <- list(estimate = estimate, asym_ci = asym_ci,
                         asym_error = asym_error, estimate_error = estimate_error)
  private$cached_values <- list(KKstats = list(m = m, nRT = nRT, nRC = nRC),
                               s_beta_hat_T = se)
  private$compute_rand_pval_matched_pairs <- function(delta) {
    if (private$cached_values$KKstats$m == 0L) stop("matched provider must not be called")
    exp(-abs(delta - private$fixture$estimate))
  }
  private$compute_rand_pval_reservoir <- function(delta) {
    stats <- private$cached_values$KKstats
    if (stats$nRT == 0L || stats$nRC == 0L) stop("reservoir provider must not be called")
    exp(-abs(delta - private$fixture$estimate))
  }
  R6::R6Class("QuantileCICoverageFixture", parent_env = asNamespace("EDI"),
              public = public, private = private)$new()
}

test_that("quantile CI inverts a single available randomization component", {
  for (layout in list(c(4L, 0L, 0L), c(0L, 5L, 6L), c(4L, 3L, 0L))) {
    inf <- quantile_ci_coverage_fixture(layout[1], layout[2], layout[3])
    ci <- inf$compute_rand_confidence_interval(alpha = 0.2, r = 31L,
                                              pval_epsilon = 1e-7)
    expect_equal(ci, 1.25 + c(-1, 1) * -log(0.2), tolerance = 2e-6)
    expect_identical(inf$.__enclos_env__$private$nsim_rand, 31L)
  }
})

test_that("quantile CI combines both strata using the Fisher rejection boundary", {
  inf <- quantile_ci_coverage_fixture(m = 4L, nRT = 5L, nRC = 6L)
  # With both p-values exp(-distance), Fisher's statistic is 4*distance.
  radius <- stats::qchisq(0.2, df = 4, lower.tail = FALSE) / 4
  ci <- inf$compute_rand_confidence_interval(alpha = 0.2, r = 31L,
                                            pval_epsilon = 1e-7)
  expect_equal(ci, 1.25 + c(-radius, radius), tolerance = 2e-6)
})

test_that("quantile CI falls back when asymptotic limits or variance are unavailable", {
  fixtures <- list(
    quantile_ci_coverage_fixture(asym_error = TRUE, se = 0.5),
    quantile_ci_coverage_fixture(asym_ci = c(NA_real_, NA_real_), se = NULL),
    quantile_ci_coverage_fixture(asym_ci = NULL, se = NA_real_),
    quantile_ci_coverage_fixture(asym_ci = NULL, se = 0)
  )
  for (inf in fixtures) {
    expect_equal(inf$compute_rand_confidence_interval(alpha = 0.2, r = 19L,
                                                     pval_epsilon = 1e-7),
                 1.25 + c(-1, 1) * -log(0.2), tolerance = 2e-6)
  }
})

test_that("quantile CI represents failed or nonfinite estimates as missing limits", {
  for (inf in list(quantile_ci_coverage_fixture(estimate = NA_real_),
                   quantile_ci_coverage_fixture(estimate = Inf),
                   quantile_ci_coverage_fixture(estimate_error = TRUE))) {
    expect_identical(inf$compute_rand_confidence_interval(r = 19L),
                     c(NA_real_, NA_real_))
  }
})

test_that("quantile CI rejects invalid simulation and tolerance arguments", {
  skip_if_not(EDI:::should_run_asserts())
  inf <- quantile_ci_coverage_fixture()
  expect_error(inf$compute_rand_confidence_interval(alpha = 0), "alpha")
  expect_error(inf$compute_rand_confidence_interval(r = 0L), "r")
  expect_error(inf$compute_rand_confidence_interval(r = 1.5), "r")
  expect_error(inf$compute_rand_confidence_interval(pval_epsilon = 0), "pval_epsilon")
})

test_that("a completed KK quantile fit supplies finite randomization limits", {
  skip_if_not_installed("quantreg")
  withr::local_seed(321)
  des <- DesignSeqOneByOneKK14$new(n = 24L, response_type = "continuous", verbose = FALSE)
  for (i in seq_len(24L)) {
    w <- des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1L)))
    des$add_one_subject_response(i, 0.5 * w + rnorm(1L))
  }
  inf <- InferenceContinKKQuantileRegrIVWC$new(des, verbose = FALSE)
  estimate <- inf$compute_estimate()
  expect_true(is.finite(estimate))
  ci <- inf$compute_rand_confidence_interval(alpha = 0.4, r = 19L,
                                            pval_epsilon = 0.05, show_progress = FALSE)
  expect_length(ci, 2L)
  expect_true(all(is.finite(ci)))
  expect_lte(ci[1L], estimate)
  expect_gte(ci[2L], estimate)
})
