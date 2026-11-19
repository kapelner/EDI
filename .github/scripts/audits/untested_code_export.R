#!/usr/bin/env Rscript
# Export a merged covr report as one CSV row per measured expression, for the untested-code audit
# (.github/scripts/audits/untested_code.py), which reads it with the Python standard library.
#
#   Rscript untested_code_export.R MERGED_COVERAGE_RDS OUTPUT_CSV
#
# MERGED_COVERAGE_RDS is merge_coverage.R's output (list(coverage = <covr coverage>, commit, ...)) or
# a bare covr coverage object. Columns: file (repo-relative: R/EDI/R/..., R/EDI/src/...), first_line,
# last_line, value (execution count), fn (covr's function name; empty for C++), plus one leading
# comment line "# commit=<sha> measured_at=<time> covr=<version>".
# Base R only: the elements are read as plain lists, so neither covr nor EDI has to be installed.
# Used by the merge job of test-coverage-R.yaml (artifact `coverage-lines`) and, as a fallback, by
# the audit itself on a downloaded `coverage-merged` artifact.
args = commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: untested_code_export.R MERGED_COVERAGE_RDS OUTPUT_CSV")
x = readRDS(args[[1]])
cov = if (!is.null(x$coverage)) x$coverage else x
meta = if (!is.null(x$coverage)) x else list()
cov = cov[names(cov) != "tests"]

repo_path = function(f, native) {
	f = gsub("\\\\", "/", f)
	f = sub("^.*/R/EDI/", "R/EDI/", f)
	if (startsWith(f, "R/EDI/")) return(f)
	f = sub("^\\./", "", f)
	if (startsWith(f, "R/") || startsWith(f, "src/")) return(paste0("R/EDI/", f))
	paste0(if (native) "R/EDI/src/" else "R/EDI/R/", f)
}

n = length(cov)
file = character(n); first = integer(n); last = integer(n); value = numeric(n); fn = character(n)
for (i in seq_len(n)) {
	e = cov[[i]]
	s = e$srcref
	sf = attr(s, "srcfile")
	f = if (is.environment(sf)) sf$filename else NA_character_
	file[i] = if (is.na(f)) NA_character_ else repo_path(f, grepl("\\.(cpp|cc|c|h|hpp)$", f))
	first[i] = as.integer(s[[1]])
	last[i] = as.integer(s[[3]])
	value[i] = as.numeric(e$value)
	fn[i] = if (length(e$functions)) as.character(e$functions[[1]]) else ""
}
keep = !is.na(file)
out = data.frame(file = file[keep], first_line = first[keep], last_line = last[keep], value = value[keep],
	fn = ifelse(is.na(fn[keep]), "", fn[keep]), stringsAsFactors = FALSE)
# gcov reports a header line once per translation unit that includes it: sum those duplicates (the
# merge job's convention), so each (file, span, fn) appears once.
out = aggregate(value ~ file + first_line + last_line + fn, out, sum)
out = out[order(out$file, out$first_line, out$last_line), ]
con = file(args[[2]], "w")
writeLines(sprintf("# commit=%s measured_at=%s covr=%s", if (is.null(meta$commit)) "" else meta$commit,
	if (is.null(meta$measured_at)) "" else meta$measured_at,
	if (is.null(meta$covr_version)) "" else meta$covr_version), con)
write.csv(out, con, row.names = FALSE)
close(con)
cat(sprintf("%d expressions in %d files written to %s\n", nrow(out), length(unique(out$file)), args[[2]]))
