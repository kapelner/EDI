library(testthat)
library(EDI)

# SimulationFramework's internal apply_treatment_and_noise() closure (simulations_framework.R,
# defined inside the per-cell worker-execution machinery) validates a user-supplied
# custom_apply_treatment_and_noise hook's return value: `if (!is.list(out) || is.null(out$y) ||
# is.null(out$dead)) stop("custom_apply_treatment_and_noise must return a list with 'y' and
# 'dead'")`. A codebase-wide grep across testthat_bulk/, R/package_tests/testthat/ and
# R/EDI/tests/testthat/ confirms this exact guard message had no test reference anywhere -- the
# existing custom_apply_treatment_and_noise reference files (e.g. test-simulation-custom-noise-
# heterogeneous-estimand-reference.R) only exercise well-formed hooks. Reached via a real, minimal
# SimulationFramework run whose custom_apply_treatment_and_noise hook deliberately omits the
# required 'dead' field; with stop_on_error = FALSE (the default), the error is captured into the
# framework's own error log rather than propagating, matching this file's documented error-handling
# contract (test-simulation-framework-append-errors-and-state-for-current-cell-reference.R).

test_that("a custom_apply_treatment_and_noise hook that omits 'dead' is captured with the documented error message, not a raised exception", {
	folder <- tempfile("edi_bad_apply_noise_")
	dir.create(folder)
	on.exit(unlink(folder, recursive = TRUE), add = TRUE)

	bad_noise <- function(y_linear_model, w, state) {
		list(y = y_linear_model)   # missing 'dead'
	}

	sim <- SimulationFramework$new(
		response_type = "continuous",
		design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_pval = list()),
		n = 10L, p = 1L, betaT = 1, alpha = 0.1, Nrep_W = 1L, Nrep_Y_w = 1L,
		num_cores = 1L, seed = 1L,
		custom_apply_treatment_and_noise = bad_noise,
		results_filename = file.path(folder, "res.csv"),
		verbose = FALSE, turn_off_asserts_for_speed = FALSE, stop_on_error = FALSE
	)

	expect_no_error(sim$run())
	priv <- sim$.__enclos_env__$private
	expect_gt(length(priv$error_log), 0L)
	expect_true(any(vapply(priv$error_log, function(rec) {
		identical(rec$error_message, "custom_apply_treatment_and_noise must return a list with 'y' and 'dead'")
	}, logical(1))))
})

test_that("a well-formed custom_apply_treatment_and_noise hook does not trigger the guard", {
	folder <- tempfile("edi_good_apply_noise_")
	dir.create(folder)
	on.exit(unlink(folder, recursive = TRUE), add = TRUE)

	good_noise <- function(y_linear_model, w, state) {
		list(y = y_linear_model + rnorm(length(y_linear_model)), dead = rep(1L, length(y_linear_model)))
	}

	sim <- SimulationFramework$new(
		response_type = "continuous",
		design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_pval = list()),
		n = 10L, p = 1L, betaT = 1, alpha = 0.1, Nrep_W = 1L, Nrep_Y_w = 1L,
		num_cores = 1L, seed = 2L,
		custom_apply_treatment_and_noise = good_noise,
		results_filename = file.path(folder, "res2.csv"),
		verbose = FALSE, turn_off_asserts_for_speed = FALSE, stop_on_error = FALSE
	)

	sim$run()
	priv <- sim$.__enclos_env__$private
	expect_false(any(vapply(priv$error_log, function(rec) {
		identical(rec$error_message, "custom_apply_treatment_and_noise must return a list with 'y' and 'dead'")
	}, logical(1))))
})
