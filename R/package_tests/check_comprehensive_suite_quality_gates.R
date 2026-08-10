#!/usr/bin/env Rscript

`%||%` = function(x, y) if (is.null(x)) y else x

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "package_tests/check_comprehensive_suite_quality_gates.R")
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}
artifact = function(name) file.path(repo_root, "package_tests", name)

gate_paths = list(
	inventory = artifact("public_api_inventory.csv"),
	registry = artifact("comprehensive_suite_registry.csv"),
	coverage = artifact("comprehensive_suite_coverage.csv"),
	suite_results = artifact("comprehensive_suite_results.csv"),
	runtime_tiers = artifact("comprehensive_suite_runtime_tiers.csv"),
	internal_surfaces = artifact("comprehensive_suite_internal_surfaces.csv"),
	unsupported_skipped = artifact("comprehensive_suite_unsupported_skipped_contexts.csv"),
	exemptions = artifact("comprehensive_suite_exemptions.csv"),
	gate_exemptions = artifact("comprehensive_suite_quality_gate_exemptions.csv"),
	report = artifact("comprehensive_suite_quality_gates.csv"),
	summary = artifact("comprehensive_suite_quality_gate_summary.csv")
)

required_artifacts = c(
	"public_api_inventory.csv",
	"public_argument_combination_coverage.csv",
	"public_argument_combination_results.csv",
	"comprehensive_suite_registry.csv",
	"comprehensive_suite_coverage.csv",
	"comprehensive_suite_results.csv",
	"comprehensive_suite_runtime_tiers.csv",
	"comprehensive_suite_internal_surfaces.csv"
)

required_schemas = list(
	inventory = c("export_name", "api_kind", "class_name", "method_name", "has_more_than_one_configurable_arg"),
	registry = c("target", "coverage_scope", "api_kind", "class_name", "method_name", "required_coverage", "has_exemption"),
	coverage = c("target", "coverage_scope", "api_kind", "required_coverage", "unified_coverage_status", "has_workflow_coverage", "has_multidimensional_argument_coverage", "has_internal_safety_net_coverage", "has_exemption"),
	suite_results = c("case_id", "tier", "step", "status", "failures_written"),
	runtime_tiers = c("tier", "argument_combination_tier", "comprehensive_harness_mode", "resampling_scale", "expected_scheduler"),
	internal_surfaces = c("normalized_symbol", "coverage_scope", "registry_targets", "rationale", "classification_reason"),
	unsupported_skipped = c("source", "tier", "target", "status", "reason")
)

allowed_tiers = c("smoke", "ci", "nightly", "release")
allowed_unified_statuses = c(
	"workflow_and_multidimensional_arguments", "workflow_and_argument_smoke",
	"workflow_only", "argument_only", "focused_public_testthat", "exempted",
	"internal_safety_net_covered", "internal_safety_net_missing", "uncovered"
)
allowed_skip_statuses = c("unsupported", "skipped_slow", "skipped_dependency", "invalid_registry", "nonestimable", "exempted")

clean_chr = function(x) {
	x = as.character(x %||% "")
	x[is.na(x)] = ""
	x
}

truthy = function(x) {
	x %in% c(TRUE, "TRUE", "true", "1", 1L)
}

as_int = function(x) {
	x = suppressWarnings(as.integer(x))
	x[is.na(x)] = 0L
	x
}

read_required_csv = function(path, label) {
	if (!file.exists(path)) stop("Missing ", label, ": ", path, call. = FALSE)
	read.csv(path, stringsAsFactors = FALSE, na.strings = character())
}

read_optional_csv = function(path, cols = character()) {
	if (!file.exists(path) || isTRUE(file.info(path)$size == 0)) {
		return(as.data.frame(setNames(replicate(length(cols), character(), simplify = FALSE), cols), stringsAsFactors = FALSE))
	}
	first_line = readLines(path, n = 1L, warn = FALSE)
	if (!length(first_line) || identical(first_line, "\"\"")) {
		return(as.data.frame(setNames(replicate(length(cols), character(), simplify = FALSE), cols), stringsAsFactors = FALSE))
	}
	tryCatch(read.csv(path, stringsAsFactors = FALSE, na.strings = character()), error = function(e) {
		as.data.frame(setNames(replicate(length(cols), character(), simplify = FALSE), cols), stringsAsFactors = FALSE)
	})
}

