comprehensive_sha256_file <- function(path){
	if (length(path) != 1L || is.na(path) || !file.exists(path) || dir.exists(path)) {
		stop("cannot hash a missing comprehensive-run provenance file", call. = FALSE)
	}
	commands = list(
		list(command = Sys.which("sha256sum"), args = character()),
		list(command = Sys.which("shasum"), args = c("-a", "256")),
		list(command = Sys.which("openssl"), args = c("dgst", "-sha256")),
		list(command = Sys.which("certutil"), args = c("-hashfile", shQuote(path), "SHA256"))
	)
	for (entry in commands) {
		if (!nzchar(entry$command)) next
		args = c(entry$args, if (!identical(entry$command, Sys.which("certutil"))) shQuote(path))
		output = tryCatch(
			suppressWarnings(system2(entry$command, args = args, stdout = TRUE, stderr = FALSE)),
			error = function(e) character()
		)
		status = attr(output, "status")
		if (!length(output) || (!is.null(status) && !identical(as.integer(status), 0L))) next
		hashes = tolower(unlist(regmatches(output, gregexpr("[[:xdigit:]]{64}", output, perl = TRUE)), use.names = FALSE))
		if (length(hashes)) return(hashes[[1L]])
	}
	stop("no available SHA-256 utility could hash comprehensive-run provenance", call. = FALSE)
}

comprehensive_git_output <- function(repo_root, args){
	output = suppressWarnings(system2(
		"git",
		args = c("-C", shQuote(repo_root), args),
		stdout = TRUE,
		stderr = TRUE
	))
	status = attr(output, "status")
	if (!is.null(status) && !identical(as.integer(status), 0L)) {
		stop("could not capture comprehensive-run checkout provenance: ", paste(output, collapse = "\n"), call. = FALSE)
	}
	output
}

comprehensive_package_payload_identity <- function(package_root){
	if (length(package_root) != 1L || is.na(package_root) || !dir.exists(package_root)) {
		stop("package_root must be one existing package directory", call. = FALSE)
	}
	package_root = normalizePath(package_root, winslash = "/", mustWork = TRUE)
	required = file.path(package_root, c("DESCRIPTION", "NAMESPACE", "R", "src"))
	if (any(!file.exists(required))) {
		stop("package payload is missing DESCRIPTION, NAMESPACE, R, or src", call. = FALSE)
	}
	if (any(!dir.exists(required[3:4])) || any(dir.exists(required[1:2]))) {
		stop("package payload has invalid DESCRIPTION, NAMESPACE, R, or src paths", call. = FALSE)
	}

	# Fingerprint files that can define package behavior or its source/runtime
	# payload. Keep documentation and tests outside this set so unrelated edits
	# do not invalidate an otherwise identical run. The loaded native library is
	# captured separately by edi_dll_path and edi_dll_sha256.
	payload_dirs = file.path(package_root, c("R", "src", "data", "inst", "exec", "po", "Meta"))
	payload_dirs = payload_dirs[dir.exists(payload_dirs)]
	optional_root_files = c(
		"configure", "configure.win", "cleanup", "cleanup.win",
		"LICENSE", "LICENSE.md", "LICENSE.txt"
	)
	root_files = file.path(package_root, c("DESCRIPTION", "NAMESPACE", optional_root_files))
	root_files = root_files[file.exists(root_files) & !dir.exists(root_files)]
	listed_files = tryCatch(
		unlist(lapply(payload_dirs, function(path){
			withCallingHandlers(
				list.files(path, all.files = TRUE, recursive = TRUE, full.names = TRUE, include.dirs = FALSE),
				warning = function(w) stop(conditionMessage(w), call. = FALSE)
			)
		}), use.names = FALSE),
		error = function(e) stop("could not enumerate package payload: ", conditionMessage(e), call. = FALSE)
	)
	files = sort(unique(c(root_files, listed_files[!dir.exists(listed_files)])))
	if (!length(files) || any(!file.exists(files)) || any(dir.exists(files))) {
		stop("package payload contains missing or non-file entries", call. = FALSE)
	}
	normalized_files = vapply(files, normalizePath, character(1L), winslash = "/", mustWork = TRUE)
	root_prefix = paste0(package_root, "/")
	if (any(!startsWith(normalized_files, root_prefix))) {
		stop("package payload contains a path outside package_root", call. = FALSE)
	}
	relative_paths = substring(normalized_files, nchar(root_prefix) + 1L)
	compiled_artifact = grepl("\\.(o|so|dll|dylib|a|la|lo|obj|lib)$", relative_paths, ignore.case = TRUE)
	normalized_files = normalized_files[!compiled_artifact]
	relative_paths = relative_paths[!compiled_artifact]
	if (!length(normalized_files)) stop("package payload has no source/runtime files", call. = FALSE)
	file_hashes = vapply(normalized_files, comprehensive_sha256_file, character(1L))
	manifest = serialize(list(paths = relative_paths, sha256 = tolower(unname(file_hashes))), NULL, version = 2L)
	manifest_path = tempfile("edi-comprehensive-package-payload-")
	on.exit(unlink(manifest_path), add = TRUE)
	writeBin(manifest, manifest_path)
	list(path = package_root, sha256 = comprehensive_sha256_file(manifest_path))
}

