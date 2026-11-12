#!/usr/bin/env Rscript
# Per class (v1.0.5 TODO-203, new_feature_plans/v1_0_5/calibration_class_major_campaign_order.md): classes.md (every class
# of the campaign's plan with its status and worst verdict) and one class-<Class>.md per class (figure, convergence
# verdicts, the class's cells), from summary/class_status.csv; both have the same back-links.
# Writes the READMEs of the public calibration-results branch (release_v1_2_0.md
# TODO-36): campaigns/<id>/README.md (that campaign's short master page) with its
# sub-pages next to it (v1.0.5 TODO-201: failing cells per response type, screen flags,
# bias, designs, convergence, figures per response type, data, about; every sub-page
# starts and ends with a link back to README.md; relative links only), and the branch's
# top-level README.md (what the study is, the latest campaign, every campaign so far).
# No EDI needed.
#
# Usage: Rscript R/package_tests/calibration/render_calibration_study_readme.R \
#          --results-dir DIR --campaign ID --repo OWNER/NAME [--progress TEXT]

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
source(file.path(script_dir, "calibration_study_stats.R"))   # CAL_STUDY_RT_DISPLAY_ORDER
args <- commandArgs(TRUE)
arg_value <- function(flag, default = NULL) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
results_dir <- arg_value("--results-dir")
campaign <- arg_value("--campaign")
repo <- arg_value("--repo", "kapelner/EDI")
progress <- arg_value("--progress", "")
cdir <- file.path(results_dir, "campaigns", campaign)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

read_env <- function(f) {
	if (!file.exists(f)) return(list())
	l <- readLines(f, warn = FALSE)
	l <- l[grepl("=", l, fixed = TRUE)]
	stats::setNames(as.list(sub("^[^=]*=", "", l)), sub("=.*$", "", l))
}
rd <- function(f) if (file.exists(f)) readLines(f, warn = FALSE) else character()
env <- read_env(file.path(cdir, "campaign.env"))
runs <- rd(file.path(cdir, "runs.txt"))
gate <- rd(file.path(cdir, "summary", "gate_failures.txt"))
complete <- identical(rd(file.path(cdir, "status.txt")), "complete")

