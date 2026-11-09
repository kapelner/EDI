#!/usr/bin/env Rscript
# Analysis of the published calibration study (release_v1_2_0.md TODO-36), from a
# campaign's running totals (calibration_study_stats.R), never from raw rows. Same
# tests as analyze_calibration_fast_tier.R:
#
#   size      H0: size <= 0.05 vs > 0.05        exact one-sided binomial
#   coverage  H0: coverage >= 0.95 vs < 0.95     exact one-sided binomial, under the
#             null and at each power effect (coverage of the class's true estimand,
#             estimand_true from calibrate_study_truths.R; cells without one are
#             reported as such)
#   Two-stage gate (see "Two-stage gate" below): Benjamini-Hochberg q < 0.05 over
#   every test of the screening replicates flags a cell; the flagged cells are
#   re-run on fresh replicates and fail only if those alone reject (at 0.01 / the
#   number of flagged tests). --final marks the campaign complete, so pending
#   confirmations become verdicts. A row of --accepted re-tests its cell against
#   the accepted level instead of 0.05 / 0.95, in both stages.
#
# Reported, never gated: size at 0.10, yield, bias at the power effects (as null
# bias, against estimand_true), null bias (mean of estimate - null
# value, SD, bias / SD, z-test; share of estimates below the null value with an
# exact sign test, a median-unbiasedness check that, unlike a median, merges across
# waves), power (share of p < 0.05 under each power effect), and the null p-value
# calibration curve P(p <= u) - u at the u grid of calibration_study_stats.R.
#
# Outputs in --out-dir: calibration_summary.csv, null_bias_summary.csv,
# power_summary.csv (power and coverage of the true estimand), nonnull_bias_summary.csv,
# pvalue_curves.csv, confirm_cells.csv (the flagged tests, read by the planner),
# confirmation_summary.csv, calibration_summary.md, gate_failures.txt.
#
# Usage: Rscript R/package_tests/calibration/analyze_calibration_study.R --stats-dir DIR \
#          --out-dir DIR [--accepted FILE] [--title TEXT] [--note TEXT] [--summary-md FILE] [--final]
#          [--confirm-min-n 500]
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
final <- "--final" %in% args
# A flagged cell is cleared only on at least this many confirmation results: fewer
# (a confirmation abandoned or cut short) cannot clear it, so it counts as failing.
confirm_min_n <- as.integer(arg_value("--confirm-min-n", "500"))
FAMILY_ALPHA <- 0.01
SCREEN_Q <- 0.05
MIN_FINITE <- 30L
NULL_BIAS_STD_FLAG <- 0.1
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

tests <- cal_stats_prepare(cal_stats_read(file.path(stats_dir, "tests.csv.gz")))
est <- cal_stats_prepare(cal_stats_read(file.path(stats_dir, "est.csv.gz")))
cell_cols <- c(setdiff(CAL_STATS_CELL, c("effect_label", "stage")), "inf_procedure")
# No results at all (e.g. every shard of the first wave failed): say so and stop,
# rather than building tables from zero rows. The plot script skips missing CSVs.
if (is.null(tests) || !nrow(tests)) {
	md <- c(paste("##", title), "", if (nzchar(note)) c(note, "") else NULL, "No results yet.", "")
	writeLines("0", file.path(out_dir, "gate_failures.txt"))
	writeLines(md, file.path(out_dir, "calibration_summary.md"))
	if (!is.null(summary_md)) cat(md, sep = "\n", file = summary_md, append = TRUE)
	quit(save = "no", status = 0L)
}
# Confirmation replicates are judged apart (the gate's second stage, below); every
# other table describes the screening replicates.
tests_confirm <- tests[tests$stage == "confirm", ]
tests <- tests[tests$stage == "screen", ]
est <- est[est$stage == "screen", ]

