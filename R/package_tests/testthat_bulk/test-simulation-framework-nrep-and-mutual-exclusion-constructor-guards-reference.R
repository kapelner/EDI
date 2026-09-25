library(testthat)
library(EDI)

# SimulationFramework$new() (simulations_framework.R:726-782) has five constructor-time argument
# guards, none exercised by any existing test (confirmed via codebase-wide grep for each exact
# message -- "simulations_framework" is "closed already" per this session's standing list, but
# that closure covered the render/parallel-dispatch layer, not this standalone constructor
# argument-validation surface):
#   1. Nrep_W must be a positive integer.
#   2. Nrep_Y_w must be a positive integer.
#   3. num_cores > 1 is incompatible with keep_all_intermediate_data = TRUE.
#   4. Nrep_Y_w > 1 is not supported together with a custom_dgp.
#   5. Nrep_Y_w > 1 is not supported together with keep_all_intermediate_data = TRUE.
# Exercised via the plain public constructor, reusing the same minimal fixture already established
# in test-simulation-framework-results-file-unsupported-format-defensive-guard-reference.R.

fx <- function(...) {
	args <- list(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), verbose = FALSE
	)
	extra = list(...)
	args[names(extra)] = extra
	do.call(SimulationFramework$new, args)
}

test_that("Nrep_W < 1 is rejected", {
	expect_error(fx(Nrep_W = 0L), "Nrep_W must be a positive integer", fixed = TRUE)
})

test_that("Nrep_Y_w < 1 is rejected", {
	expect_error(fx(Nrep_Y_w = 0L), "Nrep_Y_w must be a positive integer", fixed = TRUE)
})

test_that("num_cores > 1 with keep_all_intermediate_data = TRUE is rejected", {
	expect_error(
		fx(num_cores = 2L, keep_all_intermediate_data = TRUE),
		"Multithreading (num_cores > 1) is incompatible with 'keep_all_intermediate_data = TRUE'.",
		fixed = TRUE
	)
})

test_that("Nrep_Y_w > 1 together with custom_dgp is rejected", {
	expect_error(
		fx(Nrep_Y_w = 2L, custom_dgp = function(...) NULL),
		"Nrep_Y_w > 1 is not supported with custom_dgp.",
		fixed = TRUE
	)
})

test_that("Nrep_Y_w > 1 together with keep_all_intermediate_data = TRUE is rejected", {
	expect_error(
		fx(Nrep_Y_w = 2L, keep_all_intermediate_data = TRUE),
		"Nrep_Y_w > 1 is not supported with keep_all_intermediate_data = TRUE.",
		fixed = TRUE
	)
})

test_that("none of the five guards fire on the plain default fixture", {
	expect_no_error(fx())
})
