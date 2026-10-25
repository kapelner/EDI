# Read-only validator for the TODO-14 IVWC rand candidate CSV.
# Source this file and call validate_todo14_candidate() with the source-derived
# expected-attempt manifest, isolated candidate output, and captured package
# provenance. It never writes to either input.

.todo14_key_columns <- c(
	"rep", "beta_T", "dataset", "response_type", "design",
	"inference_class", "function_run"
)

.todo14_required_candidate_columns <- c(
	"id", .todo14_key_columns, "run_row_id", "status", "error_message", "skip_reason",
	"method_family", "coverage_scope", "argument_coverage_kind",
	"github_commit_id", "timestamp", "result_1", "result_2",
	"coverage_truth", "beta_T_in_confidence_interval"
)

.todo14_expected_classes <- c(
	"InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC [design_formula=~1]",
	"InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC [design_formula=~.]"
)

.todo14_expected_functions <- c(
	"compute_rand_two_sided_pval",
	"compute_rand_two_sided_pval(delta=0.5)",
	"compute_rand_confidence_interval"
)

.todo14_expected_datasets <- c(
	"diamonds", "pte_example", "ionosphere", "abalone", "iris",
	"boston", "fuel", "cars", "airquality"
)

.todo14_provenance_fields <- c(
	"checkout_sha", "r_version", "package_version", "library_path",
	"dll_path", "dll_sha256"
)

.todo14_read_table <- function(x, label) {
	if (is.data.frame(x)) return(as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE))
	if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
		stop(label, " must be a data.frame or one nonempty CSV path.", call. = FALSE)
	}
	if (!file.exists(x)) stop(label, " does not exist: ", x, call. = FALSE)
	utils::read.csv(x, stringsAsFactors = FALSE, check.names = FALSE, na.strings = c("", "NA"))
}

.todo14_nonempty <- function(x) {
	!is.na(x) & nzchar(trimws(as.character(x)))
}

.todo14_beta_token <- function(x) {
	value <- suppressWarnings(as.numeric(as.character(x)))
	ifelse(is.finite(value), format(value, scientific = TRUE, digits = 17), "<invalid-beta>")
}

.todo14_build_id <- function(data) {
	rep_value <- suppressWarnings(as.integer(as.character(data$rep)))
	paste(
		rep_value,
		.todo14_beta_token(data$beta_T),
		as.character(data$dataset),
		as.character(data$response_type),
		as.character(data$design),
		as.character(data$inference_class),
		as.character(data$function_run),
		sep = "||"
	)
}

.todo14_natural_key <- function(data) {
	.todo14_build_id(data)
}

.todo14_assignment_rhs <- function(exprs, name, top_level_only = FALSE) {
	find <- function(node) {
		if (!is.call(node) || identical(node[[1L]], as.name("function"))) return(NULL)
		if ((identical(node[[1L]], as.name("<-")) || identical(node[[1L]], as.name("="))) &&
				length(node) >= 3L && identical(node[[2L]], as.name(name))) return(node[[3L]])
		if (top_level_only) return(NULL)
		for (child in as.list(node)[-1L]) {
			found <- find(child)
			if (!is.null(found)) return(found)
		}
		NULL
	}
	found <- lapply(as.list(exprs), find)
	found <- Filter(Negate(is.null), found)
	if (length(found) != 1L) {
		stop("expected one source assignment for ", name, call. = FALSE)
	}
	found[[1L]]
}

.todo14_literal_vector <- function(expr, mode, label) {
	if (!is.call(expr) || !identical(expr[[1L]], as.name("c"))) {
		stop(label, " must remain a literal c(...) source axis", call. = FALSE)
	}
	values <- as.list(expr)[-1L]
	valid <- if (mode == "character") vapply(values, is.character, logical(1)) else
		vapply(values, function(x) is.numeric(x) && length(x) == 1L && is.finite(x), logical(1))
	if (!length(values) || !all(valid)) stop(label, " contains a non-literal value", call. = FALSE)
	unlist(values, use.names = FALSE)
}

.todo14_named_argument <- function(expr, name) {
	if (!is.call(expr)) return(NULL)
	args <- as.list(expr)[-1L]
	arg_names <- names(args)
	if (is.null(arg_names) || !name %in% arg_names) return(NULL)
	args[[match(name, arg_names)]]
}

