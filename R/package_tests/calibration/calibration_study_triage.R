# Failure triage for the published calibration study: groups a campaign's failing cells into one row per
# response type x class x procedure x metric, across designs, formulas, n and effects, so one likely cause is one
# row rather than dozens of cells. analyze_calibration_study.R writes the result as summary/triage.csv after every
# wave (provisional until the campaign is final); triage_calibration_study.R reads it from the results branch and
# drafts release-plan TODOs from it.
#
# metric:
#   size      null size failing its gate level (calibration_summary.csv fail_size)
#   coverage  coverage failing its gate level, null (calibration_summary.csv) and at the power effects
#             (power_summary.csv), merged: one group whatever the effect
#   bias      |bias| / SD above the flag at the campaign's largest n (bias_sd_large_n, null_bias_summary.csv and
#             nonnull_bias_summary.csv). Reported, never gated; the estimate is per class, so inf_procedure is "estimate".
#
# category / suggested_release (the triage rule, owner-approved 2026-11-12):
#   bug           -> current: a finite-sample procedure (exact, rand) failing at any n, or an asymptotic one failing at
#                    the campaign's largest n (the level there is nearly nominal, so it does not converge), or one whose
#                    largest n never ran
#   small_sample  -> next:    an asymptotic procedure failing only below the largest n
#   bias          -> next:    drafted only when it shows on at least two designs (n_designs)
#
# Each row names its worst cell (largest excess over the level) and a command that re-runs that cell locally.

CAL_TRIAGE_REPRO_REPS <- "1:200"

# Short design names as in the README tables ("KK21", "Bernoulli@0.2").
cal_triage_short_design <- function(design, prob_T)
	paste0(sub("^Design(Fixed|SeqOneByOne)", "", design), ifelse(!is.na(prob_T) & abs(prob_T - 0.5) > 1e-9, paste0("@", prob_T), ""))

cal_triage_repro <- function(response_type, design, prob_T, n, effect, inf_class) {
	label <- ifelse(!is.na(prob_T) & abs(prob_T - 0.5) > 1e-9, paste0(design, "@prob_T=", prob_T), design)
	sprintf(paste("Rscript R/package_tests/calibration/run_calibration_study.R --response-type %s --design %s --n %d",
		"--effect %s --only %s --reps %s --out-dir \"$TMPDIR/cal_repro\""), response_type, shQuote(label), as.integer(n), effect,
		inf_class, CAL_TRIAGE_REPRO_REPS)
}

