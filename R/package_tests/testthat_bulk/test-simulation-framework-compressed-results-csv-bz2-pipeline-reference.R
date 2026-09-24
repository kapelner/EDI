library(testthat)
library(EDI)

# SimulationFramework's compressed-results (.csv.bz2) write pipeline (simulations_framework.R) --
# .results_file_format(), .results_output_path(), .results_staging_filename(), .append_result_row_
# to_file() and .sync_results_bz2_from_staging() -- had NO test reference anywhere by name (confirmed
# via zero-hit greps for each function and each of its distinct stop() messages), despite the core
# simulation-running logic being otherwise thoroughly tested elsewhere. This exercises the whole
# subsystem directly against a real SimulationFramework instance, without ever calling $run():
#   1. .results_file_format() classifies "*.csv"/"*.csv.bz2" (case-insensitively) and returns NA for
#      anything else.
#   2. .results_output_path()/.results_staging_filename() derive the expected absolute path and
#      staging-CSV sibling filename.
#   3. .append_result_row_to_file() appends to the staging CSV (not the final .bz2 path) when the
#      results file is .csv.bz2, and appends directly to the results file itself when it is plain .csv.
#   4. .sync_results_bz2_from_staging() compresses the accumulated staging CSV into the final .csv.bz2
#      file, byte-content round-tripping through data.table::fread() exactly, and errors with the
#      documented message when the staging file doesn't exist.

sim_fixture <- function(results_path) {
	SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list(), asymp_pval = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = results_path, continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
}

test_that(".results_file_format() classifies csv/csv.bz2 case-insensitively and returns NA otherwise", {
	sim <- sim_fixture(tempfile(fileext = ".csv"))
	priv <- sim$.__enclos_env__$private
	expect_identical(priv$.results_file_format("foo.csv"), "csv")
	expect_identical(priv$.results_file_format("foo.CSV"), "csv")
	expect_identical(priv$.results_file_format("foo.csv.bz2"), "csv.bz2")
	expect_identical(priv$.results_file_format("foo.CSV.BZ2"), "csv.bz2")
	expect_true(is.na(priv$.results_file_format("foo.txt")))
})

test_that(".results_output_path()/.results_staging_filename() derive the expected paths", {
	tmpdir <- tempfile("edi_sim_paths")
	dir.create(tmpdir)
	results_path <- file.path(tmpdir, "results.csv.bz2")
	sim <- sim_fixture(results_path)
	priv <- sim$.__enclos_env__$private
	expect_identical(priv$.results_output_path(), results_path)                # already absolute
	expect_identical(priv$.results_staging_filename(), file.path(tmpdir, "results__staging.csv"))
})

test_that(".append_result_row_to_file() writes to the staging CSV (not the final path) for a .csv.bz2 results file, accumulating rows", {
	tmpdir <- tempfile("edi_sim_bz2")
	dir.create(tmpdir)
	results_path <- file.path(tmpdir, "results.csv.bz2")
	sim <- sim_fixture(results_path)
	priv <- sim$.__enclos_env__$private

	priv$.append_result_row_to_file(data.frame(a = 1L, b = "x"))
	expect_false(file.exists(results_path))
	expect_true(file.exists(priv$.results_staging_filename()))
	priv$.append_result_row_to_file(data.frame(a = 2L, b = "y"))
	staged <- data.table::fread(priv$.results_staging_filename())
	expect_equal(staged$a, c(1L, 2L))
	expect_equal(staged$b, c("x", "y"))
})

test_that(".append_result_row_to_file() writes directly to the results file for a plain .csv results file", {
	tmpdir <- tempfile("edi_sim_csv")
	dir.create(tmpdir)
	results_path <- file.path(tmpdir, "results.csv")
	sim <- sim_fixture(results_path)
	priv <- sim$.__enclos_env__$private

	priv$.append_result_row_to_file(data.frame(a = 9L, b = "z"))
	expect_true(file.exists(results_path))
	out <- data.table::fread(results_path)
	expect_equal(out$a, 9L)
	expect_equal(out$b, "z")
})

test_that(".sync_results_bz2_from_staging() compresses the staging CSV into the final .csv.bz2 file, round-tripping the data exactly", {
	tmpdir <- tempfile("edi_sim_sync")
	dir.create(tmpdir)
	results_path <- file.path(tmpdir, "results.csv.bz2")
	sim <- sim_fixture(results_path)
	priv <- sim$.__enclos_env__$private

	priv$.append_result_row_to_file(data.frame(a = 1L, b = "x"))
	priv$.append_result_row_to_file(data.frame(a = 2L, b = "y"))
	staged_before <- data.table::fread(priv$.results_staging_filename())

	invisible(capture.output(priv$.sync_results_bz2_from_staging(), type = "message"))
	expect_true(file.exists(results_path))
	final <- data.table::fread(results_path)
	expect_equal(final, staged_before)
})

test_that(".sync_results_bz2_from_staging() errors with the documented message when the staging file is missing", {
	tmpdir <- tempfile("edi_sim_nostaging")
	dir.create(tmpdir)
	results_path <- file.path(tmpdir, "results.csv.bz2")
	sim <- sim_fixture(results_path)
	priv <- sim$.__enclos_env__$private

	expect_false(file.exists(priv$.results_staging_filename()))
	expect_error(
		invisible(capture.output(priv$.sync_results_bz2_from_staging(), type = "message")),
		paste0("Cannot update compressed results because staging CSV is missing: ", priv$.results_staging_filename()),
		fixed = TRUE
	)
})