about <- c(
	"Every month EDI re-runs a simulation study of its own inference procedures on GitHub Actions and publishes the",
	"results here: Type I error (size), confidence-interval coverage and null bias for every inference class on every",
	"design it applies to, and power under identical data on every design. Nothing is hand-picked: every cell of the",
	"study is in the tables, failures included.", "",
	"* **Data:** synthetic, n = 50, 200 and 1000 subjects, five covariates (three continuous, two binary factors) that",
	"  explain about half the outcome variance, drawn from each response type's own model. Formulas `~ 1` (treatment",
	"  only) and `~ .` (treatment + all covariates).",
	"* **Order (v1.0.5 TODO-203):** a campaign runs class by class: the null effect first, then the power effects; within an",
	"  effect by response type, then inference class; within a class by design, then n = 50, 200, 1000, then the class's",
	"  confirmation replicates when any of its tests is flagged. A class is finished before the next starts (several fast",
	"  classes of one cell share a shard and its data and design, so a few neighbouring classes run together), so verdicts",
	"  become final class by class. All procedures of a class share one fit on the same data and are never split.",
	"* **Null:** no treatment effect, 1,000 replicates per cell. Size and coverage are tested against a level that",
	"  depends on the procedure's regime and on n (below), with exact one-sided binomial tests, in two stages. Screen: Benjamini-Hochberg q < 0.05 over every test the",
	"  whole campaign plan contains (the number m is known in advance; a test that has not run counts as p = 1, and a test",
	"  enters with its p-value once its cell's screening replicates are all in) flags a test (catching size of about 0.07 at 1,000",
	"  replicates). BH is monotone in the p-values, so a flag is never withdrawn by later results: only \"not flagged\" is",
	"  provisional while the campaign runs. Confirm: each flagged test is re-run",
	"  on 5,000 fresh replicates (1,000 for the slow classes) and fails only if those alone reject, at 0.01 over m, the total number of tests in the plan",
	"  (fixed in advance, so a confirmed failure is final when it is made; with 5,000 replicates this still detects a size of about 0.065);",
	"  one with fewer than 500 confirmation results counts as failing. Null bias (mean",
	"  estimate minus the null value) is reported and flagged, not gated: an honest estimator has O(1/n) null bias on",
	"  ratio scales and under unequal allocation.",
	"* **Levels (v1.0.5 TODO-200):** each procedure is either asymptotic (Wald, jackknife, score, likelihood ratio,",
	"  gradient, Bartlett, the bootstraps, the randomization bootstrap) or finite-sample (exact, randomization); the registry is",
	sprintf("  [`inference_procedure_regime.R`](https://github.com/%s/blob/main/R/EDI/R/inference_procedure_regime.R).", repo),
	"  Finite-sample procedures are held to size 5% and coverage 95% at every n. An asymptotic procedure with a known",
	"  convergence order a (the registry's expected order of its size error, `inference_convergence_expectation()`) is",
	"  held to size min(10%, 5% + c n_eff^-a) and coverage 1 minus that, with c chosen so the level reaches the 10% cap at",
	"  an effective n of 50 (a = 1: 10% up to n_eff 50, 7.5% at 100, 6.25% at 200, 5.25% at 1,000). n_eff is the nominal",
	"  effective sample size of the registry's rule (n, pairs, the smaller arm; counts the summary statistics do not carry",
	"  fall back to n and are marked `proxy`). Procedures whose order is unknown are held to the cap at every n below the",
	"  campaign's largest n and to the a = 1 level at it (a failure says \"rate unknown: open a TODO to establish it\").",
	"  Cells with an expected O(1) error from a design mismatch (the model standard error ignores the design) fail only on the",
	"  anticonservative side; conservative ones are reported. Rate check: a cell converging slower than its expected order",
	"  (whole CI for the order below it) is held to the nominal level at its largest n. With 5,000 confirmation replicates",
	"  an excess of about 0.006 is detectable at the largest n, so \"nominal\" there means no worse than about 0.06. Each table",
	"  gives, per cell, the regime, n_eff, expected order and basis, the level tested and the rule that set it (finite, rate,",
	"  cap, unknown, mismatch, rate check, accepted). Accepted cells use their own level.",
	"* **Which red:** a campaign is red only when its `analyze` job's last step, `Gate verdict`, fails: a completed campaign",
	"  with confirmed failing cells (annotation \"Calibration gate\"). A failure of any other step or job is a bug in the check",
	"  itself (annotation \"Calibration CI bug\"), never a calibration result.",
	"* **Power:** three effect sizes per response type, set to give 20 / 50 / 80% power to the Bernoulli-design",
	"  baseline class at every n, 500 replicates per cell. Every design in a replicate sees the same subjects and",
	"  outcomes, so power differences between designs are differences between designs. When a campaign completes,",
	"  each design's power is compared with Bernoulli's by an exact McNemar test on the replicates they share",
	"  (`design_comparison.csv`; unpaired where a design runs at another n). Reported, not gated.",
	"* **Away from the null:** coverage at every power effect is tested like the null coverage (same two-stage",
	"  gate), and bias is reported like the null bias, both against the true value of each class's own estimand:",
	"  its estimate on eight samples of 20,000 from the same data generator (median; `calibrate_study_truths.R`). A",
	"  marginal log odds ratio under `~1` is not the conditional beta_T, so each class gets its own value. Classes",
	"  that apply only to matched designs have none (their estimand depends on the pairing), nor do cells where",
	"  fewer than 75% of the large-sample fits were finite; both are reported as having no true value.",
	"* **Slow classes:** the KK random-effects fits for count and ordinal responses on the matched designs",
	"  (`InferenceCountKKGLMM` and the four `InferenceOrdinalKKCLMM*` links) take 4-40 minutes per replicate at",
	"  n = 1000, so they get 500 null replicates at n = 1000 (1,000 below) and power at n = 50 only. Every table",
	"  gives each cell's own replicate count.",
	"* **Procedures:** Wald, score, likelihood ratio, gradient and exact tests and CIs, and the randomization test,",
	"  monthly. Bootstrap, jackknife, Bartlett-corrected and randomization CIs run in slower tiers (see",
	sprintf("  [the plan](https://github.com/%s/blob/main/R/package_metadata/future_release_plans/release_v1_2_0.md)).", repo),
	sprintf("* **Code:** [`R/package_tests/calibration/`](https://github.com/%s/tree/main/R/package_tests/calibration),", repo),
	"  run by `.github/workflows/calibration-study.yml`; each campaign is pinned to one EDI commit.")