.todo14_survival_dataset_roster <- function(dataset_source_path) {
	if (!file.exists(dataset_source_path) || dir.exists(dataset_source_path)) {
		stop("dataset_source_path must name the checked-in dataset loader", call. = FALSE)
	}
	exprs <- parse(dataset_source_path, keep.source = FALSE)
	dataset_expr <- .todo14_assignment_rhs(exprs, "datasets_and_response_models", top_level_only = TRUE)
	if (!is.call(dataset_expr) || !identical(dataset_expr[[1L]], as.name("list"))) {
		stop("datasets_and_response_models must remain a literal list", call. = FALSE)
	}
	entries <- as.list(dataset_expr)[-1L]
	dataset_names <- names(entries)
	if (is.null(dataset_names) || anyNA(dataset_names) || any(!nzchar(dataset_names))) {
		stop("source dataset entries must all have literal names", call. = FALSE)
	}
	transform_rhs <- .todo14_assignment_rhs(exprs, "finagle_different_responses_from_continuous", top_level_only = TRUE)
	if (!is.call(transform_rhs) || !identical(transform_rhs[[1L]], as.name("function"))) {
		stop("response transformer must remain a literal function", call. = FALSE)
	}
	walk <- function(node, fn) {
		if (!is.call(node)) return(invisible(NULL))
		fn(node)
		for (child in as.list(node)[-1L]) walk(child, fn)
		invisible(NULL)
	}
	response_lists <- list()
	walk(transform_rhs[[3L]], function(node) {
		if (identical(node[[1L]], as.name("list")) && "survival" %in% names(as.list(node)[-1L])) {
			response_lists[[length(response_lists) + 1L]] <<- node
		}
	})
	if (length(response_lists) != 1L) {
		stop("response transformer must expose one literal survival response list", call. = FALSE)
	}
	response_keys <- names(as.list(response_lists[[1L]])[-1L])
	pairs <- lapply(seq_along(entries), function(i) {
		y_expr <- .todo14_named_argument(entries[[i]], "y_original")
		if (is.call(y_expr) && identical(y_expr[[1L]], as.name("finagle_different_responses_from_continuous"))) {
			responses <- response_keys
		} else if (is.call(y_expr) && identical(y_expr[[1L]], as.name("list"))) {
			responses <- names(as.list(y_expr)[-1L])
			if (is.null(responses)) stop("direct y_original response lists must be named", call. = FALSE)
		} else {
			stop("unsupported y_original expression for ", dataset_names[[i]], call. = FALSE)
		}
		if (!"survival" %in% responses) return(character())
		dataset_names[[i]]
	})
	datasets <- unique(unlist(pairs, use.names = FALSE))
	if (!length(datasets) || anyNA(datasets) || any(!nzchar(datasets))) {
		stop("no named survival datasets are declared in source", call. = FALSE)
	}
	datasets
}

