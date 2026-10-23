library(testthat)
library(EDI)

receipt_test_repo_root <- normalizePath(getwd(), mustWork = TRUE)
while (!file.exists(file.path(receipt_test_repo_root, "R/package_tests/comprehensive_run_provenance.R"))) {
	parent <- dirname(receipt_test_repo_root)
	if (identical(parent, receipt_test_repo_root)) stop("could not locate repository root for receipt test")
	receipt_test_repo_root <- parent
}
source(file.path(receipt_test_repo_root, "R/package_tests/comprehensive_run_provenance.R"))
source(file.path(receipt_test_repo_root, "R/package_tests/comprehensive_external_process_receipt.R"))

receipt_test_sha256 <- function(path) {
	command <- Sys.which("sha256sum")
	if (!nzchar(command)) stop("sha256sum is required for the independent receipt-hash check")
	line <- system2(command, shQuote(path), stdout = TRUE)
	strsplit(line[[1L]], "[[:space:]]+")[[1L]][[1L]]
}

test_that("external-process receipts pin command, PID, timestamps, logs, and exit status", {
	scratch <- withr::local_tempdir(tmpdir = "/tmp")
	receipt_path <- file.path(scratch, "receipt.rds")
	stdout_path <- file.path(scratch, "stdout.log")
	stderr_path <- file.path(scratch, "stderr.log")
	command <- file.path(R.home("bin"), "Rscript")
	args <- c(
		"-e",
		"cat('stdout-marker\\n'); cat('stderr-marker\\n', file=stderr()); quit(status=7)"
	)

	result <- run_comprehensive_external_process_with_receipt(
		command = command,
		args = args,
		receipt_path = receipt_path,
		stdout_path = stdout_path,
		stderr_path = stderr_path
	)

	receipt <- readRDS(receipt_path)
	expect_identical(result$exit_status, 7L)
	expect_identical(receipt$schema, "edi_external_process_receipt")
	expect_identical(receipt$schema_version, 1L)
	expect_identical(receipt$state, "completed")
	expect_identical(receipt$command, command)
	expect_identical(receipt$args, args)
	expect_null(receipt$env_overrides)
	expect_true(receipt$env_inherits_parent)
	expect_true(is.numeric(receipt$supervisor_pid) && length(receipt$supervisor_pid) == 1L && receipt$supervisor_pid > 0)
	expect_true(is.numeric(receipt$pid) && length(receipt$pid) == 1L && receipt$pid > 0)
	expect_true(receipt$started_at_utc < receipt$completed_at_utc)
	expect_identical(receipt$exit_status, 7L)
	expect_identical(readLines(stdout_path, warn = FALSE), "stdout-marker")
	expect_identical(readLines(stderr_path, warn = FALSE), "stderr-marker")
	expect_identical(receipt$stdout$sha256, receipt_test_sha256(stdout_path))
	expect_identical(receipt$stderr$sha256, receipt_test_sha256(stderr_path))
	expect_false(file.exists(paste0(receipt_path, ".running")))
	expect_error(
		run_comprehensive_external_process_with_receipt(
			command, args, receipt_path, stdout_path, stderr_path
		),
		"refusing to overwrite"
	)
})

