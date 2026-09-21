#!/usr/bin/env Rscript
# Merges per-shard coverage.rds reports at line level after normalizing file paths.
# Local shards build in private copies (/tmp/.../shard-N/R/EDI/...), so covr records some files
# under those absolute paths; covr's own merge then treats each shard's copy as a different file.
# Output rows are (filename, line, value) with repo-relative names, which is the CSV shape
# coverage_gap_registry.R reads.
suppressMessages(library(covr))
args = commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: merge_coverage_lines.R ARTIFACT_DIR OUTPUT_CSV")
files = list.files(args[[1]], pattern = "^coverage\\.rds$", recursive = TRUE, full.names = TRUE)
if (!length(files)) stop("No coverage.rds files under ", args[[1]])

normalize = function(path) {
	path = gsub("\\\\", "/", path)
	path = sub("^.*/shard-[0-9]+/", "", path)
	sub("^.*/R/EDI/", "R/EDI/", path)
}

per_shard = lapply(files, function(f) {
	report = readRDS(f)
	rows = covr::tally_coverage(report$coverage, by = "line")
	out = data.frame(filename = normalize(rows$filename), line = rows$line, value = rows$value)
	message(sprintf("%s: %d rows", basename(dirname(f)), nrow(out)))
	out
})
rows = do.call(rbind, per_shard)
merged = aggregate(value ~ filename + line, rows, max)
write.csv(merged, args[[2]], row.names = FALSE)

is_native = grepl("\\.(cpp|h|hpp)$", merged$filename)
pct = function(x) if (nrow(x)) round(100 * mean(x$value > 0), 2) else NA_real_
cat(sprintf("shards: %d | files: R %d, native %d | lines: R %d, native %d\n", length(files),
	length(unique(merged$filename[!is_native])), length(unique(merged$filename[is_native])),
	sum(!is_native), sum(is_native)))
cat(sprintf("coverage: overall %.2f%% | R %.2f%% | native %.2f%%\n", pct(merged), pct(merged[!is_native, ]), pct(merged[is_native, ])))
