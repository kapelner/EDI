#!/usr/bin/env Rscript

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (!length(script_path) || is.na(script_path)) script_path = "package_tests/smoke_test_public_workflow_coverage.R"
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}
repo_path = function(...) file.path(repo_root, ...)

expect_true = function(x, msg) {
	if (!isTRUE(x)) stop(msg, call. = FALSE)
}

out = tempfile(fileext = ".csv")
script = repo_path("package_tests", "run_public_workflow_coverage.R")
status = system2("Rscript", c(script, "smoke", out))
expect_true(identical(status, 0L), "Public workflow coverage runner failed.")
expect_true(file.exists(out), "Public workflow coverage CSV was not written.")

coverage = read.csv(out, stringsAsFactors = FALSE)
inventory = read.csv(repo_path("package_tests", "public_api_inventory.csv"), stringsAsFactors = FALSE)
r6_classes = sort(unique(inventory$export_name[inventory$api_kind == "r6_class"]))

required_cols = c(
	"case_id", "target", "api_kind", "coverage_scope", "runner", "workflow_kind",
	"status", "method_family", "argument_coverage_kind", "runtime_tier",
	"github_commit_id", "method_name", "operation_kind", "capability", "support_status",
	"exemption_type", "exemption_reason", "error_message"
)
missing_cols = setdiff(required_cols, names(coverage))
expect_true(!length(missing_cols), paste("Missing coverage columns:", paste(missing_cols, collapse = ", ")))
expect_true(!any(coverage$status == "error"), "Public workflow coverage contains error rows.")

missing_r6 = setdiff(r6_classes, unique(coverage$target[coverage$api_kind == "r6_class"]))
expect_true(!length(missing_r6), paste("Missing exported R6 classes:", paste(missing_r6, collapse = ", ")))

design_rows = coverage[coverage$workflow_kind == "design_complete_workflow", , drop = FALSE]
expect_true(nrow(design_rows) >= 20L, "Expected design workflow rows for exported design classes.")
expect_true(all(design_rows$status %in% c("ok", "exempted")), "Design workflow rows must be ok or explicitly exempted.")

suite_rows = coverage[coverage$target == "InferenceSuite" & coverage$workflow_kind == "inference_suite_discovery_and_params", , drop = FALSE]
expect_true(nrow(suite_rows) == 1L && identical(suite_rows$status[1], "ok"), "InferenceSuite workflow coverage is missing or not ok.")

sim_rows = coverage[coverage$target == "SimulationFramework" & coverage$workflow_kind == "simulation_framework_smoke", , drop = FALSE]
expect_true(nrow(sim_rows) == 1L && identical(sim_rows$status[1], "ok"), "SimulationFramework workflow coverage is missing or not ok.")

report_rows = coverage[coverage$target == "SimulationFrameworkReport" & coverage$workflow_kind == "simulation_framework_report_smoke", , drop = FALSE]
expect_true(nrow(report_rows) == 1L && identical(report_rows$status[1], "ok"), "SimulationFrameworkReport workflow coverage is missing or not ok.")

function_rows = coverage[coverage$api_kind == "function" & coverage$workflow_kind == "exported_function_classification", , drop = FALSE]
expect_true(nrow(function_rows) > 0L, "Exported function classification rows are missing.")
expect_true(all(nzchar(function_rows$method_family)), "Exported function classification rows must include method_family.")

method_rows = coverage[coverage$workflow_kind == "method_family_workflow", , drop = FALSE]
expect_true(nrow(method_rows) > 0L, "Method-family workflow rows are missing.")
required_method_families = c(
	"estimate", "asymptotic_wald", "asymptotic_score", "asymptotic_lik_ratio",
	"asymptotic_gradient", "exact", "bootstrap", "bayesian_bootstrap",
	"parametric_bootstrap", "bartlett", "jackknife", "randomization",
	"randomization_bootstrap", "m_out_of_n_subsampling", "debug_distribution"
)
missing_method_families = setdiff(required_method_families, unique(method_rows$method_family))
expect_true(!length(missing_method_families), paste("Missing method-family rows:", paste(missing_method_families, collapse = ", ")))
expect_true(any(method_rows$operation_kind == "p_value" & method_rows$status == "ok"), "Expected at least one successful representative p-value method.")
expect_true(any(method_rows$operation_kind == "confidence_interval" & method_rows$status == "ok"), "Expected at least one successful representative confidence-interval method.")
expect_true(any(method_rows$operation_kind == "estimate" & method_rows$status == "ok"), "Expected at least one successful representative estimate method.")
expect_true(all(method_rows$status %in% c("ok", "unsupported", "nonestimable", "exempted")), "Method-family rows must be ok, unsupported, nonestimable, or explicitly exempted.")
expect_true(all(nzchar(method_rows$support_status)), "Method-family rows must include support_status.")
expect_true(all(nzchar(method_rows$argument_coverage_kind)), "Method-family rows must include argument_coverage_kind.")

message("public_workflow_coverage smoke test passed with ", nrow(coverage), " rows")
