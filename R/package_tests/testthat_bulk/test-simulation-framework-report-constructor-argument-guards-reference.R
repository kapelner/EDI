library(testthat)
library(EDI)

# SimulationFrameworkReport$initialize() (simulation_framework_report.R) has four distinct
# argument-validation guards, none of which had a test reference anywhere (confirmed via a zero-hit
# grep for each literal message):
#   1. "'sim_or_filename' must be a SimulationFramework object or a character filename" -- neither a
#      SimulationFramework nor a character (e.g. a bare number).
#   2. "File not found: <path>" -- a character path that doesn't exist on disk.
#   3. "Unsupported file format; must end in .csv or .csv.bz2" -- an existing file with the wrong
#      extension.
#   4. "SimulationFramework must be run first (call $run())." -- a genuine SimulationFramework object
#      that has never had $run() called on it.
# All four are reachable at construction time, before any simulation work is attempted, using the
# same minimal SimulationFramework fixture already established in
# test-simulation-report-completed-state-contracts.R (but here left genuinely un-run, rather than
# having its "completed" state hand-installed).

sim_fixture <- function() {
	SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list(), asymp_pval = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
}

test_that("neither a SimulationFramework nor a character filename errors with the documented type message", {
	expect_error(
		SimulationFrameworkReport$new(123),
		"'sim_or_filename' must be a SimulationFramework object or a character filename",
		fixed = TRUE
	)
})

test_that("a nonexistent file path errors with the documented 'File not found' message", {
	bogus <- file.path(tempdir(), "__edi_definitely_not_a_real_results_file__.csv")
	expect_false(file.exists(bogus))
	expect_error(SimulationFrameworkReport$new(bogus), paste0("File not found: ", bogus), fixed = TRUE)
})

test_that("an existing file with an unsupported extension errors with the documented format message", {
	tmpf <- tempfile(fileext = ".txt")
	writeLines("not a results file", tmpf)
	on.exit(unlink(tmpf), add = TRUE)
	expect_error(
		SimulationFrameworkReport$new(tmpf),
		"Unsupported file format; must end in .csv or .csv.bz2",
		fixed = TRUE
	)
})

test_that("a genuine SimulationFramework that has never been run errors with the documented message", {
	sim <- sim_fixture()
	expect_error(
		SimulationFrameworkReport$new(sim),
		"SimulationFramework must be run first (call $run()).",
		fixed = TRUE
	)
})
