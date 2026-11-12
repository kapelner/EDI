#!/usr/bin/env Rscript
# Analysis of the published calibration study (release_v1_2_0.md TODO-36), from a
# campaign's running totals (calibration_study_stats.R), never from raw rows. Same
# tests as analyze_calibration_fast_tier.R:
#
#   size      H0: size <= level vs > level       exact one-sided binomial
#   coverage  H0: coverage >= level vs < level   exact one-sided binomial, under the
#             null and at each power effect (coverage of the class's true estimand,
#             estimand_true from calibrate_study_truths.R; cells without one are
#             reported as such)
#   Two-stage gate (see "Two-stage gate" below): Benjamini-Hochberg q < 0.05 over
#   every test of the screening replicates flags a cell; the flagged cells are
#   re-run on fresh replicates and fail only if those alone reject (at 0.01 / the
#   number of flagged tests). --final marks the campaign complete, so pending
#   confirmations become verdicts. A row of --accepted re-tests its cell against
#   the accepted level instead of the schedule's, in both stages.
#   Level (v1.0.5 TODO-200, new_feature_plans/v1_0_5/calibration_rate_derived_gate.md; cal_gate_levels() in
#   calibration_study_stats.R): finite-sample procedures (exact, rand) 0.05 / 0.95 at every n; asymptotic
#   procedures with a known order a > 0 (registry, inference_convergence_expectation()) size
#   min(0.10, 0.05 + c_a n_eff^-a), coverage 1 - that, reaching the 0.10 cap at n_eff = 50; unknown order:
#   the cap below the campaign's largest n, the a = 1 level at it; expected order 0 (design mismatch):
#   the a = 1 level, anticonservative side only (conservative cells are reported, never failed).
#   Rate check: a cell whose convergence verdict (convergence_calibration_study.R) is `slower` is tested
#   at its largest n against the nominal 0.05 / 0.95 (rule rate_check), through the same screen and
#   confirmation. The level tested against is the size_null / coverage_null column of
#   calibration_summary.csv and power_summary.csv, the rule that set it rule_size / rule_coverage / rule.
#
# Reported, never gated: size at 0.10, yield, bias at the power effects (as null
# bias, against estimand_true; flag bias_sd_large_n when |bias| / SD > 0.1 at the largest n), null bias (mean of estimate - null
# value, SD, bias / SD, z-test; share of estimates below the null value with an
# exact sign test, a median-unbiasedness check that, unlike a median, merges across
# waves), power (share of p < 0.05 under each power effect), and the null p-value
# calibration curve P(p <= u) - u at the u grid of calibration_study_stats.R.
#
# Outputs in --out-dir: calibration_summary.csv, null_bias_summary.csv,
# power_summary.csv (power and coverage of the true estimand), nonnull_bias_summary.csv,
# pvalue_curves.csv, confirm_cells.csv (the flagged tests, read by the planner),
# confirmation_summary.csv, calibration_summary.md, gate_failures.txt, triage.csv (failing cells grouped by class x
# procedure x metric, calibration_study_triage.R).
#
# Usage: Rscript R/package_tests/calibration/analyze_calibration_study.R --stats-dir DIR \
#          --out-dir DIR [--accepted FILE] [--title TEXT] [--note TEXT] [--summary-md FILE] [--final]
#          [--confirm-min-n 500] [--convergence FILE] [--plan FILE] [--confirm-reps 5000] [--slow-confirm-reps 1000]
# --convergence: convergence_summary.csv of the same stats (default <out-dir>/convergence_summary.csv; run
# convergence_calibration_study.R first); absent = no rate check.
# --stats-dir holds tests.csv.gz and est.csv.gz.
# --plan: plan.csv of the campaign (plan_calibration_study.R --plan-out; default <stats-dir>/../plan.csv). With a
# plan (v1.0.5 TODO-203, new_feature_plans/v1_0_5/calibration_class_major_campaign_order.md), campaigns run class by class
# and the gate works on the whole plan: Benjamini-Hochberg over all m_total tests of the plan, where a test enters with its
# p-value once its unit's screening replicates are all done and counts as p = 1 until then, so a flag is never withdrawn
# (cal_bh_q()); a flagged test fails when its fresh confirmation replicates alone reject at 0.01 / m_total, decided once the
# planned confirmation replicates (--confirm-reps, --slow-confirm-reps for the slow classes) are in; the "campaign's largest
# n" is the plan's. Also writes class_status.csv. Without a plan (older campaigns, small tests) every test that has results is in
# the family and flags are counted as before.

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
source(file.path(script_dir, "calibration_study_stats.R"))
source(file.path(script_dir, "calibration_study_plan_common.R"))
# The procedure -> regime registry, read from the checkout: this job runs without EDI installed.
source(file.path(script_dir, "..", "..", "EDI", "R", "inference_procedure_regime.R"))
# conv_expectations(): the registry's expected order and nominal n_eff per row, the same computation
# the convergence study uses (functions only: its main runs only as a script).
source(file.path(script_dir, "convergence_calibration_study.R"))
source(file.path(script_dir, "calibration_study_triage.R"))
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
convergence_path <- arg_value("--convergence", file.path(out_dir, "convergence_summary.csv"))
# A flagged cell is cleared only on at least this many confirmation results: fewer
# (a confirmation abandoned or cut short) cannot clear it, so it counts as failing.
confirm_min_n <- as.integer(arg_value("--confirm-min-n", "500"))
confirm_reps <- as.integer(arg_value("--confirm-reps", "5000"))
slow_confirm_reps <- as.integer(arg_value("--slow-confirm-reps", "1000"))
plan_path <- arg_value("--plan", file.path(dirname(normalizePath(stats_dir, mustWork = FALSE)), "plan.csv"))
FAMILY_ALPHA <- 0.01
SCREEN_Q <- 0.05
MIN_FINITE <- 30L
NULL_BIAS_STD_FLAG <- CAL_GATE_BIAS_SD_FLAG
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

