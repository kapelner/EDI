#!/usr/bin/env Rscript
# Coverage-floor gate (TODO-9, R/package_metadata/new_feature_plans/
# full_test_coverage.md): fails if aggregate coverage drops below the
# best-ever figure recorded in coverage_baseline.json. On a new high, prints
# instructions to bump the baseline by hand -- mirrors
# check_coverage_registry.R's existing measure-then-human-commits pattern;
# this script never writes the baseline file itself.
args = commandArgs(TRUE)
if (length(args) != 3L) stop("Usage: check_coverage_floor.R MERGED_COVERAGE_RDS BASELINE_JSON LANGUAGE_KEY", call. = FALSE)
report_path = args[[1L]]
baseline_path = args[[2L]]
language_key = args[[3L]]
epsilon = 0.05  # percentage points; avoids failing on float noise between otherwise-identical runs

report = readRDS(report_path)
coverage = if (is.list(report) && !inherits(report, "coverage") && "coverage" %in% names(report)) report$coverage else report
fresh_pct = covr::percent_coverage(coverage)

baseline = jsonlite::fromJSON(baseline_path, simplifyVector = TRUE)
best_pct = baseline[[language_key]]$coverage_pct
if (is.null(best_pct)) best_pct = NA_real_

cat(sprintf("Coverage floor check (%s): fresh = %.2f%%, best-ever = %s\n",
	language_key, fresh_pct,
	if (is.na(best_pct)) "none recorded yet" else sprintf("%.2f%%", best_pct)))

summary_path = Sys.getenv("GITHUB_STEP_SUMMARY")
write_summary = function(line) if (nzchar(summary_path)) cat(line, "\n", sep = "", file = summary_path, append = TRUE)

if (!is.na(best_pct) && fresh_pct < best_pct - epsilon) {
	msg = sprintf("Coverage regressed: %.2f%% is below the best-ever figure of %.2f%% (dropped %.2f points). See R/package_tests/ci/coverage_baseline.json.",
		fresh_pct, best_pct, best_pct - fresh_pct)
	write_summary(paste0("**", msg, "**"))
	stop(msg, call. = FALSE)
}

if (is.na(best_pct) || fresh_pct > best_pct + epsilon) {
	msg = sprintf("New best-ever %s coverage: %.2f%% (previous: %s). Update the \"%s\" entry in R/package_tests/ci/coverage_baseline.json and commit it to raise the floor.",
		language_key, fresh_pct, if (is.na(best_pct)) "none" else sprintf("%.2f%%", best_pct), language_key)
	cat(msg, "\n")
	write_summary(msg)
}
