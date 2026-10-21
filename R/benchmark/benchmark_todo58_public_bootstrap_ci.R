# Focused public-path evidence for release v1.0.5 TODO-58/TODO-6.
#
# This script only loads an installed EDI package; it never sources the
# checkout or compiles code. See --help for the two independent modes:
#   benchmark <new-output.csv>
#   dump-parity <expected-EDI-version> <new-output.rds>
#   compare-parity <EDI-1.0.2.rds> <current-EDI.rds>

args <- commandArgs(trailingOnly = TRUE)
script_file <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grepl("^--file=", commandArgs(trailingOnly = FALSE))][1L])
repo_root <- normalizePath(file.path(dirname(script_file), "../.."), winslash = "/", mustWork = TRUE)

sha256_file <- function(path) {
  if (length(path) != 1L || is.na(path) || !file.exists(path) || dir.exists(path)) return("<unavailable>")
  commands <- list(
    list(command = Sys.which("sha256sum"), args = character()),
    list(command = Sys.which("shasum"), args = c("-a", "256")),
    list(command = Sys.which("openssl"), args = c("dgst", "-sha256")),
    list(command = Sys.which("certutil"), args = c("-hashfile", shQuote(path), "SHA256"))
  )
  for (entry in commands) {
    if (!nzchar(entry$command)) next
    args <- c(entry$args, if (!identical(entry$command, Sys.which("certutil"))) shQuote(path))
    output <- tryCatch(system2(entry$command, args = args, stdout = TRUE, stderr = FALSE),
                       error = function(e) character())
    status <- attr(output, "status")
    if (!length(output) || (!is.null(status) && !identical(as.integer(status), 0L))) next
    hashes <- regmatches(output, gregexpr("[[:xdigit:]]{64}", output, perl = TRUE))
    hashes <- tolower(unlist(hashes, use.names = FALSE))
    if (length(hashes)) return(hashes[[1L]])
  }
  "<unavailable>"
}

todo58_provenance_sidecar_path <- function(output_csv) {
  if (!is.character(output_csv) || length(output_csv) != 1L || is.na(output_csv) || !nzchar(output_csv)) {
    stop("TODO-58 output CSV path must be one nonempty string.", call. = FALSE)
  }
  paste0(output_csv, ".provenance.rds")
}

capture_todo58_namespace_r_fingerprint <- function(namespace_path) {
  if (!is.character(namespace_path) || length(namespace_path) != 1L ||
      is.na(namespace_path) || !dir.exists(namespace_path)) {
    stop("TODO-58 loaded namespace path is unavailable.", call. = FALSE)
  }
  namespace_path <- normalizePath(namespace_path, winslash = "/", mustWork = TRUE)
  r_path <- file.path(namespace_path, "R")
  if (!dir.exists(r_path)) stop("TODO-58 loaded namespace has no R payload directory.", call. = FALSE)
  relative_paths <- sort(list.files(r_path, all.files = TRUE, recursive = TRUE,
                                   full.names = FALSE, include.dirs = FALSE))
  if (!length(relative_paths)) stop("TODO-58 loaded namespace R payload is empty.", call. = FALSE)
  full_paths <- file.path(r_path, relative_paths)
  info <- file.info(full_paths)
  if (anyNA(info$isdir) || any(info$isdir) || any(!file.exists(full_paths))) {
    stop("TODO-58 loaded namespace R payload contains a missing or non-file entry.", call. = FALSE)
  }
  hashes <- vapply(full_paths, sha256_file, character(1L), USE.NAMES = FALSE)
  if (any(!grepl("^[[:xdigit:]]{64}$", hashes))) {
    stop("TODO-58 could not hash every loaded namespace R payload file.", call. = FALSE)
  }
  entries <- paste(relative_paths, tolower(hashes), sep = "\t")
  manifest_path <- tempfile("edi-todo58-r-layer-manifest-")
  on.exit(unlink(manifest_path), add = TRUE)
  writeLines(entries, manifest_path, useBytes = TRUE)
  manifest_sha256 <- sha256_file(manifest_path)
  if (!grepl("^[[:xdigit:]]{64}$", manifest_sha256)) {
    stop("TODO-58 could not hash the loaded namespace R payload manifest.", call. = FALSE)
  }
  list(namespace_path = namespace_path,
       r_payload_path = normalizePath(r_path, winslash = "/", mustWork = TRUE),
       file_count = length(entries), files = entries,
       manifest_sha256 = tolower(manifest_sha256))
}

