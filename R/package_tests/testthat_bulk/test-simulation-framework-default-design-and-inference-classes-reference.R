library(testthat)
library(EDI)

# SimulationFramework's private .default_design_classes() and .default_inference_classes()
# (simulations_framework.R) supply the design/inference class lists used when the user doesn't pass
# design_classes_and_params/inference_classes_and_params explicitly. Both had NO test reference
# anywhere, confirmed via grep. .default_inference_classes() dispatches on
# private$response_type_values[[1]], prepending InferenceAllSimpleAverageDiff (the univariate
# "always applicable" comparator) UNLESS the response is survival with prob_censoring > 0 -- and has
# its own "Unknown response_type" defensive stop() for an unrecognized response type, which is
# structurally unreachable through the public API (SimulationFramework$new()'s own response_type
# validation always rejects an unrecognized value first), reached here only by directly overwriting
# private$response_type_values after construction.

sim_fixture <- function(response_type = "continuous", prob_censoring = 0) {
	SimulationFramework$new(
		response_type = response_type, design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0, prob_censoring = prob_censoring,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
}

test_that(".default_design_classes() returns the full 23-class list, starting with DesignFixedBernoulli and ending with DesignSeqOneByOneKK14", {
	priv <- sim_fixture()$.__enclos_env__$private
	dd <- priv$.default_design_classes()
	expect_length(dd, 23L)
	expect_identical(dd[[1]], DesignFixedBernoulli)
	expect_identical(dd[[length(dd)]], DesignSeqOneByOneKK14)
	expect_true(all(vapply(dd, function(cls) inherits(cls, "R6ClassGenerator"), logical(1))))
})

test_that(".default_inference_classes() prepends InferenceAllSimpleAverageDiff for an ordinary (non-censored) response type", {
	priv <- sim_fixture("continuous")$.__enclos_env__$private
	di <- priv$.default_inference_classes()
	expect_identical(di[[1]], InferenceAllSimpleAverageDiff)
	expect_length(di, 8L)
})

test_that(".default_inference_classes() omits InferenceAllSimpleAverageDiff for survival with prob_censoring > 0, but includes it when uncensored", {
	priv_censored <- sim_fixture("survival", prob_censoring = 0.3)$.__enclos_env__$private
	di_censored <- priv_censored$.default_inference_classes()
	expect_false(any(vapply(di_censored, identical, logical(1), y = InferenceAllSimpleAverageDiff)))
	expect_identical(di_censored[[1]], InferenceSurvivalCoxPHRegr)
	expect_length(di_censored, 6L)

	priv_uncensored <- sim_fixture("survival", prob_censoring = 0)$.__enclos_env__$private
	di_uncensored <- priv_uncensored$.default_inference_classes()
	expect_identical(di_uncensored[[1]], InferenceAllSimpleAverageDiff)
	expect_length(di_uncensored, 7L)
})

test_that(".default_inference_classes() throws its documented defensive error for an unrecognized response_type (unreachable via the public constructor, reached only by direct field manipulation)", {
	priv <- sim_fixture("continuous")$.__enclos_env__$private
	priv$response_type_values <- list("bogus")
	expect_error(priv$.default_inference_classes(), "Unknown response_type: bogus")
})
