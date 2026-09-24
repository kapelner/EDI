library(testthat)
library(EDI)

# SimulationFramework's private .append_errors() and .state_for_current_cell() (simulations_framework.R)
# had no test reference anywhere by name (confirmed via zero-hit greps):
#   .append_errors() -- accumulates a list of error records onto private$error_log, in order, across
#      repeated calls; an empty list is a true no-op (does not touch error_log at all).
#   .state_for_current_cell() -- snapshots the current simulation cell's parameters (and the supplied
#      rep) into a plain list, the shape passed to custom_apply_treatment_and_noise() extension hooks.
# Both reachable directly on a cheaply-constructed SimulationFramework instance, without ever calling
# $run().

sim_fixture <- function() {
	SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
}

test_that(".append_errors() accumulates error records in order across calls, and an empty list is a true no-op", {
	priv <- sim_fixture()$.__enclos_env__$private
	expect_length(priv$error_log, 0L)

	priv$.append_errors(list())
	expect_length(priv$error_log, 0L)

	priv$.append_errors(list(list(stage = "design", message = "err1")))
	expect_length(priv$error_log, 1L)

	priv$.append_errors(list(list(stage = "fit", message = "err2"), list(stage = "fit", message = "err3")))
	expect_length(priv$error_log, 3L)
	expect_identical(vapply(priv$error_log, `[[`, "", "message"), c("err1", "err2", "err3"))
})

test_that(".state_for_current_cell() snapshots the current cell's parameters and the supplied rep into a plain list", {
	priv <- sim_fixture()$.__enclos_env__$private
	priv$current_response_type <- "count"
	priv$current_cond_exp_func_model <- "linear"
	priv$current_n <- 30L
	priv$current_p <- 2L
	priv$current_betaT <- 0.5

	st <- priv$.state_for_current_cell(rep = 5L)
	expect_identical(st$rep, 5L)
	expect_identical(st$response_type, "count")
	expect_identical(st$cond_exp_func_model, "linear")
	expect_identical(st$n, 30L)
	expect_identical(st$p, 2L)
	expect_identical(st$betaT, 0.5)

	st_norep <- priv$.state_for_current_cell()
	expect_null(st_norep$rep)
})
