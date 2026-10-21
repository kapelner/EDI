library(testthat)
library(EDI)

simulation_calibration_report <- function(rows, alpha = 0.05) {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(rows, path)
  SimulationFrameworkReport$new(path, alpha = alpha)
}

simulation_calibration_rows <- function(type, beta = 0, truth = 0) {
  data.frame(rep = 1:5, response_type = "continuous", cond_exp_func_model = "linear",
             n = 20L, p = 1L, betaT = beta, design = "Bernoulli", inference = "mean",
             inference_type = type, estimate = c(truth, truth + 1, NA, Inf, truth - 1),
             ci_lo = NA_real_, ci_hi = NA_real_, pval = NA_real_, true_estimand = truth)
}

simulation_calibration_report_from_run_state <- function(rows, errors, nrep) {
  sim <- SimulationFramework$new(
    response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
    inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
    inference_types_and_params = list(asymp_ci = list()),
    n = 20L, p = 1L, Nrep_W = nrep, Nrep_Y_w = 1L, betaT = 0,
    results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
    verbose = FALSE, turn_off_asserts_for_speed = FALSE, stop_on_error = FALSE
  )
  private <- sim$.__enclos_env__$private
  rows$design <- private$design_labels[[1L]]
  rows$inference <- private$inference_labels[[1L]]
  combo_cols <- c("response_type", "cond_exp_func_model", "n", "p", "betaT",
                  "design", "inference", "inference_type")
  private$has_run <- TRUE
  private$raw_results <- list(data.table::as.data.table(rows))
  private$results_idx <- 1L
  private$error_log <- errors
  private$valid_combos <- list(as.list(rows[1L, combo_cols, drop = FALSE]))
  private$inf_types <- unique(rows$inference_type)
  list(report = SimulationFrameworkReport$new(sim), private = private)
}

test_that("simulation calibration excludes nonfinite estimates and intervals", {
  ci <- simulation_calibration_rows("asymp_ci")
  ci$ci_lo <- c(-1, 1, NA, -Inf, -0.5)
  ci$ci_hi <- c(1, 2, 1, Inf, 0)
  pv <- simulation_calibration_rows("asymp_pval")
  pv$pval <- c(0.01, 0.1, NA, Inf, 0.05)
  report <- simulation_calibration_report(rbind(ci, pv))
  sm <- report$summarize()
  ci_summary <- sm[sm$inference_type == "asymp_ci", ]
  pv_summary <- sm[sm$inference_type == "asymp_pval", ]
  raw_results <- report$get_results()
  ci_rows <- raw_results[raw_results$inference_type == "asymp_ci", ]
  interval_finite <- is.finite(ci_rows$ci_lo) & is.finite(ci_rows$ci_hi)
  interval_covered <- interval_finite &
    ci_rows$ci_lo <= ci_rows$true_estimand & ci_rows$true_estimand <= ci_rows$ci_hi
  attempted_reps <- nrow(ci_rows)
  invalid_intervals <- sum(!interval_finite)
  covered_reps <- sum(interval_covered)
  finite_only_coverage <- covered_reps / sum(interval_finite)
  # This all-attempts rate treats every invalid interval as noncoverage; it is
  # distinct from SimulationFrameworkReport's finite-interval calibration.
  all_attempts_coverage <- covered_reps / attempted_reps
  expect_identical(sort(as.integer(ci_rows$rep)), 1:5)
  expect_identical(attempted_reps, 5L)
  expect_identical(invalid_intervals, 2L)
  expect_identical(covered_reps, 2L)
  expect_equal(finite_only_coverage, 2 / 3)
  expect_equal(all_attempts_coverage, 2 / 5)
  expect_equal(ci_summary$MSE, 2 / 3)
  expect_equal(ci_summary$n_est, 3)
  expect_equal(ci_summary$coverage, finite_only_coverage)
  expect_equal(ci_summary$n_cov, sum(interval_finite))
  expect_equal(ci_summary$ci_length, mean(c(2, 1, 0.5)))
  expect_equal(ci_summary$coverage_pval,
               binom.test(covered_reps, sum(interval_finite), p = 0.95)$p.value)
  expect_equal(pv_summary$size, 1 / 3)
  expect_equal(pv_summary$n_size, 3)
  expect_equal(pv_summary$size_pval, binom.test(1, 3, p = 0.05)$p.value)
  expect_true(is.na(pv_summary$power))
  expect_equal(pv_summary$n_pow, 0)
  expect_true(is.na(pv_summary$coverage))
  expect_equal(pv_summary$n_cov, 0)
  expect_identical(report$get_errors(), list())
  expect_equal(nrow(report$get_results()), 10L)
})

