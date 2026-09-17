#!/usr/bin/env Rscript

# Regenerate coverage_gap_registry.csv from a saved covr coverage object or
# from as.data.frame(<covr coverage>) written as CSV.  Coverage measurement is
# deliberately separate from this script: covr::package_coverage() compiles an
# instrumented package and must only be run when that cost has been authorized.

`%||%` = function(x, y) if (is.null(x)) y else x

script_arg = grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path = if (length(script_arg)) sub("^--file=", "", script_arg[[1L]]) else "package_tests/coverage_gap_registry.R"
package_tests_dir = normalizePath(dirname(script_path), mustWork = FALSE)
default_output = file.path(package_tests_dir, "coverage_gap_registry.csv")

registry_columns = c(
	"file", "coverage_percent", "covered_lines", "coverable_lines",
	"weighted_opportunity", "category", "owning_todo", "status",
	"baseline_commit", "measured_commit", "measured_at", "notes"
)

empty_registry = function() {
	out = as.data.frame(setNames(replicate(length(registry_columns), character(), simplify = FALSE), registry_columns), stringsAsFactors = FALSE)
	out$coverage_percent = numeric()
	out$covered_lines = integer()
	out$coverable_lines = integer()
	out$weighted_opportunity = numeric()
	out
}

read_coverage_rows = function(path) {
	if (!file.exists(path)) stop("Coverage input does not exist: ", path, call. = FALSE)
	provenance = list()
	if (grepl("\\.rds$", path, ignore.case = TRUE)) {
		coverage = readRDS(path)
		# CI shard/merged reports wrap the covr object with measurement metadata.
		if (is.list(coverage) && !inherits(coverage, "coverage") && "coverage" %in% names(coverage)) {
			provenance = coverage[intersect(c("commit", "measured_at"), names(coverage))]
			coverage = coverage$coverage
		}
		rows = covr::tally_coverage(coverage, by = "line")
	} else {
		rows = read.csv(path, stringsAsFactors = FALSE, na.strings = c("NA"))
		if (!"filename" %in% names(rows) && "file" %in% names(rows)) rows$filename = rows$file
		if (!"value" %in% names(rows)) {
			value_col = intersect(c("hits", "count"), names(rows))
			if (length(value_col)) rows$value = rows[[value_col[[1L]]]]
		}
		if (nrow(rows) && !"line" %in% names(rows) && !all(c("first_line", "last_line", "functions") %in% names(rows))) {
			stop("Coverage CSV needs line or covr expression source spans; counter rows are not source lines.", call. = FALSE)
		}
		rows = covr::tally_coverage(rows, by = "line")
	}
	if (!nrow(rows)) {
		out = data.frame(file = character(), line = integer(), value = numeric())
	} else {
		if (!all(c("filename", "line", "value") %in% names(rows))) stop("Coverage rows need filename, line and value.", call. = FALSE)
		rows$file = normalize_coverage_path(as.character(rows$filename))
		rows$value = suppressWarnings(as.numeric(rows$value))
		rows = rows[!is.na(rows$value) & !is.na(rows$file) & nzchar(rows$file) & !is.na(rows$line), , drop = FALSE]
		# Multiple functions/counters can share a physical source line.
		out = if (nrow(rows)) aggregate(value ~ file + line, rows, max) else data.frame(file = character(), line = integer(), value = numeric())
	}
	attr(out, "provenance") = provenance
	out
}

normalize_coverage_path = function(path) {
	path = gsub("\\\\", "/", path)
	path = sub("^.*/R/EDI/", "R/EDI/", path)
	path = ifelse(grepl("^R/EDI/", path), path,
		ifelse(grepl("^(R|src)/", path), paste0("R/EDI/", path), path))
	path
}

summarize_coverage = function(rows) {
	if (!nrow(rows)) return(empty_registry()[, registry_columns[1:5], drop = FALSE])
	by_file = split(rows$value, rows$file)
	out = do.call(rbind, lapply(names(by_file), function(file) {
		values = by_file[[file]]
		coverable = length(values)
		covered = sum(values > 0)
		percent = if (coverable) 100 * covered / coverable else NA_real_
		data.frame(
			file = file,
			coverage_percent = percent,
			covered_lines = covered,
			coverable_lines = coverable,
			weighted_opportunity = coverable - covered,
			stringsAsFactors = FALSE
		)
	}))
	out[order(-out$weighted_opportunity, out$file), , drop = FALSE]
}