capture_comprehensive_run_provenance <- function(repo_root, runner_path){
	if (length(repo_root) != 1L || is.na(repo_root) || !dir.exists(repo_root)) {
		stop("repo_root must be one existing directory", call. = FALSE)
	}
	if (length(runner_path) != 1L || is.na(runner_path) || !file.exists(runner_path) || dir.exists(runner_path)) {
		stop("runner_path must be one existing file", call. = FALSE)
	}
	repo_root = normalizePath(repo_root, winslash = "/", mustWork = TRUE)
	namespace = asNamespace("EDI")
	namespace_path = normalizePath(getNamespaceInfo(namespace, "path"), winslash = "/", mustWork = TRUE)
	package_path = normalizePath(find.package("EDI"), winslash = "/", mustWork = TRUE)
	package_version = as.character(getNamespaceInfo(namespace, "spec")[["version"]])
	if (length(package_version) != 1L || is.na(package_version) || !nzchar(package_version)) {
		stop("could not identify the loaded EDI package version", call. = FALSE)
	}
	dll = getLoadedDLLs()[["EDI"]]
	if (is.null(dll) || is.null(dll[["path"]]) || !nzchar(dll[["path"]])) {
		stop("could not identify the loaded EDI native library", call. = FALSE)
	}
	dll_path = normalizePath(dll[["path"]], winslash = "/", mustWork = TRUE)
	git_head = comprehensive_git_output(repo_root, c("rev-parse", "HEAD"))
	git_head = trimws(git_head[[1L]])
	if (!grepl("^[[:xdigit:]]{40}([[:xdigit:]]{24})?$", git_head)) {
		stop("could not identify the comprehensive-run checkout HEAD", call. = FALSE)
	}
	runner_path = normalizePath(runner_path, winslash = "/", mustWork = TRUE)
	runner_dir = dirname(runner_path)
	package_root = file.path(dirname(runner_dir), "EDI")
	package_payload = comprehensive_package_payload_identity(package_root)
	git_status = comprehensive_git_output(repo_root, c("status", "--porcelain=v1", "--untracked-files=all"))
	diff_path = tempfile("edi-comprehensive-git-diff-")
	diff_error_path = tempfile("edi-comprehensive-git-diff-error-")
	on.exit(unlink(c(diff_path, diff_error_path)), add = TRUE)
	diff_status = suppressWarnings(system2(
		"git",
		args = c("-C", shQuote(repo_root), "diff", "--binary", "HEAD"),
		stdout = diff_path,
		stderr = diff_error_path
	))
	if (!identical(as.integer(diff_status), 0L)) {
		diff_error = if (file.exists(diff_error_path)) paste(readLines(diff_error_path, warn = FALSE), collapse = "\n") else ""
		stop("could not hash the comprehensive-run checkout diff: ", diff_error, call. = FALSE)
	}
	beta_filter_helper_path = normalizePath(file.path(runner_dir, "comprehensive_beta_filter.R"), winslash = "/", mustWork = TRUE)
	helper_path = normalizePath(file.path(runner_dir, "comprehensive_run_provenance.R"), winslash = "/", mustWork = TRUE)
	rng_seed = if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
		get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
	} else {
		NULL
	}
	list(
		captured_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC"),
		r_version = R.version.string,
		rng_kind = RNGkind(),
		rng_seed = rng_seed,
		edi_package_version = package_version,
		edi_package_path = package_path,
		edi_namespace_path = namespace_path,
		edi_package_payload_path = package_payload$path,
		edi_package_payload_sha256 = package_payload$sha256,
		edi_dll_path = dll_path,
		edi_dll_sha256 = comprehensive_sha256_file(dll_path),
		checkout_path = repo_root,
		checkout_head = git_head,
		checkout_status_porcelain = git_status,
		checkout_diff_sha256 = comprehensive_sha256_file(diff_path),
		runner_path = runner_path,
		runner_sha256 = comprehensive_sha256_file(runner_path),
		beta_filter_helper_path = beta_filter_helper_path,
		beta_filter_helper_sha256 = comprehensive_sha256_file(beta_filter_helper_path),
		provenance_helper_path = helper_path,
		provenance_helper_sha256 = comprehensive_sha256_file(helper_path)
	)
}

