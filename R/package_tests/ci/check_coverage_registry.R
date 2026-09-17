#!/usr/bin/env Rscript
# Compare measured backlog fields, excluding timestamps/commit provenance which
# necessarily change on each run. Publish the candidate; never edit the checkout.
args = commandArgs(TRUE)
if (length(args) != 3L) stop("Usage: check_coverage_registry.R REPORT TRACKED_CSV OUTPUT_DIR")
source("R/package_tests/coverage_gap_registry.R")
dir.create(args[[3L]], recursive = TRUE, showWarnings = FALSE)
candidate = file.path(args[[3L]], "coverage_gap_registry.csv")
if (!file.copy(args[[2L]], candidate, overwrite = TRUE)) stop("Could not seed candidate registry")
new = main(c(args[[1L]], candidate))
old = read.csv(args[[2L]], stringsAsFactors = FALSE, na.strings = c("", "NA"))
fields = c("file", "coverage_percent", "covered_lines", "coverable_lines", "weighted_opportunity", "category", "owning_todo", "status", "notes")
canonical = function(x) {
	x = x[order(x$file), fields, drop = FALSE]
	for (column in c("coverage_percent", "covered_lines", "coverable_lines", "weighted_opportunity")) {
		x[[column]] = suppressWarnings(as.numeric(x[[column]]))
	}
	for (column in setdiff(fields, c("coverage_percent", "covered_lines", "coverable_lines", "weighted_opportunity"))) {
		x[[column]] = as.character(x[[column]])
		x[[column]][is.na(x[[column]])] = ""
	}
	row.names(x) = NULL
	x
}
changed = !isTRUE(all.equal(canonical(old), canonical(new), check.attributes = FALSE))
report = c("Coverage gap registry drift check", "", if (changed)
	"Measured backlog differs from the tracked registry. Review the candidate CSV artifact and commit its updated measurements/triage."
	else "Measured backlog matches the tracked registry (measurement provenance excluded).",
	paste("Tracked rows:", nrow(old), "Candidate rows:", nrow(new)))
writeLines(report, file.path(args[[3L]], "coverage-registry-drift.txt"))
summary = Sys.getenv("GITHUB_STEP_SUMMARY")
if (nzchar(summary)) cat(paste(report, collapse = "\n"), "\n", file = summary, append = TRUE)
if (changed) message("::warning::Coverage gap registry drift detected; review coverage-registry artifact.")