default_triage = function(file, coverage_percent) {
	base = basename(file)
	performance = c(
		"kk_bootstrap_loop.cpp", "base_bootstrap_loop.cpp", "bisection_ci_loop.cpp",
		"bisection_ci.cpp", "randomization_loop.cpp", "ols_distr_parallel.cpp",
		"ridit_distr_parallel.cpp", "fast_kk_wilcox_parallel.cpp",
		"fast_wilcox_parallel.cpp", "KK_bootstrap_helper_fillin.cpp",
		"kk_bootstrap_reservoir_stats.cpp", "kk_lin_match_data.cpp",
		"kk21_stepwise_survival.cpp", "random_block_size_speedups.cpp",
		"which_cols_vary.cpp", "match_data_compute_speedup.cpp",
		"build_kk_combined_ols_design.cpp", "log_lik_nb.cpp",
		"fast_jonckheere_terpstra.cpp", "fast_ordinal_clmm.cpp",
		"fast_scale_cols.cpp", "fast_shuffle.cpp", "fast_math_utils.cpp",
		"beta_regression_helpers.cpp", "_glmm_links.h", "zero_one_logit_transform.h"
	)
	class_files = c(
		"inference_continuous_KK14_bai.R", "inference_continuous_KK21_bai.R",
		"inference_ext_quantile_rand_ci.R", "inference_all_abstract_quantile_rand_ci.R"
	)
	if (base %in% performance && identical(coverage_percent, 0)) {
		return(c(category = "dispatch_threshold", owning_todo = "TODO-3", status = "pending",
			notes = "Locate and cross the production dispatch threshold in a CI-only bulk test."))
	}
	if (base %in% class_files && identical(coverage_percent, 0)) {
		return(c(category = "straightforward_test", owning_todo = "TODO-4", status = "pending",
			notes = "Confirm existing coverage, then add a focused public-contract test if genuinely untested."))
	}
	if (identical(base, "build_info.cpp") && identical(coverage_percent, 0)) {
		return(c(category = "diagnostic_smoke", owning_todo = "TODO-5", status = "pending",
			notes = "Smoke-test the exported edi_build_info_cpp() accessor."))
	}
	c(category = "unclassified", owning_todo = "TODO-1", status = "triage_needed", notes = "")
}

merge_triage = function(summary, prior = empty_registry(), threshold = 80,
	measured_commit = "", measured_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
	# Keep tracked files when they reach the threshold; newly well-covered files
	# do not need backlog entries. Unmeasured historical rows stay unchanged.
	summary = summary[summary$coverage_percent < threshold | summary$file %in% prior$file, , drop = FALSE]
	registry = empty_registry()
	if (nrow(summary)) {
		triage = t(vapply(seq_len(nrow(summary)), function(i) {
			default_triage(summary$file[[i]], summary$coverage_percent[[i]])
		}, character(4L)))
		registry = cbind(summary, as.data.frame(triage, stringsAsFactors = FALSE))
		registry$baseline_commit = rep(measured_commit, nrow(registry))
		registry$measured_commit = rep(measured_commit, nrow(registry))
		registry$measured_at = rep(measured_at, nrow(registry))
		matched = match(registry$file, prior$file)
		keep = !is.na(matched)
		for (column in intersect(c("category", "owning_todo", "status", "baseline_commit", "notes"), names(prior))) {
			old = as.character(prior[[column]][matched[keep]])
			nonblank = !is.na(old) & nzchar(old)
			registry[[column]][which(keep)[nonblank]] = old[nonblank]
		}
		registry$status[registry$coverage_percent >= threshold & registry$status != "excluded"] = "addressed"
		registry$status[registry$coverage_percent < threshold & registry$status == "addressed"] = "pending"
	}
	missing = prior[!prior$file %in% summary$file, , drop = FALSE]
	for (column in setdiff(registry_columns, names(missing))) missing[[column]] = rep("", nrow(missing))
	registry = rbind(registry[, registry_columns, drop = FALSE], missing[, registry_columns, drop = FALSE])
	registry[order(-registry$weighted_opportunity, registry$file, na.last = TRUE), , drop = FALSE]
}

validate_registry = function(registry) {
	if (anyDuplicated(registry$file)) stop("Registry contains duplicate files.", call. = FALSE)
	if (any(!nzchar(registry$file))) stop("Registry contains a blank file path.", call. = FALSE)
	if (any(!registry$category %in% c("straightforward_test", "dispatch_threshold", "dead_or_unreachable", "diagnostic_smoke", "unclassified"))) {
		stop("Registry contains an unknown category.", call. = FALSE)
	}
	if (any(!registry$status %in% c("triage_needed", "pending", "in_progress", "addressed", "excluded"))) {
		stop("Registry contains an unknown status.", call. = FALSE)
	}
	invisible(TRUE)
}

main = function(args = commandArgs(TRUE)) {
	if (!length(args)) {
		stop("Usage: Rscript coverage_gap_registry.R <coverage.rds|coverage.csv> [output.csv] [threshold] [measured_commit] [measured_at]", call. = FALSE)
	}
	input = args[[1L]]
	arg = function(i, default) if (length(args) >= i) args[[i]] else default
	output = arg(2L, default_output)
	threshold = as.numeric(arg(3L, "80"))
	if (!is.finite(threshold) || threshold <= 0 || threshold > 100) stop("threshold must be in (0, 100].", call. = FALSE)
	prior = if (file.exists(output)) read.csv(output, stringsAsFactors = FALSE, na.strings = character()) else empty_registry()
	rows = read_coverage_rows(input)
	provenance = attr(rows, "provenance")
	registry = merge_triage(summarize_coverage(rows), prior, threshold,
		measured_commit = arg(4L, provenance$commit %||% ""),
		measured_at = arg(5L, provenance$measured_at %||% format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")))
	validate_registry(registry)
	write.csv(registry, output, row.names = FALSE, na = "")
	message("Wrote ", nrow(registry), " coverage-gap rows to ", output)
	invisible(registry)
}

if (sys.nframe() == 0L) main()
