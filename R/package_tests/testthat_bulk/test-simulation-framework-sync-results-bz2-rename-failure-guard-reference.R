library(testthat)
library(EDI)

# SimulationFramework's .sync_results_bz2_from_staging() (simulations_framework.R:3884-3911), the
# final step of the compressed-results (.csv.bz2) write pipeline exercised in test-simulation-
# framework-compressed-results-csv-bz2-pipeline-reference.R (happy path and missing-staging-file
# guard), has one more guard that sibling file didn't cover: if file.rename() fails to move the
# freshly-compressed temp file into place, it errors -- "Failed to move temporary compressed results
# into place: <results_filename>." A codebase-wide grep confirmed this exact message had zero test
# references anywhere. Reached by mocking base::file.rename() (via with_mocked_bindings,
# .package = "base") to always return FALSE, on the same fixture/technique the sibling file
# established -- the temp compressed file is still written and cleaned up via the method's own
# on.exit(unlink(...)), so nothing is left behind.

sim_fixture <- function(results_path) {
	SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list(), asymp_pval = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = results_path, continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
}

test_that(".sync_results_bz2_from_staging() errors with the documented message when file.rename() fails to move the compressed temp file into place", {
	tmpdir <- tempfile("edi_sim_sync_fail")
	dir.create(tmpdir)
	results_path <- file.path(tmpdir, "results.csv.bz2")
	sim <- sim_fixture(results_path)
	priv <- sim$.__enclos_env__$private

	priv$.append_result_row_to_file(data.frame(a = 1L, b = "x"))

	with_mocked_bindings(
		"file.rename" = function(...) FALSE,
		.package = "base",
		{
			expect_error(
				invisible(capture.output(priv$.sync_results_bz2_from_staging(), type = "message")),
				paste0("Failed to move temporary compressed results into place: ", results_path),
				fixed = TRUE
			)
		}
	)
	expect_false(file.exists(results_path))
})
