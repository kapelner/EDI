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

test_that("baseline preflight refuses ambiguous duplicate response names", {
	files <- c(continuous = "continuous.csv", continuous = "other.csv")

	expect_error(
		validate_comprehensive_audit_baseline_inputs(files),
		"files must be a named character vector of response-level paths"
	)
})

test_that("the baseline CLI refuses a partial artifact set without replacing prior state", {
	skip_if_not(nzchar(Sys.which("Rscript")), "Rscript is required for the CLI safety check")
	response_types <- c("continuous", "incidence", "proportion", "count", "survival", "ordinal")
	scratch <- tempfile("comprehensive-audit-partial-")
	dir.create(scratch)
	withr::defer(unlink(scratch, recursive = TRUE), envir = parent.frame())

	paths <- stats::setNames(file.path(scratch, paste0("comprehensive_tests_results_nc_1_", response_types, ".csv")), response_types)
	writeLines("header", paths[["ordinal"]])
	baseline <- file.path(scratch, "comprehensive_results_audit_baseline.csv")
	stamp <- file.path(scratch, ".comprehensive_results_audit_stamp")
	writeLines("prior accepted baseline", baseline)
	writeLines("prior passing stamp", stamp)

	script <- normalizePath(test_path("..", "audit_comprehensive_results.R"), winslash = "/", mustWork = TRUE)
	output <- suppressWarnings(system2(
		Sys.which("Rscript"),
		args = c(shQuote(script), "--write-baseline"),
		env = paste0("EDI_COMPREHENSIVE_RESULTS_DIR=", scratch),
		stdout = TRUE,
		stderr = TRUE
	))

	status <- attr(output, "status")
	if (is.null(status)) status <- 0L
	expect_gt(status, 0L)
	expect_true(any(grepl(
		"Refusing --write-baseline: missing or empty response-level inputs for: continuous, incidence, proportion, count, survival",
		output,
		fixed = TRUE
	)))
	expect_identical(readLines(baseline), "prior accepted baseline")
	expect_identical(readLines(stamp), "prior passing stamp")

	# Present, nonempty CSVs with only headers are not a complete result set:
	# accepting them would turn every prior finding into an apparent resolution.
	header_only <- data.frame(
		inference_class = character(), function_run = character(), status = character(),
		result = numeric(), result_1 = numeric(), result_2 = numeric(), beta_T = numeric(),
		coverage_truth = numeric(), beta_T_in_confidence_interval = logical(), error_message = character()
	)
	invisible(lapply(paths, function(path) utils::write.csv(header_only, path, row.names = FALSE)))
	output <- suppressWarnings(system2(
		Sys.which("Rscript"),
		args = c(shQuote(script), "--write-baseline"),
		env = paste0("EDI_COMPREHENSIVE_RESULTS_DIR=", scratch),
		stdout = TRUE,
		stderr = TRUE
	))
	status <- attr(output, "status")
	if (is.null(status)) status <- 0L
	expect_gt(status, 0L)
	expect_true(any(grepl(
		"Refusing --write-baseline: response-level inputs must have the result schema and at least one data row for: continuous, incidence, proportion, count, survival, ordinal",
		output,
		fixed = TRUE
	)))
	expect_identical(readLines(baseline), "prior accepted baseline")
	expect_identical(readLines(stamp), "prior passing stamp")
})