# Generate a source-bound candidate-key inventory for the fixed TODO-14 scope.
# It intentionally does not claim that every candidate reaches an emitted
# safe_call: setup, capability, and runtime skip decisions belong to the live
# runner and must be accounted for from its attempt-event output.
todo14_source_candidate_manifest <- function(
	runner_path,
	dataset_source_path,
	Nrep = 40L
){
	if (!is.numeric(Nrep) || length(Nrep) != 1L || is.na(Nrep) || !is.finite(Nrep) || Nrep != 40L) {
		stop("TODO-14 source candidate scope is fixed to the checked-in 40-replicate run", call. = FALSE)
	}
	if (!file.exists(runner_path) || dir.exists(runner_path)) {
		stop("runner_path must name the checked-in comprehensive_tests.R", call. = FALSE)
	}
	runner_exprs <- parse(runner_path, keep.source = FALSE)
	nrep_rhs <- .todo14_assignment_rhs(runner_exprs, "Nrep", top_level_only = TRUE)
	if (!is.call(nrep_rhs) || !identical(nrep_rhs[[1L]], as.name("if")) ||
			length(nrep_rhs) != 4L || !is.numeric(nrep_rhs[[4L]]) || as.integer(nrep_rhs[[4L]]) != 40L) {
		stop("runner default Nrep no longer matches the 40-replicate TODO-14 scope", call. = FALSE)
	}
	designs <- .todo14_literal_vector(
		.todo14_assignment_rhs(runner_exprs, "TESTED_DESIGNS", top_level_only = TRUE),
		"character", "TESTED_DESIGNS"
	)
	target_designs <- c("KK21stepwise", "FixedBinaryMatch")
	if (!all(target_designs %in% designs)) {
		stop("runner TESTED_DESIGNS no longer includes both TODO-14 target designs", call. = FALSE)
	}
	formula_rhs <- .todo14_assignment_rhs(runner_exprs, "formulas_to_test")
	if (!is.call(formula_rhs) || !identical(formula_rhs[[1L]], as.name("list"))) {
		stop("runner formulas_to_test must remain a literal list", call. = FALSE)
	}
	formulas <- vapply(as.list(formula_rhs)[-1L], function(expr) {
		paste(deparse(expr, width.cutoff = 500L), collapse = "")
	}, character(1))
	if (!setequal(gsub("[[:space:]]", "", formulas), c("~1", "~."))) {
		stop("runner formulas_to_test no longer matches the two TODO-14 formula arms", call. = FALSE)
	}
	beta_rhs <- .todo14_assignment_rhs(runner_exprs, "beta_T_values", top_level_only = TRUE)
	if (!is.call(beta_rhs) || !identical(beta_rhs[[1L]], as.name("resolve_comprehensive_beta_values")) ||
			length(beta_rhs) < 3L) {
		stop("runner beta_T_values no longer uses the expected default-axis resolver", call. = FALSE)
	}
	betas <- as.numeric(.todo14_literal_vector(as.list(beta_rhs)[[2L]], "numeric", "default beta_T axis"))
	if (!setequal(betas, c(0, 0.5))) stop("runner default beta_T axis changed", call. = FALSE)
	selector_rhs <- .todo14_assignment_rhs(runner_exprs, "select_kk_survival_class_generators", top_level_only = TRUE)
	selector_source <- paste(deparse(selector_rhs, width.cutoff = 500L), collapse = " ")
	if (!grepl("InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC", selector_source, fixed = TRUE)) {
		stop("runner no longer selects the TODO-14 target class", call. = FALSE)
	}
	run_checks_rhs <- .todo14_assignment_rhs(runner_exprs, "run_inference_checks_impl")
	runner_ops <- paste(deparse(run_checks_rhs, width.cutoff = 500L), collapse = " ")
	if (!all(vapply(.todo14_expected_functions, grepl, logical(1), x = runner_ops, fixed = TRUE))) {
		stop("runner no longer contains every TODO-14 rand operation label", call. = FALSE)
	}
	datasets <- .todo14_survival_dataset_roster(dataset_source_path)
	if (!setequal(datasets, .todo14_expected_datasets)) {
		stop("source survival-dataset roster differs from the validated TODO-14 scope", call. = FALSE)
	}
	formula_labels <- gsub("[[:space:]]", "", formulas)
	classes <- paste0("InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC [design_formula=", formula_labels, "]")
	manifest <- expand.grid(
		rep = seq_len(as.integer(Nrep)), beta_T = betas, dataset = datasets,
		response_type = "survival", design = target_designs,
		inference_class = classes, function_run = .todo14_expected_functions,
		KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
	)
	manifest$id <- .todo14_build_id(manifest)
	manifest$candidate_status <- "candidate_only_requires_setup_and_runtime_eligibility"
	manifest$scope_source <- "checked_in_runner_defaults_without_cli_filters"
	if (nrow(manifest) != 8640L || anyDuplicated(manifest$id)) {
		stop("TODO-14 source candidate scope did not produce 8640 unique candidate keys", call. = FALSE)
	}
	manifest
}

# G6 #33 (decided 2026-10-22): the FixedBinaryMatch x pte_example x
# design_formula=~1 keys are a predeclared expected skip. The runner's
# FixedBinaryMatch constructor supplies no matched-pair ids and pte_example has
# no pair-id column, so that setup cannot run. The keys stay in the 8,640-key
# manifest and are counted separately; validators accept them only when they
# are passed explicitly as `approved_skips`.
.todo14_formula_label <- function(inference_class) {
	label <- sub("^.*\\[design_formula=(.*)\\]$", "\\1", as.character(inference_class))
	label[label == as.character(inference_class)] <- NA_character_
	gsub("[[:space:]]", "", label)
}

