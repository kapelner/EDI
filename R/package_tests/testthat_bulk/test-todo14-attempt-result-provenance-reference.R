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
	skipped_candidates <- data.frame(
		rep = c(1L, 1L, 1L), beta_T = c(0.5, 0.5, 0.5), dataset = c("airquality", "boston", "fuel"),
		response_type = "survival", design = "KK21stepwise",
		inference_class = rep(.todo14_expected_classes[1L], 3L),
		function_run = c("compute_rand_two_sided_pval", "compute_rand_confidence_interval", "compute_rand_two_sided_pval(delta=0.5)"),
		stringsAsFactors = FALSE
	)
	skipped_candidates$id <- .todo14_build_id(skipped_candidates)
	candidate_manifest <- rbind(manifest, skipped_candidates)
	candidate_manifest$candidate_status <- "candidate_only_requires_setup_and_runtime_eligibility"
	candidate_manifest$scope_source <- "checked_in_runner_defaults_without_cli_filters"
	eligibility_manifest <- candidate_manifest[c("id", .todo14_key_columns)]
	eligibility_manifest$eligibility <- c("attempt", "attempt", "skipped_completed", "skipped_slow", "skipped_confirmed_timeout")

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
			skip_reason = switch(type,
				skipped_completed = "completed_cache", skipped_slow = "slow_path",
				skipped_confirmed_timeout = "confirmed_timeout_cache", ""),
			error_message = NA_character_, stringsAsFactors = FALSE
		)
	}
	events <- do.call(rbind, list(
		event("started", manifest[1L, ], 1L), event("terminal", manifest[1L, ], 2L, "ok"),
		event("started", manifest[2L, ], 3L), event("terminal", manifest[2L, ], 4L, "ok"),
		event("skipped_completed", skipped_candidates[1L, ], 5L),
		event("skipped_slow", skipped_candidates[2L, ], 6L),
		event("skipped_confirmed_timeout", skipped_candidates[3L, ], 7L)
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
	validate_artifact <- function(expected = manifest, candidates = candidate_manifest, eligibility = eligibility_manifest) {
		validate_todo14_attempt_result_artifact(
			results_path, sidecar_path, events_path, expected, expected_provenance,
			candidate_manifest = candidates, eligibility_manifest = eligibility
		)
	}

	accepted <- validate_artifact()
	expect_equal(accepted$rows, 2L)
	expect_equal(accepted$attempt_events, 7L)
	expect_equal(as.integer(accepted$status_counts), c(2L, 0L))
	expect_equal(accepted$eligibility$attempt_count, 2L)
	expect_equal(as.integer(accepted$eligibility$runtime_skip_counts), c(1L, 1L, 1L))
	expect_equal(accepted$eligibility$runtime_skips$eligibility,
		c("skipped_completed", "skipped_slow", "skipped_confirmed_timeout"))
	expect_equal(accepted$eligibility$runtime_skips$event_seq, 5:7)
	expect_error(
		validate_todo14_attempt_result_artifact(results_path, sidecar_path, events_path, manifest, expected_provenance),
		"candidate_manifest and explicit eligibility_manifest are required"
	)
	expect_error(validate_artifact(candidate_manifest), "key/method inventory mismatch")

	missing_skip <- events[-5L, , drop = FALSE]
	utils::write.csv(missing_skip, events_path, row.names = FALSE, na = "")
	write_sidecar()
	expect_error(validate_artifact(), "exactly one matching keyed skip event")
	utils::write.csv(events, events_path, row.names = FALSE, na = "")
	write_sidecar()
	bad_skip_reason <- events
	bad_skip_reason$skip_reason[5L] <- "slow_path"
	utils::write.csv(bad_skip_reason, events_path, row.names = FALSE, na = "")
	write_sidecar()
	expect_error(validate_artifact(), "reason does not match its runner skip classification")
	utils::write.csv(events, events_path, row.names = FALSE, na = "")
	write_sidecar()
	setup_event <- event("setup_failure", manifest[1L, ], 8L)
	setup_event$id <- NA_character_
	for (column in .todo14_key_columns) setup_event[[column]] <- NA
	utils::write.csv(rbind(events, setup_event), events_path, row.names = FALSE, na = "")
	write_sidecar()
	expect_error(validate_artifact(), "unmapped setup-level event")
	utils::write.csv(events, events_path, row.names = FALSE, na = "")
	write_sidecar()

	bad_expected <- manifest
	bad_expected$dataset[1L] <- NA_character_
	expect_error(
		validate_artifact(bad_expected),
		"missing or empty natural-key fields"
	)
	bad_started <- events
	bad_started$status[1L] <- "ok"
	utils::write.csv(bad_started, events_path, row.names = FALSE, na = "")
	write_sidecar()
	expect_error(
		validate_artifact(),
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
	accepted_error <- validate_artifact()
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
		validate_artifact(),
		"timeout result rows cannot have status='ok'"
	)
	utils::write.csv(results, results_path, row.names = FALSE, na = "")
	utils::write.csv(events, events_path, row.names = FALSE, na = "")
	write_sidecar()
	utils::write.csv(results[-1L, , drop = FALSE], results_path, row.names = FALSE, na = "")
	write_sidecar()
	expect_error(
		validate_artifact(),
		"key/method inventory mismatch"
	)
	utils::write.csv(results, results_path, row.names = FALSE, na = "")
	write_sidecar()

	bad_values <- results
	bad_values$result_1[1L] <- 1.01
	utils::write.csv(bad_values, results_path, row.names = FALSE, na = "")
	write_sidecar()
	expect_error(
		validate_artifact(),
		"successful p-value rows have invalid result fields"
	)

	utils::write.csv(results, results_path, row.names = FALSE, na = "")
	events$status[2L] <- "error"
	utils::write.csv(events, events_path, row.names = FALSE, na = "")
	write_sidecar()
	expect_error(
		validate_artifact(),
		"attempt event/result reconciliation"
	)

	events$status[2L] <- "ok"
	utils::write.csv(events, events_path, row.names = FALSE, na = "")
	write_sidecar()
	provenance <- readRDS(sidecar_path)
	provenance$attempt_manifest$identity$sha256 <- paste(rep("0", 64L), collapse = "")
	saveRDS(provenance, sidecar_path)
	expect_error(
		validate_artifact(),
		"attempt manifest bytes or SHA-256"
	)
})

