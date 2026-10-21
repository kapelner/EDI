# Focused Pocock-Simon per-arrival benchmark (release v1.0.5 TODO-60).
# Set EDI_BENCH_SOURCE=1 for a non-compiling pkgload checkout run.

if (identical(Sys.getenv("EDI_BENCH_SOURCE"), "1")) {
  pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)
} else {
  suppressPackageStartupMessages(library(EDI))
}

args = commandArgs(trailingOnly = TRUE)
n = if (length(args) >= 1L) as.integer(args[[1L]]) else 1000L
batch = if (length(args) >= 2L) as.integer(args[[2L]]) else 20L
repeats = if (length(args) >= 3L) as.integer(args[[3L]]) else 5L
if (length(args) >= 4L) {
  output_csv = args[[4L]]
  output_paths = c(output_csv, paste0(output_csv, ".provenance.txt"))
  already_exists = file.exists(output_paths) | dir.exists(output_paths)
  if (any(already_exists)) {
    stop("Refusing to overwrite existing benchmark output(s): ",
         paste(output_paths[already_exists], collapse = ", "), call. = FALSE)
  }
}
checkpoints = unique(pmin(n, c(10L, 100L, 500L, 1000L)))

sha256_file = function(path) {
  if (length(path) != 1L || is.na(path) || !file.exists(path)) return("<unavailable>")
  commands = list(
    list(command = Sys.which("sha256sum"), args = character()),
    list(command = Sys.which("shasum"), args = "-a 256"),
    list(command = Sys.which("openssl"), args = c("dgst", "-sha256"))
  )
  for (entry in commands) {
    if (!nzchar(entry$command)) next
    output = tryCatch(suppressWarnings(system2(entry$command,
      c(entry$args, shQuote(path)), stdout = TRUE, stderr = FALSE)), error = function(e) character())
    status = attr(output, "status")
    if (!length(output) || (!is.null(status) && !identical(as.integer(status), 0L))) next
    hashes = tolower(unlist(regmatches(output, gregexpr("[[:xdigit:]]{64}", output, perl = TRUE)), use.names = FALSE))
    if (length(hashes)) return(hashes[[1L]])
  }
  "<unavailable>"
}
loaded_edi_dll_path = function() {
  dlls = getLoadedDLLs()
  paths = vapply(dlls, function(dll) tryCatch(as.character(dll[["path"]]), error = function(e) ""), character(1L))
  paths = paths[grepl("(^|[/\\\\])EDI\\.(so|dylib|dll)$", paths, ignore.case = TRUE) & nzchar(paths)]
  if (!length(paths)) return("<unavailable>")
  tryCatch(normalizePath(paths[[1L]], winslash = "/", mustWork = TRUE), error = function(e) "<unavailable>")
}
loaded_edi_namespace_path = function() {
  namespace = tryCatch(asNamespace("EDI"), error = function(e) NULL)
  if (is.null(namespace)) return("<unavailable>")
  path = tryCatch(getNamespaceInfo(namespace, "path"), error = function(e) "")
  if (!is.character(path) || length(path) != 1L || is.na(path) || !dir.exists(path)) return("<unavailable>")
  tryCatch(normalizePath(path, winslash = "/", mustWork = TRUE), error = function(e) "<unavailable>")
}
edi_r_layer_sha256 = function(namespace_path = loaded_edi_namespace_path()) {
  if (!is.character(namespace_path) || length(namespace_path) != 1L || is.na(namespace_path) ||
      identical(namespace_path, "<unavailable>")) return("<unavailable>")
  r_dir = file.path(namespace_path, "R")
  if (!dir.exists(r_dir)) return("<unavailable>")
  files = sort(list.files(r_dir, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE))
  files = files[!dir.exists(files)]
  if (!length(files)) return("<unavailable>")
  file_hashes = vapply(files, sha256_file, character(1L))
  if (any(!grepl("^[[:xdigit:]]{64}$", file_hashes))) return("<unavailable>")
  root = normalizePath(r_dir, winslash = "/", mustWork = TRUE)
  paths = normalizePath(files, winslash = "/", mustWork = TRUE)
  relative_paths = substring(paths, nchar(root) + 2L)
  manifest = tempfile("edi-pocock-r-layer-manifest-")
  on.exit(unlink(manifest), add = TRUE)
  writeLines(paste(relative_paths, tolower(file_hashes), sep = "\t"), manifest, useBytes = TRUE)
  sha256_file(manifest)
}
read_git_state = function(git_command = "git") {
  status = tryCatch(suppressWarnings(system2(git_command,
    c("status", "--porcelain=v1", "--untracked-files=all"), stdout = TRUE, stderr = FALSE)),
    error = function(e) NULL)
  status_code = if (is.null(status)) NA_integer_ else attr(status, "status")
  status_failed = is.null(status) || (!is.null(status_code) && !identical(as.integer(status_code), 0L))
  status_text = if (status_failed) "<unavailable>" else if (!length(status)) "<clean>" else paste(status, collapse = " | ")
  diff_file = tempfile("edi-pocock-benchmark-git-diff-")
  on.exit(unlink(diff_file), add = TRUE)
  diff_code = tryCatch(suppressWarnings(system2(git_command, c("diff", "--binary", "HEAD"),
    stdout = diff_file, stderr = FALSE)), error = function(e) NA_integer_)
  diff_hash = if (isTRUE(as.integer(diff_code) == 0L)) sha256_file(diff_file) else "<unavailable>"
  list(status = status_text, tracked_diff_sha256 = diff_hash)
}
read_host_state = function() {
  loadavg = tryCatch(readLines("/proc/loadavg", warn = FALSE, n = 1L), error = function(e) character())
  proc_status = tryCatch(readLines("/proc/self/status", warn = FALSE), error = function(e) character())
  affinity = grep("^Cpus_allowed_list:", proc_status, value = TRUE)
  list(loadavg = if (length(loadavg)) loadavg[[1L]] else "<unavailable>",
       cpu_affinity = if (length(affinity)) sub("^Cpus_allowed_list:[[:space:]]*", "", affinity[[1L]]) else "<unavailable>")
}
benchmark_started_at = Sys.time()
benchmark_dll_path = loaded_edi_dll_path()
benchmark_dll_sha256 = sha256_file(benchmark_dll_path)
benchmark_namespace_path = loaded_edi_namespace_path()
benchmark_r_layer_sha256 = edi_r_layer_sha256(benchmark_namespace_path)
benchmark_git_start = read_git_state()
benchmark_host_start = read_host_state()
benchmark_environment_names = c("EDI_BENCH_SOURCE", "R_LIBS", "R_LIBS_USER", "OMP_NUM_THREADS",
  "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "BLAS_NUM_THREADS")
benchmark_environment = Sys.getenv(benchmark_environment_names, unset = "<unset>")
names(benchmark_environment) = benchmark_environment_names

set.seed(6001L)
X = data.frame(
  x1 = factor(sample(letters[1:3], n, TRUE), levels = letters[1:3]),
  x2 = factor(sample(LETTERS[1:4], n, TRUE), levels = LETTERS[1:4]),
  x3 = factor(sample(c("low", "high"), n, TRUE), levels = c("low", "high")),
  x4 = factor(sample(c("north", "south", "east"), n, TRUE), levels = c("north", "south", "east"))
)

new_design = function() DesignSeqOneByOnePocockSimon$new(
  strata_cols = names(X), response_type = "continuous", n = n, seed = 6002L
)
advance_to = function(d, last) {
  if (last > 0L) for (i in seq_len(last)) d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
  d
}
elapsed_ms = function(expr, calls) unname(system.time(force(expr))[["elapsed"]]) * 1000 / calls

rows = lapply(checkpoints, function(t) {
  samples = vapply(seq_len(repeats), function(rep_i) {
    designs = lapply(seq_len(batch), function(i) advance_to(new_design(), t - 1L))
    elapsed_ms(lapply(designs, function(d) d$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])), batch)
  }, numeric(1))
  data.frame(t = t, median_ms = median(samples), min_ms = min(samples), max_ms = max(samples))
})
results = do.call(rbind, rows)

