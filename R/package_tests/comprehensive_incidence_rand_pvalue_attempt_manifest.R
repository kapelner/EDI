# Source-derived expected-attempt inventory for incidence rand p-values.
# This is separate from the proportion helper: incidence's delta=0.5 runner
# call is deliberately retained as an attempted row, but current public R
# methods reject it (unless a custom randomization statistic is supplied).

comprehensive_incidence_rand_pvalue_source_guard <- function(runner_path) {
	if (!is.character(runner_path) || length(runner_path) != 1L || is.na(runner_path) ||
			!file.exists(runner_path) || dir.exists(runner_path)) {
		stop("runner_path must name an existing comprehensive_tests.R", call. = FALSE)
	}
	parsed <- parse(runner_path, keep.source = FALSE)
	find_assignment <- function(node, name) {
		if (!is.call(node) || identical(node[[1L]], as.name("function"))) return(NULL)
		if ((identical(node[[1L]], as.name("<-")) || identical(node[[1L]], as.name("="))) &&
				length(node) >= 3L && identical(node[[2L]], as.name(name))) return(node[[3L]])
		children <- as.list(node)[-1L]
		for (i in seq_along(children)) {
			if (identical(children[[i]], quote(expr = ))) next
			found <- find_assignment(children[[i]], name)
			if (!is.null(found)) return(found)
		}
		NULL
	}
	impl <- NULL
	for (expr in as.list(parsed)) {
		impl <- find_assignment(expr, "run_inference_checks_impl")
		if (!is.null(impl)) break
	}
	if (is.null(impl) || !is.call(impl) || !identical(impl[[1L]], as.name("function"))) {
		stop("could not find run_inference_checks_impl() in parsed source", call. = FALSE)
	}
	walk <- function(node, fn) {
		if (!is.call(node)) return(invisible(NULL))
		fn(node)
		children <- as.list(node)[-1L]
		for (i in seq_along(children)) {
			if (identical(children[[i]], quote(expr = ))) next
			walk(children[[i]], fn)
		}
		invisible(NULL)
	}
	condition_atoms <- function(expr) {
		if (is.call(expr) && identical(expr[[1L]], as.name("&&"))) {
			return(c(condition_atoms(expr[[2L]]), condition_atoms(expr[[3L]])))
		}
		paste(deparse(expr, width.cutoff = 500L), collapse = " ")
	}
	count_safe_call <- function(node, label) {
		count <- 0L
		walk(node, function(expr) {
			if (identical(expr[[1L]], as.name("safe_call")) && length(expr) >= 2L &&
					is.character(expr[[2L]]) && identical(expr[[2L]], label)) count <<- count + 1L
		})
		count
	}
	condition <- c(
		"supports_randomization_test", "should_run_test_family(\"rand\")", "!skip_slow",
		"!skip_rand", "!skip_regular_rand_pval", "!skip_rand_slow",
		"response_type %in% c(\"continuous\", \"survival\", \"proportion\", \"incidence\", \"count\", \"ordinal\")"
	)
	branches <- list()
	walk(impl[[3L]], function(expr) {
		if (!identical(expr[[1L]], as.name("if")) || length(expr) < 3L) return(invisible(NULL))
		atoms <- condition_atoms(expr[[2L]])
		if (!setequal(atoms, condition) || length(atoms) != length(condition)) return(invisible(NULL))
		if (count_safe_call(expr[[3L]], "compute_rand_two_sided_pval") != 1L ||
				count_safe_call(expr[[3L]], "compute_rand_two_sided_pval(delta=0.5)") != 1L) return(invisible(NULL))
		delta_guards <- list()
		walk(expr[[3L]], function(inner) {
			if (identical(inner[[1L]], as.name("if")) && length(inner) >= 3L &&
					identical(paste(deparse(inner[[2L]], width.cutoff = 500L), collapse = " "),
						"!skip_rand_delta_pval_slow") &&
					count_safe_call(inner[[3L]], "compute_rand_two_sided_pval(delta=0.5)") == 1L) {
				delta_guards[[length(delta_guards) + 1L]] <<- inner
			}
		})
		if (length(delta_guards) == 1L) branches[[length(branches) + 1L]] <<- expr
	})
	if (length(branches) != 1L) {
		stop("unrecognized incidence plain-rand p-value runner guards or labels", call. = FALSE)
	}

	# The public entry points have a correctness guard, not merely an optional
	# assertion. Check all current implementations that can own this method.
	repo_root <- dirname(dirname(dirname(normalizePath(runner_path, winslash = "/"))))
	edi_r_dir <- file.path(repo_root, "R", "EDI", "R")
	method_files <- c(
		"inference_all_abstract_rand.R",
		"inference_all_abstract_rand_ci.R",
		"inference_mixin_kk_gee_shared.R"
	)
	contains_guard <- function(path) {
		if (!file.exists(path)) return(FALSE)
		source <- parse(path, keep.source = FALSE)
		found <- FALSE
		for (top_expr in as.list(source)) {
			walk(top_expr, function(expr) {
				if (!identical(expr[[1L]], as.name("if")) || length(expr) < 3L) return(invisible(NULL))
				condition_text <- paste(deparse(expr[[2L]], width.cutoff = 500L), collapse = " ")
				if (!grepl("isTRUE\\(delta != 0\\)", condition_text) ||
						!grepl('response_type == "incidence"', condition_text, fixed = TRUE) ||
						!grepl("is.null(private$custom_randomization_statistic_function)", condition_text, fixed = TRUE)) {
					return(invisible(NULL))
				}
				walk(expr[[3L]], function(inner) {
					if (identical(inner[[1L]], as.name("stop")) && length(inner) >= 2L &&
							is.character(inner[[2L]]) &&
							identical(inner[[2L]], "randomization tests with delta nonzero not supported for incidence")) {
						found <<- TRUE
					}
				})
			})
		}
		found
	}
	missing_guards <- method_files[!vapply(file.path(edi_r_dir, method_files), contains_guard, logical(1))]
	if (length(missing_guards)) {
		stop("missing current incidence nonzero-delta guard in: ",
			paste(missing_guards, collapse = ", "), call. = FALSE)
	}
	invisible(TRUE)
}

