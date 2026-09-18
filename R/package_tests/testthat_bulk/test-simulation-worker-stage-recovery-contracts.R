library(testthat)
library(EDI)

# These fixtures isolate orchestration: no statistical optimizer or background
# worker is needed to distinguish constructor, estimate and inference failures.
stage_worker_condition <- function(stage) {
  structure(list(message = paste("fixture failed at", stage), call = NULL),
    class = c("fixture_worker_error", "error", "condition"))
}

StageWorkerInference <- R6::R6Class("StageWorkerInference", public = list(
  failure = NULL,
  initialize = function(design, failure = "none") {
    if (failure == "inference_initialize") stop(stage_worker_condition(failure))
    self$failure <- failure
  },
  supports = function(capability) stats::setNames(list(capability == "wald"), capability),
  compute_estimate = function() {
    if (self$failure == "estimate") stop(stage_worker_condition("estimate"))
    .75
  },
  compute_asymp_two_sided_pval = function(marker = "forwarded") {
    if (self$failure == "inference_call") stop(stage_worker_condition("inference_call"))
    .125
  },
  compute_asymp_confidence_interval = function(alpha) c(1.5, -.25)
))

StageWorkerBrokenDesign <- R6::R6Class("StageWorkerBrokenDesign", public = list(
  initialize = function(response_type, n, marker = "design-param") {
    stop(stage_worker_condition("design_build"))
  }
))

stage_worker_state <- function() {
  list(response_type = "continuous", cond_exp_func_model = "linear", n = 8L,
    p = 1L, betaT = .5, alpha = .05, Nrep_Y_w = 1L, stop_on_error = FALSE,
    custom_replication_data_generator = function(...) {
      list(X = data.frame(x = seq_len(8L)), y_linear_model = seq_len(8L))
    },
    custom_apply_treatment_and_noise = function(y_linear_model, w, ...) {
      list(y = y_linear_model + .5 * w, dead = rep(1L, length(w)))
    },
    design_classes = list(DesignFixedBernoulli), design_labels = "healthy-design",
    design_params = list(list()), inference_classes = list(StageWorkerInference),
    inference_labels = "fixture-inference", inference_ctor_params = list(list()),
    inf_types = c("asymp_pval", "asymp_ci"),
    inference_type_params = list(asymp_pval = list(marker = "forwarded")))
}

run_stage_worker <- function(state, progress_cb = NULL) {
  sim <- SimulationFramework$new(response_type = "continuous",
    design_classes_and_params = list(DesignFixedBernoulli),
    inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
    inference_types_and_params = list(asymp_pval = list()), n = 8L, p = 1L,
    Nrep_W = 1L, Nrep_Y_w = 1L, results_filename = tempfile(fileext = ".csv"),
    verbose = FALSE)
  sim$.__enclos_env__$private$.run_single_replication_in_worker(3L, state, progress_cb)
}

test_that("design failures retain metadata and recover into later designs", {
  for (fatal in c(FALSE, TRUE)) {
    state <- stage_worker_state()
    state$stop_on_error <- fatal
    state$design_classes <- list(StageWorkerBrokenDesign, DesignFixedBernoulli)
    state$design_labels <- c("broken-design", "healthy-design")
    state$design_params <- list(list(marker = "design-param"), list())
    out <- run_stage_worker(state)
    expect_length(out$errors, 1L)
    err <- out$errors[[1L]]
    expect_identical(err$stage, "design_build")
    expect_identical(err$design, "broken-design")
    expect_identical(err$design_params, list(marker = "design-param"))
    expect_identical(err$metadata$design_class, "StageWorkerBrokenDesign")
    expect_identical(err$metadata$condition_class, class(stage_worker_condition("design_build")))
    expect_identical(err$rep, 3L)
    if (fatal) {
      expect_null(out$results_dt)
      expect_identical(out$fatal_error, err)
    } else {
      expect_null(out$fatal_error)
      expect_identical(out$results_dt$design, rep("healthy-design", 2L))
    }
  }
})

