library(testthat)
library(EDI)

test_that("custom noise and full replication data survive nested response draws", {
  folder <- tempfile("edi_custom_noise_")
  dir.create(folder)
  on.exit(unlink(folder, recursive = TRUE), add = TRUE)
  response_records <- list()
  estimand_records <- list()
  data_generator <- function(state, rep) {
    x <- seq(-1, 1, length.out = state$n)
    list(X = data.frame(x = x), y_linear_model = .3 * x,
      latent_noise = rep(c(-.8, .4, -.2, .7), length.out = state$n),
      subject_effect = state$dgp_params$tau * (1 + x / 4), draw = rep,
      annotation = "extra replication fields")
  }
  noise_generator <- function(y_linear_model, w, rep_data, state) {
    # A separate deterministic noise scale for each repeated outcome vector
    # makes accidental reuse of a previous response observable.
    draw_index <- length(response_records) + 1L
    y <- y_linear_model + rep_data$subject_effect * as.numeric(w == 1L) +
      rep_data$latent_noise * (1 + draw_index / 10)
    response_records[[draw_index]] <<- list(w = w, y = y, rep_data = rep_data,
      dgp_params = state$dgp_params, y_linear_model = y_linear_model)
    list(y = y, dead = rep(1L, length(y)))
  }
  make_estimand <- function(betaT) {
    function(y_linear_model, X, w, rep_data, state) {
      estimand_records[[length(estimand_records) + 1L]] <<-
        list(betaT = betaT, X = X, w = w, rep_data = rep_data,
          y_linear_model = y_linear_model, dgp_params = state$dgp_params)
      mean(rep_data$subject_effect)
    }
  }
  sim <- SimulationFramework$new(response_type = "continuous",
    design_classes_and_params = list(DesignFixedBernoulli),
    inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
    inference_types_and_params = list(asymp_pval = list(), asymp_ci = list()),
    n = 16L, p = 1L, betaT = 7, alpha = .1, Nrep_W = 2L, Nrep_Y_w = 2L,
    num_cores = 1L, seed = 8321L, dgp_params = list(tau = 1.5),
    custom_replication_data_generator = data_generator,
    custom_apply_treatment_and_noise = noise_generator,
    make_estimand_fn = make_estimand,
    results_filename = file.path(folder, "results.csv"),
    continue_from_last_result_row = FALSE, verbose = FALSE)
  sim$run()
  report <- SimulationFrameworkReport$new(sim)
  raw <- report$get_results()
  expect_length(report$get_errors(), 0L)
  expect_length(response_records, 4L)
  expect_length(estimand_records, 2L)
  expect_equal(nrow(raw), 8L)
  expect_identical(sort(unique(raw$rep)), 1:4)
  expect_identical(raw$simulation_mode, rep("crdg+catn+cte", 8L))
  expect_equal(raw$true_estimand, rep(1.5, 8L), tolerance = 1e-12)
  expect_identical(response_records[[1L]]$w, response_records[[2L]]$w)
  expect_identical(response_records[[3L]]$w, response_records[[4L]]$w)
  expect_false(identical(response_records[[1L]]$y, response_records[[2L]]$y))
  expect_false(identical(response_records[[3L]]$y, response_records[[4L]]$y))
  expect_identical(vapply(response_records, function(record) record$rep_data$draw,
    integer(1L)), c(1L, 1L, 2L, 2L))
  for (rep in 1:4) {
    target_rep <- rep
    record <- response_records[[rep]]
    expect_true(all(record$w %in% c(0L, 1L)))
    expect_identical(record$dgp_params, list(tau = 1.5))
    expect_identical(record$rep_data$annotation, "extra replication fields")
    expect_equal(record$y_linear_model, .3 * record$rep_data$X$x)
    reference <- stats::t.test(record$y[record$w == 1L],
      record$y[record$w == 0L], conf.level = .9)
    row_pv <- raw[raw$rep == target_rep & raw$inference_type == "asymp_pval"]
    row_ci <- raw[raw$rep == target_rep & raw$inference_type == "asymp_ci"]
    estimate <- mean(record$y[record$w == 1L]) - mean(record$y[record$w == 0L])
    expect_equal(row_pv$estimate, estimate, tolerance = 1e-12)
    expect_equal(row_ci$estimate, estimate, tolerance = 1e-12)
    expect_equal(row_pv$pval, reference$p.value, tolerance = 1e-12)
    expect_equal(c(row_ci$ci_lo, row_ci$ci_hi), as.numeric(reference$conf.int),
      tolerance = 1e-12)
  }
  for (draw in 1:2) {
    estimand <- estimand_records[[draw]]
    response <- response_records[[2L * draw - 1L]]
    expect_equal(estimand$betaT, 7)
    expect_identical(estimand$w, response$w)
    expect_equal(estimand$X, response$rep_data$X)
    expect_identical(estimand$rep_data, response$rep_data)
    expect_identical(estimand$dgp_params, list(tau = 1.5))
    expect_equal(estimand$y_linear_model, response$y_linear_model)
  }
})