comprehensive_incidence_rand_pvalue_attempt_manifest <- function(cases, runner_path) {
	comprehensive_incidence_rand_pvalue_source_guard(runner_path)
	if (!is.data.frame(cases)) stop("cases must be a data.frame", call. = FALSE)
	key_columns <- c("rep", "beta_T", "dataset", "response_type", "design", "inference_class")
	flag_columns <- c(
		"supports_randomization_test", "test_family_filter", "skip_slow", "skip_rand",
		"skip_regular_rand_pval", "skip_rand_slow", "skip_rand_delta_pval_slow",
		"has_custom_randomization_statistic_function"
	)
	missing <- setdiff(c(key_columns, flag_columns), names(cases))
	if (length(missing)) {
		stop("missing case-manifest field(s): ", paste(missing, collapse = ", "), call. = FALSE)
	}
	if (nrow(cases) && any(cases$response_type != "incidence" | is.na(cases$response_type))) {
		stop("all cases must have response_type = 'incidence'", call. = FALSE)
	}
	if (!is.numeric(cases$rep) || !is.numeric(cases$beta_T)) {
		stop("rep and beta_T must be numeric key columns", call. = FALSE)
	}
	if (nrow(cases) && (anyNA(cases[key_columns]) || any(!is.finite(cases$rep)) ||
			any(cases$rep != floor(cases$rep)) || any(!is.finite(cases$beta_T)))) {
		stop("case-manifest key fields must be non-missing and beta_T finite", call. = FALSE)
	}
	for (column in c("dataset", "response_type", "design", "inference_class")) {
		if (!is.character(cases[[column]])) {
			stop(column, " must be a character key column", call. = FALSE)
		}
	}
	if (anyDuplicated(cases[key_columns])) stop("duplicate source case key in case manifest", call. = FALSE)
	if (!is.character(cases$test_family_filter) || length(cases$test_family_filter) != nrow(cases)) {
		stop("test_family_filter must be a character column", call. = FALSE)
	}
	for (i in seq_len(nrow(cases))) {
		filter <- cases$test_family_filter[i]
		if (length(filter) != 1L || (!is.na(filter) &&
				(!is.character(filter) || !filter %in% c(
					"estimate", "exact", "asymp", "wald", "score", "lik_ratio", "gradient",
					"bootstrap", "bayesian_bootstrap", "parametric_bootstrap", "bartlett",
					"jackknife", "rand", "rand_custom", "rand_bootstrap"
				)))) {
			stop("test_family_filter must be one supported family or NA", call. = FALSE)
		}
		for (flag in setdiff(flag_columns, "test_family_filter")) {
			value <- cases[[flag]][i]
			if (!is.logical(value) || length(value) != 1L || is.na(value)) {
				stop(flag, " must be one non-missing logical value", call. = FALSE)
			}
		}
	}

	rows <- list()
	for (i in seq_len(nrow(cases))) {
		eligible <- isTRUE(cases$supports_randomization_test[i]) &&
			(is.na(cases$test_family_filter[i]) || cases$test_family_filter[i] == "rand") &&
			!isTRUE(cases$skip_slow[i]) && !isTRUE(cases$skip_rand[i]) &&
			!isTRUE(cases$skip_regular_rand_pval[i]) && !isTRUE(cases$skip_rand_slow[i])
		if (!eligible) next
		functions <- "compute_rand_two_sided_pval"
		statuses <- NA_character_
		skip_reasons <- NA_character_
		if (!isTRUE(cases$skip_rand_delta_pval_slow[i])) {
			functions <- c(functions, "compute_rand_two_sided_pval(delta=0.5)")
			statuses <- c(statuses, if (isTRUE(cases$has_custom_randomization_statistic_function[i])) NA_character_ else "error")
			skip_reasons <- c(skip_reasons, if (isTRUE(cases$has_custom_randomization_statistic_function[i])) NA_character_ else "error")
		}
		base <- cases[rep(i, length(functions)), key_columns, drop = FALSE]
		base$function_run <- functions
		base$expected_status <- statuses
		base$expected_skip_reason <- skip_reasons
		rows[[length(rows) + 1L]] <- base
	}
	if (!length(rows)) {
		out <- cases[FALSE, key_columns, drop = FALSE]
		out$function_run <- character()
		out$expected_status <- character()
		out$expected_skip_reason <- character()
		return(out)
	}
	manifest <- do.call(rbind, rows)
	rownames(manifest) <- NULL
	manifest <- manifest[c(key_columns, "function_run", "expected_status", "expected_skip_reason")]
	if (anyDuplicated(manifest[c(key_columns, "function_run")])) {
		stop("duplicate attempted incidence result key in case manifest", call. = FALSE)
	}
	manifest
}

