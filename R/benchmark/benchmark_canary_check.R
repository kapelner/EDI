#!/usr/bin/env Rscript
# Nightly self-test of the benchmark regression check (release_v1_1_0.md TODO-195,
# plan Phase 4: a known slowdown must be detected). Base R only, no EDI.
#
# Takes the night's four real reports of one section (A1, A2 = last release;
# B1, B2 = current commit), picks one row that is stable on this runner, makes it
# 3x slower in copies of B1 and B2 (in memory, at the parsed level), and runs the
# same comparison and verdict the `bench` job uses. The injected row must fail;
# if it does not, the check could not see a real regression either, and this
# script fails with "Benchmark CI bug". Untouched rows are not judged here.
#
# Usage: benchmark_canary_check.R <A1.md> <A2.md> <B1.md> <B2.md> <section>
# Exit status: 0 detected (or no usable row, with a warning), 1 not detected, 2 usage/input error.

benchmark_canary_main = function(args = commandArgs(trailingOnly = TRUE)) {
	if (length(args) != 5L) {
		message("usage: benchmark_canary_check.R <A1.md> <A2.md> <B1.md> <B2.md> <section>")
		return(2L)
	}
	script_arg = grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]
	here = if (is.na(script_arg)) "benchmark" else dirname(sub("^--file=", "", script_arg))
	env = new.env()
	sys.source(file.path(here, "compare_benchmark_runs.R"), envir = env)
	sys.source(file.path(here, "benchmark_abba_verdict.R"), envir = env)
	section = args[[5L]]
	rd = function(f) env$parse_benchmark_report(readLines(f, warn = FALSE), f)
	r = lapply(args[1:4], rd)
	names(r) = c("A1", "A2", "B1", "B2")
	cmp = function(o, n) env$compare_benchmark_reports(o, n, ratio = 1.25, min_delta_ms = 0.05,
	                                                    normalize_host = TRUE, sections = section, parts = "R")$rows
	noise_a = cmp(r$A1, r$A2)
	noise_b = cmp(r$B1, r$B2)
	stable = intersect(noise_a$key[noise_a$status == "ok"], noise_b$key[noise_b$status == "ok"])
	timed = function(d) d$key[d$section == section & d$part == "R" & is.finite(d$edi_ms) & d$edi_ms >= 1]
	cand = Reduce(intersect, list(stable, timed(r$A1), timed(r$A2), timed(r$B1), timed(r$B2)))
	if (!length(cand)) {
		cat(sprintf("::warning title=Benchmark canary::%s: no row is timed on both sides and stable on this runner; detection not tested tonight.\n", section))
		return(0L)
	}
	ms = r$B1$edi_ms[match(cand, r$B1$key)]
	k = cand[order(ms)][ceiling(length(cand) / 2)]  # the median-time stable row
	slow = function(d) { d$edi_ms[d$key == k] = 3 * d$edi_ms[d$key == k]; d }
	v = env$benchmark_abba_verdict(noise_a, noise_b, cmp(r$A1, slow(r$B1)), cmp(r$A2, slow(r$B2)))
	msg = sprintf("%s: injected a 3x slowdown into '%s' (%.4g ms)", section, k, ms[match(k, cand)])
	summary_file = Sys.getenv("GITHUB_STEP_SUMMARY")
	if (k %in% v$failing) {
		line = paste0("Benchmark canary: ", msg, ", and the check flagged it.")
		cat(line, "\n", sep = "")
		if (nzchar(summary_file)) cat(line, "\n", file = summary_file, append = TRUE, sep = "")
		return(0L)
	}
	cat(sprintf("::error title=Benchmark CI bug::%s, but the check did NOT flag it; it cannot be trusted to catch a real regression.\n", msg))
	1L
}

if (sys.nframe() == 0L) {
	status = tryCatch(benchmark_canary_main(), error = function(e) {
		message("benchmark_canary_check.R: ", conditionMessage(e))
		2L
	})
	quit(save = "no", status = status)
}
