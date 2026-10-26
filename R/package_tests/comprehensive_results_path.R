# Resolve the comprehensive harness result path without changing its default.
# Set EDI_COMPREHENSIVE_RESULTS_DIR to an existing directory for isolated runs;
# the canonical filename (including filters) is preserved within that directory.
# EDI_COMPREHENSIVE_SKIP_PRUNE_CHECK=1 skips only the startup dry-run scan and
# is accepted only when results are redirected outside the checkout.
resolve_comprehensive_results_file <- function(
  default_path,
  output_dir = Sys.getenv("EDI_COMPREHENSIVE_RESULTS_DIR", unset = "")
) {
  if (length(default_path) != 1L || is.na(default_path) || !nzchar(default_path)) {
    stop("default_path must be one nonempty path.", call. = FALSE)
  }
  if (length(output_dir) != 1L || is.na(output_dir)) {
    stop("EDI_COMPREHENSIVE_RESULTS_DIR must be one directory path.", call. = FALSE)
  }
  if (!nzchar(output_dir)) return(default_path)
  if (!dir.exists(output_dir)) {
    stop("EDI_COMPREHENSIVE_RESULTS_DIR is not an existing directory: ", output_dir, call. = FALSE)
  }
  file.path(normalizePath(output_dir, winslash = "/", mustWork = TRUE), basename(default_path))
}

# Optional append-only event ledger for the comprehensive runner. This is a
# separate artifact: it deliberately does not add columns to the canonical
# result CSV. Refuse to reuse an existing file so events from distinct runs
# cannot be silently mixed. The one exception is resume = TRUE, which the
# watchdog sets (COMPREHENSIVE_ATTEMPT_MANIFEST_RESUME=1) only on a worker it
# relaunched within the same run: that worker appends to the existing ledger
# and continues its event_seq.
new_comprehensive_attempt_manifest_writer <- function(
  path,
  results_file = NULL,
  checkout_root = NULL,
  resume = FALSE
) {
  if (length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("attempt manifest path must be one nonempty path.", call. = FALSE)
  }
  parent <- dirname(path)
  if (!dir.exists(parent)) {
    stop("attempt manifest parent directory must already exist: ", parent, call. = FALSE)
  }
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (!is.null(results_file) && length(results_file) == 1L && !is.na(results_file) && nzchar(results_file)) {
    result_path <- normalizePath(results_file, winslash = "/", mustWork = FALSE)
    if (identical(path, result_path)) {
      stop("attempt manifest must be separate from the comprehensive results CSV.", call. = FALSE)
    }
  }
  if (!is.null(checkout_root)) {
    if (length(checkout_root) != 1L || is.na(checkout_root) || !dir.exists(checkout_root)) {
      stop("checkout_root must be one existing directory path.", call. = FALSE)
    }
    root <- normalizePath(checkout_root, winslash = "/", mustWork = TRUE)
    root_prefix <- if (endsWith(root, "/")) root else paste0(root, "/")
    if (identical(path, root) || startsWith(path, root_prefix)) {
      stop("attempt manifest must be written outside the checkout.", call. = FALSE)
    }
  }
  header <- data.frame(
    event_seq = integer(), event_type = character(), id = character(), rep = integer(),
    beta_T = numeric(), dataset = character(), response_type = character(), design = character(),
    model_formula = character(), inference_class = character(), function_run = character(), status = character(),
    skip_reason = character(), error_message = character(), event_epoch = numeric(),
    stringsAsFactors = FALSE
  )
  if (dir.exists(path)) {
    stop("refusing to overwrite an existing attempt manifest: ", path, call. = FALSE)
  }
  if (file.exists(path)) {
    if (!isTRUE(resume)) {
      stop("refusing to overwrite an existing attempt manifest: ", path, call. = FALSE)
    }
    existing <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = "")
    if (!identical(names(existing), names(header))) {
      stop("cannot resume an attempt manifest with a different header: ", path, call. = FALSE)
    }
    seq_values <- suppressWarnings(as.integer(existing$event_seq))
    if (anyNA(seq_values) || anyDuplicated(seq_values) || (length(seq_values) && any(seq_values != seq_along(seq_values)))) {
      stop("cannot resume an attempt manifest whose event_seq is not 1..n: ", path, call. = FALSE)
    }
    event_seq <- length(seq_values)
  } else {
    utils::write.table(header, file = path, sep = ",", row.names = FALSE, col.names = TRUE, na = "", qmethod = "double")
    event_seq <- 0L
  }
  function(event_type, key = list(), status = NA_character_, skip_reason = NA_character_, error_message = NA_character_) {
    event_types <- c(
      "started", "terminal", "skipped_completed", "skipped_slow",
      "skipped_confirmed_timeout", "setup_skipped", "setup_failure"
    )
    if (length(event_type) != 1L || is.na(event_type) || !event_type %in% event_types) {
      stop("unknown comprehensive attempt event type.", call. = FALSE)
    }
    if (!is.list(key) || (length(key) && (is.null(names(key)) || any(!nzchar(names(key))))) ||
        any(!names(key) %in% c("id", "rep", "beta_T", "dataset", "response_type", "design", "model_formula", "inference_class", "function_run"))) {
      stop("attempt manifest key must be a named list of supported key fields.", call. = FALSE)
    }
    key_fields <- c("id", "rep", "beta_T", "dataset", "response_type", "design", "model_formula", "inference_class", "function_run")
    values <- lapply(key_fields, function(name) if (name %in% names(key)) key[[name]] else NA)
    names(values) <- key_fields
    event_seq <<- event_seq + 1L
    row <- data.frame(
      event_seq = event_seq,
      event_type = as.character(event_type),
      id = as.character(values$id),
      rep = suppressWarnings(as.integer(values$rep)),
      beta_T = suppressWarnings(as.numeric(values$beta_T)),
      dataset = as.character(values$dataset),
      response_type = as.character(values$response_type),
      design = as.character(values$design),
      model_formula = as.character(values$model_formula),
      inference_class = as.character(values$inference_class),
      function_run = as.character(values$function_run),
      status = as.character(status),
      skip_reason = as.character(skip_reason),
      error_message = as.character(error_message),
      event_epoch = as.numeric(Sys.time()),
      stringsAsFactors = FALSE
    )
    utils::write.table(
      row,
      file = path,
      sep = ",",
      row.names = FALSE,
      col.names = FALSE,
      append = TRUE,
      na = "",
      qmethod = "double"
    )
    invisible(row)
  }
}

