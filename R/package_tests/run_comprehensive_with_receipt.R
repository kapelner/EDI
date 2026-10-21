#!/usr/bin/env Rscript

# Run an arbitrary command under the external receipt contract. This wrapper
# is intentionally separate from comprehensive_tests.R and its schema-v2
# sidecar; it must be invoked explicitly by the owner of an authorized run.
#
# Usage:
#   Rscript R/package_tests/run_comprehensive_with_receipt.R \
#     --receipt PATH --stdout PATH --stderr PATH [--wd DIR] [--env NAME=VALUE]... \
#     --command EXECUTABLE [ARG ...]

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("could not locate receipt wrapper script", call. = FALSE)
script_path <- normalizePath(sub("^--file=", "", script_arg), winslash = "/", mustWork = TRUE)
helper_dir <- dirname(script_path)
source(file.path(helper_dir, "comprehensive_run_provenance.R"), local = TRUE)
source(file.path(helper_dir, "comprehensive_external_process_receipt.R"), local = TRUE)

args <- commandArgs(trailingOnly = TRUE)
options <- list(receipt = NULL, stdout = NULL, stderr = NULL, wd = NULL, env = character())
i <- 1L
command_marker <- NA_integer_
seen_options <- character()
while (i <= length(args)) {
	if (identical(args[[i]], "--command")) {
		command_marker <- i
		break
	}
	flag <- args[[i]]
	if (flag %in% c("--receipt", "--stdout", "--stderr", "--wd", "--env")) {
		if (!identical(flag, "--env") && flag %in% seen_options) {
			stop("duplicate option: ", flag, call. = FALSE)
		}
		seen_options <- c(seen_options, flag)
		if (i == length(args)) stop("missing value after ", flag, call. = FALSE)
		value <- args[[i + 1L]]
		if (identical(flag, "--env")) {
			options$env <- c(options$env, value)
		} else {
			name <- substring(flag, 3L)
			options[[name]] <- value
		}
		i <- i + 2L
	} else {
		stop("unknown receipt-wrapper option: ", flag, call. = FALSE)
	}
}
if (is.na(command_marker) || command_marker >= length(args)) {
	stop("usage requires --receipt, --stdout, --stderr, then --command EXECUTABLE [ARG ...]", call. = FALSE)
}
command <- args[[command_marker + 1L]]
child_args <- if (command_marker + 1L < length(args)) args[seq.int(command_marker + 2L, length(args))] else character()
required_paths <- c("receipt", "stdout", "stderr")
if (any(vapply(options[required_paths], is.null, logical(1L)))) {
	stop("--receipt, --stdout, and --stderr are required", call. = FALSE)
}
if (length(options$env) && anyDuplicated(sub("=.*$", "", options$env))) {
	stop("--env may specify each environment variable only once", call. = FALSE)
}
env <- if (length(options$env)) options$env else NULL

receipt <- run_comprehensive_external_process_with_receipt(
	command = command,
	args = child_args,
	receipt_path = options$receipt,
	stdout_path = options$stdout,
	stderr_path = options$stderr,
	wd = options$wd,
	env = env
)
cat("external process receipt:", normalizePath(options$receipt, winslash = "/", mustWork = TRUE), "\n")
quit(save = "no", status = receipt$exit_status, runLast = FALSE)