# Bind the source-derived expected outcome to the completed incidence-rand
# artifact. The generic validator establishes provenance and exact key parity;
# this narrow second check enforces the known nonzero-delta rejection contract.
validate_comprehensive_incidence_rand_pvalue_expected_outcomes <- function(
	expected_manifest,
	result_rows
){
	key_columns <- c("rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run")
	missing_expected <- setdiff(c(key_columns, "expected_status", "expected_skip_reason"), names(expected_manifest))
	if (!is.data.frame(expected_manifest) || length(missing_expected)) {
		stop("expected incidence-rand manifest is missing field(s): ", paste(missing_expected, collapse = ", "), call. = FALSE)
	}
	missing_actual <- setdiff(c(key_columns, "status", "skip_reason"), names(result_rows))
	if (!is.data.frame(result_rows) || length(missing_actual)) {
		stop("incidence-rand results are missing field(s): ", paste(missing_actual, collapse = ", "), call. = FALSE)
	}
	if (anyDuplicated(comprehensive_result_manifest_keys(expected_manifest, key_columns))) {
		stop("expected incidence-rand manifest contains duplicate result keys", call. = FALSE)
	}
	if (anyDuplicated(comprehensive_result_manifest_keys(result_rows, key_columns))) {
		stop("incidence-rand results contain duplicate result keys", call. = FALSE)
	}
	expected_keys <- comprehensive_result_manifest_keys(expected_manifest, key_columns)
	actual_keys <- comprehensive_result_manifest_keys(result_rows, key_columns)
	if (!setequal(expected_keys, actual_keys)) {
		stop("incidence-rand result keys do not match the expected outcome manifest", call. = FALSE)
	}
	actual_index <- match(expected_keys, actual_keys)
	status <- as.character(result_rows$status[actual_index])
	skip_reason <- as.character(result_rows$skip_reason[actual_index])
	expected_status <- as.character(expected_manifest$expected_status)
	expected_skip_reason <- as.character(expected_manifest$expected_skip_reason)
	status_mismatch <- !is.na(expected_status) & (is.na(status) | status != expected_status)
	reason_mismatch <- !is.na(expected_skip_reason) & (is.na(skip_reason) | skip_reason != expected_skip_reason)
	if (any(status_mismatch)) {
		stop("incidence-rand result status violates expected_status for ", sum(status_mismatch), " row(s)", call. = FALSE)
	}
	if (any(reason_mismatch)) {
		stop("incidence-rand result skip_reason violates expected_skip_reason for ", sum(reason_mismatch), " row(s)", call. = FALSE)
	}
	invisible(list(rows = nrow(expected_manifest), checked_status = sum(!is.na(expected_status)),
		checked_skip_reason = sum(!is.na(expected_skip_reason))))
}

