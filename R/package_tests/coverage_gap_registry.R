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
	"baseline_commit", "measured_at", "notes"
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
	if (grepl("\\.rds$", path, ignore.case = TRUE)) {
		coverage = readRDS(path)
		rows = tryCatch(as.data.frame(coverage), error = function(e) {
			stop("Could not convert the saved coverage object with as.data.frame(): ", conditionMessage(e), call. = FALSE)
		})
	} else {
		rows = read.csv(path, stringsAsFactors = FALSE, na.strings = c("NA"))
	}
	filename_col = intersect(c("filename", "file"), names(rows))
	value_col = intersect(c("value", "hits", "count"), names(rows))
	if (!length(filename_col) || !length(value_col)) {
		stop("Coverage rows need filename/file and value/hits/count columns.", call. = FALSE)
	}
	rows$file = as.character(rows[[filename_col[[1L]]]])
	rows$value = suppressWarnings(as.numeric(rows[[value_col[[1L]]]]))
	rows = rows[!is.na(rows$value) & nzchar(rows$file), c("file", "value"), drop = FALSE]
	rows$file = normalize_coverage_path(rows$file)
	rows[nzchar(rows$file), , drop = FALSE]
}

normalize_coverage_path = function(path) {
	path = gsub("\\\\", "/", path)
	path = sub("^.*/R/EDI/", "R/EDI/", path)
	path = ifelse(grepl("^R/EDI/", path), path,
		ifelse(grepl("^(R|src)/", path), paste0("R/EDI/", path), path))
	path
}

summarize_coverage = function(rows, threshold = 80) {
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
	out = out[is.na(out$coverage_percent) | out$coverage_percent < threshold, , drop = FALSE]
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

merge_triage = function(summary, prior = empty_registry()) {
	triage = t(vapply(seq_len(nrow(summary)), function(i) {
		default_triage(summary$file[[i]], summary$coverage_percent[[i]])
	}, character(4L)))
	registry = cbind(summary, as.data.frame(triage, stringsAsFactors = FALSE))
	registry$baseline_commit = ""
	registry$measured_at = ""
	if (nrow(prior)) {
		matched = match(registry$file, prior$file)
		keep = !is.na(matched)
		for (column in c("category", "owning_todo", "status", "baseline_commit", "measured_at", "notes")) {
			old = as.character(prior[[column]][matched[keep]])
			nonblank = !is.na(old) & nzchar(old)
			registry[[column]][which(keep)[nonblank]] = old[nonblank]
		}
	}
	registry[, registry_columns, drop = FALSE]
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
		stop("Usage: Rscript coverage_gap_registry.R <coverage.rds|coverage.csv> [output.csv] [threshold]", call. = FALSE)
	}
	input = args[[1L]]
	output = args[[2L]] %||% default_output
	threshold = as.numeric(args[[3L]] %||% "80")
	if (!is.finite(threshold) || threshold <= 0 || threshold > 100) stop("threshold must be in (0, 100].", call. = FALSE)
	prior = if (file.exists(output)) read.csv(output, stringsAsFactors = FALSE, na.strings = character()) else empty_registry()
	registry = merge_triage(summarize_coverage(read_coverage_rows(input), threshold), prior)
	registry$measured_at[!nzchar(registry$measured_at)] = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
	validate_registry(registry)
	write.csv(registry, output, row.names = FALSE, na = "")
	message("Wrote ", nrow(registry), " coverage-gap rows to ", output)
	invisible(registry)
}

if (sys.nframe() == 0L) main()
