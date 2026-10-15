# Cross-leg reproducibility comparison for the R-CMD-check workflow's
# repro-compare job (cross_platform_reproducibility.md TODO-4).
#
# Usage: Rscript compare_repro_digests.R <dir-of-leg-csvs>
#
# Each R-CMD-check leg writes one CSV from
# R/EDI/tests/testthat/test-cross-platform-reproducibility-digests.R. This
# script fails (exit 1) when:
#   - a design's seed-pinned draw digest is not identical on every leg and at
#     every thread count;
#   - a float (estimate, CI bound, p-value) differs across legs by more than
#     REPRO_FLOAT_TOL relative to max(1, |median|);
#   - fewer legs reported than REPRO_EXPECTED_LEGS.
# It writes a platform x quantity table to $GITHUB_STEP_SUMMARY when set.
# Base R only, so the job needs no package installs.

args = commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("usage: Rscript compare_repro_digests.R <dir-of-leg-csvs>")
dir = args[[1L]]
expected_legs = as.integer(Sys.getenv("REPRO_EXPECTED_LEGS", "0"))
float_tol = as.numeric(Sys.getenv("REPRO_FLOAT_TOL", "1e-8"))

summary_lines = character()
emit = function(...) {
	line = paste0(...)
	cat(line, "\n", sep = "")
	summary_lines <<- c(summary_lines, line)
}
problems = character()
problem = function(...) problems <<- c(problems, paste0(...))

files = if (dir.exists(dir)) list.files(dir, pattern = "\\.csv$", full.names = TRUE) else character()
rows = do.call(rbind, lapply(files, function(f)
	utils::read.csv(f, stringsAsFactors = FALSE, colClasses = c(value_chr = "character", value_num = "character"))))
legs = if (is.null(rows)) character() else sort(unique(rows$leg))

emit("## Cross-platform reproducibility")
emit("")
emit(length(legs), " leg(s) reported", if (expected_legs > 0L) paste0(" (expected ", expected_legs, ")") else "", ": ",
	if (length(legs)) paste(legs, collapse = ", ") else "none")
if (expected_legs > 0L && length(legs) < expected_legs) {
	problem(expected_legs - length(legs), " leg(s) produced no results; check those legs' logs")
}

if (!is.null(rows) && nrow(rows)) {
	# Integer draws: one digest per design and quantity (w_md5 for the r
	# redraws; w_seq_md5 for a sequential design's one-at-a-time assignment)
	# across every leg and thread count.
	design = rows[rows$kind == "design_draw", , drop = FALSE]
	design$key = paste(design$name, design$quantity, sep = "$")
	emit("")
	emit("### Seed-pinned design draws (md5 of w, first 8 characters)")
	emit("")
	emit("| design | ", paste(legs, collapse = " | "), " | identical |")
	emit("|", paste(rep("---", length(legs) + 2L), collapse = "|"), "|")
	for (key in sort(unique(design$key))) {
		d = design[design$key == key, , drop = FALSE]
		cells = vapply(legs, function(leg) {
			v = unique(d$value_chr[d$leg == leg])
			if (!length(v)) "–" else paste(substr(v, 1L, 8L), collapse = " / ")
		}, character(1))
		same = length(unique(d$value_chr)) == 1L
		if (!same) problem(key, ": draw digest differs across legs or thread counts")
		emit("| ", key, " | ", paste(cells, collapse = " | "), " | ", if (same) "yes" else "**NO**", " |")
	}

	# Thread counts each leg actually obtained (a leg without OpenMP reports 1).
	capped = design[!is.na(design$threads_obtained) & design$threads_obtained < design$threads, , drop = FALSE]
	if (nrow(capped)) {
		emit("")
		emit("Legs where OpenMP ran fewer threads than requested (thread-count invariance not exercised there): ",
			paste(sort(unique(capped$leg)), collapse = ", "))
	}

	# Floats: within tolerance of the cross-leg median.
	floats = rows[rows$kind == "inference_float", , drop = FALSE]
	floats$value = as.numeric(floats$value_num)
	if (nrow(floats)) {
		emit("")
		emit("### Floating-point results (relative tolerance ", format(float_tol), ")")
		emit("")
		emit("| quantity | min | max | max relative spread | within tolerance |")
		emit("|---|---|---|---|---|")
		for (key in unique(paste(floats$name, floats$quantity, sep = "$"))) {
			f = floats[paste(floats$name, floats$quantity, sep = "$") == key, , drop = FALSE]
			mid = stats::median(f$value)
			spread = max(abs(f$value - mid)) / max(1, abs(mid))
			ok = is.finite(spread) && spread <= float_tol
			if (!ok) problem(key, ": cross-leg relative spread ", format(spread), " exceeds ", format(float_tol))
			emit("| ", key, " | ", sprintf("%.17g", min(f$value)), " | ", sprintf("%.17g", max(f$value)), " | ",
				format(spread, digits = 3), " | ", if (ok) "yes" else "**NO**", " |")
		}
	}
}

emit("")
if (length(problems)) {
	emit("### Failures")
	emit("")
	for (p in problems) emit("- ", p)
} else {
	emit("All legs agree.")
}

step_summary = Sys.getenv("GITHUB_STEP_SUMMARY")
if (nzchar(step_summary)) cat(summary_lines, file = step_summary, sep = "\n", append = TRUE)
if (length(problems)) quit(status = 1L)