# One row per failing (cell, metric) item, in a common shape, from the analysis CSVs in summary_dir.
cal_triage_items <- function(summary_dir) {
	rd <- function(f) {
		p <- file.path(summary_dir, f)
		if (file.exists(p) && file.size(p) > 0) utils::read.csv(p, stringsAsFactors = FALSE) else NULL
	}
	s <- rd("calibration_summary.csv"); pw <- rd("power_summary.csv")
	b <- rd("null_bias_summary.csv"); nb <- rd("nonnull_bias_summary.csv")
	cf <- rd("confirmation_summary.csv")
	tkey <- function(d, metric, effect) paste(d$response_type, d$design, d$prob_T, d$inf_class, d$formula, d$n, d$inf_procedure, effect, metric, sep = "|")
	status_of <- function(d, metric, effect) {
		if (is.null(cf) || !nrow(cf)) return(rep("", nrow(d)))
		st <- cf$status[match(tkey(d, metric, effect), tkey(cf, cf$metric, cf$effect_label))]
		ifelse(is.na(st), "", st)
	}
	mk <- function(d, metric, effect, value, level, reps, regime, rule, accepted) {
		if (!nrow(d)) return(NULL)
		data.frame(response_type = d$response_type, design = d$design, prob_T = d$prob_T, inf_class = d$inf_class,
			inf_procedure = d$inf_procedure, formula = d$formula, n = d$n_nominal, effect = effect, metric = metric,
			value = value, level = level, excess = if (metric == "coverage") level - value else if (metric == "size") value - level else abs(value) - level,
			reps = reps, regime = regime, rule = rule, accepted = accepted, status = status_of(d, metric, effect), stringsAsFactors = FALSE)
	}
	acc <- function(d) if ("accepted" %in% names(d)) ifelse(is.na(d$accepted), "", as.character(d$accepted)) else rep("", nrow(d))
	out <- list()
	if (!is.null(s) && nrow(s)) {
		f <- s[s$fail_size %in% TRUE, , drop = FALSE]
		out$size <- mk(f, "size", rep("null", nrow(f)), f$size, f$size_null, f$n_p, f$regime, f$rule_size, acc(f))
		f <- s[s$fail_coverage %in% TRUE, , drop = FALSE]
		out$cov <- mk(f, "coverage", rep("null", nrow(f)), f$coverage, f$coverage_null, f$n_ci, f$regime, f$rule_coverage, acc(f))
	}
	if (!is.null(pw) && nrow(pw)) {
		f <- pw[pw$fail_coverage %in% TRUE, , drop = FALSE]
		out$pcov <- mk(f, "coverage", f$effect_label, f$coverage, f$coverage_null, f$n_ci, f$regime, f$rule_coverage, acc(f))
	}
	bias_items <- function(d, std_col, effect) {
		f <- d[d$bias_sd_large_n %in% TRUE, , drop = FALSE]
		if (!nrow(f)) return(NULL)
		f$inf_procedure <- "estimate"
		r <- mk(f, "bias", effect(f), f[[std_col]], rep(CAL_TRIAGE_BIAS_FLAG, nrow(f)), f$n_est, rep(NA_character_, nrow(f)),
			rep("flag", nrow(f)), rep("", nrow(f)))
		r$status <- "reported (not gated)"
		r
	}
	if (!is.null(b) && nrow(b)) out$bias <- bias_items(b, "null_bias_std", function(f) rep("null", nrow(f)))
	if (!is.null(nb) && nrow(nb)) out$nbias <- bias_items(nb, "bias_std", function(f) f$effect_label)
	out <- Filter(Negate(is.null), out)
	if (!length(out)) return(NULL)
	do.call(rbind, out)
}
# The bias flag of calibration_study_stats.R (CAL_GATE_BIAS_SD_FLAG) when sourced with it, else its value.
CAL_TRIAGE_BIAS_FLAG <- if (exists("CAL_GATE_BIAS_SD_FLAG")) CAL_GATE_BIAS_SD_FLAG else 0.1

# The n each group was tested at (any result), for the pattern: from calibration_summary.csv (size / null coverage),
# power_summary.csv (coverage), and the bias summaries (bias).
cal_triage_tested_n <- function(summary_dir) {
	rd <- function(f) {
		p <- file.path(summary_dir, f)
		if (file.exists(p) && file.size(p) > 0) utils::read.csv(p, stringsAsFactors = FALSE) else NULL
	}
	s <- rd("calibration_summary.csv"); pw <- rd("power_summary.csv")
	b <- rd("null_bias_summary.csv"); nb <- rd("nonnull_bias_summary.csv")
	rows <- list(
		if (!is.null(s)) data.frame(response_type = s$response_type, inf_class = s$inf_class, inf_procedure = s$inf_procedure,
			metric = "size", n = s$n_nominal)[s$n_p > 0, , drop = FALSE],
		if (!is.null(s)) data.frame(response_type = s$response_type, inf_class = s$inf_class, inf_procedure = s$inf_procedure,
			metric = "coverage", n = s$n_nominal)[s$n_ci > 0, , drop = FALSE],
		if (!is.null(pw) && nrow(pw)) data.frame(response_type = pw$response_type, inf_class = pw$inf_class, inf_procedure = pw$inf_procedure,
			metric = "coverage", n = pw$n_nominal)[pw$n_ci > 0, , drop = FALSE],
		if (!is.null(b) && nrow(b)) data.frame(response_type = b$response_type, inf_class = b$inf_class, inf_procedure = "estimate",
			metric = "bias", n = b$n_nominal)[b$n_est > 0, , drop = FALSE],
		if (!is.null(nb) && nrow(nb)) data.frame(response_type = nb$response_type, inf_class = nb$inf_class, inf_procedure = "estimate",
			metric = "bias", n = nb$n_nominal)[nb$n_est > 0, , drop = FALSE])
	rows <- Filter(function(d) !is.null(d) && nrow(d), rows)
	if (!length(rows)) return(NULL)
	unique(do.call(rbind, rows))
}

