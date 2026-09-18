library(testthat)
library(EDI)

serial_observational_data <- function(n, p, rep) {
  list(X = data.frame(x = seq_len(n)), w = rep(c(0L, 1L), n / 2L),
    y = as.vector(rbind(c(-1, 0, 1, 2), c(1, 3, 4, 7) + .25 * rep)),
    true_estimand = 2)
}

serial_observational_sim <- function(filename, reps, include_ci, resume) {
  types <- list(asymp_pval = list(delta = 0))
  if (include_ci) types$asymp_ci <- list(alpha = .1)
  SimulationFramework$new(response_type = "continuous",
    design_classes_and_params = list(DesignFixedBernoulli),
    inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
    inference_types_and_params = types, n = 8L, p = 1L, betaT = 0,
    Nrep_W = reps, Nrep_Y_w = 1L, num_cores = 1L, seed = 1642L,
    custom_dgp = serial_observational_data, results_filename = filename,
    continue_from_last_result_row = resume, save_to_disk_every_n_rep = 1L,
    verbose = FALSE, turn_off_asserts_for_speed = TRUE)
}

test_that("legacy resume files inherit the configured simulation mode", {
  folder <- tempfile("edi_legacy_resume_")
  dir.create(folder)
  on.exit(unlink(folder, recursive = TRUE), add = TRUE)
  filename <- file.path(folder, "results.csv")
  rows <- data.table::data.table(response_type = "continuous",
    cond_exp_func_model = "linear", n = 8L, p = 1L, betaT = 0, rep = 1:2,
    design = "Bernoulli", inference = "mean", inference_type = "asymp_pval",
    estimate = c(3, 4), ci_lo = NA_real_, ci_hi = NA_real_,
    pval = c(.1, .2), true_estimand = 2)
  data.table::fwrite(rows, filename)
  sim <- serial_observational_sim(filename, 2L, FALSE, TRUE)
  loaded <- sim$.__enclos_env__$private$.load_existing_results()
  expect_equal(nrow(loaded), 2L)
  expect_identical(loaded$simulation_mode, rep("custom_dgp", 2L))
  expect_equal(loaded$estimate, rows$estimate)
  loaded[, simulation_mode := NULL]
  expect_equal(loaded, rows)
})

test_that("serial observational runs fill missing methods and reps on resume", {
  # Both formats use the real serial run path, native duplicate-key store,
  # statistical inference, incremental flush, and completed report collection.
  for (extension in c(".csv", ".csv.bz2")) {
    folder <- tempfile("edi_serial_resume_")
    dir.create(folder)
    on.exit(unlink(folder, recursive = TRUE), add = TRUE)
    filename <- file.path(folder, paste0("results", extension))
    set.seed(7351L)
    original_rng <- .Random.seed
    first <- serial_observational_sim(filename, 2L, FALSE, FALSE)
    first$run()
    expect_identical(.Random.seed, original_rng)
    original <- SimulationFrameworkReport$new(first)$get_results()
    expect_equal(nrow(original), 2L)
    expect_identical(sort(original$rep), 1:2)
    expect_identical(original$simulation_mode, rep("custom_dgp", 2L))
    expect_true(file.exists(filename))

    resumed <- serial_observational_sim(filename, 3L, TRUE, TRUE)
    resumed$run()
    expect_identical(.Random.seed, original_rng)
    report <- SimulationFrameworkReport$new(resumed)
    raw <- report$get_results()
    expect_length(report$get_errors(), 0L)
    expect_equal(nrow(raw), 6L)
    expect_equal(nrow(unique(raw[, c("rep", "inference_type"), with = FALSE])), 6L)
    expect_identical(sort(unique(raw$rep)), 1:3)
    expect_identical(sort(unique(raw$inference_type)), c("asymp_ci", "asymp_pval"))
    expect_equal(raw$true_estimand, rep(2, 6L))
    pvals <- raw[raw$inference_type == "asymp_pval"][order(rep)]
    cis <- raw[raw$inference_type == "asymp_ci"][order(rep)]
    expect_equal(pvals$estimate[1:2], original$estimate[order(original$rep)])
    expect_equal(pvals$pval[1:2], original$pval[order(original$rep)])

    # Welch's test is an independent implementation of the actual estimator,
    # arm-specific variance, degrees of freedom, p-value and interval.
    expected <- lapply(1:3, function(rep) {
      treated <- c(1, 3, 4, 7) + .25 * rep
      control <- c(-1, 0, 1, 2)
      test <- stats::t.test(treated, control, conf.level = .9)
      list(estimate = mean(treated) - mean(control), pval = test$p.value,
        ci = as.numeric(test$conf.int))
    })
    estimates <- vapply(expected, `[[`, numeric(1L), "estimate")
    pv <- vapply(expected, `[[`, numeric(1L), "pval")
    ci <- do.call(rbind, lapply(expected, `[[`, "ci"))
    expect_equal(pvals$estimate, estimates, tolerance = 1e-12)
    expect_equal(cis$estimate, estimates, tolerance = 1e-12)
    expect_equal(pvals$pval, pv, tolerance = 1e-12)
    expect_equal(cis$ci_lo, ci[, 1L], tolerance = 1e-12)
    expect_equal(cis$ci_hi, ci[, 2L], tolerance = 1e-12)
    expect_true(all(is.na(cis$pval)))
    expect_true(all(is.na(pvals$ci_lo) & is.na(pvals$ci_hi)))

    disk <- SimulationFrameworkReport$new(filename)$get_results()
    data.table::setorderv(raw, c("rep", "inference_type"))
    data.table::setorderv(disk, c("rep", "inference_type"))
    data.table::setcolorder(disk, names(raw))
    expect_equal(disk, raw, tolerance = 1e-12)
    summary <- report$summarize()
    expect_equal(summary$MSE, rep(mean((estimates - 2)^2), 2L), tolerance = 1e-12)
    expect_equal(summary$n_est, c(3L, 3L))
    ci_summary <- summary[summary$inference_type == "asymp_ci"]
    pv_summary <- summary[summary$inference_type == "asymp_pval"]
    expect_equal(ci_summary$n_cov, 3L)
    expect_equal(ci_summary$coverage, mean(ci[, 1L] <= 2 & ci[, 2L] >= 2))
    expect_equal(ci_summary$ci_length, mean(ci[, 2L] - ci[, 1L]), tolerance = 1e-12)
    expect_equal(pv_summary$n_pow, 3L)
    expect_equal(pv_summary$power, mean(pv < .05))
    expect_equal(pv_summary$n_size, 0L)
    expect_true(is.na(pv_summary$size))
    expect_identical(ci_summary$inference_type_params, "asymp_ci(alpha=0.1)")

    # A fully resumed run must collect its existing results without duplicates.
    complete <- serial_observational_sim(filename, 3L, TRUE, TRUE)
    complete$run()
    complete_raw <- SimulationFrameworkReport$new(complete)$get_results()
    data.table::setorderv(complete_raw, c("rep", "inference_type"))
    data.table::setcolorder(complete_raw, names(raw))
    expect_equal(complete_raw, raw,
      tolerance = 1e-12, ignore_attr = TRUE)
  }
})