tests <- cal_stats_read(file.path(stats_dir, "tests.csv.gz"))
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
tests <- cal_stats_prepare(tests)
# The campaign plan (see the header): m_total, per-unit completeness, the plan's largest n.
plan <- NULL
if (file.exists(plan_path)) {
	plan <- utils::read.csv(plan_path, stringsAsFactors = FALSE)
	# family comes from the roster (the package's matched-design predicate), via plan.csv.
	if (!"family" %in% names(plan)) stop("plan.csv lacks the `family` column (written by plan_calibration_study.R --plan-out)")
	cal_plan_set_matched(plan$design[plan$family == "matched"])
	plan$key <- cal_plan_key(plan$response_type, plan$design, plan$n, plan$effect, plan$inf_class)
	plan$block <- cal_plan_block(plan$effect, plan$response_type, plan$inf_class)
	plan$rep_from <- 1L
	plan <- cal_unit_progress(plan, tests)
}
have_plan <- !is.null(plan) && nrow(plan) > 0L
m_total <- if (have_plan) cal_plan_m_total(plan) else NA_integer_
# Test p-values enter the gate once their unit is complete (or the campaign is final); no plan: always.
unit_key_of <- function(d) cal_plan_key(d$response_type, cal_plan_design_label(d$design, d$prob_T), d$n_nominal, d$effect_label, d$inf_class)
unit_complete <- function(d) {
	if (!have_plan || final) return(rep(TRUE, nrow(d)))
	m <- match(unit_key_of(d), plan$key)
	!is.na(m) & plan$done[m]
}
# Rate check only on a cell whose every planned n is complete: its verdict (convergence study) then cannot change, so the
# level its largest-n test is held to cannot change either (a flag is never withdrawn).
cell_complete <- function(d) {
	if (!have_plan || final) return(rep(TRUE, nrow(d)))
	all_done <- tapply(plan$done, paste(plan$response_type, plan$design, plan$effect, plan$inf_class), all)
	v <- all_done[paste(d$response_type, cal_plan_design_label(d$design, d$prob_T), d$effect_label, d$inf_class)]
	!is.na(v) & v
}
est <- cal_stats_read(file.path(stats_dir, "est.csv.gz"))
# No estimand table (cannot happen when tests exist, but never a crash): empty, so the bias sections say "none yet".
if (is.null(est)) est <- tests[0, intersect(CAL_STATS_CELL, names(tests))]
est <- cal_stats_prepare(est)
for (col in c("reps", "n_est", "n_below", "n_above", "sum_d", "sum_d2", "null_value", "estimand_true")) if (!(col %in% names(est))) est[[col]] <- numeric(nrow(est))
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
# Levels from the rate-derived rule (calibration_study_stats.R), one row per cell, with the
# registry's expectation and n_eff (the convergence study's computation) next to it. "Largest n"
# is the campaign's largest n_nominal among null cells for the null tables, among power cells
# for the power tables (the power effects run at fewer sizes).
max_of <- function(x) if (length(x)) max(x) else -Inf
gate_context <- function(d, largest_n) {
	regime <- cal_gate_regime(d$inf_procedure)   # stops on a procedure label the registry lacks
	ex <- conv_expectations(d$design, d$prob_T, d$inf_class, d$inf_procedure, d$n_nominal)
	lv <- cal_gate_levels(regime, ex$size_order, ex$basis_size, ex$n_eff, d$n_nominal >= largest_n)
	data.frame(regime = regime, n_eff = ex$n_eff, n_eff_rule = ex$n_eff_rule, n_eff_flag = ex$n_eff_flag,
		expected_order = ex$size_order, basis = ex$basis_size, regularity = ex$regularity, rule = lv$rule,
		size_level = lv$size, coverage_level = lv$coverage, stringsAsFactors = FALSE)
}
set_context <- function(d, ctx, metrics) {
	d$regime <- ctx$regime
	for (col in c("n_eff", "n_eff_rule", "n_eff_flag", "expected_order", "basis", "regularity")) d[[col]] <- ctx[[col]]
	if ("size" %in% metrics) { d$size_null <- ctx$size_level; d$rule_size <- ctx$rule }
	if ("coverage" %in% metrics) { d$coverage_null <- ctx$coverage_level; d$rule_coverage <- ctx$rule }
	d
}
max_n_null <- if (have_plan) cal_plan_largest_n(plan, TRUE) else max_of(s$n_nominal)
s$unit_done <- unit_complete(s)
s$cell_done <- cell_complete(s)
s <- set_context(s, gate_context(s, max_n_null), c("size", "coverage"))
s$accepted <- rep("", nrow(s))
if (file.exists(accepted_path)) {
	acc <- utils::read.csv(accepted_path, stringsAsFactors = FALSE, colClasses = c(formula = "character"))
	acc$formula[is.na(acc$formula)] <- ""
	for (i in seq_len(nrow(acc))) {
		a <- acc[i, ]
		hit <- s$response_type == a$response_type & s$design == a$design & s$prob_T == a$prob_T &
			s$inf_class == a$inf_class & s$inf_procedure == a$inf_procedure & s$formula == a$formula & s$n == a$n
		if (!any(hit)) next
		if (a$metric == "size") { s$size_null[hit] <- a$accepted_level; s$rule_size[hit] <- "accepted" }
		if (a$metric == "coverage") { s$coverage_null[hit] <- a$accepted_level; s$rule_coverage[hit] <- "accepted" }
		s$accepted[hit] <- trimws(paste(s$accepted[hit], a$metric))
	}
}
# Rate check (TODO-200): a cell whose convergence verdict is `slower` is held to the nominal level at its
# largest n (the cell's own), through the same screen and confirmation as every other test. Only the
# anticonservative side (size above 0.05, coverage below 0.95) and not an accepted cell.
conv <- if (file.exists(convergence_path)) utils::read.csv(convergence_path, stringsAsFactors = FALSE,
	colClasses = c(formula = "character")) else NULL