todo14_predeclared_approved_skips <- function(manifest) {
	manifest <- .todo14_read_table(manifest, "manifest")
	missing <- setdiff(c("id", .todo14_key_columns), names(manifest))
	if (length(missing)) stop("manifest is missing column(s): ", paste(missing, collapse = ", "), call. = FALSE)
	keep <- as.character(manifest$design) == "FixedBinaryMatch" &
		as.character(manifest$dataset) == "pte_example" &
		.todo14_formula_label(manifest$inference_class) %in% "~1"
	out <- manifest[keep, c("id", .todo14_key_columns), drop = FALSE]
	out$skip_rule <- rep("G6#33: FixedBinaryMatch design_formula=~1 on pte_example (no matched-pair ids)", nrow(out))
	rownames(out) <- NULL
	out
}

# R5 re-scope (owner decision 2026-10-25), on top of G6 #33:
# (a) every FixedBinaryMatch x design_formula=~1 key, not only pte_example: the
#     runner skips that setup on all nine datasets ("no covariates provided to
#     run the binary matching algorithm"), so the G6 #33 skip was too narrow;
# (b) compute_rand_confidence_interval x design_formula=~. on the four wide
#     datasets, where nearly every call hit the runner's per-call timeout (R5
#     batch 2026-10-23/25: 419 of 536 timeouts). The two rand p-values stay
#     gated everywhere.
TODO14_R5_RESCOPE_WIDE_DATASETS <- c("fuel", "ionosphere", "diamonds", "cars")

todo14_r5_rescope_approved_skips <- function(manifest) {
	manifest <- .todo14_read_table(manifest, "manifest")
	missing <- setdiff(c("id", .todo14_key_columns), names(manifest))
	if (length(missing)) stop("manifest is missing column(s): ", paste(missing, collapse = ", "), call. = FALSE)
	formula_label <- .todo14_formula_label(manifest$inference_class)
	fbm_no_covariates <- as.character(manifest$design) == "FixedBinaryMatch" & formula_label %in% "~1"
	wide_rand_ci <- as.character(manifest$function_run) == "compute_rand_confidence_interval" &
		formula_label %in% "~." & as.character(manifest$dataset) %in% TODO14_R5_RESCOPE_WIDE_DATASETS
	out <- manifest[fbm_no_covariates | wide_rand_ci, c("id", .todo14_key_columns), drop = FALSE]
	out$skip_rule <- ifelse(
		fbm_no_covariates[fbm_no_covariates | wide_rand_ci],
		"G6#33 + R5 re-scope 2026-10-25: FixedBinaryMatch design_formula=~1 (no covariates to match on)",
		"R5 re-scope 2026-10-25: rand CI on design_formula=~. for a wide dataset (per-call timeout)"
	)
	rownames(out) <- NULL
	out
}

# Normalise `approved_skips` (NULL, a character vector of ids, or a table with
# an id column and/or the natural-key columns) to a character id vector. A
# table that carries both must agree with the serialized natural key.
.todo14_approved_skip_ids <- function(approved_skips) {
	if (is.null(approved_skips)) return(character())
	if (is.character(approved_skips)) {
		ids <- approved_skips
	} else {
		approved_skips <- .todo14_read_table(approved_skips, "approved_skips")
		has_keys <- all(.todo14_key_columns %in% names(approved_skips))
		if (!"id" %in% names(approved_skips) && !has_keys) {
			stop("approved_skips must carry an id column or every natural-key column", call. = FALSE)
		}
		built <- if (has_keys) .todo14_build_id(approved_skips) else NULL
		ids <- if ("id" %in% names(approved_skips)) as.character(approved_skips$id) else built
		if (!is.null(built) && (anyNA(ids) || any(ids != built))) {
			stop("approved_skips id differs from its natural-key fields", call. = FALSE)
		}
	}
	ids <- as.character(ids)
	if (anyNA(ids) || any(!nzchar(trimws(ids)))) stop("approved_skips contains missing/empty ids", call. = FALSE)
	if (anyDuplicated(ids)) stop("approved_skips contains duplicate ids", call. = FALSE)
	ids
}

