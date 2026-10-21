# Read-only post-run acceptance for TODO-14's isolated comprehensive artifact.
# Candidate enumeration remains in validate_todo14_candidate.R; this helper
# consumes a separately prepared exact attempt roster plus the runner's event,
# result, and provenance-receipt files.

.todo14_attempt_value_issues <- function(rows, expected_manifest) {
	issues <- character()
	required <- c(
		"id", .todo14_key_columns, "run_row_id", "status", "error_message", "skip_reason",
		"method_family", "coverage_scope", "argument_coverage_kind", "github_commit_id",
		"timestamp", "result_1", "result_2", "coverage_truth",
		"beta_T_in_confidence_interval"
	)
	missing <- setdiff(required, names(rows))
	if (length(missing)) return(paste("result CSV is missing field(s):", paste(missing, collapse = ", ")))
	if (nrow(rows) != nrow(expected_manifest)) {
		issues <- c(issues, sprintf("result row count %d differs from exact attempt roster %d", nrow(rows), nrow(expected_manifest)))
	}
	if (anyDuplicated(rows$id)) issues <- c(issues, "result id values are not unique")
	if (anyDuplicated(rows$run_row_id)) issues <- c(issues, "run_row_id values are not unique")
	run_row_id <- suppressWarnings(as.numeric(as.character(rows$run_row_id)))
	if (any(!is.finite(run_row_id) | run_row_id < 1 | run_row_id != floor(run_row_id))) {
		issues <- c(issues, "run_row_id must contain positive finite integers")
	}
	if (anyNA(rows$method_family) || any(as.character(rows$method_family) != "rand")) issues <- c(issues, "method_family must be rand")
	if (anyNA(rows$coverage_scope) || any(as.character(rows$coverage_scope) != "comprehensive_workflow")) {
		issues <- c(issues, "coverage_scope must be comprehensive_workflow")
	}
	if (anyNA(rows$argument_coverage_kind) || any(as.character(rows$argument_coverage_kind) != "not_argument_combination")) {
		issues <- c(issues, "argument_coverage_kind must be not_argument_combination")
	}
	if (anyNA(rows$github_commit_id) || any(!nzchar(trimws(as.character(rows$github_commit_id))))) {
		issues <- c(issues, "github_commit_id must be nonempty")
	}
	if (anyNA(rows$timestamp) || any(!nzchar(trimws(as.character(rows$timestamp))))) {
		issues <- c(issues, "timestamp must be nonempty")
	}
	status <- as.character(rows$status)
	if (anyNA(status) || any(!status %in% c("ok", "error"))) {
		issues <- c(issues, "status must be one of ok/error")
		return(unique(issues))
	}
	ok <- status == "ok"
	function_run <- as.character(rows$function_run)
	pvalue <- function_run %in% .todo14_expected_functions[1:2]
	ci <- function_run == "compute_rand_confidence_interval"
	if (any(!pvalue & !ci)) issues <- c(issues, "function_run contains a label outside the TODO-14 result contract")
	result_1 <- suppressWarnings(as.numeric(as.character(rows$result_1)))
	result_2 <- suppressWarnings(as.numeric(as.character(rows$result_2)))
	error_rows <- status == "error"
	result_1_text <- trimws(as.character(rows$result_1))
	result_2_text <- trimws(as.character(rows$result_2))
	has_result_1 <- !is.na(rows$result_1) & nzchar(result_1_text)
	has_result_2 <- !is.na(rows$result_2) & nzchar(result_2_text)
	bad_error <- which(error_rows & (has_result_1 | has_result_2))
	if (length(bad_error)) issues <- c(issues, paste0("error rows must not retain numeric results at row(s): ", paste(bad_error, collapse = ",")))
	bad_p <- which(ok & pvalue & (!is.finite(result_1) | result_1 < 0 | result_1 > 1 | !is.na(result_2) | is.nan(result_2)))
	if (length(bad_p)) issues <- c(issues, paste0("successful p-value rows have invalid result fields at row(s): ", paste(bad_p, collapse = ",")))
	truth <- suppressWarnings(as.numeric(as.character(rows$coverage_truth)))
	membership <- rows$beta_T_in_confidence_interval
	if (!is.logical(membership)) {
		membership_text <- tolower(trimws(as.character(membership)))
		membership <- ifelse(membership_text %in% c("true", "t", "1"), TRUE,
			ifelse(membership_text %in% c("false", "f", "0"), FALSE, NA))
	}
	bad_ci <- which(ok & ci & (!is.finite(result_1) | !is.finite(result_2) | result_1 > result_2 |
		!is.finite(truth) | is.na(membership) | membership != (truth >= result_1 & truth <= result_2)))
	if (length(bad_ci)) issues <- c(issues, paste0("successful CI rows have invalid endpoints/truth/membership at row(s): ", paste(bad_ci, collapse = ",")))
	if (!identical(as.character(rows$response_type), rep("survival", nrow(rows)))) {
		issues <- c(issues, "response_type must be survival for TODO-14 rows")
	}
	issues
}

