library(testthat)
library(EDI)

source(testthat::test_path("..", "comprehensive_run_provenance.R"), local = TRUE)
source(testthat::test_path("..", "validate_todo23_attempt_reconciliation.R"), local = TRUE)
source(testthat::test_path("..", "validate_todo14_candidate.R"), local = TRUE)
source(testthat::test_path("..", "validate_todo14_attempt_result_artifact.R"), local = TRUE)

test_that("TODO-14 post-run validation binds exact results, attempt lifecycle, values, and receipts", {
	fixture_dir <- tempfile("todo14-attempt-result-", tmpdir = "/tmp")
	expect_true(dir.create(fixture_dir))
	on.exit(unlink(fixture_dir, recursive = TRUE), add = TRUE)

	manifest <- data.frame(
		rep = c(1L, 1L), beta_T = c(0, 0.5), dataset = c("diamonds", "cars"),
		response_type = "survival", design = "KK21stepwise",
		inference_class = rep(.todo14_expected_classes[1L], 2L),
		function_run = c("compute_rand_two_sided_pval", "compute_rand_confidence_interval"),
		stringsAsFactors = FALSE
	)
	manifest$id <- .todo14_build_id(manifest)

	results_path <- file.path(fixture_dir, "results.csv")
	events_path <- file.path(fixture_dir, "attempts.csv")
	sidecar_path <- file.path(fixture_dir, "results.provenance.rds")
	results <- manifest
	results$run_row_id <- 1:2
	results$status <- "ok"
	results$error_message <- NA_character_
	results$skip_reason <- NA_character_
	results$method_family <- "rand"
	results$coverage_scope <- "comprehensive_workflow"
	results$argument_coverage_kind <- "not_argument_combination"
	results$github_commit_id <- paste(rep("a", 40L), collapse = "")
	results$timestamp <- "2026-10-21 12:00:00 UTC"
	results$result_1 <- c(0.25, -0.5)
	results$result_2 <- c(NA_real_, 0.7)
	results$coverage_truth <- c(0, 0.1)
	results$beta_T_in_confidence_interval <- c(NA, TRUE)

	event <- function(type, key, seq, status = NA_character_) {
		data.frame(
			event_seq = as.integer(seq), event_type = type,
			id = key$id, key[c(.todo14_key_columns)], status = status,
			skip_reason = if (type == "terminal") "" else NA_character_,
			error_message = NA_character_, stringsAsFactors = FALSE
		)
	}
	events <- do.call(rbind, list(
		event("started", manifest[1L, ], 1L), event("terminal", manifest[1L, ], 2L, "ok"),
		event("started", manifest[2L, ], 3L), event("terminal", manifest[2L, ], 4L, "ok")
	))
	utils::write.csv(results, results_path, row.names = FALSE, na = "")
	utils::write.csv(events, events_path, row.names = FALSE, na = "")

	identity <- function(path, sha) list(
		r_version = "R 4.5.0", edi_package_version = "1.0.3",
		edi_package_path = "/tmp/library/EDI", edi_namespace_path = "/tmp/library/EDI",
		edi_package_payload_path = "/tmp/checkout/R/EDI", edi_package_payload_sha256 = paste(rep("b", 64L), collapse = ""),
		edi_dll_path = "/tmp/library/EDI/libs/EDI.so", edi_dll_sha256 = paste(rep("c", 64L), collapse = ""),
		checkout_path = "/tmp/checkout", checkout_head = paste(rep("a", 40L), collapse = ""),
		checkout_status_porcelain = character(), checkout_diff_sha256 = paste(rep("d", 64L), collapse = ""),
		runner_path = "/tmp/checkout/R/package_tests/comprehensive_tests.R", runner_sha256 = paste(rep("e", 64L), collapse = ""),
		beta_filter_helper_path = "/tmp/checkout/R/package_tests/comprehensive_beta_filter.R", beta_filter_helper_sha256 = paste(rep("f", 64L), collapse = ""),
		provenance_helper_path = "/tmp/checkout/R/package_tests/comprehensive_run_provenance.R", provenance_helper_sha256 = paste(rep("1", 64L), collapse = "")
	)
	write_sidecar <- function() {
		result_id <- comprehensive_result_file_identity(results_path, include_sha256 = TRUE)
		attempt_id <- comprehensive_result_file_identity(events_path, include_sha256 = TRUE)
		before_after <- identity(NULL, NULL)
		provenance <- list(
			schema_version = 2L, results_file = normalizePath(results_path, winslash = "/"),
			command_args = c("40", "1", "survival"), results_file_before = list(exists = FALSE, bytes = 0, sha256 = NA_character_),
			results_file_after = result_id, started_at_utc = "2026-10-21T12:00:00.000000Z",
			completed_at_utc = "2026-10-21T12:01:00.000000Z",
			attempt_manifest = list(enabled = TRUE, path = normalizePath(events_path, winslash = "/"), identity = attempt_id),
			before = before_after, after = before_after
		)
		saveRDS(provenance, sidecar_path)
	}
	write_sidecar()
	expected_provenance <- list(
		checkout_sha = paste(rep("a", 40L), collapse = ""), r_version = "R 4.5.0",
		package_version = "1.0.3", library_path = "/tmp/library/EDI",
		dll_path = "/tmp/library/EDI/libs/EDI.so", dll_sha256 = paste(rep("c", 64L), collapse = "")
	)

	accepted <- validate_todo14_attempt_result_artifact(
		results_path, sidecar_path, events_path, manifest, expected_provenance
	)
	expect_equal(accepted$rows, 2L)
	expect_equal(accepted$attempt_events, 4L)
	expect_equal(as.integer(accepted$status_counts), c(2L, 0L))

	bad_expected <- manifest
	bad_expected$dataset[1L] <- NA_character_
	expect_error(
		validate_todo14_attempt_result_artifact(results_path, sidecar_path, events_path, bad_expected, expected_provenance),
		"missing or empty natural-key fields"
	)
	bad_started <- events
	bad_started$status[1L] <- "ok"
	utils::write.csv(bad_started, events_path, row.names = FALSE, na = "")
	write_sidecar()
	expect_error(
		validate_todo14_attempt_result_artifact(results_path, sidecar_path, events_path, manifest, expected_provenance),
		"started events must have no status"
	)
	utils::write.csv(events, events_path, row.names = FALSE, na = "")
	write_sidecar()

	error_results <- results
	error_results$status[1L] <- "error"
	error_results$error_message[1L] <- "synthetic captured error"
	error_results$skip_reason[1L] <- "error"
	error_results$result_1[1L] <- NA_real_
	error_results$result_2[1L] <- NA_real_
	error_events <- events
	error_events$status[2L] <- "error"
	utils::write.csv(error_results, results_path, row.names = FALSE, na = "")
	utils::write.csv(error_events, events_path, row.names = FALSE, na = "")
	write_sidecar()
	accepted_error <- validate_todo14_attempt_result_artifact(
		results_path, sidecar_path, events_path, manifest, expected_provenance
	)
	expect_equal(as.integer(accepted_error$status_counts), c(1L, 1L))

	utils::write.csv(results, results_path, row.names = FALSE, na = "")
	utils::write.csv(events, events_path, row.names = FALSE, na = "")
	write_sidecar()

	# The comprehensive producer records a timeout as status="ok" with the
	# exact timeout message/skip reason, but TODO-14 post-run acceptance
	# requires an actual p-value or CI for every eligible roster key.
	timeout_message <- "Skipped due to timeout after 60 seconds"
	timeout_results <- results
	timeout_results$error_message[1L] <- timeout_message
	timeout_results$skip_reason[1L] <- "timeout"
	timeout_results$result_1[1L] <- NA_real_
	timeout_results$result_2[1L] <- NA_real_
	timeout_events <- events
	timeout_events$skip_reason[2L] <- "timeout"
	timeout_events$error_message[2L] <- timeout_message
	utils::write.csv(timeout_results, results_path, row.names = FALSE, na = "")
	utils::write.csv(timeout_events, events_path, row.names = FALSE, na = "")
	write_sidecar()
	expect_error(
		validate_todo14_attempt_result_artifact(results_path, sidecar_path, events_path, manifest, expected_provenance),
		"timeout result rows cannot have status='ok'"
	)
	utils::write.csv(results, results_path, row.names = FALSE, na = "")
	utils::write.csv(events, events_path, row.names = FALSE, na = "")
	write_sidecar()
	utils::write.csv(results[-1L, , drop = FALSE], results_path, row.names = FALSE, na = "")
	write_sidecar()
	expect_error(
		validate_todo14_attempt_result_artifact(results_path, sidecar_path, events_path, manifest, expected_provenance),
		"key/method inventory mismatch"
	)
	utils::write.csv(results, results_path, row.names = FALSE, na = "")
	write_sidecar()

	bad_values <- results
	bad_values$result_1[1L] <- 1.01
	utils::write.csv(bad_values, results_path, row.names = FALSE, na = "")
	write_sidecar()
	expect_error(
		validate_todo14_attempt_result_artifact(results_path, sidecar_path, events_path, manifest, expected_provenance),
		"successful p-value rows have invalid result fields"
	)

	utils::write.csv(results, results_path, row.names = FALSE, na = "")
	events$status[2L] <- "error"
	utils::write.csv(events, events_path, row.names = FALSE, na = "")
	write_sidecar()
	expect_error(
		validate_todo14_attempt_result_artifact(results_path, sidecar_path, events_path, manifest, expected_provenance),
		"attempt event/result reconciliation"
	)

	events$status[2L] <- "ok"
	utils::write.csv(events, events_path, row.names = FALSE, na = "")
	write_sidecar()
	provenance <- readRDS(sidecar_path)
	provenance$attempt_manifest$identity$sha256 <- paste(rep("0", 64L), collapse = "")
	saveRDS(provenance, sidecar_path)
	expect_error(
		validate_todo14_attempt_result_artifact(results_path, sidecar_path, events_path, manifest, expected_provenance),
		"attempt manifest bytes or SHA-256"
	)
})
