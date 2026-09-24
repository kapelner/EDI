library(testthat)
library(EDI)

# SimulationFramework's private .apply_treatment_and_noise(y_linear_model, w, rep_data = NULL)
# (simulations_framework.R) -- the real R6 method version of the custom_apply_treatment_and_noise
# dispatch (distinct from the closure-based copy inside the older worker-execution code path already
# closed this stretch in test-simulation-framework-custom-apply-treatment-and-noise-malformed-return-
# guard-reference.R, reached only via a full $run()) -- had NO test reference anywhere, confirmed via
# grep. It:
#   1. dispatches to custom_apply_treatment_and_noise with or without a rep_data argument, based on
#      the hook's own formal argument names (`"rep_data" %in% names(formals(fn))`);
#   2. validates the hook's return value is a list containing both 'y' and 'dead', else throws
#      "custom_apply_treatment_and_noise must return a list with 'y' and 'dead'".
# Reached directly on a cheaply-constructed SimulationFramework instance (no $run() needed), matching
# the established pattern for this file's other directly-callable private methods
# (.append_errors()/.state_for_current_cell(), already tested elsewhere).

sim_fixture <- function() {
	SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
}

test_that("a hook missing 'dead' throws the documented contract error", {
	priv <- sim_fixture()$.__enclos_env__$private
	priv$custom_apply_treatment_and_noise <- function(y_linear_model, w, state) list(y = y_linear_model)
	expect_error(
		priv$.apply_treatment_and_noise(rnorm(5), rep(0:1, length.out = 5)),
		"custom_apply_treatment_and_noise must return a list with 'y' and 'dead'"
	)
})

test_that("a hook missing 'y' throws the same contract error", {
	priv <- sim_fixture()$.__enclos_env__$private
	priv$custom_apply_treatment_and_noise <- function(y_linear_model, w, state) list(dead = rep(1L, length(y_linear_model)))
	expect_error(
		priv$.apply_treatment_and_noise(rnorm(5), rep(0:1, length.out = 5)),
		"custom_apply_treatment_and_noise must return a list with 'y' and 'dead'"
	)
})

test_that("a hook that doesn't return a list at all throws the same contract error", {
	priv <- sim_fixture()$.__enclos_env__$private
	priv$custom_apply_treatment_and_noise <- function(y_linear_model, w, state) 5
	expect_error(
		priv$.apply_treatment_and_noise(rnorm(5), rep(0:1, length.out = 5)),
		"custom_apply_treatment_and_noise must return a list with 'y' and 'dead'"
	)
})

test_that("a well-formed hook without a rep_data argument dispatches on (y_linear_model, w, state)", {
	priv <- sim_fixture()$.__enclos_env__$private
	priv$custom_apply_treatment_and_noise <- function(y_linear_model, w, state) {
		list(y = y_linear_model, dead = rep(1L, length(y_linear_model)))
	}
	res <- priv$.apply_treatment_and_noise(1:5, rep(0:1, length.out = 5))
	expect_equal(res$y, 1:5)
	expect_equal(res$dead, rep(1L, 5))
})

test_that("a well-formed hook WITH a rep_data argument receives it and can use it", {
	priv <- sim_fixture()$.__enclos_env__$private
	priv$custom_apply_treatment_and_noise <- function(y_linear_model, w, rep_data, state) {
		list(y = y_linear_model + rep_data$shift, dead = rep(1L, length(y_linear_model)))
	}
	res <- priv$.apply_treatment_and_noise(rep(1, 5), rep(0:1, length.out = 5), rep_data = list(shift = 10))
	expect_equal(res$y, rep(11, 5))
})