CAL_TRIAGE_COLS <- c("group_id", "response_type", "inf_class", "inf_procedure", "metric", "category", "suggested_release",
	"pattern", "regime", "n_cells", "n_confirmed", "n_provisional", "n_designs", "designs", "formulas", "effects", "failing_ns",
	"tested_ns", "accepted", "worst_cell", "worst_value", "worst_level", "worst_reps", "repro", "campaign_final")

# summary_dir: the analysis outputs; max_n: the campaign's largest planned n (the plan's; else the largest seen);
# final: the campaign is complete. Returns a data frame with CAL_TRIAGE_COLS, worst groups first (bugs, then by excess).
cal_triage_groups <- function(summary_dir, max_n = NA, final = FALSE) {
	it <- cal_triage_items(summary_dir)
	empty <- as.data.frame(stats::setNames(replicate(length(CAL_TRIAGE_COLS), character(), simplify = FALSE), CAL_TRIAGE_COLS))
	if (is.null(it) || !nrow(it)) return(empty)
	tn <- cal_triage_tested_n(summary_dir)
	if (!is.finite(max_n)) max_n <- max(c(it$n, tn$n))
	gk <- paste(it$response_type, it$inf_class, it$inf_procedure, it$metric, sep = "|")
	tk <- if (is.null(tn)) character() else paste(tn$response_type, tn$inf_class, tn$inf_procedure, tn$metric, sep = "|")
	fmt <- function(x) trimws(formatC(x, digits = 3, format = "fg"))
	rows <- lapply(split(seq_len(nrow(it)), factor(gk, levels = unique(gk))), function(ix) {
		g <- it[ix, , drop = FALSE]
		fail_ns <- sort(unique(g$n))
		tested <- sort(unique(c(fail_ns, tn$n[tk == gk[ix[1L]]])))
		finite <- any(g$regime %in% "finite_sample")
		pattern <- if (max(fail_ns) >= max_n) "persistent: fails at the largest n"
			else if (max(tested) < max_n) "largest n not run"
			else "small n only: passes at the largest n"
		designs <- unique(cal_triage_short_design(g$design, g$prob_T))
		category <- if (g$metric[1L] == "bias") "bias"
			else if (finite || !startsWith(pattern, "small n only")) "bug" else "small_sample"
		w <- g[which.max(g$excess), ]
		data.frame(
			response_type = g$response_type[1L], inf_class = g$inf_class[1L], inf_procedure = g$inf_procedure[1L], metric = g$metric[1L],
			category = category, suggested_release = if (category == "bug") "current" else "next", pattern = pattern,
			regime = if (finite) "finite_sample" else if (all(is.na(g$regime))) "" else paste(sort(unique(stats::na.omit(g$regime))), collapse = ";"),
			n_cells = nrow(g), n_confirmed = sum(grepl("^fail", g$status)), n_provisional = sum(grepl("pending", g$status)),
			n_designs = length(designs), designs = paste(designs, collapse = ";"), formulas = paste(sort(unique(g$formula)), collapse = ";"),
			effects = paste(unique(g$effect), collapse = ";"), failing_ns = paste(fail_ns, collapse = ";"), tested_ns = paste(tested, collapse = ";"),
			accepted = any(nzchar(g$accepted)),
			worst_cell = sprintf("%s, %s, n = %d, %s: %s %s vs level %s", cal_triage_short_design(w$design, w$prob_T), w$formula,
				as.integer(w$n), w$effect, w$metric, fmt(w$value), fmt(w$level)),
			worst_value = w$value, worst_level = w$level, worst_reps = w$reps,
			repro = cal_triage_repro(w$response_type, w$design, w$prob_T, w$n, w$effect, w$inf_class),
			campaign_final = final, excess = w$excess, stringsAsFactors = FALSE)
	})
	r <- do.call(rbind, rows)
	r <- r[order(match(r$category, c("bug", "small_sample", "bias")), -r$excess), , drop = FALSE]
	r$group_id <- paste(r$response_type, sub("^Inference", "", r$inf_class), r$inf_procedure, r$metric, sep = "/")
	rownames(r) <- NULL
	r[CAL_TRIAGE_COLS]
}
