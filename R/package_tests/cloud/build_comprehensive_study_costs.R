#!/usr/bin/env Rscript
# Seconds per replicate of every (response type, dataset, design, inference class,
# beta_T) piece of comprehensive_tests.R, from a set of raw result CSVs
# (comprehensive_tests_results_nc_1_<response>.csv). The cloud comprehensive study
# (.github/workflows/comprehensive-study.yml, release_v1_1_0.md TODO-194) packs its
# shards with these costs, and its planner enumerates the pieces from this table.
# Each finished campaign rewrites the table from its own measured rows, so it
# tracks the hosted runners; the first one comes from a local regeneration.
#
# Usage: build_comprehensive_study_costs.R <results-dir> <out.csv>
# Class names lose their " [design_formula=...]" / " (model_formula=...)" suffix:
# the runner's class filter selects a class with every formula variant.

suppressPackageStartupMessages(library(data.table))
args = commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("usage: build_comprehensive_study_costs.R <results-dir> <out.csv>")
response_types = c("continuous", "incidence", "proportion", "count", "survival", "ordinal")
files = file.path(args[[1L]], sprintf("comprehensive_tests_results_nc_1_%s.csv", response_types))
files = files[file.exists(files)]
if (!length(files)) stop("no comprehensive_tests_results_nc_1_<response>.csv in ", args[[1L]])
costs = rbindlist(lapply(files, function(f) {
	d = fread(f, select = c("rep", "beta_T", "dataset", "response_type", "design", "inference_class", "duration_time_sec"), showProgress = FALSE)
	d[, design := sub("@prob_T=.*$", "", design)]
	d[, class := sub(" .*$", "", inference_class)]
	d = d[!is.na(class) & nzchar(class) & !is.na(design) & nzchar(design)]
	per_rep = d[, .(sec = sum(duration_time_sec, na.rm = TRUE)), by = .(response_type, dataset, design, class, beta_T, rep)]
	per_rep[, .(sec_per_rep = round(stats::median(sec), 1), reps_seen = .N), by = .(response_type, dataset, design, class, beta_T)]
}))
setorder(costs, response_type, dataset, design, class, beta_T)
fwrite(costs, args[[2L]])
cat(sprintf("%d pieces, %.0f CPU-hours per 50 reps, written to %s\n", nrow(costs), sum(costs$sec_per_rep) * 50 / 3600, args[[2L]]))
