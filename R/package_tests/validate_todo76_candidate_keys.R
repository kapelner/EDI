# Read-only key validator for the TODO-76 ordinal Bayesian-bootstrap run.
# The caller must supply the maintainer-approved (design_formula,
# model_formula) pairs explicitly; this helper never chooses formula scope.
# Its result is key-set reconciliation only, not evidence that a row was
# emitted, attempted, runtime-eligible, or accepted.
.todo76_result_key_columns <- c(
	"rep", "beta_T", "dataset", "response_type", "design",
	"design_formula", "model_formula", "inference_class", "function_run"
)

.todo76_nonempty <- function(x) {
	!is.na(x) & nzchar(trimws(as.character(x)))
}

.todo76_beta_token <- function(x) {
	value <- suppressWarnings(as.numeric(as.character(x)))
	ifelse(is.finite(value), format(value, scientific = TRUE, digits = 17), "<invalid-beta>")
}

.todo76_key <- function(x) {
	values <- lapply(x[.todo76_result_key_columns], as.character)
	values$beta_T <- .todo76_beta_token(x$beta_T)
	vapply(seq_len(nrow(x)), function(i) {
		paste(vapply(values, function(col) {
			value <- col[[i]]
			paste0(nchar(value, type = "bytes"), ":", value)
		}, character(1L)), collapse = "|")
	}, character(1L))
}

# Build the source-potential key universe for an explicitly bounded runner
# case grid. The axes are passed in from the source contract rather than
# interpreted as an approved production target. For TODO-76, the runner
# evidence is `comprehensive_tests.R`: the two outer formulas in
# `formulas_to_test`, the five KK ordinal classes in the `is_kk_design`
# dispatch, and the ten labels emitted by the Bayesian-bootstrap CI/p-value
# loops. Runtime capability, filtering, skip, and model-construction gates
# still determine which of these possible keys are actually attempted.
todo76_candidate_key_universe <- function(case_grid, design_formulas, model_formulas,
		inference_classes, function_runs) {
	case_columns <- c("rep", "beta_T", "dataset", "response_type", "design")
	missing <- setdiff(case_columns, names(case_grid))
	if (!is.data.frame(case_grid) || length(missing)) {
		stop("case_grid must contain the runner's rep/beta/dataset/response/design dimensions", call. = FALSE)
	}
	if (nrow(case_grid) && (anyNA(case_grid[case_columns]) || any(!vapply(case_grid[case_columns], .todo76_nonempty, logical(nrow(case_grid)))))) {
		stop("case_grid dimensions must be complete and nonempty", call. = FALSE)
	}
	if (anyDuplicated(case_grid[case_columns])) stop("case_grid contains duplicate runner cases", call. = FALSE)
	validate_axis <- function(x, label) {
		if (!is.character(x) || !length(x) || anyNA(x) || any(!nzchar(trimws(x))) || anyDuplicated(x)) {
			stop(label, " must be a nonempty unique character vector", call. = FALSE)
		}
	}
	validate_axis(design_formulas, "design_formulas")
	validate_axis(model_formulas, "model_formulas")
	validate_axis(inference_classes, "inference_classes")
	validate_axis(function_runs, "function_runs")

	if (!nrow(case_grid)) return(case_grid[FALSE, case_columns, drop = FALSE])
	axes <- expand.grid(
		case_index = seq_len(nrow(case_grid)),
		design_formula = design_formulas,
		model_formula = model_formulas,
		inference_class_base = inference_classes,
		function_run = function_runs,
		KEEP.OUT.ATTRS = FALSE,
		stringsAsFactors = FALSE
	)
	out <- case_grid[axes$case_index, case_columns, drop = FALSE]
	out$design_formula <- axes$design_formula
	out$model_formula <- axes$model_formula
	out$inference_class <- paste0(
		axes$inference_class_base,
		" (model_formula=", axes$model_formula,
		") [design_formula=", axes$design_formula, "]"
	)
	out$function_run <- axes$function_run
	row.names(out) <- NULL
	out <- out[.todo76_result_key_columns]
	if (anyDuplicated(.todo76_key(out))) stop("candidate universe contains duplicate full result keys", call. = FALSE)
	out[order(out$rep, out$beta_T, out$dataset, out$design, out$design_formula,
		out$model_formula, out$inference_class, out$function_run), , drop = FALSE]
}

