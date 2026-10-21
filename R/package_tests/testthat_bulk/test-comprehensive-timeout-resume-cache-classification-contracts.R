library(testthat)
library(EDI)

source(test_path("..", "comprehensive_result_cache_classification.R"), local = TRUE)
source(test_path("..", "comprehensive_results_path.R"), local = TRUE)

test_that("resumed cache separates exact timeout rows from other completed outcomes", {
	results = data.frame(
		id = paste0("row-", seq_len(8L)),
		status = c("ok", "ok", "ok", "ok", "ok", "ok", "error", "error"),
		error_message = c(
			"Skipped due to timeout after 60 seconds",
			"Skipped due to timeout after 120 seconds (outer safe_call guard)",
			"Skipped due to timeout after 1 seconds",
			"Explicitly non-estimable for this inference method",
			"timeout noted in diagnostic text but not a timeout outcome",
			NA_character_,
			"Skipped due to timeout after 60 seconds",
			"ordinary recorded error"
		),
		stringsAsFactors = FALSE
	)

	classified = classify_comprehensive_existing_result_rows(results)

	# These exact runner-emitted messages are retryable; the independent expected
	# classification keeps every other status=ok outcome completed and excludes
	# status=error rows from both caches.
	expect_identical(classified$confirmed_timeout_rows, 1:3)
	expect_identical(classified$completed_rows, 4:6)
	expect_length(intersect(classified$completed_rows, classified$confirmed_timeout_rows), 0L)
	expect_false(any(c(7L, 8L) %in% c(classified$completed_rows, classified$confirmed_timeout_rows)))

	# A timeout-like phrase must be anchored and match the runner's exact wording;
	# optional outer-guard suffix is the only accepted trailing text.
	near_misses = data.frame(
		status = rep("ok", 4L),
		error_message = c(
			"prefix: Skipped due to timeout after 60 seconds",
			"Skipped due to timeout after 60 seconds (other guard)",
			"Skipped due to timeout after 30 seconds",
			"Skipped due to timeout after 60 seconds extra"
		),
		stringsAsFactors = FALSE
	)
	near_miss_classification = classify_comprehensive_existing_result_rows(near_misses)
	expect_identical(near_miss_classification$confirmed_timeout_rows, integer())
	expect_identical(near_miss_classification$completed_rows, 1:4)
})

test_that("legacy rows without status preserve completed-row fallback", {
	legacy = data.frame(id = c("legacy-1", "legacy-2"), stringsAsFactors = FALSE)
	expect_identical(
		classify_comprehensive_existing_result_rows(legacy),
		list(completed_rows = 1:2, confirmed_timeout_rows = integer())
	)
})