test_that("external receipt CLI preserves explicit environment and child status", {
	scratch <- tempfile("edi-external-receipt-cli-", tmpdir = "/tmp")
	if (!dir.create(scratch)) stop("could not create isolated receipt CLI scratch directory")
	# Default to retaining diagnostics if any unexpected error interrupts the test.
	# Flip this only after every contract value below has been independently checked.
	keep_scratch <- TRUE
	withr::defer(if (!keep_scratch) unlink(scratch, recursive = TRUE), envir = environment())
	receipt_path <- file.path(scratch, "cli-receipt.rds")
	stdout_path <- file.path(scratch, "cli-stdout.log")
	stderr_path <- file.path(scratch, "cli-stderr.log")
	cli_path <- file.path(receipt_test_repo_root, "R/package_tests/run_comprehensive_with_receipt.R")
	command <- file.path(R.home("bin"), "Rscript")
	child_args <- c("-e", "cat(Sys.getenv('RECEIPT_TEST_MARKER')); quit(status=7)")
	env_override <- "RECEIPT_TEST_MARKER=receipt-env-visible"
	cli_args <- c(
		shQuote(cli_path),
		"--receipt", shQuote(receipt_path),
		"--stdout", shQuote(stdout_path),
		"--stderr", shQuote(stderr_path),
		"--env", shQuote(env_override),
		"--command", shQuote(command),
		vapply(child_args, shQuote, character(1L))
	)
	cli_output <- suppressWarnings(system2(
		file.path(R.home("bin"), "Rscript"),
		args = cli_args,
		stdout = TRUE,
		stderr = TRUE
	))

	cli_status <- as.integer(attr(cli_output, "status"))
	cli_diagnostic <- paste(cli_output, collapse = "\n")
	failure_info <- paste("CLI diagnostic directory:", scratch, "\nCLI stdout/stderr:", cli_diagnostic)
	expect_identical(cli_status, 7L, info = failure_info)
	expect_true(file.exists(receipt_path), info = failure_info)
	if (!file.exists(receipt_path)) {
		stop("receipt CLI did not create its receipt; retained diagnostics at ", scratch, call. = FALSE)
	}
	receipt <- readRDS(receipt_path)
	contract_checks <- c(
		status = identical(cli_status, 7L),
		state = identical(receipt$state, "completed"),
		command = identical(receipt$command, command),
		args = identical(receipt$args, child_args),
		env = identical(receipt$env_overrides, env_override),
		env_inherits_parent = identical(receipt$env_inherits_parent, TRUE),
		supervisor_pid = is.numeric(receipt$supervisor_pid) && length(receipt$supervisor_pid) == 1L && receipt$supervisor_pid > 0,
		exit_status = identical(receipt$exit_status, 7L),
		stdout = file.exists(stdout_path) && identical(readLines(stdout_path, warn = FALSE), "receipt-env-visible"),
		stdout_hash = file.exists(stdout_path) && identical(receipt$stdout$sha256, receipt_test_sha256(stdout_path)),
		stderr_hash = file.exists(stderr_path) && identical(receipt$stderr$sha256, receipt_test_sha256(stderr_path)),
		no_running_marker = !file.exists(paste0(receipt_path, ".running"))
	)
	keep_scratch <- !all(contract_checks)
	expect_identical(receipt$state, "completed", info = failure_info)
	expect_identical(receipt$command, command, info = failure_info)
	expect_identical(receipt$args, child_args, info = failure_info)
	expect_identical(receipt$env_overrides, env_override, info = failure_info)
	expect_true(receipt$env_inherits_parent, info = failure_info)
	expect_true(is.numeric(receipt$supervisor_pid) && length(receipt$supervisor_pid) == 1L && receipt$supervisor_pid > 0, info = failure_info)
	expect_identical(receipt$exit_status, 7L, info = failure_info)
	expect_identical(readLines(stdout_path, warn = FALSE), "receipt-env-visible", info = failure_info)
	expect_identical(receipt$stdout$sha256, receipt_test_sha256(stdout_path), info = failure_info)
	expect_identical(receipt$stderr$sha256, receipt_test_sha256(stderr_path), info = failure_info)
	expect_false(file.exists(paste0(receipt_path, ".running")), info = failure_info)
})

test_that("--env extends the parent environment instead of replacing it (2026-10-23)", {
	# Before the fix the child saw only the --env variables, lost HOME and
	# R_LIBS_USER, and could not load the installed EDI.
	scratch <- tempfile("edi-external-receipt-env-", tmpdir = "/tmp")
	if (!dir.create(scratch)) stop("could not create scratch directory")
	withr::defer(unlink(scratch, recursive = TRUE), envir = environment())
	withr::local_envvar(RECEIPT_TEST_INHERITED = "inherited-visible")
	stdout_path <- file.path(scratch, "out.log")
	receipt <- run_comprehensive_external_process_with_receipt(
		command = file.path(R.home("bin"), "Rscript"),
		args = c("-e", "cat(Sys.getenv('RECEIPT_TEST_INHERITED'), Sys.getenv('RECEIPT_TEST_ADDED'))"),
		receipt_path = file.path(scratch, "r.rds"),
		stdout_path = stdout_path,
		stderr_path = file.path(scratch, "err.log"),
		env = "RECEIPT_TEST_ADDED=added-visible"
	)
	expect_identical(receipt$exit_status, 0L)
	expect_identical(readLines(stdout_path, warn = FALSE), "inherited-visible added-visible")
})
