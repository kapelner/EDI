#!/usr/bin/env Rscript
# Class roster of ONE calibration campaign (v1.0.5 TODO-203 Amendment A,
# new_feature_plans/v1_0_5/calibration_class_major_campaign_order.md): which inference classes the study runs on
# which (response type, design), how many size / coverage tests each has, and its single-core seconds per
# replicate at n = 50. The workflow's `roster` job runs this once, in a campaign's first wave, with the EDI built at
# the campaign's pinned commit, and publishes the result as <campaign>/roster.csv; later waves reuse that file, so
# the class list is frozen for the campaign and is the one the shards simulate. Nothing is committed.
#
#   Rscript R/package_tests/calibration/build_calibration_study_roster.R --out FILE \
#       [--response-types all] [--designs all] [--n 50] [--prev-stats-dir DIR]
#
# Enumeration (no fitting): per (response type, design label incl. `@prob_T`) the classes are
# cal_study_classes(), the runner's own function, and each class's rows are cal_task_list(), the task
# enumeration cal_run_tasks() fits (formula x procedure, minus tasks without a method). Columns: response_type,
# design, matched (the package's is_a_kk_matching_capable(): the matched-pair class set), design_rank (sort order of the design, cal_study_design_rank(); the planner has no design list of its own),
# inf_class, n_size (rows with a p-value: formula x procedure), n_cov (rows with a CI: the same without
# the p-value-only `rand`), secs_n50. The designs are cal_study_designs(): discovered from the installed EDI, after a
# one-replicate smoke check that each can be built and assigned on the study's data (else the job fails naming it). A cell's tests are n_size size tests plus n_cov coverage tests under the null
# and n_cov coverage tests at a power effect (an upper bound: a class with no true estimand value has none there).
# The class set is read at --n (default the smallest study n, 50); tests/test-calibration-class-major-order.R checks
# it against the runner's at the other n.
#
# secs_n50 (used only to pack classes into shards; the planner corrects it with the shards' measured timings after
# the first wave): sum over the class's rows of fit_secs / reps at the smallest n of --prev-stats-dir's tests.csv.gz
# (the previous published campaign's statistics, null screening rows) where that (response type, design, class)
# existed there, else CAL_ROSTER_DEFAULT_SECS_N50 = 2 s, about the 90th percentile of the classes measured in
# campaign 2026-11-09-8c32d060 (median 0.43 s), i.e. conservative: an over-estimate only makes shards smaller.

CAL_ROSTER_DEFAULT_SECS_N50 <- 2

# Per (response type, design label, class) single-core seconds per replicate at the smallest n, from a previous
# campaign's tests table (cal_stats_prepare()'d). One row per key: response_type, design, inf_class, secs_n50.
cal_roster_costs <- function(tests) {
	tests <- cal_stats_prepare(tests)
	tests <- tests[tests$effect_label == "null" & tests$stage == "screen", ]
	if (!nrow(tests)) return(NULL)
	tests <- tests[tests$n_nominal == min(tests$n_nominal), ]
	tests$design_label <- ifelse(tests$prob_T != 0.5, paste0(tests$design, "@prob_T=", tests$prob_T), tests$design)
	tests$spr <- ifelse(tests$reps > 0, tests$fit_secs / tests$reps, 0)
	key <- paste(tests$response_type, tests$design_label, tests$inf_class, sep = "\r")
	first <- !duplicated(key)
	out <- tests[first, c("response_type", "design_label", "inf_class")]
	names(out)[2L] <- "design"
	out$secs_n50 <- round(as.numeric(tapply(tests$spr, factor(key, levels = key[first]), sum)), 4)
	out
}

# The roster rows of one (response type, design label): needs the installed EDI and calibration_study_common.R.
cal_roster_enumerate <- function(response_type, design_label, n_nominal = 50L, methods = CAL_STUDY_TIER1_METHODS,
		pval_only = CAL_STUDY_TIER1_PVAL_ONLY) {
	des <- cal_study_throwaway_design(response_type, design_label, n_nominal)
	classes <- sort(EDI:::applicable_inference_class_names_for_design(des))
	if (!length(classes)) return(NULL)
	tasks <- cal_task_list(des, classes, methods)
	cls <- vapply(tasks, function(t) t$cls_name, character(1L))
	has_ci <- vapply(tasks, function(t) !(t$method %in% pval_only), logical(1L))
	# Every class of the design gets a row, even one whose tasks all dropped out (n_size 0): the planner then has no test for it.
	# matched: the package's own predicate for the matched-pair class set (what its class discovery uses), so the
	# planner keeps no list of matched designs.
	data.frame(response_type = response_type, design = design_label, matched = isTRUE(des$is_a_kk_matching_capable()), inf_class = classes,
		n_size = as.integer(vapply(classes, function(k) sum(cls == k), numeric(1L))),
		n_cov = as.integer(vapply(classes, function(k) sum(cls == k & has_ci), numeric(1L))), stringsAsFactors = FALSE)
}

