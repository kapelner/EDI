library(testthat)
library(EDI)

test_that("legacy hook arities bind custom estimands to each grid effect", {
  folder <- tempfile("edi_legacy_grid_")
  dir.create(folder)
  on.exit(unlink(folder, recursive = TRUE), add = TRUE)
  responses <- list()
  estimands <- list()
  data_generator <- function(state, rep) {
    list(X = data.frame(x = seq_len(state$n)),
      y_linear_model = seq_len(state$n) / 20)
  }
  # These older signatures omit rep_data and X/w arguments. They must receive
  # state in the same position, including the current cell and DGP parameters.
  response_generator <- function(y_linear_model, w, state) {
    effect <- (state$betaT + state$dgp_params$shift) * state$dgp_params$scale
    y <- y_linear_model + effect * w
    responses[[length(responses) + 1L]] <<-
      list(n = state$n, betaT = state$betaT, w = w, y = y, effect = effect)
    list(y = y, dead = rep(1L, length(y)))
  }
  make_estimand <- function(betaT) {
    function(y_linear_model, state) {
      effect <- (betaT + state$dgp_params$shift) * state$dgp_params$scale
      estimands[[length(estimands) + 1L]] <<-
        list(n = state$n, factory_betaT = betaT, state_betaT = state$betaT,
          effect = effect, baseline = y_linear_model)
      effect
    }
  }
  sim <- SimulationFramework$new(response_type = "continuous",
    design_classes_and_params = list(DesignFixedBernoulli),
    inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
    inference_types_and_params = list(asymp_pval = list(), asymp_ci = list()),
    n = c(16L, 20L), p = 1L, betaT = c(-.5, 0, .75),
    Nrep_W = 1L, Nrep_Y_w = 1L, num_cores = 1L, seed = 13257L,
    dgp_params = list(shift = .5, scale = 1.25),
    custom_replication_data_generator = data_generator,
    custom_apply_treatment_and_noise = response_generator,
    make_estimand_fn = make_estimand, results_filename = file.path(folder, "results.csv"),
    continue_from_last_result_row = FALSE, verbose = FALSE)
  sim$run()
  report <- SimulationFrameworkReport$new(sim)
  raw <- report$get_results()
  summary <- report$summarize()
  expect_length(report$get_errors(), 0L)
  expect_length(responses, 6L)
  expect_length(estimands, 6L)
  expect_equal(nrow(raw), 12L)
  expect_equal(nrow(summary), 12L)
  expect_equal(data.table::uniqueN(raw[, c("n", "betaT"), with = FALSE]), 6L)
  expect_identical(raw$simulation_mode, rep("crdg+catn+cte", 12L))
  for (record in responses) {
    target_n <- record$n
    target_beta <- record$betaT
    effect <- (target_beta + .5) * 1.25
    rows <- raw[raw$n == target_n & raw$betaT == target_beta]
    cell <- summary[summary$n == target_n & summary$betaT == target_beta]
    expect_equal(nrow(rows), 2L)
    expect_equal(rows$true_estimand, rep(effect, 2L), tolerance = 1e-12)
    estimate <- mean(record$y[record$w == 1]) - mean(record$y[record$w == 0])
    reference <- stats::t.test(record$y[record$w == 1], record$y[record$w == 0])
    pval <- rows$pval[rows$inference_type == "asymp_pval"]
    ci_row <- rows[rows$inference_type == "asymp_ci"]
    expect_equal(rows$estimate, rep(estimate, 2L), tolerance = 1e-12)
    expect_equal(pval, reference$p.value, tolerance = 1e-12)
    expect_equal(c(ci_row$ci_lo, ci_row$ci_hi), as.numeric(reference$conf.int),
      tolerance = 1e-12)
    expect_equal(cell$MSE, rep((estimate - effect)^2, 2L), tolerance = 1e-12)
    expect_equal(cell$n_est, c(1L, 1L))
    pv_cell <- cell[cell$inference_type == "asymp_pval"]
    ci_cell <- cell[cell$inference_type == "asymp_ci"]
    covered <- ci_row$ci_lo <= effect && effect <= ci_row$ci_hi
    expect_equal(ci_cell$coverage, as.numeric(covered))
    expect_equal(ci_cell$coverage_pval, stats::binom.test(as.integer(covered), 1L, p = .95)$p.value)
    if (effect == 0) {
      # The custom null occurs at betaT=-.5, whereas betaT=0 is an alternative.
      expect_equal(pv_cell$n_size, 1L)
      expect_equal(pv_cell$size, as.numeric(pval < .05))
      expect_equal(pv_cell$size_pval, stats::binom.test(as.integer(pval < .05), 1L, p = .05)$p.value)
      expect_equal(pv_cell$n_pow, 0L)
      expect_true(is.na(pv_cell$power))
    } else {
      expect_equal(pv_cell$n_pow, 1L)
      expect_equal(pv_cell$power, as.numeric(pval < .05))
      expect_equal(pv_cell$n_size, 0L)
      expect_true(is.na(pv_cell$size))
      expect_true(is.na(pv_cell$size_pval))
    }
    match <- Filter(function(x) x$n == target_n && x$state_betaT == target_beta,
      estimands)
    expect_length(match, 1L)
    expect_equal(match[[1L]]$factory_betaT, target_beta)
    expect_equal(match[[1L]]$effect, effect)
    expect_equal(match[[1L]]$baseline, seq_len(target_n) / 20)
  }
})
