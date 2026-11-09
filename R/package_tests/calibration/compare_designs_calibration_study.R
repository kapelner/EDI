#!/usr/bin/env Rscript
# Paired comparison of power between designs for the published calibration study
# (release_v1_2_0.md TODO-36). Every design in a replicate sees the same subjects
# and potential outcomes (cal_study_seed() depends on response type, n and rep
# only), so for each power cell (response type, n_nominal, effect, class, formula,
# procedure) and each design, the replicates it shares with the baseline
# (DesignFixedBernoulli) are paired: an exact McNemar test on "rejects at 0.05"
# compares the two designs' power with the subject-to-subject noise cancelled.
# A design run at a different n than the baseline (pair-switching rounds 50 up to
# 52) has different subjects, so it gets an unpaired two-proportion z-test
# instead (paired = FALSE).
#
# Reported, not gated: a power difference between designs is a finding about the
# designs, not an error. q_bh is the Benjamini-Hochberg q-value over every row.
#
# Reads raw rows (the campaign's study-rows artifacts: rows.csv.xz per wave, or
# rows.csv.gz per shard), searched recursively under --rows-dir. Needs data.table.
#
# Usage: Rscript R/package_tests/calibration/compare_designs_calibration_study.R \
#          --rows-dir DIR --out FILE [--baseline DesignFixedBernoulli]

suppressPackageStartupMessages(library(data.table))
args <- commandArgs(TRUE)
arg_value <- function(flag, default = NULL) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
rows_dir <- arg_value("--rows-dir")
out_path <- arg_value("--out")
baseline <- arg_value("--baseline", "DesignFixedBernoulli")
if (is.null(rows_dir) || is.null(out_path)) stop("--rows-dir and --out are required")

keep <- c("response_type", "design", "prob_T", "n", "n_nominal", "effect_label", "inf_class", "formula",
	"inf_procedure", "rep", "pval")
files <- list.files(rows_dir, pattern = "rows\\.csv\\.(xz|gz)$", recursive = TRUE, full.names = TRUE)
cat(sprintf("compare designs: %d raw-row file(s) under %s\n", length(files), rows_dir))
read_one <- function(f) {
	cmd <- sprintf("%s -dc %s", if (grepl("\\.xz$", f)) "xz" else "gzip", shQuote(f))
	d <- fread(cmd = cmd, select = keep, colClasses = list(character = c("formula")), showProgress = FALSE)
	# Screening replicates only: confirmation replicates (above 10000, the gate's
	# second stage) exist for flagged classes only, so they have no partner.
	d[effect_label != "null" & is.finite(pval) & rep <= 10000L]
}
d <- rbindlist(lapply(files, read_one), use.names = TRUE, fill = TRUE)
if (!nrow(d)) {
	fwrite(data.table(), out_path)
	cat("compare designs: no power rows\n")
	quit(save = "no", status = 0L)
}
d[is.na(formula), formula := ""]
d[, design_label := ifelse(prob_T != 0.5, sprintf("%s@prob_T=%s", design, prob_T), design)]
d[, reject := pval < 0.05]
# A replicate re-run by a later wave would appear twice: keep one.
cell <- c("response_type", "n_nominal", "effect_label", "inf_class", "formula", "inf_procedure")
d <- unique(d, by = c(cell, "design_label", "rep"))

base <- d[design_label == baseline, c(cell, "rep", "n", "reject"), with = FALSE]
setnames(base, c("n", "reject"), c("n_base", "reject_base"))
other <- d[design_label != baseline, c(cell, "design_label", "rep", "n", "reject"), with = FALSE]

# Paired: same n, so the same subjects.
j <- merge(other, base, by = c(cell, "rep"))
j <- j[n == n_base]
paired <- j[, .(paired = TRUE, n_design = n[1L], n_pairs = .N, both = sum(reject & reject_base),
	design_only = sum(reject & !reject_base), base_only = sum(!reject & reject_base)), by = c(cell, "design_label")]
paired[, `:=`(power_design = (both + design_only) / n_pairs, power_base = (both + base_only) / n_pairs)]
paired[, diff := (design_only - base_only) / n_pairs]
paired[, diff_se := sqrt(pmax(design_only + base_only - (design_only - base_only)^2 / n_pairs, 0)) / n_pairs]
paired[, p_value := ifelse(design_only + base_only > 0,
	pmin(1, 2 * pbinom(pmin(design_only, base_only), design_only + base_only, 0.5)), 1)]

# Unpaired: a design run at another n (different subjects).
bs <- base[, .(n_base = n_base[1L], n_b = .N, rej_b = sum(reject_base)), by = cell]
os <- other[, .(n_design = n[1L], n_o = .N, rej_o = sum(reject)), by = c(cell, "design_label")]
u <- merge(os, bs, by = cell)
u <- u[n_design != n_base]
unpaired <- u[, .(paired = FALSE, n_design, n_pairs = pmin(n_o, n_b), both = NA_integer_, design_only = NA_integer_,
	base_only = NA_integer_, power_design = rej_o / n_o, power_base = rej_b / n_b), by = c(cell, "design_label")]
unpaired[, diff := power_design - power_base]
pooled <- (u$rej_o + u$rej_b) / (u$n_o + u$n_b)
unpaired[, diff_se := sqrt(pooled * (1 - pooled) * (1 / u$n_o + 1 / u$n_b))]
unpaired[, p_value := ifelse(diff_se > 0, 2 * pnorm(-abs(diff / diff_se)), 1)]

res <- rbindlist(list(paired, unpaired), use.names = TRUE)
setnames(res, "design_label", "design")
res[, baseline := baseline]
res[, q_bh := p.adjust(p_value, method = "BH")]
# Response types in the published display order (CAL_STUDY_RT_DISPLAY_ORDER).
res[, rt_rank := match(response_type, c("continuous", "incidence", "count", "proportion", "survival", "ordinal"))]
setorderv(res, c("rt_rank", "response_type", "inf_class", "inf_procedure", "formula", "n_nominal", "effect_label", "design"))
res[, rt_rank := NULL]
fwrite(res, out_path)
cat(sprintf("compare designs: %d comparison(s) (%d paired), %d with q < 0.05; wrote %s\n", nrow(res), sum(res$paired),
	sum(res$q_bh < 0.05), out_path))
