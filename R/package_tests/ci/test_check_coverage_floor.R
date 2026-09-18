#!/usr/bin/env Rscript
# Pure regression checks for check_coverage_floor.R: no EDI load/install/
# build, and no real covr instrumentation -- a hand-built covr "coverage"
# object (same technique as test_coverage_gap_registry.R) gives a known
# percentage to check the floor logic against.
`%||%` = function(x, y) if (is.null(x)) y else x
work = tempfile("coverage-floor-tests-")
dir.create(work)

make_coverage = function(covered, total) {
	# One synthetic file with `total` lines, `covered` of them hit once.
	sf = srcfilecopy("R/synthetic.R", rep("x", total))
	counter = function(line, value) structure(list(
		srcref = srcref(sf, c(line, 1L, line, 1L)), value = value, functions = "f"
	), class = "line_coverage")
	structure(lapply(seq_len(total), function(i) counter(i, as.numeric(i <= covered))), class = "coverage")
}

write_report = function(covered, total, path) saveRDS(make_coverage(covered, total), path)
write_baseline = function(r_pct, py_pct, path) {
	fmt = function(x) if (is.null(x)) "null" else as.character(x)
	writeLines(sprintf('{"r": {"coverage_pct": %s, "commit": "prev", "measured_at": "prev-time"}, "python": {"coverage_pct": %s, "commit": null, "measured_at": null}}',
		fmt(r_pct), fmt(py_pct)), path)
}

run = function(report, baseline, key) {
	out = suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
		shQuote(c("R/package_tests/ci/check_coverage_floor.R", report, baseline, key)),
		stdout = TRUE, stderr = TRUE))
	list(status = attr(out, "status") %||% 0L, output = out)
}

# Regression: 40% fresh vs. 60% baseline must fail loudly.
report = file.path(work, "regressed.rds"); write_report(2, 5, report)
baseline = file.path(work, "baseline.json"); write_baseline(60, NULL, baseline)
res = run(report, baseline, "r")
stopifnot(res$status != 0L, any(grepl("regressed", res$output, ignore.case = TRUE)))

# Improvement: 80% fresh vs. 60% baseline must pass and announce a new high.
report = file.path(work, "improved.rds"); write_report(4, 5, report)
res = run(report, baseline, "r")
stopifnot(res$status == 0L, any(grepl("New best-ever", res$output)))

# No prior baseline (python still null): any measurement passes and is
# reported as a new high, never a regression.
res = run(report, baseline, "python")
stopifnot(res$status == 0L, any(grepl("New best-ever", res$output)),
	!any(grepl("regressed", res$output, ignore.case = TRUE)))

# Within epsilon of the baseline: neither a regression nor a new high.
baseline_tight = file.path(work, "baseline-tight.json"); write_baseline(80, NULL, baseline_tight)
res = run(report, baseline_tight, "r")
stopifnot(res$status == 0L, !any(grepl("regressed|New best-ever", res$output)))

# GITHUB_STEP_SUMMARY receives the same message.
summary = file.path(work, "summary.md")
Sys.setenv(GITHUB_STEP_SUMMARY = summary)
res = run(file.path(work, "regressed.rds"), baseline, "r")
Sys.unsetenv("GITHUB_STEP_SUMMARY")
stopifnot(res$status != 0L, any(grepl("regressed", readLines(summary), ignore.case = TRUE)))

cat("Coverage floor check regression checks passed.\n")
