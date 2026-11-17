#!/usr/bin/env Rscript
# Covariate balance summary of a calibration-study campaign (owner, 2026-11-17): reads the campaign's balance
# statistics (calibration_study_balance.R) and writes, in --out-dir,
#   balance_summary.csv  one row per (response type, design, prob_T, n, effect): reps, mean and SD of every metric,
#                        median and 95th percentile of mahal_p and max_abs_smd;
#                        plus pooled rows (response_type "all") over response types at the null;
#   balance_summary.md   the pooled null rows as one table per n, designs ordered by mean M/p.
# Source: stats/balance.csv.gz (recorded by the shards, campaigns pinned at or after the commit that added it), else
# balance/backfill.csv.gz (balance_calibration_study.R, for earlier campaigns). Reported, not gated. No EDI needed.
#
# Usage: Rscript R/package_tests/calibration/summarize_balance_calibration_study.R --campaign-dir DIR --out-dir DIR

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
source(file.path(script_dir, "calibration_study_balance.R"))
args <- commandArgs(TRUE)
arg_value <- function(flag, default = NULL) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
cdir <- arg_value("--campaign-dir")
out_dir <- arg_value("--out-dir", file.path(cdir, "summary"))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

shard_path <- file.path(cdir, "stats", "balance.csv.gz")
backfill_path <- file.path(cdir, "balance", "backfill.csv.gz")
st <- cal_balance_read(shard_path)
source_note <- "recorded by the shards on every screening replicate"
if (is.null(st) || !nrow(st)) {
	st <- cal_balance_read(backfill_path)
	source_note <- "recomputed once for this campaign (`balance_calibration_study.R`: the designs re-run on the campaign's own seeds, continuous response, without inference)"
}
md_path <- file.path(out_dir, "balance_summary.md")
if (is.null(st) || !nrow(st)) {
	writeLines(c("No covariate balance statistics yet for this campaign.", ""), md_path)
	cat("balance summary: no statistics\n")
	quit(save = "no", status = 0L)
}
st$prob_T[is.na(st$prob_T)] <- 0.5
null <- st[st$effect_label == "null", ]
pooled <- if (nrow(null)) { p <- null; p$response_type <- "all"; cal_balance_merge(list(p)) } else NULL
summ <- cal_balance_summary(rbind(st, pooled))
summ$design_label <- ifelse(summ$prob_T != 0.5, sprintf("%s@prob_T=%s", summ$design, summ$prob_T), summ$design)
num <- vapply(summ, is.double, logical(1L))
summ[num] <- lapply(summ[num], signif, 5)
utils::write.csv(summ, file.path(out_dir, "balance_summary.csv"), row.names = FALSE)

f3 <- function(x) ifelse(is.finite(x), sprintf("%.3f", x), "")
f4 <- function(x) ifelse(is.finite(x), formatC(x, format = "g", digits = 3), "")
a <- summ[summ$response_type == "all", ]
rts <- sort(unique(null$response_type))
md <- c(sprintf("Covariate balance of every design's assignments at the null, %s; pooled over %s.", source_note,
		if (length(rts) > 1L) sprintf("the response types (%s)", paste(rts, collapse = ", ")) else sprintf("one response type (%s)", rts)),
	"Every design of a replicate sees the same subjects (the seed depends on response type, n and replicate only), so",
	"rows compare designs on identical covariates; pair-switching runs at n = 52 where the others run at 50.", "",
	"Columns are means over replicates unless marked: **M/p** is the Mahalanobis distance between the arms' covariate",
	"means over p = 5 (about chi2_5 / 5, mean 1, under complete randomization); **|SMD|** the standardized mean",
	"difference (mean over covariates, and the largest one per replicate); **|log VR|** the log variance ratio;",
	"**KS** the Kolmogorov-Smirnov distance between the arms' covariate distributions; **energy** the energy",
	"distance between the arms' joint covariate distributions. Lower is better balance for all of them; q50 / q95",
	"are the median and 95th percentile over replicates. Reported, not gated. Every unit, per response type:",
	"`balance_summary.csv`.", "")
for (nn in sort(unique(a$n_nominal))) {
	x <- a[a$n_nominal == nn, ]
	x <- x[order(x$mahal_p), ]
	md <- c(md, sprintf("### n = %d", nn), "",
		"| Design | reps | M/p | M/p q50 | M/p q95 | mean \\|SMD\\| | max \\|SMD\\| | max \\|SMD\\| q95 | mean \\|log VR\\| | mean KS | max KS | energy |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|",
		sprintf("| %s | %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |", sub("^Design", "", x$design_label), as.integer(x$reps),
			f4(x$mahal_p), f4(x$mahal_p_q50), f4(x$mahal_p_q95), f3(x$mean_abs_smd), f3(x$max_abs_smd), f3(x$max_abs_smd_q95),
			f3(x$mean_abs_log_vr), f3(x$mean_ks), f3(x$max_ks), f4(x$energy)), "")
}
writeLines(md, md_path)
cat(sprintf("balance summary: %d unit(s) -> %s\n", nrow(summ), out_dir))