.todo14_provenance_problem <- function(provenance, expected_provenance) {
	problems <- character()
	if (!is.list(provenance) || !all(c("before", "after") %in% names(provenance))) {
		return("provenance must contain before and after snapshots")
	}
	if (!is.list(provenance$before) || !is.list(provenance$after)) {
		return("provenance before and after snapshots must be named lists")
	}
	if (!is.list(expected_provenance)) return("expected_provenance must be a named list")
	if (anyDuplicated(names(provenance$before))) {
		problems <- c(problems, "provenance before snapshot has duplicate field names")
	}
	if (anyDuplicated(names(provenance$after))) {
		problems <- c(problems, "provenance after snapshot has duplicate field names")
	}
	if (anyDuplicated(names(expected_provenance))) {
		problems <- c(problems, "expected provenance has duplicate field names")
	}
	for (field in .todo14_provenance_fields) {
		before_field <- provenance$before[[field]]
		after_field <- provenance$after[[field]]
		expected_field <- expected_provenance[[field]]
		if (length(before_field) != 1L || !.todo14_nonempty(before_field) ||
			length(after_field) != 1L || !.todo14_nonempty(after_field)) {
			problems <- c(problems, paste0("missing provenance field: ", field))
			next
		}
		if (length(expected_field) != 1L || !.todo14_nonempty(expected_field)) {
			problems <- c(problems, paste0("missing expected provenance field: ", field))
			next
		}
		before_value <- as.character(before_field)
		after_value <- as.character(after_field)
		expected_value <- as.character(expected_field)
		if (!identical(before_value, after_value)) {
			problems <- c(problems, paste0("provenance changed during run: ", field))
		}
		if (!identical(after_value, expected_value)) {
			problems <- c(problems, paste0("provenance differs from expected: ", field))
		}
	}
	sha <- expected_provenance$dll_sha256
	if (length(sha) == 1L && .todo14_nonempty(sha) && !grepl("^[[:xdigit:]]{64}$", as.character(sha))) {
		problems <- c(problems, "expected dll_sha256 must be a 64-character SHA-256")
	}
	checkout <- expected_provenance$checkout_sha
	if (length(checkout) == 1L && .todo14_nonempty(checkout) && !grepl("^[[:xdigit:]]{40}([[:xdigit:]]{24})?$", as.character(checkout))) {
		problems <- c(problems, "expected checkout_sha must be a 40- or 64-character hexadecimal hash")
	}
	unique(problems)
}

