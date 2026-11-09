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
	"  exact one-sided binomial tests, Bonferroni-corrected at 0.01 over every test in the campaign. Null bias (mean",
	"  estimate minus the null value) is reported and flagged, not gated: an honest estimator has O(1/n) null bias on",
	"  ratio scales and under unequal allocation.",
	"* **Power:** three effect sizes per response type, set to give 20 / 50 / 80% power to the Bernoulli-design",
	"  baseline class at every n, 500 replicates per cell. Every design in a replicate sees the same subjects and",
	"  outcomes, so power differences between designs are differences between designs.",
	"* **Procedures:** Wald, score, likelihood ratio, gradient and exact tests and CIs, and the randomization test,",
	"  monthly. Bootstrap, jackknife, Bartlett-corrected and randomization CIs run in slower tiers (see",
	sprintf("  [the plan](https://github.com/%s/blob/main/R/package_metadata/future_release_plans/release_v1_2_0.md)).", repo),
	sprintf("* **Code:** [`R/package_tests/calibration/`](https://github.com/%s/tree/main/R/package_tests/calibration),", repo),
	"  run by `.github/workflows/calibration-study.yml`; each campaign is pinned to one EDI commit.")

# Campaign README.
run_links <- if (length(runs)) paste(sprintf("[%s](https://github.com/%s/actions/runs/%s)", runs, repo, runs), collapse = ", ") else "none yet"
crd <- c(sprintf("# EDI calibration study: campaign %s", campaign), "",
	if (complete) "**Complete.**" else "**In progress: provisional.** Cells fill in as waves finish; the size / coverage gate is applied when the campaign completes.",
	"", if (nzchar(progress)) c(progress, "") else NULL,
	sprintf("EDI commit: [`%s`](https://github.com/%s/commit/%s). Started %s.",
		substr(env$SHA %||% "", 1L, 8L), repo, env$SHA %||% "", env$STARTED %||% "?"), "",
	rd(file.path(cdir, "summary", "calibration_summary.md")), "",
	"## Figures", "", rd(file.path(cdir, "figures.md")),
	"## Data", "",
	"* Tables: [`summary/calibration_summary.csv`](summary/calibration_summary.csv) (size, coverage),",
	"  [`summary/null_bias_summary.csv`](summary/null_bias_summary.csv),",
	"  [`summary/power_summary.csv`](summary/power_summary.csv).",
	sprintf("* Raw per-replicate rows: the `study-rows-*` artifacts of the workflow runs %s (kept 90 days; a GitHub login is needed to download).", run_links),
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
