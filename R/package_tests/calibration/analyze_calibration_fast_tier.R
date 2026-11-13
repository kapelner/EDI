#!/usr/bin/env Rscript
# Gate for the scheduled CI calibration fast tier (design:
# R/package_metadata/new_feature_plans/v1_0_5/calibration_gates.md). Merges the
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
# Null bias (reported and flagged, never gated): per estimand cell -- the cell
# above without `method`, since every method of a (class, formula) fit shares
# one point estimate -- the mean of estimate - null_value over the replicates
# with a finite estimate. Under the sharp null that is the estimator's bias.
# Also: median bias, SD, SE, bias / SD, share of non-finite estimates. A cell
# is FLAGGED when the two-sided z-test of zero bias is significant at
# 0.01 / K_bias (K_bias = number of estimand cells tested) AND |bias| / SD >
# NULL_BIAS_STD_FLAG. Not gated because an honest estimator can carry a real
# O(1/n) null bias: ratio-scale estimates (Jensen) and unequal allocation
# (prob_T != 0.5 breaks the label-swap symmetry that zeroes it otherwise).
# Writes OUT_DIR/null_bias_summary.csv.
#
# Power (published calibration study, release_v1_2_0.md TODO-36): rows with an
# effect_label other than "null" are never mixed into size / coverage / null
# bias; per cell and effect they give power = share of finite p-values below 0.05
# (the test of the class's null value), with its binomial SE. Writes
# OUT_DIR/power_summary.csv. Reported, never gated.
#
# Usage: Rscript R/package_tests/calibration/analyze_calibration_fast_tier.R \
#          --in-dir DIR --out-dir DIR [--accepted FILE] [--summary-md FILE] [--report-only] \
#          [--title TEXT] [--note TEXT]
# Reads every rows.csv / rows.csv.gz under --in-dir (fast-tier shards and study
# shards alike). --title heads the markdown summary; --note (e.g. a campaign's
# progress) is printed under it.
# Always finishes the whole report and writes the number of failing cells to
# OUT_DIR/gate_failures.txt. Exits 1 when any test fails, unless --report-only:
# CI passes that and enforces the gate in a later step, so the analysis step
# itself never looks like it stopped partway.

