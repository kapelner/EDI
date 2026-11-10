# What the published calibration study plans to run, and how far it has got (v1.0.5 TODO-203,
# new_feature_plans/v1_0_5/calibration_class_major_campaign_order.md). Shared by the planner
# (plan_calibration_study.R) and the analysis (analyze_calibration_study.R,
# convergence_calibration_study.R). No EDI needed: the class list is the campaign's roster.csv, written once per
# campaign by build_calibration_study_roster.R (the workflow's `roster` job, from the EDI built at the pinned commit)
# and frozen for the campaign; nothing is committed.
#
# A UNIT is one inference class on one (response type, design, n, effect), with all its procedures
# (they share one fit on the same data, so they are never split). The campaign plan is every unit
# with its screening replicates, sorted class-major:
#   effect (null before the power effects), response type, inference class, design, n.
# A BLOCK is (effect, response type, class): the unit of "finished". Once a block's screening
# replicates are all done its flagged tests get confirmation replicates (replicate numbers above
# CAL_PLAN_CONFIRM_REP0), planned right after the block.
#
# Multiple testing: the screen is Benjamini-Hochberg over every test the whole plan contains
# (m_total, known in advance from the roster); a test enters with its p-value when its unit's
# screening replicates are all done and counts as p = 1 until then, so a flag is never withdrawn
# by later results (cal_bh_q()). The confirmation level is 0.01 / m_total, fixed in advance.

# Kept in sync with calibration_study_common.R (sourcing that needs EDI). There is no design list here: the designs
# (and their sort rank) are the campaign roster's, discovered from the installed EDI by the roster job.
CAL_PLAN_RESPONSE_TYPES <- c("continuous", "incidence", "proportion", "count", "ordinal", "survival")
CAL_PLAN_EFFECTS <- c("null", "power20", "power50", "power80")
CAL_PLAN_CONFIRM_REP0 <- 10000L   # = CAL_STUDY_CONFIRM_REP0
# Which designs are "matched" (the package's KK-matching-capable designs, whose applicable class set is the
# matched-pair one: more, slower classes) is not hand-kept: the roster job records it per design from the installed
# EDI (`des$is_a_kk_matching_capable()`, the predicate the package's own class discovery uses) in the roster's
# `matched` column, and plan.csv carries it on as `family`. cal_plan_set_matched() is called when either is read;
# cal_plan_family() refuses to guess before that.
cal_plan_state <- new.env(parent = emptyenv())
cal_plan_set_matched <- function(designs) assign("matched", unique(as.character(designs)), envir = cal_plan_state)
# Classes whose KK random-effects fits take 4-40 single-core minutes per replicate at n = 1000 on the
# matched designs: fewer replicates (user decision 2026-11-09, release_v1_2_0.md TODO-36).
CAL_PLAN_SLOW_CLASSES <- list(
	count = "InferenceCountKKGLMM",
	ordinal = c("InferenceOrdinalKKCLMM", "InferenceOrdinalKKCLMMCauchit", "InferenceOrdinalKKCLMMCloglog",
		"InferenceOrdinalKKCLMMProbit")
)

cal_plan_family <- function(design_label) {
	matched <- get0("matched", envir = cal_plan_state, inherits = FALSE)
	if (is.null(matched)) stop("matched designs unknown: read the campaign roster (cal_plan_read_roster) or plan.csv first")
	ifelse(design_label %in% matched, "matched", "iid")
}
cal_plan_is_slow <- function(design_label, inf_class) cal_plan_family(design_label) == "matched" & inf_class %in% unlist(CAL_PLAN_SLOW_CLASSES)
cal_plan_design_label <- function(design, prob_T) ifelse(!is.na(prob_T) & abs(prob_T - 0.5) > 1e-9, paste0(design, "@prob_T=", prob_T), design)
cal_plan_key <- function(response_type, design, n, effect, inf_class) paste(response_type, design, n, effect, inf_class, sep = "|")
cal_plan_block <- function(effect, response_type, inf_class) paste(effect, response_type, inf_class, sep = "|")

CAL_PLAN_ROSTER_COLS <- c("response_type", "design", "design_rank", "matched", "inf_class", "n_size", "n_cov", "secs_n50")