whole_samples = vapply(seq_len(repeats), function(rep_i) elapsed_ms(replicate(batch, {
  d = new_design()
  for (i in seq_len(n)) d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
}, simplify = FALSE), batch), numeric(1))

print(results, row.names = FALSE, digits = 4)
cat(sprintf("whole_sequence_median_ms %.4f\n", median(whole_samples)))
if (length(args) >= 4L) {
  utils::write.csv(results, output_csv, row.names = FALSE)
  benchmark_git_end = read_git_state()
  benchmark_host_end = read_host_state()
  checkout_head = tryCatch(system2("git", "rev-parse HEAD", stdout = TRUE, stderr = FALSE), error = function(e) "<unavailable>")
  if (!length(checkout_head)) checkout_head = "<unavailable>"
  provenance = c(
    paste("started:", format(benchmark_started_at, tz = "UTC", usetz = TRUE)),
    paste("finished:", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    paste("parameters: n=", n, " batch=", batch, " repeats=", repeats, " covariate_seed=6001 assignment_seed=6002", sep = ""),
    paste("EDI version:", as.character(utils::packageVersion("EDI"))),
    paste("EDI library:", find.package("EDI")),
    paste("EDI namespace path:", benchmark_namespace_path),
    paste("EDI R-layer SHA-256:", benchmark_r_layer_sha256),
    paste("EDI native DLL:", benchmark_dll_path),
    paste("EDI native DLL SHA-256:", benchmark_dll_sha256),
    paste("checkout HEAD:", checkout_head[[1L]]),
    paste("checkout worktree status at start (porcelain):", benchmark_git_start$status),
    paste("checkout tracked diff at start SHA-256:", benchmark_git_start$tracked_diff_sha256),
    paste("checkout worktree status at finish (porcelain):", benchmark_git_end$status),
    paste("checkout tracked diff at finish SHA-256:", benchmark_git_end$tracked_diff_sha256),
    paste("R:", R.version.string),
    paste("platform:", R.version$platform),
    paste("host:", paste(Sys.info(), collapse = " | ")),
    paste("host load average at start:", benchmark_host_start$loadavg),
    paste("host load average at finish:", benchmark_host_end$loadavg),
    paste("process CPU affinity at start:", benchmark_host_start$cpu_affinity),
    paste("process CPU affinity at finish:", benchmark_host_end$cpu_affinity),
    paste("environment:", paste(names(benchmark_environment), benchmark_environment, sep = "=", collapse = "; ")),
    capture.output(utils::sessionInfo())
  )
  writeLines(provenance, paste0(output_csv, ".provenance.txt"))
}
