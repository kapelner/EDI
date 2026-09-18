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
  expect_equal(ci_summary$MSE, 2 / 3)
  expect_equal(ci_summary$n_est, 3)
  expect_equal(ci_summary$coverage, 2 / 3)
  expect_equal(ci_summary$n_cov, 3)
  expect_equal(ci_summary$ci_length, mean(c(2, 1, 0.5)))
  expect_equal(ci_summary$coverage_pval, binom.test(2, 3, p = 0.95)$p.value)
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