# The campaign's roster. Refuses to plan without one (no committed fallback: a stale class list would silently
# drop the classes added since).
cal_plan_read_roster <- function(path) {
	if (is.null(path) || !nzchar(path)) stop("--roster FILE is required: the campaign's roster.csv (build_calibration_study_roster.R)")
	if (!file.exists(path)) stop("class roster not found: ", path, " (build_calibration_study_roster.R writes it in the first wave)")
	r <- utils::read.csv(path, stringsAsFactors = FALSE)
	if (!all(CAL_PLAN_ROSTER_COLS %in% names(r)) || !nrow(r)) stop("class roster ", path, " is empty or lacks columns ", paste(setdiff(CAL_PLAN_ROSTER_COLS, names(r)), collapse = ", "))
	r$matched <- as.logical(r$matched)
	if (anyNA(r$matched)) stop("class roster ", path, ": column `matched` must be TRUE / FALSE")
	cal_plan_set_matched(r$design[r$matched])
	r
}

# The campaign plan: one row per unit, in run order. Columns: response_type, design (label), n,
# effect, inf_class, family, reps (screening replicates), rep_from (1), n_tests (the unit's upper bound
# on tests: size + coverage under the null, coverage away from it), secs_n50, key, block, rank.
cal_plan_units <- function(roster, rts = CAL_PLAN_RESPONSE_TYPES, designs = unique(roster$design), ns = c(50L, 200L, 1000L),
		effects = CAL_PLAN_EFFECTS, power_ns = c(50L, 200L), null_reps = 1000L, power_reps = 500L, slow_null_reps = 500L,
		slow_reduced_n = 1000L, slow_power_ns = 50L) {
	if (!"matched" %in% names(roster) || anyNA(as.logical(roster$matched))) stop("the roster needs a logical `matched` column")
	cal_plan_set_matched(roster$design[as.logical(roster$matched)])
	r <- roster[roster$response_type %in% rts & roster$design %in% designs, , drop = FALSE]
	if (!nrow(r)) return(NULL)
	g <- expand.grid(i = seq_len(nrow(r)), n = as.integer(ns), effect = effects, stringsAsFactors = FALSE)
	u <- data.frame(response_type = r$response_type[g$i], design = r$design[g$i], design_rank = r$design_rank[g$i], n = g$n, effect = g$effect, inf_class = r$inf_class[g$i],
		n_size = r$n_size[g$i], n_cov = r$n_cov[g$i], secs_n50 = r$secs_n50[g$i], stringsAsFactors = FALSE)
	slow <- cal_plan_is_slow(u$design, u$inf_class)
	keep <- u$effect == "null" | (!slow & u$n %in% power_ns) | (slow & u$n %in% slow_power_ns)
	u <- u[keep, , drop = FALSE]
	slow <- slow[keep]
	u$family <- cal_plan_family(u$design)
	u$reps <- ifelse(u$effect == "null", as.integer(null_reps), as.integer(power_reps))
	u$reps[slow & u$effect == "null" & u$n >= slow_reduced_n] <- as.integer(min(null_reps, slow_null_reps))
	u$rep_from <- 1L
	u$n_tests <- ifelse(u$effect == "null", u$n_size + u$n_cov, u$n_cov)
	u$key <- cal_plan_key(u$response_type, u$design, u$n, u$effect, u$inf_class)
	u$block <- cal_plan_block(u$effect, u$response_type, u$inf_class)
	o <- order(match(u$effect, CAL_PLAN_EFFECTS), cal_rt_rank(u$response_type), u$inf_class, u$design_rank,
		u$design, u$n)
	u <- u[o, , drop = FALSE]
	u$rank <- seq_len(nrow(u))
	rownames(u) <- NULL
	u[c("response_type", "design", "design_rank", "n", "effect", "inf_class", "family", "reps", "rep_from", "n_tests", "secs_n50", "key", "block", "rank")]
}

# Replicates of a flagged unit's confirmation: --confirm-reps, or the smaller slow-class number.
cal_plan_confirm_reps <- function(design_label, inf_class, confirm_reps = 5000L, slow_confirm_reps = 1000L) {
	ifelse(cal_plan_is_slow(design_label, inf_class), as.integer(slow_confirm_reps), as.integer(confirm_reps))
}

