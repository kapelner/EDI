#!/usr/bin/env Rscript
# Gate for the scheduled CI calibration fast tier (design:
# R/package_metadata/new_feature_plans/calibration_gates.md). Merges the
# rows.csv of every shard under --in-dir and tests each cell
# (response type x design x class x formula x method x n):
#
#   size      H0: size <= 0.05 vs size > 0.05      exact one-sided binomial
#   coverage  H0: coverage >= 0.95 vs < 0.95       exact one-sided binomial
#             (anti-conservative only; a conservative interval passes)
#
# Under the sharp null every replicate's truth is the class's null value, so
# size = share of finite p-values below 0.05 and coverage = share of finite CIs
# containing the null value. A cell needs >= 30 finite results for a test to
# run. Bonferroni across the whole run: each test at 0.01 / K, K = number of
# size tests + number of coverage tests run.
#
# Accepted deviations (calibration_fast_tier_accepted.csv): a cell triaged as
# honest small-sample behaviour is re-tested against its ACCEPTED level instead
# of 0.05 / 0.95 -- same one-sided exact test, same 0.01 / K -- so it reopens
# only when it becomes significantly worse than what was accepted.
#
# Also reported, never gated: size at alpha = 0.10 (from the same p-values) and
# yield (share of replicates with a finite result).
#
# Usage: Rscript R/package_tests/calibration/analyze_calibration_fast_tier.R \
#          --in-dir DIR --out-dir DIR [--accepted FILE] [--summary-md FILE]
# Exits 1 when any test fails.

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
args <- commandArgs(TRUE)
arg_value <- function(flag, default = NULL) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
in_dir <- arg_value("--in-dir")
out_dir <- arg_value("--out-dir")
accepted_path <- arg_value("--accepted", file.path(script_dir, "calibration_fast_tier_accepted.csv"))
summary_md <- arg_value("--summary-md")
FAMILY_ALPHA <- 0.01
MIN_FINITE <- 30L
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

files <- list.files(in_dir, pattern = "^rows\\.csv$", recursive = TRUE, full.names = TRUE)
if (!length(files)) stop("no rows.csv under ", in_dir)
d <- do.call(rbind, lapply(files, utils::read.csv, stringsAsFactors = FALSE, colClasses = c(formula = "character")))
d$formula[is.na(d$formula)] <- ""

cell_cols <- c("response_type", "design", "inference_class", "method", "formula", "n")
cell_key <- do.call(paste, c(d[cell_cols], sep = "\r"))
cells <- lapply(split(seq_len(nrow(d)), cell_key), function(idx) {
	x <- d[idx, ]
	fin_p <- is.finite(x$pval)
	fin_ci <- is.finite(x$ci_a) & is.finite(x$ci_b)
	covers <- fin_ci & x$ci_a <= x$null_value & x$null_value <= x$ci_b
	data.frame(x[1L, cell_cols], reps = nrow(x),
		n_p = sum(fin_p), rej = sum(x$pval[fin_p] < 0.05), rej10 = sum(x$pval[fin_p] < 0.10),
		n_ci = sum(fin_ci), cov = sum(covers[fin_ci]),
		median_fit_secs = stats::median(x$fit_secs, na.rm = TRUE), stringsAsFactors = FALSE)
})
s <- do.call(rbind, cells)
rownames(s) <- NULL
s$size <- ifelse(s$n_p > 0, s$rej / s$n_p, NA_real_)
s$size_10 <- ifelse(s$n_p > 0, s$rej10 / s$n_p, NA_real_)
s$coverage <- ifelse(s$n_ci > 0, s$cov / s$n_ci, NA_real_)
s$yield <- pmax(s$n_p, s$n_ci) / s$reps

# Null levels: nominal, unless the cell has an accepted deviation.
s$size_null <- 0.05
s$coverage_null <- 0.95
s$accepted <- ""
if (file.exists(accepted_path)) {
	acc <- utils::read.csv(accepted_path, stringsAsFactors = FALSE, colClasses = c(formula = "character"))
	acc$formula[is.na(acc$formula)] <- ""
	for (i in seq_len(nrow(acc))) {
		a <- acc[i, ]
		hit <- s$response_type == a$response_type & s$design == a$design & s$inference_class == a$inference_class &
			s$method == a$method & s$formula == a$formula & s$n == a$n
		if (!any(hit)) next
		if (a$metric == "size") s$size_null[hit] <- a$accepted_level
		if (a$metric == "coverage") s$coverage_null[hit] <- a$accepted_level
		s$accepted[hit] <- trimws(paste(s$accepted[hit], a$metric))
	}
}

s$p_size <- ifelse(s$n_p >= MIN_FINITE,
	stats::pbinom(s$rej - 1L, s$n_p, s$size_null, lower.tail = FALSE), NA_real_)
s$p_coverage <- ifelse(s$n_ci >= MIN_FINITE, stats::pbinom(s$cov, s$n_ci, s$coverage_null), NA_real_)
K <- sum(!is.na(s$p_size)) + sum(!is.na(s$p_coverage))
threshold <- FAMILY_ALPHA / max(K, 1L)
s$fail_size <- !is.na(s$p_size) & s$p_size < threshold
s$fail_coverage <- !is.na(s$p_coverage) & s$p_coverage < threshold
s <- s[order(!(s$fail_size | s$fail_coverage), s$response_type, s$inference_class, s$method, s$formula, s$n), ]
utils::write.csv(s, file.path(out_dir, "calibration_summary.csv"), row.names = FALSE)

fails <- s[s$fail_size | s$fail_coverage, ]
fmt <- function(x, d = 3) ifelse(is.na(x), "", formatC(x, digits = d, format = "fg"))
md <- c("## Calibration fast tier",
	"",
	sprintf("%d rows, %d cells, K = %d tests, per-test alpha = 0.01 / K = %.2g. Failures: **%d**.",
		nrow(d), nrow(s), K, threshold, nrow(fails)),
	"")
if (nrow(fails)) {
	md <- c(md, "| response | design | class | method | formula | n | size | coverage | finite | p (size) | p (coverage) | accepted |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|",
		sprintf("| %s | %s | %s | %s | %s | %d | %s%s | %s%s | %d/%d | %s | %s | %s |",
			fails$response_type, sub("^DesignFixed", "", fails$design), sub("^Inference", "", fails$inference_class),
			fails$method, fails$formula, fails$n, fmt(fails$size), ifelse(fails$fail_size, " **FAIL**", ""),
			fmt(fails$coverage), ifelse(fails$fail_coverage, " **FAIL**", ""), pmax(fails$n_p, fails$n_ci), fails$reps,
			fmt(fails$p_size, 2), fmt(fails$p_coverage, 2), fails$accepted), "")
}
low_yield <- s[s$yield < 0.8, ]
if (nrow(low_yield)) {
	md <- c(md, sprintf("Low yield (< 80%% finite, reported only): %s", paste(sprintf("%s %s %s %s n=%d (%.0f%%)",
		low_yield$response_type, sub("^Inference", "", low_yield$inference_class), low_yield$method, low_yield$formula,
		low_yield$n, 100 * low_yield$yield), collapse = "; ")), "")
}
md <- c(md, "Full table: `calibration_summary.csv` in this run's artifacts.")
writeLines(md, file.path(out_dir, "calibration_summary.md"))
if (!is.null(summary_md)) cat(md, sep = "\n", file = summary_md, append = TRUE)
cat(md, sep = "\n")
quit(status = if (nrow(fails)) 1L else 0L)
