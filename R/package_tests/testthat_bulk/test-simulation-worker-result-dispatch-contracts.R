library(testthat)
library(EDI)

# Finite sentinel values and recorded arguments separate result dispatch from
# the numerical algorithms exercised by the inference-specific test files.
DispatchWorkerInference <- R6::R6Class("DispatchWorkerInference", public = list(
  recorder = NULL, values = NULL, capabilities = NULL,
  initialize = function(design, recorder, values, capabilities) {
    self$recorder <- recorder
    self$values <- values
    self$capabilities <- capabilities
  },
  supports = function(capability) {
    stats::setNames(list(capability %in% self$capabilities), capability)
  },
  compute_estimate = function() private$record("estimate", list()),
  compute_asymp_two_sided_pval = function(...) private$record("asymp_pval", list(...)),
  compute_asymp_confidence_interval = function(...) private$record("asymp_ci", list(...)),
  compute_exact_two_sided_pval_for_treatment_effect = function(...) private$record("exact_pval", list(...)),
  compute_exact_confidence_interval = function(...) private$record("exact_ci", list(...)),
  compute_bootstrap_two_sided_pval = function(...) private$record("boot_pval", list(...)),
  compute_bootstrap_confidence_interval = function(...) private$record("boot_ci", list(...)),
  compute_rand_two_sided_pval = function(...) private$record("rand_pval", list(...)),
  compute_rand_confidence_interval = function(...) private$record("rand_ci", list(...))
), private = list(record = function(type, args) {
  self$recorder$calls[[length(self$recorder$calls) + 1L]] <- list(type = type, args = args)
  self$values[[type]]
}))

dispatch_worker_fixture <- function(response_type = "continuous") {
  recorder <- new.env(parent = emptyenv())
  recorder$calls <- list()
  values <- list(estimate = .8, asymp_pval = .1, asymp_ci = c(-1, 1),
    exact_pval = .15, exact_ci = c(3, -3), boot_pval = .2,
    boot_ci = c(-2, 2), rand_pval = .25, rand_ci = c(-4, 4))
  state <- list(response_type = response_type, cond_exp_func_model = "linear",
    n = 8L, p = 1L, betaT = .5, alpha = .05, Nrep_Y_w = 1L,
    stop_on_error = TRUE, B_boot = 11L, r_rand = 13L, pval_epsilon = .002,
    custom_replication_data_generator = function(...) {
      list(X = data.frame(x = seq_len(8L)), y_linear_model = seq_len(8L))
    },
    custom_apply_treatment_and_noise = function(y_linear_model, w, ...) {
      list(y = rep(c(0, 1), 4L), dead = rep(1L, 8L))
    }, design_classes = list(DesignFixedBernoulli), design_labels = "dispatch-design",
    design_params = list(list()), inference_classes = list(DispatchWorkerInference),
    inference_labels = "dispatch-inference", inference_ctor_params = list(list(
      recorder = recorder, values = values, capabilities = c("wald", "exact_test",
        "nonparametric_bootstrap", "randomization_test", "randomization_ci"))),
    inf_types = names(values)[-1L], inference_type_params = list())
  list(state = state, recorder = recorder)
}

dispatch_worker_run <- function(state, progress_cb = NULL) {
  sim <- SimulationFramework$new(response_type = state$response_type,
    design_classes_and_params = list(DesignFixedBernoulli),
    inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
    inference_types_and_params = list(asymp_pval = list()), n = 8L, p = 1L,
    Nrep_W = 1L, Nrep_Y_w = 1L, results_filename = tempfile(fileext = ".csv"),
    verbose = FALSE)
  sim$.__enclos_env__$private$.run_single_replication_in_worker(3L, state, progress_cb)
}

test_that("all worker inference families collect results and merge argument defaults", {
  fixture <- dispatch_worker_fixture()
  fixture$state$inference_type_params <- list(boot_ci = list(B = 17L, na.rm = FALSE),
    rand_pval = list(r = 19L, show_progress = TRUE), exact_ci = list(alpha = .1))
  progress <- 0L
  out <- dispatch_worker_run(fixture$state, function() progress <<- progress + 1L)
  expect_length(out$errors, 0L)
  expect_null(out$fatal_error)
  expect_identical(progress, 8L)
  expect_identical(out$results_dt$inference_type, fixture$state$inf_types)
  expect_equal(out$results_dt$estimate, rep(.8, 8L))
  expect_equal(out$results_dt$true_estimand, rep(.5, 8L))
  pvals <- out$results_dt[grepl("pval$", out$results_dt$inference_type)]
  expect_equal(pvals$pval, c(.1, .15, .2, .25))
  expect_true(all(is.na(pvals$ci_lo) & is.na(pvals$ci_hi)))
  cis <- out$results_dt[grepl("ci$", out$results_dt$inference_type)]
  expect_equal(cis$ci_lo, c(-1, -3, -2, -4))
  expect_equal(cis$ci_hi, c(1, 3, 2, 4))
  expect_true(all(is.na(cis$pval)))
  calls <- stats::setNames(lapply(fixture$recorder$calls, `[[`, "args"),
    vapply(fixture$recorder$calls, `[[`, character(1L), "type"))
  expect_identical(calls$asymp_ci, list(alpha = .05))
  expect_identical(calls$exact_ci, list(alpha = .1))
  expect_identical(calls$boot_pval, list(B = 11L, na.rm = TRUE))
  expect_identical(calls$boot_ci, list(B = 17L, alpha = .05, na.rm = FALSE, show_progress = FALSE))
  expect_identical(calls$rand_pval, list(r = 19L, na.rm = TRUE, show_progress = TRUE))
  expect_identical(calls$rand_ci, list(r = 13L, alpha = .05, pval_epsilon = .002, show_progress = FALSE))
})

