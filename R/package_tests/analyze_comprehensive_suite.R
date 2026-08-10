#!/usr/bin/env Rscript

`%||%` = function(x, y) if (is.null(x)) y else x

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "package_tests/analyze_comprehensive_suite.R")
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}
artifact = function(name) file.path(repo_root, "package_tests", name)

paths = list(
	registry = artifact("comprehensive_suite_registry.csv"),
	argument_coverage = artifact("public_argument_combination_coverage.csv"),
	argument_results = artifact("public_argument_combination_results.csv"),
	argument_failures = artifact("public_argument_combination_failures.csv"),
	suite_results = artifact("comprehensive_suite_results.csv"),
	suite_failures = artifact("comprehensive_suite_failures.csv"),
	workflow_coverage = artifact("comprehensive_suite_coverage.csv"),
	workflow_coverage_raw = artifact("comprehensive_suite_workflow_coverage.csv"),
	internal_surfaces = artifact("comprehensive_suite_internal_surfaces.csv"),
	coverage = artifact("comprehensive_suite_coverage.csv"),
	failures = artifact("comprehensive_suite_failures.csv"),
	uncovered = artifact("comprehensive_suite_uncovered_apis.csv"),
	argument_only = artifact("comprehensive_suite_argument_only_apis.csv"),
	workflow_only = artifact("comprehensive_suite_workflow_only_apis.csv"),
	internal_gaps = artifact("comprehensive_suite_internal_safety_net_gaps.csv"),
	unsupported_skipped = artifact("comprehensive_suite_unsupported_skipped_contexts.csv"),
	slowest = artifact("comprehensive_suite_slowest_cases.csv"),
	report = artifact("comprehensive_suite_report.html")
)

read_required_csv = function(path, label) {
	if (!file.exists(path)) stop("Missing ", label, ": ", path, call. = FALSE)
	read.csv(path, stringsAsFactors = FALSE, na.strings = character())
}

read_optional_csv = function(path) {
	if (!file.exists(path) || isTRUE(file.info(path)$size == 0)) return(data.frame())
	first_line = readLines(path, n = 1L, warn = FALSE)
	if (!length(first_line) || identical(first_line, "\"\"")) return(data.frame())
	tryCatch(read.csv(path, stringsAsFactors = FALSE, na.strings = character()), error = function(e) data.frame())
}

bind_rows_fill = function(rows) {
	rows = rows[vapply(rows, function(x) is.data.frame(x) && nrow(x) > 0L, logical(1))]
	if (!length(rows)) return(data.frame())
	cols = unique(unlist(lapply(rows, names), use.names = FALSE))
	rows = lapply(rows, function(df) {
		for (col in setdiff(cols, names(df))) df[[col]] = NA
		df[, cols, drop = FALSE]
	})
	do.call(rbind, rows)
}

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

target_from_parts = function(class_name, method_name, function_name = "") {
	class_name = clean_chr(class_name)
	method_name = clean_chr(method_name)
	function_name = clean_chr(function_name)
	ifelse(nzchar(method_name), paste(class_name, method_name, sep = "::"), function_name)
}

target_from_workflow_row = function(workflow) {
	target = clean_chr(workflow$target)
	if ("method_name" %in% names(workflow)) {
		method_target = ifelse(nzchar(clean_chr(workflow$method_name)) & nzchar(clean_chr(workflow$target)), paste(workflow$target, workflow$method_name, sep = "::"), target)
		target = ifelse(nzchar(clean_chr(workflow$method_name)), method_target, target)
	}
	target
}

count_by = function(df, key_col, value_name) {
	if (!nrow(df) || !key_col %in% names(df)) {
		out = data.frame(target = character(), stringsAsFactors = FALSE)
		out[[value_name]] = integer()
		return(out)
	}
	tab = table(clean_chr(df[[key_col]]))
	tab = tab[nzchar(names(tab))]
	data.frame(target = names(tab), value = as.integer(tab), stringsAsFactors = FALSE, check.names = FALSE) |>
		stats::setNames(c("target", value_name))
}

merge_count = function(base, counts, col) {
	if (!nrow(counts)) {
		base[[col]] = 0L
		return(base)
	}
	out = merge(base, counts, by = "target", all.x = TRUE, sort = FALSE)
	out[[col]][is.na(out[[col]])] = 0L
	out[[col]] = as.integer(out[[col]])
	out
}