capture_todo58_checkout_identity <- function(repo_root, git_command = Sys.which("git")) {
  if (!is.character(repo_root) || length(repo_root) != 1L || is.na(repo_root) || !dir.exists(repo_root) ||
      !is.character(git_command) || length(git_command) != 1L || is.na(git_command) || !nzchar(git_command)) {
    stop("TODO-58 checkout or Git executable is unavailable.", call. = FALSE)
  }
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  git <- function(args, stdout = TRUE) {
    result <- tryCatch(suppressWarnings(system2(
      git_command, c("-C", shQuote(repo_root), args), stdout = stdout, stderr = FALSE
    )), error = function(e) NULL)
    status <- if (is.null(result)) NA_integer_ else attr(result, "status")
    if (is.null(result) || (!is.null(status) && !identical(as.integer(status), 0L))) {
      stop("TODO-58 could not capture checkout identity from Git.", call. = FALSE)
    }
    result
  }
  head <- trimws(git(c("rev-parse", "HEAD"))[[1L]])
  if (!grepl("^[[:xdigit:]]{40}([[:xdigit:]]{24})?$", head)) {
    stop("TODO-58 checkout HEAD is unavailable.", call. = FALSE)
  }
  status <- git(c("status", "--porcelain=v1", "--untracked-files=all"))
  status_text <- if (length(status)) paste(status, collapse = " | ") else "<clean>"

  diff_path <- tempfile("edi-todo58-checkout-diff-")
  on.exit(unlink(diff_path), add = TRUE)
  diff_status <- tryCatch(suppressWarnings(system2(
    git_command, c("-C", shQuote(repo_root), "diff", "--binary", "HEAD"),
    stdout = diff_path, stderr = FALSE
  )), error = function(e) NA_integer_)
  if (!identical(as.integer(diff_status), 0L)) stop("TODO-58 could not hash the checkout diff.", call. = FALSE)
  diff_sha256 <- sha256_file(diff_path)
  if (!grepl("^[[:xdigit:]]{64}$", diff_sha256)) stop("TODO-58 checkout diff hash is unavailable.", call. = FALSE)

  untracked <- git(c("ls-files", "--others", "--exclude-standard"))
  entries <- if (length(untracked)) vapply(untracked, function(path) {
    full_path <- file.path(repo_root, path)
    if (!file.exists(full_path) || dir.exists(full_path)) return(NA_character_)
    hash <- sha256_file(full_path)
    if (!grepl("^[[:xdigit:]]{64}$", hash)) return(NA_character_)
    paste(path, tolower(hash), sep = "\t")
  }, character(1L)) else character()
  if (anyNA(entries)) stop("TODO-58 could not hash every untracked checkout file.", call. = FALSE)
  manifest_path <- tempfile("edi-todo58-untracked-manifest-")
  on.exit(unlink(manifest_path), add = TRUE)
  writeLines(entries, manifest_path, useBytes = TRUE)
  untracked_sha256 <- sha256_file(manifest_path)
  if (!grepl("^[[:xdigit:]]{64}$", untracked_sha256)) {
    stop("TODO-58 untracked checkout manifest hash is unavailable.", call. = FALSE)
  }
  list(path = repo_root, head = head, status = status_text,
       tracked_diff_sha256 = tolower(diff_sha256),
       untracked_content_sha256 = tolower(untracked_sha256))
}

capture_todo58_host_state <- function(loadavg_lines = NULL, status_lines = NULL) {
  if (is.null(loadavg_lines)) {
    loadavg_lines <- tryCatch(readLines("/proc/loadavg", warn = FALSE, n = 1L), error = function(e) character())
  }
  if (is.null(status_lines)) {
    status_lines <- tryCatch(readLines("/proc/self/status", warn = FALSE), error = function(e) character())
  }
  affinity <- grep("^Cpus_allowed_list:", status_lines, value = TRUE)
  list(
    captured_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC"),
    load_average = if (length(loadavg_lines)) loadavg_lines[[1L]] else "<unavailable>",
    cpu_affinity = if (length(affinity)) sub("^Cpus_allowed_list:[[:space:]]*", "", affinity[[1L]]) else "<unavailable>"
  )
}

capture_todo58_thread_settings <- function(env_values = Sys.getenv(c(
    "OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "BLAS_NUM_THREADS",
    "VECLIB_MAXIMUM_THREADS", "NUMEXPR_NUM_THREADS", "R_DATATABLE_NUM_THREADS",
    "RCPP_PARALLEL_NUM_THREADS"
  ), unset = "<unset>")) {
  expected <- c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "BLAS_NUM_THREADS",
                "VECLIB_MAXIMUM_THREADS", "NUMEXPR_NUM_THREADS", "R_DATATABLE_NUM_THREADS",
                "RCPP_PARALLEL_NUM_THREADS")
  if (!is.character(env_values) || length(env_values) != length(expected) ||
      !identical(names(env_values), expected) || anyNA(env_values)) {
    stop("TODO-58 thread settings must name every supported thread-control variable.", call. = FALSE)
  }
  as.list(env_values)
}

