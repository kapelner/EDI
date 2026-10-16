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
benchmark_edi_dll_path = loaded_edi_dll_path()
benchmark_edi_dll_sha256 = sha256_file(benchmark_edi_dll_path)
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
    paste("EDI native DLL:", benchmark_edi_dll_path),
    paste("EDI native DLL SHA-256:", benchmark_edi_dll_sha256),
    paste("checkout HEAD:", checkout_commit[[1L]]),
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