if (is.null(conv)) message("analyze_calibration_study.R: no convergence_summary.csv at ", convergence_path, ": rate check off")
rate_cell_cols <- c("response_type", "design", "prob_T", "inf_class", "formula", "inf_procedure", "effect_label")
ckey <- function(d) do.call(paste, c(d[rate_cell_cols], sep = "\r"))
rate_verdict <- function(d, metric) {
	if (is.null(conv) || !nrow(d)) return(rep(NA_character_, nrow(d)))
	x <- conv[conv$metric == metric, ]
	unname(setNames(x$verdict, ckey(x))[ckey(d)])
}
apply_rate_check <- function(d, metric, value, rule_col, level_col, nominal, bad) {
	if (!nrow(d)) {
		d[[paste0("rate_verdict_", metric)]] <- character()
		return(d)
	}
	v <- rate_verdict(d, metric)
	hit <- v %in% "slower" & !(d[[rule_col]] %in% c("accepted", "finite")) & !is.na(value) & bad(value, nominal) &
		d$n_nominal == stats::ave(d$n_nominal, ckey(d), FUN = max) & d$cell_done
	d[[level_col]][hit] <- nominal
	d[[rule_col]][hit] <- "rate_check"
	d[[paste0("rate_verdict_", metric)]] <- v
	d
}
s <- apply_rate_check(s, "size", s$size, "rule_size", "size_null", CAL_GATE_NOMINAL[["size"]], function(v, nom) v > nom)
s <- apply_rate_check(s, "coverage", s$coverage, "rule_coverage", "coverage_null", CAL_GATE_NOMINAL[["coverage"]], function(v, nom) v < nom)
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
max_n_power <- if (have_plan) cal_plan_largest_n(plan, FALSE) else max_of(pw$n_nominal)
pw$unit_done <- unit_complete(pw)
pw$cell_done <- cell_complete(pw)
pw <- set_context(pw, gate_context(pw, max_n_power), "coverage")
pw <- apply_rate_check(pw, "coverage", pw$coverage, "rule_coverage", "coverage_null", CAL_GATE_NOMINAL[["coverage"]], function(v, nom) v < nom)
pw$p_coverage <- ifelse(pw$n_ci >= MIN_FINITE, stats::pbinom(pw$cov, pw$n_ci, pw$coverage_null), NA_real_)
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
gate_rows <- function(d, metric, level, rule, p) {
	if (!nrow(d)) return(NULL)
	data.frame(d[key_cols], metric = metric, level = level, rule = rule, p = p, stringsAsFactors = FALSE)
}
# A test whose unit's screening replicates are not all in yet has p = NA here (p = 1 in the family: cal_bh_q()).
gate <- rbind(gate_rows(s, "size", s$size_null, s$rule_size, ifelse(s$unit_done, s$p_size, NA_real_)),
	gate_rows(s, "coverage", s$coverage_null, s$rule_coverage, ifelse(s$unit_done, s$p_coverage, NA_real_)),
	gate_rows(pw, "coverage", pw$coverage_null, pw$rule_coverage, ifelse(pw$unit_done, pw$p_coverage, NA_real_)))
