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
	saveRDS(list(commit = Sys.getenv("GITHUB_SHA"), covr_version = as.character(packageVersion("covr")),
		coverage_compiler_flags = coverage_compiler_flags,
		shard = jsonlite::fromJSON(shard_file)$shard,
		measured_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), coverage = coverage),
		file.path(artifact_dir, "coverage.rds"))
}
