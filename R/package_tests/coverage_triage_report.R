#!/usr/bin/env Rscript

# TODO-1 report processing only: never builds or runs the package.
# Run from the repository root. Categories require code/dispatch evidence;
# an uncovered file is not evidence that its code is dead.
coverage_triage_report = function(input, output_dir,
	registry_path = "R/package_tests/coverage_gap_registry.csv", threshold = 80,
	generator_path = "R/package_tests/coverage_gap_registry.R") {
	if (length(threshold) != 1L || !is.finite(threshold) || threshold <= 0 || threshold > 100) {
		stop("threshold must be in (0, 100].", call. = FALSE)
	}
	if (!grepl("\\.rds$", input, ignore.case = TRUE)) {
		stop("Use a provenance-bearing full coverage RDS report.", call. = FALSE)
	}
	report = readRDS(input)
	if (!is.list(report) || inherits(report, "coverage") || !"coverage" %in% names(report)) {
		stop("Report must wrap coverage with commit and measured_at metadata.", call. = FALSE)
	}
	for (field in c("commit", "measured_at")) {
		value = report[[field]]
		if (length(value) != 1L || is.na(value) || !nzchar(value)) {
			stop("Report needs nonblank ", field, " provenance.", call. = FALSE)
		}
	}
	if (!is.null(report$tests_complete) && !isTRUE(report$tests_complete)) {
		stop("Incomplete test inventory: do not promote partial coverage.", call. = FALSE)
	}
	generator = new.env(parent = globalenv())
	sys.source(generator_path, envir = generator)
	rows = generator$read_coverage_rows(input)
	if (!any(grepl("^R/EDI/R/", rows$file)) || !any(grepl("^R/EDI/src/", rows$file))) {
		stop("Full coverage must include both R and native source lines.", call. = FALSE)
	}
	per_file = generator$summarize_coverage(rows)
	per_file$measured_commit = report$commit
	per_file$measured_at = report$measured_at
	prior = if (file.exists(registry_path)) {
		read.csv(registry_path, stringsAsFactors = FALSE, na.strings = character())
	} else generator$empty_registry()
	registry = generator$merge_triage(per_file, prior, threshold,
		measured_commit = report$commit, measured_at = report$measured_at)
	generator$validate_registry(registry)
	# Historical rows absent from this report are not newly measured gaps.
	gaps = registry[registry$file %in% per_file$file & registry$coverage_percent < threshold, , drop = FALSE]
	unreviewed = gaps[gaps$category == "unclassified" | gaps$status == "triage_needed", , drop = FALSE]
	missing = prior[!prior$file %in% per_file$file, , drop = FALSE]
	covered = sum(per_file$covered_lines)
	coverable = sum(per_file$coverable_lines)
	text = c("# Coverage triage (TODO-1)", "",
		paste("Measured commit:", report$commit), paste("Measured at:", report$measured_at),
		sprintf("Line coverage: %.2f%% (%d/%d unique source lines).", 100 * covered / coverable, covered, coverable),
		sprintf("Measured files: %d; below %.1f%%: %d; requiring category review: %d.", nrow(per_file), threshold, nrow(gaps), nrow(unreviewed)),
		sprintf("Historical registry files absent from measurement: %d (not treated as addressed).", nrow(missing)), "",
		"Categories: straightforward_test (a), dispatch_threshold (b), dead_or_unreachable (c), diagnostic_smoke (d).",
		"Review actual callers/dispatch conditions before assigning a category. Do not infer dead code from zero hits.",
		"Historical classifications are retained, not independently revalidated by this report.",
		"The caller must verify the report covers the intended full suite; R/native presence alone does not prove completeness.",
		"For dirty snapshots, retain the producer's checkout patch and source hashes alongside this report.", "",
		"Outputs: full per-file measurements, measured gaps, manual-review queue, missing historical files, and registry candidate.",
		"The tracked registry is not overwritten. TODO-1 remains open until the full measurement and every gap's classification are reviewed.")
	dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
	write.csv(per_file, file.path(output_dir, "coverage-per-file.csv"), row.names = FALSE, na = "")
	write.csv(gaps, file.path(output_dir, "coverage-gaps.csv"), row.names = FALSE, na = "")
	write.csv(unreviewed, file.path(output_dir, "coverage-triage-needed.csv"), row.names = FALSE, na = "")
	write.csv(missing, file.path(output_dir, "coverage-unmeasured-history.csv"), row.names = FALSE, na = "")
	write.csv(registry, file.path(output_dir, "coverage-registry-candidate.csv"), row.names = FALSE, na = "")
	writeLines(text, file.path(output_dir, "SUMMARY.md"))
	message("Measured gaps: ", nrow(gaps), "; requiring manual triage: ", nrow(unreviewed))
	invisible(list(per_file = per_file, gaps = gaps, unreviewed = unreviewed, missing = missing, registry = registry))
}

coverage_triage_main = function(args = commandArgs(TRUE)) {
	if (length(args) < 2L || length(args) > 4L) {
		stop("Usage: Rscript R/package_tests/coverage_triage_report.R <full-report.rds> <output-dir> [registry.csv] [threshold=80]", call. = FALSE)
	}
	coverage_triage_report(args[[1L]], args[[2L]],
		registry_path = if (length(args) >= 3L) args[[3L]] else "R/package_tests/coverage_gap_registry.csv",
		threshold = if (length(args) >= 4L) suppressWarnings(as.numeric(args[[4L]])) else 80)
}

if (sys.nframe() == 0L) coverage_triage_main()
