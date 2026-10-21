library(testthat)
library(EDI)

source(testthat::test_path("..", "comprehensive_incidence_rand_pvalue_attempt_manifest.R"), local = TRUE)
source(testthat::test_path("..", "comprehensive_run_provenance.R"), local = TRUE)
source(testthat::test_path("..", "validate_todo23_attempt_reconciliation.R"), local = TRUE)

test_that("incidence rand expected keys distinguish rejected from skipped delta calls", {
	runner <- testthat::test_path("..", "comprehensive_tests.R")
	cases <- data.frame(
		rep = c(1L, 2L, 3L, 4L, 5L),
		beta_T = c(0, 0.5, 0, 0, 0.5),
		dataset = rep("pima", 5L),
		response_type = rep("incidence", 5L),
		design = c("Bernoulli", "KK21stepwise", "Bernoulli", "FixedBinaryMatch", "Bernoulli"),
		inference_class = paste0("fixture-class-", seq_len(5L)),
		supports_randomization_test = c(TRUE, TRUE, TRUE, TRUE, TRUE),
		test_family_filter = c(NA_character_, NA_character_, NA_character_, "asymp", NA_character_),
		skip_slow = rep(FALSE, 5L),
		skip_rand = c(FALSE, FALSE, TRUE, FALSE, FALSE),
		skip_regular_rand_pval = rep(FALSE, 5L),
		skip_rand_slow = rep(FALSE, 5L),
		skip_rand_delta_pval_slow = c(FALSE, TRUE, FALSE, FALSE, FALSE),
		has_custom_randomization_statistic_function = c(FALSE, FALSE, FALSE, FALSE, TRUE),
		stringsAsFactors = FALSE
	)
	manifest <- comprehensive_incidence_rand_pvalue_attempt_manifest(cases, runner)

	# This fixture pins the full runner natural key. The regular p-value is an
	# attempted call with runtime status left open; nonzero delta is an expected
	# safe_call error for the standard statistic, but is absent entirely when
	# the runner's delta slow-path flag skips the call. Custom statistics are
	# explicitly outside that public guard.
	expected <- data.frame(
		rep = c(1L, 1L, 2L, 5L, 5L),
		beta_T = c(0, 0, 0.5, 0.5, 0.5),
		dataset = rep("pima", 5L),
		response_type = rep("incidence", 5L),
		design = c("Bernoulli", "Bernoulli", "KK21stepwise", "Bernoulli", "Bernoulli"),
		inference_class = c("fixture-class-1", "fixture-class-1", "fixture-class-2",
			"fixture-class-5", "fixture-class-5"),
		function_run = c(
			"compute_rand_two_sided_pval",
			"compute_rand_two_sided_pval(delta=0.5)",
			"compute_rand_two_sided_pval",
			"compute_rand_two_sided_pval",
			"compute_rand_two_sided_pval(delta=0.5)"
		),
		expected_status = c(NA_character_, "error", NA_character_, NA_character_, NA_character_),
		expected_skip_reason = c(NA_character_, "error", NA_character_, NA_character_, NA_character_),
		stringsAsFactors = FALSE
	)
	expect_identical(manifest, expected)
	expect_true(comprehensive_incidence_rand_pvalue_source_guard(runner))
})

test_that("the incidence manifest rejects wrong response types and duplicate natural keys", {
	runner <- testthat::test_path("..", "comprehensive_tests.R")
	case <- data.frame(
		rep = 1L,
		beta_T = 0,
		dataset = "pima",
		response_type = "incidence",
		design = "Bernoulli",
		inference_class = "fixture-class",
		supports_randomization_test = TRUE,
		test_family_filter = NA_character_,
		skip_slow = FALSE,
		skip_rand = FALSE,
		skip_regular_rand_pval = FALSE,
		skip_rand_slow = FALSE,
		skip_rand_delta_pval_slow = FALSE,
		has_custom_randomization_statistic_function = FALSE,
		stringsAsFactors = FALSE
	)
	wrong_response <- case
	wrong_response$response_type <- "proportion"
	expect_error(
		comprehensive_incidence_rand_pvalue_attempt_manifest(wrong_response, runner),
		"all cases must have response_type = 'incidence'"
	)
	expect_error(
		comprehensive_incidence_rand_pvalue_attempt_manifest(rbind(case, case), runner),
		"duplicate source case key"
	)
	bad_rep <- case
	bad_rep$rep <- 1.5
	expect_error(
		comprehensive_incidence_rand_pvalue_attempt_manifest(bad_rep, runner),
		"case-manifest key fields must be non-missing"
	)
})

