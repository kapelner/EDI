library(testthat)
library(EDI)

# The remaining pieces of SimulationFramework's compressed-results (.csv.bz2) subsystem
# (simulations_framework.R) -- .simulation_cache_dir(), .elapsed_file(), .cleanup_results_staging_
# file(), .ensure_staging_file_exists() and .load_existing_results_from_staging_or_empty() -- had no
# test reference anywhere by name (confirmed via zero-hit greps), the natural companion to
# test-simulation-framework-compressed-results-csv-bz2-pipeline-reference.R's write-side coverage.
# .ensure_staging_file_exists()/.load_existing_results_from_staging_or_empty() are the DECOMPRESS-side
# counterpart to .sync_results_bz2_from_staging()'s compress side -- the mechanism a resumed run uses
# to recover an existing .csv.bz2's rows into a fresh staging CSV before continuing to append to it.
#   1. .simulation_cache_dir()/.elapsed_file() derive the expected sibling paths from the results path.
#   2. .cleanup_results_staging_file() removes the staging CSV for a .csv.bz2 results file (and is a
#      no-op, not an error, for a plain .csv results file or when no staging file exists).
#   3. .ensure_staging_file_exists() decompresses an existing .csv.bz2 results file into a fresh
#      staging CSV when none exists yet (the "resuming a run" scenario), and is a no-op when a staging
#      file already exists or no results file exists yet.
#   4. .load_existing_results_from_staging_or_empty() reads the staging file's rows back when present,
#      and returns the caller's supplied empty table when the results file isn't .csv.bz2 or no
#      staging file exists.

sim_fixture <- function(results_path, verbose = FALSE) {
	SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list(), asymp_pval = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = results_path, continue_from_last_result_row = FALSE,
		verbose = verbose, turn_off_asserts_for_speed = FALSE)
}

test_that(".simulation_cache_dir()/.elapsed_file() derive the expected sibling paths", {
	tmpdir <- tempfile("edi_sim_cachepaths")
	dir.create(tmpdir)
	results_path <- file.path(tmpdir, "results.csv.bz2")
	priv <- sim_fixture(results_path)$.__enclos_env__$private
	expect_identical(priv$.simulation_cache_dir(), file.path(tmpdir, "results__cache"))
	expect_identical(priv$.elapsed_file(), file.path(tmpdir, "results__elapsed.rds"))
})

test_that(".cleanup_results_staging_file() removes the staging CSV for a .csv.bz2 results file", {
	tmpdir <- tempfile("edi_sim_cleanup")
	dir.create(tmpdir)
	results_path <- file.path(tmpdir, "results.csv.bz2")
	priv <- sim_fixture(results_path)$.__enclos_env__$private
	priv$.append_result_row_to_file(data.frame(a = 1L))
	expect_true(file.exists(priv$.results_staging_filename()))
	priv$.cleanup_results_staging_file()
	expect_false(file.exists(priv$.results_staging_filename()))
})

test_that(".cleanup_results_staging_file() is a no-op for a plain .csv results file", {
	tmpdir <- tempfile("edi_sim_cleanup_csv")
	dir.create(tmpdir)
	results_path <- file.path(tmpdir, "results.csv")
	priv <- sim_fixture(results_path)$.__enclos_env__$private
	priv$.append_result_row_to_file(data.frame(a = 1L))
	expect_no_error(priv$.cleanup_results_staging_file())
	expect_true(file.exists(results_path))                                # untouched, not a staging file
})

test_that(".ensure_staging_file_exists() decompresses an existing .csv.bz2 into a fresh staging CSV, matching the original rows exactly", {
	tmpdir <- tempfile("edi_sim_resume")
	dir.create(tmpdir)
	results_path <- file.path(tmpdir, "results.csv.bz2")
	priv1 <- sim_fixture(results_path)$.__enclos_env__$private
	priv1$.append_result_row_to_file(data.frame(a = 1L, b = "x"))
	priv1$.append_result_row_to_file(data.frame(a = 2L, b = "y"))
	original <- data.table::fread(priv1$.results_staging_filename())
	invisible(capture.output(priv1$.sync_results_bz2_from_staging(), type = "message"))
	priv1$.cleanup_results_staging_file()
	expect_false(file.exists(priv1$.results_staging_filename()))

	priv2 <- sim_fixture(results_path)$.__enclos_env__$private                  # a fresh "resumed" instance
	expect_false(file.exists(priv2$.results_staging_filename()))
	invisible(capture.output(priv2$.ensure_staging_file_exists(), type = "message"))
	expect_true(file.exists(priv2$.results_staging_filename()))
	recovered <- data.table::fread(priv2$.results_staging_filename())
	expect_equal(recovered, original)
})

test_that(".ensure_staging_file_exists() is a no-op when a staging file already exists or no results file exists yet", {
	tmpdir <- tempfile("edi_sim_resume_noop")
	dir.create(tmpdir)
	results_path <- file.path(tmpdir, "results.csv.bz2")
	priv <- sim_fixture(results_path)$.__enclos_env__$private
	expect_false(file.exists(results_path))
	expect_no_error(priv$.ensure_staging_file_exists())
	expect_false(file.exists(priv$.results_staging_filename()))

	priv$.append_result_row_to_file(data.frame(a = 1L))
	before <- data.table::fread(priv$.results_staging_filename())
	invisible(capture.output(priv$.ensure_staging_file_exists(), type = "message"))   # staging already exists: no-op
	after <- data.table::fread(priv$.results_staging_filename())
	expect_equal(before, after)
})

test_that(".load_existing_results_from_staging_or_empty() reads staged rows when present, and the empty table otherwise", {
	tmpdir <- tempfile("edi_sim_loadstage")
	dir.create(tmpdir)
	empty_dt <- data.table::data.table(a = integer(0), b = character(0))

	results_path_bz2 <- file.path(tmpdir, "results.csv.bz2")
	priv_bz2 <- sim_fixture(results_path_bz2)$.__enclos_env__$private
	expect_equal(priv_bz2$.load_existing_results_from_staging_or_empty(empty_dt), empty_dt)   # no staging yet
	priv_bz2$.append_result_row_to_file(data.frame(a = 5L, b = "z"))
	loaded <- priv_bz2$.load_existing_results_from_staging_or_empty(empty_dt)
	expect_equal(loaded$a, 5L)
	expect_equal(loaded$b, "z")

	results_path_csv <- file.path(tmpdir, "results.csv")
	priv_csv <- sim_fixture(results_path_csv)$.__enclos_env__$private
	expect_identical(priv_csv$.load_existing_results_from_staging_or_empty(empty_dt), empty_dt)   # not a .csv.bz2 file at all
})