latest_comprehensive_result_files = function() {
	files = list.files(file.path(repo_root, "package_tests"), pattern = "^comprehensive_tests_results.*[.]csv$", full.names = TRUE)
	files = files[file.exists(files) & file.info(files)$size > 0]
	files[order(file.info(files)$mtime, decreasing = TRUE)]
}

read_comprehensive_harness_results = function(files = latest_comprehensive_result_files()) {
	if (!length(files)) return(data.frame())
	rows = lapply(files, function(path) {
		df = tryCatch(read.csv(path, stringsAsFactors = FALSE), error = function(e) data.frame())
		if (!nrow(df)) return(NULL)
		df$source_file = basename(path)
		df
	})
	rows = rows[!vapply(rows, is.null, logical(1))]
	if (!length(rows)) return(data.frame())
	out = do.call(rbind, rows)
	out$target = sub(" .*$", "", clean_chr(out$inference_class))
	out
}

build_unified_coverage = function(registry, argument_coverage, workflow_coverage, internal_surfaces, harness_results) {
	base = registry
	for (col in c("target", "coverage_scope", "api_kind", "response_family", "design_family", "inference_family", "method_family", "runtime_tier", "required_coverage", "coverage_status", "source_runner", "exemption_type", "exemption_reason")) {
		if (!col %in% names(base)) base[[col]] = ""
	}
	arg_cols = c(
		"target", "total_cases", "valid_candidate_cases", "pairwise_or_higher_candidate_cases",
		"targeted_3way_candidate_cases", "executed_ok_cases", "error_cases",
		"unsupported_cases", "skipped_slow_cases", "skipped_dependency_cases",
		"covered_argument_values", "covered_argument_pairs", "has_legal_combination_case",
		"has_executed_legal_combination"
	)
	arg = argument_coverage[, intersect(arg_cols, names(argument_coverage)), drop = FALSE]
	names(arg) = ifelse(names(arg) == "target", "target", paste0("argument_", names(arg)))
	base = merge(base, arg, by = "target", all.x = TRUE, sort = FALSE)
	for (col in names(base)[grepl("^argument_", names(base))]) base[[col]] = if (is.logical(base[[col]])) truthy(base[[col]]) else as_int(base[[col]])
	for (col in c("argument_has_legal_combination_case", "argument_has_executed_legal_combination")) {
		if (!col %in% names(base)) base[[col]] = FALSE
		base[[col]] = truthy(base[[col]])
	}

	if (nrow(workflow_coverage) && "workflow_kind" %in% names(workflow_coverage)) {
		workflow_coverage$target_for_join = target_from_workflow_row(workflow_coverage)
		ok_workflow = workflow_coverage[workflow_coverage$status %in% c("ok", "classified"), , drop = FALSE]
		base = merge_count(base, count_by(ok_workflow, "target_for_join", "workflow_ok_rows"), "workflow_ok_rows")
		base = merge_count(base, count_by(workflow_coverage, "target_for_join", "workflow_total_rows"), "workflow_total_rows")
	} else {
		base$workflow_ok_rows = 0L
		base$workflow_total_rows = 0L
	}

	if (nrow(harness_results)) {
		ok_harness = harness_results[harness_results$status == "ok", , drop = FALSE]
		base = merge_count(base, count_by(ok_harness, "target", "comprehensive_harness_ok_rows"), "comprehensive_harness_ok_rows")
		base = merge_count(base, count_by(harness_results, "target", "comprehensive_harness_total_rows"), "comprehensive_harness_total_rows")
	} else {
		base$comprehensive_harness_ok_rows = 0L
		base$comprehensive_harness_total_rows = 0L
	}

	if (nrow(internal_surfaces)) {
		internal_targets = data.frame(
			target = unique(unlist(strsplit(clean_chr(internal_surfaces$registry_targets), ";", fixed = TRUE), use.names = FALSE)),
			internal_surface_rows = 1L,
			stringsAsFactors = FALSE
		)
		internal_targets = internal_targets[nzchar(internal_targets$target), , drop = FALSE]
		internal_targets = count_by(internal_targets, "target", "internal_surface_rows")
		base = merge_count(base, internal_targets, "internal_surface_rows")
	} else {
		base$internal_surface_rows = 0L
	}

	base$has_imported_argument_coverage = base$argument_total_cases > 0L | base$argument_has_legal_combination_case
	base$has_multidimensional_argument_coverage = base$argument_pairwise_or_higher_candidate_cases > 0L | base$argument_covered_argument_pairs > 0L
	base$has_workflow_coverage = truthy(base$has_comprehensive_workflow_coverage) | base$workflow_ok_rows > 0L | base$comprehensive_harness_ok_rows > 0L
	base$has_focused_public_testthat_coverage = truthy(base$has_focused_testthat_coverage)
	base$has_internal_safety_net_coverage = base$coverage_scope == "internal_safety_net" & base$internal_surface_rows > 0L
	base$has_exemption = if ("has_exemption" %in% names(base)) truthy(base$has_exemption) else nzchar(clean_chr(base$exemption_type))
	base$unified_coverage_status = ifelse(
		base$coverage_scope == "internal_safety_net",
		ifelse(base$has_internal_safety_net_coverage, "internal_safety_net_covered", "internal_safety_net_missing"),
		ifelse(base$has_exemption, "exempted",
			ifelse(base$has_workflow_coverage & base$has_multidimensional_argument_coverage, "workflow_and_multidimensional_arguments",
				ifelse(base$has_workflow_coverage & base$has_imported_argument_coverage, "workflow_and_argument_smoke",
					ifelse(base$has_workflow_coverage, "workflow_only",
						ifelse(base$has_imported_argument_coverage, "argument_only",
							ifelse(base$has_focused_public_testthat_coverage, "focused_public_testthat", "uncovered")
						)
					)
				)
			)
		)
	)
	base$coverage_explanation = ifelse(
		base$unified_coverage_status == "uncovered",
		ifelse(nzchar(clean_chr(base$exemption_reason)), base$exemption_reason, "No imported argument-combination, workflow, focused testthat, or exemption evidence."),
		paste(
			"scope=", base$coverage_scope,
			"; status=", base$unified_coverage_status,
			"; runner=", clean_chr(base$source_runner),
			sep = ""
		)
	)
	base[order(base$coverage_scope, base$target), , drop = FALSE]
}

