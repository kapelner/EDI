library(testthat)
library(EDI)

# SimulationFramework$new()'s very first validation (simulations_framework.R): `valid_rt =
# c("continuous", "incidence", "proportion", "count", "survival", "ordinal"); if (any(!response_type
# %in% valid_rt)) stop("response_type must be one of: ", paste(valid_rt, collapse = ", "))`. A
# codebase-wide grep (both the full message and the narrower "response_type must be" substring)
# confirmed this exact guard had zero test references anywhere, despite SimulationFramework being one
# of the most heavily tested classes in the whole suite (a related iteration this stretch tested
# .default_inference_classes()'s OWN "Unknown response_type" defensive stop(), which fires only via
# direct private-field manipulation post-construction -- this is the much simpler, genuinely
# public-API-reachable sibling guard at construction time itself, never actually asserted anywhere).
# The check is vectorized (`any(!response_type %in% valid_rt)`), so a response_type vector with even
# one invalid entry among otherwise-valid ones also triggers it.

sim_args <- function(response_type) {
	list(
		response_type = response_type,
		design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE
	)
}

test_that("a single unrecognized response_type raises the documented guard message listing every valid value", {
	expect_error(
		do.call(SimulationFramework$new, sim_args("bogus_type")),
		"response_type must be one of: continuous, incidence, proportion, count, survival, ordinal",
		fixed = TRUE
	)
})

test_that("a response_type vector with even one invalid entry raises the same guard (vectorized check)", {
	expect_error(
		do.call(SimulationFramework$new, sim_args(c("continuous", "not_a_type"))),
		"response_type must be one of: continuous, incidence, proportion, count, survival, ordinal",
		fixed = TRUE
	)
})

test_that("every documented valid response_type value individually constructs without error", {
	for (rt in c("continuous", "incidence", "proportion", "count", "survival", "ordinal")) {
		expect_no_error(do.call(SimulationFramework$new, sim_args(rt)))
	}
})
