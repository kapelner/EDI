#!/usr/bin/env Rscript
args = commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) stop("Usage: run_shard.R ROOT SHARD_JSON TIER ARTIFACT_DIR")
root = normalizePath(args[[1]], mustWork = TRUE)
shard_file = normalizePath(args[[2]], mustWork = TRUE)
tier = match.arg(args[[3]], c("correctness", "coverage"))
dir.create(args[[4]], recursive = TRUE, showWarnings = FALSE)
artifact_dir = normalizePath(args[[4]], mustWork = TRUE)
timing_file = file.path(artifact_dir, "timings.csv")
runner = file.path(root, "R/package_tests/ci/run_selected_tests.R")
if (tier == "correctness") {
	# Preserve the bulk runner's access to internal functions. CI installation
	# produces the checkout's shared library; this load must never rebuild it.
	suppressMessages(pkgload::load_all(file.path(root, "R/EDI"), compile = FALSE, quiet = TRUE))
	source(runner)
	run_selected_tests(root, shard_file, tier, timing_file)
} else {
	source(file.path(root, "R/package_tests/ci/configure_coverage_compiler.R"))
	coverage_compiler_flags = configure_coverage_compiler()
	# Only explicit code is run: package tests are inventoried alongside bulk tests,
	# so every file runs exactly once across this matrix, with the same instrumentation.
	code = sprintf("library(EDI); source(%s); run_selected_tests(%s, %s, 'coverage', %s)",
		deparse(runner), deparse(root), deparse(shard_file), deparse(timing_file))
	coverage = covr::package_coverage(file.path(root, "R/EDI"), type = "none",
		code = code, relative_path = root, quiet = FALSE)
	provenance = list(commit = Sys.getenv("GITHUB_SHA"), covr_version = as.character(packageVersion("covr")),
		coverage_compiler_flags = coverage_compiler_flags,
		shard = jsonlite::fromJSON(shard_file)$shard,
		measured_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
	saveRDS(c(provenance, list(coverage = coverage)), file.path(artifact_dir, "coverage.rds"))
	# Compact sidecar the merge job actually sums over (merge_coverage.R). The
	# full covr object above is ~55 MB compressed and ~1.6 GB of R heap once
	# deserialized (56k srcref-bearing elements), so the merge job cannot hold
	# 100 of them; it reads ONE full object as the skeleton and adds up these
	# per-shard count vectors instead. Keys are the covr element names made
	# unique per occurrence: gcov reports a header line once per translation
	# unit that includes it, so ~9.6k names are duplicated within one shard,
	# and covr's own merge_coverage() (x[[name]] = first match) silently
	# mis-sums those. Per-line totals downstream (tally_coverage by
	# filename+line) only depend on the group sum, so occurrence-indexed keys
	# give exact line totals regardless of within-group order.
	cov_elements = coverage[names(coverage) != "tests"]
	saveRDS(c(provenance, list(
		keys = make.unique(names(cov_elements), sep = "#dup"),
		values = unname(vapply(cov_elements, function(e) as.numeric(e$value), numeric(1)))
	)), file.path(artifact_dir, "coverage_values.rds"))
}