validate_todo58_benchmark_sidecar <- function(sidecar) {
  is_text <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  is_hash <- function(x) is_text(x) && grepl("^[[:xdigit:]]{64}$", x)
  if (!is.list(sidecar) || !identical(sidecar$schema_version, 1L) ||
      !is_text(sidecar$output_csv_path) || !is_hash(sidecar$output_csv_sha256) ||
      !is_text(sidecar$started_at_utc) || !is_text(sidecar$finished_at_utc)) {
    stop("TODO-58 benchmark sidecar is missing its output or run identity.", call. = FALSE)
  }
  for (name in c("host_start", "host_finish")) {
    state <- sidecar[[name]]
    if (!is.list(state) || !all(c("captured_at_utc", "load_average", "cpu_affinity") %in% names(state)) ||
        !all(vapply(state[c("captured_at_utc", "load_average", "cpu_affinity")], is_text, logical(1L)))) {
      stop("TODO-58 benchmark sidecar is missing host load/affinity state.", call. = FALSE)
    }
  }
  expected_threads <- c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "BLAS_NUM_THREADS",
                        "VECLIB_MAXIMUM_THREADS", "NUMEXPR_NUM_THREADS", "R_DATATABLE_NUM_THREADS",
                        "RCPP_PARALLEL_NUM_THREADS")
  if (!is.list(sidecar$thread_settings) || !identical(names(sidecar$thread_settings), expected_threads) ||
      !all(vapply(sidecar$thread_settings, is_text, logical(1L)))) {
    stop("TODO-58 benchmark sidecar is missing thread settings.", call. = FALSE)
  }
  checkout <- sidecar$checkout
  if (!is.list(checkout) || !is_text(checkout$path) || !is_text(checkout$head) ||
      !is_text(checkout$status) || !is_hash(checkout$tracked_diff_sha256) ||
      !is_hash(checkout$untracked_content_sha256)) {
    stop("TODO-58 benchmark sidecar is missing checkout identity.", call. = FALSE)
  }
  r_payload <- sidecar$namespace_r_payload
  if (!is.list(r_payload) || !is_text(r_payload$namespace_path) || !is_text(r_payload$r_payload_path) ||
      !is.numeric(r_payload$file_count) || length(r_payload$file_count) != 1L ||
      !is.finite(r_payload$file_count) || r_payload$file_count < 1 ||
      !is.character(r_payload$files) || length(r_payload$files) != r_payload$file_count ||
      !is_hash(r_payload$manifest_sha256)) {
    stop("TODO-58 benchmark sidecar is missing loaded namespace R-layer identity.", call. = FALSE)
  }
  invisible(sidecar)
}

write_todo58_benchmark_sidecar <- function(output_csv, sidecar) {
  if (!is.character(output_csv) || length(output_csv) != 1L || is.na(output_csv) ||
      !file.exists(output_csv) || dir.exists(output_csv)) {
    stop("TODO-58 sidecar requires an existing output CSV.", call. = FALSE)
  }
  sidecar_path <- todo58_provenance_sidecar_path(output_csv)
  if (file.exists(sidecar_path) || dir.exists(sidecar_path)) {
    stop("Refusing to overwrite existing TODO-58 sidecar: ", sidecar_path, call. = FALSE)
  }
  sidecar$output_csv_path <- normalizePath(output_csv, winslash = "/", mustWork = TRUE)
  sidecar$output_csv_sha256 <- sha256_file(output_csv)
  if (!grepl("^[[:xdigit:]]{64}$", sidecar$output_csv_sha256)) {
    stop("TODO-58 output CSV SHA-256 is unavailable.", call. = FALSE)
  }
  sidecar$schema_version <- 1L
  validate_todo58_benchmark_sidecar(sidecar)
  saveRDS(sidecar, sidecar_path)
  invisible(sidecar_path)
}

todo58_case_manifest <- function() {
  list(
    list(key = "OLS", n = 1000L, B = 1000L, fixture_seed = 22422L, row_seed = 414230L),
    list(key = "logistic", n = 1000L, B = 500L, fixture_seed = 19021L, row_seed = 609739L),
    list(key = "Cox", n = 500L, B = 500L, fixture_seed = 17961L, row_seed = 628354L)
  )
}

todo58_case_keys <- function() {
  vapply(todo58_case_manifest(), function(spec) {
    paste(spec$key, spec$n, spec$B, spec$fixture_seed, spec$row_seed, sep = "|")
  }, character(1L))
}

validate_parity_provenance <- function(artifact, context) {
  is_scalar_text <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  if (!is.list(artifact) || !is_scalar_text(artifact$package_version) ||
      !is_scalar_text(artifact$package_path) || artifact$package_path == "<unavailable>" ||
      !is_scalar_text(artifact$edi_dll_path) || artifact$edi_dll_path == "<unavailable>" ||
      !is_scalar_text(artifact$edi_dll_sha256) ||
      !grepl("^[[:xdigit:]]{64}$", artifact$edi_dll_sha256)) {
    stop(context, " is missing valid EDI package/DLL provenance.", call. = FALSE)
  }

  # A saved path/hash is provenance metadata, not an authenticity anchor. When
  # the original files remain available, however, reject artifacts whose
  # recorded identity no longer matches those files.
  if (file.exists(artifact$package_path) && !dir.exists(artifact$package_path)) {
    stop(context, " package path is not a directory: ", artifact$package_path, call. = FALSE)
  }
  if (dir.exists(artifact$package_path)) {
    description <- file.path(artifact$package_path, "DESCRIPTION")
    if (!file.exists(description)) {
      stop(context, " package path exists without DESCRIPTION: ", artifact$package_path, call. = FALSE)
    }
    installed <- read.dcf(description)
    if (!"Version" %in% colnames(installed) ||
        !identical(unname(installed[1L, "Version"]), artifact$package_version)) {
      stop(context, " package version does not match its recorded path.", call. = FALSE)
    }
  }
  if (dir.exists(artifact$edi_dll_path)) {
    stop(context, " DLL path is a directory: ", artifact$edi_dll_path, call. = FALSE)
  }
  if (file.exists(artifact$edi_dll_path)) {
    actual_sha256 <- sha256_file(artifact$edi_dll_path)
    if (!grepl("^[[:xdigit:]]{64}$", actual_sha256) ||
        !identical(tolower(actual_sha256), tolower(artifact$edi_dll_sha256))) {
      stop(context, " DLL SHA-256 does not match its recorded path.", call. = FALSE)
    }
  }
  invisible(artifact)
}

