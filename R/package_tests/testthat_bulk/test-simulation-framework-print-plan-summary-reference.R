library(testthat)
library(EDI)

# SimulationFramework's private .print_plan_summary(planned_combos_list) (simulations_framework.R)
# had no test reference anywhere by name (confirmed via zero-hit grep). It is a pure summary-rendering
# function -- its only side effect is cat() to stderr(), safe to capture directly:
#   - Single response type: a concise 2-line "Designs (n): ..." / "Inferences (n): ..." summary.
#   - Multiple response types: one "- Response Type: <rt>" block per type, each with its own indented
#     Designs/Inferences counts.
#   - Design/inference class names have their "Design"/"Inference" prefix stripped, and inference
#     names additionally have one leading category prefix (Contin/Count/Incidence/Incid/Prop/Survival/
#     Ordinal/All) stripped, e.g. "InferenceAllSimpleAverageDiff" -> "SimpleAverageDiff".
#   - Designs/inferences are de-duplicated (unique()) across combos within the same response type.

sim_fixture <- function() {
	SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
}

test_that("a single response type prints the concise 2-line summary with prefixes stripped", {
	priv <- sim_fixture()$.__enclos_env__$private
	combos <- list(
		list(design = "DesignFixedBernoulli", inference = "InferenceAllSimpleAverageDiff", inference_type = "asymp_ci"),
		list(design = "DesignFixedBernoulli", inference = "InferenceIncidLogRegr", inference_type = "asymp_ci")
	)
	out <- capture.output(priv$.print_plan_summary(list(combos)), type = "message")
	expect_equal(out[1], "Simulation Plan Summary:")
	expect_equal(out[2], "  Designs (1): FixedBernoulli")
	expect_equal(out[3], "  Inferences (2): SimpleAverageDiff, LogRegr")
})

test_that("multiple response types print one indented block per type, with independent design/inference counts", {
	priv <- sim_fixture()$.__enclos_env__$private
	priv$param_grid <- data.table::data.table(response_type = c("continuous", "count"))
	combos1 <- list(list(design = "DesignFixedBernoulli", inference = "InferenceAllSimpleAverageDiff", inference_type = "asymp_ci"))
	combos2 <- list(list(design = "DesignFixedBernoulli", inference = "InferenceCountPoisson", inference_type = "asymp_ci"))
	out <- capture.output(priv$.print_plan_summary(list(combos1, combos2)), type = "message")
	expect_equal(out[1], "Simulation Plan Summary:")
	expect_equal(out[2], "  - Response Type: continuous")
	expect_equal(out[3], "    Designs (1): FixedBernoulli")
	expect_equal(out[4], "    Inferences (1): SimpleAverageDiff")
	expect_equal(out[5], "  - Response Type: count")
	expect_equal(out[6], "    Designs (1): FixedBernoulli")
	expect_equal(out[7], "    Inferences (1): Poisson")
})

test_that("duplicate designs/inferences across combos within the same response type are de-duplicated", {
	priv <- sim_fixture()$.__enclos_env__$private
	combos <- list(
		list(design = "DesignFixedBernoulli", inference = "InferenceAllSimpleAverageDiff", inference_type = "asymp_ci"),
		list(design = "DesignFixedBernoulli", inference = "InferenceAllSimpleAverageDiff", inference_type = "asymp_pval")
	)
	out <- capture.output(priv$.print_plan_summary(list(combos)), type = "message")
	expect_equal(out[2], "  Designs (1): FixedBernoulli")
	expect_equal(out[3], "  Inferences (1): SimpleAverageDiff")
})