# ---- Campaign pages (v1.0.5 TODO-201) ---------------------------------------------------

# The analysis's markdown starts with its own "## <title>" (it doubles as the job summary);
# bare csv names in it become links into summary/. Sub-pages sit next to README.md, so the same
# relative links (summary/, figures/) work on every page.
link_csv <- function(x) gsub("`(calibration_summary|confirmation_summary|null_bias_summary|nonnull_bias_summary|power_summary|pvalue_curves|design_comparison|convergence_summary|convergence_points)\\.csv`",
	"[`summary/\\1.csv`](summary/\\1.csv)", x)
summary_md <- link_csv(rd(file.path(cdir, "summary", "calibration_summary.md")))
back <- sprintf("[← Campaign %s summary](README.md)", campaign)
pages <- list()   # file -> list(title, body)
add_page <- function(file, title, body) pages[[file]] <<- list(title = title, body = body)

# Split the summary markdown: text before the first "### " (counts, levels, the failing table),
# then one block per "### " heading.
first_h3 <- which(grepl("^### ", summary_md))[1L]
pre <- if (is.na(first_h3)) summary_md else summary_md[seq_len(first_h3 - 1L)]
blocks <- list()
if (!is.na(first_h3)) {
	starts <- which(grepl("^### ", summary_md))
	ends <- c(starts[-1L] - 1L, length(summary_md))
	for (i in seq_along(starts)) blocks[[sub("^### ", "", summary_md[[starts[i]]])]] <- summary_md[starts[i]:ends[i]]
}
pre_title <- grepl("^## ", pre)
pre_table <- grepl("^\\|", pre)
pre_text <- pre[!pre_title & !pre_table]
tbl <- pre[pre_table]
tbl_head <- tbl[1:min(2L, length(tbl))]
tbl_rows <- if (length(tbl) > 2L) tbl[-(1:2)] else character()
tbl_rt <- sub("^\\| ([^ |]+) \\|.*$", "\\1", tbl_rows)
rts <- CAL_STUDY_RT_DISPLAY_ORDER
rts <- c(rts, setdiff(unique(tbl_rt), rts))

# Failing cells, one page per response type. A response type with no results yet says "pending", never "0 failing"
# (owner, 2026-11-12): zero failures is a result, and it has none.
cs_path <- file.path(cdir, "summary", "calibration_summary.csv")
rts_with_results <- if (file.exists(cs_path) && file.size(cs_path) > 2L)
	unique(utils::read.csv(cs_path, stringsAsFactors = FALSE, colClasses = c(formula = "character"))$response_type) else character()
fail_files <- character()
fail_label <- character()
for (rt in rts) {
	f <- sprintf("failing-%s.md", rt)
	rows_rt <- tbl_rows[tbl_rt == rt]
	fail_files[[rt]] <- f
	started <- rt %in% rts_with_results || length(rows_rt) > 0L
	fail_label[[rt]] <- if (started) sprintf("%d failing cell(s)", length(rows_rt)) else "pending (not run yet)"
	add_page(f, sprintf("Failing cells: %s", rt), if (!started) c(sprintf("Pending: no %s cell has run yet.", rt), "") else c(
		sprintf("%d failing %s cell(s) (%s).", length(rows_rt), rt, if (complete) "confirmed" else "provisional: confirmation pending or running"), "",
		if (length(rows_rt)) c(tbl_head, rows_rt) else "None.", ""))
}