# Never a zero-column table: with no testable cell (every cell below MIN_FINITE results, or no cells at all)
# the gate is empty, not an error.
if (is.null(gate)) gate <- data.frame(stats::setNames(rep(list(character()), length(key_cols)), key_cols),
	metric = character(), level = numeric(), rule = character(), p = numeric(), stringsAsFactors = FALSE)
gate <- gate[!is.na(gate$p), , drop = FALSE]
K <- nrow(gate)
gate$q <- if (K) cal_bh_q(gate$p, m_total) else numeric()
# The family's size: the plan's tests (never fewer than the tests that have p-values), else the tests that have results.
m_family <- if (have_plan) max(m_total, K) else NA_integer_
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
	# Confirmation level: 0.01 / (the plan's tests) with a plan, fixed in advance, so a confirmed failure is final when it is
	# made; without a plan 0.01 / (the flagged tests).
	confirm_alpha <- if (have_plan) FAMILY_ALPHA / m_family else FAMILY_ALPHA / m
	flagged_tests$confirm_alpha <- confirm_alpha
	confirmed <- !is.na(flagged_tests$p_confirm) & flagged_tests$p_confirm < confirm_alpha
	# A flagged test is decided once its planned confirmation replicates are all in (a rejection on part of them would
	# be an optional stop), or when the campaign is final.
	decided <- if (have_plan) final | flagged_tests$confirm_reps >= cal_plan_confirm_reps(cal_plan_design_label(flagged_tests$design, flagged_tests$prob_T),
		flagged_tests$inf_class, confirm_reps, slow_confirm_reps) else rep(final, m)
	flagged_tests$status <- ifelse(!decided, "flagged, confirmation pending", ifelse(confirmed, "fail (confirmed)",
		ifelse(flagged_tests$confirm_n < confirm_min_n, "fail (confirmation could not run)", "cleared by confirmation")))
} else flagged_tests$status <- character()
utils::write.csv(flagged_tests, file.path(out_dir, "confirmation_summary.csv"), row.names = FALSE)
# Failing: confirmed failures, and until the campaign is final the flags still awaiting confirmation (provisional).
failing_tests <- flagged_tests[grepl("^fail", flagged_tests$status) | (!final & grepl("pending", flagged_tests$status)), , drop = FALSE]
fkey <- function(d, metric) do.call(paste, c(d[key_cols], list(metric), sep = "\r"))
fails_k <- if (nrow(failing_tests)) fkey(failing_tests, failing_tests$metric) else character()
s$fail_size <- fkey(s, rep("size", nrow(s))) %in% fails_k
s$fail_coverage <- fkey(s, rep("coverage", nrow(s))) %in% fails_k
pw$fail_coverage <- fkey(pw, rep("coverage", nrow(pw))) %in% fails_k
s$q_size <- gate$q[match(fkey(s, rep("size", nrow(s))), fkey(gate, gate$metric))]
s$q_coverage <- gate$q[match(fkey(s, rep("coverage", nrow(s))), fkey(gate, gate$metric))]
pw$q_coverage <- gate$q[match(fkey(pw, rep("coverage", nrow(pw))), fkey(gate, gate$metric))]
# What a reader should know about a cell's level (reported next to the failing values): an unknown rate
# that fails says so; an O(1) design-mismatch cell that is conservative (more than 2 Monte Carlo SE on the
# safe side) is expected to be, never failed.
mc_se <- function(p0, m) sqrt(p0 * (1 - p0) / pmax(m, 1))
s$note <- ifelse((s$fail_size & s$rule_size == "unknown") | (s$fail_coverage & s$rule_coverage == "unknown"),
	"rate unknown: open a TODO to establish it", "")