comprehensive_run_provenance_sidecar_path <- function(results_file, started_at, pid){
	if (length(results_file) != 1L || is.na(results_file) || !nzchar(results_file)) {
		stop("results_file must be one nonempty path", call. = FALSE)
	}
	if (length(started_at) != 1L || is.na(started_at) || !inherits(started_at, "POSIXt")) {
		stop("started_at must be one non-missing POSIX time", call. = FALSE)
	}
	if (length(pid) != 1L || is.na(pid) || !is.finite(pid)) {
		stop("pid must be one finite number", call. = FALSE)
	}
	paste0(
		results_file,
		".provenance-",
		format(started_at, "%Y%m%dT%H%M%OS6", tz = "UTC"),
		"-pid", as.integer(pid),
		".rds"
	)
}

comprehensive_result_file_identity <- function(path, include_sha256 = TRUE){
	if (length(path) != 1L || is.na(path) || !nzchar(path)) {
		stop("results path must be one nonempty path", call. = FALSE)
	}
	if (dir.exists(path)) stop("results path is a directory", call. = FALSE)
	if (!file.exists(path)) {
		return(list(exists = FALSE, bytes = 0, sha256 = NA_character_))
	}
	info = file.info(path)
	list(
		exists = TRUE,
		bytes = unname(as.numeric(info$size)),
		sha256 = if (isTRUE(include_sha256)) comprehensive_sha256_file(path) else NA_character_
	)
}

write_comprehensive_run_provenance <- function(path, provenance){
	if (length(path) != 1L || is.na(path) || !nzchar(path)) {
		stop("provenance sidecar path must be one nonempty path", call. = FALSE)
	}
	if (file.exists(path)) stop("refusing to overwrite an existing provenance sidecar", call. = FALSE)
	parent = dirname(path)
	if (!dir.exists(parent)) stop("provenance sidecar directory does not exist", call. = FALSE)
	temporary_path = tempfile(paste0(basename(path), ".tmp-"), tmpdir = parent)
	on.exit(unlink(temporary_path), add = TRUE)
	saveRDS(provenance, temporary_path)
	if (!file.rename(temporary_path, path)) {
		stop("could not atomically write comprehensive-run provenance sidecar", call. = FALSE)
	}
	invisible(path)
}

