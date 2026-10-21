# Resolve the raw result inputs and audit state files. By default the audit
# reads and writes beside itself; the shared results-directory override keeps
# isolated harness output, baseline, and stamp together in one existing folder.
resolve_comprehensive_audit_paths <- function(
  here,
  response_types,
  output_dir = Sys.getenv("EDI_COMPREHENSIVE_RESULTS_DIR", unset = "")
) {
  if (length(here) != 1L || is.na(here) || !nzchar(here)) {
    stop("here must be one nonempty directory path.", call. = FALSE)
  }
  if (!is.character(response_types) || anyNA(response_types) || any(!nzchar(response_types))) {
    stop("response_types must be nonempty character values.", call. = FALSE)
  }
  if (length(output_dir) != 1L || is.na(output_dir)) {
    stop("EDI_COMPREHENSIVE_RESULTS_DIR must be one directory path.", call. = FALSE)
  }
  if (nzchar(output_dir)) {
    if (!dir.exists(output_dir)) {
      stop("EDI_COMPREHENSIVE_RESULTS_DIR is not an existing directory: ", output_dir, call. = FALSE)
    }
    audit_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
  } else {
    audit_dir <- here
  }
  list(
    files = stats::setNames(
      file.path(audit_dir, sprintf("comprehensive_tests_results_nc_1_%s.csv", response_types)),
      response_types
    ),
    baseline = file.path(audit_dir, "comprehensive_results_audit_baseline.csv"),
    stamp = file.path(audit_dir, ".comprehensive_results_audit_stamp")
  )
}

# A baseline replacement is suite-wide: absent response files would make all
# of their prior findings look resolved. This checks file presence, required
# result columns, and at least one row only; the caller must still establish
# that each input is a complete, provenance-valid result file.
validate_comprehensive_audit_baseline_inputs <- function(files) {
  if (!is.character(files) || !length(files) || is.null(names(files)) ||
      anyNA(names(files)) || any(!nzchar(names(files))) || anyDuplicated(names(files))) {
    stop("files must be a named character vector of response-level paths.", call. = FALSE)
  }
  present <- file.exists(files)
  nonempty <- present & file.info(files)$size > 0
  invalid <- !present | is.na(nonempty) | !nonempty
  if (any(invalid)) {
    missing_types <- names(files)[invalid]
    stop(
      "Refusing --write-baseline: missing or empty response-level inputs for: ",
      paste(missing_types, collapse = ", "),
      call. = FALSE
    )
  }
  required_columns <- c(
    "inference_class", "function_run", "status", "result", "result_1", "result_2",
    "beta_T", "coverage_truth", "beta_T_in_confidence_interval", "error_message"
  )
  has_one_result_row <- vapply(files, function(path) {
    first_row <- tryCatch(
      utils::read.csv(path, nrows = 1L, check.names = FALSE, stringsAsFactors = FALSE),
      error = function(e) NULL
    )
    !is.null(first_row) && nrow(first_row) == 1L && all(required_columns %in% names(first_row))
  }, logical(1L))
  invalid <- !has_one_result_row
  if (any(invalid)) {
    invalid_types <- names(files)[invalid]
    stop(
      "Refusing --write-baseline: response-level inputs must have the result schema and at least one data row for: ",
      paste(invalid_types, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(TRUE)
}
