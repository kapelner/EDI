#!/usr/bin/env Rscript
# Pure report-processing regression checks: no EDI load/install/build.
source("R/package_tests/coverage_gap_registry.R")
work = tempfile("registry-tests-")
dir.create(work)
input = file.path(work, "lines.csv")
write.csv(data.frame(filename = c("R/a.R", "R/a.R", "R/a.R", "R/b.R"),
	line = c(1L, 1L, 2L, 1L), value = c(0, 1, 1, 0)), input, row.names = FALSE)
rows = read_coverage_rows(input)
s = summarize_coverage(rows)
stopifnot(s$coverage_percent[s$file == "R/EDI/R/a.R"] == 100,
	s$coverable_lines[s$file == "R/EDI/R/a.R"] == 2)
prior = merge_triage(s, threshold = 100, measured_commit = "old", measured_at = "old-time")
prior$status = "in_progress"
prior$notes = "retain this work"
prior$baseline_commit = "baseline"
new = merge_triage(s, prior, threshold = 80, measured_commit = "new", measured_at = "new-time")
stopifnot(new$measured_commit == "new", new$measured_at == "new-time",
	new$baseline_commit == "baseline", new$notes == "retain this work")
# Crossing the threshold retains the file as addressed, and regression reopens it.
prior = new
prior$file = "R/EDI/R/a.R"
new = merge_triage(s, prior, measured_commit = "new")
stopifnot(new$status[new$file == prior$file] == "addressed")
s$coverage_percent[s$file == prior$file] = 50
new = merge_triage(s, new)
stopifnot(new$status[new$file == prior$file] == "pending")
empty = data.frame(filename = character(), line = integer(), value = numeric())
write.csv(empty, file.path(work, "empty.csv"), row.names = FALSE)
stopifnot(nrow(merge_triage(summarize_coverage(read_coverage_rows(file.path(work, "empty.csv"))))) == 0,
	nrow(merge_triage(summarize_coverage(rows[rows$file == "R/EDI/R/a.R", ]))) == 0)
retained = merge_triage(summarize_coverage(read_coverage_rows(file.path(work, "empty.csv"))), prior)
stopifnot(identical(retained$measured_at, prior$measured_at))
wrapper = file.path(work, "wrapper.rds")
saveRDS(list(coverage = data.frame(filename = "R/b.R", line = 1L, value = 0),
	commit = "report-commit", measured_at = "report-time", shard = 1L), wrapper)
x = main(c(wrapper, file.path(work, "out.csv")))
stopifnot(x$measured_commit == "report-commit", x$measured_at == "report-time")
x = main(c(wrapper, file.path(work, "out.csv"), "80", "override", "override-time"))
stopifnot(x$measured_commit == "override", x$measured_at == "override-time")
# Real CLI checks for one/two arguments, isolating the default output location.
script = file.path(work, "coverage_gap_registry.R")
file.copy("R/package_tests/coverage_gap_registry.R", script)
for (args in list(c(script, input), c(script, input, file.path(work, "explicit.csv")))) {
	stopifnot(system2(file.path(R.home("bin"), "Rscript"), shQuote(args)) == 0L)
}
stopifnot(file.exists(file.path(work, "coverage_gap_registry.csv")))
# Expression CSVs expand ranges before counting physical lines.
expr = file.path(work, "expressions.csv")
write.csv(data.frame(filename = c("R/c.R", "R/c.R"), functions = c("f", "g"),
	first_line = c(1L, 1L), last_line = c(2L, 1L), value = c(1, 0)), expr, row.names = FALSE)
stopifnot(summarize_coverage(read_coverage_rows(expr))$coverage_percent == 100)
# Bare and empty covr objects are supported, without loading EDI.
saveRDS(structure(list(), class = "coverage"), file.path(work, "empty.rds"))
stopifnot(nrow(read_coverage_rows(file.path(work, "empty.rds"))) == 0)
# Exercise the actual covr object format, not just a data-frame report wrapper.
# Two closures share line 1; the covered closure spans lines 1 and 2.
sf = srcfilecopy("R/native.R", c("a", "b"))
counter = function(span, value, name) structure(list(
	srcref = srcref(sf, span), value = value, functions = name
), class = "line_coverage")
coverage = structure(list(
	counter(c(1L, 1L, 2L, 1L, 1L, 1L, 1L, 2L), 1, "covered"),
	counter(rep(1L, 8L), 0, "uncovered")
), class = "coverage")
bare = file.path(work, "bare.rds")
saveRDS(coverage, bare)
physical = summarize_coverage(read_coverage_rows(bare))
stopifnot(physical$coverable_lines == 2L, physical$covered_lines == 2L,
	physical$coverage_percent == 100)
saveRDS(list(coverage = coverage, commit = "real-covr-commit",
	measured_at = "real-covr-time", shard = 2L), wrapper)
wrapped = read_coverage_rows(wrapper)
stopifnot(identical(summarize_coverage(wrapped), physical),
	identical(attr(wrapped, "provenance")$commit, "real-covr-commit"))
# Restore the drift fixture used below.
saveRDS(list(coverage = data.frame(filename = "R/b.R", line = 1L, value = 0),
	commit = "report-commit", measured_at = "report-time", shard = 1L), wrapper)
# Invalid thresholds must fail before creating a registry output.
invalid_output = file.path(work, "invalid-threshold.csv")
for (threshold in c("0", "101", "NA", "not-a-number")) {
	result = suppressWarnings(tryCatch(main(c(input, invalid_output, threshold)),
		error = identity))
	stopifnot(inherits(result, "error"), !file.exists(invalid_output))
}
# Empty CLI input and historical rows with unknown line counts remain usable.
historical = file.path(work, "historical.csv")
file.copy("R/package_tests/coverage_gap_registry.csv", historical)
x = main(c(file.path(work, "empty.csv"), historical))
stopifnot(nrow(x) == nrow(read.csv("R/package_tests/coverage_gap_registry.csv")))
# A partial report must not erase unmeasured history or its provenance, while
# tracked fully covered files remain addressed and manual exclusions survive.
history = merge_triage(summarize_coverage(rows), prior = data.frame(file = unique(rows$file)),
	measured_commit = "baseline-commit", measured_at = "baseline-time")
history$status[history$file == "R/EDI/R/b.R"] = "excluded"
partial = merge_triage(summarize_coverage(rows[rows$file == "R/EDI/R/a.R", ]),
	history, measured_commit = "partial-commit", measured_at = "partial-time")
absent = partial[partial$file == "R/EDI/R/b.R", ]
stopifnot(nrow(partial) == 2L, absent$status == "excluded",
	absent$measured_commit == "baseline-commit", absent$measured_at == "baseline-time",
	partial$status[partial$file == "R/EDI/R/a.R"] == "addressed")
tracked = file.path(work, "out.csv")
drift_dir = file.path(work, "drift")
check = function() stopifnot(system2(file.path(R.home("bin"), "Rscript"),
	shQuote(c("R/package_tests/ci/check_coverage_registry.R", wrapper, tracked, drift_dir))) == 0L)
check()
stopifnot(any(grepl("matches", readLines(file.path(drift_dir, "coverage-registry-drift.txt")))))
saveRDS(list(coverage = data.frame(filename = "R/b.R", line = 1L, value = 1),
	commit = "later", measured_at = "later-time"), wrapper)
check()
stopifnot(any(grepl("differs", readLines(file.path(drift_dir, "coverage-registry-drift.txt")))))
cat("Coverage registry regression checks passed.\n")