validate_comprehensive_incidence_rand_pvalue_result_artifact <- function(
	results_file,
	sidecar_path,
	expected_manifest,
	attempt_manifest_path,
	expected_run_provenance = NULL
){
	key_columns <- c("rep", "beta_T", "dataset", "response_type", "design", "inference_class")
	if (!is.data.frame(expected_manifest) ||
			!all(c(key_columns, "function_run", "expected_status", "expected_skip_reason") %in% names(expected_manifest))) {
		stop("expected incidence-rand manifest must include keys, function_run, expected_status, and expected_skip_reason", call. = FALSE)
	}
	if (!is.character(attempt_manifest_path) || length(attempt_manifest_path) != 1L ||
			is.na(attempt_manifest_path) || !nzchar(attempt_manifest_path) ||
			!file.exists(attempt_manifest_path) || dir.exists(attempt_manifest_path)) {
		stop("attempt_manifest_path must name one existing event CSV", call. = FALSE)
	}
	validated <- validate_comprehensive_result_artifact(
		results_file = results_file,
		sidecar_path = sidecar_path,
		expected_manifest = expected_manifest,
		key_columns = key_columns,
		method_column = "function_run",
		expected_run_provenance = expected_run_provenance,
		require_terminal_result_fields = TRUE
	)
	result_rows <- utils::read.csv(results_file, stringsAsFactors = FALSE, check.names = FALSE)
	validate_comprehensive_incidence_rand_pvalue_expected_outcomes(expected_manifest, result_rows)
	provenance <- validated$provenance
	if (isTRUE(provenance$results_file_before$exists)) {
		stop("TODO-99 result artifact must start from a fresh output file", call. = FALSE)
	}
	attempt_receipt <- provenance$attempt_manifest
	if (!is.list(attempt_receipt) || !identical(attempt_receipt$enabled, TRUE)) {
		stop("run provenance sidecar does not attest an enabled attempt manifest", call. = FALSE)
	}
	actual_attempt_path <- normalizePath(attempt_manifest_path, winslash = "/", mustWork = TRUE)
	recorded_attempt_path <- attempt_receipt$path
	if (!is.character(recorded_attempt_path) || length(recorded_attempt_path) != 1L ||
			is.na(recorded_attempt_path) ||
			!identical(normalizePath(recorded_attempt_path, winslash = "/", mustWork = FALSE), actual_attempt_path)) {
		stop("attempt manifest path does not match the run provenance receipt", call. = FALSE)
	}
	actual_attempt_identity <- comprehensive_result_file_identity(actual_attempt_path, include_sha256 = TRUE)
	recorded_attempt_identity <- attempt_receipt$identity
	if (!is.list(recorded_attempt_identity) || !identical(recorded_attempt_identity$exists, TRUE) ||
			!is.numeric(recorded_attempt_identity$bytes) || length(recorded_attempt_identity$bytes) != 1L ||
			!identical(as.numeric(recorded_attempt_identity$bytes), actual_attempt_identity$bytes) ||
			!is.character(recorded_attempt_identity$sha256) || length(recorded_attempt_identity$sha256) != 1L ||
			is.na(recorded_attempt_identity$sha256) ||
			!identical(tolower(recorded_attempt_identity$sha256), tolower(actual_attempt_identity$sha256))) {
		stop("attempt manifest bytes or SHA-256 do not match the run provenance receipt", call. = FALSE)
	}
	if (!exists("reconcile_todo23_attempts", mode = "function", inherits = TRUE)) {
		stop("source R/package_tests/validate_todo23_attempt_reconciliation.R before validating attempt events", call. = FALSE)
	}
	events <- utils::read.csv(actual_attempt_path, stringsAsFactors = FALSE,
		check.names = FALSE, na.strings = c("", "NA"))
	required_event_fields <- c("event_seq", "event_type", key_columns, "function_run", "status")
	missing_event_fields <- setdiff(required_event_fields, names(events))
	if (length(missing_event_fields)) {
		stop("attempt manifest is missing field(s): ", paste(missing_event_fields, collapse = ", "), call. = FALSE)
	}
	reconciliation <- reconcile_todo23_attempts(
		expected_manifest = expected_manifest,
		events = events,
		results = result_rows,
		key_columns = key_columns,
		method_column = "function_run"
	)
	if (nrow(reconciliation$result_missing) || nrow(reconciliation$result_extra) ||
			nrow(reconciliation$result_duplicates) || nrow(reconciliation$event_missing) ||
			nrow(reconciliation$event_extra) || nrow(reconciliation$terminal_without_result) ||
			nrow(reconciliation$result_without_terminal) || nrow(reconciliation$terminal_status_mismatches)) {
		stop("TODO-99 attempt events and result rows do not reconcile to the expected manifest", call. = FALSE)
	}
	# Setup-level skip/failure records intentionally lack an inference/function key;
	# they are context, not operation attempts. Keep them visible in the result,
	# and reject any other unkeyed event so malformed operation records cannot pass.
	unkeyed_events <- events[reconciliation$unkeyed_event_rows, , drop = FALSE]
	if (nrow(unkeyed_events) && any(!as.character(unkeyed_events$event_type) %in% c("setup_skipped", "setup_failure"))) {
		stop("TODO-99 attempt manifest contains an unkeyed non-setup event", call. = FALSE)
	}
	state <- reconciliation$event_state
	if (nrow(state) != nrow(expected_manifest) || any(state$started != 1L | state$terminal != 1L |
			state$unclosed_starts != 0L | state$orphan_terminals != 0L | state$overlapping_starts != 0L)) {
		stop("each expected TODO-99 key must have exactly one well-formed started/terminal pair", call. = FALSE)
	}
	if (nrow(reconciliation$terminal_result_counts) != nrow(expected_manifest) ||
			any(!reconciliation$terminal_result_counts$count_match)) {
		stop("TODO-99 terminal-event and result-row counts differ", call. = FALSE)
	}
	invisible(list(
		results_file = validated$results_file,
		rows = nrow(result_rows),
		attempt_events = nrow(events),
		unkeyed_setup_events = nrow(unkeyed_events),
		provenance = provenance,
		reconciliation = reconciliation
	))
}