# Size and coverage (null).
s <- tests[tests$effect_label == "null", ]
s$size <- ifelse(s$n_p > 0, s$rej / s$n_p, NA_real_)
s$size_10 <- ifelse(s$n_p > 0, s$rej10 / s$n_p, NA_real_)
s$coverage <- ifelse(s$n_ci > 0, s$cov / s$n_ci, NA_real_)
s$yield <- pmax(s$n_p, s$n_ci) / s$reps
s$mean_fit_secs <- s$fit_secs / s$reps
s$size_null <- rep(0.05, nrow(s))  # rep(): s can have no rows (a wave whose shards all failed)
s$coverage_null <- rep(0.95, nrow(s))
s$accepted <- rep("", nrow(s))
if (file.exists(accepted_path)) {
	acc <- utils::read.csv(accepted_path, stringsAsFactors = FALSE, colClasses = c(formula = "character"))
	acc$formula[is.na(acc$formula)] <- ""
	for (i in seq_len(nrow(acc))) {
		a <- acc[i, ]
		hit <- s$response_type == a$response_type & s$design == a$design & s$prob_T == a$prob_T &
			s$inf_class == a$inf_class & s$inf_procedure == a$inf_procedure & s$formula == a$formula & s$n == a$n
		if (!any(hit)) next
		if (a$metric == "size") s$size_null[hit] <- a$accepted_level
		if (a$metric == "coverage") s$coverage_null[hit] <- a$accepted_level
		s$accepted[hit] <- trimws(paste(s$accepted[hit], a$metric))
	}
}
s$p_size <- ifelse(s$n_p >= MIN_FINITE, stats::pbinom(s$rej - 1, s$n_p, s$size_null, lower.tail = FALSE), NA_real_)
s$p_coverage <- ifelse(s$n_ci >= MIN_FINITE, stats::pbinom(s$cov, s$n_ci, s$coverage_null), NA_real_)
# Power cells: power, and coverage of the class's true estimand (estimand_true,
# calibrate_study_truths.R), gated with the null tests in the two-stage gate below.
# A cell with no truth (KK classes; see that script) has n_ci = 0: no coverage.
pw <- tests[tests$effect_label != "null", ]
pw$power <- ifelse(pw$n_p > 0, pw$rej / pw$n_p, NA_real_)
pw$power_se <- sqrt(pw$power * (1 - pw$power) / pmax(pw$n_p, 1))
pw$coverage <- ifelse(pw$n_ci > 0, pw$cov / pw$n_ci, NA_real_)
pw$truth_available <- pw$n_ci > 0 | !(pw$reps > 0)
pw$p_coverage <- ifelse(pw$n_ci >= MIN_FINITE, stats::pbinom(pw$cov, pw$n_ci, 0.95), NA_real_)
# Two-stage gate (user decision 2026-11-09). Bonferroni over the campaign's ~10^5
# tests needed size >= 0.10 or coverage <= 0.90 to fail at 1,000 replicates.
#   Stage 1, screen: Benjamini-Hochberg q-values over every size / coverage test of
#     the screening replicates; q < SCREEN_Q flags the cell (catches size ~0.07).
#     The flagged cells go to confirm_cells.csv.
#   Stage 2, confirm: plan_calibration_study.R gives each flagged cell fresh
#     replicates (stage "confirm", new seeds) once screening is done. The cell
#     fails only if those alone reject, at FAMILY_ALPHA / (number of flagged
#     tests); a flagged cell with fewer than --confirm-min-n confirmation results
#     (its confirmation abandoned or cut short) counts as failing.
# Until --final (the campaign complete), flags are reported as provisional fails.
key_cols <- c(cell_cols, "effect_label")
gate_rows <- function(d, metric, level, p) {
	if (!nrow(d)) return(NULL)
	data.frame(d[key_cols], metric = metric, level = level, p = p, stringsAsFactors = FALSE)
}
gate <- rbind(gate_rows(s, "size", s$size_null, s$p_size), gate_rows(s, "coverage", s$coverage_null, s$p_coverage),
	gate_rows(pw, "coverage", rep(0.95, nrow(pw)), pw$p_coverage))
