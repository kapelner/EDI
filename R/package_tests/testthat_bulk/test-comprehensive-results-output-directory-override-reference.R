library(testthat)

source(test_path("..", "comprehensive_results_path.R"), local = TRUE)

test_that("the default comprehensive result path remains exactly canonical", {
	withr::local_envvar(c(EDI_COMPREHENSIVE_RESULTS_DIR = ""))
	canonical <- file.path(
		"/repo",
		"package_tests",
		"comprehensive_tests_results_nc_2_proportion_filtered_class-InferencePropGCompMeanDiff_family-rand.csv"
	)

	expect_identical(resolve_comprehensive_results_file(canonical), canonical)
})

test_that("an existing override directory receives the same filtered filename", {
	withr::local_envvar(c(EDI_COMPREHENSIVE_RESULTS_DIR = tempdir()))
	canonical <- file.path(
		"/repo",
		"package_tests",
		"comprehensive_tests_results_nc_2_proportion_filtered_class-InferencePropGCompMeanDiff_family-rand.csv"
	)

	expect_identical(
		resolve_comprehensive_results_file(canonical),
		file.path(normalizePath(tempdir(), winslash = "/"), basename(canonical))
	)
})

test_that("a typo in the override fails closed instead of falling back to canonical output", {
	withr::local_envvar(c(EDI_COMPREHENSIVE_RESULTS_DIR = file.path(tempdir(), "missing-output-dir")))
	canonical <- file.path("/repo", "package_tests", "comprehensive_tests_results_nc_2.csv")

	expect_error(
		resolve_comprehensive_results_file(canonical),
		"EDI_COMPREHENSIVE_RESULTS_DIR is not an existing directory"
	)
})