# 2026-10-22 (G6 #33, G4-C runbook R5): setup_skipped events for the approved
# FixedBinaryMatch x pte_example x ~1 contexts reconcile to the approved keys.
test_that("TODO-14 attempt reconciliation maps approved setup skips and nothing else", {
	approved <- expand.grid(
		rep = 1:2, beta_T = 0.5, dataset = "pte_example", response_type = "survival",
		design = "FixedBinaryMatch", inference_class = .todo14_expected_classes[1L],
		function_run = .todo14_expected_functions, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
	)
	approved$id <- .todo14_build_id(approved)
	attempted <- data.frame(
		rep = 1L, beta_T = 0.5, dataset = "pte_example", response_type = "survival",
		design = "FixedBinaryMatch", inference_class = .todo14_expected_classes[2L],
		function_run = "compute_rand_two_sided_pval", stringsAsFactors = FALSE
	)
	attempted$id <- .todo14_build_id(attempted)
	candidate_manifest <- rbind(attempted, approved[names(attempted)])
	candidate_manifest$candidate_status <- "candidate_only_requires_setup_and_runtime_eligibility"
	candidate_manifest$scope_source <- "checked_in_runner_defaults_without_cli_filters"
	eligibility <- candidate_manifest[c("id", .todo14_key_columns)]
	eligibility$eligibility <- ifelse(eligibility$id %in% approved$id, "approved_setup_skip", "attempt")

	op_event <- function(type, seq, status = NA_character_) data.frame(
		event_seq = seq, event_type = type, id = attempted$id, attempted[.todo14_key_columns],
		model_formula = "~.", status = status, skip_reason = NA_character_, error_message = NA_character_,
		stringsAsFactors = FALSE
	)
	setup_event <- function(rep, seq, type = "setup_skipped", formula = "~1") data.frame(
		event_seq = seq, event_type = type, id = NA_character_, rep = rep, beta_T = 0.5,
		dataset = "pte_example", response_type = "survival", design = "FixedBinaryMatch",
		inference_class = NA_character_, function_run = NA_character_, model_formula = formula,
		status = NA_character_, skip_reason = NA_character_,
		error_message = "FixedBinaryMatch setup needs matched-pair ids", stringsAsFactors = FALSE
	)
	events <- rbind(op_event("started", 1L), op_event("terminal", 2L, "ok"), setup_event(1L, 3L), setup_event(2L, 4L))
	results <- attempted
	results$status <- "ok"
	expected <- attempted
	reconcile <- function(ev, skips = approved, elig = eligibility) .todo14_reconcile_candidate_eligibility(
		candidate_manifest, elig, expected, ev, results,
		approved_skips = skips
	)

	ok <- reconcile(events)
	expect_equal(ok$attempt_count, 1L)
	expect_equal(ok$approved_skip_count, 6L)
	expect_length(ok$approved_setup_skip_contexts, 2L)
	expect_equal(sum(ok$runtime_skip_counts), 0L)

	# The approved_setup_skip disposition is illegal without approved_skips
	# (setup events without approval keep failing closed: test above).
	expect_error(reconcile(events, skips = NULL), "must equal exactly the approved_skips keys")
	# A setup skip outside the approved contexts (here the ~. arm), a
	# setup_failure, a missing or duplicated setup event all fail closed.
	expect_error(reconcile(rbind(events, setup_event(1L, 5L, formula = "~."))), "unmapped setup-level")
	expect_error(reconcile(rbind(events, setup_event(1L, 5L, type = "setup_failure"))), "unmapped setup-level")
	expect_error(reconcile(events[-4L, ]), "exactly one setup_skipped event")
	expect_error(reconcile(rbind(events, setup_event(2L, 5L))), "exactly one setup_skipped event")
	expect_error(reconcile(events[1:2, ]), "no setup_skipped event")
	# An approved key may not also have operation events, and the
	# approved_setup_skip disposition must match approved_skips exactly.
	stray_op <- op_event("started", 6L)
	stray_op$id <- approved$id[1L]
	stray_op[.todo14_key_columns] <- approved[1L, .todo14_key_columns]
	expect_error(reconcile(rbind(events, stray_op)), "must have no operation events")
	expect_error(reconcile(events, skips = approved[-1L, ]), "must equal exactly the approved_skips keys")
})
