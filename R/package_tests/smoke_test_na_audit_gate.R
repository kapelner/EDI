#!/usr/bin/env Rscript
# Unit checks for the NA audit gate (na_audit_gate.R), on synthetic inputs only: it writes
# nothing in the checkout. v1.0.6-TODO-54.

`%||%` = function(x, y) if (is.null(x)) y else x
script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "package_tests/smoke_test_na_audit_gate.R")
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) repo_root = normalizePath(getwd(), mustWork = TRUE)
source(file.path(repo_root, "package_tests", "na_audit_gate.R"))

expect_true = function(x, msg) if (!isTRUE(x)) stop(msg, call. = FALSE)
expect_equal = function(x, y, msg) if (!identical(x, y)) stop(msg, ": got ", paste(deparse(x), collapse = ""), call. = FALSE)

# --- TODO references and open-TODO parsing ------------------------------------------------
expect_equal(na_audit_todo_refs(c("v1.0.6-TODO-74", "see v1.1.0 TODO-189 and v1.0.6-TODO-9", "TODO-5", ""))[1:3],
	list("v1.0.6-TODO-74", c("v1.1.0-TODO-189", "v1.0.6-TODO-9"), character()), "TODO reference parsing")

plans = file.path(tempdir(), "na_audit_plans")
dir.create(plans, showWarnings = FALSE)
writeLines(c("- [ ] TODO-74 open bug", "- [x] TODO-75 fixed bug", "  - [ ] TODO-3 nested open", "- [x] TODO-8 closed here", "- [ ] TODO-8 but reopened"), file.path(plans, "release_v1_0_6.md"))
writeLines("- [ ] TODO-1 other release", file.path(plans, "release_v1_1_0.md"))
open_todos = na_audit_open_todos(plans)
expect_true(all(c("v1.0.6-TODO-74", "v1.0.6-TODO-3", "v1.0.6-TODO-8", "v1.1.0-TODO-1") %in% open_todos), "open TODOs not found")
expect_true(!"v1.0.6-TODO-75" %in% open_todos, "a closed TODO counted as open")

# --- Comprehensive row classification ------------------------------------------------------
kind = na_audit_classify_comprehensive(
	status = c("ok", "ok", "ok", "ok", "ok", "ok", "error", "ok", "ok"),
	error_message = c(
		"Invalid output detected (NA/NaN/Inf) in compute_estimate; warnings=none",
		"Invalid output detected (NA/NaN/Inf) in compute_estimate; warnings=edi_unsupported_procedure",
		"Invalid output detected (NA/NaN/Inf) in compute_estimate",
		"Explicitly non-estimable in compute_estimate; stage=se; reason=x",
		"",
		"",
		"boom",
		"Skipped due to timeout after 60 seconds",
		"Allowed missing output: ordinal asymptotic p-value not estimable"
	),
	result = c("", "", "", "", "0.3", "", "", "", ""),
	function_run = c(rep("compute_estimate", 8), "compute_asymp_two_sided_pval")
)
expect_equal(kind, c("silent", "warned", "unknown", "declared", "", "silent", "", "", "declared"), "comprehensive classification")
expect_equal(na_audit_classify_comprehensive("ok", "Invalid output detected (NA/NaN/Inf) in x; warnings=none", "", "summary"), "", "non-estimand functions are out of scope")
expect_equal(na_audit_warning_classes(c("a; warnings=edi_x,simpleWarning", "no suffix")), c("edi_x,simpleWarning", ""), "warning class extraction")

# --- Allowlist validation --------------------------------------------------------------------
allow = data.frame(
	scope = c("comprehensive", "comprehensive", "both", "both", "comprehensive", "bogus"),
	class_pattern = c("InferenceA", "InferenceB", "InferenceC", "InferenceD", "InferenceE", ""),
	function_pattern = c("compute_estimate", "compute_estimate", "compute_jackknife_.*", "compute_estimate", "compute_estimate", ""),
	context_pattern = c("", "", "", "", "", ""),
	kind = c("todo", "todo", "intentional", "intentional", "todo", "todo"),
	todo = c("v1.0.6-TODO-74", "v1.0.6-TODO-75", "", "", "TODO-74", "v1.0.6-TODO-74"),
	warning_class = c("", "", "edi_unsupported_procedure", "", "", ""),
	reason = c("open bug", "fixed bug", "documented stub", "no warning class", "bare TODO", "bad scope"),
	stringsAsFactors = FALSE
)
problems = na_audit_validate_allowlist(allow, open_todos)
expect_equal(sort(unique(problems$row)), c(2L, 4L, 5L, 6L), "allowlist problems")
expect_true(any(grepl("not an open TODO", problems$detail[problems$row == 2L])), "closed TODO must invalidate its row")

