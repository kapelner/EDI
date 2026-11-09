#!/usr/bin/env Rscript
# Writes the READMEs of the public calibration-results branch (release_v1_2_0.md
# TODO-36): campaigns/<id>/README.md (that campaign's report: summary, figures,
# tables, raw-data links) and the branch's top-level README.md (what the study is,
# the latest campaign, every campaign so far). No EDI needed.
#
# Usage: Rscript R/package_tests/calibration/render_calibration_study_readme.R \
#          --results-dir DIR --campaign ID --repo OWNER/NAME [--progress TEXT]

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
	"* **Null:** no treatment effect, 1,000 replicates per cell. Size is tested against 5% and coverage against 95% with",
	"  exact one-sided binomial tests, in two stages. Screen: Benjamini-Hochberg q < 0.05 over every test in the",
	"  campaign flags a cell (catching size of about 0.07 at 1,000 replicates). Confirm: each flagged cell is re-run",
	"  on 5,000 fresh replicates (1,000 for the slow classes) and fails only if those alone reject, at 0.01 over the",
	"  flagged tests; one with fewer than 500 confirmation results counts as failing. Null bias (mean",
	"  estimate minus the null value) is reported and flagged, not gated: an honest estimator has O(1/n) null bias on",
	"  ratio scales and under unequal allocation.",
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

# Campaign README.
# The analysis's markdown starts with its own "## <title>" (it doubles as the job
# summary); here the page title is the heading, so the section is "## Summary", and
# its bare file names become links into summary/.
summary_md <- rd(file.path(cdir, "summary", "calibration_summary.md"))
if (length(summary_md) && grepl("^## ", summary_md[[1L]])) summary_md[[1L]] <- "## Summary"
summary_md <- gsub("`(calibration_summary|confirmation_summary|null_bias_summary|nonnull_bias_summary|power_summary|pvalue_curves|design_comparison)\\.csv`",
	"[`summary/\\1.csv`](summary/\\1.csv)", summary_md)
run_links <- if (length(runs)) paste(sprintf("[%s](https://github.com/%s/actions/runs/%s)", runs, repo, runs), collapse = ", ") else ""
crd <- c(sprintf("# EDI calibration study: campaign %s", campaign), "",
	if (complete) "**Complete.**" else "**In progress: provisional.** Cells fill in as waves finish; the size / coverage gate is applied when the campaign completes.",
	# The analysis's summary already carries the progress line when it has one.
	"", if (nzchar(progress) && !any(summary_md == progress)) c(progress, "") else NULL,
	sprintf("EDI commit: [`%s`](https://github.com/%s/commit/%s). Started %s.",
		substr(env$SHA %||% "", 1L, 8L), repo, env$SHA %||% "", env$STARTED %||% "?"), "",
	summary_md, "",
	"## Figures", "", rd(file.path(cdir, "figures.md")),
	"## Data", "",
	"* Tables: [`summary/calibration_summary.csv`](summary/calibration_summary.csv) (size, coverage),",
	"  [`summary/confirmation_summary.csv`](summary/confirmation_summary.csv) (every cell the screen flagged, with its confirmation verdict),",
	"  [`summary/null_bias_summary.csv`](summary/null_bias_summary.csv),",
	"  [`summary/power_summary.csv`](summary/power_summary.csv) (power, and coverage of the true estimand),",
	"  [`summary/nonnull_bias_summary.csv`](summary/nonnull_bias_summary.csv) (bias at beta_T != 0),",
	if (file.exists(file.path(cdir, "summary", "design_comparison.csv")))
		"  [`summary/design_comparison.csv`](summary/design_comparison.csv) (paired power tests, each design vs Bernoulli),"
	else "  `design_comparison.csv` (paired power tests between designs; written when the campaign completes),",
	"  [`summary/pvalue_curves.csv`](summary/pvalue_curves.csv) (null p-value CDF minus u, the p-value curve figures).",
	if (length(runs))
		sprintf("* Raw per-replicate rows: the `study-rows` artifact of each workflow run (%s), one `rows.csv.xz` per wave (read it in R with `read.csv(xzfile(\"rows.csv.xz\"))`; kept 60 days, so the last two campaigns; a GitHub login is needed to download).", run_links)
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
	"  are rounded to 7 significant digits; the published tables use the unrounded values.",
	"", "## About this study", "", about)
writeLines(crd, file.path(cdir, "README.md"))

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