empty_gate_rows = function() {
	data.frame(
		gate = character(), severity = character(), tier = character(), target = character(),
		arg = character(), value_expr = character(), detail = character(),
		exemption_type = character(), exemption_reason = character(), stringsAsFactors = FALSE
	)
}

gate_rows = function(gate, severity, df, detail, tier = "") {
	if (!nrow(df)) return(empty_gate_rows())
	for (col in c("target", "arg", "value_expr", "exemption_type", "exemption_reason")) {
		if (!col %in% names(df)) df[[col]] = ""
	}
	if (!"tier" %in% names(df)) df$tier = tier
	data.frame(
		gate = gate,
		severity = severity,
		tier = clean_chr(df$tier),
		target = clean_chr(df$target),
		arg = clean_chr(df$arg),
		value_expr = clean_chr(df$value_expr),
		detail = detail,
		exemption_type = clean_chr(df$exemption_type),
		exemption_reason = clean_chr(df$exemption_reason),
		stringsAsFactors = FALSE
	)
}

target_from_inventory = function(inventory) {
	ifelse(nzchar(clean_chr(inventory$method_name)), paste(inventory$export_name, inventory$method_name, sep = "::"), inventory$export_name)
}

high_priority_public_api = function(coverage) {
	txt = paste(clean_chr(coverage$target), clean_chr(coverage$class_name), clean_chr(coverage$method_name), clean_chr(coverage$required_coverage), sep = " ")
	grepl("^Inference|^Design|SimulationFramework", txt) |
		grepl("constructor_workflow|public_workflow|bootstrap|bayesian_bootstrap|parametric_bootstrap|rand|asymp|wald|score|lik_ratio|gradient|jackknife|estimate|confidence_interval|pval|assign|response|strata|cluster", txt, ignore.case = TRUE)
}

ensure_schema_rows = function(inputs) {
	rows = list()
	for (name in names(required_schemas)) {
		missing = setdiff(required_schemas[[name]], names(inputs[[name]]))
		if (length(missing)) {
			rows[[length(rows) + 1L]] = gate_rows(
				"schema_validity",
				"hard",
				data.frame(target = name, value_expr = paste(missing, collapse = ","), stringsAsFactors = FALSE),
				paste("Missing required columns in", name)
			)
		}
	}
	rows
}

dependency_rows = function() {
	missing = required_artifacts[!file.exists(file.path(repo_root, "package_tests", required_artifacts))]
	gate_rows(
		"argument_checking_dependency",
		"hard",
		data.frame(target = missing, stringsAsFactors = FALSE),
		"Required argument-checking/comprehensive-suite dependency artifact is missing."
	)
}