validate_todo58_environment_provenance <- function(provenance, context) {
  is_scalar_text <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  required <- c(
    "boot_package_version", "survival_package_version", "host_sysname",
    "host_release", "host_machine", "r_platform", "blas_identity"
  )
  if (!is.list(provenance) || !all(required %in% names(provenance)) ||
      !all(vapply(required, function(name) is_scalar_text(provenance[[name]]), logical(1L)))) {
    stop(context, " is missing boot/survival, host, or BLAS provenance.", call. = FALSE)
  }
  invisible(provenance)
}

capture_todo58_environment_provenance <- function(
    boot_version = as.character(utils::packageVersion("boot")),
    survival_version = as.character(utils::packageVersion("survival")),
    host_info = Sys.info(), r_platform = R.version$platform,
    software_versions = extSoftVersion()) {
  host_fields <- c("sysname" = "sysname", "release" = "release", "machine" = "machine")
  host_identity <- lapply(host_fields, function(field) {
    value <- unname(host_info[[field]])
    if (is.null(value) || length(value) != 1L || is.na(value)) "" else as.character(value)
  })
  blas <- unname(software_versions["BLAS"])
  if (!length(blas) || is.na(blas)) blas <- ""
  provenance <- list(
    boot_package_version = as.character(boot_version),
    survival_package_version = as.character(survival_version),
    host_sysname = host_identity$sysname,
    host_release = host_identity$release,
    host_machine = host_identity$machine,
    r_platform = as.character(r_platform),
    blas_identity = as.character(blas)
  )
  validate_todo58_environment_provenance(provenance, "TODO-58 runtime environment")
  provenance
}

validate_todo58_parity_artifact <- function(artifact, context) {
  validate_parity_provenance(artifact, context)
  validate_todo58_environment_provenance(artifact, context)
  is_scalar_text <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  is_scalar_number <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x)
  if (!is_scalar_text(artifact$r_version) ||
      !is_scalar_text(artifact$script_path) || artifact$script_path == "<unavailable>" ||
      !is_scalar_text(artifact$script_sha256) || !grepl("^[[:xdigit:]]{64}$", artifact$script_sha256)) {
    stop(context, " is missing valid R/script provenance.", call. = FALSE)
  }
  if (dir.exists(artifact$script_path)) {
    stop(context, " script path is a directory: ", artifact$script_path, call. = FALSE)
  }
  if (file.exists(artifact$script_path)) {
    actual_script_sha256 <- sha256_file(artifact$script_path)
    if (!grepl("^[[:xdigit:]]{64}$", actual_script_sha256) ||
        !identical(tolower(actual_script_sha256), tolower(artifact$script_sha256))) {
      stop(context, " benchmark script SHA-256 does not match its recorded path.", call. = FALSE)
    }
  }

  expected_keys <- todo58_case_keys()
  if (!identical(as.character(artifact$case_keys), expected_keys)) {
    stop(context, " case keys do not match the accepted TODO-58 manifest.", call. = FALSE)
  }
  expected_cases <- todo58_case_manifest()
  if (!is.list(artifact$cases) || length(artifact$cases) != length(expected_cases)) {
    stop(context, " must contain exactly ", length(expected_cases), " case records.", call. = FALSE)
  }
  for (i in seq_along(expected_cases)) {
    observed <- artifact$cases[[i]]
    expected <- expected_cases[[i]]
    if (!is.list(observed) || !is_scalar_text(observed$key) || !identical(observed$key, expected$key) ||
        !is_scalar_number(observed$n) || observed$n != expected$n ||
        !is_scalar_number(observed$B) || observed$B != expected$B ||
        !is_scalar_number(observed$fixture_seed) || observed$fixture_seed != expected$fixture_seed ||
        !is_scalar_number(observed$row_seed) || observed$row_seed != expected$row_seed ||
        !is.numeric(observed$distribution) || length(observed$distribution) != expected$B) {
      stop(context, " case record does not match the accepted manifest: ", expected_keys[[i]], call. = FALSE)
    }
  }
  invisible(artifact)
}