# Screen flags and confirmation verdicts.
conf <- file.path(cdir, "summary", "confirmation_summary.csv")
flag_body <- if (file.exists(conf) && file.size(conf) > 0) {
	cs <- utils::read.csv(conf, stringsAsFactors = FALSE, colClasses = c(formula = "character"))
	if (nrow(cs)) {
		st <- table(cs$status)
		shown <- utils::head(cs[order(cs$q), ], 300L)
		fm <- function(x) ifelse(is.na(x), "", formatC(x, digits = 3, format = "g"))
		c(sprintf("%d test(s) flagged at the screen (Benjamini-Hochberg q < 0.05): %s.", nrow(cs),
			paste(sprintf("%d %s", as.integer(st), names(st)), collapse = ", ")), "",
			if ("rule" %in% names(cs)) c(paste0("By the rule that set the level: ", paste(sprintf("%s %d", names(table(cs$rule)), as.integer(table(cs$rule))), collapse = ", "), "."), "") else NULL,
			sprintf("The %d most significant (all rows: [`summary/confirmation_summary.csv`](summary/confirmation_summary.csv)).", nrow(shown)), "",
			"| response | design | class | procedure | formula | n | effect | metric | level | rule | q | confirmation | status |", "|---|---|---|---|---|---|---|---|---|---|---|---|---|",
			sprintf("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |", shown$response_type,
				sub("^Design(Fixed|SeqOneByOne)", "", shown$design), sub("^Inference", "", shown$inf_class), shown$inf_procedure, shown$formula,
				shown$n, shown$effect_label, shown$metric, fm(shown$level), if ("rule" %in% names(shown)) shown$rule else "", fm(shown$q),
				ifelse(is.na(shown$confirm_value), "pending", sprintf("%s over %s", fm(shown$confirm_value), shown$confirm_n)), shown$status), "")
	} else "Nothing flagged at the screen."
} else "No screen flags yet."
add_page("flags.md", "Screen flags and confirmation verdicts", flag_body)

# Bias, coverage away from the null, designs.
blk <- function(prefix) { i <- which(startsWith(names(blocks), prefix)); if (length(i)) unlist(blocks[i], use.names = FALSE) else character() }
add_page("null-bias.md", "Null bias", c(blk("Null bias"), ""))
nn <- c(blk("Coverage at beta_T"), blk("Bias at beta_T"))
add_page("nonnull.md", "Coverage and bias away from the null", c(if (length(nn)) nn else "No power cells in this campaign yet.", ""))
dc <- file.path(cdir, "summary", "design_comparison.csv")
dc_body <- if (file.exists(dc) && file.size(dc) > 2L) {
	d <- utils::read.csv(dc, stringsAsFactors = FALSE, colClasses = c(formula = "character"))
	if (nrow(d)) {
		top <- utils::head(d[order(d$q_bh), ], 25L)
		c(sprintf("%d paired / unpaired power comparison(s) against the Bernoulli baseline; %d with q < 0.05. Table: [`summary/design_comparison.csv`](summary/design_comparison.csv).",
			nrow(d), sum(d$q_bh < 0.05, na.rm = TRUE)), "", sprintf("The %d most significant:", nrow(top)), "",
			"| response | n | effect | class | procedure | formula | design | power (design) | power (Bernoulli) | q |", "|---|---|---|---|---|---|---|---|---|---|",
			sprintf("| %s | %s | %s | %s | %s | %s | %s | %.3f | %.3f | %.2g |", top$response_type, top$n_nominal, top$effect_label,
				sub("^Inference", "", top$inf_class), top$inf_procedure, top$formula, sub("^Design(Fixed|SeqOneByOne)", "", top$design),
				top$power_design, top$power_base, top$q_bh), "")
	} else c("No comparisons.", "")
} else c("`design_comparison.csv` (paired power tests between designs) is written when the campaign completes.", "")
add_page("designs.md", "Design comparison and power", c(blk("Power"), dc_body))

# Convergence (TODO-199).
conv_md <- link_csv(rd(file.path(cdir, "summary", "convergence_summary.md")))
add_page("convergence.md", "Convergence slopes", c(conv_md, "Tables: [`summary/convergence_summary.csv`](summary/convergence_summary.csv) (one row per cell and metric),",
	"[`summary/convergence_points.csv`](summary/convergence_points.csv) (the errors it was fitted to).", ""))