build_comprehensive_quality_gate_report = function(inputs) {
	rows = list(dependency_rows())
	rows = c(rows, ensure_schema_rows(inputs))

	inventory_targets = target_from_inventory(inputs$inventory)
	public_registry = inputs$registry[inputs$registry$coverage_scope == "public_contract", , drop = FALSE]
	missing_registry = inputs$inventory[!inventory_targets %in% public_registry$target, , drop = FALSE]
	missing_registry$target = inventory_targets[!inventory_targets %in% public_registry$target]
	rows[[length(rows) + 1L]] = gate_rows(
		"public_api_missing_from_registry",
		"hard",
		missing_registry,
		"Exported public API inventory row is absent from comprehensive suite registry."
	)

	public = inputs$coverage[inputs$coverage$coverage_scope == "public_contract", , drop = FALSE]
	public$has_exemption = truthy(public$has_exemption)
	public$has_workflow_coverage = truthy(public$has_workflow_coverage)
	public$has_multidimensional_argument_coverage = truthy(public$has_multidimensional_argument_coverage)
	public$has_imported_argument_coverage = if ("has_imported_argument_coverage" %in% names(public)) truthy(public$has_imported_argument_coverage) else FALSE
	public$has_focused_public_testthat_coverage = if ("has_focused_public_testthat_coverage" %in% names(public)) truthy(public$has_focused_public_testthat_coverage) else FALSE

	r6_constructor_gap = public[
		public$api_kind == "r6_class" &
			!public$has_workflow_coverage &
			!public$has_focused_public_testthat_coverage &
			!public$has_exemption,
		,
		drop = FALSE
	]
	rows[[length(rows) + 1L]] = gate_rows(
		"r6_constructor_without_coverage",
		"hard_later",
		r6_constructor_gap,
		"Concrete exported R6 class lacks constructor/workflow/focused coverage and has no exemption."
	)

	high_priority_gap = public[
		high_priority_public_api(public) &
			!public$has_workflow_coverage &
			!public$has_focused_public_testthat_coverage &
			!public$has_exemption,
		,
		drop = FALSE
	]
	rows[[length(rows) + 1L]] = gate_rows(
		"high_priority_public_api_without_workflow",
		"hard_later",
		high_priority_gap,
		"High-priority public API lacks workflow or focused public coverage and has no exemption."
	)

	multi_arg_gap = public[
		truthy(public$has_more_than_one_configurable_arg) &
			!public$has_imported_argument_coverage &
			!public$has_multidimensional_argument_coverage &
			!public$has_exemption,
		,
		drop = FALSE
	]
	rows[[length(rows) + 1L]] = gate_rows(
		"multi_arg_without_argument_dependency_coverage",
		ifelse(high_priority_public_api(multi_arg_gap), "hard_later", "report"),
		multi_arg_gap,
		"Public API has multiple configurable arguments but no imported argument-combination coverage and no exemption."
	)

	internal_coverage = inputs$coverage[inputs$coverage$coverage_scope == "internal_safety_net", , drop = FALSE]
	internal_coverage$has_internal_safety_net_coverage = truthy(internal_coverage$has_internal_safety_net_coverage)
	internal_missing = internal_coverage[!internal_coverage$has_internal_safety_net_coverage, , drop = FALSE]
	rows[[length(rows) + 1L]] = gate_rows(
		"internal_safety_net_missing",
		"hard",
		internal_missing,
		"Internal safety-net registry row has no matching internal surface coverage."
	)

	bad_internal_surface = inputs$internal_surfaces[
		!nzchar(clean_chr(inputs$internal_surfaces$rationale)) |
			!nzchar(clean_chr(inputs$internal_surfaces$classification_reason)) |
			clean_chr(inputs$internal_surfaces$coverage_scope) != "internal_safety_net",
		,
		drop = FALSE
	]
	if (nrow(bad_internal_surface)) bad_internal_surface$target = clean_chr(bad_internal_surface$normalized_symbol)
	rows[[length(rows) + 1L]] = gate_rows(
		"internal_safety_net_without_rationale",
		"hard",
		bad_internal_surface,
		"Internal safety-net surface is missing rationale/classification or is not scoped as internal_safety_net."
	)

	smoke_ci_errors = inputs$suite_results[
		inputs$suite_results$tier %in% c("smoke", "ci") &
			(clean_chr(inputs$suite_results$status) != "ok" | as_int(inputs$suite_results$failures_written) > 0L),
		,
		drop = FALSE
	]
	if (nrow(smoke_ci_errors)) smoke_ci_errors$target = clean_chr(smoke_ci_errors$case_id)
	rows[[length(rows) + 1L]] = gate_rows(
		"smoke_ci_unexpected_error",
		"hard",
		smoke_ci_errors,
		"Smoke/CI comprehensive suite step has non-ok status or wrote failure rows."
	)

	unknown_tier = inputs$suite_results[!inputs$suite_results$tier %in% allowed_tiers, , drop = FALSE]
	if (nrow(unknown_tier)) unknown_tier$target = clean_chr(unknown_tier$case_id)
	rows[[length(rows) + 1L]] = gate_rows(
		"unknown_runtime_tier",
		"hard",
		unknown_tier,
		paste("Comprehensive suite result tier must be one of:", paste(allowed_tiers, collapse = ", "))
	)

	unknown_coverage_status = inputs$coverage[!inputs$coverage$unified_coverage_status %in% allowed_unified_statuses, , drop = FALSE]
	rows[[length(rows) + 1L]] = gate_rows(
		"unknown_unified_coverage_status",
		"hard",
		unknown_coverage_status,
		paste("Unified coverage status must be one of:", paste(allowed_unified_statuses, collapse = ", "))
	)

	unknown_skip_status = inputs$unsupported_skipped[
		nrow(inputs$unsupported_skipped) > 0L &
			!inputs$unsupported_skipped$status %in% allowed_skip_statuses,
		,
		drop = FALSE
	]
	rows[[length(rows) + 1L]] = gate_rows(
		"unknown_skip_or_support_status",
		"hard",
		unknown_skip_status,
		paste("Skip/support status must be one of:", paste(allowed_skip_statuses, collapse = ", "))
	)

	exemptions = inputs$exemptions
	if (nrow(exemptions)) {
		expiry = suppressWarnings(as.Date(clean_chr(exemptions$expiry_date)))
		expired = exemptions[!is.na(expiry) & expiry < Sys.Date(), , drop = FALSE]
		rows[[length(rows) + 1L]] = gate_rows(
			"expired_exemption",
			"hard",
			expired,
			"Comprehensive suite exemption has expired and must be reviewed."
		)
	}

	report = do.call(rbind, rows[!vapply(rows, is.null, logical(1))])
	if (is.null(report) || !nrow(report)) report = empty_gate_rows()
	report
}