gate <- if (is.null(gate)) data.frame() else gate[!is.na(gate$p), ]
K <- nrow(gate)
gate$q <- if (K) stats::p.adjust(gate$p, method = "BH") else numeric()
flagged_tests <- gate[gate$q < SCREEN_Q, , drop = FALSE]
utils::write.csv(flagged_tests, file.path(out_dir, "confirm_cells.csv"), row.names = FALSE)
m <- nrow(flagged_tests)
if (m) {
	kc <- do.call(paste, c(flagged_tests[key_cols], sep = "\r"))
	tc <- if (nrow(tests_confirm)) tests_confirm else NULL
	idx <- if (is.null(tc)) rep(NA_integer_, m) else match(kc, do.call(paste, c(tc[key_cols], sep = "\r")))
	is_size <- flagged_tests$metric == "size"
	flagged_tests$confirm_reps <- if (is.null(tc)) 0 else ifelse(is.na(idx), 0, tc$reps[idx])
	flagged_tests$confirm_n <- if (is.null(tc)) 0 else ifelse(is.na(idx), 0, ifelse(is_size, tc$n_p[idx], tc$n_ci[idx]))
	flagged_tests$confirm_hits <- if (is.null(tc)) 0 else ifelse(is.na(idx), 0, ifelse(is_size, tc$rej[idx], tc$cov[idx]))
	flagged_tests$confirm_value <- ifelse(flagged_tests$confirm_n > 0, flagged_tests$confirm_hits / flagged_tests$confirm_n, NA_real_)
	flagged_tests$p_confirm <- ifelse(flagged_tests$confirm_n < MIN_FINITE, NA_real_, ifelse(is_size,
		stats::pbinom(flagged_tests$confirm_hits - 1, flagged_tests$confirm_n, flagged_tests$level, lower.tail = FALSE),
		stats::pbinom(flagged_tests$confirm_hits, flagged_tests$confirm_n, flagged_tests$level)))
	confirmed <- !is.na(flagged_tests$p_confirm) & flagged_tests$p_confirm < FAMILY_ALPHA / m
	flagged_tests$status <- if (!final) "flagged, confirmation pending" else
		ifelse(confirmed, "fail (confirmed)", ifelse(flagged_tests$confirm_n < confirm_min_n,
			"fail (confirmation could not run)", "cleared by confirmation"))
} else flagged_tests$status <- character()
utils::write.csv(flagged_tests, file.path(out_dir, "confirmation_summary.csv"), row.names = FALSE)
failing_tests <- flagged_tests[if (final) grepl("^fail", flagged_tests$status) else rep(TRUE, m), , drop = FALSE]
fkey <- function(d, metric) do.call(paste, c(d[key_cols], list(metric), sep = "\r"))
fails_k <- if (nrow(failing_tests)) fkey(failing_tests, failing_tests$metric) else character()
s$fail_size <- fkey(s, rep("size", nrow(s))) %in% fails_k
s$fail_coverage <- fkey(s, rep("coverage", nrow(s))) %in% fails_k
pw$fail_coverage <- fkey(pw, rep("coverage", nrow(pw))) %in% fails_k
s$q_size <- gate$q[match(fkey(s, rep("size", nrow(s))), fkey(gate, gate$metric))]
s$q_coverage <- gate$q[match(fkey(s, rep("coverage", nrow(s))), fkey(gate, gate$metric))]
pw$q_coverage <- gate$q[match(fkey(pw, rep("coverage", nrow(pw))), fkey(gate, gate$metric))]
s <- s[order(!(s$fail_size | s$fail_coverage), s$response_type, s$inf_class, s$inf_procedure, s$formula, s$n, s$design), ]
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