# A source candidate inventory is not evidence that all candidate keys were
# attempted. Require a second, caller-supplied disposition for every candidate
# and reconcile operation events against that disposition before accepting the
# attempted subset. Setup-level events are intentionally fail-closed: the
# current runner does not provide a proven mapping from those events to every
# affected operation key.
.todo14_reconcile_candidate_eligibility <- function(
	candidate_manifest, eligibility_manifest, expected_manifest, events, results
) {
	key_columns <- c("rep", "beta_T", "dataset", "response_type", "design", "inference_class")
	manifest_columns <- c(key_columns, "function_run")
	eligibility_column <- "eligibility"
	if (!is.data.frame(candidate_manifest) || !nrow(candidate_manifest) ||
			!all(c("id", manifest_columns, "candidate_status", "scope_source") %in% names(candidate_manifest))) {
		stop("candidate_manifest must be a nonempty source candidate roster with explicit candidate-only labels", call. = FALSE)
	}
	if (anyNA(candidate_manifest$candidate_status) || any(as.character(candidate_manifest$candidate_status) !=
			"candidate_only_requires_setup_and_runtime_eligibility") ||
			anyNA(candidate_manifest$scope_source) || any(as.character(candidate_manifest$scope_source) !=
				"checked_in_runner_defaults_without_cli_filters")) {
		stop("candidate_manifest must retain its candidate-only status and runner-default scope labels", call. = FALSE)
	}
	candidate_attempt_fields <- intersect(
		c("status", "expected_status", "skip_reason", "error_message", "runtime_eligible", "attempted", "attempt_event"),
		names(candidate_manifest)
	)
	if (length(candidate_attempt_fields)) {
		stop("candidate_manifest must remain key-only; attempt/runtime fields are not accepted: ",
			paste(candidate_attempt_fields, collapse = ", "), call. = FALSE)
	}
	if (!is.data.frame(eligibility_manifest) || !nrow(eligibility_manifest) ||
			!all(c("id", manifest_columns, eligibility_column) %in% names(eligibility_manifest))) {
		stop("eligibility_manifest must classify every candidate key with an explicit eligibility disposition", call. = FALSE)
	}
	if (any(c("candidate_status", "scope_source") %in% names(expected_manifest))) {
		stop("candidate-only inventory must be supplied as candidate_manifest, not expected_manifest", call. = FALSE)
	}
	validate_key_table <- function(x, label, unique_keys = TRUE) {
		values <- lapply(x[manifest_columns], as.character)
		if (any(vapply(values, function(column) anyNA(column) || any(!nzchar(trimws(column))), logical(1)))) {
			stop(label, " contains missing or empty natural-key fields", call. = FALSE)
		}
		key_ids <- comprehensive_result_manifest_keys(x, manifest_columns)
		if (isTRUE(unique_keys) && anyDuplicated(key_ids)) stop(label, " contains duplicate natural keys", call. = FALSE)
		built_ids <- .todo14_build_id(x)
		if (anyNA(x$id) || any(as.character(x$id) != built_ids)) {
			stop(label, " id does not match its natural-key fields", call. = FALSE)
		}
		key_ids
	}
	candidate_ids <- validate_key_table(candidate_manifest, "candidate_manifest")
	eligibility_ids <- validate_key_table(eligibility_manifest, "eligibility_manifest")
	if (!setequal(candidate_ids, eligibility_ids) || length(candidate_ids) != length(eligibility_ids)) {
		stop("eligibility_manifest must classify the exact source candidate inventory", call. = FALSE)
	}
	candidate_match <- match(eligibility_ids, candidate_ids)
	if (anyNA(candidate_match) || any(as.character(eligibility_manifest$id) != as.character(candidate_manifest$id[candidate_match]))) {
		stop("eligibility_manifest natural keys do not match candidate_manifest", call. = FALSE)
	}
	valid_dispositions <- c("attempt", "skipped_completed", "skipped_slow", "skipped_confirmed_timeout")
	disposition <- as.character(eligibility_manifest[[eligibility_column]])
	if (anyNA(disposition) || any(!disposition %in% valid_dispositions)) {
		stop("eligibility_manifest has missing or unsupported dispositions; setup-level outcomes require an explicit key mapping", call. = FALSE)
	}
	attempt_ids <- eligibility_ids[disposition == "attempt"]
	if (!length(attempt_ids)) stop("eligibility_manifest has no eligible operation attempts", call. = FALSE)
	expected_ids <- validate_key_table(expected_manifest, "expected_manifest")
	if (!setequal(attempt_ids, expected_ids) || length(attempt_ids) != length(expected_ids)) {
		stop("expected_manifest must equal exactly the eligibility_manifest attempt subset", call. = FALSE)
	}
	if (!is.data.frame(events) || !is.data.frame(results)) stop("events and results must be data.frames", call. = FALSE)
	event_required <- c("event_seq", "event_type", "id", manifest_columns, "status", "skip_reason")
	event_missing <- setdiff(event_required, names(events))
	if (length(event_missing)) stop("attempt manifest is missing field(s): ", paste(event_missing, collapse = ", "), call. = FALSE)
	if (anyNA(events$event_type)) stop("attempt manifest contains missing event types", call. = FALSE)
	event_type <- as.character(events$event_type)
	setup_rows <- which(event_type %in% c("setup_skipped", "setup_failure"))
	if (length(setup_rows)) {
		stop(sprintf(
			"%d unmapped setup-level event(s) (%s) cannot be reconciled to operation keys; provide a proven row-level setup eligibility mapping",
			length(setup_rows), paste(unique(event_type[setup_rows]), collapse = ", ")
		), call. = FALSE)
	}
	allowed_events <- c("started", "terminal", "skipped_completed", "skipped_slow", "skipped_confirmed_timeout")
	if (any(!event_type %in% allowed_events)) stop("attempt manifest contains an unsupported event type", call. = FALSE)
	if (nrow(events)) {
		event_ids <- validate_key_table(events, "attempt events", unique_keys = FALSE)
		if (anyNA(events$id) || any(!event_ids %in% candidate_ids)) {
			stop("attempt event keys/ids do not map to the source candidate inventory", call. = FALSE)
		}
		seq_value <- suppressWarnings(as.numeric(events$event_seq))
		if (any(!is.finite(seq_value)) || any(seq_value < 1 | seq_value != floor(seq_value)) || anyDuplicated(seq_value)) {
			stop("attempt events require unique positive integer event_seq values", call. = FALSE)
		}
	} else {
		event_ids <- character()
	}
	if (any(event_type == "started" & !is.na(events$status) & nzchar(trimws(as.character(events$status))))) {
		stop("started events must have no status", call. = FALSE)
	}
	terminal <- event_type == "terminal"
	if (any(terminal & (is.na(events$status) | !as.character(events$status) %in% c("ok", "error")))) {
		stop("terminal events must have status ok/error", call. = FALSE)
	}
	skip_rows <- which(event_type %in% valid_dispositions[-1L])
	if (length(skip_rows) && any(!is.na(events$status[skip_rows]) & nzchar(trimws(as.character(events$status[skip_rows]))))) {
		stop("runtime skip events must not carry a result status", call. = FALSE)
	}
	expected_skip_reason <- c(
		skipped_completed = "completed_cache",
		skipped_slow = "slow_path",
		skipped_confirmed_timeout = "confirmed_timeout_cache"
	)
	if (length(skip_rows) && any(is.na(events$skip_reason[skip_rows]) |
			as.character(events$skip_reason[skip_rows]) != unname(expected_skip_reason[event_type[skip_rows]]))) {
		stop("runtime skip event reason does not match its runner skip classification", call. = FALSE)
	}
	for (i in seq_along(eligibility_ids)) {
		id <- eligibility_ids[i]
		key_events <- which(event_ids == id)
		key_types <- event_type[key_events]
		if (disposition[i] == "attempt") {
			if (any(key_types %in% valid_dispositions[-1L])) {
				stop("attempt-eligible key also has a runtime skip event", call. = FALSE)
			}
		} else if (length(key_events) != 1L || !identical(key_types, disposition[i])) {
			stop("each runtime-ineligible candidate requires exactly one matching keyed skip event", call. = FALSE)
		}
	}
	if (any(!event_ids %in% eligibility_ids)) stop("attempt events contain keys absent from eligibility_manifest", call. = FALSE)
	execution_events <- events[event_type %in% c("started", "terminal"), , drop = FALSE]
	attempt_manifest <- eligibility_manifest[disposition == "attempt", , drop = FALSE]
	reconciliation <- reconcile_todo23_attempts(
		expected_manifest = attempt_manifest,
		events = execution_events,
		results = results,
		key_columns = key_columns,
		method_column = "function_run"
	)
	if (nrow(reconciliation$event_missing) || nrow(reconciliation$event_extra) ||
			nrow(reconciliation$result_missing) || nrow(reconciliation$result_extra) ||
			nrow(reconciliation$result_duplicates) || nrow(reconciliation$terminal_without_result) ||
			nrow(reconciliation$result_without_terminal) || nrow(reconciliation$terminal_status_mismatches) ||
			length(reconciliation$unkeyed_event_rows)) {
		stop("attempt event/result reconciliation found missing, extra, duplicate, unpaired, or unkeyed rows", call. = FALSE)
	}
	state <- reconciliation$event_state
	if (nrow(state) != nrow(attempt_manifest) || any(state$started != 1L | state$terminal != 1L |
			state$unclosed_starts != 0L | state$orphan_terminals != 0L | state$overlapping_starts != 0L)) {
		stop("each attempt-eligible key must have exactly one well-formed started/terminal pair", call. = FALSE)
	}
	skip_index <- which(disposition != "attempt")
	skip_event_index <- match(eligibility_ids[skip_index], event_ids)
	runtime_skips <- eligibility_manifest[skip_index, c("id", manifest_columns, eligibility_column), drop = FALSE]
	runtime_skips$event_seq <- if (length(skip_event_index)) events$event_seq[skip_event_index] else integer()
	runtime_skips$skip_reason <- if (length(skip_event_index)) events$skip_reason[skip_event_index] else character()
	list(
		attempt_count = length(attempt_ids),
		runtime_skip_counts = table(factor(disposition[disposition != "attempt"], levels = valid_dispositions[-1L])),
		runtime_skips = runtime_skips,
		reconciliation = reconciliation
	)
}