capture_todo58_benchmark_provenance <- function(artifact, case_keys, script_path,
                                                 r_version = R.version.string,
                                                 runtime_provenance = capture_todo58_environment_provenance()) {
  validate_parity_provenance(artifact, "TODO-58 benchmark package provenance")
  validate_todo58_environment_provenance(runtime_provenance, "TODO-58 benchmark environment")
  expected_case_keys <- todo58_case_keys()
  if (!identical(as.character(case_keys), expected_case_keys)) {
    stop("TODO-58 benchmark fixtures, B, or seeds differ from the accepted manifest.", call. = FALSE)
  }
  if (!dir.exists(artifact$package_path) || !file.exists(artifact$edi_dll_path) ||
      dir.exists(artifact$edi_dll_path)) {
    stop("TODO-58 benchmark requires an existing installed EDI package and native DLL.", call. = FALSE)
  }
  if (!is.character(r_version) || length(r_version) != 1L || is.na(r_version) || !nzchar(r_version)) {
    stop("TODO-58 benchmark R version is unavailable.", call. = FALSE)
  }
  if (!is.character(script_path) || length(script_path) != 1L || is.na(script_path) ||
      !file.exists(script_path) || dir.exists(script_path)) {
    stop("TODO-58 benchmark script path is unavailable.", call. = FALSE)
  }
  script_path <- normalizePath(script_path, winslash = "/", mustWork = TRUE)
  script_sha256 <- sha256_file(script_path)
  if (!grepl("^[[:xdigit:]]{64}$", script_sha256)) {
    stop("TODO-58 benchmark script SHA-256 is unavailable.", call. = FALSE)
  }
  c(list(
    package_version = artifact$package_version,
    package_path = normalizePath(artifact$package_path, winslash = "/", mustWork = TRUE),
    edi_dll_path = normalizePath(artifact$edi_dll_path, winslash = "/", mustWork = TRUE),
    edi_dll_sha256 = tolower(artifact$edi_dll_sha256),
    r_version = r_version,
    script_path = script_path,
    script_sha256 = tolower(script_sha256),
    case_keys = expected_case_keys
  ), runtime_provenance)
}

usage <- function() {
  cat(paste(
    "Usage:",
    "  Rscript R/benchmark/benchmark_todo58_public_bootstrap_ci.R benchmark <new-output.csv>",
    "  EDI_LIB=/path/to/library Rscript R/benchmark/benchmark_todo58_public_bootstrap_ci.R dump-parity <expected-version> <new-output.rds>",
    "  Rscript R/benchmark/benchmark_todo58_public_bootstrap_ci.R compare-parity <EDI-1.0.2.rds> <current-EDI.rds>",
    "",
    "benchmark runs only the three TODO-58 public percentile-CI rows, at their original B,",
    "with ten alternating EDI/boot samples. dump-parity is run separately for EDI 1.0.2",
    "and the current installed package; set EDI_LIB to select each library. Output paths",
    "must be new so existing or canonical artifacts cannot be overwritten. Benchmark mode",
    "also writes <new-output.csv>.provenance.rds beside the timing CSV.",
    sep = "\n"
  ))
}

if (!length(args) || args[[1L]] %in% c("-h", "--help", "help")) {
  usage()
  quit(status = if (length(args)) 0L else 2L)
}

mode <- args[[1L]]
if (identical(mode, "compare-parity")) {
  if (length(args) != 3L) stop("compare-parity requires two RDS paths.", call. = FALSE)
  old <- readRDS(args[[2L]])
  current <- readRDS(args[[3L]])
  validate_todo58_parity_artifact(old, "EDI 1.0.2 parity artifact")
  validate_todo58_parity_artifact(current, "Current EDI parity artifact")
  if (!identical(old$package_version, "1.0.2")) {
    stop("The first parity artifact must come from installed EDI 1.0.2.", call. = FALSE)
  }
  if (identical(current$package_version, "1.0.2")) {
    stop("The second parity artifact must come from the current installed EDI.", call. = FALSE)
  }
  if (!identical(old$case_keys, current$case_keys)) {
    stop("Parity artifacts differ in fixtures, seeds, or B.", call. = FALSE)
  }
  comparisons <- lapply(seq_along(old$cases), function(i) {
    x <- old$cases[[i]]$distribution
    y <- current$cases[[i]]$distribution
    if (length(x) != length(y) || !identical(is.finite(x), is.finite(y))) {
      stop("Distribution length or finite-value pattern differs for ", old$case_keys[[i]], call. = FALSE)
    }
    finite <- is.finite(x)
    max_abs_diff <- if (any(finite)) max(abs(x[finite] - y[finite])) else NA_real_
    data.frame(case = old$case_keys[[i]], finite_n = sum(finite), max_abs_diff = max_abs_diff)
  })
  result <- do.call(rbind, comparisons)
  print(result, row.names = FALSE)
  if (any(!is.finite(result$max_abs_diff)) || any(result$max_abs_diff > 1e-10)) {
    stop("Fixed-seed distribution parity failed the 1e-10 TODO-3 tolerance.", call. = FALSE)
  }
  quit(status = 0L)
}

