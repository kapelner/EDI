library(testthat)
library(EDI)

# SimulationFramework's private .validate_custom_replication_data() (simulations_framework.R) --
# the shape/size validator for custom_replication_data_generator()'s return value -- had no test
# reference anywhere by name (confirmed via zero-hit greps for each of its four distinct stop()
# messages). It has four failure branches and one success branch:
#   1. The returned value isn't a list at all.
#   2. The list is missing $X or $y_linear_model.
#   3. $X has the wrong number of rows for the current simulation cell's n.
#   4. $y_linear_model has the wrong length for the current simulation cell's n.
#   5. On success, $X is coerced to a data.frame (even if supplied as a plain matrix) and
#      $y_linear_model is coerced to numeric.
# Reachable directly on a cheaply-constructed SimulationFramework instance by setting private$current_n
# (the field this validator checks against) and calling the private method directly, without ever
# running a simulation.

sim_fixture <- function() {
	SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
}

priv_at_n <- function(n = 20L) {
	priv <- sim_fixture()$.__enclos_env__$private
	priv$current_n <- n
	priv
}

test_that("a non-list return value errors with the documented message", {
	priv <- priv_at_n()
	expect_error(priv$.validate_custom_replication_data("not a list"), "custom_replication_data_generator must return a list", fixed = TRUE)
})

test_that("a list missing $X or $y_linear_model errors with the documented message", {
	priv <- priv_at_n()
	expect_error(priv$.validate_custom_replication_data(list(X = data.frame(x = 1:20))), "custom_replication_data_generator must return 'X' and 'y_linear_model'", fixed = TRUE)
	expect_error(priv$.validate_custom_replication_data(list(y_linear_model = rnorm(20))), "custom_replication_data_generator must return 'X' and 'y_linear_model'", fixed = TRUE)
})

test_that("X with the wrong number of rows errors reporting the actual and expected row counts", {
	priv <- priv_at_n()
	expect_error(
		priv$.validate_custom_replication_data(list(X = data.frame(x = 1:5), y_linear_model = rnorm(5))),
		"custom replication data returned X with 5 rows; expected 20", fixed = TRUE
	)
})

test_that("y_linear_model with the wrong length errors reporting the actual and expected lengths", {
	priv <- priv_at_n()
	expect_error(
		priv$.validate_custom_replication_data(list(X = data.frame(x = 1:20), y_linear_model = rnorm(5))),
		"custom replication data returned y_linear_model of length 5; expected 20", fixed = TRUE
	)
})

test_that("a well-formed matrix X and numeric y_linear_model pass through, with X coerced to a data.frame", {
	priv <- priv_at_n()
	out <- priv$.validate_custom_replication_data(list(X = matrix(1:20, ncol = 1), y_linear_model = 1:20))
	expect_true(is.data.frame(out$X))
	expect_equal(nrow(out$X), 20L)
	expect_true(is.numeric(out$y_linear_model))
	expect_length(out$y_linear_model, 20L)
})
