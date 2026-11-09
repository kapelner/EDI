#!/usr/bin/env Rscript
# Analysis of the published calibration study (release_v1_2_0.md TODO-36), from a
# campaign's running totals (calibration_study_stats.R), never from raw rows. Same
# tests as analyze_calibration_fast_tier.R:
#
#   size      H0: size <= 0.05 vs > 0.05        exact one-sided binomial
#   coverage  H0: coverage >= 0.95 vs < 0.95     exact one-sided binomial
#   Bonferroni over the run: each test at 0.01 / K, K = number of tests run (cells
#   with >= 30 finite results); a row of --accepted re-tests its cell against the
#   accepted level instead of 0.05 / 0.95.
#
# Reported, never gated: size at 0.10, yield, null bias (mean of estimate - null
# value, SD, bias / SD, z-test; share of estimates below the null value with an
# exact sign test, a median-unbiasedness check that, unlike a median, merges across
# waves), power (share of p < 0.05 under each power effect), and the null p-value
# calibration curve P(p <= u) - u at the u grid of calibration_study_stats.R.
#
# Outputs in --out-dir: calibration_summary.csv, null_bias_summary.csv,
# power_summary.csv, pvalue_curves.csv, calibration_summary.md, gate_failures.txt.
#
# Usage: Rscript R/package_tests/calibration/analyze_calibration_study.R --stats-dir DIR \
#          --out-dir DIR [--accepted FILE] [--title TEXT] [--note TEXT] [--summary-md FILE]
# --stats-dir holds tests.csv.gz and est.csv.gz.

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
source(file.path(script_dir, "calibration_study_stats.R"))
args <- commandArgs(TRUE)
arg_value <- function(flag, default = NULL) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
stats_dir <- arg_value("--stats-dir")
out_dir <- arg_value("--out-dir")
accepted_path <- arg_value("--accepted", file.path(script_dir, "calibration_study_accepted.csv"))
title <- arg_value("--title", "EDI calibration study")
note <- arg_value("--note", "")
summary_md <- arg_value("--summary-md")
FAMILY_ALPHA <- 0.01
MIN_FINITE <- 30L
NULL_BIAS_STD_FLAG <- 0.1
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

tests <- cal_stats_prepare(cal_stats_read(file.path(stats_dir, "tests.csv.gz")))
est <- cal_stats_prepare(cal_stats_read(file.path(stats_dir, "est.csv.gz")))
cell_cols <- c(setdiff(CAL_STATS_CELL, "effect_label"), "method")

# Size and coverage (null).
s <- tests[tests$effect_label == "null", ]
s$size <- ifelse(s$n_p > 0, s$rej / s$n_p, NA_real_)
s$size_10 <- ifelse(s$n_p > 0, s$rej10 / s$n_p, NA_real_)
s$coverage <- ifelse(s$n_ci > 0, s$cov / s$n_ci, NA_real_)
s$yield <- pmax(s$n_p, s$n_ci) / s$reps
s$mean_fit_secs <- s$fit_secs / s$reps
s$size_null <- 0.05
s$coverage_null <- 0.95
s$accepted <- ""
if (file.exists(accepted_path)) {
	acc <- utils::read.csv(accepted_path, stringsAsFactors = FALSE, colClasses = c(formula = "character"))
	acc$formula[is.na(acc$formula)] <- ""
	for (i in seq_len(nrow(acc))) {
		a <- acc[i, ]
		hit <- s$response_type == a$response_type & s$design == a$design & s$prob_T == a$prob_T &
			s$inference_class == a$inference_class & s$method == a$method & s$formula == a$formula & s$n == a$n
		if (!any(hit)) next
		if (a$metric == "size") s$size_null[hit] <- a$accepted_level
		if (a$metric == "coverage") s$coverage_null[hit] <- a$accepted_level
		s$accepted[hit] <- trimws(paste(s$accepted[hit], a$metric))
	}
}
s$p_size <- ifelse(s$n_p >= MIN_FINITE, stats::pbinom(s$rej - 1, s$n_p, s$size_null, lower.tail = FALSE), NA_real_)
s$p_coverage <- ifelse(s$n_ci >= MIN_FINITE, stats::pbinom(s$cov, s$n_ci, s$coverage_null), NA_real_)
K <- sum(!is.na(s$p_size)) + sum(!is.na(s$p_coverage))
threshold <- FAMILY_ALPHA / max(K, 1L)
s$fail_size <- !is.na(s$p_size) & s$p_size < threshold
s$fail_coverage <- !is.na(s$p_coverage) & s$p_coverage < threshold
s <- s[order(!(s$fail_size | s$fail_coverage), s$response_type, s$inference_class, s$method, s$formula, s$n, s$design), ]
ucols <- cal_stats_u_cols()
utils::write.csv(s[setdiff(names(s), ucols)], file.path(out_dir, "calibration_summary.csv"), row.names = FALSE)

# P-value calibration curves (null).
pc <- do.call(rbind, lapply(seq_along(CAL_STATS_U), function(j) {
	data.frame(s[cell_cols], u = CAL_STATS_U[[j]], dev = ifelse(s$n_p > 0, s[[ucols[[j]]]] / s$n_p - CAL_STATS_U[[j]], NA_real_),
		n_p = s$n_p, stringsAsFactors = FALSE)
}))
utils::write.csv(pc, file.path(out_dir, "pvalue_curves.csv"), row.names = FALSE)

