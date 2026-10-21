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

#' Validate an isolated TODO-14 attempt/result artifact and its receipts.
#'
#' `expected_manifest` is the independently prepared *exact eligible-attempt*
#' roster for this isolated run, not merely the source candidate inventory.
#' Every expected key must have exactly one started/terminal event pair and one
#' result row. Setup/runtime-ineligible candidates must be resolved before
#' calling this validator; they are not silently treated as emitted attempts.
#' The result CSV and attempt-event CSV must both be bound by the run sidecar.
#' `expected_provenance` pins the run to the approved checkout, R version,
#' EDI package location/version, and native DLL hash.
validate_todo14_attempt_result_artifact <- function(
	results_file,
	sidecar_path,
	attempt_manifest_path,
	expected_manifest,
	expected_provenance = NULL
) {
	key_columns <- c("rep", "beta_T", "dataset", "response_type", "design", "inference_class")
	manifest_columns <- c(key_columns, "function_run")
	if (!is.data.frame(expected_manifest) || !nrow(expected_manifest) ||
			!all(c("id", manifest_columns) %in% names(expected_manifest))) {
		stop("expected_manifest must be a nonempty exact TODO-14 roster with id and full natural-key fields", call. = FALSE)
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
	event_required <- c("id", manifest_columns, "event_type", "event_seq", "status")
	event_missing <- setdiff(event_required, names(events))
	if (length(event_missing)) {
		stop("attempt manifest is missing field(s): ", paste(event_missing, collapse = ", "), call. = FALSE)
	}
	event_type <- as.character(events$event_type)
	if (anyNA(event_type) || any(!event_type %in% c("started", "terminal"))) {
		stop("isolated TODO-14 attempt manifest may contain only started and terminal operation events", call. = FALSE)
	}
	event_status <- as.character(events$status)
	bad_started_status <- event_type == "started" & !is.na(event_status) & nzchar(trimws(event_status))
	bad_terminal_status <- event_type == "terminal" &
		(is.na(event_status) | !event_status %in% c("ok", "error"))
	if (any(bad_started_status) || any(bad_terminal_status)) {
		stop("started events must have no status and terminal events must have status ok/error", call. = FALSE)
	}
	if (nrow(events)) {
		event_key_ids <- comprehensive_result_manifest_keys(events, manifest_columns)
		event_to_expected <- match(event_key_ids, expected_key_ids)
		if (anyNA(event_to_expected) || anyNA(events$id) || any(as.character(events$id) != as.character(expected_manifest$id[event_to_expected]))) {
			stop("attempt event id does not agree with an expected natural key", call. = FALSE)
		}
	}
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

	reconciliation <- reconcile_todo23_attempts(
		expected_manifest = expected_manifest,
		events = events,
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
	if (nrow(state) != nrow(expected_manifest) || any(state$started != 1L | state$terminal != 1L |
			state$unclosed_starts != 0L | state$orphan_terminals != 0L | state$overlapping_starts != 0L)) {
		stop("each expected key must have exactly one well-formed started/terminal pair", call. = FALSE)
	}
	if (nrow(reconciliation$terminal_result_counts) != nrow(expected_manifest) ||
			any(!reconciliation$terminal_result_counts$count_match)) {
		stop("terminal-event and result-row counts differ for one or more expected keys", call. = FALSE)
	}
	invisible(list(
		results_file = validated$results_file,
		rows = nrow(results),
		attempt_events = nrow(events),
		status_counts = table(factor(results$status, levels = c("ok", "error"))),
		provenance = provenance,
		reconciliation = reconciliation
	))
}