cal_roster_build <- function(response_types, designs, n_nominal = 50L, costs = NULL, default_secs = CAL_ROSTER_DEFAULT_SECS_N50) {
	parts <- list()
	for (rt in response_types) for (d in designs) {
		r <- cal_roster_enumerate(rt, d, n_nominal)
		if (!is.null(r)) parts[[length(parts) + 1L]] <- r
	}
	if (!length(parts)) stop("no class applies to any requested (response type, design)")
	out <- do.call(rbind, parts)
	out$secs_n50 <- default_secs
	out$design_rank <- cal_study_design_rank(out$design)
	if (!is.null(costs) && nrow(costs)) {
		hit <- match(paste(out$response_type, out$design, out$inf_class, sep = "\r"), paste(costs$response_type, costs$design, costs$inf_class, sep = "\r"))
		out$secs_n50[!is.na(hit)] <- costs$secs_n50[hit[!is.na(hit)]]
	}
	out <- out[out$n_size > 0L, , drop = FALSE]
	out <- out[order(cal_rt_rank(out$response_type), out$inf_class, out$design_rank, out$design), ]
	rownames(out) <- NULL
	out
}

if (sys.nframe() == 0L) {
	script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
	suppressPackageStartupMessages(library(EDI))
	source(file.path(script_dir, "calibration_study_stats.R"))
	source(file.path(script_dir, "calibration_study_common.R"))
	args <- commandArgs(TRUE)
	arg_value <- function(flag, default = NULL) {
		i <- match(flag, args)
		if (is.na(i) || i == length(args)) default else args[[i + 1L]]
	}
	split_csv <- function(x) trimws(strsplit(x, ",", fixed = TRUE)[[1L]])
	out <- arg_value("--out")
	if (is.null(out)) stop("--out is required")
	rts <- arg_value("--response-types", "all")
	rts <- if (identical(rts, "all")) CAL_RESPONSE_TYPES else split_csv(rts)
	designs <- arg_value("--designs", "all")
	discovered <- cal_study_designs()
	designs <- if (identical(designs, "all")) discovered else split_csv(designs)
	stopifnot(all(rts %in% CAL_RESPONSE_TYPES), all(designs %in% discovered))
	cat(sprintf("%d designs discovered from the installed EDI (%d with a prob_T = %g variant); excluded: %s\n", length(discovered),
		sum(grepl("@prob_T=", discovered, fixed = TRUE)), CAL_STUDY_UNEQUAL_PROB_T, paste(names(CAL_STUDY_EXCLUDED_DESIGNS), collapse = ", ")))
	cal_study_smoke_check_designs(designs)
	prev <- arg_value("--prev-stats-dir")
	costs <- NULL
	if (!is.null(prev) && nzchar(prev) && file.exists(file.path(prev, "tests.csv.gz"))) {
		costs <- cal_roster_costs(cal_stats_read(file.path(prev, "tests.csv.gz")))
		cat(sprintf("costs from %s: %d (response type, design, class) rows\n", prev, if (is.null(costs)) 0L else nrow(costs)))
	} else cat(sprintf("no previous campaign statistics: every class gets the default %g s per replicate at n = 50\n", CAL_ROSTER_DEFAULT_SECS_N50))
	roster <- cal_roster_build(rts, designs, as.integer(arg_value("--n", "50")), costs)
	dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
	utils::write.csv(roster, out, row.names = FALSE)
	cat(sprintf("%d (response type, design, class) rows, %d classes, %d with a previous cost -> %s\n", nrow(roster),
		length(unique(roster$inf_class)), sum(roster$secs_n50 != CAL_ROSTER_DEFAULT_SECS_N50), out))
}