# read.csv() calls in this file go through read_csv_fast(): fread-backed, same
# result as read.csv (R/package_tests/read_csv_fast.R), loaded from the checkout.
if (!exists("read_csv_fast", mode = "function")) local({
	script = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
	for (d in c(getwd(), if (!is.na(script)) dirname(script))) {
		top = tryCatch(suppressWarnings(system2("git", c("-C", shQuote(d), "rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE)), error = function(e) character())
		helper = if (length(top)) file.path(top[1], "R", "package_tests", "read_csv_fast.R") else ""
		if (nzchar(helper) && file.exists(helper)) { sys.source(helper, envir = parent.env(environment())); break }
	}
	if (!exists("read_csv_fast", mode = "function")) stop("read_csv_fast.R not found: run from inside the EDI git checkout.", call. = FALSE)
})

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
report_only <- "--report-only" %in% args
title <- arg_value("--title", "Calibration fast tier")
note <- arg_value("--note", "")
FAMILY_ALPHA <- 0.01
MIN_FINITE <- 30L
NULL_BIAS_STD_FLAG <- 0.1
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

files <- list.files(in_dir, pattern = "^rows\\.csv(\\.gz)?$", recursive = TRUE, full.names = TRUE)
if (!length(files)) stop("no rows.csv under ", in_dir)
read_rows <- function(f) {
	x <- read_csv_fast(f, stringsAsFactors = FALSE, colClasses = c(formula = "character"))
	if (!("effect_label" %in% names(x))) x$effect_label <- "null"
	if (!("effect" %in% names(x))) x$effect <- 0
	if (!("n_nominal" %in% names(x))) x$n_nominal <- x$n
	x
}
d <- do.call(rbind, lapply(files, read_rows))
d$formula[is.na(d$formula)] <- ""
# Rows from before the prob_T column ran at equal allocation (release_v1_0_5.md TODO-184).
if (!("prob_T" %in% names(d))) d$prob_T <- 0.5
d$prob_T[is.na(d$prob_T)] <- 0.5

# Power rows: summarized separately, below; everything else sees the null only.
dp <- d[d$effect_label != "null", ]
d <- d[d$effect_label == "null", ]
if (!nrow(d)) stop("no null rows under ", in_dir)
cell_cols <- c("response_type", "design", "prob_T", "inference_class", "method", "formula", "n")
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
	acc <- read_csv_fast(accepted_path, stringsAsFactors = FALSE, colClasses = c(formula = "character"))
	acc$formula[is.na(acc$formula)] <- ""
	# An accepted deviation without a prob_T column applies to the equal-allocation cell.
	if (!("prob_T" %in% names(acc))) acc$prob_T <- 0.5
	acc$prob_T[is.na(acc$prob_T)] <- 0.5
	for (i in seq_len(nrow(acc))) {
		a <- acc[i, ]
		hit <- s$response_type == a$response_type & s$design == a$design & s$prob_T == a$prob_T & s$inference_class == a$inference_class &
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

# Null bias, one row per estimand cell; one estimate per replicate (the first
# finite one across that fit's methods).
est_cols <- setdiff(cell_cols, "method")
if (!("rep" %in% names(d))) d$rep <- seq_len(nrow(d))
est_key <- do.call(paste, c(d[est_cols], sep = "\r"))
b <- do.call(rbind, lapply(split(seq_len(nrow(d)), est_key), function(idx) {
	x <- d[idx, ]
	x <- x[order(!is.finite(x$estimate)), ]
	x <- x[!duplicated(x$rep), ]
	dev <- x$estimate - x$null_value
	fin <- is.finite(dev)
	m <- sum(fin)
	sdv <- if (m > 1L) stats::sd(dev[fin]) else NA_real_
	data.frame(x[1L, est_cols], reps = nrow(x), n_est = m, nonfinite_share = 1 - m / nrow(x),
		null_value = x$null_value[which(is.finite(x$null_value))[1L]],
		null_bias = if (m) mean(dev[fin]) else NA_real_,
		null_bias_median = if (m) stats::median(dev[fin]) else NA_real_,
		null_bias_sd = sdv, null_bias_se = sdv / sqrt(m), stringsAsFactors = FALSE)
}))
rownames(b) <- NULL
b$null_bias_std <- ifelse(is.finite(b$null_bias_sd) & b$null_bias_sd > 0, b$null_bias / b$null_bias_sd, NA_real_)
b$p_null_bias <- ifelse(b$n_est >= MIN_FINITE & is.finite(b$null_bias_se) & b$null_bias_se > 0,
	2 * stats::pnorm(-abs(b$null_bias / b$null_bias_se)), NA_real_)
K_bias <- sum(!is.na(b$p_null_bias))
threshold_bias <- FAMILY_ALPHA / max(K_bias, 1L)
b$flag_null_bias <- !is.na(b$p_null_bias) & b$p_null_bias < threshold_bias & abs(b$null_bias_std) > NULL_BIAS_STD_FLAG
b <- b[order(!b$flag_null_bias, -abs(ifelse(is.na(b$null_bias_std), 0, b$null_bias_std))), ]
utils::write.csv(b, file.path(out_dir, "null_bias_summary.csv"), row.names = FALSE)

# Power per (cell, effect).
if (nrow(dp)) {
	pkey <- do.call(paste, c(dp[c(cell_cols, "effect_label")], sep = "\r"))
	pw <- do.call(rbind, lapply(split(seq_len(nrow(dp)), pkey), function(idx) {
		x <- dp[idx, ]
		fin <- is.finite(x$pval)
		data.frame(x[1L, c(cell_cols, "n_nominal", "effect_label")], effect = x$effect[[1L]], reps = nrow(x),
			n_p = sum(fin), rej = sum(x$pval[fin] < 0.05), stringsAsFactors = FALSE)
	}))
	rownames(pw) <- NULL
	pw$power <- ifelse(pw$n_p > 0, pw$rej / pw$n_p, NA_real_)
	pw$power_se <- sqrt(pw$power * (1 - pw$power) / pmax(pw$n_p, 1L))
	pw <- pw[order(pw$response_type, pw$inference_class, pw$method, pw$formula, pw$n, pw$effect_label, pw$design), ]
	utils::write.csv(pw, file.path(out_dir, "power_summary.csv"), row.names = FALSE)
}

fails <- s[s$fail_size | s$fail_coverage, ]
fmt <- function(x, d = 3) ifelse(is.na(x), "", formatC(x, digits = d, format = "fg"))
md <- c(paste("##", title),
	"",
	if (nzchar(note)) c(note, "") else NULL,
	sprintf("%d rows, %d cells, K = %d tests, per-test alpha = 0.01 / K = %.2g. Failures: **%d**.",
		nrow(d), nrow(s), K, threshold, nrow(fails)),
	"")
if (nrow(fails)) {
	md <- c(md, "| response | design | prob_T | class | method | formula | n | size | coverage | finite | p (size) | p (coverage) | accepted |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|---|",
		sprintf("| %s | %s | %s | %s | %s | %s | %d | %s%s | %s%s | %d/%d | %s | %s | %s |",
			fails$response_type, sub("^DesignFixed", "", fails$design), format(fails$prob_T), sub("^Inference", "", fails$inference_class),
			fails$method, fails$formula, fails$n, fmt(fails$size), ifelse(fails$fail_size, " **FAIL**", ""),
			fmt(fails$coverage), ifelse(fails$fail_coverage, " **FAIL**", ""), pmax(fails$n_p, fails$n_ci), fails$reps,
			fmt(fails$p_size, 2), fmt(fails$p_coverage, 2), fails$accepted), "")
}
low_yield <- s[s$yield < 0.8, ]
if (nrow(low_yield)) {
	md <- c(md, sprintf("Low yield (< 80%% finite, reported only): %s", paste(sprintf("%s %s %s %s %s n=%d (%.0f%%)",
		low_yield$response_type, paste0(sub("^DesignFixed", "", low_yield$design), ifelse(low_yield$prob_T != 0.5, paste0("@", low_yield$prob_T), "")),
		sub("^Inference", "", low_yield$inference_class), low_yield$method, low_yield$formula,
		low_yield$n, 100 * low_yield$yield), collapse = "; ")), "")
}
flagged <- b[b$flag_null_bias, ]
md <- c(md, sprintf("### Null bias (reported, not gated)"), "",
	sprintf("%d estimand cells, K_bias = %d tests at 0.01 / K_bias = %.2g; flagged when also |bias| / SD > %g: **%d**.",
		nrow(b), K_bias, threshold_bias, NULL_BIAS_STD_FLAG, nrow(flagged)), "")
if (nrow(flagged)) {
	md <- c(md, "| response | design | prob_T | class | formula | n | null value | null bias | median | bias / SD | non-finite | p |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|",
		sprintf("| %s | %s | %s | %s | %s | %d | %s | %s | %s | %s | %s | %s |",
			flagged$response_type, sub("^DesignFixed", "", flagged$design), format(flagged$prob_T),
			sub("^Inference", "", flagged$inference_class), flagged$formula, flagged$n, fmt(flagged$null_value),
			fmt(flagged$null_bias), fmt(flagged$null_bias_median), fmt(flagged$null_bias_std, 2),
			sprintf("%.1f%%", 100 * flagged$nonfinite_share), fmt(flagged$p_null_bias, 2)), "")
}
if (nrow(dp)) md <- c(md, sprintf("### Power (reported, not gated)"), "",
	sprintf("%d power cells over %d effect size(s); see `power_summary.csv`.", nrow(pw), length(unique(pw$effect_label))), "")
md <- c(md, sprintf("Full tables: `calibration_summary.csv` (size, coverage), `null_bias_summary.csv`%s.",
	if (nrow(dp)) ", `power_summary.csv`" else ""), "",
	if (nrow(fails)) sprintf("**Gate: FAIL** -- %d cell(s) significantly worse than nominal or their accepted level. Triage each: fix it, or add a reasoned row to `calibration_fast_tier_accepted.csv` that cites an open TODO to investigate it (open one if none exists).", nrow(fails))
	else "**Gate: pass**")
writeLines(as.character(nrow(fails)), file.path(out_dir, "gate_failures.txt"))
writeLines(md, file.path(out_dir, "calibration_summary.md"))
if (!is.null(summary_md)) cat(md, sep = "\n", file = summary_md, append = TRUE)
cat(md, sep = "\n")
quit(status = if (nrow(fails) && !report_only) 1L else 0L)