test_that("the baseline CLI writes a complete synthetic artifact set only to its override directory", {
	skip_if_not(nzchar(Sys.which("Rscript")), "Rscript is required for the CLI safety check")
	response_types <- c("continuous", "incidence", "proportion", "count", "survival", "ordinal")
	scratch <- tempfile("comprehensive-audit-complete-")
	dir.create(scratch)
	withr::defer(unlink(scratch, recursive = TRUE), envir = parent.frame())
	runner_dir <- file.path(scratch, "runner")
	output_dir <- file.path(scratch, "results")
	dir.create(runner_dir)
	dir.create(output_dir)
	for (file in c("audit_comprehensive_results.R", "comprehensive_audit_paths.R")) {
		expect_true(file.copy(test_path("..", file), runner_dir))
	}

	paths <- stats::setNames(
		file.path(output_dir, paste0("comprehensive_tests_results_nc_1_", response_types, ".csv")),
		response_types
	)
	n <- 30L
	pval_rows <- data.frame(
		inference_class = rep("SyntheticNoOp", n), function_run = rep("compute_rand_two_sided_pval", n),
		status = rep("ok", n), result = rep(NA_real_, n), result_1 = (seq_len(n) - 0.5) / n,
		result_2 = rep(NA_real_, n), beta_T = rep(0, n), coverage_truth = rep(0.25, n),
		beta_T_in_confidence_interval = rep(NA, n), error_message = rep("", n)
	)
	ci_rows <- data.frame(
		inference_class = rep("SyntheticNoOp", n), function_run = rep("compute_rand_confidence_interval", n),
		status = rep("ok", n), result = rep(NA_real_, n), result_1 = rep(-1, n), result_2 = rep(1, n),
		beta_T = rep(0, n), coverage_truth = rep(0.25, n), beta_T_in_confidence_interval = rep(TRUE, n),
		error_message = rep("", n)
	)
	estimate_rows <- data.frame(
		inference_class = rep("SyntheticNoOp", n), function_run = rep("compute_estimate", n),
		status = rep("ok", n), result = rep(0, n), result_1 = rep(NA_real_, n), result_2 = rep(NA_real_, n),
		beta_T = rep(0, n), coverage_truth = rep(0.25, n), beta_T_in_confidence_interval = rep(NA, n),
		error_message = rep("", n)
	)
	invisible(lapply(paths, function(path) utils::write.csv(
		rbind(pval_rows, ci_rows, estimate_rows), path, row.names = FALSE, na = "NA"
	)))

	script <- file.path(runner_dir, "audit_comprehensive_results.R")
	output <- suppressWarnings(system2(
		Sys.which("Rscript"),
		args = c(shQuote(script), "--write-baseline"),
		env = paste0("EDI_COMPREHENSIVE_RESULTS_DIR=", output_dir),
		stdout = TRUE,
		stderr = TRUE
	))
	status <- attr(output, "status")
	if (is.null(status)) status <- 0L
	expect_identical(status, 0L, info = paste(output, collapse = "\n"))

	baseline <- file.path(output_dir, "comprehensive_results_audit_baseline.csv")
	stamp <- file.path(output_dir, ".comprehensive_results_audit_stamp")
	expect_true(any(grepl("wrote baseline with 0 accepted finding(s)", output, fixed = TRUE)))
	expect_true(file.exists(baseline))
	expect_true(file.exists(stamp))
	expect_identical(
		names(utils::read.csv(baseline, check.names = FALSE)),
		c("key", "check", "response_type", "class", "formula", "function_run", "detail")
	)
	expect_equal(nrow(utils::read.csv(baseline, check.names = FALSE)), 0L)
	expect_identical(
		readLines(stamp),
		paste(sprintf("%s:%d:%d", basename(paths), as.integer(file.size(paths)), as.integer(file.mtime(paths))), collapse = "|")
	)
	expect_false(file.exists(file.path(runner_dir, "comprehensive_results_audit_baseline.csv")))
	expect_false(file.exists(file.path(runner_dir, ".comprehensive_results_audit_stamp")))
})

test_that("baseline replacement accepts all expected nonempty response inputs", {
	response_types <- c("continuous", "incidence", "proportion", "count", "survival", "ordinal")
	files <- stats::setNames(file.path(tempdir(), paste0("audit-complete-", response_types, ".csv")), response_types)
	on.exit(unlink(files), add = TRUE)
	valid_row <- data.frame(
		inference_class = "SyntheticNoOp", function_run = "compute_estimate", status = "ok",
		result = 0, result_1 = NA_real_, result_2 = NA_real_, beta_T = 0,
		coverage_truth = 0.25, beta_T_in_confidence_interval = NA,
		error_message = "", stringsAsFactors = FALSE
	)
	invisible(lapply(files, function(path) utils::write.csv(valid_row, path, row.names = FALSE)))

	expect_invisible(validate_comprehensive_audit_baseline_inputs(files))
})