test_that("the opt-in attempt event ledger preserves operation and setup outcomes", {
	scratch = tempfile("edi-attempt-events-")
	dir.create(scratch)
	on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
	results_file = file.path(scratch, "results.csv")
	manifest_file = file.path(scratch, "attempt-events.csv")
	writer = new_comprehensive_attempt_manifest_writer(
		manifest_file,
		results_file = results_file,
		checkout_root = test_path("..", "..", "..")
	)

	key = list(
		id = "1||2.50000000000000000e-01||cars||count||KK21||CountKKGLMM (model_formula=~1)||compute_estimate",
		rep = 1L,
		beta_T = 0.25,
		dataset = "cars",
		response_type = "count",
		design = "KK21",
		inference_class = "InferenceCountKKGLMM (model_formula=~1)",
		function_run = "compute_estimate"
	)
	writer("started", key)
	writer("terminal", key, status = "ok")
	writer("started", key)
	writer("terminal", key, status = "error", skip_reason = "error", error_message = "fit failed")
	writer("started", key)
	writer(
		"terminal", key, status = "ok", skip_reason = "timeout",
		error_message = "Skipped due to timeout after 120 seconds"
	)
	writer("skipped_completed", key, skip_reason = "completed_cache")
	writer("skipped_slow", key, skip_reason = "slow_path")
	writer("skipped_confirmed_timeout", key, skip_reason = "confirmed_timeout_cache")
	writer(
		"setup_skipped",
		list(rep = 7L, beta_T = 0.5, dataset = "cars", response_type = "count", design = "KK21",
			model_formula = "~."),
		skip_reason = "setup_skipped", error_message = "design assignment failed"
	)
	writer(
		"setup_failure",
		list(rep = 7L, beta_T = 0.5, dataset = "cars", response_type = "count", design = "KK21",
			model_formula = "~1", function_run = "run_tests_for_response"),
		status = "error", skip_reason = "error", error_message = "response setup failed"
	)

	events = utils::read.csv(manifest_file, stringsAsFactors = FALSE, na.strings = "")
	expect_identical(events$event_seq, seq_len(11L))
	expect_identical(events$event_type, c(
		"started", "terminal", "started", "terminal", "started", "terminal",
		"skipped_completed", "skipped_slow", "skipped_confirmed_timeout",
		"setup_skipped", "setup_failure"
	))
	expect_identical(events$status[c(2L, 4L, 6L, 11L)], c("ok", "error", "ok", "error"))
	expect_identical(events$skip_reason[6L], "timeout")
	expect_identical(events$error_message[6L], "Skipped due to timeout after 120 seconds")
	expect_identical(events$id[1L], key$id)
	expect_true(is.na(events$id[10L]))
	expect_identical(events$model_formula[10L], "~.")
	expect_identical(events$rep[11L], 7L)
	expect_identical(events$beta_T[11L], 0.5)
	expect_identical(events$model_formula[11L], "~1")
	expect_identical(names(events), c(
		"event_seq", "event_type", "id", "rep", "beta_T", "dataset", "response_type",
		"design", "model_formula", "inference_class", "function_run", "status", "skip_reason",
		"error_message", "event_epoch"
	))

	# The ledger is a separate, one-run artifact: it cannot overwrite a previous
	# run or alias the results CSV, and no attempt columns enter the result schema.
	expect_error(
		new_comprehensive_attempt_manifest_writer(manifest_file),
		"refusing to overwrite"
	)
	expect_error(
		new_comprehensive_attempt_manifest_writer(results_file, results_file = results_file),
		"separate from the comprehensive results CSV"
	)
})

test_that("the runner emits ledger events at live safe-call and setup boundaries", {
	runner = paste(readLines(test_path("..", "comprehensive_tests.R"), warn = FALSE), collapse = "\n")
	for (event in c("started", "terminal", "skipped_completed", "skipped_slow", "skipped_confirmed_timeout", "setup_skipped", "setup_failure")) {
		expect_true(grepl(paste0('"', event, '"'), runner, fixed = TRUE), info = event)
	}
	expect_true(grepl('Sys.getenv("EDI_COMPREHENSIVE_ATTEMPT_MANIFEST", unset = "")', runner, fixed = TRUE))
	expect_true(grepl('skip_reason = skip_reason_for_result(status, error_message_chr)', runner, fixed = TRUE))

	runner_lines = readLines(test_path("..", "comprehensive_tests.R"), warn = FALSE)
	setup_failure_line = grep('"setup_failure", function_run = "run_tests_for_response"', runner_lines, fixed = TRUE)
	expect_length(setup_failure_line, 1L)
	setup_failure_call = paste(runner_lines[setup_failure_line:(setup_failure_line + 7L)], collapse = "\n")
	expect_true(grepl("rep_value = rep_curr, beta_value = beta_T", setup_failure_call, fixed = TRUE))
	expect_true(grepl('model_formula_value = paste(deparse(model_formula), collapse = " ")', setup_failure_call, fixed = TRUE))
	setup_skipped_lines = grep('"setup_skipped", error_message = conditionMessage(', runner_lines, fixed = TRUE)
	expect_length(setup_skipped_lines, 3L)
	for (line in setup_skipped_lines) {
		setup_skipped_call = paste(runner_lines[line:(line + 7L)], collapse = "\n")
		expect_true(grepl("rep_value = rep_curr, beta_value = beta_T", setup_skipped_call, fixed = TRUE))
		expect_true(grepl('model_formula_value = paste(deparse(design_formula), collapse = " ")', setup_skipped_call, fixed = TRUE))
	}
	row_start = grep("results_dt <<- data.table::rbindlist\\(list\\(", runner_lines)
	row_end = grep("\\), use.names = TRUE\\)", runner_lines)
	row_end = row_end[row_end > row_start[[1L]]][[1L]]
	result_row_construction = paste(runner_lines[row_start[[1L]]:row_end], collapse = "\n")
	expect_false(grepl("attempt_manifest", result_row_construction, fixed = TRUE))
})
