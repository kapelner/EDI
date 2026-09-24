library(testthat)
library(EDI)

# SimulationFramework's .compute_design_labels()/.compute_inference_labels() (simulations_framework.R)
# had no test reference anywhere by name (confirmed via zero-hit greps). Both build a "ClassName
# (k1=v1, k2=v2)" label per configured class/params pair (via .params_to_str(), omitting the
# parenthetical when params are empty), then append " [k]" to every member of any group of labels that
# are STILL identical after that -- the genuine "two classes with the exact same name and params"
# disambiguation case, distinct from the (already implicitly exercised via ordinary construction)
# single-class-per-list happy path. Reachable both directly (calling the private methods) and via the
# design_labels/inference_labels fields SimulationFramework$new() populates from them at construction.

test_that("a single design/inference class with no params gets its bare class name as the label, no suffix", {
	sim <- SimulationFramework$new(
		response_type = "continuous",
		design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
	priv <- sim$.__enclos_env__$private
	expect_identical(priv$design_labels, "DesignFixedBernoulli")
	expect_identical(priv$inference_labels, "InferenceAllSimpleAverageDiff")
	expect_identical(priv$.compute_design_labels(), "DesignFixedBernoulli")
	expect_identical(priv$.compute_inference_labels(), "InferenceAllSimpleAverageDiff")
})

test_that("two instances of the same class with the same (empty) params get ' [1]'/' [2]' disambiguating suffixes", {
	sim <- SimulationFramework$new(
		response_type = "continuous",
		design_classes_and_params = list(DesignFixedBernoulli, DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff, InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
	priv <- sim$.__enclos_env__$private
	expect_identical(priv$design_labels, c("DesignFixedBernoulli [1]", "DesignFixedBernoulli [2]"))
	expect_identical(priv$inference_labels, c("InferenceAllSimpleAverageDiff [1]", "InferenceAllSimpleAverageDiff [2]"))
})

test_that("two instances of the same class with DIFFERENT params get distinct '(k=v)' labels and no disambiguating suffix", {
	sim <- SimulationFramework$new(
		response_type = "continuous",
		design_classes_and_params = list(DesignFixedBernoulli = list(prob_T = 0.5), DesignFixedBernoulli = list(prob_T = 0.6)),
		inference_types_and_params = list(asymp_ci = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
	priv <- sim$.__enclos_env__$private
	expect_identical(priv$design_labels, c("DesignFixedBernoulli (prob_T=0.5)", "DesignFixedBernoulli (prob_T=0.6)"))
	expect_false(any(grepl("\\[", priv$design_labels)))
})