# Null bias.
b <- est[est$effect_label == "null", ]
b$nonfinite_share <- 1 - b$n_est / b$reps
b$null_bias <- ifelse(b$n_est > 0, b$sum_d / b$n_est, NA_real_)
b$null_bias_sd <- ifelse(b$n_est > 1, sqrt(pmax(b$sum_d2 - b$n_est * b$null_bias^2, 0) / (b$n_est - 1)), NA_real_)
b$null_bias_se <- b$null_bias_sd / sqrt(b$n_est)
b$null_bias_std <- ifelse(is.finite(b$null_bias_sd) & b$null_bias_sd > 0, b$null_bias / b$null_bias_sd, NA_real_)
b$p_null_bias <- ifelse(b$n_est >= MIN_FINITE & is.finite(b$null_bias_se) & b$null_bias_se > 0,
	2 * stats::pnorm(-abs(b$null_bias / b$null_bias_se)), NA_real_)
nb <- b$n_below + b$n_above
b$share_below_null <- ifelse(nb > 0, b$n_below / nb, NA_real_)
b$p_sign <- ifelse(nb >= MIN_FINITE, pmin(1, 2 * stats::pbinom(pmin(b$n_below, b$n_above), nb, 0.5)), NA_real_)
K_bias <- sum(!is.na(b$p_null_bias))
threshold_bias <- FAMILY_ALPHA / max(K_bias, 1L)
b$flag_null_bias <- !is.na(b$p_null_bias) & b$p_null_bias < threshold_bias & abs(b$null_bias_std) > NULL_BIAS_STD_FLAG
b <- b[order(!b$flag_null_bias, -abs(ifelse(is.na(b$null_bias_std), 0, b$null_bias_std))), ]
utils::write.csv(b, file.path(out_dir, "null_bias_summary.csv"), row.names = FALSE)

# Power.
pw <- tests[tests$effect_label != "null", ]
if (nrow(pw)) {
	pw$power <- ifelse(pw$n_p > 0, pw$rej / pw$n_p, NA_real_)
	pw$power_se <- sqrt(pw$power * (1 - pw$power) / pmax(pw$n_p, 1))
	pw <- pw[order(pw$response_type, pw$inference_class, pw$method, pw$formula, pw$n, pw$effect_label, pw$design),
		c(cell_cols, "effect_label", "reps", "n_p", "rej", "power", "power_se")]
}
utils::write.csv(pw, file.path(out_dir, "power_summary.csv"), row.names = FALSE)

# Markdown.
fails <- s[s$fail_size | s$fail_coverage, ]
flagged <- b[b$flag_null_bias, ]
fmt <- function(x, d = 3) ifelse(is.na(x), "", formatC(x, digits = d, format = "fg"))
short_design <- function(x, p) paste0(sub("^Design(Fixed|SeqOneByOne)", "", x), ifelse(p != 0.5, paste0("@", p), ""))
md <- c(paste("##", title), "", if (nzchar(note)) c(note, "") else NULL,
	sprintf("%d null cells, K = %d size / coverage tests at 0.01 / K = %.2g. Failing cells: **%d**.",
		nrow(s), K, threshold, nrow(fails)), "")
if (nrow(fails)) md <- c(md,
	"| response | design | class | method | formula | n | size | coverage | finite | accepted |",
	"|---|---|---|---|---|---|---|---|---|---|",
	sprintf("| %s | %s | %s | %s | %s | %d | %s%s | %s%s | %d/%d | %s |", fails$response_type,
		short_design(fails$design, fails$prob_T), sub("^Inference", "", fails$inference_class), fails$method, fails$formula,
		as.integer(fails$n), fmt(fails$size), ifelse(fails$fail_size, " **FAIL**", ""), fmt(fails$coverage),
		ifelse(fails$fail_coverage, " **FAIL**", ""), as.integer(pmax(fails$n_p, fails$n_ci)), as.integer(fails$reps),
		fails$accepted), "")
md <- c(md, "### Null bias (reported, not gated)", "",
	sprintf("%d estimand cells; flagged (z-test at 0.01 / %d and |bias| / SD > %g): **%d**.", nrow(b), K_bias,
		NULL_BIAS_STD_FLAG, nrow(flagged)), "")
if (nrow(flagged)) md <- c(md,
	"| response | design | class | formula | n | null value | null bias | bias / SD | share below null | non-finite |",
	"|---|---|---|---|---|---|---|---|---|---|",
	sprintf("| %s | %s | %s | %s | %d | %s | %s | %s | %s | %.1f%% |", flagged$response_type,
		short_design(flagged$design, flagged$prob_T), sub("^Inference", "", flagged$inference_class), flagged$formula,
		as.integer(flagged$n), fmt(flagged$null_value), fmt(flagged$null_bias), fmt(flagged$null_bias_std, 2),
		fmt(flagged$share_below_null, 2), 100 * flagged$nonfinite_share), "")
if (nrow(pw)) md <- c(md, "### Power (reported, not gated)", "",
	sprintf("%d power cells; see `power_summary.csv` and the power figures.", nrow(pw)), "")
writeLines(as.character(nrow(fails)), file.path(out_dir, "gate_failures.txt"))
writeLines(md, file.path(out_dir, "calibration_summary.md"))
if (!is.null(summary_md)) cat(md, sep = "\n", file = summary_md, append = TRUE)
cat(md, sep = "\n")
