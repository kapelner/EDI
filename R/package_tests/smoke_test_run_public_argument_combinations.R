#!/usr/bin/env Rscript

# read.csv() calls in this file go through read_csv_fast(): fread-backed, same
# result as read.csv (R/package_tests/read_csv_fast.R), loaded from the checkout.
if (!exists("read_csv_fast", mode = "function")) local({
	script = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
	for (d in c(getwd(), if (!is.na(script)) dirname(script))) {
		top = tryCatch(suppressWarnings(system2("git", c("-C", shQuote(d), "rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE)), error = function(e) character())
		helper = if (length(top)) file.path(top[1], "R", "package_tests", "read_csv_fast.R") else ""
		if (nzchar(helper) && file.exists(helper)) { sys.source(helper, envir = parent.env(environment())); break }
	}
	if (!exists("read_csv_fast", mode = "function")) stop("read_csv_fast.R not found: run from inside the EDI git checkout.", call. = FALSE)
})

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (!length(script_path) || is.na(script_path)) script_path = "package_tests/smoke_test_run_public_argument_combinations.R"
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}

source(file.path(repo_root, "package_tests", "generate_public_argument_combinations.R"))
source(file.path(repo_root, "package_tests", "run_public_argument_combinations.R"))

expect_true = function(x, msg) {
	if (!isTRUE(x)) stop(msg, call. = FALSE)
}

tmp_dir = file.path(tempdir(), paste0("public_arg_runner_smoke_", Sys.getpid()))
dir.create(tmp_dir, showWarnings = FALSE)
cases = generate_public_argument_combinations(
	tier = "smoke",
	target_filter = "^InferenceAllSimpleAverageDiff::compute_bootstrap_confidence_interval$|^DesignFixedBernoulli::add_all_subject_responses$",
	fixture_ids = c("fixed_bernoulli_continuous_smoke", "fixed_bernoulli_survival_censored_smoke")
)
cases_file = file.path(tmp_dir, "cases.csv")
results_file = file.path(tmp_dir, "results.csv")
failures_file = file.path(tmp_dir, "failures.csv")
write.csv(cases, cases_file, row.names = FALSE)

results = run_public_argument_combinations(
	tier = "smoke",
	timeout_sec = 10,
	cases_file = cases_file,
	results_file = results_file,
	failures_file = failures_file
)

required_cols = c(
	"case_id", "api_kind", "class_name", "function_name", "method_name",
	"fixture_id", "argument_signature", "tier", "status", "duration_time_sec",
	"warning_message", "message_text", "output_type", "output_shape",
	"invariant_status", "error_message", "output_outcome", "na_reason"
)
expect_true(all(required_cols %in% names(results)), "Runner results are missing required schema columns.")
expect_true(nrow(results) == nrow(cases), "Runner did not write one result row per selected case.")
expect_true(any(results$status == "ok"), "Runner did not execute any valid case successfully.")
expect_true(any(results$status == "skipped_slow"), "Runner did not preserve skipped_slow cases.")
expect_true(!any(results$status == "error"), "Runner produced unexpected errors in smoke test.")
expect_true(file.exists(results_file), "Results CSV was not written.")
expect_true(file.exists(failures_file), "Failures CSV was not written.")

persisted_before_resume = read_csv_fast(results_file, stringsAsFactors = FALSE)
results_again = run_public_argument_combinations(
	tier = "smoke",
	timeout_sec = 10,
	cases_file = cases_file,
	results_file = results_file,
	failures_file = failures_file
)
persisted_after_resume = read_csv_fast(results_file, stringsAsFactors = FALSE)
expect_true(identical(persisted_before_resume, persisted_after_resume), "Runner resume behavior is not deterministic by case_id.")
expect_true(identical(persisted_after_resume$case_id, results_again$case_id), "Runner resume returned different case IDs.")

expect_true(all(results$output_outcome[results$status == "ok"] %in% c("finite", "warned_na", "recorded_na", "silent_na", "nonfinite", "non_numeric")), "ok cases carry an error outcome.")
expect_true(all(results$output_outcome[results$status == "skipped_slow"] == "not_run"), "Constraint-rejected cases are not marked not_run.")

# output_outcome vocabulary (v1.0.7-TODO-41): a silent NA is its own outcome, apart from a warned one.
expect_true(identical(classify_output_outcome(list(status = "ok", result = c(1, 2), warning_message = "")), "finite"), "Finite output misclassified.")
expect_true(identical(classify_output_outcome(list(status = "ok", result = c(NA_real_, NA_real_), warning_message = "")), "silent_na"), "Silent NA misclassified.")
expect_true(identical(classify_output_outcome(list(status = "ok", result = NA_real_, warning_message = "not estimable")), "warned_na"), "Warned NA misclassified.")
expect_true(identical(classify_output_outcome(list(status = "error", error_message = "missing value where TRUE/FALSE needed")), "unclear_error"), "Internal R error not marked unclear.")
expect_true(identical(classify_output_outcome(list(status = "error", error_message = "B must be at least 10.")), "clear_error"), "EDI's own error marked unclear.")

# Resuming over a results file written before output_outcome existed keeps working.
legacy = read_csv_fast(results_file, stringsAsFactors = FALSE)
legacy$output_outcome = NULL
legacy = legacy[-1L, , drop = FALSE]
write.csv(legacy, results_file, row.names = FALSE)
results_legacy = run_public_argument_combinations(tier = "smoke", timeout_sec = 10, cases_file = cases_file, results_file = results_file, failures_file = failures_file)
expect_true(nrow(results_legacy) == nrow(cases) && "output_outcome" %in% names(results_legacy), "Resume over a pre-output_outcome results file failed.")

message("public argument combination runner smoke test passed with ", nrow(results), " results")