# Figures: the plot script's fragment (### section, #### response type) regrouped per response type.
fig <- rd(file.path(cdir, "figures.md"))
fig_files <- character()
h3 <- which(grepl("^### ", fig))
fig_sections <- lapply(seq_along(h3), function(i) {
	x <- fig[h3[i]:(c(h3[-1L] - 1L, length(fig))[i])]
	h4 <- which(grepl("^#### ", x))
	intro <- if (length(h4)) x[2L:max(2L, h4[1L]) ][seq_len(max(h4[1L] - 2L, 0L))] else x[-1L]
	rt_blocks <- lapply(seq_along(h4), function(j) x[(h4[j] + 1L):c(h4[-1L] - 1L, length(x))[j]])
	names(rt_blocks) <- tolower(sub("^#### ", "", x[h4]))
	list(head = x[1L], intro = intro, rt = rt_blocks)
})
for (rt in rts) {
	body <- unlist(lapply(fig_sections, function(sec) if (is.null(sec$rt[[rt]])) NULL else c(sec$head, "", sec$intro, sec$rt[[rt]])))
	f <- sprintf("figures-%s.md", rt)
	fig_files[[rt]] <- f
	add_page(f, sprintf("Figures: %s", rt), c(if (length(body)) body else "No figures for this response type yet.", ""))
}