test_that("coverage audit counts returned invalid intervals as noncoverage", {
	skip_if_not(nzchar(Sys.which("Rscript")), "Rscript is required for the audit CLI check")
	response_types <- c("continuous", "incidence", "proportion", "count", "survival", "ordinal")
	scratch <- tempfile("comprehensive-audit-invalid-ci-")
	dir.create(scratch)
	withr::defer(unlink(scratch, recursive = TRUE), envir = parent.frame())
	runner_dir <- file.path(scratch, "runner")
	output_dir <- file.path(scratch, "results")
	dir.create(runner_dir)
	dir.create(output_dir)
	for (file in c("audit_comprehensive_results.R", "comprehensive_audit_paths.R")) {
		expect_true(file.copy(test_path("..", file), runner_dir))
	}

	empty_rows <- data.frame(
		inference_class = character(), function_run = character(), status = character(),
		result = numeric(), result_1 = numeric(), result_2 = numeric(), beta_T = numeric(),
		coverage_truth = numeric(), beta_T_in_confidence_interval = logical(), error_message = character()
	)
	n_valid <- 30L
	n_invalid <- 30L
	n_error <- 2L
	ci_rows <- data.frame(
		inference_class = rep("SyntheticNoOp", n_valid + n_invalid),
		function_run = rep("compute_asymp_confidence_interval", n_valid + n_invalid),
		status = rep("ok", n_valid + n_invalid),
		result = rep(NA_real_, n_valid + n_invalid),
		result_1 = c(rep(-1, n_valid), rep(NA_real_, n_invalid)),
		result_2 = c(rep(1, n_valid), rep(NA_real_, n_invalid)),
		beta_T = rep(0, n_valid + n_invalid),
		coverage_truth = rep(0.25, n_valid + n_invalid),
		beta_T_in_confidence_interval = c(rep(TRUE, n_valid), rep(NA, n_invalid)),
		error_message = rep("", n_valid + n_invalid)
	)
	error_rows <- data.frame(
		inference_class = rep("SyntheticNoOp", n_error),
		function_run = rep("compute_asymp_confidence_interval", n_error),
		status = rep("error", n_error),
		result = rep(NA_real_, n_error),
		result_1 = rep(NA_real_, n_error),
		result_2 = rep(NA_real_, n_error),
		beta_T = rep(0, n_error),
		coverage_truth = rep(0.25, n_error),
		beta_T_in_confidence_interval = rep(NA, n_error),
		error_message = rep("synthetic CI failure", n_error)
	)
	n_pvals <- 30L
	pval_rows <- data.frame(
		inference_class = rep("SyntheticNoOp", n_pvals),
		function_run = rep("compute_rand_two_sided_pval", n_pvals),
		status = rep("ok", n_pvals),
		result = rep(NA_real_, n_pvals),
		result_1 = (seq_len(n_pvals) - 0.5) / n_pvals,
		result_2 = rep(NA_real_, n_pvals),
		beta_T = rep(0, n_pvals),
		coverage_truth = rep(0.25, n_pvals),
		beta_T_in_confidence_interval = rep(NA, n_pvals),
		error_message = rep("", n_pvals)
	)
	paths <- stats::setNames(
		file.path(output_dir, paste0("comprehensive_tests_results_nc_1_", response_types, ".csv")),
		response_types
	)
	for (response_type in response_types) {
		rows <- if (identical(response_type, "survival")) {
			rbind(pval_rows, ci_rows, error_rows)
		} else {
			rbind(pval_rows, empty_rows)
		}
		utils::write.csv(rows, paths[[response_type]], row.names = FALSE, na = "NA")
	}

	script <- file.path(runner_dir, "audit_comprehensive_results.R")
	output <- suppressWarnings(system2(
		Sys.which("Rscript"),
		args = c(shQuote(script), "--write-baseline"),
		env = paste0("EDI_COMPREHENSIVE_RESULTS_DIR=", output_dir),
		stdout = TRUE,
		stderr = TRUE
	))
	status <- attr(output, "status")
	if (is.null(status)) status <- 0L
	expect_identical(status, 0L, info = paste(output, collapse = "\n"))

	baseline <- utils::read.csv(file.path(output_dir, "comprehensive_results_audit_baseline.csv"),
		check.names = FALSE, stringsAsFactors = FALSE)
	coverage_finding <- baseline[baseline$check == "low_coverage", , drop = FALSE]
	expect_equal(nrow(coverage_finding), 1L)
	expect_match(coverage_finding$detail, "coverage 0.484 over 62 rows, UNDER")

	attempts <- utils::read.csv(
		file.path(output_dir, "comprehensive_coverage_attempt_summary.csv"),
		check.names = FALSE, stringsAsFactors = FALSE
	)
	attempt <- attempts[
		attempts$response_type == "survival" & attempts$class == "SyntheticNoOp" &
			attempts$function_run == "compute_asymp_confidence_interval",
		, drop = FALSE
	]
	expect_equal(nrow(attempt), 1L)
	expect_equal(attempt$n_attempted, n_valid + n_invalid + n_error)
	expect_equal(attempt$n_covered, n_valid)
	expect_equal(attempt$n_invalid, n_invalid + n_error)
	expect_equal(attempt$coverage, n_valid / (n_valid + n_invalid + n_error))
	expect_equal(
		attempt$p_cov,
		stats::binom.test(n_valid, n_valid + n_invalid + n_error, p = 0.95)$p.value,
		tolerance = 1e-15
	)
})
