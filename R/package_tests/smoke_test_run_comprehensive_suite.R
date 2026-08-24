#!/usr/bin/env Rscript

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (!length(script_path) || is.na(script_path)) script_path = "package_tests/smoke_test_run_comprehensive_suite.R"
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}
repo_path = function(...) file.path(repo_root, ...)

expect_true = function(x, msg) {
	if (!isTRUE(x)) stop(msg, call. = FALSE)
}

results_path = repo_path("package_tests", "comprehensive_suite_results.csv")
failures_path = repo_path("package_tests", "comprehensive_suite_failures.csv")
before_rows = if (file.exists(results_path)) nrow(read.csv(results_path, stringsAsFactors = FALSE)) else 0L

status = system2(
	"Rscript",
	c(repo_path("package_tests", "run_comprehensive_suite.R"), "smoke", "InferenceAllSimpleAverageDiff", "180", "--force")
)
expect_true(identical(status, 0L), "Unified comprehensive suite smoke runner failed.")
expect_true(file.exists(results_path), "Unified comprehensive suite results file was not written.")
expect_true(file.exists(failures_path), "Unified comprehensive suite failures file was not written.")

results = read.csv(results_path, stringsAsFactors = FALSE)
selected = results[results$tier == "smoke" & results$target_filter == "InferenceAllSimpleAverageDiff", , drop = FALSE]
required_cols = c(
	"case_id", "tier", "target_filter", "step", "runner", "status",
	"start_time", "end_time", "duration_time_sec", "output_file", "failure_file",
	"rows_written", "failures_written", "resumed", "command", "error_message"
)
missing_cols = setdiff(required_cols, names(results))
expect_true(!length(missing_cols), paste("Unified results missing columns:", paste(missing_cols, collapse = ", ")))
required_steps = c("dependency_gate", "argument_combinations", "comprehensive_harness", "public_workflow_coverage", "internal_safety_nets")
missing_steps = setdiff(required_steps, selected$step)
expect_true(!length(missing_steps), paste("Unified runner missing steps:", paste(missing_steps, collapse = ", ")))
expect_true(all(selected$status == "ok"), "Unified smoke run has non-ok step rows.")
expect_true(any(selected$step == "argument_combinations" & selected$rows_written > 0L), "Argument-combination step did not report rows.")
expect_true(any(selected$step == "public_workflow_coverage" & selected$rows_written > 0L), "Workflow coverage step did not report rows.")
expect_true(any(selected$step == "internal_safety_nets" & selected$rows_written > 0L), "Internal safety-net step did not report rows.")
expect_true(nrow(results) >= before_rows, "Unified results unexpectedly lost prior rows.")

failures = read.csv(failures_path, stringsAsFactors = FALSE)
selected_failures = failures[failures$tier == "smoke" & failures$target_filter == "InferenceAllSimpleAverageDiff", , drop = FALSE]
expect_true(!nrow(selected_failures), "Unified smoke run wrote failure rows.")

message("run_comprehensive_suite smoke test passed with ", nrow(selected), " selected step rows")
