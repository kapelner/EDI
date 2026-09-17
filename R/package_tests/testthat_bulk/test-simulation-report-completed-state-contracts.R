library(testthat)
library(EDI)

# Build a framework, then install a completed worker state without running
# simulations. This isolates report construction from statistical fitting.
completed_report_fixture <- function(rows = list(), combos = list(), errors = list()) {
  sim <- SimulationFramework$new(
    response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
    inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
    inference_types_and_params = list(asymp_ci = list(), asymp_pval = list()),
    n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
    results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
    verbose = FALSE, turn_off_asserts_for_speed = FALSE)
  p <- sim$.__enclos_env__$private
  p$has_run <- TRUE
  p$raw_results <- rows
  p$results_idx <- length(rows)
  p$valid_combos <- combos
  p$error_log <- errors
  p$alpha <- .1
  p$inf_types <- c("asymp_ci", "asymp_pval")
  p$design_labels <- c("balanced", "unobserved")
  p$design_params <- list(list(prob_T = .5, strata_cols = c("site", "age")), list())
  p$inference_labels <- "mean"
  p$inference_constructor_params <- list(list(covariate_formula = ~ x))
  p$inference_type_params <- list(asymp_ci = list(), asymp_pval = list(delta = 0))
  sim
}

completed_report_combo <- function(design = "balanced", type = "asymp_pval", rep = NULL) {
  combo <- list(response_type = "continuous", cond_exp_func_model = "linear", n = 20L,
    p = 1L, betaT = 0, design = design, inference = "mean", inference_type = type,
    simulation_mode = "standard")
  if (!is.null(rep)) combo$rep <- rep
  combo
}

test_that("completed frameworks with no valid cells retain errors and an empty typed result table", {
  errors <- list(list(stage = "design", message = "incompatible configuration", rep = 1L))
  report <- SimulationFrameworkReport$new(completed_report_fixture(errors = errors))
  raw <- report$get_results()
  expect_s3_class(raw, "data.table")
  expect_equal(nrow(raw), 0L)
  expect_identical(typeof(raw$rep), "integer")
  expect_identical(typeof(raw$estimate), "double")
  expect_identical(typeof(raw$inference), "character")
  expect_identical(report$get_errors(), errors)
  expect_message(expect_null(report$summarize()), "No results")
})

test_that("completed frameworks with no successful results report every valid cell without invented observations", {
  combos <- list(completed_report_combo(type = "asymp_ci"), completed_report_combo(type = "asymp_pval"))
  report <- SimulationFrameworkReport$new(completed_report_fixture(combos = combos))
  summary <- report$summarize()
  expect_equal(nrow(summary), 2L)
  expect_setequal(summary$inference_type, c("asymp_ci", "asymp_pval"))
  expect_equal(summary$n_est, c(0L, 0L))
  expect_equal(summary$n_cov, c(0L, 0L))
  expect_equal(summary$n_pow, c(0L, 0L))
  expect_equal(summary$n_size, c(0L, 0L))
  for (col in c("MSE", "coverage", "ci_length", "coverage_pval", "power", "size", "size_pval")) {
    expect_true(col %in% names(summary))
    expect_true(all(is.na(summary[[col]])))
  }
  expect_output(report$print(), "Summary \\(alpha = 0.1\\)")
})

test_that("completed framework reports preserve unobserved cells and annotate supplied parameters", {
  combos <- list(completed_report_combo(rep = 1L), completed_report_combo(rep = 2L),
    completed_report_combo("unobserved", "asymp_ci"))
  rows <- lapply(1:2, function(rep) c(completed_report_combo(rep = rep),
    list(estimate = c(1, 3)[rep], ci_lo = NA_real_, ci_hi = NA_real_,
      pval = c(.08, .2)[rep], true_estimand = 2)))
  sim <- completed_report_fixture(rows, combos)
  report <- SimulationFrameworkReport$new(sim)
  summary <- report$summarize()
  observed <- summary[summary$design == "balanced", ]
  missing <- summary[summary$design == "unobserved", ]
  expect_equal(nrow(summary), 2L) # replicate IDs do not duplicate reference cells
  expect_equal(observed$MSE, 1)
  expect_equal(observed$n_est, 2L)
  expect_equal(observed$size, .5) # framework alpha .1 is inherited
  expect_equal(observed$n_size, 2L)
  expect_identical(observed$design_params, 'prob_T=0.5, strata_cols=c("site", "age")')
  expect_identical(observed$inference_params, "covariate_formula=~x")
  expect_identical(observed$inference_type_params, "asymp_pval(delta=0)")
  expect_identical(missing$design_params, "")
  expect_identical(missing$inference_type_params, "")
  expect_equal(missing$n_est, 0L)
  expect_equal(missing$n_cov, 0L)
  expect_equal(missing$n_size, 0L)
  expect_true(is.na(missing$coverage))
  override <- SimulationFrameworkReport$new(sim, alpha = .05)$summarize()
  expect_equal(override$size[override$design == "balanced"], 0)
})
