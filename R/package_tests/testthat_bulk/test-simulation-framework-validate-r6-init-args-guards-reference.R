library(testthat)
library(EDI)

# SimulationFramework's private .validate_r6_init_args() (simulations_framework.R), called from
# .parse_inference_classes_and_params() to validate inference_classes_and_params entries against the
# target class's own initialize() formals, has three distinct guards. Two had no test reference
# anywhere (confirmed via zero-hit greps for each literal message) and are closed here:
#   1. Unnamed constructor-argument list entries (e.g. list(1, 2) instead of list(a = 1, b = 2)).
#   2. A named constructor argument the target class's initialize() doesn't declare (and doesn't
#      accept via '...').
# The third guard ("<class> has no discoverable initialize() constructor") requires a genuinely
# init-less R6 generator resolved BY NAME through .resolve_inference_class()'s eval_env = parent.frame()
# lookup at the SimulationFramework$new() call site -- verified reachable in a standalone script, but
# that lookup does not survive testthat's own expect_error()/test_that() call-frame indirection (the
# generator becomes invisible to the name lookup once wrapped), so it is not exercised here.

mk <- function(...) {
	SimulationFramework$new(
		response_type = "continuous",
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE, ...
	)
}

test_that("unnamed constructor-argument entries error with the documented message", {
	expect_error(
		mk(inference_classes_and_params = list(InferenceAllSimpleAverageDiff = list(1, 2))),
		"inference_classes_and_params for InferenceAllSimpleAverageDiff must be a named list of constructor arguments",
		fixed = TRUE
	)
})

test_that("an unaccepted named constructor argument errors with the documented message", {
	expect_error(
		mk(inference_classes_and_params = list(InferenceAllSimpleAverageDiff = list(bogus_ctor_arg_xyz = 5))),
		"inference_classes_and_params for InferenceAllSimpleAverageDiff contains constructor argument(s) not accepted by initialize(): bogus_ctor_arg_xyz",
		fixed = TRUE
	)
})

test_that("a well-formed named constructor-argument list constructs without error", {
	expect_no_error(mk(inference_classes_and_params = list(InferenceAllSimpleAverageDiff = list(verbose = FALSE))))
})
