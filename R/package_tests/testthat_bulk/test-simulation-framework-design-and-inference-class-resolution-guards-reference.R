library(testthat)
library(EDI)

# SimulationFramework$new()'s .parse_design_classes_and_params()/.parse_inference_classes_and_
# params() (simulations_framework.R:2185-2280) each resolve a design/inference_classes_and_params
# entry by name (via .resolve_design_class()/.resolve_inference_class()) and reject it if the
# resolved object isn't an R6ClassGenerator -- "design class '<name>' is not an R6 class generator"
# / "inference class '<name>' is not an R6 class generator". A name that resolves to something real
# in the EDI namespace (e.g. the exported plain function toggle_asserts) but isn't itself an R6
# class generator reaches this branch. A sibling guard on the unnamed-entry shape ("inference_
# classes_and_params[[i]] must be an R6 class generator or a named parameter list...") is likewise
# exercised; the design-side equivalent of that shape guard and the "must be a list of parameters"
# guard are already covered elsewhere. A codebase-wide grep confirmed the three messages closed here
# had zero test references anywhere. Exercised via the plain public constructor, reusing the same
# minimal fixture already established in this session's other SimulationFramework guard files.

fx <- function(...) {
	args = list(
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

test_that("a design_classes_and_params name resolving to a non-R6-generator object is rejected", {
	expect_error(
		fx(design_classes_and_params = list(toggle_asserts = list())),
		"design class 'toggle_asserts' is not an R6 class generator",
		fixed = TRUE
	)
})

test_that("an inference_classes_and_params name resolving to a non-R6-generator object is rejected", {
	expect_error(
		fx(inference_classes_and_params = list(toggle_asserts = list())),
		"inference class 'toggle_asserts' is not an R6 class generator",
		fixed = TRUE
	)
})

test_that("an unnamed, non-R6-generator inference_classes_and_params entry is rejected with the documented shape message", {
	expect_error(
		fx(inference_classes_and_params = list(list())),
		"inference_classes_and_params\\[\\[1\\]\\] must be an R6 class generator or a named parameter list whose name is the inference class",
	)
})