cons_s <- (s$rule_size == "mismatch" & !is.na(s$size) & s$size < CAL_GATE_NOMINAL[["size"]] - 2 * mc_se(CAL_GATE_NOMINAL[["size"]], s$n_p)) |
	(s$rule_coverage == "mismatch" & !is.na(s$coverage) & s$coverage > CAL_GATE_NOMINAL[["coverage"]] + 2 * mc_se(CAL_GATE_NOMINAL[["coverage"]], s$n_ci))
s$note[cons_s & !s$fail_size & !s$fail_coverage] <- "conservative (expected: model SE ignores the design)"
pw$note <- ifelse(pw$fail_coverage & pw$rule_coverage == "unknown", "rate unknown: open a TODO to establish it", "")
cons_p <- pw$rule_coverage == "mismatch" & !is.na(pw$coverage) & pw$coverage > CAL_GATE_NOMINAL[["coverage"]] + 2 * mc_se(CAL_GATE_NOMINAL[["coverage"]], pw$n_ci)
pw$note[cons_p & !pw$fail_coverage] <- "conservative (expected: model SE ignores the design)"
s <- s[order(!(s$fail_size | s$fail_coverage), cal_rt_rank(s$response_type), s$inf_class, s$inf_procedure, s$formula, s$n, s$design), ]
ucols <- cal_stats_u_cols()
utils::write.csv(s[setdiff(names(s), ucols)], file.path(out_dir, "calibration_summary.csv"), row.names = FALSE)

