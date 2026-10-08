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

set.seed(5901L)
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

new_ibcrd = function() DesignFixediBCRD$new(n = n, response_type = "continuous")

results = do.call(rbind, list(
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
      d = DesignFixedBlocking$new(
        n = n, response_type = "continuous", strata_cols = c("x1", "x2"),
        equal_block_sizes = FALSE
      )
      d$add_all_subjects_to_experiment(X_fac)
      d$assign_w_to_all_subjects()
    }, simplify = FALSE), batch)
  })
))

print(results, row.names = FALSE, digits = 4)
if (length(args) >= 4L) utils::write.csv(results, args[[4L]], row.names = FALSE)