build_unsupported_skipped = function(argument_results, argument_coverage, workflow_coverage, suite_results) {
	rows = list()
	if (nrow(argument_results)) {
		sk = argument_results[argument_results$status %in% c("unsupported", "skipped_slow", "skipped_dependency", "invalid_registry"), , drop = FALSE]
		if (nrow(sk)) {
			rows[[length(rows) + 1L]] = data.frame(
				source = "public_argument_combinations",
				tier = clean_chr(sk$tier),
				target = target_from_parts(sk$class_name, sk$method_name, sk$function_name),
				status = clean_chr(sk$status),
				reason = clean_chr(sk$error_message),
				duration_time_sec = suppressWarnings(as.numeric(sk$duration_time_sec)),
				stringsAsFactors = FALSE
			)
		}
	}
	if (nrow(argument_coverage)) {
		for (status_col in c("unsupported_cases", "skipped_slow_cases", "skipped_dependency_cases")) {
			if (!status_col %in% names(argument_coverage)) next
			rows_with_status = argument_coverage[as_int(argument_coverage[[status_col]]) > 0L, , drop = FALSE]
			if (nrow(rows_with_status)) {
				rows[[length(rows) + 1L]] = data.frame(
					source = "public_argument_coverage",
					tier = "",
					target = clean_chr(rows_with_status$target),
					status = sub("_cases$", "", status_col),
					reason = paste(status_col, as_int(rows_with_status[[status_col]]), sep = "="),
					duration_time_sec = NA_real_,
					stringsAsFactors = FALSE
				)
			}
		}
	}
	if (nrow(workflow_coverage) && "status" %in% names(workflow_coverage)) {
		sk = workflow_coverage[workflow_coverage$status %in% c("unsupported", "nonestimable", "exempted"), , drop = FALSE]
		if (nrow(sk)) {
			rows[[length(rows) + 1L]] = data.frame(
				source = "public_workflow_coverage",
				tier = clean_chr(sk$runtime_tier),
				target = target_from_workflow_row(sk),
				status = clean_chr(sk$status),
				reason = if ("exemption_reason" %in% names(sk)) clean_chr(sk$exemption_reason) else clean_chr(sk$error_message),
				duration_time_sec = NA_real_,
				stringsAsFactors = FALSE
			)
		}
	}
	if (nrow(suite_results)) {
		sk = suite_results[suite_results$status != "ok" | as_int(suite_results$failures_written) > 0L, , drop = FALSE]
		if (nrow(sk)) {
			rows[[length(rows) + 1L]] = data.frame(
				source = "run_comprehensive_suite",
				tier = clean_chr(sk$tier),
				target = clean_chr(sk$target_filter),
				status = clean_chr(sk$status),
				reason = clean_chr(sk$error_message),
				duration_time_sec = suppressWarnings(as.numeric(sk$duration_time_sec)),
				stringsAsFactors = FALSE
			)
		}
	}
	if (!length(rows)) return(data.frame(source = character(), tier = character(), target = character(), status = character(), reason = character(), duration_time_sec = numeric(), stringsAsFactors = FALSE))
	out = do.call(rbind, rows)
	out[order(out$source, out$status, out$target), , drop = FALSE]
}