# P-value calibration curves (null).
pc <- do.call(rbind, lapply(seq_along(CAL_STATS_U), function(j) {
	data.frame(s[cell_cols], u = rep(CAL_STATS_U[[j]], nrow(s)), dev = ifelse(s$n_p > 0, s[[ucols[[j]]]] / s$n_p - CAL_STATS_U[[j]], NA_real_),
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
# bias_sd_large_n (TODO-200): |bias| / SD above the flag at the campaign's largest n. Reported, never gated.
b$bias_sd_large_n <- b$n_nominal >= max_of(b$n_nominal) & is.finite(b$null_bias_std) & abs(b$null_bias_std) > CAL_GATE_BIAS_SD_FLAG
b$flag_null_bias <- !is.na(b$p_null_bias) & b$p_null_bias < threshold_bias & abs(b$null_bias_std) > NULL_BIAS_STD_FLAG
b <- b[order(!b$flag_null_bias, !b$bias_sd_large_n, -abs(ifelse(is.na(b$null_bias_std), 0, b$null_bias_std))), ]
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
nb_est$bias_sd_large_n <- nb_est$n_nominal >= max_of(nb_est$n_nominal) & is.finite(nb_est$bias_std) & abs(nb_est$bias_std) > CAL_GATE_BIAS_SD_FLAG
nb_est$flag_bias <- !is.na(nb_est$p_bias) & nb_est$p_bias < FAMILY_ALPHA / max(K_nnbias, 1L) &
	abs(nb_est$bias_std) > NULL_BIAS_STD_FLAG
nb_est <- nb_est[order(!nb_est$flag_bias, !nb_est$bias_sd_large_n, -abs(ifelse(is.na(nb_est$bias_std), 0, nb_est$bias_std))), ]
utils::write.csv(nb_est, file.path(out_dir, "nonnull_bias_summary.csv"), row.names = FALSE)

# Power.
pw <- pw[order(!pw$fail_coverage, cal_rt_rank(pw$response_type), pw$inf_class, pw$inf_procedure, pw$formula, pw$n, pw$effect_label,
	pw$design), c(cell_cols, "effect_label", "reps", "n_p", "rej", "power", "power_se", "n_ci", "cov", "coverage",
	"truth_available", "regime", "n_eff", "n_eff_rule", "n_eff_flag", "expected_order", "basis", "regularity", "rule_coverage",
	"rate_verdict_coverage", "coverage_null", "p_coverage", "q_coverage", "fail_coverage", "note")]
utils::write.csv(pw, file.path(out_dir, "power_summary.csv"), row.names = FALSE)

# Class status (v1.0.5 TODO-203): how far each class has got and the worst gate verdict so far, for the Classes page of the README.
# verdict: fail (a confirmed failure, or a flag whose confirmation could not run), pending confirmation (flags awaiting their
# fresh replicates), pass (class complete, nothing flagged), pass so far (still running, nothing flagged), not started.
if (have_plan) {
	cp <- cal_class_progress(plan)
	ck <- paste(cp$response_type, cp$inf_class, sep = "|")
	ftk <- paste(flagged_tests$response_type, flagged_tests$inf_class, sep = "|")
	cnt <- function(pat) as.integer(table(factor(ftk[grepl(pat, flagged_tests$status)], levels = ck)))
	cp$flagged <- as.integer(table(factor(ftk, levels = ck)))
	cp$pending <- cnt("pending")
	cp$confirmed_fail <- cnt("fail \\(confirmed\\)")
	cp$could_not_confirm <- cnt("could not run")
	cp$cleared <- cnt("cleared")
	cp$verdict <- ifelse(cp$status == "not started", "not started", ifelse(cp$confirmed_fail + cp$could_not_confirm > 0, "fail",
		ifelse(cp$pending > 0, "pending confirmation", ifelse(cp$status == "complete", "pass", "pass so far"))))
	utils::write.csv(cp, file.path(out_dir, "class_status.csv"), row.names = FALSE)
}

# Markdown.
fails <- s[s$fail_size | s$fail_coverage, ]
flagged <- b[b$flag_null_bias, ]
fmt <- function(x, d = 3) ifelse(is.na(x), "", trimws(formatC(x, digits = d, format = "fg")))
# "0.07 **FAIL** (level 0.10, cap)" style cell of the failing tables.
lv_cell <- function(v, fail, level, rule) sprintf("%s%s (level %s, %s)", fmt(v), ifelse(fail, " **FAIL**", ""), fmt(level), sub("_", " ", rule))
order_cell <- function(o, basis) ifelse(is.na(o), "unknown", paste0(ifelse(is.infinite(o), "Inf", fmt(o)), " (", basis, ")"))
neff_cell <- function(n, flag) paste0(fmt(n), ifelse(flag == "nominal", "", " (proxy)"))
short_design <- function(x, p) paste0(sub("^Design(Fixed|SeqOneByOne)", "", x), ifelse(p != 0.5, paste0("@", p), ""))
md <- c(paste("##", title), "", if (nzchar(note)) c(note, "") else NULL,
	if (K > 0 && have_plan) c(sprintf(paste("%d null cells and %d power cells have results; %d of the plan's %d tests (null size and coverage,",
		"coverage of the true estimand at the power effects) have a p-value from a completed cell. Two-stage gate:",
		"Benjamini-Hochberg q < %g over all %d tests of the plan on the screening replicates (a test enters with its p-value when its",
		"cell's screening replicates are all in and counts as p = 1 until then, so a flag is never withdrawn; only \"not flagged\" is",
		"provisional) flags **%d** test(s); each flagged test is re-run on fresh replicates and fails only if those alone reject at",
		"0.01 / %d, fixed in advance, so a confirmed failure is final when it is made."), nrow(s), nrow(pw), K, m_total, SCREEN_Q, m_family,
		m, m_family), "",
		sprintf("Confirmation%s: %d confirmed failing, %d pending, %d could not be confirmed (counted as failing), %d cleared. Failing null cells%s: **%d**.",
			if (final) "" else " so far", sum(flagged_tests$status == "fail (confirmed)"), sum(grepl("pending", flagged_tests$status)),
			sum(flagged_tests$status == "fail (confirmation could not run)"), sum(flagged_tests$status == "cleared by confirmation"),
			if (final) "" else " so far (provisional)", nrow(fails)))
	else if (K > 0) c(sprintf(paste("%d null cells and %d power cells; %d tests (null size and coverage, coverage of the",
		"true estimand at the power effects). Two-stage gate: Benjamini-Hochberg q < %g on the screening replicates",
		"flags **%d** test(s); each flagged cell is re-run on fresh replicates and fails only if those alone reject",
		"(at 0.01 / %d)."), nrow(s), nrow(pw), K, SCREEN_Q, m, max(m, 1L)), "",
		if (!final) sprintf("Confirmation: pending (the flags are provisional). Failing null cells so far: **%d**.", nrow(fails))
		else sprintf("Confirmation: %d confirmed failing, %d could not be confirmed (counted as failing), %d cleared. Failing null cells: **%d**.",
			sum(flagged_tests$status == "fail (confirmed)"), sum(flagged_tests$status == "fail (confirmation could not run)"),
			sum(flagged_tests$status == "cleared by confirmation"), nrow(fails)))
	else sprintf("%d null cells, none with enough results for a size / coverage test yet.", nrow(s)), "")
md <- c(md, sprintf(paste("Levels (TODO-200): finite-sample procedures 0.05 / 0.95; asymptotic ones 0.05 + c n_eff^-a up to a cap of %g",
	"reached at n_eff = %g (a = the registry's expected order; rule `rate` below the cap, `cap` at it); unknown order: the cap",
	"below the campaign's largest n; a `slower` convergence verdict is held to the nominal level at the cell's largest n",
	"(`rate check`). Null cells by rule (size): %s."), CAL_GATE_CAP, CAL_GATE_N_CAP,
	if (nrow(s)) paste(sprintf("%s %d", names(table(s$rule_size)), as.integer(table(s$rule_size))), collapse = ", ") else "none"), "")
n_cons <- sum(s$note == "conservative (expected: model SE ignores the design)")
if (n_cons) md <- c(md, sprintf("%d design-mismatch null cell(s) are conservative (expected: model SE ignores the design); reported, never failed.", n_cons), "")
if (nrow(fails)) md <- c(md,
	"| response | design | class | procedure | formula | n | n_eff | order (basis) | size | coverage | finite | accepted | note |",
	"|---|---|---|---|---|---|---|---|---|---|---|---|---|",
	sprintf("| %s | %s | %s | %s | %s | %d | %s | %s | %s | %s | %d/%d | %s | %s |", fails$response_type,
		short_design(fails$design, fails$prob_T), sub("^Inference", "", fails$inf_class), fails$inf_procedure, fails$formula,
		as.integer(fails$n), neff_cell(fails$n_eff, fails$n_eff_flag), order_cell(fails$expected_order, fails$basis),
		lv_cell(fails$size, fails$fail_size, fails$size_null, fails$rule_size),
		lv_cell(fails$coverage, fails$fail_coverage, fails$coverage_null, fails$rule_coverage),
		as.integer(pmax(fails$n_p, fails$n_ci)), as.integer(fails$reps), fails$accepted, fails$note), "")
md <- c(md, "### Null bias (reported, not gated)", "",
	if (K_bias > 0) sprintf("%d estimand cells; flagged (z-test at 0.01 / %d and |bias| / SD > %g): **%d**.", nrow(b), K_bias,
		NULL_BIAS_STD_FLAG, nrow(flagged))
	else sprintf("%d estimand cells, none with enough results for a null-bias test yet.", nrow(b)), "")
b_large <- b[b$bias_sd_large_n, ]
md <- c(md, sprintf("`bias_sd_large_n` (|bias| / SD > %g at the campaign's largest n, %s): **%d** of %d cell(s) there; reported, not part of the gate.",
	CAL_GATE_BIAS_SD_FLAG, if (nrow(b)) as.character(max(b$n_nominal)) else "none yet", nrow(b_large), sum(b$n_nominal >= max_of(b$n_nominal))), "")
if (nrow(b_large)) {
	shown <- utils::head(b_large, 30L)
	md <- c(md, "| response | design | class | formula | n | null bias | bias / SD |", "|---|---|---|---|---|---|---|",
		sprintf("| %s | %s | %s | %s | %d | %s | %s |", shown$response_type, short_design(shown$design, shown$prob_T),
			sub("^Inference", "", shown$inf_class), shown$formula, as.integer(shown$n), fmt(shown$null_bias), fmt(shown$null_bias_std, 2)),
		if (nrow(b_large) > nrow(shown)) sprintf("(%d shown of %d; all in `null_bias_summary.csv`.)", nrow(shown), nrow(b_large)) else NULL, "")
}
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
		"| response | design | class | procedure | formula | n | n_eff | order (basis) | effect | coverage | finite | note |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|",
		sprintf("| %s | %s | %s | %s | %s | %d | %s | %s | %s | %s | %d/%d | %s |", pw_fails$response_type,
			short_design(pw_fails$design, pw_fails$prob_T), sub("^Inference", "", pw_fails$inf_class), pw_fails$inf_procedure,
			pw_fails$formula, as.integer(pw_fails$n), neff_cell(pw_fails$n_eff, pw_fails$n_eff_flag),
			order_cell(pw_fails$expected_order, pw_fails$basis), pw_fails$effect_label,
			lv_cell(pw_fails$coverage, TRUE, pw_fails$coverage_null, pw_fails$rule_coverage),
			as.integer(pw_fails$n_ci), as.integer(pw_fails$reps), pw_fails$note), "")
	md <- c(md, "### Bias at beta_T != 0 (reported, not gated)", "",
		if (K_nnbias > 0) sprintf("%d estimand cells; flagged (z-test at 0.01 / %d and |bias| / SD > %g): **%d**.",
			nrow(nb_est), K_nnbias, NULL_BIAS_STD_FLAG, nrow(nb_flagged))
		else sprintf("%d estimand cells, none with enough results for a bias test yet.", nrow(nb_est)), "")
	nb_large <- nb_est[nb_est$bias_sd_large_n, ]
	md <- c(md, sprintf("`bias_sd_large_n` (|bias| / SD > %g at the largest n, %s): **%d** of %d cell(s) there; reported, not part of the gate.",
		CAL_GATE_BIAS_SD_FLAG, if (nrow(nb_est)) as.character(max(nb_est$n_nominal)) else "none yet", nrow(nb_large),
		sum(nb_est$n_nominal >= max_of(nb_est$n_nominal))), "")
	if (nrow(nb_large)) {
		shown <- utils::head(nb_large, 30L)
		md <- c(md, "| response | design | class | formula | n | effect | bias | bias / SD |", "|---|---|---|---|---|---|---|---|",
			sprintf("| %s | %s | %s | %s | %d | %s | %s | %s |", shown$response_type, short_design(shown$design, shown$prob_T),
				sub("^Inference", "", shown$inf_class), shown$formula, as.integer(shown$n), shown$effect_label, fmt(shown$bias), fmt(shown$bias_std, 2)),
			if (nrow(nb_large) > nrow(shown)) sprintf("(%d shown of %d; all in `nonnull_bias_summary.csv`.)", nrow(shown), nrow(nb_large)) else NULL, "")
	}
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
# Failing cells, not tests: a cell failing both size and coverage counts once
# (the workflow's gate and the results index both read this as a cell count).
writeLines(as.character(nrow(fails) + sum(pw$fail_coverage, na.rm = TRUE)), file.path(out_dir, "gate_failures.txt"))
# Failure triage: the failing cells grouped by class x procedure x metric (calibration_study_triage.R), read by
# triage_calibration_study.R to draft release-plan TODOs. Provisional (campaign_final FALSE) until --final.
utils::write.csv(cal_triage_groups(out_dir, max_n = if (have_plan) max(plan$n) else NA, final = final),
	file.path(out_dir, "triage.csv"), row.names = FALSE)
writeLines(md, file.path(out_dir, "calibration_summary.md"))
if (!is.null(summary_md)) cat(md, sep = "\n", file = summary_md, append = TRUE)
cat(md, sep = "\n")