# Bias at the power effects: beta_T_hat - estimand_true, as for the null bias.
nb_est <- est[est$effect_label != "null", ]
bias_stats <- function(b) {
	b$nonfinite_share <- 1 - b$n_est / b$reps
	b$bias <- ifelse(b$n_est > 0, b$sum_d / b$n_est, NA_real_)
	b$bias_sd <- ifelse(b$n_est > 1, sqrt(pmax(b$sum_d2 - b$n_est * b$bias^2, 0) / (b$n_est - 1)), NA_real_)
	b$bias_se <- b$bias_sd / sqrt(b$n_est)
	b$bias_std <- ifelse(is.finite(b$bias_sd) & b$bias_sd > 0, b$bias / b$bias_sd, NA_real_)
	b$p_bias <- ifelse(b$n_est >= MIN_FINITE & is.finite(b$bias_se) & b$bias_se > 0,
		2 * stats::pnorm(-abs(b$bias / b$bias_se)), NA_real_)
	b
}
nb_est <- bias_stats(nb_est)
nb_est$truth_available <- if ("estimand_true" %in% names(nb_est)) is.finite(nb_est$estimand_true) else rep(FALSE, nrow(nb_est))
K_nnbias <- sum(!is.na(nb_est$p_bias))
nb_est$flag_bias <- !is.na(nb_est$p_bias) & nb_est$p_bias < FAMILY_ALPHA / max(K_nnbias, 1L) &
	abs(nb_est$bias_std) > NULL_BIAS_STD_FLAG
nb_est <- nb_est[order(!nb_est$flag_bias, -abs(ifelse(is.na(nb_est$bias_std), 0, nb_est$bias_std))), ]
utils::write.csv(nb_est, file.path(out_dir, "nonnull_bias_summary.csv"), row.names = FALSE)

# Power.
pw <- pw[order(!pw$fail_coverage, pw$response_type, pw$inf_class, pw$inf_procedure, pw$formula, pw$n, pw$effect_label,
	pw$design), c(cell_cols, "effect_label", "reps", "n_p", "rej", "power", "power_se", "n_ci", "cov", "coverage",
	"truth_available", "p_coverage", "q_coverage", "fail_coverage")]
utils::write.csv(pw, file.path(out_dir, "power_summary.csv"), row.names = FALSE)

# Markdown.
fails <- s[s$fail_size | s$fail_coverage, ]
flagged <- b[b$flag_null_bias, ]
fmt <- function(x, d = 3) ifelse(is.na(x), "", formatC(x, digits = d, format = "fg"))
short_design <- function(x, p) paste0(sub("^Design(Fixed|SeqOneByOne)", "", x), ifelse(p != 0.5, paste0("@", p), ""))
md <- c(paste("##", title), "", if (nzchar(note)) c(note, "") else NULL,
	if (K > 0) c(sprintf(paste("%d null cells and %d power cells; %d tests (null size and coverage, coverage of the",
		"true estimand at the power effects). Two-stage gate: Benjamini-Hochberg q < %g on the screening replicates",
		"flags **%d** test(s); each flagged cell is re-run on fresh replicates and fails only if those alone reject",
		"(at 0.01 / %d)."), nrow(s), nrow(pw), K, SCREEN_Q, m, max(m, 1L)), "",
		if (!final) sprintf("Confirmation: pending (flags below are provisional). Failing null cells so far: **%d**.", nrow(fails))
		else sprintf("Confirmation: %d confirmed failing, %d could not be confirmed (counted as failing), %d cleared. Failing null cells: **%d**.",
			sum(flagged_tests$status == "fail (confirmed)"), sum(flagged_tests$status == "fail (confirmation could not run)"),
			sum(flagged_tests$status == "cleared by confirmation"), nrow(fails)))
	else sprintf("%d null cells, none with enough results for a size / coverage test yet.", nrow(s)), "")
if (nrow(fails)) md <- c(md,
	"| response | design | class | procedure | formula | n | size | coverage | finite | accepted |",
	"|---|---|---|---|---|---|---|---|---|---|",
	sprintf("| %s | %s | %s | %s | %s | %d | %s%s | %s%s | %d/%d | %s |", fails$response_type,
		short_design(fails$design, fails$prob_T), sub("^Inference", "", fails$inf_class), fails$inf_procedure, fails$formula,
		as.integer(fails$n), fmt(fails$size), ifelse(fails$fail_size, " **FAIL**", ""), fmt(fails$coverage),
		ifelse(fails$fail_coverage, " **FAIL**", ""), as.integer(pmax(fails$n_p, fails$n_ci)), as.integer(fails$reps),
		fails$accepted), "")
