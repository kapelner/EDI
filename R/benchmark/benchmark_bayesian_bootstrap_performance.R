# Reproducible Bayesian-bootstrap comparison harness (release v1.0.5 TODO-57).
#
# Runs the same installed-package benchmark protocol at B = 1000 and 5000,
# first with the shipped dispatch blocklist and then with that blocklist
# overridden. The child benchmark compares EDI at one and three cores against
# bayesboot at the same core counts. It never builds or loads the checkout.
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
print(combined, row.names = FALSE, digits = 3)
if (!is.null(output)) utils::write.csv(combined, output, row.names = FALSE)
