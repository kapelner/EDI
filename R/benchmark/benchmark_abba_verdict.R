#!/usr/bin/env Rscript
# Verdict for the nightly benchmark regression check (.github/workflows/nightly.yml,
# `bench` job; release_v1_1_0.md TODO-195). Base R only.
#
# The job times one benchmark section four times on one runner, alternating the
# last release (A) and the current commit (B) in the order A1 B1 B2 A2, and runs
# compare_benchmark_runs.R on four pairs, each with --tsv:
#   noise_a  A1 vs A2   same code twice: any change is runner noise
#   noise_b  B1 vs B2   same code twice
#   cmp_1    A1 vs B1   release vs current
#   cmp_2    A2 vs B2   release vs current
# A row FAILS when it is an unexplained "regression" or "lost" row in BOTH cmp_1
# and cmp_2, and it is not noisy: its status in noise_a and noise_b is "ok"
# (a row that regressed or improved between two runs of the same code cannot be
# judged this run). Rows that fail in only one of cmp_1/cmp_2 are reported as
# "inconsistent", not failed.
#
# Usage: benchmark_abba_verdict.R <noise_a.tsv> <noise_b.tsv> <cmp_1.tsv> <cmp_2.tsv> [label]
# Exit status: 0 no failing row, 1 at least one, 2 usage or input error.
# Appends a markdown table to $GITHUB_STEP_SUMMARY when it is set.

benchmark_abba_read = function(path) {
	d = utils::read.delim(path, stringsAsFactors = FALSE, na.strings = "NA", check.names = FALSE)
	need = c("key", "label", "status", "explained", "edi_ms_old", "edi_ms_new", "adj_ratio")
	miss = setdiff(need, names(d))
	if (length(miss)) stop(path, " lacks column(s): ", paste(miss, collapse = ", "), call. = FALSE)
	d$explained = as.logical(d$explained)
	d$explained[is.na(d$explained)] = FALSE
	d
}

benchmark_abba_verdict = function(noise_a, noise_b, cmp_1, cmp_2) {
	bad = function(d) d$key[d$status %in% c("regression", "lost") & !d$explained]
	noisy = function(d) d$key[!d$status %in% c("ok", "na-both", "added", "removed")]
	in_1 = bad(cmp_1)
	in_2 = bad(cmp_2)
	noisy_keys = union(noisy(noise_a), noisy(noise_b))
	both = intersect(in_1, in_2)
	list(
		failing = setdiff(both, noisy_keys),
		noisy_skipped = intersect(both, noisy_keys),
		inconsistent = setdiff(union(in_1, in_2), both),
		n_noisy = length(noisy_keys),
		n_compared = sum(cmp_1$status %in% c("ok", "improved", "regression", "lost"))
	)
}

benchmark_abba_main = function(args = commandArgs(trailingOnly = TRUE)) {
	if (length(args) < 4L) {
		message("usage: benchmark_abba_verdict.R <noise_a.tsv> <noise_b.tsv> <cmp_1.tsv> <cmp_2.tsv> [label]")
		return(2L)
	}
	label = if (length(args) >= 5L) args[[5L]] else "benchmark"
	d = lapply(args[1:4], benchmark_abba_read)
	v = benchmark_abba_verdict(d[[1]], d[[2]], d[[3]], d[[4]])
	row_of = function(k) {
		r1 = d[[3]][match(k, d[[3]]$key), ]
		r2 = d[[4]][match(k, d[[4]]$key), ]
		sprintf("| %s | %.4g | %.4g | %.2f | %.2f |", r1$label, r1$edi_ms_old, r1$edi_ms_new, r1$adj_ratio, r2$adj_ratio)
	}
	lines = c(
		sprintf("### Benchmark regression check: %s", label),
		"",
		sprintf("%d rows compared; %d too noisy on this runner to judge (moved between two runs of the same code).",
		        v$n_compared, v$n_noisy)
	)
	if (length(v$failing)) {
		lines = c(lines, "", sprintf("**%d regression(s)** (slower in both release-vs-current comparisons, not noisy):", length(v$failing)),
		          "", "| row | release ms | current ms | ratio 1 | ratio 2 |", "|---|---|---|---|---|",
		          vapply(v$failing, row_of, character(1)))
	} else {
		lines = c(lines, "", "No regression.")
	}
	if (length(v$inconsistent)) {
		lines = c(lines, "", sprintf("%d row(s) slower in only one of the two comparisons (not failed): %s",
		                             length(v$inconsistent), paste(head(v$inconsistent, 10L), collapse = "; ")))
	}
	if (length(v$noisy_skipped)) {
		lines = c(lines, "", sprintf("%d row(s) slower in both but noisy (not failed): %s",
		                             length(v$noisy_skipped), paste(head(v$noisy_skipped, 10L), collapse = "; ")))
	}
	cat(lines, sep = "\n")
	cat("\n")
	summary_file = Sys.getenv("GITHUB_STEP_SUMMARY")
	if (nzchar(summary_file)) cat(lines, "", file = summary_file, sep = "\n", append = TRUE)
	for (k in v$failing) {
		r = d[[3]][match(k, d[[3]]$key), ]
		cat(sprintf("::error title=Benchmark regression::%s: %s: release %.4g ms, current %.4g ms\n", label, r$label, r$edi_ms_old, r$edi_ms_new))
	}
	if (length(v$failing)) 1L else 0L
}

if (sys.nframe() == 0L) {
	status = tryCatch(benchmark_abba_main(), error = function(e) {
		message("benchmark_abba_verdict.R: ", conditionMessage(e))
		2L
	})
	quit(save = "no", status = status)
}
