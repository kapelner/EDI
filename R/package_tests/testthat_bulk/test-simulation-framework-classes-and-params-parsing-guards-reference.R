library(testthat)
library(EDI)

# SimulationFramework$initialize()'s design/inference class-and-params parsing (simulations_framework.R,
# .parse_design_classes_and_params()/.parse_inference_classes_and_params()/.parse_inference_types_and_
# params()/.resolve_design_class()/.resolve_inference_class()) has a rich set of argument-validation
# guards, none of which had a test reference anywhere (confirmed via zero-hit greps for each literal
# message), despite the core $run() machinery being otherwise thoroughly tested elsewhere. All fire at
# construction time, before any simulation work is attempted.

mk <- function(...) {
	SimulationFramework$new(
		response_type = "continuous",
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE, ...
	)
}

test_that("design_classes_and_params must be NULL or a list", {
	expect_error(mk(design_classes_and_params = "not a list"), "design_classes_and_params must be NULL or a list", fixed = TRUE)
})

test_that("an unresolvable design class name errors with the documented message", {
	expect_error(
		mk(design_classes_and_params = list(NotARealDesignClassXYZ = list())),
		"could not find design class 'NotARealDesignClassXYZ'", fixed = TRUE
	)
})

test_that("a non-list entry for a named design class errors with the documented message", {
	expect_error(
		mk(design_classes_and_params = list(DesignFixedBernoulli = "not a list")),
		"design_classes_and_params[['DesignFixedBernoulli']] must be a list of parameters", fixed = TRUE
	)
})

test_that("an unnamed, non-R6-generator design entry errors with the documented message", {
	expect_error(
		mk(design_classes_and_params = list(list())),
		"design_classes_and_params[[1]] must be an R6 class generator or a named parameter list whose name is the design class",
		fixed = TRUE
	)
})

test_that("inference_classes_and_params must be NULL or a list", {
	expect_error(mk(inference_classes_and_params = "not a list"), "inference_classes_and_params must be NULL or a list", fixed = TRUE)
})

test_that("an unresolvable inference class name errors with the documented message", {
	expect_error(
		mk(inference_classes_and_params = list(NotARealInferenceClassXYZ = list())),
		"could not find inference class 'NotARealInferenceClassXYZ'", fixed = TRUE
	)
})

test_that("inference_types_and_params must be NULL or a named list", {
	expect_error(
		mk(inference_types_and_params = "not a list"),
		"inference_types_and_params must be NULL or a named list", fixed = TRUE
	)
})

test_that("an unknown inference_types_and_params name errors listing every valid value", {
	expect_error(
		mk(inference_types_and_params = list(bogus_type = list())),
		"Invalid inference_types_and_params names: bogus_type.  Valid values: asymp_ci, asymp_pval, exact_ci, exact_pval, boot_ci, boot_pval, rand_ci, rand_pval",
		fixed = TRUE
	)
})

test_that("a non-list (or unnamed-list) value for a valid inference type errors with the documented message", {
	expect_error(
		mk(inference_types_and_params = list(asymp_ci = "not a list")),
		"inference_types_and_params[['asymp_ci']] must be a named list", fixed = TRUE
	)
	expect_error(
		mk(inference_types_and_params = list(asymp_ci = list(1, 2))),
		"inference_types_and_params[['asymp_ci']] must be a named list", fixed = TRUE
	)
})

test_that("valid, well-formed classes-and-params arguments construct without error", {
	expect_no_error(mk(
		design_classes_and_params = list(DesignFixedBernoulli = list(prob_T = 0.5)),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff = list()),
		inference_types_and_params = list(asymp_ci = list(), asymp_pval = list(delta = 0))
	))
})