test_that("incidence rand artifact rows honor manifest expected status and skip reason", {
	runner <- testthat::test_path("..", "comprehensive_tests.R")
	cases <- data.frame(
		rep = c(1L, 2L), beta_T = c(0, 0.5), dataset = c("pima", "pima"),
		response_type = c("incidence", "incidence"), design = c("Bernoulli", "Bernoulli"),
		inference_class = c("standard", "standard"),
		supports_randomization_test = c(TRUE, TRUE), test_family_filter = c(NA_character_, NA_character_),
		skip_slow = c(FALSE, FALSE), skip_rand = c(FALSE, FALSE),
		skip_regular_rand_pval = c(FALSE, FALSE), skip_rand_slow = c(FALSE, FALSE),
		skip_rand_delta_pval_slow = c(FALSE, FALSE),
		has_custom_randomization_statistic_function = c(FALSE, FALSE),
		stringsAsFactors = FALSE
	)
	manifest <- comprehensive_incidence_rand_pvalue_attempt_manifest(cases, runner)
	result_rows <- manifest[c("rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run")]
	result_rows$status <- ifelse(is.na(manifest$expected_status), "ok", manifest$expected_status)
	result_rows$skip_reason <- ifelse(is.na(manifest$expected_skip_reason), "", manifest$expected_skip_reason)

	expect_no_error(validate_comprehensive_incidence_rand_pvalue_expected_outcomes(manifest, result_rows))

	delta_row <- which(manifest$function_run == "compute_rand_two_sided_pval(delta=0.5)")
	incorrect_status <- result_rows
	incorrect_status$status[delta_row] <- "ok"
	expect_error(
		validate_comprehensive_incidence_rand_pvalue_expected_outcomes(manifest, incorrect_status),
		"status violates expected_status"
	)

	incorrect_reason <- result_rows
	incorrect_reason$skip_reason[delta_row] <- "unsupported"
	expect_error(
		validate_comprehensive_incidence_rand_pvalue_expected_outcomes(manifest, incorrect_reason),
		"skip_reason violates expected_skip_reason"
	)
})

