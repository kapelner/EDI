#!/usr/bin/env Rscript

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (!length(script_path) || is.na(script_path)) script_path = "package_tests/smoke_test_comprehensive_suite_quality_gates.R"
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}

source(file.path(repo_root, "package_tests", "check_comprehensive_suite_quality_gates.R"))

expect_true = function(x, msg) {
	if (!isTRUE(x)) stop(msg, call. = FALSE)
}

out = check_comprehensive_suite_quality_gates("report")

expect_true(nrow(out$report) > 0L, "Comprehensive quality gate report is empty.")
expect_true(all(c("gate", "severity", "tier", "target", "arg", "value_expr", "detail", "exempted") %in% names(out$report)), "Gate report schema is incomplete.")
expect_true(all(c("mode", "total_rows", "active_hard_rows", "ci_should_fail") %in% names(out$summary)), "Gate summary schema is incomplete.")
expect_true(any(out$report$gate == "multi_arg_without_argument_dependency_coverage"), "Expected multi-argument ratchet gate rows.")
expect_true(!any(out$report$gate == "r6_constructor_without_coverage" & out$report$severity == "hard"), "R6 constructor coverage gate must not produce active hard rows in report mode.")
expect_true(!any(out$report$gate == "high_priority_public_api_without_workflow" & out$report$severity == "hard"), "High-priority workflow gate must not produce active hard rows in report mode.")
expect_true(!any(out$report$gate == "internal_safety_net_without_rationale"), "Internal safety-net rationale gate should be clean.")
expect_true(!any(out$report$gate == "unknown_skip_or_support_status"), "Skip/support status gate should be clean.")
expect_true(!any(out$report$gate == "expired_exemption"), "Expired exemption gate should be clean.")
expect_true(!isTRUE(out$summary$ci_should_fail[1L]), "Report-mode comprehensive gates should not fail current artifacts.")
expect_true(file.exists(gate_paths$report), "Comprehensive quality gate CSV was not written.")
expect_true(file.exists(gate_paths$summary), "Comprehensive quality gate summary CSV was not written.")

message("comprehensive suite quality gates smoke test passed with ", nrow(out$report), " rows")