build_slowest_cases = function(argument_results, suite_results, harness_results, limit = 100L) {
	rows = list()
	if (nrow(argument_results)) {
		rows[[length(rows) + 1L]] = data.frame(
			source = "public_argument_combinations",
			tier = clean_chr(argument_results$tier),
			target = target_from_parts(argument_results$class_name, argument_results$method_name, argument_results$function_name),
			case_id = clean_chr(argument_results$case_id),
			status = clean_chr(argument_results$status),
			duration_time_sec = suppressWarnings(as.numeric(argument_results$duration_time_sec)),
			stringsAsFactors = FALSE
		)
	}
	if (nrow(suite_results)) {
		rows[[length(rows) + 1L]] = data.frame(
			source = "run_comprehensive_suite",
			tier = clean_chr(suite_results$tier),
			target = clean_chr(suite_results$target_filter),
			case_id = clean_chr(suite_results$case_id),
			status = clean_chr(suite_results$status),
			duration_time_sec = suppressWarnings(as.numeric(suite_results$duration_time_sec)),
			stringsAsFactors = FALSE
		)
	}
	if (nrow(harness_results) && "duration_time_sec" %in% names(harness_results)) {
		rows[[length(rows) + 1L]] = data.frame(
			source = "comprehensive_tests",
			tier = "",
			target = clean_chr(harness_results$target),
			case_id = if ("case_id" %in% names(harness_results)) clean_chr(harness_results$case_id) else clean_chr(harness_results$id),
			status = clean_chr(harness_results$status),
			duration_time_sec = suppressWarnings(as.numeric(harness_results$duration_time_sec)),
			stringsAsFactors = FALSE
		)
	}
	if (!length(rows)) return(data.frame())
	out = do.call(rbind, rows)
	out = out[is.finite(out$duration_time_sec), , drop = FALSE]
	out = out[order(-out$duration_time_sec), , drop = FALSE]
	head(out, limit)
}

