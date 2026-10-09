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
checkpoints = unique(pmin(n, c(10L, 100L, 500L, 1000L)))

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
if (length(args) >= 4L) utils::write.csv(results, args[[4L]], row.names = FALSE)
