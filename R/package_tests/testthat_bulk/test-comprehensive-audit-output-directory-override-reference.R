library(testthat)

source(test_path("..", "comprehensive_audit_paths.R"), local = TRUE)

test_that("audit paths default to the existing canonical inputs and sidecars", {
	withr::local_envvar(c(EDI_COMPREHENSIVE_RESULTS_DIR = ""))
	here <- file.path("/repo", "R", "package_tests")
	response_types <- c("continuous", "incidence", "proportion", "count", "survival", "ordinal")
	paths <- resolve_comprehensive_audit_paths(here, response_types)

	expect_identical(
		paths$files,
		stats::setNames(file.path(here, sprintf("comprehensive_tests_results_nc_1_%s.csv", response_types)), response_types)
	)
	expect_identical(paths$baseline, file.path(here, "comprehensive_results_audit_baseline.csv"))
	expect_identical(paths$stamp, file.path(here, ".comprehensive_results_audit_stamp"))
})

test_that("audit inputs, baseline, and stamp route together to the existing scratch directory", {
	withr::local_envvar(c(EDI_COMPREHENSIVE_RESULTS_DIR = tempdir()))
	home_here <- file.path("/repo", "R", "package_tests")
	response_types <- c("continuous", "proportion")
	paths <- resolve_comprehensive_audit_paths(home_here, response_types)
	scratch <- normalizePath(tempdir(), winslash = "/")

	expect_identical(
		paths$files,
		stats::setNames(file.path(scratch, sprintf("comprehensive_tests_results_nc_1_%s.csv", response_types)), response_types)
	)
	expect_identical(paths$baseline, file.path(scratch, "comprehensive_results_audit_baseline.csv"))
	expect_identical(paths$stamp, file.path(scratch, ".comprehensive_results_audit_stamp"))
})

test_that("a missing scratch directory fails closed", {
	withr::local_envvar(c(EDI_COMPREHENSIVE_RESULTS_DIR = file.path(tempdir(), "missing-audit-dir")))

	expect_error(
		resolve_comprehensive_audit_paths("/repo/R/package_tests", "proportion"),
		"EDI_COMPREHENSIVE_RESULTS_DIR is not an existing directory"
	)
})

test_that("baseline replacement refuses a missing or empty response input", {
	response_types <- c("continuous", "incidence", "proportion", "count", "survival", "ordinal")
	files <- stats::setNames(file.path(tempdir(), paste0("audit-input-", response_types, ".csv")), response_types)
	on.exit(unlink(files), add = TRUE)
	writeLines("header", files[["ordinal"]])

	expect_error(
		validate_comprehensive_audit_baseline_inputs(files),
		"Refusing --write-baseline: missing or empty response-level inputs for: continuous, incidence, proportion, count, survival"
	)
})

test_that("baseline replacement accepts all expected nonempty response inputs", {
	response_types <- c("continuous", "incidence", "proportion", "count", "survival", "ordinal")
	files <- stats::setNames(file.path(tempdir(), paste0("audit-complete-", response_types, ".csv")), response_types)
	on.exit(unlink(files), add = TRUE)
	invisible(lapply(files, function(path) writeLines("header", path)))

	expect_invisible(validate_comprehensive_audit_baseline_inputs(files))
})
