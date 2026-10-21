library(testthat)

# This standalone pure-R audit utility has no EDI namespace/native dependency;
# keeping this test package-load-free lets it run without an install/build.
source(testthat::test_path("..", "validate_todo23_attempt_reconciliation.R"), local = TRUE)

test_that("TODO-23 exact-key reconciliation exposes missing, extra, and duplicate rows", {
	key <- data.frame(
		rep = c(1L, 2L, 3L), beta_T = c(0, 0, 0), dataset = c("fit", "missing", "retry"),
		response_type = "survival", design = "Bernoulli", inference_class = "RMST",
		function_run = "compute_wald_confidence_interval", stringsAsFactors = FALSE
	)
	results <- rbind(key[1, ], key[1, ], key[3, ])
	results$status <- c("ok", "ok", "error")
	extra <- transform(key[3, ], dataset = "unexpected")
	extra$status <- "ok"
	results <- rbind(results, extra)

	reconciliation <- reconcile_todo23_attempts(
		key, data.frame(event_type = character(), status = character(), rep = integer(), beta_T = numeric(),
			dataset = character(), response_type = character(), design = character(),
			inference_class = character(), function_run = character()),
		results, key_columns = names(key)[1:6]
	)
	expect_identical(reconciliation$result_missing$dataset, "missing")
	expect_identical(reconciliation$result_extra$dataset, "unexpected")
	expect_identical(reconciliation$result_duplicates$dataset, "fit")
	expect_identical(reconciliation$result_duplicates$rows, 2L)
	fit_counts <- reconciliation$terminal_result_counts[reconciliation$terminal_result_counts$dataset == "fit", ]
	expect_equal(fit_counts$terminal_events, 0L)
	expect_equal(fit_counts$result_rows, 2L)
	fit_status <- reconciliation$terminal_status_mismatches[
		reconciliation$terminal_status_mismatches$dataset == "fit", , drop = FALSE
	]
	expect_equal(nrow(fit_status), 0L)
	expect_identical(sort(reconciliation$result_without_terminal$dataset), c("fit", "fit", "retry", "unexpected"))
	expect_equal(nrow(reconciliation$terminal_without_result), 0L)
})

test_that("TODO-23 event reconciliation allows completed retries but flags open and orphan attempts", {
	key <- data.frame(
		rep = c(1L, 2L, 3L, 4L, 5L, 6L, 7L), beta_T = rep(0, 7L),
		dataset = c("retry", "open", "no-event", "start-open", "status-mismatch", "result-only", "overlap"),
		response_type = "survival", design = "Bernoulli", inference_class = "RMST",
		function_run = "compute_wald_confidence_interval", stringsAsFactors = FALSE
	)
	event <- function(type, rep, dataset, seq) data.frame(
		event_seq = as.integer(seq), event_type = type,
		status = if (identical(type, "terminal")) "ok" else NA_character_,
		rep = as.integer(rep), beta_T = 0,
		dataset = dataset, response_type = "survival", design = "Bernoulli",
		inference_class = "RMST", function_run = "compute_wald_confidence_interval",
		stringsAsFactors = FALSE
	)
	events <- do.call(rbind, list(
		event("started", 1L, "retry", 1L), event("terminal", 1L, "retry", 2L),
		event("started", 1L, "retry", 3L), event("terminal", 1L, "retry", 4L),
		event("started", 2L, "open", 5L), event("terminal", 2L, "open", 6L),
		event("terminal", 2L, "open", 7L), event("started", 4L, "start-open", 8L),
		event("started", 5L, "unexpected", 9L), event("terminal", 5L, "unexpected", 10L),
		event("started", 5L, "status-mismatch", 11L),
		transform(event("terminal", 5L, "status-mismatch", 12L), status = "error"),
		# A second start before the first terminal is an overlapping, unclosed
		# attempt—not a valid completed retry, even though the final counts balance.
		event("started", 7L, "overlap", 13L), event("started", 7L, "overlap", 14L),
		event("terminal", 7L, "overlap", 15L),
		# Setup outcomes have no operation key and must remain visible without
		# being misclassified as missing/extra keyed inference attempts.
		transform(event("setup_failure", NA_integer_, "setup", 16L), status = "error"),
		transform(event("setup_skipped", NA_integer_, "setup-skip", 17L), status = "skipped")
	))
	results <- rbind(
		key[1L, ], key[1L, ], key[2L, ],
		transform(key[5L, ], rep = 5L),
		transform(key[6L, ], rep = 6L), key[7L, ]
	)
	results$status <- c("ok", "ok", "ok", "ok", "ok", "ok")
	reconciliation <- reconcile_todo23_attempts(key, events, results, names(key)[1:6])

	expect_identical(sort(reconciliation$event_missing$dataset), c("no-event", "result-only"))
	expect_identical(reconciliation$event_extra$dataset, "unexpected")
	expect_identical(reconciliation$unkeyed_event_rows, c(16L, 17L))
	retry_state <- reconciliation$event_state[reconciliation$event_state$dataset == "retry", ]
	expect_identical(retry_state$retries, 1L)
	expect_identical(retry_state$unclosed_starts, 0L)
	open_state <- reconciliation$event_state[reconciliation$event_state$dataset == "open", ]
	expect_identical(open_state$unclosed_starts, 0L)
	expect_identical(open_state$orphan_terminals, 1L)
	start_state <- reconciliation$event_state[reconciliation$event_state$dataset == "start-open", ]
	expect_identical(start_state$unclosed_starts, 1L)
	overlap_state <- reconciliation$event_state[reconciliation$event_state$dataset == "overlap", ]
	expect_identical(overlap_state$retries, 1L)
	expect_identical(overlap_state$unclosed_starts, 1L)
	expect_identical(overlap_state$overlapping_starts, 1L)
	counts <- reconciliation$terminal_result_counts
	open_counts <- counts[counts$dataset == "open", ]
	expect_identical(open_counts$terminal_events, 2L)
	expect_identical(open_counts$result_rows, 1L)
	expect_false(open_counts$count_match)
	result_only_counts <- counts[counts$dataset == "result-only", ]
	expect_identical(result_only_counts$terminal_events, 0L)
	expect_identical(result_only_counts$result_rows, 1L)
	expect_false(result_only_counts$count_match)
	status_mismatch <- reconciliation$terminal_status_mismatches
	expect_identical(status_mismatch$dataset, "status-mismatch")
	expect_identical(status_mismatch$terminal_status, "error")
	expect_identical(status_mismatch$result_status, "ok")
	terminal_without_result <- reconciliation$terminal_without_result
	expect_identical(sort(terminal_without_result$dataset), c("open", "unexpected"))
	expect_true(all(terminal_without_result$terminal_status == "ok"))
	result_without_terminal <- reconciliation$result_without_terminal
	expect_identical(result_without_terminal$dataset, "result-only")
	expect_identical(result_without_terminal$result_status, "ok")
	retry_counts <- counts[counts$dataset == "retry", ]
	expect_identical(retry_counts$terminal_events, 2L)
	expect_identical(retry_counts$result_rows, 2L)
	expect_true(retry_counts$count_match)
	overlap_counts <- counts[counts$dataset == "overlap", ]
	expect_identical(overlap_counts$terminal_events, 1L)
	expect_identical(overlap_counts$result_rows, 1L)
	expect_true(overlap_counts$count_match)
})