if (!mode %in% c("benchmark", "dump-parity")) {
  usage()
  stop("Unknown mode: ", mode, call. = FALSE)
}

if (identical(mode, "benchmark")) {
  if (length(args) != 2L) stop("benchmark requires one new CSV output path.", call. = FALSE)
  output_path <- args[[2L]]
  expected_version <- NULL
} else {
  if (length(args) != 3L) stop("dump-parity requires expected version and new RDS output path.", call. = FALSE)
  expected_version <- args[[2L]]
  output_path <- args[[3L]]
}

if (!is.character(output_path) || length(output_path) != 1L || is.na(output_path) || !nzchar(output_path)) {
  stop("Output path must be one nonempty string.", call. = FALSE)
}
output_parent <- normalizePath(dirname(output_path), winslash = "/", mustWork = TRUE)
output_path <- file.path(output_parent, basename(output_path))
sidecar_path <- if (identical(mode, "benchmark")) todo58_provenance_sidecar_path(output_path) else NULL
requested_outputs <- c(output_path, sidecar_path)
existing_outputs <- requested_outputs[file.exists(requested_outputs) | dir.exists(requested_outputs)]
if (length(existing_outputs)) {
  stop("Refusing to overwrite existing output(s): ", paste(existing_outputs, collapse = ", "), call. = FALSE)
}
if (startsWith(output_path, paste0(repo_root, "/R/package_metadata/"))) {
  stop("Benchmark evidence must not be written into canonical package metadata.", call. = FALSE)
}

edi_lib <- Sys.getenv("EDI_LIB", unset = "")
if (nzchar(edi_lib)) {
  if (!dir.exists(edi_lib)) stop("EDI_LIB is not a directory: ", edi_lib, call. = FALSE)
  .libPaths(c(normalizePath(edi_lib, winslash = "/", mustWork = TRUE), .libPaths()))
}
compiler::enableJIT(0L)
suppressPackageStartupMessages(library(EDI))
suppressPackageStartupMessages(library(boot))
suppressPackageStartupMessages(library(survival))
edi_path <- normalizePath(find.package("EDI"), winslash = "/", mustWork = TRUE)
if (startsWith(edi_path, paste0(repo_root, "/R/EDI"))) {
  stop("This evidence driver must use an installed EDI package, not the checkout.", call. = FALSE)
}
edi_version <- as.character(utils::packageVersion("EDI"))
loaded_edi_dll_path <- function() {
  dlls <- getLoadedDLLs()
  dll_paths <- vapply(dlls, function(dll) {
    tryCatch(as.character(dll[["path"]]), error = function(e) "")
  }, character(1L))
  is_edi <- grepl("(^|[/\\\\])EDI\\.(so|dylib|dll)$", dll_paths, ignore.case = TRUE)
  paths <- dll_paths[is_edi & nzchar(dll_paths)]
  if (!length(paths)) return("<unavailable>")
  tryCatch(normalizePath(paths[[1L]], winslash = "/", mustWork = TRUE),
           error = function(e) "<unavailable>")
}
edi_dll_path <- loaded_edi_dll_path()
edi_dll_sha256 <- sha256_file(edi_dll_path)
if (!is.null(expected_version) && !identical(edi_version, expected_version)) {
  stop("Expected EDI ", expected_version, " but loaded ", edi_version, " from ", edi_path, call. = FALSE)
}
cat("Installed EDI", edi_version, "from", edi_path,
    "(DLL:", edi_dll_path, "; SHA-256:", edi_dll_sha256, ")\n")

seed_for_class <- function(label) {
  codes <- utf8ToInt(label)
  as.integer(sum(codes * seq_along(codes)) %% 2147483647)
}

cases <- list(
  list(key = "OLS", fixture = "continuous", response = "continuous", n = 1000L, B = 1000L,
       row = "Nonparametric bootstrap CI: OLS (B = 1000) [R6 InferenceContinOLS]",
       canonical = "boot(lm.fit)+boot.ci(perc)", class = InferenceContinOLS),
  list(key = "logistic", fixture = "incidence", response = "incidence", n = 1000L, B = 500L,
       row = "Nonparametric bootstrap CI: logistic regression (B = 500) [R6 InferenceIncidLogRegr]",
       canonical = "boot(glm.fit)+boot.ci(perc)", class = InferenceIncidLogRegr),
  list(key = "Cox", fixture = "survival", response = "survival", n = 500L, B = 500L,
       row = "Nonparametric bootstrap CI: Cox PH (B = 500, n = 500) [R6 InferenceSurvivalCoxPHRegr]",
       canonical = "boot(coxph.fit)+boot.ci(perc)", class = InferenceSurvivalCoxPHRegr)
)
for (i in seq_along(cases)) {
  cases[[i]]$fixture_seed <- seed_for_class(paste("Procedure", cases[[i]]$fixture))
  cases[[i]]$row_seed <- seed_for_class(paste(cases[[i]]$row, "boot", cases[[i]]$canonical))
}
case_keys <- vapply(cases, function(x) paste(x$key, x$n, x$B, x$fixture_seed, x$row_seed, sep = "|"), character(1L))
benchmark_provenance <- capture_todo58_benchmark_provenance(
  artifact = list(
    package_version = edi_version, package_path = edi_path,
    edi_dll_path = edi_dll_path, edi_dll_sha256 = edi_dll_sha256
  ),
  case_keys = case_keys,
  script_path = script_file
)
if (identical(mode, "benchmark")) {
  benchmark_sidecar_started_at <- Sys.time()
  benchmark_sidecar_host_start <- capture_todo58_host_state()
  benchmark_sidecar_threads <- capture_todo58_thread_settings()
  benchmark_sidecar_checkout <- capture_todo58_checkout_identity(repo_root)
  benchmark_sidecar_r_payload <- capture_todo58_namespace_r_fingerprint(
    getNamespaceInfo(asNamespace("EDI"), "path")
  )
}