test_that("inference failures respect stopping mode and retain completed rows", {
  for (stage in c("inference_initialize", "estimate", "inference_call")) {
    for (fatal in c(FALSE, TRUE)) {
      state <- stage_worker_state()
      state$stop_on_error <- fatal
      state$inference_classes <- rep(list(StageWorkerInference), 2L)
      state$inference_labels <- c("completed-inference", "broken-inference")
      state$inference_ctor_params <- list(list(), list(failure = stage))
      progress <- 0L
      out <- run_stage_worker(state, function() progress <<- progress + 1L)
      expect_length(out$errors, 1L)
      err <- out$errors[[1L]]
      expect_identical(err$stage, stage)
      expect_identical(err$inference, "broken-inference")
      expect_identical(err$inference_params, list(failure = stage))
      expect_identical(err$metadata$condition_class, class(stage_worker_condition(stage)))
      expect_identical(err$error_message, paste("fixture failed at", stage))
      expect_identical(err$rep, 3L)
      completed <- out$results_dt[out$results_dt$inference == "completed-inference"]
      expect_identical(completed$estimate, rep(.75, 2L))
      expect_equal(completed$pval[completed$inference_type == "asymp_pval"], .125)
      expect_equal(completed$ci_lo[completed$inference_type == "asymp_ci"], -.25)
      expect_equal(completed$ci_hi[completed$inference_type == "asymp_ci"], 1.5)
      expect_identical(progress, nrow(out$results_dt))
      if (fatal) {
        expect_identical(out$fatal_error, err)
        expect_equal(nrow(out$results_dt), 2L)
      } else {
        expect_null(out$fatal_error)
        broken <- out$results_dt[out$results_dt$inference == "broken-inference"]
        if (stage == "inference_initialize") expect_equal(nrow(broken), 0L)
        if (stage == "estimate") {
          expect_true(all(is.na(broken$estimate)))
          expect_equal(broken$pval[broken$inference_type == "asymp_pval"], .125)
        }
        if (stage == "inference_call") {
          expect_true(is.na(broken$pval[broken$inference_type == "asymp_pval"]))
          expect_equal(broken$ci_hi[broken$inference_type == "asymp_ci"], 1.5)
        }
      }
      if (stage == "inference_call") {
        expect_identical(err$inference_type, "asymp_pval")
        expect_identical(err$inference_type_params, list(marker = "forwarded"))
        expect_identical(err$metadata$method, "compute_asymp_two_sided_pval")
      }
    }
  }
})

test_that("plan rejected inference constructors are skipped without worker errors", {
  state <- stage_worker_state()
  state$stop_on_error <- TRUE
  state$inference_classes <- rep(list(StageWorkerInference), 2L)
  state$inference_labels <- c("rejected-inference", "allowed-inference")
  state$inference_ctor_params <- list(list(failure = "inference_initialize"), list())
  state$valid_combo_keys <- "healthy-design|allowed-inference|asymp_pval"
  out <- run_stage_worker(state)
  expect_length(out$errors, 0L)
  expect_null(out$fatal_error)
  expect_identical(out$results_dt$inference, rep("allowed-inference", 2L))
})

test_that("cached inference types advance progress and bypass completed estimates", {
  on.exit(EDI:::clear_result_key_store_cpp(), add = TRUE)
  for (cached in list(character(), "asymp_pval", c("asymp_pval", "asymp_ci"))) {
    EDI:::init_result_key_store_cpp(2L)
    state <- stage_worker_state()
    state$stop_on_error <- TRUE
    if (length(cached) > 0L) {
      EDI:::add_to_result_key_store_cpp(rep("continuous", length(cached)),
        rep("linear", length(cached)), rep(8L, length(cached)),
        rep(1L, length(cached)), rep(.5, length(cached)), rep(3L, length(cached)),
        rep("healthy-design", length(cached)), rep("fixture-inference", length(cached)),
        cached)
    }
    if (length(cached) == 2L) {
      # A completed inference must not attempt a fresh estimate on resume.
      state$inference_ctor_params <- list(list(failure = "estimate"))
    }
    progress <- 0L
    out <- run_stage_worker(state, function() progress <<- progress + 1L)
    expect_length(out$errors, 0L)
    expect_null(out$fatal_error)
    expect_equal(out$skipped_count, length(cached))
    expect_identical(progress, 2L)
    if (length(cached) == 2L) {
      expect_null(out$results_dt)
    } else {
      expect_identical(out$results_dt$inference_type, setdiff(state$inf_types, cached))
    }
  }
})