test_that("TODO-23 paired terminal/result statuses must be recognized runner outcomes", {
	key <- data.frame(
		rep = 1:3, beta_T = c(0, 0, 0),
		dataset = c("invalid-terminal-status", "missing-terminal-status", "invalid-result-status"),
		response_type = "survival", design = "Bernoulli", inference_class = "RMST",
		function_run = "compute_wald_confidence_interval", stringsAsFactors = FALSE
	)
	event <- function(type, rep, dataset, seq, status = NA_character_) data.frame(
		event_seq = as.integer(seq), event_type = type, status = status,
		rep = as.integer(rep), beta_T = 0, dataset = dataset,
		response_type = "survival", design = "Bernoulli", inference_class = "RMST",
		function_run = "compute_wald_confidence_interval", stringsAsFactors = FALSE
	)
	events <- do.call(rbind, list(
		event("started", 1L, key$dataset[1L], 1L),
		event("terminal", 1L, key$dataset[1L], 2L, "skipped"),
		event("started", 2L, key$dataset[2L], 3L),
		event("terminal", 2L, key$dataset[2L], 4L),
		event("started", 3L, key$dataset[3L], 5L),
		event("terminal", 3L, key$dataset[3L], 6L, "ok")
	))
	results <- key
	results$status <- c("ok", "ok", "not-a-runner-status")

	reconciliation <- reconcile_todo23_attempts(key, events, results, names(key)[1:6])
	invalid <- reconciliation$terminal_status_mismatches
	expect_identical(sort(invalid$dataset), sort(key$dataset))
	expect_identical(invalid$terminal_status[invalid$dataset == key$dataset[1L]], "skipped")
	expect_identical(invalid$result_status[invalid$dataset == key$dataset[1L]], "ok")
	expect_true(is.na(invalid$terminal_status[invalid$dataset == key$dataset[2L]]))
	expect_identical(invalid$result_status[invalid$dataset == key$dataset[2L]], "ok")
	expect_identical(invalid$terminal_status[invalid$dataset == key$dataset[3L]], "ok")
	expect_identical(invalid$result_status[invalid$dataset == key$dataset[3L]], "not-a-runner-status")
	expect_true(all(reconciliation$terminal_result_counts$count_match))
	expect_equal(nrow(reconciliation$terminal_without_result), 0L)
	expect_equal(nrow(reconciliation$result_without_terminal), 0L)
})

test_that("TODO-23 event sequence IDs must be finite and unique", {
	key <- data.frame(
		rep = 1L, beta_T = 0, dataset = "fit", response_type = "survival",
		design = "Bernoulli", inference_class = "RMST",
		function_run = "compute_wald_confidence_interval", stringsAsFactors = FALSE
	)
	events <- data.frame(
		event_seq = c(1L, 1L), event_type = c("started", "terminal"),
		status = c(NA_character_, "ok"), rep = 1L, beta_T = 0,
		dataset = "fit", response_type = "survival", design = "Bernoulli",
		inference_class = "RMST", function_run = "compute_wald_confidence_interval",
		stringsAsFactors = FALSE
	)
	results <- key
	results$status <- "ok"
	events$event_seq <- c(1L, 1L)
	expect_error(
		reconcile_todo23_attempts(key, events, results, names(key)[1:6]),
		"events contain missing, invalid, or duplicate event sequence values"
	)
})