#' Validate a TODO-14 candidate against its source-derived candidate inventory.
#'
#' The function reports structural/result/provenance problems without editing
#' inputs. A successful validation is candidate-only evidence: it does not
#' establish that every source candidate passed setup/runtime eligibility or
#' was actually attempted. `provenance` must contain `before` and `after`
#' snapshots, each with checkout_sha, r_version, package_version, library_path,
#' dll_path and dll_sha256. `expected_provenance` contains the approved values
#' for those same fields; callers must not treat an unverified/old DLL as the
#' target.
#'
#' `approved_skips` (2026-10-22, G6 #33) lists manifest keys that were approved
#' as expected skips before the run (see todo14_predeclared_approved_skips()).
#' Each such key may be absent from the candidate (the runner's setup skip
#' writes no result row) or present as a skip row (status ok, nonempty
#' skip_reason, no results); it is never accepted with a result. Every other
#' key keeps the full success contract. Approved-skip counts are returned.
validate_todo14_candidate <- function(manifest, candidate, provenance, expected_provenance, approved_skips = NULL) {
	manifest <- .todo14_read_table(manifest, "manifest")
	candidate <- .todo14_read_table(candidate, "candidate")
	approved_ids <- .todo14_approved_skip_ids(approved_skips)
	issue_rows <- list()
	add_issue <- function(check, detail, row = NA_integer_, id = NA_character_) {
		issue_rows[[length(issue_rows) + 1L]] <<- data.frame(
			check = as.character(check), row = as.integer(row), id = as.character(id),
			detail = as.character(detail), stringsAsFactors = FALSE
		)
	}
	collect_issues <- function() {
		if (!length(issue_rows)) {
			return(data.frame(check = character(), row = integer(), id = character(), detail = character(), stringsAsFactors = FALSE))
		}
		do.call(rbind, issue_rows)
	}

	manifest_missing <- setdiff(c(
		"id", .todo14_key_columns, "candidate_status", "scope_source"
	), names(manifest))
	candidate_missing <- setdiff(.todo14_required_candidate_columns, names(candidate))
	if (length(manifest_missing)) add_issue("manifest_schema", paste("missing columns:", paste(manifest_missing, collapse = ", ")))
	if (length(candidate_missing)) add_issue("candidate_schema", paste("missing columns:", paste(candidate_missing, collapse = ", ")))
	if (length(manifest_missing) || length(candidate_missing)) {
		return(list(ok = FALSE, issues = collect_issues(), missing_ids = character(), extra_ids = character()))
	}

	if (nrow(manifest) != 8640L) add_issue("manifest_row_count", paste("expected 8640 rows; found", nrow(manifest)))
	if (anyNA(manifest$candidate_status) || any(as.character(manifest$candidate_status) !=
			"candidate_only_requires_setup_and_runtime_eligibility")) {
		add_issue("manifest_candidate_status", "manifest must remain explicitly candidate-only pending setup/runtime eligibility")
	}
	manifest_attempt_fields <- intersect(
		c("status", "expected_status", "skip_reason", "error_message", "runtime_eligible", "attempted", "attempt_event"),
		names(manifest)
	)
	if (length(manifest_attempt_fields)) {
		add_issue(
			"manifest_attempt_fields",
			paste("candidate manifest must remain key-only; attempt/runtime fields are not accepted:",
				paste(manifest_attempt_fields, collapse = ", "))
		)
	}
	if (anyNA(manifest$scope_source) || any(as.character(manifest$scope_source) !=
			"checked_in_runner_defaults_without_cli_filters")) {
		add_issue("manifest_scope_source", "manifest scope must identify the checked-in runner defaults without CLI filters")
	}
	manifest_rep <- suppressWarnings(as.numeric(as.character(manifest$rep)))
	candidate_rep <- suppressWarnings(as.numeric(as.character(candidate$rep)))
	bad_manifest_rep <- !is.finite(manifest_rep) | manifest_rep < 1 | manifest_rep != floor(manifest_rep)
	bad_candidate_rep <- !is.finite(candidate_rep) | candidate_rep < 1 | candidate_rep != floor(candidate_rep)
	for (i in which(bad_manifest_rep)) {
		add_issue("invalid_manifest_rep", "manifest rep must be a positive finite integer", i, as.character(manifest$id[i]))
	}
	for (i in which(bad_candidate_rep)) {
		add_issue("invalid_rep", "candidate rep must be a positive finite integer", i, as.character(candidate$id[i]))
	}

	manifest_ids <- as.character(manifest$id)
	candidate_ids <- as.character(candidate$id)
	if (any(!.todo14_nonempty(manifest_ids))) add_issue("manifest_id_missing", "manifest contains missing/empty id values")
	if (any(!.todo14_nonempty(candidate_ids))) add_issue("candidate_id_missing", "candidate contains missing/empty id values")
	for (i in which(duplicated(manifest_ids) | duplicated(manifest_ids, fromLast = TRUE))) {
		add_issue("duplicate_manifest_id", "manifest id is not unique", i, manifest_ids[i])
	}
	for (i in which(duplicated(candidate_ids) | duplicated(candidate_ids, fromLast = TRUE))) {
		add_issue("duplicate_candidate_id", "candidate id is not unique", i, candidate_ids[i])
	}

	manifest_natural <- .todo14_natural_key(manifest)
	candidate_natural <- .todo14_natural_key(candidate)
	for (i in which(duplicated(candidate_natural) | duplicated(candidate_natural, fromLast = TRUE))) {
		add_issue("duplicate_natural_key", "candidate natural key is not unique", i, candidate_ids[i])
	}
	manifest_id_from_fields <- .todo14_build_id(manifest)
	candidate_id_from_fields <- .todo14_build_id(candidate)
	for (i in which(is.na(manifest_ids) | manifest_ids != manifest_id_from_fields)) {
		add_issue("manifest_id_key_mismatch", "manifest id differs from serialized natural key", i, manifest_ids[i])
	}
	for (i in which(is.na(candidate_ids) | candidate_ids != candidate_id_from_fields)) {
		add_issue("candidate_id_key_mismatch", "candidate id differs from serialized natural key", i, candidate_ids[i])
	}

	missing_ids <- setdiff(manifest_ids[.todo14_nonempty(manifest_ids)], candidate_ids[.todo14_nonempty(candidate_ids)])
	extra_ids <- setdiff(candidate_ids[.todo14_nonempty(candidate_ids)], manifest_ids[.todo14_nonempty(manifest_ids)])
	for (id in setdiff(approved_ids, manifest_ids)) {
		add_issue("approved_skip_not_in_manifest", "approved skip key is not in the manifest", id = id)
	}
	approved_absent_ids <- intersect(missing_ids, approved_ids)
	missing_ids <- setdiff(missing_ids, approved_ids)
	expected_candidate_rows <- 8640L - length(approved_absent_ids)
	if (nrow(candidate) != expected_candidate_rows) {
		add_issue("candidate_row_count", paste0("expected ", expected_candidate_rows, " rows (8640 minus ",
			length(approved_absent_ids), " absent approved skips); found ", nrow(candidate)))
	}
	for (id in missing_ids) add_issue("missing_id", "expected attempt is absent", id = id)
	for (id in extra_ids) add_issue("unexpected_id", "candidate id is not in manifest", id = id)

	run_row_id <- suppressWarnings(as.numeric(as.character(candidate$run_row_id)))
	bad_run_row_id <- !is.finite(run_row_id) | run_row_id <= 0 | run_row_id != floor(run_row_id)
	for (i in which(bad_run_row_id)) add_issue("invalid_run_row_id", "run_row_id must be a positive finite integer", i, candidate_ids[i])
	for (i in which(duplicated(run_row_id) | duplicated(run_row_id, fromLast = TRUE))) {
		add_issue("duplicate_run_row_id", "run_row_id is not unique", i, candidate_ids[i])
	}

	# Every non-replicate key must contain exactly reps 1:40. The exact ID
	# anti-join is still reported separately so a malformed manifest cannot
	# silently define a weaker replication contract.
	group_fields <- c("beta_T", "dataset", "response_type", "design", "inference_class", "function_run")
	group_key <- function(data) paste(.todo14_beta_token(data$beta_T), data$dataset, data$response_type,
		data$design, data$inference_class, data$function_run, sep = "||")
	manifest_groups <- unique(group_key(manifest))
	approved_absent_rows <- manifest[manifest_ids %in% approved_absent_ids, , drop = FALSE]
	for (g in manifest_groups) {
		mrep <- sort(unique(suppressWarnings(as.integer(as.character(manifest$rep[group_key(manifest) == g])))))
		crep <- sort(unique(suppressWarnings(as.integer(as.character(c(
			candidate$rep[group_key(candidate) == g],
			approved_absent_rows$rep[group_key(approved_absent_rows) == g]
		))))))
		if (!identical(mrep, 1:40)) add_issue("manifest_replicates", paste("manifest group does not contain reps 1:40:", g))
		if (!identical(crep, 1:40)) add_issue("candidate_replicates", paste("candidate group does not contain reps 1:40:", g))
	}

	approved_row <- candidate_ids %in% approved_ids
	for (i in seq_len(nrow(candidate))) {
		row <- candidate[i, , drop = FALSE]
		if (approved_row[i]) {
			# Approved skip present as a row: it must be a skip, never a result.
			has_result <- .todo14_nonempty(row$result_1) || .todo14_nonempty(row$result_2)
			if (!identical(as.character(row$status), "ok") || !.todo14_nonempty(row$skip_reason) || has_result) {
				add_issue("approved_skip_not_skipped", "approved skip key must be absent or a status=ok skip row with skip_reason and no results", i, candidate_ids[i])
			}
		}
		if (!identical(as.character(row$response_type), "survival")) add_issue("wrong_response_type", "expected survival", i, candidate_ids[i])
		beta_value <- suppressWarnings(as.numeric(as.character(row$beta_T)))
		if (!is.finite(beta_value) || !(beta_value %in% c(0, 0.5))) add_issue("wrong_beta_T", "beta_T is outside the TODO-14 target set", i, candidate_ids[i])
		if (!(as.character(row$dataset) %in% .todo14_expected_datasets)) add_issue("wrong_dataset", "dataset is outside the TODO-14 survival target set", i, candidate_ids[i])
		if (!(as.character(row$design) %in% c("KK21stepwise", "FixedBinaryMatch"))) add_issue("wrong_design", "design is outside the TODO-14 eligible set", i, candidate_ids[i])
		if (!(as.character(row$inference_class) %in% .todo14_expected_classes)) add_issue("wrong_inference_class", "unexpected IVWC formula label", i, candidate_ids[i])
		if (!(as.character(row$function_run) %in% .todo14_expected_functions)) add_issue("wrong_function_run", "function_run is outside the TODO-14 rand set", i, candidate_ids[i])
		if (!approved_row[i]) {
			if (!identical(as.character(row$status), "ok")) add_issue("status_not_ok", "status must be ok", i, candidate_ids[i])
			if (.todo14_nonempty(row$error_message)) add_issue("error_message_present", "error_message must be empty/NA", i, candidate_ids[i])
			if (.todo14_nonempty(row$skip_reason)) add_issue("skip_reason_present", "skip_reason must be empty/NA for a successful candidate row", i, candidate_ids[i])
		}
		if (!identical(as.character(row$method_family), "rand")) add_issue("wrong_method_family", "method_family must be rand", i, candidate_ids[i])
		if (!identical(as.character(row$coverage_scope), "comprehensive_workflow")) add_issue("wrong_coverage_scope", "coverage_scope must be comprehensive_workflow", i, candidate_ids[i])
		if (!identical(as.character(row$argument_coverage_kind), "not_argument_combination")) add_issue("wrong_argument_coverage_kind", "argument_coverage_kind must be not_argument_combination", i, candidate_ids[i])
		if (!.todo14_nonempty(row$github_commit_id)) add_issue("missing_github_commit_id", "github_commit_id must be nonempty", i, candidate_ids[i])
		if (!.todo14_nonempty(row$timestamp)) add_issue("missing_timestamp", "timestamp must be nonempty", i, candidate_ids[i])
	}

	provenance_problems <- .todo14_provenance_problem(provenance, expected_provenance)
	for (problem in provenance_problems) add_issue("provenance", problem)
	if (is.list(expected_provenance) && .todo14_nonempty(expected_provenance$checkout_sha)) {
		wrong_commit <- which(as.character(candidate$github_commit_id) != as.character(expected_provenance$checkout_sha))
		for (i in wrong_commit) add_issue("github_commit_id_mismatch", "row commit differs from captured checkout", i, candidate_ids[i])
	}

	function_run <- as.character(candidate$function_run)
	pval_rows <- which(function_run %in% .todo14_expected_functions[1:2] & !approved_row)
	pvals <- suppressWarnings(as.numeric(as.character(candidate$result_1[pval_rows])))
	bad_pval <- !is.finite(pvals) | pvals < 0 | pvals > 1
	for (j in which(bad_pval)) {
		i <- pval_rows[j]
		add_issue("invalid_p_value", "p-value result_1 must be finite and in [0,1]", i, candidate_ids[i])
	}

	ci_rows <- which(function_run == "compute_rand_confidence_interval" & !approved_row)
	ci_lo <- suppressWarnings(as.numeric(as.character(candidate$result_1[ci_rows])))
	ci_hi <- suppressWarnings(as.numeric(as.character(candidate$result_2[ci_rows])))
	truth <- suppressWarnings(as.numeric(as.character(candidate$coverage_truth[ci_rows])))
	ci_bad <- !is.finite(ci_lo) | !is.finite(ci_hi) | ci_lo > ci_hi
	truth_bad <- !is.finite(truth)
	for (j in which(ci_bad)) add_issue("invalid_ci", "CI endpoints must be finite and ordered", ci_rows[j], candidate_ids[ci_rows[j]])
	for (j in which(truth_bad)) add_issue("invalid_coverage_truth", "coverage_truth must be finite for CI rows", ci_rows[j], candidate_ids[ci_rows[j]])
	membership <- candidate$beta_T_in_confidence_interval[ci_rows]
	if (is.logical(membership)) {
		membership_value <- membership
	} else {
		membership_text <- tolower(trimws(as.character(membership)))
		membership_value <- ifelse(membership_text %in% c("true", "t", "1"), TRUE,
			ifelse(membership_text %in% c("false", "f", "0"), FALSE, NA))
	}
	expected_membership <- truth >= ci_lo & truth <= ci_hi
	membership_bad <- is.na(membership_value) | is.na(expected_membership) | membership_value != expected_membership
	for (j in which(membership_bad)) add_issue("coverage_membership_mismatch", "beta_T_in_confidence_interval must equal inclusive coverage_truth membership", ci_rows[j], candidate_ids[ci_rows[j]])

	issues <- collect_issues()
	list(
		ok = nrow(issues) == 0L,
		issues = issues,
		missing_ids = missing_ids,
		extra_ids = extra_ids,
		approved_skip_ids = approved_ids,
		counts = list(
			manifest_rows = nrow(manifest), candidate_rows = nrow(candidate), issues = nrow(issues),
			approved_skips = length(approved_ids),
			approved_skips_absent = length(approved_absent_ids),
			approved_skips_present_as_skip_rows = sum(approved_row)
		)
	)
}