# Classes (TODO-203): the index page and one page per class.
rdcsv <- function(f) {
	p <- file.path(cdir, "summary", f)
	if (file.exists(p) && file.size(p) > 2L) suppressWarnings(utils::read.csv(p, stringsAsFactors = FALSE, colClasses = c(formula = "character"))) else NULL
}
cstat <- rdcsv("class_status.csv")
cfmt <- function(x, d = 3) ifelse(is.na(x), "", trimws(formatC(x, digits = d, format = "fg")))
cshort <- function(x) sub("^Inference", "", x)
cdesign <- function(x, p) paste0(sub("^Design(Fixed|SeqOneByOne)", "\\1:", x), ifelse(!is.na(p) & p != 0.5, paste0("@", p), ""))
if (is.null(cstat)) {
	add_page("classes.md", "Classes", c("No class data yet: the first waves have not finished.", ""))
	class_counts <- NULL
} else {
	cstat <- cstat[order(cal_rt_rank(cstat$response_type), cstat$inf_class), ]
	class_counts <- table(factor(cstat$status, levels = c("complete", "in progress", "not started")))
	cs_all <- rdcsv("calibration_summary.csv"); nb_all <- rdcsv("null_bias_summary.csv"); pw_all <- rdcsv("power_summary.csv")
	cv_all <- rdcsv("convergence_summary.csv")
	idx_rows <- sprintf("| %s | [%s](class-%s.md) | %s | %s | %s | %s |", cstat$response_type, cshort(cstat$inf_class), cshort(cstat$inf_class),
		cstat$null_status, cstat$nonnull_status, cstat$verdict,
		ifelse(cstat$flagged > 0, sprintf("%d flagged: %d failing, %d pending, %d cleared", cstat$flagged, cstat$confirmed_fail + cstat$could_not_confirm,
			cstat$pending, cstat$cleared), ""))
	add_page("classes.md", "Classes", c(
		sprintf("%d classes: %d complete, %d in progress, %d not started. The campaign runs class by class (null effect first, then the power effects), so a class's verdict is final once it is complete and its flagged tests have their confirmation replicates.",
			nrow(cstat), class_counts[["complete"]], class_counts[["in progress"]], class_counts[["not started"]]), "",
		"Verdict: **fail** (a confirmed failure), **pending confirmation** (flagged tests waiting for fresh replicates), **pass** (complete, nothing flagged), **pass so far** (still running, nothing flagged so far; a class that has not run a test is not yet cleared).", "",
		"| response | class | null effect | power effects | verdict | flags |", "|---|---|---|---|---|---|", idx_rows, ""))
	for (i in seq_len(nrow(cstat))) {
		rt <- cstat$response_type[[i]]; cl <- cstat$inf_class[[i]]; sh <- cshort(cl)
		fig <- if (file.exists(file.path(cdir, "figures", sprintf("class-%s.png", sh))))
			c(sprintf("<picture><source media=\"(prefers-color-scheme: dark)\" srcset=\"figures/class-%s-dark.png\"><img alt=\"%s convergence of the error with n\" src=\"figures/class-%s.png\"></picture>", sh, sh, sh), "")
		else c("No convergence figure yet.", "")
		body <- c(sprintf("Part of the [Classes index](classes.md). Response type: %s. Status: null effect %s, power effects %s. Verdict: **%s**%s.", rt,
			cstat$null_status[[i]], cstat$nonnull_status[[i]], cstat$verdict[[i]],
			if (cstat$flagged[[i]] > 0) sprintf(" (%d flagged test(s): %d failing, %d pending, %d cleared)", cstat$flagged[[i]], cstat$confirmed_fail[[i]] + cstat$could_not_confirm[[i]],
				cstat$pending[[i]], cstat$cleared[[i]]) else ""), "", fig)
		cvx <- if (is.null(cv_all)) NULL else cv_all[cv_all$response_type == rt & cv_all$inf_class == cl, ]
		if (!is.null(cvx) && nrow(cvx)) {
			cvx$proc <- ifelse(cvx$inf_procedure == "(estimator)", "estimator (bias)", cvx$inf_procedure)
			rk <- c(slower = 4L, faster = 3L, consistent = 2L, undetermined = 1L, not_applicable = 0L)
			w <- aggregate(verdict ~ proc + metric, cvx, function(v) names(which.max(rk[v])))
			body <- c(body, "Convergence verdicts (worst over designs, formulas and effects; provisional until the class is complete):", "",
				"| procedure | metric | verdict |", "|---|---|---|", sprintf("| %s | %s | %s |", w$proc, w$metric, sub("_", " ", w$verdict)), "")
		}
		x <- if (is.null(cs_all)) NULL else cs_all[cs_all$response_type == rt & cs_all$inf_class == cl, ]
		if (!is.null(x) && nrow(x)) {
			x <- x[order(cdesign(x$design, x$prob_T), x$formula, x$inf_procedure, x$n), ]
			bx <- if (is.null(nb_all)) NULL else nb_all[nb_all$response_type == rt & nb_all$inf_class == cl, ]
			bk <- if (is.null(bx)) character() else paste(bx$design, bx$prob_T, bx$formula, bx$n)
			bias <- if (length(bk)) bx$null_bias_std[match(paste(x$design, x$prob_T, x$formula, x$n), bk)] else rep(NA_real_, nrow(x))
			failed <- x$fail_size | x$fail_coverage
			body <- c(body, sprintf("Null effect: %d cells (%d failing). Size, coverage and bias / SD against the level each is held to.", nrow(x), sum(failed)), "",
				"| design | n | formula | procedure | size | coverage | bias / SD | size level | coverage level | verdict |", "|---|---|---|---|---|---|---|---|---|---|",
				sprintf("| %s | %d | `%s` | %s | %s | %s | %s | %s | %s | %s |", cdesign(x$design, x$prob_T), as.integer(x$n_nominal), x$formula, x$inf_procedure,
					cfmt(x$size), cfmt(x$coverage), cfmt(bias, 2), cfmt(x$size_null), cfmt(x$coverage_null), ifelse(failed, "**FAIL**", "ok")), "")
		}
		px <- if (is.null(pw_all)) NULL else pw_all[pw_all$response_type == rt & pw_all$inf_class == cl, ]
		if (!is.null(px) && nrow(px)) {
			px <- px[order(cdesign(px$design, px$prob_T), px$formula, px$inf_procedure, px$effect_label, px$n), ]
			body <- c(body, sprintf("Power effects: %d cells (%d failing coverage).", nrow(px), sum(px$fail_coverage %in% TRUE)), "",
				"| design | n | effect | formula | procedure | power | coverage of the true estimand | coverage level | verdict |", "|---|---|---|---|---|---|---|---|---|",
				sprintf("| %s | %d | %s | `%s` | %s | %s | %s | %s | %s |", cdesign(px$design, px$prob_T), as.integer(px$n_nominal), px$effect_label, px$formula,
					px$inf_procedure, cfmt(px$power), cfmt(px$coverage), cfmt(px$coverage_null), ifelse(px$fail_coverage %in% TRUE, "**FAIL**", "ok")), "")
		}
		if (length(body) <= 4L) body <- c(body, "No results for this class yet.", "")
		add_page(sprintf("class-%s.md", sh), sprintf("Class %s", sh), body)
	}
}