test_that("attempt denominator includes an errored rep and a rep with no interval row", {
  ci <- simulation_calibration_rows("asymp_ci")[1:3, ]
  ci$ci_lo <- c(-1, -2, NA_real_)
  ci$ci_hi <- c(1, 2, 1)
  error <- list(
    list(rep = 4L, stage = "inference", inference_type = "asymp_ci",
         error_message = "synthetic failed interval attempt")
  )
  fixture <- simulation_calibration_report_from_run_state(ci, error, nrep = 5L)
  report <- fixture$report
  sim_private <- fixture$private

  # SimulationFramework sets Nrep = Nrep_W * Nrep_Y_w; this expected roster
  # is independent of the result rows that happened to be recorded.
  expected_attempt_reps <- seq_len(sim_private$Nrep_W * sim_private$Nrep_Y_w)
  expect_identical(as.integer(length(expected_attempt_reps)), sim_private$Nrep)
  expect_identical(expected_attempt_reps, 1:5)

  raw_ci <- report$get_results()
  expect_identical(sort(as.integer(raw_ci$rep)), 1:3)
  finite_interval <- is.finite(raw_ci$ci_lo) & is.finite(raw_ci$ci_hi)
  covered <- finite_interval &
    raw_ci$ci_lo <= raw_ci$true_estimand & raw_ci$true_estimand <= raw_ci$ci_hi
  missing_result_reps <- setdiff(expected_attempt_reps, raw_ci$rep)
  errored_reps <- vapply(report$get_errors(), `[[`, integer(1), "rep")
  unclassified_missing_reps <- setdiff(missing_result_reps, errored_reps)
  all_attempt_coverage <- sum(covered) / length(expected_attempt_reps)

  expect_identical(sort(missing_result_reps), c(4L, 5L))
  expect_identical(errored_reps, 4L)
  expect_identical(unclassified_missing_reps, 5L)
  expect_equal(sum(covered), 2L)
  expect_equal(all_attempt_coverage, 2 / 5)

  ci_summary <- report$summarize()[inference_type == "asymp_ci", ]
  expect_equal(ci_summary$n_cov, 2L)
  expect_equal(ci_summary$coverage, 1)
  # Report summaries cover recorded finite intervals only. Captured errors are
  # exposed separately, and a missing result is visible only against the
  # expected-rep roster above; neither changes the report's finite denominator.
})

test_that("custom simulation calibration uses the true estimand to identify the null", {
  custom_null <- simulation_calibration_rows("asymp_pval", beta = 3, truth = 0)
  custom_null$simulation_mode <- "custom"
  custom_null$pval <- c(0.01, 0.04, 0.06, NA, Inf)
  standard_alt <- custom_null
  standard_alt$simulation_mode <- "standard"
  custom_alt <- custom_null
  custom_alt$betaT <- 0
  custom_alt$true_estimand <- 2
  rows <- rbind(custom_null, standard_alt, custom_alt)
  summary <- simulation_calibration_report(rows)$summarize()
  null <- summary[summary$simulation_mode == "custom" & summary$betaT == 3, ]
  expect_equal(null$size, 2 / 3)
  expect_equal(null$n_size, 3)
  expect_equal(null$size_pval, binom.test(2, 3, p = 0.05)$p.value)
  expect_true(is.na(null$power))
  alt <- summary[summary$simulation_mode == "standard" | summary$betaT == 0, ]
  expect_equal(alt$power, rep(2 / 3, 2))
  expect_equal(alt$n_pow, rep(3L, 2))
  expect_true(all(is.na(alt$size)))
  expect_equal(alt$n_size, rep(0L, 2))
  expect_true(all(is.na(alt$size_pval)))
})

test_that("missing simulation modes retain legacy null classification", {
  for (beta in c(0, 1)) {
    rows <- simulation_calibration_rows("asymp_pval", beta = beta, truth = 2 - beta)
    rows$pval <- c(.01, .1, NA_real_, Inf, .05)
    legacy <- simulation_calibration_report(rows)$summarize()
    rows$simulation_mode <- NA_character_
    missing_mode <- simulation_calibration_report(rows)$summarize()
    for (metric in c("MSE", "n_est", "power", "n_pow", "size", "n_size", "size_pval")) {
      expect_equal(missing_mode[[metric]], legacy[[metric]], info = metric)
    }
  }
})

test_that("simulation summaries retain nonestimable cells without fabricating counts", {
  rows <- simulation_calibration_rows("asymp_pval", beta = 1)
  rows$estimate <- NA_real_
  summary <- simulation_calibration_report(rows)$summarize()
  expect_equal(summary$n_est, 0)
  expect_equal(summary$n_pow, 0)
  expect_true(is.na(summary$MSE))
  expect_true(is.na(summary$power))
  expect_true(is.na(summary$size))
})

test_that("compressed simulation reports preserve results and use the supplied alpha", {
  rows <- simulation_calibration_rows("asymp_pval")
  rows$pval <- c(0.09, 0.11, 0.1, NA, Inf)
  path <- tempfile(fileext = ".CSV.BZ2")
  on.exit(unlink(path), add = TRUE)
  con <- bzfile(path, "wt")
  tryCatch(write.csv(rows, con, row.names = FALSE), finally = close(con))
  report <- SimulationFrameworkReport$new(path, alpha = 0.1)
  expect_equal(as.data.frame(report$get_results()), rows)
  summary <- report$summarize()
  expect_equal(summary$size, 1 / 3)
  expect_equal(summary$n_size, 3)
  expect_equal(summary$size_pval, binom.test(1, 3, p = 0.1)$p.value)
  expect_identical(report$get_errors(), list())
})

test_that("empty simulation result files produce an empty report", {
  rows <- simulation_calibration_rows("asymp_pval")[FALSE, ]
  report <- simulation_calibration_report(rows)
  expect_equal(nrow(report$get_results()), 0)
  expect_message(expect_null(report$summarize()), "No results")
  expect_identical(report$get_errors(), list())
})

test_that("simulation result readers reject unsupported inputs", {
  expect_error(SimulationFrameworkReport$new(1), "must be a SimulationFramework")
  expect_error(SimulationFrameworkReport$new(tempfile(fileext = ".csv")), "File not found")
  path <- tempfile(fileext = ".txt")
  on.exit(unlink(path), add = TRUE)
  writeLines("existing but unsupported", path)
  expect_error(SimulationFrameworkReport$new(path), "Unsupported file format")
})