#' Validate an isolated TODO-14 attempt/result artifact and its receipts.
#'
#' `candidate_manifest` is a source-derived key inventory only. The explicit
#' `eligibility_manifest` must classify every candidate as an attempt or one
#' keyed runtime skip; `expected_manifest` must equal its attempt subset. Setup
#' events are rejected until the runner proves their mapping to operation keys.
#' The result CSV and raw attempt-event CSV must both be bound by the run sidecar.
#' `expected_provenance` pins the run to the approved checkout, R version,
#' EDI package location/version, and native DLL hash.
validate_todo14_attempt_result_artifact <- function(
	results_file,
	sidecar_path,
	attempt_manifest_path,
	expected_manifest,
	expected_provenance = NULL,
	candidate_manifest = NULL,
	eligibility_manifest = NULL
) {
	key_columns <- c("rep", "beta_T", "dataset", "response_type", "design", "inference_class")
	manifest_columns <- c(key_columns, "function_run")
	if (!is.data.frame(expected_manifest) || !nrow(expected_manifest) ||
			!all(c("id", manifest_columns) %in% names(expected_manifest))) {
		stop("expected_manifest must be a nonempty exact TODO-14 roster with id and full natural-key fields", call. = FALSE)
	}
	if (is.null(candidate_manifest) || is.null(eligibility_manifest)) {
		stop("candidate_manifest and explicit eligibility_manifest are required; a candidate roster is not an attempt roster", call. = FALSE)
	}
	manifest_values <- lapply(expected_manifest[manifest_columns], as.character)
	if (any(vapply(manifest_values, function(x) anyNA(x) || any(!nzchar(trimws(x))), logical(1)))) {
		stop("expected_manifest contains missing or empty natural-key fields", call. = FALSE)
	}
	rep_value <- suppressWarnings(as.numeric(as.character(expected_manifest$rep)))
	beta_value <- suppressWarnings(as.numeric(as.character(expected_manifest$beta_T)))
	if (any(!is.finite(rep_value) | rep_value < 1 | rep_value != floor(rep_value)) || any(!is.finite(beta_value))) {
		stop("expected_manifest rep/beta_T fields must be positive integer/finite numeric values", call. = FALSE)
	}
	if (any(!as.character(expected_manifest$function_run) %in% .todo14_expected_functions)) {
		stop("expected_manifest contains a function_run outside the TODO-14 rand contract", call. = FALSE)
	}
	expected_key_ids <- comprehensive_result_manifest_keys(expected_manifest, manifest_columns)
	if (anyDuplicated(expected_key_ids)) stop("expected_manifest contains duplicate natural keys", call. = FALSE)
	if (anyNA(expected_manifest$id) || any(as.character(expected_manifest$id) != .todo14_build_id(expected_manifest))) {
		stop("expected_manifest id does not match its natural-key fields", call. = FALSE)
	}
	if (is.null(expected_provenance)) {
		stop("expected_provenance is required for TODO-14 post-run acceptance", call. = FALSE)
	}
	if (!is.character(attempt_manifest_path) || length(attempt_manifest_path) != 1L ||
			is.na(attempt_manifest_path) || !nzchar(attempt_manifest_path) ||
			!file.exists(attempt_manifest_path) || dir.exists(attempt_manifest_path)) {
		stop("attempt_manifest_path must name one existing event CSV", call. = FALSE)
	}
	fields <- c("checkout_sha", "r_version", "package_version", "library_path", "dll_path", "dll_sha256")
	if (!is.list(expected_provenance) || is.null(names(expected_provenance)) ||
			anyDuplicated(names(expected_provenance)) || any(!fields %in% names(expected_provenance)) ||
			any(vapply(expected_provenance[fields], function(x) length(x) != 1L || is.na(x) || !nzchar(as.character(x)), logical(1)))) {
		stop("expected_provenance must include all six scalar TODO-14 identity fields", call. = FALSE)
	}
	if (!grepl("^[[:xdigit:]]{40}([[:xdigit:]]{24})?$", as.character(expected_provenance$checkout_sha)) ||
			!grepl("^[[:xdigit:]]{64}$", as.character(expected_provenance$dll_sha256))) {
		stop("expected_provenance contains an invalid checkout or DLL hash", call. = FALSE)
	}

	validated <- validate_comprehensive_result_artifact(
		results_file = results_file,
		sidecar_path = sidecar_path,
		expected_manifest = expected_manifest,
		key_columns = key_columns,
		method_column = "function_run",
		expected_run_provenance = NULL,
		require_terminal_result_fields = TRUE
	)
	provenance <- validated$provenance
	if (isTRUE(provenance$results_file_before$exists)) {
		stop("TODO-14 result artifact must start from a fresh output file", call. = FALSE)
	}
	if (!is.list(provenance$attempt_manifest) || !identical(provenance$attempt_manifest$enabled, TRUE)) {
		stop("run provenance sidecar does not attest an enabled attempt manifest", call. = FALSE)
	}
	receipt_path <- provenance$attempt_manifest$path
	actual_attempt_path <- normalizePath(attempt_manifest_path, winslash = "/", mustWork = TRUE)
	if (!is.character(receipt_path) || length(receipt_path) != 1L || is.na(receipt_path) ||
			!identical(normalizePath(receipt_path, winslash = "/", mustWork = FALSE), actual_attempt_path)) {
		stop("attempt manifest path does not match the run provenance receipt", call. = FALSE)
	}
	actual_attempt_identity <- comprehensive_result_file_identity(actual_attempt_path, include_sha256 = TRUE)
	receipt_identity <- provenance$attempt_manifest$identity
	if (!is.list(receipt_identity) || !identical(receipt_identity$exists, TRUE) ||
			!identical(as.numeric(receipt_identity$bytes), actual_attempt_identity$bytes) ||
			!is.character(receipt_identity$sha256) || length(receipt_identity$sha256) != 1L ||
			!identical(tolower(receipt_identity$sha256), tolower(actual_attempt_identity$sha256))) {
		stop("attempt manifest bytes or SHA-256 do not match the run provenance receipt", call. = FALSE)
	}
	mapping <- c(
		checkout_sha = "checkout_head", r_version = "r_version",
		package_version = "edi_package_version", library_path = "edi_package_path",
		dll_path = "edi_dll_path", dll_sha256 = "edi_dll_sha256"
	)
	for (field in names(mapping)) {
		if (!identical(as.character(provenance$after[[mapping[[field]]]]), as.character(expected_provenance[[field]]))) {
			stop("run provenance differs from expected TODO-14 field: ", field, call. = FALSE)
		}
	}

	results <- utils::read.csv(results_file, stringsAsFactors = FALSE, check.names = FALSE, na.strings = c("", "NA"))
	events <- utils::read.csv(actual_attempt_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = c("", "NA"))
	value_issues <- .todo14_attempt_value_issues(results, expected_manifest)
	if (length(value_issues)) stop(paste(value_issues, collapse = "; "), call. = FALSE)
	result_key_ids <- comprehensive_result_manifest_keys(results, manifest_columns)
	manifest_key_ids <- comprehensive_result_manifest_keys(expected_manifest, manifest_columns)
	match_expected <- match(result_key_ids, manifest_key_ids)
	if (anyNA(match_expected) || anyNA(results$id) || any(as.character(results$id) != as.character(expected_manifest$id[match_expected]))) {
		stop("result id field does not agree with exact natural-key fields", call. = FALSE)
	}
	if (any(as.character(results$github_commit_id) != as.character(expected_provenance$checkout_sha))) {
		stop("result github_commit_id does not match expected checkout", call. = FALSE)
	}

	eligibility_reconciliation <- .todo14_reconcile_candidate_eligibility(
		candidate_manifest = candidate_manifest,
		eligibility_manifest = eligibility_manifest,
		expected_manifest = expected_manifest,
		events = events,
		results = results
	)
	invisible(list(
		results_file = validated$results_file,
		rows = nrow(results),
		attempt_events = nrow(events),
		status_counts = table(factor(results$status, levels = c("ok", "error"))),
		provenance = provenance,
		reconciliation = eligibility_reconciliation$reconciliation,
		eligibility = eligibility_reconciliation[c("attempt_count", "runtime_skip_counts", "runtime_skips")]
	))
}