comprehensive_result_manifest_keys <- function(data, columns){
	if (!is.data.frame(data) || !length(columns) || any(!columns %in% names(data))) {
		stop("manifest data must contain every key column", call. = FALSE)
	}
	if (!nrow(data)) return(character())
	encode <- function(x){
		value = as.character(x)
		missing = is.na(x)
		encoded = paste0("V", nchar(value, type = "bytes"), ":", value)
		encoded[missing] = "N;"
		encoded
	}
	parts = lapply(columns, function(column) encode(data[[column]]))
	do.call(paste0, parts)
}

validate_comprehensive_result_artifact <- function(
	results_file,
	sidecar_path,
	expected_manifest,
	key_columns,
	method_column = "function_run",
	forbidden_methods = character(),
	expected_run_provenance = NULL,
	require_terminal_result_fields = FALSE
){
	if (length(results_file) != 1L || is.na(results_file) || !file.exists(results_file) || dir.exists(results_file)) {
		stop("results_file must be one existing CSV file", call. = FALSE)
	}
	if (length(sidecar_path) != 1L || is.na(sidecar_path) || !file.exists(sidecar_path) || dir.exists(sidecar_path)) {
		stop("a matching comprehensive-run provenance sidecar is required", call. = FALSE)
	}
	if (!is.data.frame(expected_manifest) || !nrow(expected_manifest)) {
		stop("expected_manifest must be a nonempty data.frame", call. = FALSE)
	}
	if (!is.character(key_columns) || !length(key_columns) || anyNA(key_columns) || any(!nzchar(key_columns)) ||
			anyDuplicated(key_columns) || !is.character(method_column) || length(method_column) != 1L ||
			is.na(method_column) || !nzchar(method_column) || method_column %in% key_columns) {
		stop("key_columns and method_column must define distinct, nonempty fields", call. = FALSE)
	}
	manifest_columns = c(key_columns, method_column)
	missing_manifest_columns = setdiff(manifest_columns, names(expected_manifest))
	if (length(missing_manifest_columns)) {
		stop("expected_manifest is missing field(s): ", paste(missing_manifest_columns, collapse = ", "), call. = FALSE)
	}
	if (!is.character(forbidden_methods) || anyNA(forbidden_methods)) {
		stop("forbidden_methods must be a character vector", call. = FALSE)
	}
	if (!is.null(expected_run_provenance) &&
			(!is.list(expected_run_provenance) || is.null(names(expected_run_provenance)) ||
				anyNA(names(expected_run_provenance)) || any(!nzchar(names(expected_run_provenance))) ||
				anyDuplicated(names(expected_run_provenance)))) {
		stop("expected_run_provenance must be a uniquely named list", call. = FALSE)
	}
	if (!is.logical(require_terminal_result_fields) || length(require_terminal_result_fields) != 1L ||
			is.na(require_terminal_result_fields)) {
		stop("require_terminal_result_fields must be one non-missing logical value", call. = FALSE)
	}

	provenance = tryCatch(readRDS(sidecar_path), error = function(e) {
		stop("could not read comprehensive-run provenance sidecar: ", conditionMessage(e), call. = FALSE)
	})
	if (!is.list(provenance) || !identical(as.integer(provenance$schema_version), 2L)) {
		stop("unsupported or missing comprehensive-run provenance schema", call. = FALSE)
	}
	actual_path = normalizePath(results_file, winslash = "/", mustWork = TRUE)
	recorded_path = provenance$results_file
	if (!is.character(recorded_path) || length(recorded_path) != 1L || is.na(recorded_path) ||
			!identical(normalizePath(recorded_path, winslash = "/", mustWork = FALSE), actual_path)) {
		stop("provenance sidecar results_file does not match the supplied CSV", call. = FALSE)
	}
	before_id = provenance$results_file_before
	after_id = provenance$results_file_after
	if (!is.list(before_id) || !is.list(after_id) || !identical(after_id$exists, TRUE) ||
			!is.numeric(after_id$bytes) || length(after_id$bytes) != 1L || !is.finite(after_id$bytes) ||
			!is.character(after_id$sha256) || length(after_id$sha256) != 1L ||
			!grepl("^[[:xdigit:]]{64}$", after_id$sha256)) {
		stop("provenance sidecar has no valid completed result-file identity", call. = FALSE)
	}
	actual_id = comprehensive_result_file_identity(actual_path, include_sha256 = TRUE)
	if (!identical(as.numeric(after_id$bytes), actual_id$bytes) ||
			!identical(tolower(after_id$sha256), tolower(actual_id$sha256))) {
		stop("results CSV size or SHA-256 does not match the provenance sidecar", call. = FALSE)
	}
	if (!is.character(provenance$started_at_utc) || length(provenance$started_at_utc) != 1L ||
			is.na(provenance$started_at_utc) || !nzchar(provenance$started_at_utc) ||
			!is.character(provenance$completed_at_utc) || length(provenance$completed_at_utc) != 1L ||
			is.na(provenance$completed_at_utc) || !nzchar(provenance$completed_at_utc) ||
			provenance$completed_at_utc < provenance$started_at_utc ||
			!is.character(provenance$command_args)) {
		stop("provenance sidecar is missing a valid run interval or command arguments", call. = FALSE)
	}

	identity_fields = c(
		"r_version", "edi_package_version", "edi_package_path", "edi_namespace_path",
		"edi_package_payload_path", "edi_package_payload_sha256",
		"edi_dll_path", "edi_dll_sha256", "checkout_path", "checkout_head",
		"checkout_diff_sha256", "runner_path", "runner_sha256",
		"beta_filter_helper_path", "beta_filter_helper_sha256", "provenance_helper_path",
		"provenance_helper_sha256"
	)
	stable_identity_fields = setdiff(identity_fields, "checkout_diff_sha256")
	if (!is.list(provenance$before) || !is.list(provenance$after) ||
			any(!identity_fields %in% names(provenance$before)) ||
			any(!identity_fields %in% names(provenance$after)) ||
			!is.character(provenance$before$checkout_status_porcelain) ||
			!is.character(provenance$after$checkout_status_porcelain) ||
			!identical(provenance$before[stable_identity_fields], provenance$after[stable_identity_fields])) {
		stop("comprehensive-run package, DLL, or checkout provenance changed or is incomplete", call. = FALSE)
	}
	text_fields = setdiff(identity_fields, "checkout_status_porcelain")
	for (field in text_fields) {
		value = provenance$after[[field]]
		if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(value)) {
			stop("comprehensive-run provenance has an invalid ", field, call. = FALSE)
		}
	}
	if (!grepl("^[[:xdigit:]]{40}([[:xdigit:]]{24})?$", provenance$after$checkout_head)) {
		stop("comprehensive-run provenance has an invalid checkout_head", call. = FALSE)
	}
	for (field in c("edi_package_payload_sha256", "edi_dll_sha256", "checkout_diff_sha256", "runner_sha256",
			"beta_filter_helper_sha256", "provenance_helper_sha256")) {
		if (!is.character(provenance$after[[field]]) || length(provenance$after[[field]]) != 1L ||
				!grepl("^[[:xdigit:]]{64}$", provenance$after[[field]])) {
			stop("comprehensive-run provenance has an invalid ", field, call. = FALSE)
		}
	}
	if (!is.character(provenance$before$checkout_diff_sha256) || length(provenance$before$checkout_diff_sha256) != 1L ||
			!grepl("^[[:xdigit:]]{64}$", provenance$before$checkout_diff_sha256)) {
		stop("comprehensive-run provenance has an invalid before checkout_diff_sha256", call. = FALSE)
	}
	if (!is.null(expected_run_provenance)) {
		for (field in names(expected_run_provenance)) {
			observed = if (field %in% names(provenance$after)) provenance$after[[field]] else provenance[[field]]
			if (is.null(observed) || !identical(observed, expected_run_provenance[[field]])) {
				stop("comprehensive-run provenance does not match expected field: ", field, call. = FALSE)
			}
		}
	}

	actual = tryCatch(utils::read.csv(actual_path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) {
		stop("could not read comprehensive results CSV: ", conditionMessage(e), call. = FALSE)
	})
	missing_actual_columns = setdiff(manifest_columns, names(actual))
	if (length(missing_actual_columns)) {
		stop("results CSV is missing manifest field(s): ", paste(missing_actual_columns, collapse = ", "), call. = FALSE)
	}
	if (length(forbidden_methods) && any(as.character(actual[[method_column]]) %in% forbidden_methods, na.rm = TRUE)) {
		stop("results CSV contains a forbidden method row", call. = FALSE)
	}
	expected_keys = comprehensive_result_manifest_keys(expected_manifest, manifest_columns)
	actual_keys = comprehensive_result_manifest_keys(actual, manifest_columns)
	if (anyDuplicated(expected_keys)) stop("expected_manifest contains duplicate key/method rows", call. = FALSE)
	if (anyDuplicated(actual_keys)) stop("results CSV contains duplicate key/method rows", call. = FALSE)
	missing_keys = setdiff(expected_keys, actual_keys)
	extra_keys = setdiff(actual_keys, expected_keys)
	if (length(missing_keys) || length(extra_keys)) {
		stop("results CSV key/method inventory mismatch (missing=", length(missing_keys),
				", extra=", length(extra_keys), ")", call. = FALSE)
	}
	if (isTRUE(require_terminal_result_fields)) {
		validate_comprehensive_terminal_result_fields(actual)
	}
	invisible(list(results_file = actual_path, rows = nrow(actual), provenance = provenance))
}

