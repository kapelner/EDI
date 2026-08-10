#!/usr/bin/env Rscript

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (!length(script_path) || is.na(script_path)) script_path = "package_tests/smoke_test_comprehensive_suite_internal_surfaces.R"
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}
repo_path = function(...) file.path(repo_root, ...)

expect_true = function(x, msg) {
	if (!isTRUE(x)) stop(msg, call. = FALSE)
}

out = tempfile(fileext = ".csv")
script = repo_path("package_tests", "comprehensive_suite_internal_surfaces.R")
status = system2("Rscript", c(script, out))
expect_true(identical(status, 0L), "Internal surface registry runner failed.")
expect_true(file.exists(out), "Internal surface registry CSV was not written.")

surfaces = read.csv(out, stringsAsFactors = FALSE)
audit = read.csv(repo_path("package_tests", "comprehensive_suite_baseline_audit.csv"), stringsAsFactors = FALSE)
registry = read.csv(repo_path("package_tests", "comprehensive_suite_registry.csv"), stringsAsFactors = FALSE)

required_cols = c(
	"internal_symbol", "normalized_symbol", "surface_category", "coverage_scope",
	"source_runner", "required_coverage", "runtime_tier", "priority_score",
	"test_fan_in", "occurrence_count", "source_reference_count",
	"numerical_risk_score", "argument_complexity_score", "historical_failure_score",
	"direct_testthat_files", "registry_targets", "source_files", "public_entrypoints",
	"public_link_status", "classification_reason", "rationale"
)
missing_cols = setdiff(required_cols, names(surfaces))
expect_true(!length(missing_cols), paste("Missing internal surface columns:", paste(missing_cols, collapse = ", ")))
expect_true(nrow(surfaces) > 0L, "Expected at least one internal surface row.")
expect_true(all(surfaces$coverage_scope == "internal_safety_net"), "Internal surface rows must be reported separately as internal_safety_net.")
expect_true(all(surfaces$source_runner == "internal_safety_net"), "Internal surface rows must use source_runner=internal_safety_net.")
expect_true(all(nzchar(surfaces$rationale)), "Every internal surface needs a rationale.")
expect_true(all(nzchar(surfaces$classification_reason)), "Every internal surface needs a classification reason.")
expect_true(all(surfaces$priority_score > 0L), "Every internal surface must receive a positive priority score.")

required_categories = c(
	"validator_or_canonicalizer", "shared_resampling_helper",
	"model_matrix_or_data_shaping", "numerical_kernel", "registry_or_capability"
)
missing_categories = setdiff(required_categories, unique(surfaces$surface_category))
expect_true(!length(missing_categories), paste("Missing internal surface categories:", paste(missing_categories, collapse = ", ")))

internal_audit = audit[audit$row_type == "testthat_internal", , drop = FALSE]
internal_registry = registry[registry$coverage_scope == "internal_safety_net", , drop = FALSE]
missing_registry = setdiff(unique(internal_audit$target), unique(internal_registry$target))
expect_true(!length(missing_registry), paste("Internal audit rows missing registry rows:", paste(missing_registry, collapse = ", ")))

covered_registry = unique(unlist(strsplit(surfaces$registry_targets, ";", fixed = TRUE), use.names = FALSE))
missing_surface = setdiff(unique(internal_audit$target), covered_registry)
expect_true(!length(missing_surface), paste("Internal audit rows missing rationale-bearing surface rows:", paste(missing_surface, collapse = ", ")))

expect_true(any(surfaces$test_fan_in > 1L | surfaces$source_reference_count > 1L | surfaces$numerical_risk_score >= 3L), "Expected at least one high-fan-in or high-risk internal safety net.")
expect_true(any(surfaces$public_link_status == "linked_to_source_files"), "Expected at least one internal surface linked to source files.")

message("comprehensive_suite_internal_surfaces smoke test passed with ", nrow(surfaces), " rows")