# Number of tests of the whole plan (the m of the screen and of the confirmation level).
cal_plan_m_total <- function(units) if (is.null(units)) 0L else as.integer(sum(units$n_tests))

# Largest planned n per null / non-null effect group (the "campaign's largest n" of the gate's unknown-rate rule and of the
# bias flag: fixed by the plan, not by how far the campaign has got).
cal_plan_largest_n <- function(units, null) {
	u <- units[(units$effect == "null") == null, ]
	if (nrow(u)) max(u$n) else -Inf
}

# Benjamini-Hochberg q-values of the p-values of the tests that have run, as if every one of the
# m_total tests of the plan were in the family and the others had p = 1. BH is monotone in the
# p-values, and a p = 1 test is never rejected, so a test flagged at any interim state is
# flagged at every later one. m_total = NULL (or below the number of tests that have run): the family is the
# tests that have run.
cal_bh_q <- function(p, m_total = NULL) {
	if (!length(p)) return(numeric())
	m <- max(if (is.null(m_total) || !is.finite(m_total)) length(p) else m_total, length(p))
	stats::p.adjust(p, method = "BH", n = m)
}

# Screening progress per unit: replicates done (the most any of the unit's rows has), and whether
# that reaches the plan. `tests`: the campaign's tests table (cal_stats_prepare()'d).
cal_unit_progress <- function(units, tests, stage = "screen") {
	units$reps_done <- 0
	if (is.null(tests) || !nrow(tests)) { units$done <- rep(FALSE, nrow(units)); return(units) }
	tests <- tests[tests$stage == stage, , drop = FALSE]
	if (nrow(tests)) {
		k <- cal_plan_key(tests$response_type, cal_plan_design_label(tests$design, tests$prob_T), tests$n_nominal, tests$effect_label, tests$inf_class)
		mx <- tapply(tests$reps, k, max)
		hit <- units$key %in% names(mx)
		units$reps_done[hit] <- as.numeric(mx[units$key[hit]])
	}
	units$done <- units$reps_done >= units$reps
	units
}

# Status of each class, separately for the null effect and for the power effects ("phase": the plan runs all null
# units before any power unit): "not started", "in progress" or "complete" (every screening unit of the class in that
# phase has all its replicates). One row per (response type, class) with null_status, nonnull_status and the overall
# status (complete when both are; not started when both are).
cal_class_progress <- function(units_progress) {
	phase <- ifelse(units_progress$effect == "null", "null", "nonnull")
	g <- paste(units_progress$response_type, units_progress$inf_class, sep = "|")
	first <- !duplicated(g)
	out <- units_progress[first, c("response_type", "inf_class")]
	f <- factor(g, levels = g[first])
	out$units <- as.integer(tapply(rep(1L, nrow(units_progress)), f, sum))
	out$units_done <- as.integer(tapply(units_progress$done, f, sum))
	st <- function(ph) {
		ix <- phase == ph
		if (!any(ix)) return(rep("none planned", nrow(out)))
		n <- tapply(rep(1L, sum(ix)), factor(g[ix], levels = levels(f)), sum)
		d <- tapply(units_progress$done[ix], factor(g[ix], levels = levels(f)), sum)
		s <- tapply(units_progress$reps_done[ix] > 0, factor(g[ix], levels = levels(f)), sum)
		ifelse(is.na(n), "none planned", ifelse(d >= n, "complete", ifelse(s > 0, "in progress", "not started")))
	}
	out$null_status <- unname(st("null"))
	out$nonnull_status <- unname(st("nonnull"))
	all_of <- function(v) function(a, b) (a == v | a == "none planned") & (b == v | b == "none planned")
	out$status <- ifelse(all_of("complete")(out$null_status, out$nonnull_status), "complete",
		ifelse(all_of("not started")(out$null_status, out$nonnull_status), "not started", "in progress"))
	out <- out[order(cal_rt_rank(out$response_type), out$inf_class), ]
	rownames(out) <- NULL
	out
}