test_that("empty and nonfinite successful results preserve a usable result schema", {
  fixture <- dispatch_worker_fixture()
  values <- fixture$state$inference_ctor_params[[1L]]$values
  values["estimate"] <- list(NULL)
  values["exact_pval"] <- list(numeric())
  values$boot_pval <- c(.2, .3)
  values$rand_pval <- Inf
  values$asymp_ci <- .1
  values$boot_ci <- c(NA_real_, Inf)
  values$rand_ci <- numeric()
  fixture$state$inference_ctor_params[[1L]]$values <- values
  out <- dispatch_worker_run(fixture$state)
  expect_length(out$errors, 0L)
  expect_equal(nrow(out$results_dt), 8L)
  expect_true(all(is.na(out$results_dt$estimate)))
  expect_true(is.na(out$results_dt$pval[out$results_dt$inference_type == "exact_pval"]))
  expect_true(is.na(out$results_dt$pval[out$results_dt$inference_type == "rand_pval"]))
  expect_equal(out$results_dt$pval[out$results_dt$inference_type == "boot_pval"], .2)
  for (type in c("asymp_ci", "rand_ci")) {
    row <- out$results_dt[out$results_dt$inference_type == type]
    expect_true(is.na(row$ci_lo) && is.na(row$ci_hi))
  }
  row <- out$results_dt[out$results_dt$inference_type == "boot_ci"]
  expect_true(is.na(row$ci_lo))
  expect_identical(row$ci_hi, Inf)
})

test_that("unsupported capabilities and response restrictions omit inappropriate methods", {
  fixture <- dispatch_worker_fixture()
  fixture$state$inference_ctor_params[[1L]]$capabilities <- character()
  out <- dispatch_worker_run(fixture$state)
  expect_null(out$results_dt)
  expect_length(out$errors, 0L)
  expect_length(fixture$recorder$calls, 0L)
  fixture <- dispatch_worker_fixture("incidence")
  out <- dispatch_worker_run(fixture$state)
  expect_length(out$errors, 0L)
  expect_identical(out$results_dt$inference_type, setdiff(fixture$state$inf_types, "rand_ci"))
  expect_false("rand_ci" %in% vapply(fixture$recorder$calls, `[[`, character(1L), "type"))
})

test_that("nested response replications carry actual indices and custom estimands", {
  fixture <- dispatch_worker_fixture()
  fixture$state$Nrep_Y_w <- 3L
  fixture$state$inf_types <- "exact_ci"
  fixture$state$make_estimand_fn <- function(betaT) {
    function(y_linear_model, state) mean(y_linear_model) + betaT
  }
  out <- dispatch_worker_run(fixture$state)
  expect_length(out$errors, 0L)
  expect_identical(out$results_dt$rep, 7:9)
  expect_equal(out$results_dt$true_estimand, rep(5, 3L))
  expect_equal(out$results_dt$estimate, rep(.8, 3L))
  expect_identical(out$results_dt$simulation_mode, rep("crdg+catn+cte", 3L))
})

test_that("nonfinite and empty estimates are recorded as missing without stopping", {
  for (estimate in list(Inf, NaN, numeric())) {
    fixture <- dispatch_worker_fixture()
    fixture$state$inf_types <- "exact_ci"
    fixture$state$inference_ctor_params[[1L]]$values["estimate"] <- list(estimate)
    out <- dispatch_worker_run(fixture$state)
    expect_length(out$errors, 0L)
    expect_null(out$fatal_error)
    expect_identical(out$results_dt$estimate, NA_real_)
    expect_equal(out$results_dt$ci_lo, -3)
    expect_equal(out$results_dt$ci_hi, 3)
  }
})

test_that("observational DGP estimands override standard class-based estimands", {
  for (with_state in c(FALSE, TRUE)) {
    fixture <- dispatch_worker_fixture()
    fixture$state$inf_types <- "exact_ci"
    observed <- list()
    make_data <- function(n, p, rep) {
      observed <<- list(n = n, p = p, rep = rep)
      w <- rep(c(-1L, 1L), n / 2L)
      list(X = data.frame(x = seq_len(n)), w = w,
        y = 2 * w, true_estimand = 4)
    }
    fixture$state$custom_dgp <- if (with_state) {
      function(n, p, rep, state) {
        data <- make_data(n, p, rep)
        observed$state_rep <<- state$rep
        data
      }
    } else make_data
    out <- dispatch_worker_run(fixture$state)
    expect_length(out$errors, 0L)
    expect_equal(out$results_dt$true_estimand, 4)
    expect_equal(observed$n, 8L)
    expect_equal(observed$p, 1L)
    expect_equal(observed$rep, 3L)
    if (with_state) expect_equal(observed$state_rep, 3L)
  }
})
