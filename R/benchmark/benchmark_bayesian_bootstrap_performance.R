# Reproducible Bayesian-bootstrap comparison harness (release v1.0.5 TODO-57).
#
# Runs the same installed-package benchmark protocol at B = 1000 and 5000,
# first with the shipped dispatch blocklist and then with that blocklist
# overridden. The child benchmark compares EDI at one and the requested number
# of cores against bayesboot at the same core counts. It never builds or loads
# the checkout.
# The combined CSV also records the installed EDI DLL hash/path, package
# versions, source commit/worktree state and run parameters for provenance.
#
# Usage from the repository root:
#   Rscript R/benchmark/benchmark_bayesian_bootstrap_performance.R [n] [reps] [cores] [B-list] [output.csv]
#
# The default n/reps/cores are 500/3/3. Each configuration can be expensive;
# pass a CSV path to retain the combined measurements.

args = commandArgs(trailingOnly = TRUE)
n = if (length(args) >= 1L) as.integer(args[[1L]]) else 500L
reps = if (length(args) >= 2L) as.integer(args[[2L]]) else 3L
cores = if (length(args) >= 3L) as.integer(args[[3L]]) else 3L
if (length(args) >= 4L) {
  B_values = as.integer(strsplit(args[[4L]], ",", fixed = TRUE)[[1L]])
} else {
  B_values = c(1000L, 5000L)
}
output = if (length(args) >= 5L) args[[5L]] else NULL
stopifnot(is.finite(n), n >= 2L, is.finite(reps), reps >= 1L,
          is.finite(cores), cores >= 1L, length(B_values) > 0L,
          all(is.finite(B_values) & B_values >= 1L))

script_arg = grep("^--file=", commandArgs(), value = TRUE)
script_path = normalizePath(sub("^--file=", "", script_arg[[1L]]))
repo_root = normalizePath(file.path(dirname(script_path), "..", ".."))
benchmark = file.path(repo_root, "marketing_plans", "bb_bench2.R")
if (!file.exists(benchmark)) stop("Could not find marketing_plans/bb_bench2.R")
rscript = Sys.which("Rscript")
if (!nzchar(rscript)) stop("Rscript is not on PATH")

read_benchmark_worktree_state = function(repo_root, git_command = Sys.which("git")) {
  if (length(git_command) != 1L || is.na(git_command) || !nzchar(git_command)) {
    return(list(status = "<unavailable>", dirty = NA))
  }
  status = tryCatch(
    suppressWarnings(system2(git_command,
      c("-C", repo_root, "status", "--porcelain", "--untracked-files=no"),
      stdout = TRUE, stderr = FALSE)),
    error = function(e) NULL
  )
  status_code = if (is.null(status)) NA_integer_ else attr(status, "status")
  status_failed = is.null(status) ||
    (!is.null(status_code) && !identical(as.integer(status_code), 0L))
  if (status_failed) return(list(status = "<unavailable>", dirty = NA))
  if (!length(status)) return(list(status = "<clean>", dirty = FALSE))
  list(status = paste(status, collapse = ";"), dirty = TRUE)
}

csv_paths = character()
results = list()
for (B in B_values) {
  for (override in c(FALSE, TRUE)) {
    csv_path = tempfile(pattern = "edi-bb-bench-", fileext = ".csv")
    csv_paths = c(csv_paths, csv_path)
    env = c(
      paste0("EDI_BB_BENCH_N=", n),
      paste0("EDI_BB_BENCH_B=", B),
      paste0("EDI_BB_BENCH_REPS=", reps),
      paste0("EDI_BB_BENCH_CORES=", cores),
      paste0("EDI_BB_BENCH_OVERRIDE_BLOCKLIST=", as.integer(override))
    )
    status = system2(
      rscript,
      args = c(shQuote(benchmark), shQuote(csv_path)),
      env = env
    )
    if (!identical(status, 0L)) {
      unlink(csv_paths)
      stop("Benchmark child failed for B = ", B,
           ", blocklist override = ", override, " (status ", status, ")")
    }
    if (!file.exists(csv_path)) {
      unlink(csv_paths)
      stop("Benchmark child did not write its requested result CSV")
    }
    run = utils::read.csv(csv_path, stringsAsFactors = FALSE)
    run$blocklist_override = override
    results[[length(results) + 1L]] = run
  }
}

combined = do.call(rbind, results)
unlink(csv_paths)
source_commit = tryCatch(
  system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
  error = function(e) character()
)
if (!length(source_commit)) source_commit = NA_character_
source_state = read_benchmark_worktree_state(repo_root)
suppressPackageStartupMessages(library("EDI"))
edi_dll = getLoadedDLLs()[["EDI"]]
edi_dll_path = if (is.null(edi_dll)) NA_character_ else unname(edi_dll[["path"]])
edi_dll_path = if (!is.na(edi_dll_path) && file.exists(edi_dll_path)) normalizePath(edi_dll_path) else NA_character_
edi_dll_md5 = if (is.na(edi_dll_path)) NA_character_ else unname(tools::md5sum(edi_dll_path))
benchmark_packages = c("EDI", "bayesboot", "survival", "MASS", "betareg", "quantreg", "doParallel")
package_versions = vapply(benchmark_packages, function(pkg) {
  if (requireNamespace(pkg, quietly = TRUE)) as.character(utils::packageVersion(pkg)) else NA_character_
}, character(1L))
provenance = data.frame(
  measured_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  source_commit = source_commit[[1L]],
  source_worktree_dirty = source_state$dirty,
  source_worktree_status = source_state$status,
  installed_edi_version = as.character(utils::packageVersion("EDI")),
  installed_edi_path = normalizePath(find.package("EDI"), winslash = "/"),
  installed_edi_dll_path = edi_dll_path,
  installed_edi_dll_md5 = edi_dll_md5,
  benchmark_package_versions = paste(paste(names(package_versions), package_versions, sep = "="), collapse = ";"),
  R_version = R.version.string,
  platform = R.version$platform,
  host = Sys.info()[["nodename"]],
  requested_cores = cores,
  requested_B_values = paste(B_values, collapse = ","),
  seed = 2L, detected_cores = parallel::detectCores(),
  stringsAsFactors = FALSE
)
combined = cbind(combined, provenance[rep(1L, nrow(combined)), , drop = FALSE])
print(combined, row.names = FALSE, digits = 3)
if (!is.null(output)) utils::write.csv(combined, output, row.names = FALSE)
