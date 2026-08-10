#!/usr/bin/env Rscript

`%||%` = function(x, y) if (is.null(x)) y else x

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "package_tests/comprehensive_suite_runtime_tiers.R")
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}
artifact = function(name) file.path(repo_root, "package_tests", name)

runtime_tier_columns = c(
	"tier", "tier_rank", "default_timeout_sec", "argument_combination_tier",
	"argument_combination_mode", "comprehensive_harness_mode", "workflow_tier",
	"internal_safety_net_mode", "resampling_scale", "fixture_scope",
	"method_family_scope", "internal_scope", "expected_scheduler",
	"manual_or_scheduled", "hard_failure_policy", "description"
)

build_comprehensive_suite_runtime_tiers = function() {
	data.frame(
		tier = c("smoke", "ci", "nightly", "release"),
		tier_rank = c(1L, 2L, 3L, 4L),
		default_timeout_sec = c(180L, 600L, 1800L, 3600L),
		argument_combination_tier = c("smoke", "ci", "ci", "ci"),
		argument_combination_mode = c("run_or_resume_existing_cases", "run_or_resume_existing_cases", "import_ci_results", "import_ci_results"),
		comprehensive_harness_mode = c("import_existing_results", "import_existing_results", "bounded_filtered_run", "maximal_registry_driven_run"),
		workflow_tier = c("smoke", "ci", "nightly", "release"),
		internal_safety_net_mode = c("highest_fan_in_smoke", "representative_high_fan_in", "broader_internal_surfaces", "all_required_internal_surfaces"),
		resampling_scale = c("tiny", "small", "moderate", "larger"),
		fixture_scope = c("one_default_per_major_family", "representative_response_design_inference", "broader_datasets_fixtures_formulas", "maximal_registry_driven"),
		method_family_scope = c("smoke_representatives", "selected_method_family_checks", "targeted_high_risk_3way", "selected_exhaustive_small_spaces"),
		internal_scope = c("highest_fan_in_validators", "selected_high_fan_in_safety_nets", "broader_internal_safety_nets", "all_required_high_fan_in_safety_nets"),
		expected_scheduler = c("developer_smoke_or_pr", "ci", "nightly", "manual_or_release"),
		manual_or_scheduled = c("manual_or_ci", "scheduled_ci", "scheduled_nightly", "manual_release"),
		hard_failure_policy = c("dependency_schema_and_unexpected_errors", "dependency_schema_unexpected_errors_and_strict_public_invariants", "report_slow_cases_and_unexpected_errors", "final_report_with_exemptions"),
		description = c(
			"Dependency validation, argument-combination smoke import, default workflows, highest-fan-in internal validators, tiny B/r.",
			"Argument-combination CI import, representative workflows, selected method-family checks, strict public invariants.",
			"Broader comprehensive harness paths, more datasets/fixtures/formulas, targeted high-risk 3-way workflows, broader internal safety nets, slow-case reporting.",
			"Maximal registry-driven coverage, selected exhaustive small spaces, larger resampling counts, all required internal safety nets, final report with exemptions."
		),
		stringsAsFactors = FALSE
	)
}

validate_comprehensive_suite_runtime_tiers = function(tiers) {
	missing = setdiff(runtime_tier_columns, names(tiers))
	if (length(missing)) stop("Runtime tier registry missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
	expected = c("smoke", "ci", "nightly", "release")
	if (!identical(tiers$tier, expected)) stop("Runtime tiers must be ordered smoke, ci, nightly, release.", call. = FALSE)
	if (anyDuplicated(tiers$tier)) stop("Runtime tiers must be unique.", call. = FALSE)
	if (any(!tiers$argument_combination_tier %in% c("smoke", "ci"))) {
		stop("Runtime tiers must reuse smoke/ci argument-combination artifacts instead of defining new generation tiers.", call. = FALSE)
	}
	if (any(tiers$tier %in% c("nightly", "release") & !grepl("import", tiers$argument_combination_mode))) {
		stop("Nightly/release must import existing argument-combination coverage rather than reimplement generation.", call. = FALSE)
	}
	if (any(tiers$tier %in% c("smoke", "ci") & grepl("maximal|larger|exhaustive", paste(tiers$comprehensive_harness_mode, tiers$resampling_scale, tiers$method_family_scope)))) {
		stop("Smoke/CI tiers must not request release-scale comprehensive sweeps.", call. = FALSE)
	}
	if (any(tiers$default_timeout_sec <= 0L)) stop("Runtime tiers must have positive default timeouts.", call. = FALSE)
	invisible(TRUE)
}

tier_policy_for = function(tier, tiers = build_comprehensive_suite_runtime_tiers()) {
	validate_comprehensive_suite_runtime_tiers(tiers)
	if (!tier %in% tiers$tier) stop("Unsupported comprehensive suite tier: ", tier, call. = FALSE)
	tiers[tiers$tier == tier, , drop = FALSE]
}

write_comprehensive_suite_runtime_tiers = function(path = artifact("comprehensive_suite_runtime_tiers.csv"), tiers = build_comprehensive_suite_runtime_tiers()) {
	validate_comprehensive_suite_runtime_tiers(tiers)
	write.csv(tiers, path, row.names = FALSE)
	invisible(tiers)
}

called_as_runtime_tier_script = function() {
	file_arg = grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% ""
	identical(basename(sub("^--file=", "", file_arg)), "comprehensive_suite_runtime_tiers.R")
}

if (called_as_runtime_tier_script()) {
	args = commandArgs(trailingOnly = TRUE)
	path = args[1] %||% artifact("comprehensive_suite_runtime_tiers.csv")
	tiers = write_comprehensive_suite_runtime_tiers(path)
	message("wrote ", nrow(tiers), " comprehensive suite runtime tier rows to ", path)
}