validate_todo76_candidate_keys <- function(manifest, candidate, approved_formula_pairs) {
	validation_scope <- "exact_key_set_only_not_attempt_validation"
	issues <- character()
	add_issue <- function(message) issues <<- c(issues, message)
	if (!is.data.frame(manifest)) add_issue("manifest must be a data.frame")
	if (!is.data.frame(candidate)) add_issue("candidate must be a data.frame")
	if (!is.data.frame(approved_formula_pairs) ||
		!all(c("design_formula", "model_formula") %in% names(approved_formula_pairs))) {
		add_issue("approved_formula_pairs must contain design_formula and model_formula")
	}
	if (length(issues)) return(list(ok = FALSE, issues = issues, missing_keys = character(), extra_keys = character(), validation_scope = validation_scope))

	manifest_missing <- setdiff(.todo76_result_key_columns, names(manifest))
	candidate_missing <- setdiff(.todo76_result_key_columns, names(candidate))
	if (length(manifest_missing)) add_issue(paste("manifest missing key field(s):", paste(manifest_missing, collapse = ", ")))
	if (length(candidate_missing)) add_issue(paste("candidate missing key field(s):", paste(candidate_missing, collapse = ", ")))
	manifest_extra_fields <- setdiff(names(manifest), .todo76_result_key_columns)
	if (length(manifest_extra_fields)) {
		add_issue(paste(
			"source-potential manifest must remain key-only; extra metadata/outcome fields are not accepted:",
			paste(manifest_extra_fields, collapse = ", ")
		))
	}
	if (length(issues)) return(list(ok = FALSE, issues = issues, missing_keys = character(), extra_keys = character(), validation_scope = validation_scope))

	pairs <- approved_formula_pairs[c("design_formula", "model_formula")]
	if (!nrow(pairs) || anyNA(pairs) || any(!vapply(pairs, .todo76_nonempty, logical(nrow(pairs))))) {
		add_issue("approved_formula_pairs must be nonempty and contain no missing/empty formulas")
	}
	# Length-prefix both fields so delimiter characters inside a formula cannot
	# make a distinct design/model pair compare equal to an approved pair.
	pair_key <- function(x) {
		design <- as.character(x$design_formula)
		model <- as.character(x$model_formula)
		paste0(nchar(design, type = "bytes"), ":", design, "|",
			nchar(model, type = "bytes"), ":", model)
	}
	if (nrow(pairs) && anyDuplicated(pair_key(pairs))) add_issue("approved_formula_pairs contains duplicates")
	if (nrow(manifest) && anyNA(manifest[.todo76_result_key_columns])) add_issue("manifest contains missing key values")
	if (nrow(candidate) && anyNA(candidate[.todo76_result_key_columns])) add_issue("candidate contains missing key values")
	if (nrow(manifest) && any(!vapply(manifest[.todo76_result_key_columns], .todo76_nonempty, logical(nrow(manifest))))) {
		add_issue("manifest contains empty key values")
	}
	if (nrow(candidate) && any(!vapply(candidate[.todo76_result_key_columns], .todo76_nonempty, logical(nrow(candidate))))) {
		add_issue("candidate contains empty key values")
	}
	manifest_beta <- suppressWarnings(as.numeric(as.character(manifest$beta_T)))
	candidate_beta <- suppressWarnings(as.numeric(as.character(candidate$beta_T)))
	if (any(!is.finite(manifest_beta))) add_issue("manifest beta_T values must be finite numbers")
	if (any(!is.finite(candidate_beta))) add_issue("candidate beta_T values must be finite numbers")
	if (length(issues)) return(list(ok = FALSE, issues = issues, missing_keys = character(), extra_keys = character(), validation_scope = validation_scope))

	approved_pairs <- pair_key(pairs)
	manifest_pairs <- unique(pair_key(manifest))
	if (!setequal(manifest_pairs, approved_pairs)) {
		add_issue("manifest formula pairs do not equal the explicitly approved formula pairs")
	}
	if (anyDuplicated(.todo76_key(manifest))) add_issue("manifest contains duplicate full result keys")
	if (anyDuplicated(.todo76_key(candidate))) add_issue("candidate contains duplicate full result keys")

	manifest_keys <- .todo76_key(manifest)
	candidate_keys <- .todo76_key(candidate)
	missing_keys <- setdiff(manifest_keys, candidate_keys)
	extra_keys <- setdiff(candidate_keys, manifest_keys)
	if (length(missing_keys)) add_issue(paste(length(missing_keys), "expected full result key(s) are missing"))
	if (length(extra_keys)) add_issue(paste(length(extra_keys), "unexpected full result key(s) are present"))
	list(
		ok = !length(issues), issues = issues, missing_keys = missing_keys,
		extra_keys = extra_keys, validation_scope = validation_scope
	)
}