generate_data <- function(n, p = 5L, family) {
  X <- matrix(stats::rnorm(n * p), n, p)
  X[, 1L] <- 1
  beta <- stats::rnorm(p) * 0.5
  n_treat <- floor(n / 2)
  w <- sample(c(rep(1, n_treat), rep(0, n - n_treat)))
  eta <- drop(X %*% beta + 0.5 * w)
  out <- list(X = X, w = w)
  if (identical(family, "logistic")) {
    out$y <- stats::rbinom(n, 1L, stats::plogis(eta))
  } else if (identical(family, "cox")) {
    out$y <- stats::rexp(n, exp(eta))
    out$dead <- stats::rbinom(n, 1L, 0.8)
  } else {
    out$y <- as.numeric(eta + stats::rnorm(n, 0, 0.5))
  }
  out
}

build_case <- function(spec) {
  set.seed(spec$fixture_seed)
  d <- generate_data(spec$n, family = switch(spec$fixture,
    continuous = "continuous", incidence = "logistic", survival = "cox"
  ))
  X_cov <- as.data.frame(d$X[, -1L, drop = FALSE])
  names(X_cov) <- paste0("x", seq_len(ncol(X_cov)))
  des <- DesignFixediBCRD$new(n = spec$n, response_type = spec$response)
  des$add_all_subjects_to_experiment(X_cov)
  des$assign_w_to_all_subjects(as.numeric(d$w))
  if (identical(spec$response, "survival")) {
    des$add_all_subject_responses(
      ifelse(d$dead == 1L, d$y, NA_real_),
      y_Ls = ifelse(d$dead == 0L, d$y, NA_real_),
      y_Rs = ifelse(d$dead == 0L, Inf, NA_real_)
    )
  } else {
    des$add_all_subject_responses(as.numeric(d$y))
  }
  X_full <- cbind(`(Intercept)` = 1, treatment = as.numeric(d$w), as.matrix(X_cov))
  X_ord <- cbind(treatment = as.numeric(d$w), as.matrix(X_cov))
  df <- cbind(data.frame(y = as.numeric(d$y), treatment = as.integer(d$w),
                         Z = as.integer(d$w), dead = if (!is.null(d$dead)) d$dead else 1L), X_cov)
  list(design = des, d = d, df = df, X_full = X_full, X_ord = X_ord)
}

new_inference <- function(spec, fixture) {
  inference <- spec$class$new(fixture$design)
  inference$num_cores <- 1L
  inference
}

run_edi_ci <- function(spec, fixture, seed) {
  set.seed(seed)
  construction_ms <- system.time(inference <- new_inference(spec, fixture))[["elapsed"]] * 1000
  # This is the same public call used by benchmark_model_fits.R. The fresh
  # object is outside the procedure timer so the two columns remain separate.
  elapsed <- system.time(
    ci <- inference$compute_bootstrap_confidence_interval(
      B = spec$B, type = "percentile", show_progress = FALSE
    )
  )[["elapsed"]] * 1000
  list(ci = as.numeric(ci[1:2]), construction_ms = construction_ms, elapsed_ms = elapsed)
}

run_boot_ci <- function(spec, fixture, seed) {
  d <- fixture$d
  df <- fixture$df
  X_full <- fixture$X_full
  X_ord <- fixture$X_ord
  set.seed(seed)
  elapsed <- system.time({
    if (identical(spec$key, "OLS")) {
      bo <- boot::boot(df, function(dd, i) stats::lm.fit(X_full[i, , drop = FALSE], dd$y[i])$coefficients[2L], R = spec$B)
    } else if (identical(spec$key, "logistic")) {
      bo <- boot::boot(df, function(dd, i) stats::glm.fit(X_full[i, , drop = FALSE], dd$y[i], family = stats::binomial())$coefficients[2L], R = spec$B)
    } else {
      bo <- boot::boot(df, function(dd, i) survival::coxph.fit(
        x = X_ord[i, , drop = FALSE],
        y = survival::Surv(dd$y[i], dd$dead[i]), strata = NULL, offset = NULL, init = NULL,
        control = survival::coxph.control(), weights = NULL, method = "breslow",
        rownames = as.character(seq_along(i))
      )$coefficients[1L], R = spec$B)
    }
    ci <- boot::boot.ci(bo, type = "perc")$percent[4:5]
  })[["elapsed"]] * 1000
  list(ci = as.numeric(ci), elapsed_ms = elapsed)
}