# --- Gate rows -------------------------------------------------------------------------------
cases = data.frame(
	class_name = c("InferenceA", "InferenceB", "InferenceC", "InferenceC", "InferenceZ", "InferenceZ", "InferenceZ", "InferenceY"),
	function_run = c("compute_estimate", "compute_estimate", "compute_jackknife_estimate", "compute_jackknife_estimate", "compute_estimate", "compute_wald_two_sided_pval", "compute_rand_two_sided_pval", "compute_estimate"),
	context = "response_type=continuous;design=Bernoulli",
	group = c("continuous", "continuous", "continuous", "count", "continuous", "continuous", "continuous", "continuous"),
	n_silent = c(3L, 2L, 0L, 1L, 4L, 0L, 0L, 0L),
	n_warned = c(0L, 0L, 5L, 0L, 0L, 2L, 0L, 0L),
	n_unknown = c(0L, 0L, 0L, 0L, 0L, 0L, 7L, 0L),
	n_declared = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 9L),
	warning_classes = c("", "", "edi_unsupported_procedure", "", "", "edi_other", "", ""),
	detail_unit = "Bernoulli",
	stringsAsFactors = FALSE
)
rows = na_audit_gate_rows(cases, allow, open_todos, scope = "comprehensive")
gate_of = function(target, group = "continuous") rows$gate[rows$target == target & rows$value_expr == group]
expect_equal(gate_of("InferenceA::compute_estimate"), "na_output_allowlisted_todo", "open-TODO row allowlists a silent NA")
expect_equal(gate_of("InferenceB::compute_estimate"), "silent_na_output", "a row citing a closed TODO must not allowlist")
expect_equal(gate_of("InferenceC::compute_jackknife_estimate"), "na_output_allowlisted_intentional", "intentional NA that warns is allowlisted")
expect_equal(gate_of("InferenceC::compute_jackknife_estimate", "count"), "silent_na_output", "intentional row must not accept an NA with no warning")
expect_true(grepl("but returned NA with no warning", rows$detail[rows$target == "InferenceC::compute_jackknife_estimate" & rows$value_expr == "count"]), "intentional-but-silent detail")
expect_equal(gate_of("InferenceZ::compute_estimate"), "silent_na_output", "unallowlisted silent NA fails")
expect_equal(gate_of("InferenceZ::compute_wald_two_sided_pval"), "warned_na_output_not_allowlisted", "warned NA without allowlist is reported")
expect_equal(gate_of("InferenceZ::compute_rand_two_sided_pval"), "na_output_warning_status_unknown", "legacy rows are unknown")
expect_equal(gate_of("InferenceY::compute_estimate"), "declared_nonestimable_na_output", "declared non-estimable is reported")
expect_true(all(rows$severity[rows$gate == "silent_na_output"] == "hard"), "silent NA must be hard")
expect_true(all(rows$severity[rows$gate == "na_output_warning_status_unknown"] == "hard_later"), "unknown status must be hard_later")
expect_true(all(rows$severity[rows$gate == "na_allowlist_invalid"] == "hard"), "invalid allowlist must be hard")
expect_equal(sum(rows$gate == "na_allowlist_invalid"), length(unique(problems$row)) + sum(duplicated(problems$row)), "one invalid row per problem")

# A class-wide intentional row only accepts rows whose warning classes were recorded.
generic = allow[3L, ]
generic$class_pattern = ".*"
hit = na_audit_match("comprehensive", c("InferenceQ", "InferenceQ", "InferenceQ"), rep("compute_jackknife_estimate", 3L), rep("", 3L), generic,
	warning_classes = c("edi_unsupported_procedure", "", "edi_other"))
expect_equal(hit, c(1L, NA_integer_, NA_integer_), "class-wide intentional row matching")

# --- Argument-combination results -------------------------------------------------------------
results = data.frame(
	case_id = paste0("c", 1:6), class_name = "InferenceA", function_name = "",
	method_name = c("compute_estimate", "compute_estimate", "compute_estimate", "compute_estimate", "summary", "compute_estimate"),
	fixture_id = c("f", "f", "f", "f", "f", "data_shape__fixed_bernoulli__continuous__fixed__equal__none__yes__null"),
	argument_signature = "<default>", status = c("ok", "ok", "ok", "ok", "ok", "ok"),
	output_outcome = c("silent_na", "recorded_na", "warned_na", "finite", "silent_na", "silent_na"),
	stringsAsFactors = FALSE
)
arg_cases = na_audit_cases_from_argument_results(results)
expect_equal(nrow(arg_cases), 4L, "argument-combination cases (finite and non-estimand rows dropped)")
expect_equal(arg_cases$n_silent, c(1L, 1L, 0L, 1L), "recorded_na counts as silent")
expect_equal(arg_cases$input_has_missing, c(FALSE, FALSE, FALSE, TRUE), "missing-covariate data-shape fixture detected")
arg_rows = na_audit_gate_rows(arg_cases, allow[0, ], character(), scope = "argument_combination")
expect_true("silent_na_output_missing_input" %in% arg_rows$gate, "missing-input silent NA gets its own gate")
expect_true(is.null(na_audit_cases_from_argument_results(results[, setdiff(names(results), "output_outcome")])), "results without output_outcome are not evaluable")

# --- The committed allowlist is valid against the real release plans ---------------------------
real_allow = na_audit_read_allowlist(file.path(repo_root, "package_tests", "na_audit_allowlist.csv"))
real_open = na_audit_open_todos(file.path(repo_root, "package_metadata", "future_release_plans"))
expect_true(nrow(real_allow) > 0L, "na_audit_allowlist.csv is empty")
bad = na_audit_validate_allowlist(real_allow, real_open)
expect_true(!nrow(bad), paste("na_audit_allowlist.csv has invalid rows:", paste(bad$row, bad$detail, collapse = " | ")))

message("NA audit gate smoke test passed")