apply_gate_exemptions = function(rows, exemptions) {
	if (!nrow(rows) || !nrow(exemptions)) return(rows)
	for (col in c("gate", "target", "arg", "value_expr")) {
		if (!col %in% names(exemptions)) exemptions[[col]] = ""
	}
	exemptions$key = paste(exemptions$gate, exemptions$target, exemptions$arg, exemptions$value_expr, sep = "\r")
	rows$key = paste(rows$gate, rows$target, rows$arg, rows$value_expr, sep = "\r")
	rows$exempted = rows$key %in% exemptions$key
	rows$key = NULL
	rows
}

summarize_comprehensive_quality_gates = function(report, mode = "report") {
	active = report$severity == "hard"
	if (identical(mode, "strict")) active = report$severity %in% c("hard", "hard_later")
	if (identical(mode, "report")) active = active & report$gate %in% c("argument_checking_dependency", "schema_validity", "unknown_runtime_tier", "unknown_unified_coverage_status", "unknown_skip_or_support_status", "expired_exemption")
	if ("exempted" %in% names(report)) active = active & !truthy(report$exempted)
	data.frame(
		mode = mode,
		total_rows = nrow(report),
		report_rows = sum(report$severity == "report"),
		future_hard_rows = sum(report$severity == "hard_later"),
		hard_rows = sum(report$severity == "hard"),
		active_hard_rows = sum(active),
		ci_should_fail = sum(active) > 0L,
		stringsAsFactors = FALSE
	)
}

check_comprehensive_suite_quality_gates = function(mode = "report") {
	inputs = list(
		inventory = read_required_csv(gate_paths$inventory, "public_api_inventory"),
		registry = read_required_csv(gate_paths$registry, "comprehensive_suite_registry"),
		coverage = read_required_csv(gate_paths$coverage, "comprehensive_suite_coverage"),
		suite_results = read_required_csv(gate_paths$suite_results, "comprehensive_suite_results"),
		runtime_tiers = read_required_csv(gate_paths$runtime_tiers, "comprehensive_suite_runtime_tiers"),
		internal_surfaces = read_required_csv(gate_paths$internal_surfaces, "comprehensive_suite_internal_surfaces"),
		unsupported_skipped = read_optional_csv(gate_paths$unsupported_skipped, required_schemas$unsupported_skipped),
		exemptions = read_optional_csv(gate_paths$exemptions, c("target", "api_kind", "class_name", "method_name", "exemption_type", "reason", "expiry_date", "owner", "created_date"))
	)
	gate_exemptions = read_optional_csv(gate_paths$gate_exemptions, c("gate", "target", "arg", "value_expr", "reason"))
	report = apply_gate_exemptions(build_comprehensive_quality_gate_report(inputs), gate_exemptions)
	if (!"exempted" %in% names(report)) report$exempted = FALSE
	summary = summarize_comprehensive_quality_gates(report, mode)
	write.csv(report, gate_paths$report, row.names = FALSE)
	write.csv(summary, gate_paths$summary, row.names = FALSE)
	invisible(list(report = report, summary = summary))
}

main = function() {
	args = commandArgs(trailingOnly = TRUE)
	mode = if (length(args) >= 1L && nzchar(args[1L])) args[1L] else "report"
	out = check_comprehensive_suite_quality_gates(mode)
	message("Wrote comprehensive suite quality gate rows: ", nrow(out$report))
	message("Active hard gate rows: ", out$summary$active_hard_rows[1L])
	if (isTRUE(out$summary$ci_should_fail[1L])) quit(status = 1L)
}

called_as_gate_script = function() {
	file_arg = grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% ""
	identical(basename(sub("^--file=", "", file_arg)), "check_comprehensive_suite_quality_gates.R")
}

if (called_as_gate_script()) {
	main()
}