test_that("incidence rand artifact wrapper enforces expected outcomes after receipt and key validation", {
	fixture_dir <- tempfile("incidence-rand-artifact-", tmpdir = "/tmp")
	expect_true(dir.create(fixture_dir))
	on.exit(unlink(fixture_dir, recursive = TRUE), add = TRUE)

	manifest <- data.frame(
		rep = c(1L, 1L), beta_T = c(0, 0.5), dataset = c("pima", "pima"),
		response_type = c("incidence", "incidence"), design = c("Bernoulli", "Bernoulli"),
		inference_class = c("standard", "standard"),
		function_run = c("compute_rand_two_sided_pval", "compute_rand_two_sided_pval(delta=0.5)"),
		expected_status = c(NA_character_, "error"),
		expected_skip_reason = c(NA_character_, "error"), stringsAsFactors = FALSE
	)
	results_path <- file.path(fixture_dir, "results.csv")
	sidecar_path <- file.path(fixture_dir, "results.provenance.rds")
	result_rows <- manifest[c(
		"rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run"
	)]
	result_rows$status <- c("ok", "error")
	result_rows$error_message <- c(NA_character_, "delta is unsupported for this statistic")
	result_rows$skip_reason <- c("", "error")
	result_rows$result_1 <- c(0.25, NA_real_)
	result_rows$result_2 <- c(NA_real_, NA_real_)
	events_path <- file.path(fixture_dir, "attempts.csv")
	make_events <- function(rows) {
		key_columns <- c("rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run")
		rows <- rows[c(key_columns, "status")]
		pieces <- lapply(seq_len(nrow(rows)), function(i) {
			data.frame(
				event_seq = c(2L * i - 1L, 2L * i),
				event_type = c("started", "terminal"),
				id = NA_character_,
				rep = rep(rows$rep[i], 2L), beta_T = rep(rows$beta_T[i], 2L),
				dataset = rep(rows$dataset[i], 2L), response_type = rep(rows$response_type[i], 2L),
				design = rep(rows$design[i], 2L),
				model_formula = NA_character_,
				inference_class = rep(rows$inference_class[i], 2L),
				function_run = rep(rows$function_run[i], 2L),
				status = c(NA_character_, as.character(rows$status[i])),
				skip_reason = NA_character_, error_message = NA_character_,
				stringsAsFactors = FALSE
			)
		})
		do.call(rbind, pieces)
	}

	identity <- function() list(
		r_version = "R test fixture", edi_package_version = "1.0.3",
		edi_package_path = "/tmp/library/EDI", edi_namespace_path = "/tmp/library/EDI",
		edi_package_payload_path = "/tmp/checkout/R/EDI",
		edi_package_payload_sha256 = paste(rep("b", 64L), collapse = ""),
		edi_dll_path = "/tmp/library/EDI/libs/EDI.so",
		edi_dll_sha256 = paste(rep("c", 64L), collapse = ""),
		checkout_path = "/tmp/checkout", checkout_head = paste(rep("a", 40L), collapse = ""),
		checkout_status_porcelain = character(),
		checkout_diff_sha256 = paste(rep("d", 64L), collapse = ""),
		runner_path = "/tmp/checkout/R/package_tests/comprehensive_tests.R",
		runner_sha256 = paste(rep("e", 64L), collapse = ""),
		beta_filter_helper_path = "/tmp/checkout/R/package_tests/comprehensive_beta_filter.R",
		beta_filter_helper_sha256 = paste(rep("f", 64L), collapse = ""),
		provenance_helper_path = "/tmp/checkout/R/package_tests/comprehensive_run_provenance.R",
		provenance_helper_sha256 = paste(rep("1", 64L), collapse = "")
	)
	write_artifact <- function(rows, events = make_events(rows)) {
		utils::write.csv(rows, results_path, row.names = FALSE, na = "")
		utils::write.csv(events, events_path, row.names = FALSE, na = "")
		provenance <- list(
			schema_version = 2L, results_file = normalizePath(results_path, winslash = "/"),
			command_args = character(), results_file_before = list(exists = FALSE, bytes = 0, sha256 = NA_character_),
			results_file_after = comprehensive_result_file_identity(results_path, include_sha256 = TRUE),
			attempt_manifest = list(enabled = TRUE,
				path = normalizePath(events_path, winslash = "/"),
				identity = comprehensive_result_file_identity(events_path, include_sha256 = TRUE)),
			started_at_utc = "2026-10-21T12:00:00.000000Z",
			completed_at_utc = "2026-10-21T12:01:00.000000Z",
			before = identity(), after = identity()
		)
		saveRDS(provenance, sidecar_path)
	}

	write_artifact(result_rows)
	validated <- validate_comprehensive_incidence_rand_pvalue_result_artifact(
		results_path, sidecar_path, manifest, events_path
	)
	expect_equal(validated$attempt_events, 4L)
	expect_equal(validated$unkeyed_setup_events, 0L)

	setup_context <- data.frame(
		event_seq = 5L, event_type = "setup_skipped", id = NA_character_, rep = 1L, beta_T = 0,
		dataset = "pima", response_type = "incidence", design = "Bernoulli",
		model_formula = "~1", inference_class = NA_character_, function_run = NA_character_,
		status = NA_character_, skip_reason = NA_character_, error_message = "fixture setup failed",
		stringsAsFactors = FALSE
	)
	write_artifact(result_rows, rbind(make_events(result_rows), setup_context))
	validated_with_setup_context <- validate_comprehensive_incidence_rand_pvalue_result_artifact(
		results_path, sidecar_path, manifest, events_path
	)
	expect_equal(validated_with_setup_context$unkeyed_setup_events, 1L)
	setup_failure_context <- setup_context
	setup_failure_context$event_type <- "setup_failure"
	setup_failure_context$function_run <- "run_tests_for_response"
	setup_failure_context$status <- "error"
	write_artifact(result_rows, rbind(make_events(result_rows), setup_failure_context))
	validated_with_setup_failure <- validate_comprehensive_incidence_rand_pvalue_result_artifact(
		results_path, sidecar_path, manifest, events_path
	)
	expect_equal(validated_with_setup_failure$unkeyed_setup_events, 1L)
	missing_setup_formula <- setup_context
	missing_setup_formula$model_formula <- NA_character_
	write_artifact(result_rows, rbind(make_events(result_rows), missing_setup_formula))
	expect_error(
		validate_comprehensive_incidence_rand_pvalue_result_artifact(
			results_path, sidecar_path, manifest, events_path
		),
		"setup events have incomplete context or invalid lifecycle fields"
	)
	malformed_setup_status <- setup_context
	malformed_setup_status$status <- "error"
	write_artifact(result_rows, rbind(make_events(result_rows), malformed_setup_status))
	expect_error(
		validate_comprehensive_incidence_rand_pvalue_result_artifact(
			results_path, sidecar_path, manifest, events_path
		),
		"setup events have incomplete context or invalid lifecycle fields"
	)

	missing_terminal <- make_events(result_rows)
	missing_terminal <- missing_terminal[missing_terminal$event_type != "terminal" | missing_terminal$rep != 1L | missing_terminal$beta_T != 0.5, , drop = FALSE]
	write_artifact(result_rows, missing_terminal)
	expect_error(
		validate_comprehensive_incidence_rand_pvalue_result_artifact(results_path, sidecar_path, manifest, events_path),
		"do not reconcile"
	)

	incorrect_status <- result_rows
	incorrect_status$status[2L] <- "ok"
	incorrect_status$error_message[2L] <- ""
	incorrect_status$skip_reason[2L] <- ""
	write_artifact(incorrect_status)
	expect_error(
		validate_comprehensive_incidence_rand_pvalue_result_artifact(results_path, sidecar_path, manifest, events_path),
		"status violates expected_status"
	)
})
