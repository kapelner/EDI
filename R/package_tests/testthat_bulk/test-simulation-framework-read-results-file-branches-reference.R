library(testthat)
library(EDI)

# SimulationFramework's private .read_results_file() (simulations_framework.R) had no test reference
# anywhere by name (confirmed via zero-hit grep). It has three distinct branches, the last two of
# which are the read-side counterpart of the .csv.bz2 write/resume pipeline already closed in
# test-simulation-framework-compressed-results-csv-bz2-pipeline-reference.R and test-simulation-
# framework-compressed-results-resume-and-cleanup-reference.R:
#   1. A plain .csv results file: read directly via data.table::fread().
#   2. A .csv.bz2 results file whose staging CSV still exists (an in-progress or just-synced run):
#      read the staging CSV directly, not the compressed file.
#   3. A .csv.bz2 results file with NO staging CSV (a freshly-synced, cleaned-up run): decompress the
#      whole file to a throwaway temp CSV via .copy_binary_stream() and read that.
# All three produce identical row content for the same underlying data.

sim_fixture <- function(results_path) {
	SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = results_path, continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
}

test_that(".read_results_file() reads a plain .csv results file directly", {
	tmpdir <- tempfile("edi_readres_csv")
	dir.create(tmpdir)
	priv <- sim_fixture(file.path(tmpdir, "r.csv"))$.__enclos_env__$private
	priv$.append_result_row_to_file(data.frame(a = 1L, b = "x"))
	out <- priv$.read_results_file()
	expect_equal(out$a, 1L)
	expect_equal(out$b, "x")
})

test_that(".read_results_file() reads the staging CSV directly for a .csv.bz2 file whose staging CSV still exists", {
	tmpdir <- tempfile("edi_readres_staging")
	dir.create(tmpdir)
	priv <- sim_fixture(file.path(tmpdir, "r.csv.bz2"))$.__enclos_env__$private
	priv$.append_result_row_to_file(data.frame(a = 2L, b = "y"))
	expect_true(file.exists(priv$.results_staging_filename()))
	out <- priv$.read_results_file()
	expect_equal(out$a, 2L)
	expect_equal(out$b, "y")
})

test_that(".read_results_file() decompresses the whole .csv.bz2 file when no staging CSV exists", {
	tmpdir <- tempfile("edi_readres_decompress")
	dir.create(tmpdir)
	priv <- sim_fixture(file.path(tmpdir, "r.csv.bz2"))$.__enclos_env__$private
	priv$.append_result_row_to_file(data.frame(a = 3L, b = "z"))
	invisible(capture.output(priv$.sync_results_bz2_from_staging(), type = "message"))
	priv$.cleanup_results_staging_file()
	expect_false(file.exists(priv$.results_staging_filename()))

	out <- priv$.read_results_file()
	expect_equal(out$a, 3L)
	expect_equal(out$b, "z")
	expect_false(file.exists(priv$.results_staging_filename()))          # the decompressed copy is a throwaway temp file, not the staging path
})