md <- c(md, "### Null bias (reported, not gated)", "",
	if (K_bias > 0) sprintf("%d estimand cells; flagged (z-test at 0.01 / %d and |bias| / SD > %g): **%d**.", nrow(b), K_bias,
		NULL_BIAS_STD_FLAG, nrow(flagged))
	else sprintf("%d estimand cells, none with enough results for a null-bias test yet.", nrow(b)), "")
if (nrow(flagged)) md <- c(md,
	"| response | design | class | formula | n | null value | null bias | bias / SD | share below null | non-finite |",
	"|---|---|---|---|---|---|---|---|---|---|",
	sprintf("| %s | %s | %s | %s | %d | %s | %s | %s | %s | %.1f%% |", flagged$response_type,
		short_design(flagged$design, flagged$prob_T), sub("^Inference", "", flagged$inf_class), flagged$formula,
		as.integer(flagged$n), fmt(flagged$null_value), fmt(flagged$null_bias), fmt(flagged$null_bias_std, 2),
		fmt(flagged$share_below_null, 2), 100 * flagged$nonfinite_share), "")
pw_fails <- pw[pw$fail_coverage, ]
nb_flagged <- nb_est[nb_est$flag_bias, ]
if (nrow(pw)) {
	n_truth <- sum(pw$truth_available & pw$reps > 0)
	md <- c(md, "### Coverage at beta_T != 0 (gated)", "",
		sprintf(paste("%d power cells, %d with a true estimand value (calibrate_study_truths.R; none for classes that apply only to matched designs, or whose large-sample fits failed);",
			"%d with enough results tested. Failing cells: **%d**."), nrow(pw), n_truth, sum(!is.na(pw$p_coverage)),
			nrow(pw_fails)), "")
	if (nrow(pw_fails)) md <- c(md,
		"| response | design | class | procedure | formula | n | effect | coverage | finite |",
		"|---|---|---|---|---|---|---|---|---|",
		sprintf("| %s | %s | %s | %s | %s | %d | %s | %s **FAIL** | %d/%d |", pw_fails$response_type,
			short_design(pw_fails$design, pw_fails$prob_T), sub("^Inference", "", pw_fails$inf_class), pw_fails$inf_procedure,
			pw_fails$formula, as.integer(pw_fails$n), pw_fails$effect_label, fmt(pw_fails$coverage),
			as.integer(pw_fails$n_ci), as.integer(pw_fails$reps)), "")
	md <- c(md, "### Bias at beta_T != 0 (reported, not gated)", "",
		if (K_nnbias > 0) sprintf("%d estimand cells; flagged (z-test at 0.01 / %d and |bias| / SD > %g): **%d**.",
			nrow(nb_est), K_nnbias, NULL_BIAS_STD_FLAG, nrow(nb_flagged))
		else sprintf("%d estimand cells, none with enough results for a bias test yet.", nrow(nb_est)), "")
	if (nrow(nb_flagged)) md <- c(md,
		"| response | design | class | formula | n | effect | true value | bias | bias / SD |",
		"|---|---|---|---|---|---|---|---|---|",
		sprintf("| %s | %s | %s | %s | %d | %s | %s | %s | %s |", nb_flagged$response_type,
			short_design(nb_flagged$design, nb_flagged$prob_T), sub("^Inference", "", nb_flagged$inf_class),
			nb_flagged$formula, as.integer(nb_flagged$n), nb_flagged$effect_label, fmt(nb_flagged$estimand_true),
			fmt(nb_flagged$bias), fmt(nb_flagged$bias_std, 2)), "")
	md <- c(md, "### Power (reported, not gated)", "",
		sprintf("%d power cells; see `power_summary.csv`, `design_comparison.csv` (paired tests between designs, when the campaign is complete) and the power figures.", nrow(pw)), "")
}
writeLines(as.character(nrow(failing_tests)), file.path(out_dir, "gate_failures.txt"))
writeLines(md, file.path(out_dir, "calibration_summary.md"))
if (!is.null(summary_md)) cat(md, sep = "\n", file = summary_md, append = TRUE)
cat(md, sep = "\n")
