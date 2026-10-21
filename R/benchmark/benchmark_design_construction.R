# Focused fixed-design construction benchmark (release v1.0.5 TODO-59).
#
# Default: benchmark the installed package.  For a non-compiling checkout run,
# set EDI_BENCH_SOURCE=1; pkgload then loads R/EDI with compile = FALSE.

if (identical(Sys.getenv("EDI_BENCH_SOURCE"), "1")) {
  pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)
} else {
  suppressPackageStartupMessages(library(EDI))
}

args = commandArgs(trailingOnly = TRUE)
n = if (length(args) >= 1L) as.integer(args[[1L]]) else 1000L
batch = if (length(args) >= 2L) as.integer(args[[2L]]) else 100L
repeats = if (length(args) >= 3L) as.integer(args[[3L]]) else 7L
stopifnot(n > 1L, batch > 0L, repeats > 0L)
if (length(args) >= 4L) {
  output_csv = args[[4L]]
  output_paths = c(output_csv, paste0(output_csv, ".provenance.txt"))
  already_exists = file.exists(output_paths) | dir.exists(output_paths)
  if (any(already_exists)) {
    stop(
      "Refusing to overwrite existing benchmark output(s): ",
      paste(output_paths[already_exists], collapse = ", "),
      call. = FALSE
    )
  }
}