# Data and about.
data_body <- c(
	"* Tables: [`summary/calibration_summary.csv`](summary/calibration_summary.csv) (size, coverage, with n_eff, expected order, level and rule per cell),",
	"  [`summary/confirmation_summary.csv`](summary/confirmation_summary.csv) (every cell the screen flagged, with its confirmation verdict),",
	"  [`summary/null_bias_summary.csv`](summary/null_bias_summary.csv) (with the `bias_sd_large_n` flag),",
	"  [`summary/power_summary.csv`](summary/power_summary.csv) (power, and coverage of the true estimand),",
	"  [`summary/nonnull_bias_summary.csv`](summary/nonnull_bias_summary.csv) (bias at beta_T != 0, with `bias_sd_large_n`),",
	if (file.exists(file.path(cdir, "summary", "design_comparison.csv")))
		"  [`summary/design_comparison.csv`](summary/design_comparison.csv) (paired power tests, each design vs Bernoulli),"
	else "  `design_comparison.csv` (paired power tests between designs; written when the campaign completes),",
	"  [`summary/convergence_summary.csv`](summary/convergence_summary.csv) and [`summary/convergence_points.csv`](summary/convergence_points.csv),",
	"  [`summary/pvalue_curves.csv`](summary/pvalue_curves.csv) (null p-value CDF minus u, the p-value curve figures).",
	if (length(runs))
		sprintf("* Raw per-replicate rows: the `study-rows` artifact of each workflow run (%s), one `rows.csv.xz` per wave (read it in R with `read.csv(xzfile(\"rows.csv.xz\"))`; kept 60 days, so the last two campaigns; a GitHub login is needed to download).", paste(sprintf("[%s](https://github.com/%s/actions/runs/%s)", runs, repo, runs), collapse = ", "))
	else "* Raw per-replicate rows: none yet. Each workflow run of the campaign will add a `study-rows` artifact (one `rows.csv.xz` per wave, kept 60 days), linked here.",
	"  One row per replicate x class x formula x procedure:",
	"  `inf_class` (EDI inference class), `inf_procedure` (`wald`, `score`, `lik_ratio`, `gradient`, `exact`, `rand`),",
	"  `formula` (`~1` or `~.`), `beta_T_hat` (treatment-effect estimate), `ci_beta_T_a` / `ci_beta_T_b` (95% CI",
	"  ends; NA for `rand`, p-value only), `pval` (two-sided, H0: beta_T = `null_value`), `null_value` (0 on the",
	"  class's scale), `fit_secs`, `status` (`ok`, `nonestimable`, `error`), `message` (error text), then the cell:",
	"  `response_type`, `design`, `prob_T`, `n` (as run), `n_nominal` (as planned; pair-switching runs 52 for 50),",
	"  `p` (covariates), `rep` (sets the seed: the same `rep` is the same subjects on every design), `effect_label`",
	"  (`null`, `power20`, `power50`, `power80`), `beta_T` (the true effect, 0 under the null) and `estimand_true`",
	"  (the true value of the class's own estimand, which coverage and bias are measured against: `null_value` under",
	"  the null; NA at beta_T != 0 where there is none). Result columns",
	"  are rounded to 7 significant digits; the published tables use the unrounded values.", "")
add_page("data.md", "Data", data_body)
add_page("about.md", "About this study", c(about, ""))

# Master page.
ana_sha <- env$ANALYSIS_SHA %||% ""
commit_link <- function(sha) sprintf("[`%s`](https://github.com/%s/commit/%s)", substr(sha, 1L, 8L), repo, sha)
toc <- c("| Page | Contents |", "|---|---|",
	sprintf("| [Failing cells: %s](%s) | %s |", rts, fail_files[rts], fail_label[rts]),
	"| [Screen flags and confirmation](flags.md) | every test the screen flagged, with its confirmation verdict |",
	"| [Null bias](null-bias.md) | bias at beta_T = 0, `bias_sd_large_n` flag (reported, not gated) |",
	"| [Coverage and bias away from the null](nonnull.md) | gated coverage of the true estimand, bias at beta_T != 0 |",
	"| [Design comparison and power](designs.md) | paired power tests between designs |",
	"| [Classes](classes.md) | every class: status, verdict and its own page (figure, cells) |",
	"| [Convergence slopes](convergence.md) | error versus n_eff against the registry's expected order |",
	sprintf("| [Figures: %s](%s) | null and non-null figures |", rts, fig_files[rts]),
	"| [Data](data.md) | tables, raw rows, column descriptions |",
	"| [About this study](about.md) | design of the study, levels, gate |")
