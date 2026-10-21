todo33_validate_search_run_identity <- function(identity, context = "TODO-33 run identity") {
	required <- c("package_provenance", "trigger_runner_path", "trigger_runner_sha256")
	if (!is.list(identity) || any(!required %in% names(identity))) {
		stop(context, " is missing required package or runner provenance", call. = FALSE)
	}
	package <- identity$package_provenance
	package_fields <- c(
		"r_version", "edi_package_version", "edi_package_path", "edi_namespace_path",
		"edi_package_payload_path", "edi_package_payload_sha256", "edi_dll_path",
		"edi_dll_sha256", "checkout_path", "checkout_head", "checkout_status_porcelain",
		"checkout_diff_sha256"
	)
	if (!is.list(package) || any(!package_fields %in% names(package))) {
		stop(context, " is missing package, source, DLL, or checkout provenance", call. = FALSE)
	}
	sha_fields <- c("edi_package_payload_sha256", "edi_dll_sha256", "checkout_diff_sha256")
	for (field in sha_fields) {
		value <- package[[field]]
		if (!is.character(value) || length(value) != 1L || is.na(value) ||
		    !grepl("^[[:xdigit:]]{64}$", value)) {
			stop(context, " has an invalid ", field, call. = FALSE)
		}
	}
	if (!is.character(package$checkout_head) || length(package$checkout_head) != 1L ||
	    is.na(package$checkout_head) || !grepl("^[[:xdigit:]]{40}([[:xdigit:]]{24})?$", package$checkout_head)) {
		stop(context, " has an invalid checkout_head", call. = FALSE)
	}
	if (!is.character(identity$trigger_runner_path) || length(identity$trigger_runner_path) != 1L ||
	    is.na(identity$trigger_runner_path) || !nzchar(identity$trigger_runner_path) ||
	    !is.character(identity$trigger_runner_sha256) || length(identity$trigger_runner_sha256) != 1L ||
	    is.na(identity$trigger_runner_sha256) || !grepl("^[[:xdigit:]]{64}$", identity$trigger_runner_sha256)) {
		stop(context, " has invalid TODO-33 runner provenance", call. = FALSE)
	}
	invisible(identity)
}

todo33_capture_search_run_identity <- function(
	repo_root,
	runner_path,
	provenance_anchor_path,
	capture_provenance = capture_comprehensive_run_provenance,
	sha256_file = comprehensive_sha256_file
) {
	if (!is.function(capture_provenance) || !is.function(sha256_file)) {
		stop("TODO-33 provenance capture requires provenance and SHA-256 helpers", call. = FALSE)
	}
	if (length(runner_path) != 1L || is.na(runner_path) || !file.exists(runner_path) || dir.exists(runner_path)) {
		stop("TODO-33 runner path must identify one existing file", call. = FALSE)
	}
	package_provenance <- capture_provenance(repo_root, provenance_anchor_path)
	runner_path <- normalizePath(runner_path, winslash = "/", mustWork = TRUE)
	runner_sha256 <- tolower(sha256_file(runner_path))
	identity <- list(
		package_provenance = package_provenance,
		trigger_runner_path = runner_path,
		trigger_runner_sha256 = runner_sha256
	)
	todo33_validate_search_run_identity(identity)
	identity
}

todo33_make_search_run_sidecar <- function(
	provenance_before,
	provenance_after,
	run_spec,
	input_data,
	results,
	trigger_replay_paths = character()
) {
	todo33_validate_search_run_identity(provenance_before, "TODO-33 before-run provenance")
	todo33_validate_search_run_identity(provenance_after, "TODO-33 after-run provenance")
	if (!is.list(run_spec) || !is.data.frame(input_data) || !is.data.frame(results) ||
	    !"seed" %in% names(results) || !is.logical(results$trigger) ||
	    length(results$trigger) != nrow(results)) {
		stop("TODO-33 sidecar requires run settings, input data, and per-seed trigger results", call. = FALSE)
	}
	if (anyNA(results$seed) || anyDuplicated(results$seed) || anyNA(results$trigger)) {
		stop("TODO-33 per-seed results require unique seeds and non-missing trigger outcomes", call. = FALSE)
	}
	if (!is.character(trigger_replay_paths) || anyNA(trigger_replay_paths) || any(!nzchar(trigger_replay_paths))) {
		stop("TODO-33 trigger replay paths must be character paths", call. = FALSE)
	}
	if (any(results$trigger) && length(trigger_replay_paths) == 0L) {
		stop("TODO-33 positive trigger results require at least one replay bundle", call. = FALSE)
	}
	if (length(trigger_replay_paths) > 0L &&
	    any(!file.exists(trigger_replay_paths) | dir.exists(trigger_replay_paths))) {
		stop("TODO-33 replay paths must identify existing replay bundle files", call. = FALSE)
	}
	list(
		schema_version = 1L,
		completed_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC"),
		provenance_before = provenance_before,
		provenance_after = provenance_after,
		run_spec = run_spec,
		input_data = input_data,
		results = results,
		trigger_count = sum(results$trigger),
		trigger_replay_paths = trigger_replay_paths
	)
}

todo33_write_search_run_sidecar <- function(path, sidecar) {
	if (length(path) != 1L || is.na(path) || !nzchar(path) || dir.exists(path)) {
		stop("TODO-33 sidecar path must be one nonempty file path", call. = FALSE)
	}
	if (file.exists(path)) stop("refusing to overwrite an existing TODO-33 run sidecar", call. = FALSE)
	if (!is.list(sidecar) || !identical(sidecar$schema_version, 1L) ||
	    !is.data.frame(sidecar$results) || !is.data.frame(sidecar$input_data)) {
		stop("TODO-33 sidecar is incomplete", call. = FALSE)
	}
	parent <- dirname(path)
	if (!dir.exists(parent)) stop("TODO-33 sidecar directory does not exist", call. = FALSE)
	temporary_path <- tempfile(paste0(basename(path), ".tmp-"), tmpdir = parent)
	on.exit(unlink(temporary_path), add = TRUE)
	saveRDS(sidecar, temporary_path)
	if (!file.rename(temporary_path, path)) {
		stop("could not atomically write TODO-33 run sidecar", call. = FALSE)
	}
	invisible(path)
}

todo33_search_run_sidecar_path <- function(dataset_name, captured_at = Sys.time(), pid = Sys.getpid(), output_dir = "/tmp") {
	if (!is.character(dataset_name) || length(dataset_name) != 1L || is.na(dataset_name) ||
	    !grepl("^[A-Za-z0-9._-]+$", dataset_name)) {
		stop("TODO-33 dataset name must be a simple filename component", call. = FALSE)
	}
	if (length(captured_at) != 1L || is.na(captured_at) || !inherits(captured_at, "POSIXt")) {
		stop("TODO-33 capture time must be one non-missing POSIX time", call. = FALSE)
	}
	if (length(pid) != 1L || is.na(pid) || !is.finite(pid) || pid < 1) {
		stop("TODO-33 process ID must be one positive finite number", call. = FALSE)
	}
	if (!is.character(output_dir) || length(output_dir) != 1L || is.na(output_dir) || !dir.exists(output_dir)) {
		stop("TODO-33 sidecar output directory must already exist", call. = FALSE)
	}
	stamp <- gsub("[^0-9T]", "", format(captured_at, "%Y%m%dT%H%M%OS6", tz = "UTC"))
	file.path(normalizePath(output_dir, winslash = "/", mustWork = TRUE),
		paste0("edi-todo33-", dataset_name, "-", stamp, "-pid", as.integer(pid), ".run-provenance.rds"))
}