write_html_report = function(coverage, uncovered, argument_only, workflow_only, internal_gaps, unsupported_skipped, slowest) {
	esc = function(x) {
		x = clean_chr(x)
		x = gsub("&", "&amp;", x, fixed = TRUE)
		x = gsub("<", "&lt;", x, fixed = TRUE)
		x = gsub(">", "&gt;", x, fixed = TRUE)
		x
	}
	table_html = function(df, cols, limit = 25L) {
		if (!nrow(df)) return("<p>No rows.</p>")
		df = head(df[, intersect(cols, names(df)), drop = FALSE], limit)
		header = paste(sprintf("<th>%s</th>", esc(names(df))), collapse = "")
		body = apply(df, 1L, function(row) paste(sprintf("<td>%s</td>", esc(row)), collapse = ""))
		paste0("<table><thead><tr>", header, "</tr></thead><tbody>", paste0("<tr>", body, "</tr>", collapse = ""), "</tbody></table>")
	}
	scope_tab = as.data.frame(table(coverage$coverage_scope, coverage$unified_coverage_status), stringsAsFactors = FALSE)
	names(scope_tab) = c("coverage_scope", "unified_coverage_status", "n")
	html = paste0(
		"<!doctype html><html><head><meta charset=\"utf-8\"><title>Comprehensive Suite Report</title>",
		"<style>body{font-family:system-ui,sans-serif;margin:24px;}table{border-collapse:collapse;margin:12px 0;width:100%;}th,td{border:1px solid #ddd;padding:4px 6px;font-size:12px;}th{background:#f5f5f5;text-align:left;}code{background:#f5f5f5;padding:1px 3px;}</style>",
		"</head><body>",
		"<h1>Comprehensive Suite Report</h1>",
		"<p>Generated ", esc(format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")), ".</p>",
		"<h2>Coverage Summary</h2>", table_html(scope_tab, names(scope_tab), 100L),
		"<h2>Uncovered Public APIs</h2>", table_html(uncovered, c("target", "api_kind", "required_coverage", "exemption_type", "coverage_explanation")),
		"<h2>Argument-Only Public APIs</h2>", table_html(argument_only, c("target", "api_kind", "required_coverage", "unified_coverage_status")),
		"<h2>Workflow-Only Public APIs</h2>", table_html(workflow_only, c("target", "api_kind", "required_coverage", "unified_coverage_status")),
		"<h2>Internal Safety-Net Gaps</h2>", table_html(internal_gaps, c("target", "internal_symbols", "classification_reason", "coverage_explanation")),
		"<h2>Unsupported / Skipped Contexts</h2>", table_html(unsupported_skipped, c("source", "tier", "target", "status", "reason")),
		"<h2>Slowest Cases</h2>", table_html(slowest, c("source", "tier", "target", "status", "duration_time_sec")),
		"</body></html>"
	)
	writeLines(html, paths$report, useBytes = TRUE)
}

analyze_comprehensive_suite = function() {
	registry = read_required_csv(paths$registry, "comprehensive_suite_registry")
	argument_coverage = read_required_csv(paths$argument_coverage, "public_argument_combination_coverage")
	argument_results = read_optional_csv(paths$argument_results)
	suite_results = read_optional_csv(paths$suite_results)
	workflow_coverage = read_optional_csv(paths$workflow_coverage_raw)
	if (!nrow(workflow_coverage)) {
		workflow_coverage = read_optional_csv(paths$workflow_coverage)
		if (nrow(workflow_coverage) && "workflow_kind" %in% names(workflow_coverage)) {
			write.csv(workflow_coverage, paths$workflow_coverage_raw, row.names = FALSE)
		}
	}
	internal_surfaces = read_optional_csv(paths$internal_surfaces)
	harness_results = read_comprehensive_harness_results()

	coverage = build_unified_coverage(registry, argument_coverage, workflow_coverage, internal_surfaces, harness_results)
	public = coverage[coverage$coverage_scope == "public_contract", , drop = FALSE]
	uncovered = public[public$unified_coverage_status == "uncovered" & !public$has_exemption, , drop = FALSE]
	argument_only = public[public$unified_coverage_status == "argument_only", , drop = FALSE]
	workflow_only = public[public$unified_coverage_status == "workflow_only", , drop = FALSE]
	internal_gaps = coverage[coverage$coverage_scope == "internal_safety_net" & coverage$unified_coverage_status == "internal_safety_net_missing", , drop = FALSE]
	unsupported_skipped = build_unsupported_skipped(argument_results, argument_coverage, workflow_coverage, suite_results)
	slowest = build_slowest_cases(argument_results, suite_results, harness_results)
	failures = bind_rows_fill(list(read_optional_csv(paths$suite_failures), read_optional_csv(paths$argument_failures)))
	if (!nrow(failures)) {
		failures = data.frame(
			source = character(), tier = character(), target = character(), status = character(),
			reason = character(), case_id = character(), stringsAsFactors = FALSE
		)
	}

	write.csv(coverage, paths$coverage, row.names = FALSE)
	write.csv(failures, paths$failures, row.names = FALSE)
	write.csv(uncovered, paths$uncovered, row.names = FALSE)
	write.csv(argument_only, paths$argument_only, row.names = FALSE)
	write.csv(workflow_only, paths$workflow_only, row.names = FALSE)
	write.csv(internal_gaps, paths$internal_gaps, row.names = FALSE)
	write.csv(unsupported_skipped, paths$unsupported_skipped, row.names = FALSE)
	write.csv(slowest, paths$slowest, row.names = FALSE)
	write_html_report(coverage, uncovered, argument_only, workflow_only, internal_gaps, unsupported_skipped, slowest)
	invisible(list(
		coverage = coverage,
		failures = failures,
		uncovered = uncovered,
		argument_only = argument_only,
		workflow_only = workflow_only,
		internal_gaps = internal_gaps,
		unsupported_skipped = unsupported_skipped,
		slowest = slowest
	))
}

if (identical(environment(), globalenv()) && !interactive()) {
	out = analyze_comprehensive_suite()
	message("comprehensive suite analyzer wrote ", nrow(out$coverage), " coverage rows to ", paths$coverage)
	message("uncovered public APIs without exemption: ", nrow(out$uncovered))
	message("internal safety-net gaps: ", nrow(out$internal_gaps))
}