red <- c("A red campaign is one whose `analyze` job's last step, `Gate verdict`, failed: confirmed failing cells (a calibration result).",
	"Any other failed step or job is a bug in the check itself (annotation \"Calibration CI bug\"), not a result.")
crd <- c(sprintf("# EDI calibration study: campaign %s", campaign), "",
	if (complete) "**Complete.**" else "**In progress: provisional.** Cells fill in as waves finish; the size / coverage gate is applied when the campaign completes.",
	"", if (nzchar(progress) && !any(pre_text == progress)) c(progress, "") else NULL,
	sprintf("Simulated at EDI commit %s (started %s)%s.", commit_link(env$SHA %||% ""), env$STARTED %||% "?",
		if (nzchar(ana_sha)) sprintf("; analysed at %s", commit_link(ana_sha)) else ""), "",
	"## Summary", "", pre_text[!startsWith(pre_text, "Levels (TODO-200)")],
	if (!is.null(class_counts)) sprintf("Classes: %d complete, %d in progress, %d not started ([Classes](classes.md)).", class_counts[["complete"]], class_counts[["in progress"]], class_counts[["not started"]]),
	"", red, "",
	"## Contents", "", toc, "",
	"## Data", "", "Tables as CSV, raw replicate rows as workflow artifacts: see [Data](data.md).", "",
	"## About this study", "",
	"Every month EDI re-runs a simulation study of its own inference procedures and publishes the results here, failures included. How the data are generated, the level each cell is held to and the two-stage gate are on the [About page](about.md).", "")
# Collapse runs of blank lines (optional paragraphs that are absent leave empty
# strings behind) so the rendered Markdown has no stray gaps.
squeeze_blank <- function(x) {
	x <- unlist(strsplit(paste(x, collapse = "\n"), "\n", fixed = TRUE))
	blank <- !nzchar(trimws(x))
	x[!(blank & c(FALSE, head(blank, -1L)))]
}
# Every page starts and ends with the link back to the master.
for (f in names(pages)) {
	pg <- pages[[f]]
	writeLines(squeeze_blank(c(back, "", sprintf("# %s", pg$title), "", pg$body, "", back)), file.path(cdir, f))
}
writeLines(squeeze_blank(crd), file.path(cdir, "README.md"))

# Top-level README: index of campaigns, newest first.
ids <- sort(list.dirs(file.path(results_dir, "campaigns"), full.names = FALSE, recursive = FALSE), decreasing = TRUE)
rows <- vapply(ids, function(id) {
	d <- file.path(results_dir, "campaigns", id)
	e <- read_env(file.path(d, "campaign.env"))
	g <- rd(file.path(d, "summary", "gate_failures.txt"))
	st <- if (identical(rd(file.path(d, "status.txt")), "complete")) "complete" else "in progress"
	sprintf("| [%s](campaigns/%s/README.md) | %s | [`%s`](https://github.com/%s/commit/%s) | %s |", id, id, st,
		substr(e$SHA %||% "", 1L, 8L), repo, e$SHA %||% "", if (length(g)) g[[1L]] else "")
}, character(1L))
top <- c("# EDI calibration study", "",
	sprintf("Latest campaign: **[%s](campaigns/%s/README.md)**%s.", ids[[1L]], ids[[1L]],
		if (identical(ids[[1L]], campaign) && !complete) " (in progress)" else ""), "",
	"| Campaign | Status | EDI commit | Failing cells |", "|---|---|---|---|", rows, "",
	"## About this study", "", about)
writeLines(top, file.path(results_dir, "README.md"))
