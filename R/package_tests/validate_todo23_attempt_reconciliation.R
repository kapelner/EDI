# Pure-R reconciliation for a source-derived comprehensive attempt roster,
# append-only attempt events, and the emitted result rows. This utility does
# not define the empirical target; callers must supply an approved roster.

.todo23_key_ids <- function(x, key_columns, object_name) {
	if (!is.data.frame(x)) stop(object_name, " must be a data.frame", call. = FALSE)
	missing <- setdiff(key_columns, names(x))
	if (length(missing)) {
		stop(object_name, " is missing key field(s): ", paste(missing, collapse = ", "), call. = FALSE)
	}
	if (!nrow(x)) return(character())
	values <- lapply(x[key_columns], as.character)
	if (any(vapply(values, function(column) anyNA(column) || any(!nzchar(trimws(column))), logical(1)))) {
		stop(object_name, " contains missing or empty key values", call. = FALSE)
	}
	# Length-prefix each field so delimiters inside a key value cannot collide.
	vapply(seq_len(nrow(x)), function(i) {
		parts <- vapply(values, `[`, character(1), i)
		paste0(nchar(parts, type = "bytes"), ":", parts, collapse = "")
	}, character(1), USE.NAMES = FALSE)
}

reconcile_todo23_attempts <- function(expected_manifest, events, results, key_columns,
		method_column = "function_run", event_type_column = "event_type",
		event_seq_column = "event_seq") {
	if (!is.character(key_columns) || !length(key_columns) || anyNA(key_columns) ||
			any(!nzchar(key_columns)) || anyDuplicated(key_columns)) {
		stop("key_columns must be unique, nonempty field names", call. = FALSE)
	}
	if (length(method_column) != 1L || is.na(method_column) || !nzchar(method_column) ||
			method_column %in% key_columns) {
		stop("method_column must be one nonempty field distinct from key_columns", call. = FALSE)
	}
	full_key <- c(key_columns, method_column)
	if (anyDuplicated(full_key)) stop("full result key fields must be unique", call. = FALSE)
	if (!is.data.frame(events)) stop("events must be a data.frame", call. = FALSE)
	if (!event_type_column %in% names(events)) {
		stop("events is missing event type field: ", event_type_column, call. = FALSE)
	}
	expected_id <- .todo23_key_ids(expected_manifest, full_key, "expected_manifest")
	if (!length(expected_id)) stop("expected_manifest must be nonempty", call. = FALSE)
	if (anyDuplicated(expected_id)) stop("expected_manifest contains duplicate full keys", call. = FALSE)
	result_id <- .todo23_key_ids(results, full_key, "results")
	if (nrow(results) && !"status" %in% names(results)) {
		stop("results is missing status field", call. = FALSE)
	}
	event_key_fields <- full_key
	event_missing_fields <- setdiff(event_key_fields, names(events))
	if (length(event_missing_fields)) {
		stop("events is missing key field(s): ", paste(event_missing_fields, collapse = ", "), call. = FALSE)
	}

	# Setup-level events may have no operation key. Keep them visible to the
	# caller, but exclude them from operation-key anti-joins and lifecycle state.
	event_values <- lapply(events[event_key_fields], as.character)
	event_key_complete <- if (nrow(events)) {
		Reduce(`&`, lapply(event_values, function(column) !is.na(column) & nzchar(trimws(column))))
	} else logical()
	event_id <- rep(NA_character_, nrow(events))
	if (any(event_key_complete)) {
		event_id[event_key_complete] <- .todo23_key_ids(
			events[event_key_complete, , drop = FALSE], full_key, "keyed events"
		)
	}
	keyed_event_rows <- which(event_key_complete)
	keyed_event_id <- event_id[keyed_event_rows]
	event_types <- as.character(events[[event_type_column]])
	if (nrow(events) && anyNA(event_types)) stop("events contains missing event types", call. = FALSE)
	if (any(event_types == "terminal") && !"status" %in% names(events)) {
		stop("terminal events are missing status field", call. = FALSE)
	}
	if (event_seq_column %in% names(events) && nrow(events)) {
		seq_values <- suppressWarnings(as.numeric(events[[event_seq_column]]))
		if (anyNA(seq_values) || any(!is.finite(seq_values)) || anyDuplicated(seq_values)) {
			stop("events contain missing, invalid, or duplicate event sequence values", call. = FALSE)
		}
	}
	allowed_event_types <- c(
		"started", "terminal", "skipped_completed", "skipped_slow",
		"skipped_confirmed_timeout", "setup_skipped", "setup_failure"
	)
	if (any(!event_types %in% allowed_event_types)) {
		stop("events contains an unsupported event type", call. = FALSE)
	}

	result_missing_ids <- setdiff(expected_id, unique(result_id))
	result_extra_ids <- setdiff(unique(result_id), expected_id)
	result_counts <- tabulate(match(result_id, unique(result_id)), nbins = length(unique(result_id)))
	result_unique_ids <- unique(result_id)
	result_duplicate_ids <- result_unique_ids[result_counts > 1L]

	event_missing_ids <- setdiff(expected_id, unique(keyed_event_id))
	event_extra_ids <- setdiff(unique(keyed_event_id), expected_id)

	# Interpret each keyed operation as ordered start/terminal pairs. A completed
	# start/terminal pair may be retried; an unmatched start is surfaced rather
	# than silently treated as success. Skipped/setup events are retained in the
	# key anti-join but do not close an execution attempt.
	state_rows <- list()
	all_event_ids <- unique(keyed_event_id)
	for (id in all_event_ids) {
		rows <- keyed_event_rows[keyed_event_id == id]
		if (event_seq_column %in% names(events)) {
			seq_value <- suppressWarnings(as.numeric(events[[event_seq_column]][rows]))
			if (anyNA(seq_value)) stop("keyed events contain invalid event sequence values", call. = FALSE)
			rows <- rows[order(seq_value, rows)]
		}
		open_attempt <- FALSE
		starts <- terminals <- retries <- unclosed_starts <- orphan_terminals <- overlapping_starts <- 0L
		for (row in rows) {
			type <- event_types[row]
			if (identical(type, "started")) {
				starts <- starts + 1L
				if (open_attempt) {
					unclosed_starts <- unclosed_starts + 1L
					overlapping_starts <- overlapping_starts + 1L
				}
				open_attempt <- TRUE
			} else if (identical(type, "terminal")) {
				terminals <- terminals + 1L
				if (open_attempt) {
					open_attempt <- FALSE
				} else {
					orphan_terminals <- orphan_terminals + 1L
				}
			}
		}
		if (open_attempt) unclosed_starts <- unclosed_starts + 1L
		retries <- max(starts - 1L, 0L)
		state_rows[[length(state_rows) + 1L]] <- data.frame(
			.key_id = id, started = starts, terminal = terminals, retries = retries,
			unclosed_starts = unclosed_starts, orphan_terminals = orphan_terminals,
			overlapping_starts = overlapping_starts, stringsAsFactors = FALSE
		)
	}
	event_state <- if (length(state_rows)) do.call(rbind, state_rows) else data.frame(
		.key_id = character(), started = integer(), terminal = integer(), retries = integer(),
		unclosed_starts = integer(), orphan_terminals = integer(), overlapping_starts = integer(),
		stringsAsFactors = FALSE
	)
	key_rows_by_id <- function(ids, source, source_id) {
		if (!length(ids)) return(source[FALSE, full_key, drop = FALSE])
		first <- !duplicated(source_id)
		lookup <- source[which(first & source_id %in% ids), full_key, drop = FALSE]
		lookup_ids <- source_id[which(first & source_id %in% ids)]
		lookup[match(ids, lookup_ids), , drop = FALSE]
	}
	result_duplicate_counts <- data.frame(
		.key_id = result_duplicate_ids,
		rows = result_counts[match(result_duplicate_ids, result_unique_ids)],
		stringsAsFactors = FALSE
	)
	if (nrow(result_duplicate_counts)) {
		result_duplicate_counts <- cbind(
			key_rows_by_id(result_duplicate_ids, results, result_id),
			result_duplicate_counts["rows"], stringsAsFactors = FALSE
		)
	} else {
		result_duplicate_counts <- results[FALSE, full_key, drop = FALSE]
		result_duplicate_counts$rows <- integer()
	}
	if (nrow(event_state)) {
		event_state <- cbind(key_rows_by_id(event_state$.key_id, events[keyed_event_rows, , drop = FALSE], keyed_event_id),
			event_state[setdiff(names(event_state), ".key_id")], stringsAsFactors = FALSE)
	} else {
		event_state <- events[FALSE, full_key, drop = FALSE]
		for (name in c("started", "terminal", "retries", "unclosed_starts", "orphan_terminals", "overlapping_starts")) {
			event_state[[name]] <- integer()
		}
	}

	# Every terminal call in one isolated run should correspond to one emitted
	# result row for that same operation key. Retries remain visible as repeated
	# terminal/result pairs; this helper reports counts and does not choose a
	# winning retry or inflate the caller's per-replicate coverage denominator.
	terminal_rows <- keyed_event_rows[event_types[keyed_event_rows] == "terminal"]
	terminal_ids <- keyed_event_id[event_types[keyed_event_rows] == "terminal"]
	result_order <- seq_len(nrow(results))
	if ("run_row_id" %in% names(results) && nrow(results)) {
		result_order <- order(suppressWarnings(as.numeric(results$run_row_id)), result_order, na.last = TRUE)
	}
	result_ordered_id <- result_id[result_order]
	terminal_result_ids <- unique(c(expected_id, terminal_ids, result_id))
	key_source <- rbind(
		expected_manifest[full_key],
		events[keyed_event_rows, full_key, drop = FALSE],
		results[full_key]
	)
	key_source_ids <- c(expected_id, keyed_event_id, result_id)
	terminal_result_keys <- key_rows_by_id(terminal_result_ids, key_source, key_source_ids)
	terminal_count <- vapply(terminal_result_ids, function(id) sum(terminal_ids == id), integer(1))
	result_count <- vapply(terminal_result_ids, function(id) sum(result_id == id), integer(1))
	terminal_result_counts <- cbind(
		terminal_result_keys,
		data.frame(
			terminal_events = terminal_count,
			result_rows = result_count,
			count_match = terminal_count == result_count,
			stringsAsFactors = FALSE
		)
	)
	status_mismatch_rows <- list()
	terminal_without_result_rows <- list()
	result_without_terminal_rows <- list()
	for (id in terminal_result_ids) {
		term_for_key <- terminal_rows[terminal_ids == id]
		if (event_seq_column %in% names(events) && length(term_for_key)) {
			term_for_key <- term_for_key[order(as.numeric(events[[event_seq_column]][term_for_key]), term_for_key)]
		}
		result_for_key <- result_order[result_ordered_id == id]
		paired <- min(length(term_for_key), length(result_for_key))
		for (i in seq_len(paired)) {
			terminal_status <- as.character(events$status[term_for_key[i]])
			result_status <- as.character(results$status[result_for_key[i]])
			terminal_valid <- length(terminal_status) == 1L && !is.na(terminal_status) &&
				terminal_status %in% c("ok", "error")
			result_valid <- length(result_status) == 1L && !is.na(result_status) &&
				result_status %in% c("ok", "error")
			if (!terminal_valid || !result_valid || !identical(terminal_status, result_status)) {
				status_mismatch_rows[[length(status_mismatch_rows) + 1L]] <- data.frame(
					.key_id = id,
					attempt_index = as.integer(i),
					terminal_event_seq = if (event_seq_column %in% names(events)) as.numeric(events[[event_seq_column]][term_for_key[i]]) else NA_real_,
					result_row_index = as.integer(result_for_key[i]),
					terminal_status = terminal_status,
					result_status = result_status,
					stringsAsFactors = FALSE
				)
			}
		}
		if (length(term_for_key) > paired) {
			for (i in seq.int(paired + 1L, length(term_for_key))) {
				terminal_without_result_rows[[length(terminal_without_result_rows) + 1L]] <- data.frame(
					.key_id = id, attempt_index = as.integer(i),
					terminal_event_seq = if (event_seq_column %in% names(events)) as.numeric(events[[event_seq_column]][term_for_key[i]]) else NA_real_,
					terminal_status = as.character(events$status[term_for_key[i]]),
					stringsAsFactors = FALSE
				)
			}
		}
		if (length(result_for_key) > paired) {
			for (i in seq.int(paired + 1L, length(result_for_key))) {
				result_without_terminal_rows[[length(result_without_terminal_rows) + 1L]] <- data.frame(
					.key_id = id, result_attempt_index = as.integer(i),
					result_row_index = as.integer(result_for_key[i]),
					result_status = as.character(results$status[result_for_key[i]]),
					stringsAsFactors = FALSE
				)
			}
		}
	}
	terminal_status_mismatches <- if (length(status_mismatch_rows)) do.call(rbind, status_mismatch_rows) else data.frame(
		.key_id = character(), attempt_index = integer(), terminal_event_seq = numeric(),
		result_row_index = integer(), terminal_status = character(), result_status = character(),
		stringsAsFactors = FALSE
	)
	if (nrow(terminal_status_mismatches)) {
		terminal_status_mismatches <- cbind(
			key_rows_by_id(terminal_status_mismatches$.key_id, key_source, key_source_ids),
			terminal_status_mismatches[setdiff(names(terminal_status_mismatches), ".key_id")],
			stringsAsFactors = FALSE
		)
	} else {
		terminal_status_mismatches <- key_source[FALSE, full_key, drop = FALSE]
		terminal_status_mismatches$attempt_index <- integer()
		terminal_status_mismatches$terminal_event_seq <- numeric()
		terminal_status_mismatches$result_row_index <- integer()
		terminal_status_mismatches$terminal_status <- character()
		terminal_status_mismatches$result_status <- character()
	}
	terminal_without_result <- if (length(terminal_without_result_rows)) {
		unmatched <- do.call(rbind, terminal_without_result_rows)
		cbind(
			key_rows_by_id(unmatched$.key_id, key_source, key_source_ids),
			unmatched[setdiff(names(unmatched), ".key_id")],
			stringsAsFactors = FALSE
		)
	} else {
		out <- key_source[FALSE, full_key, drop = FALSE]
		out$attempt_index <- integer()
		out$terminal_event_seq <- numeric()
		out$terminal_status <- character()
		out
	}
	result_without_terminal <- if (length(result_without_terminal_rows)) {
		unmatched <- do.call(rbind, result_without_terminal_rows)
		cbind(
			key_rows_by_id(unmatched$.key_id, key_source, key_source_ids),
			unmatched[setdiff(names(unmatched), ".key_id")],
			stringsAsFactors = FALSE
		)
	} else {
		out <- key_source[FALSE, full_key, drop = FALSE]
		out$result_attempt_index <- integer()
		out$result_row_index <- integer()
		out$result_status <- character()
		out
	}

	list(
		key_columns = full_key,
		result_missing = key_rows_by_id(result_missing_ids, expected_manifest, expected_id),
		result_extra = key_rows_by_id(result_extra_ids, results, result_id),
		result_duplicates = result_duplicate_counts,
		event_missing = key_rows_by_id(event_missing_ids, expected_manifest, expected_id),
		event_extra = key_rows_by_id(event_extra_ids, events[keyed_event_rows, , drop = FALSE], keyed_event_id),
		event_state = event_state,
		terminal_result_counts = terminal_result_counts,
		terminal_without_result = terminal_without_result,
		result_without_terminal = result_without_terminal,
		terminal_status_mismatches = terminal_status_mismatches,
		unkeyed_event_rows = which(!event_key_complete)
	)
}
