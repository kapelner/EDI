#!/usr/bin/env Rscript

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (!length(script_path) || is.na(script_path)) script_path = "package_tests/smoke_test_analyze_comprehensive_suite.R"
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}

source(file.path(repo_root, "package_tests", "analyze_comprehensive_suite.R"))

expect_true = function(x, msg) {
	if (!isTRUE(x)) stop(msg, call. = FALSE)
}

out = analyze_comprehensive_suite()

expect_true(nrow(out$coverage) > 0L, "Unified coverage report is empty.")
required_cols = c(
	"target", "coverage_scope", "api_kind", "response_family", "design_family",
	"inference_family", "method_family", "runtime_tier", "required_coverage",
	"unified_coverage_status", "coverage_explanation",
	"has_imported_argument_coverage", "has_multidimensional_argument_coverage",
	"has_workflow_coverage", "has_internal_safety_net_coverage"
)
missing_cols = setdiff(required_cols, names(out$coverage))
expect_true(!length(missing_cols), paste("Unified coverage missing columns:", paste(missing_cols, collapse = ", ")))
expect_true(any(out$coverage$coverage_scope == "public_contract"), "Unified coverage has no public contract rows.")
expect_true(any(out$coverage$coverage_scope == "internal_safety_net"), "Unified coverage has no internal safety-net rows.")
expect_true(any(out$coverage$has_imported_argument_coverage), "Analyzer did not import argument-combination coverage.")
expect_true(any(out$coverage$has_workflow_coverage), "Analyzer did not report workflow coverage.")
expect_true(any(out$coverage$has_focused_public_testthat_coverage), "Analyzer did not report focused public testthat coverage.")
expect_true(any(out$coverage$has_internal_safety_net_coverage), "Analyzer did not report internal safety-net coverage.")
expect_true(all(nzchar(out$coverage$coverage_explanation)), "Every coverage row needs an explanation.")
expect_true(!any(out$coverage$unified_coverage_status == "uncovered" & out$coverage$has_focused_public_testthat_coverage), "Focused public testthat coverage must not be reported as uncovered.")
expect_true(all(out$uncovered$has_exemption | out$uncovered$unified_coverage_status == "uncovered"), "Uncovered report is malformed.")
expect_true(all(c("source", "tier", "target", "status", "reason") %in% names(out$unsupported_skipped)), "Unsupported/skipped report schema is incomplete.")
expect_true(all(c("source", "tier", "target", "status", "duration_time_sec") %in% names(out$slowest)), "Slowest-case report schema is incomplete.")
expect_true(file.exists(paths$coverage), "Unified coverage CSV was not written.")
expect_true(file.exists(paths$failures), "Unified failures CSV was not written.")
expect_true(file.exists(paths$uncovered), "Uncovered CSV was not written.")
expect_true(file.exists(paths$argument_only), "Argument-only CSV was not written.")
expect_true(file.exists(paths$workflow_only), "Workflow-only CSV was not written.")
expect_true(file.exists(paths$internal_gaps), "Internal gaps CSV was not written.")
expect_true(file.exists(paths$unsupported_skipped), "Unsupported/skipped CSV was not written.")
expect_true(file.exists(paths$slowest), "Slowest-case CSV was not written.")
expect_true(file.exists(paths$report), "HTML report was not written.")

message("comprehensive suite analyzer smoke test passed with ", nrow(out$coverage), " coverage rows")
