library(testthat)
library(EDI)

test_that("suite preserves null defaults and suppresses replicate progress", {
  calls <- list()
  inf <- list(capabilities = function() c("wald", "parametric_likelihood_bootstrap",
                                         "nonparametric_bootstrap"),
    compute_asymp_two_sided_pval = function(delta = 1) {
      calls$wald <<- delta
      .25
    },
    compute_param_bootstrap_pval = function(delta, show_progress = TRUE) {
      calls$direct <<- list(delta = delta, progress = show_progress)
      .4
    },
    get_supported_bootstrap_ci_types = function() "percentile",
    get_supported_bootstrap_pval_types = function() "studentized",
    compute_bootstrap_confidence_interval = function(alpha, type, show_progress = TRUE) {
      calls$ci <<- list(alpha = alpha, type = type, progress = show_progress)
      c(-2, 3)
    },
    compute_bootstrap_two_sided_pval = function(delta = 1, type, show_progress = TRUE) {
      calls$pv <<- list(delta = delta, type = type, progress = show_progress)
      .15
    })
  expect_equal(EDI:::run_all_inference_call_pval_for_method(inf, "wald"),
               list(pval = .25, method = "wald"))
  expect_identical(calls$wald, 1)
  expect_equal(EDI:::run_all_inference_call_pval_for_method(inf, "param_boot_direct"),
               list(pval = .4, method = "param_boot_direct"))
  expect_identical(calls$direct, list(delta = 0, progress = FALSE))
  expect_equal(EDI:::run_all_inference_call_ci_for_method(inf, .1, "bootstrap", "percentile"),
               list(lower = -2, upper = 3, method = "bootstrap"))
  expect_identical(calls$ci, list(alpha = .1, type = "percentile", progress = FALSE))
  expect_equal(EDI:::run_all_inference_call_pval_for_method(inf, "bootstrap", "studentized"),
               list(pval = .15, method = "bootstrap"))
  expect_identical(calls$pv, list(delta = 1, type = "studentized", progress = FALSE))
  before <- calls
  expect_equal(EDI:::run_all_inference_call_ci_for_method(inf, .1, "bootstrap", "studentized"),
               list(lower = NA_real_, upper = NA_real_, method = "bootstrap"))
  expect_equal(EDI:::run_all_inference_call_pval_for_method(inf, "bootstrap", "percentile"),
               list(pval = NA_real_, method = "bootstrap"))
  expect_identical(calls, before)
})

test_that("suite retains attempted methods and original failure diagnostics", {
  inf <- list(capabilities = function() "wald",
    compute_asymp_confidence_interval = function(alpha) stop("interval fixture failed"),
    compute_asymp_two_sided_pval = function(delta = 1) stop("p-value fixture failed"))
  expect_equal(EDI:::run_all_inference_call_ci_for_method(inf, .05, "wald"),
    list(lower = NA_real_, upper = NA_real_, method = "wald", error = "interval fixture failed"))
  expect_equal(EDI:::run_all_inference_call_pval_for_method(inf, "wald"),
    list(pval = NA_real_, method = "wald", error = "p-value fixture failed"))
  for (interval in list(c(NA_real_, 1), c(-Inf, Inf), c(-1, 0, 1))) {
    inf$compute_asymp_confidence_interval <- function(alpha) interval
    expect_equal(EDI:::run_all_inference_call_ci_for_method(inf, .05, "wald"),
      list(lower = NA_real_, upper = NA_real_, method = "wald", error = "returned a non-finite interval"))
  }
  for (value in list(NA_real_, Inf, c(.1, .2))) {
    inf$compute_asymp_two_sided_pval <- function(delta = 1) value
    expect_equal(EDI:::run_all_inference_call_pval_for_method(inf, "wald"),
      list(pval = NA_real_, method = "wald", error = "returned a non-finite p-value"))
  }
  inf$compute_asymp_two_sided_pval <- function(delta = 1) NULL
  inf$compute_asymp_confidence_interval <- function(alpha) NULL
  expect_equal(EDI:::run_all_inference_call_pval_for_method(inf, "wald"),
    list(pval = NA_real_, method = "wald", error = NULL))
  expect_equal(EDI:::run_all_inference_call_ci_for_method(inf, .05, "wald"),
    list(lower = NA_real_, upper = NA_real_, method = "wald", error = NULL))
})

test_that("unsupported suite requests never call alternative procedures", {
  inf <- list(capabilities = function() c("likelihood_tests", "randomization_test"),
    get_supported_testing_types = function() c("score", "lik_ratio"),
    supports_rand_pval_for_incidence = function() FALSE,
    compute_rand_two_sided_pval = function(...) stop("must not be called"),
    compute_score_two_sided_pval = function(...) stop("must not cascade"))
  for (method in c("unrecognized", "wald", "lik_ratio_bartlett_exact", "lik_ratio_bartlett_approx")) {
    expect_equal(EDI:::run_all_inference_call_ci_for_method(inf, .05, method),
      list(lower = NA_real_, upper = NA_real_, method = NA_character_))
    expect_equal(EDI:::run_all_inference_call_pval_for_method(inf, method),
      list(pval = NA_real_, method = NA_character_))
  }
  expect_equal(EDI:::run_all_inference_call_pval_for_method(inf, "rand"),
    list(pval = NA_real_, method = NA_character_))
  inf$get_supported_testing_types <- function() stop("unavailable type metadata")
  expect_equal(EDI:::run_all_inference_call_pval_for_method(inf, "lik_ratio_bartlett_exact"),
    list(pval = NA_real_, method = NA_character_))
  expect_equal(EDI:::run_all_inference_call_ci_for_method(inf, .05, "lik_ratio_bartlett_exact"),
    list(lower = NA_real_, upper = NA_real_, method = NA_character_))
})
