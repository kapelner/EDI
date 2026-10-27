#!/usr/bin/env Rscript
# Splits one calibration fast-tier run into GitHub Actions matrix shards
# (design: R/package_metadata/new_feature_plans/calibration_gates.md). No EDI
# needed. Each (group, n) gets enough shards that every shard's estimated
# runtime -- calibration_fast_tier_timings.csv's single-core seconds per
# replicate x replicates / cores -- stays under --target-minutes. A group is a
# response type, except that a class too slow to share a shard
# (InferenceCountKKGLMM) is its own group.
#
# Usage: Rscript R/package_tests/calibration/plan_calibration_fast_tier.R \
#          --ns 50,200 --reps 1000 [--cores 4] [--target-minutes 270] [--groups count,ordinal]
# Prints the matrix JSON ({"include": [...]}) on stdout.

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
args <- commandArgs(TRUE)
arg_value <- function(flag, default) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
ns <- as.integer(strsplit(arg_value("--ns", "50,200"), ",", fixed = TRUE)[[1L]])
total_reps <- as.integer(arg_value("--reps", "1000"))
cores <- as.integer(arg_value("--cores", "4"))
target_secs <- 60 * as.numeric(arg_value("--target-minutes", "270"))
groups <- arg_value("--groups", "")

tim <- utils::read.csv(file.path(script_dir, "calibration_fast_tier_timings.csv"), stringsAsFactors = FALSE,
	colClasses = c(only = "character", exclude = "character"))
tim$only[is.na(tim$only)] <- ""
tim$exclude[is.na(tim$exclude)] <- ""
tim <- tim[tim$n %in% ns, ]
if (nzchar(groups)) tim <- tim[tim$group %in% strsplit(groups, ",", fixed = TRUE)[[1L]], ]
missing_n <- setdiff(ns, tim$n)
if (length(missing_n)) stop("no timing estimate for n = ", paste(missing_n, collapse = ", "), " in calibration_fast_tier_timings.csv")

esc <- function(x) gsub('"', '\\\\"', x)
include <- character()
for (i in seq_len(nrow(tim))) {
	t <- tim[i, ]
	per_shard <- max(1L, floor(target_secs * cores / t$secs_per_rep))
	n_shards <- ceiling(total_reps / per_shard)
	bounds <- unique(round(seq(0, total_reps, length.out = n_shards + 1L)))
	for (k in seq_len(length(bounds) - 1L)) {
		include <- c(include, sprintf(
			'{"id":"%s-n%d-%d","response_type":"%s","n":%d,"reps":"%d:%d","only":"%s","exclude":"%s"}',
			t$group, t$n, k, t$response_type, t$n, bounds[[k]] + 1L, bounds[[k + 1L]], esc(t$only), esc(t$exclude)))
	}
}
if (length(include) > 256L) stop(length(include), " shards exceed GitHub's 256-job matrix limit; raise --target-minutes or lower --reps")
cat(sprintf('{"include":[%s]}\n', paste(include, collapse = ",")))