if (identical(mode, "dump-parity")) {
  results <- lapply(cases, function(spec) {
    fixture <- build_case(spec)
    set.seed(spec$row_seed)
    inference <- new_inference(spec, fixture)
    distribution <- as.numeric(inference$approximate_bootstrap_distribution_beta_hat_T(
      B = spec$B, show_progress = FALSE
    ))
    list(key = spec$key, n = spec$n, B = spec$B, fixture_seed = spec$fixture_seed,
         row_seed = spec$row_seed, distribution = distribution)
  })
  saveRDS(c(benchmark_provenance, list(cases = results)), output_path)
  cat("Wrote installed-package parity dump:", output_path, "\n")
  quit(status = 0L)
}

rows <- vector("list", length(cases) * 10L)
row_i <- 0L
for (i in seq_along(cases)) {
  spec <- cases[[i]]
  fixture <- build_case(spec)
  # Unrecorded warmups; measured samples below still use fresh inference objects.
  invisible(run_edi_ci(spec, fixture, spec$row_seed))
  invisible(run_boot_ci(spec, fixture, spec$row_seed))
  for (sample_id in seq_len(10L)) {
    row_i <- row_i + 1L
    # Match the exact row seed recorded in the canonical benchmark plan. Both
    # sides restart from it for each timing pair; timing parity does not assume
    # that the two implementations consume identical bootstrap indices.
    seed <- spec$row_seed
    if (sample_id %% 2L == 1L) {
      edi <- run_edi_ci(spec, fixture, seed)
      canonical <- run_boot_ci(spec, fixture, seed)
    } else {
      canonical <- run_boot_ci(spec, fixture, seed)
      edi <- run_edi_ci(spec, fixture, seed)
    }
    rows[[row_i]] <- data.frame(
      case = spec$key, sample = sample_id, n = spec$n, B = spec$B,
      EDI_package_version = edi_version, EDI_package_path = edi_path,
      EDI_dll_path = edi_dll_path, EDI_dll_sha256 = edi_dll_sha256,
      EDI_R_version = benchmark_provenance$r_version,
      boot_package_version = benchmark_provenance$boot_package_version,
      survival_package_version = benchmark_provenance$survival_package_version,
      host_sysname = benchmark_provenance$host_sysname,
      host_release = benchmark_provenance$host_release,
      host_machine = benchmark_provenance$host_machine,
      R_platform = benchmark_provenance$r_platform,
      BLAS_identity = benchmark_provenance$blas_identity,
      benchmark_script_path = benchmark_provenance$script_path,
      benchmark_script_sha256 = benchmark_provenance$script_sha256,
      fixture_seed = spec$fixture_seed, row_seed = seed,
      EDI_CI_lower = edi$ci[1L], EDI_CI_upper = edi$ci[2L],
      EDI_construction_ms = edi$construction_ms,
      EDI_procedure_ms = edi$elapsed_ms, boot_CI_lower = canonical$ci[1L],
      boot_CI_upper = canonical$ci[2L], boot_complete_ms = canonical$elapsed_ms,
      speedup = canonical$elapsed_ms / edi$elapsed_ms
    )
    cat(sprintf("%s sample %02d/10: EDI %.1f ms, boot %.1f ms, speedup %.3fx\n",
                spec$key, sample_id, edi$elapsed_ms, canonical$elapsed_ms,
                canonical$elapsed_ms / edi$elapsed_ms))
  }
}
result <- do.call(rbind, rows)
utils::write.csv(result, output_path, row.names = FALSE)
summary <- aggregate(speedup ~ case, data = result, FUN = stats::median)
cat("Median current speed ratios (boot complete time / EDI public R6 procedure):\n")
print(summary, row.names = FALSE)
cat("Wrote isolated timing samples:", output_path, "\n")
if (identical(mode, "benchmark")) {
  benchmark_sidecar <- list(
    started_at_utc = format(benchmark_sidecar_started_at, "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC"),
    finished_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC"),
    host_start = benchmark_sidecar_host_start,
    host_finish = capture_todo58_host_state(),
    thread_settings = benchmark_sidecar_threads,
    checkout = benchmark_sidecar_checkout,
    namespace_r_payload = benchmark_sidecar_r_payload,
    benchmark_provenance = benchmark_provenance,
    case_keys = case_keys
  )
  written_sidecar <- write_todo58_benchmark_sidecar(output_path, benchmark_sidecar)
  cat("Wrote benchmark provenance sidecar:", written_sidecar, "\n")
}
if (any(!is.finite(summary$speedup)) || any(summary$speedup < 1)) {
  stop("TODO-6 current-speed acceptance failed: at least one row is below 1x boot.", call. = FALSE)
}
