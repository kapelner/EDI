# External-process receipt for comprehensive runs. This is deliberately
# separate from the runner's schema-v2 package/runtime sidecar: the parent
# process owns command identity, PID, terminal status, and captured logs.

write_comprehensive_external_receipt_atomic <- function(path, value) {
	parent <- dirname(path)
	if (!dir.exists(parent)) stop("receipt parent directory must exist", call. = FALSE)
	tmp <- tempfile(paste0(basename(path), ".tmp-"), tmpdir = parent)
	on.exit(unlink(tmp), add = TRUE)
	saveRDS(value, tmp)
	if (!file.rename(tmp, path)) stop("could not atomically write external-process receipt", call. = FALSE)
	invisible(path)
}

run_comprehensive_external_process_with_receipt <- function(
	command,
	args = character(),
	receipt_path,
	stdout_path,
	stderr_path,
	wd = NULL,
	env = NULL,
	sha256_file = comprehensive_sha256_file
) {
	valid_path <- function(x, name) {
		if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
			stop(name, " must be one nonempty path", call. = FALSE)
		}
		normalizePath(x, winslash = "/", mustWork = FALSE)
	}
	if (!is.character(command) || length(command) != 1L || is.na(command) || !nzchar(command)) {
		stop("command must be one nonempty executable", call. = FALSE)
	}
	if (!is.character(args) || anyNA(args)) stop("args must be a character vector without NA", call. = FALSE)
	if (!is.null(wd) && (!is.character(wd) || length(wd) != 1L || is.na(wd) || !dir.exists(wd))) {
		stop("wd must be NULL or one existing directory", call. = FALSE)
	}
	if (!is.null(env) && (!is.character(env) || anyNA(env) || any(!grepl("^[^=]+=.*$", env)))) {
		stop("env must be NULL or a character vector of NAME=value entries", call. = FALSE)
	}
	# Keep the receipt's stable NAME=value representation, but processx expects
	# its `env` argument as a named character vector.
	# The leading "current" makes processx extend the parent environment rather
	# than replace it; without it the child lost HOME/R_LIBS_USER and could not
	# load the installed EDI (found 2026-10-23 while smoke-testing the G4-C runners).
	env_for_child <- if (is.null(env)) NULL else {
		separator <- regexpr("=", env, fixed = TRUE)
		c("current", stats::setNames(substring(env, separator + 1L), substring(env, 1L, separator - 1L)))
	}
	if (!is.function(sha256_file)) stop("sha256_file must be a function", call. = FALSE)

	receipt_path <- valid_path(receipt_path, "receipt_path")
	stdout_path <- valid_path(stdout_path, "stdout_path")
	stderr_path <- valid_path(stderr_path, "stderr_path")
	pending_path <- paste0(receipt_path, ".running")
	all_paths <- c(receipt_path, pending_path, stdout_path, stderr_path)
	if (anyDuplicated(all_paths)) stop("receipt and log paths must be distinct", call. = FALSE)
	if (any(file.exists(all_paths) | dir.exists(all_paths))) {
		stop("refusing to overwrite an existing receipt or log path", call. = FALSE)
	}
	if (!all(dir.exists(dirname(all_paths)))) stop("all receipt/log parent directories must exist", call. = FALSE)
	if (!requireNamespace("processx", quietly = TRUE)) stop("processx is required to capture the child PID and exit status", call. = FALSE)

	started_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
	child <- processx::process$new(
		command = command,
		args = args,
		wd = wd,
		env = env_for_child,
		stdout = stdout_path,
		stderr = stderr_path,
		cleanup = TRUE,
		supervise = TRUE
	)
	pid <- as.numeric(child$get_pid())
	completed <- FALSE
	on.exit({
		if (!completed && child$is_alive()) {
			child$kill()
			child$wait()
		}
	}, add = TRUE)
	pending <- list(
		schema = "edi_external_process_receipt",
		schema_version = 1L,
		state = "running",
		command = command,
		args = args,
		env_overrides = env,
		env_inherits_parent = TRUE,  # "current" is always passed to processx (2026-10-23)
		wd = if (is.null(wd)) NULL else normalizePath(wd, winslash = "/", mustWork = TRUE),
		supervisor_pid = as.numeric(Sys.getpid()),
		pid = pid,
		started_at_utc = started_at,
		stdout_path = stdout_path,
		stderr_path = stderr_path
		)
	write_comprehensive_external_receipt_atomic(pending_path, pending)

	child$wait()
	exit_status <- child$get_exit_status()
	completed_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
	if (is.null(exit_status) || length(exit_status) != 1L || is.na(exit_status)) {
		stop("child terminated without a terminal exit status; running receipt retained", call. = FALSE)
	}
	file_identity <- function(path) {
		if (!file.exists(path) || dir.exists(path)) stop("child did not produce captured output file: ", path, call. = FALSE)
		hash <- tolower(sha256_file(path))
		if (!grepl("^[[:xdigit:]]{64}$", hash)) stop("could not capture SHA-256 for child output: ", path, call. = FALSE)
		list(path = path, bytes = unname(file.info(path)$size), sha256 = hash)
	}
	pending$state <- "completed"
	receipt <- c(pending, list(
		completed_at_utc = completed_at,
		exit_status = as.integer(exit_status),
		stdout = file_identity(stdout_path),
		stderr = file_identity(stderr_path)
	))
	write_comprehensive_external_receipt_atomic(receipt_path, receipt)
	if (unlink(pending_path) != 0L) stop("completed receipt written but running marker could not be removed", call. = FALSE)
	completed <- TRUE
	invisible(receipt)
}