set.seed(5901L)
benchmark_started_at = Sys.time()
loaded_edi_dll_path = function() {
  dlls = getLoadedDLLs()
  dll_paths = vapply(dlls, function(dll) {
    tryCatch(as.character(dll[["path"]]), error = function(e) "")
  }, character(1L))
  is_edi = grepl("(^|[/\\\\])EDI\\.(so|dylib|dll)$", dll_paths, ignore.case = TRUE)
  paths = dll_paths[is_edi & nzchar(dll_paths)]
  if (!length(paths)) return("<unavailable>")
  tryCatch(normalizePath(paths[[1L]], winslash = "/", mustWork = TRUE),
           error = function(e) "<unavailable>")
}
sha256_file = function(path) {
  if (length(path) != 1L || is.na(path) || !file.exists(path)) return("<unavailable>")
  commands = list(
    list(command = Sys.which("sha256sum"), args = character()),
    list(command = Sys.which("shasum"), args = "-a 256"),
    list(command = Sys.which("openssl"), args = c("dgst", "-sha256")),
    list(command = Sys.which("certutil"), args = c("-hashfile", shQuote(path), "SHA256"))
  )
  for (entry in commands) {
    if (!nzchar(entry$command)) next
    args = c(entry$args, if (!identical(entry$command, Sys.which("certutil"))) shQuote(path))
    output = tryCatch(system2(entry$command, args = args, stdout = TRUE, stderr = FALSE),
                      error = function(e) character())
    status = attr(output, "status")
    if (!length(output) || (!is.null(status) && !identical(as.integer(status), 0L))) next
    hashes = regmatches(output, gregexpr("[[:xdigit:]]{64}", output, perl = TRUE))
    hashes = tolower(unlist(hashes, use.names = FALSE))
    if (length(hashes)) return(hashes[[1L]])
  }
  "<unavailable>"
}
read_benchmark_r_layer_state = function(package_path) {
  unavailable = list(path = "<unavailable>", file_count = NA_integer_,
                     files = "<unavailable>", manifest_sha256 = "<unavailable>")
  if (length(package_path) != 1L || is.na(package_path) || !dir.exists(package_path)) {
    return(unavailable)
  }
  r_path = file.path(package_path, "R")
  if (!dir.exists(r_path)) return(unavailable)
  r_path = tryCatch(normalizePath(r_path, winslash = "/", mustWork = TRUE),
                    error = function(e) NA_character_)
  if (is.na(r_path)) return(unavailable)
  relative_paths = sort(list.files(r_path, all.files = TRUE, recursive = TRUE,
                                   full.names = FALSE, include.dirs = FALSE))
  if (!length(relative_paths)) return(unavailable)
  full_paths = file.path(r_path, relative_paths)
  info = file.info(full_paths)
  if (anyNA(info$isdir) || any(info$isdir) || any(!file.exists(full_paths))) {
    return(unavailable)
  }
  hashes = vapply(full_paths, sha256_file, character(1L), USE.NAMES = FALSE)
  if (any(!grepl("^[[:xdigit:]]{64}$", hashes))) return(unavailable)
  entries = paste(relative_paths, tolower(hashes), sep = "\t")
  manifest_path = tempfile("edi-design-benchmark-r-layer-manifest-")
  on.exit(unlink(manifest_path), add = TRUE)
  writeLines(entries, manifest_path, useBytes = TRUE)
  manifest_sha256 = sha256_file(manifest_path)
  if (!grepl("^[[:xdigit:]]{64}$", manifest_sha256)) return(unavailable)
  list(path = r_path, file_count = length(entries), files = entries,
       manifest_sha256 = tolower(manifest_sha256))
}
read_benchmark_git_state = function(git_command = Sys.which("git"), git_args_prefix = character()) {
  if (length(git_command) != 1L || is.na(git_command) || !nzchar(git_command)) {
    return(list(status = "<unavailable>", tracked_diff_sha256 = "<unavailable>",
                untracked_content_sha256 = "<unavailable>"))
  }
  status = tryCatch(
    suppressWarnings(system2(git_command,
      c(git_args_prefix, "status", "--porcelain=v1", "--untracked-files=all"),
      stdout = TRUE, stderr = FALSE)),
    error = function(e) NULL
  )
  status_code = if (is.null(status)) NA_integer_ else attr(status, "status")
  status_failed = is.null(status) || (!is.null(status_code) && !identical(as.integer(status_code), 0L))
  status_text = if (status_failed) {
    "<unavailable>"
  } else if (!length(status)) {
    "<clean>"
  } else {
    paste(status, collapse = " | ")
  }

  diff_file = tempfile("edi-design-benchmark-git-diff-")
  on.exit(unlink(diff_file), add = TRUE)
  diff_code = tryCatch(
    suppressWarnings(system2(git_command, c(git_args_prefix, "diff", "--binary", "HEAD"),
                             stdout = diff_file, stderr = FALSE)),
    error = function(e) NA_integer_
  )
  diff_sha256 = if (isTRUE(as.integer(diff_code) == 0L)) sha256_file(diff_file) else "<unavailable>"

  untracked_paths = tryCatch(
    suppressWarnings(system2(git_command,
      c(git_args_prefix, "ls-files", "--others", "--exclude-standard"),
      stdout = TRUE, stderr = FALSE)),
    error = function(e) NULL
  )
  untracked_code = if (is.null(untracked_paths)) NA_integer_ else attr(untracked_paths, "status")
  untracked_failed = is.null(untracked_paths) ||
    (!is.null(untracked_code) && !identical(as.integer(untracked_code), 0L))
  untracked_sha256 = "<unavailable>"
  if (!untracked_failed) {
    repository_root = tryCatch(
      suppressWarnings(system2(git_command,
        c(git_args_prefix, "rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE)),
      error = function(e) NULL
    )
    root_code = if (is.null(repository_root)) NA_integer_ else attr(repository_root, "status")
    root_failed = is.null(repository_root) || !length(repository_root) ||
      (!is.null(root_code) && !identical(as.integer(root_code), 0L))
    if (!root_failed) {
      entries = vapply(untracked_paths, function(path) {
        full_path = file.path(repository_root[[1L]], path)
        if (!file.exists(full_path) || dir.exists(full_path)) return(NA_character_)
        paste(path, sha256_file(full_path), sep = "\t")
      }, character(1L))
      if (all(!is.na(entries)) && all(!grepl("<unavailable>$", entries))) {
        manifest_file = tempfile("edi-design-benchmark-untracked-manifest-")
        on.exit(unlink(manifest_file), add = TRUE)
        writeLines(entries, manifest_file, useBytes = TRUE)
        untracked_sha256 = sha256_file(manifest_file)
      }
    }
  }
  list(status = status_text, tracked_diff_sha256 = diff_sha256,
       untracked_content_sha256 = untracked_sha256)
}
benchmark_edi_dll_path = loaded_edi_dll_path()
benchmark_edi_dll_sha256 = sha256_file(benchmark_edi_dll_path)
benchmark_edi_namespace_path = tryCatch(
  normalizePath(getNamespaceInfo(asNamespace("EDI"), "path"), winslash = "/", mustWork = TRUE),
  error = function(e) "<unavailable>"
)
benchmark_edi_r_layer = read_benchmark_r_layer_state(benchmark_edi_namespace_path)
if (!grepl("^[[:xdigit:]]{64}$", benchmark_edi_r_layer$manifest_sha256)) {
  stop("Could not authenticate the loaded EDI R namespace payload.", call. = FALSE)
}
benchmark_git_state = read_benchmark_git_state()
read_benchmark_host_state = function() {
  loadavg = tryCatch(readLines("/proc/loadavg", warn = FALSE, n = 1L), error = function(e) character())
  status = tryCatch(readLines("/proc/self/status", warn = FALSE), error = function(e) character())
  affinity = grep("^Cpus_allowed_list:", status, value = TRUE)
  list(
    loadavg = if (length(loadavg)) loadavg[[1L]] else "<unavailable>",
    cpu_affinity = if (length(affinity)) sub("^Cpus_allowed_list:[[:space:]]*", "", affinity[[1L]]) else "<unavailable>"
  )
}
benchmark_start_host_state = read_benchmark_host_state()
X_cont = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n), x4 = rnorm(n))
X_fac = data.frame(
  x1 = factor(rep(1:3, length.out = n)),
  x2 = factor(rep(1:2, each = ceiling(n / 2), length.out = n))
)

elapsed_per_call_ms = function(expr, calls) {
  unname(system.time(force(expr))[["elapsed"]]) * 1000 / calls
}

measure = function(label, run_batch) {
  samples = vapply(seq_len(repeats), function(i) {
    set.seed(5901L + i)
    run_batch()
  }, numeric(1))
  data.frame(
    stage = label,
    n = n,
    batch = batch,
    median_ms = stats::median(samples),
    min_ms = min(samples),
    max_ms = max(samples),
    stringsAsFactors = FALSE
  )
}

new_ibcrd = function(n_value = n) {
  DesignFixediBCRD$new(n = n_value, response_type = "continuous")
}

new_blocking = function(n_value = n) {
  DesignFixedBlocking$new(
    n = n_value, response_type = "continuous", strata_cols = c("x1", "x2"),
    equal_block_sizes = FALSE
  )
}

register_blocking_batch = function() {
  designs = replicate(batch, new_blocking(), simplify = FALSE)
  invisible(lapply(designs, function(d) d$add_all_subjects_to_experiment(X_fac)))
  designs
}

results = do.call(rbind, list(
  measure("DesignFixediBCRD$new(n = NULL) only", function() {
    elapsed_per_call_ms(replicate(batch, new_ibcrd(n_value = NULL), simplify = FALSE), batch)
  }),
  measure("DesignFixediBCRD$new() only", function() {
    elapsed_per_call_ms(replicate(batch, new_ibcrd(), simplify = FALSE), batch)
  }),
  measure("add_all_subjects_to_experiment() only (lazy registration)", function() {
    designs = replicate(batch, new_ibcrd(), simplify = FALSE)
    elapsed_per_call_ms(lapply(designs, function(d) d$add_all_subjects_to_experiment(X_cont)), batch)
  }),
  measure("first get_X() only (deferred ingestion/model matrix)", function() {
    designs = replicate(batch, new_ibcrd(), simplify = FALSE)
    invisible(lapply(designs, function(d) d$add_all_subjects_to_experiment(X_cont)))
    elapsed_per_call_ms(lapply(designs, function(d) d$get_X()), batch)
  }),
  measure("iBCRD construction + registration + assignment", function() {
    elapsed_per_call_ms(replicate(batch, {
      d = new_ibcrd()
      d$add_all_subjects_to_experiment(X_cont)
      d$assign_w_to_all_subjects()
    }, simplify = FALSE), batch)
  }),
  measure("blocking construction + registration + assignment", function() {
    elapsed_per_call_ms(replicate(batch, {
      d = new_blocking()
      d$add_all_subjects_to_experiment(X_fac)
      d$assign_w_to_all_subjects()
    }, simplify = FALSE), batch)
  }),
  measure("DesignFixedBlocking$new(n = NULL) only", function() {
    elapsed_per_call_ms(replicate(batch, new_blocking(n_value = NULL), simplify = FALSE), batch)
  }),
  measure("DesignFixedBlocking$new() only", function() {
    elapsed_per_call_ms(replicate(batch, new_blocking(), simplify = FALSE), batch)
  }),
  measure("blocking registration only (lazy covariates)", function() {
    designs = replicate(batch, new_blocking(), simplify = FALSE)
    elapsed_per_call_ms(lapply(designs, function(d) d$add_all_subjects_to_experiment(X_fac)), batch)
  }),
  measure("blocking assignment only", function() {
    designs = register_blocking_batch()
    elapsed_per_call_ms(lapply(designs, function(d) d$assign_w_to_all_subjects()), batch)
  })
))

print(results, row.names = FALSE, digits = 4)
if (length(args) >= 4L) {
  utils::write.csv(results, output_csv, row.names = FALSE)

  # Keep machine/package identity beside the scratch timing output without
  # changing the stable CSV schema consumed by benchmark reports.
  relevant_env = c("EDI_BENCH_SOURCE", "R_LIBS", "R_LIBS_USER", "OMP_NUM_THREADS",
                   "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "BLAS_NUM_THREADS")
  env_values = Sys.getenv(relevant_env, unset = "<unset>")
  names(env_values) = relevant_env
  checkout_commit = tryCatch(
    system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(e) "unavailable"
  )
  if (!length(checkout_commit)) checkout_commit = "unavailable"
  benchmark_end_host_state = read_benchmark_host_state()
  provenance = c(
    paste("started:", format(benchmark_started_at, tz = "UTC", usetz = TRUE)),
    paste("finished:", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    paste("parameters: n=", n, " batch=", batch, " repeats=", repeats, " seed=5901", sep = ""),
    paste("EDI version:", as.character(utils::packageVersion("EDI"))),
    paste("EDI library:", find.package("EDI")),
    paste("EDI R namespace path:", benchmark_edi_r_layer$path),
    paste("EDI R namespace payload files:", benchmark_edi_r_layer$file_count),
    paste("EDI R namespace payload manifest SHA-256:", benchmark_edi_r_layer$manifest_sha256),
    paste("EDI R namespace payload file SHA-256:", paste(benchmark_edi_r_layer$files, collapse = " | ")),
    paste("EDI native DLL:", benchmark_edi_dll_path),
    paste("EDI native DLL SHA-256:", benchmark_edi_dll_sha256),
    paste("checkout HEAD:", checkout_commit[[1L]]),
    paste("checkout worktree status (porcelain):", benchmark_git_state$status),
    paste("checkout tracked diff from HEAD SHA-256:", benchmark_git_state$tracked_diff_sha256),
    paste("checkout untracked content manifest SHA-256:", benchmark_git_state$untracked_content_sha256),
    paste("R:", R.version.string),
    paste("platform:", R.version$platform),
    paste("host:", paste(Sys.info(), collapse = " | ")),
    paste("host load average at start:", benchmark_start_host_state$loadavg),
    paste("host load average at finish:", benchmark_end_host_state$loadavg),
    paste("process CPU affinity at start:", benchmark_start_host_state$cpu_affinity),
    paste("process CPU affinity at finish:", benchmark_end_host_state$cpu_affinity),
    paste("environment:", paste(names(env_values), env_values, sep = "=", collapse = "; ")),
    capture.output(utils::sessionInfo())
  )
  writeLines(provenance, paste0(output_csv, ".provenance.txt"))
}