should_skip_comprehensive_prune_check <- function(
  skip = Sys.getenv("EDI_COMPREHENSIVE_SKIP_PRUNE_CHECK", unset = ""),
  output_dir = Sys.getenv("EDI_COMPREHENSIVE_RESULTS_DIR", unset = ""),
  checkout_root
) {
  if (length(skip) != 1L || is.na(skip)) {
    stop("EDI_COMPREHENSIVE_SKIP_PRUNE_CHECK must be unset or exactly '1'.", call. = FALSE)
  }
  if (!nzchar(skip)) return(FALSE)
  if (!identical(skip, "1")) {
    stop("EDI_COMPREHENSIVE_SKIP_PRUNE_CHECK must be unset or exactly '1'.", call. = FALSE)
  }
  if (length(output_dir) != 1L || is.na(output_dir) || !nzchar(output_dir)) {
    stop("skipping the prune check requires EDI_COMPREHENSIVE_RESULTS_DIR outside the checkout.", call. = FALSE)
  }
  if (!dir.exists(output_dir)) {
    stop("EDI_COMPREHENSIVE_RESULTS_DIR is not an existing directory: ", output_dir, call. = FALSE)
  }
  if (length(checkout_root) != 1L || is.na(checkout_root) || !nzchar(checkout_root) || !dir.exists(checkout_root)) {
    stop("checkout_root must be one existing directory path.", call. = FALSE)
  }

  output_path <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
  checkout_path <- normalizePath(checkout_root, winslash = "/", mustWork = TRUE)
  checkout_prefix <- if (endsWith(checkout_path, "/")) checkout_path else paste0(checkout_path, "/")
  if (identical(output_path, checkout_path) || startsWith(output_path, checkout_prefix)) {
    stop("skipping the prune check requires EDI_COMPREHENSIVE_RESULTS_DIR outside the checkout.", call. = FALSE)
  }
  TRUE
}

run_comprehensive_startup_prune_check <- function(
  pruner_path,
  checkout_root,
  skip = Sys.getenv("EDI_COMPREHENSIVE_SKIP_PRUNE_CHECK", unset = ""),
  output_dir = Sys.getenv("EDI_COMPREHENSIVE_RESULTS_DIR", unset = ""),
  system2_fn = system2,
  message_fn = message
) {
  if (should_skip_comprehensive_prune_check(skip, output_dir, checkout_root)) {
    message_fn("[prune-check] skipped by EDI_COMPREHENSIVE_SKIP_PRUNE_CHECK=1; results are isolated outside the checkout")
    return(invisible(NULL))
  }

  tryCatch({
    output <- system2_fn("Rscript", c(shQuote(pruner_path)), stdout = TRUE, stderr = TRUE)
    summary <- grep("stale row\\(s\\)", output, value = TRUE)
    if (length(summary)) {
      message_fn("[prune-check] ", summary[1], " (run `Rscript package_tests/prune_stale_result_rows.R --apply` to clean up)")
    }
  }, error = function(e) invisible(NULL))
  invisible(NULL)
}
