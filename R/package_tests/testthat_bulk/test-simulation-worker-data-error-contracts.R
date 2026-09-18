library(testthat)
library(EDI)

# Invoke the actual protected worker at its data-validation boundary. No
# assignments, statistical fits, cache files, or parallel workers are needed.
data_error_worker <- function(generator, fatal = FALSE) {
  sim <- SimulationFramework$new(
    response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
    inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
    inference_types_and_params = list(asymp_pval = list()),
    n = 8L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L,
    results_filename = tempfile(fileext = ".csv"), verbose = FALSE)
  state <- list(response_type = "continuous", cond_exp_func_model = "linear",
    n = 8L, p = 1L, betaT = .25, stop_on_error = fatal,
    custom_replication_data_generator = generator)
  sim$.__enclos_env__$private$.run_single_replication_in_worker(3L, state)
}

test_that("invalid custom data preserves validation errors in both worker stopping modes", {
  cases <- list(
    list(value = 1, message = "must return a list"),
    list(value = list(X = data.frame(x = 1:8)), message = "must return 'X' and 'y_linear_model'"),
    list(value = list(X = data.frame(x = 1:7), y_linear_model = 1:8),
      message = "X with 7 rows; expected 8"),
    list(value = list(X = matrix(1:8, ncol = 1), y_linear_model = 1:7),
      message = "y_linear_model of length 7; expected 8"))
  for (case in cases) for (fatal in c(FALSE, TRUE)) {
    out <- data_error_worker(function(...) case$value, fatal)
    expect_null(out$results_dt)
    expect_identical(out$skipped_count, 0L)
    expect_length(out$errors, 1L)
    err <- out$errors[[1L]]
    expect_identical(err$stage, "data_generation")
    expect_identical(err$rep, 3L)
    expect_match(err$error_message, case$message, fixed = TRUE)
    if (fatal) expect_identical(out$fatal_error, err) else expect_null(out$fatal_error)
  }
})

test_that("fatal generator errors retain original condition class and simulation cell metadata", {
  condition <- structure(list(message = "fixture generator refused data", call = NULL),
    class = c("fixture_data_error", "error", "condition"))
  out <- data_error_worker(function(...) stop(condition), TRUE)
  err <- out$fatal_error
  expect_identical(err$error_message, condition$message)
  expect_identical(err$metadata$condition_class, class(condition))
  expect_identical(err$response_type, "continuous")
  expect_identical(err$cond_exp_func_model, "linear")
  expect_identical(err$n, 8L)
  expect_identical(err$p, 1L)
  expect_identical(err$betaT, .25)
  expect_true(is.na(err$design))
  expect_true(is.na(err$inference))
  expect_true(is.na(err$inference_type))
  expect_identical(out$errors, list(err))
  expect_true(nzchar(err$timestamp))
})