validate_comprehensive_terminal_result_fields <- function(rows) {
	if (!is.data.frame(rows)) stop("rows must be a data.frame", call. = FALSE)
	required <- c("status", "error_message", "skip_reason", "result_1", "result_2")
	missing <- setdiff(required, names(rows))
	if (length(missing)) {
		stop("results CSV is missing terminal result field(s): ", paste(missing, collapse = ", "), call. = FALSE)
	}
	status <- as.character(rows$status)
	if (anyNA(status) || any(!status %in% c("ok", "error"))) {
		stop("results CSV has a missing or unsupported terminal status", call. = FALSE)
	}
	error_message <- as.character(rows$error_message)
	error_message[is.na(error_message)] <- ""
	skip_reason <- as.character(rows$skip_reason)
	skip_reason[is.na(skip_reason)] <- ""
	error_rows <- status == "error"
	if (any(error_rows & !nzchar(trimws(error_message))) || any(error_rows & skip_reason != "error")) {
		stop("error result rows require an error_message and skip_reason='error'", call. = FALSE)
	}
	ok_rows <- status == "ok"
	no_message <- ok_rows & !nzchar(trimws(error_message))
	with_message <- ok_rows & nzchar(trimws(error_message))
	# Match the runner's terminal timeout marker, not arbitrary diagnostic text
	# that happens to mention a timeout. Cache classification uses the same
	# anchored message contract so unrelated status=ok rows remain reusable.
	timeout_message <- grepl(
		"^Skipped due to timeout after [0-9]+(?:\\.[0-9]+)? seconds(?: \\(outer safe_call guard\\))?$",
		error_message, ignore.case = TRUE, perl = TRUE
	)
	if (any(ok_rows & (skip_reason == "timeout" | timeout_message))) {
		stop("timeout result rows cannot have status='ok'", call. = FALSE)
	}
	if (any(no_message & skip_reason != "") ||
			any(with_message & (!nzchar(trimws(skip_reason)) | skip_reason == "error"))) {
		stop("ok result rows have inconsistent error_message/skip_reason fields", call. = FALSE)
	}
	invisible(list(rows = nrow(rows), errors = sum(error_rows), recorded_skips = sum(with_message)))
}
