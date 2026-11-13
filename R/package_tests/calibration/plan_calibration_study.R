#!/usr/bin/env Rscript
# Plans the next wave of the published monthly calibration study
# (release_v1_2_0.md TODO-36). No EDI needed.
#
# Class-major plan (v1.0.5 TODO-203, new_feature_plans/v1_0_5/calibration_class_major_campaign_order.md).
# A campaign is every UNIT = (response type, design, n, effect, inference class) x its replicates
# (--null-reps for effect "null", --power-reps for the power effects; the class list is the campaign's roster.csv,
# --roster, written once per campaign by build_calibration_study_roster.R from the EDI built at the pinned commit). Units run in this order: null effect
# before the power effects; within an effect response type, then class; within a class design, then n
# (50, 200, 1000); then the class's confirmation replicates. A class's procedures share one fit and are never
# split. Shards: classes of one cell (response type, design, n, effect) that are next to each other in that
# order and cheap share a shard (--pack-minutes of whole work on --cores cores; 0 = one class per shard), because a
# job's setup costs minutes and a campaign would otherwise be ~13,600 jobs; they share each replicate's data and
# design, so the repeated-design cost is also small (measured in the plan's Done section). The campaign
# directory (on the calibration-results branch) holds the ledger:
#   ledger.csv    one row per finished shard (its shard.csv, plus id): response_type, design, n, effect, only (its
#                 classes, ";"-joined), reps_done, cost
#   planned.csv   every shard ever planned: id, response_type, design, n, effect, group (its classes), wave, run id
#   roster.csv    the campaign's class roster (--roster; frozen at the first wave)
#   plan.csv      --plan-out: every screening unit in run order (analysis reads it: m_total, completed cells)
# Missing replicates = all - union(reps_done) per unit (class). They are cut into shards of about --target-minutes on
# --cores cores, using the class's seconds per replicate: measured on this campaign's own finished shards where there are
# any (stats/tests.csv.gz), else the roster's, scaled to n by calibration_study_costs.csv (v1.0.5 TODO-203 Amendment E; the
# fallback chain is documented at "Costs" below). Shards that would come out well under --target-minutes (the leftovers of
# a shard that hit its deadline) are topped up with further classes of the same cell ("Fold" below). Shards run time-boxed
# (run_calibration_study.R), so a low estimate costs nothing but an extra wave.
#
# A unit is abandoned after --max-dead planned shards that left no shard.csv (the job died or hit its timeout), so a
# replicate that hangs cannot loop forever; a unit that has lost a shard runs alone from then on.
#
# Prints the wave's matrix JSON ({"include": [...]}) on stdout; --meta-out gets key=value lines for $GITHUB_OUTPUT: units,
# units_done, units_abandoned, reps_total, reps_done, wave (shards in this wave), shards_left (shards still needed after it,
# at current estimates), m_total (tests in the whole plan). --plan-only writes --plan-out / --meta-out and exits.
#
# Usage: Rscript R/package_tests/calibration/plan_calibration_study.R --campaign-dir DIR \
#          [--ns 50,200,1000] [--effects null,power20,power50,power80] [--designs all] \
#          [--response-types all] [--null-reps 1000] [--power-reps 500] [--cores 4] \
#          [--target-minutes 25] [--pack-minutes 25] [--min-shard-minutes 8.33] [--min-measured-reps 20] [--verbose] [--wave-size 64] [--max-dead 3] [--meta-out FILE] [--power-ns 50,200] \
#          [--slow-null-reps 500] [--slow-reduced-n 1000] [--slow-power-ns 50] \
#          [--confirm-reps 5000] [--slow-confirm-reps 1000] --roster FILE [--plan-out FILE] [--plan-only]
#
# Two-stage gate: a block (effect, response type, class) whose screening replicates are all done has its flagged tests
# (<campaign-dir>/summary/confirm_cells.csv, from analyze_calibration_study.R) confirmed on fresh replicates (10001 on),
# planned right after the block; the campaign is complete when all of those are done too.
#
# --power-ns: the n values that get the power effects (default 50,200). The power effects are local alternatives
# beta_T = h / sqrt(n), so power at n = 1000 is asymptotically what n = 200 shows, and it would be a third of the
# campaign's compute (measured 2026-11-09); the null runs at every n in --ns.
#
# Slow classes (CAL_PLAN_SLOW_CLASSES, calibration_study_plan_common.R): on the matched designs the KK random-effects fits for
# count and ordinal take 4-15 single-core minutes per replicate at n = 1000; they get fewer replicates (user decision
# 2026-11-09, release_v1_2_0.md TODO-36): --slow-null-reps at n >= --slow-reduced-n (default 500 at n = 1000) and the
# power effects only at --slow-power-ns (default 50).

# read.csv() calls in this file go through read_csv_fast(): fread-backed, same
# result as read.csv (R/package_tests/read_csv_fast.R), loaded from the checkout.
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
source(file.path(script_dir, "calibration_study_stats.R"))        # cal_rt_rank()
source(file.path(script_dir, "calibration_study_plan_common.R"))  # the unit plan, BH helper
args <- commandArgs(TRUE)
arg_value <- function(flag, default) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
split_csv <- function(x) trimws(strsplit(x, ",", fixed = TRUE)[[1L]])
`%||%` <- function(a, b) if (is.null(a)) b else a

campaign_dir <- arg_value("--campaign-dir", "")
ns <- as.integer(split_csv(arg_value("--ns", "50,200,1000")))
effects <- split_csv(arg_value("--effects", paste(CAL_PLAN_EFFECTS, collapse = ",")))
designs <- arg_value("--designs", "all")
rts <- arg_value("--response-types", "all")
rts <- if (identical(rts, "all")) CAL_PLAN_RESPONSE_TYPES else split_csv(rts)
null_reps <- as.integer(arg_value("--null-reps", "1000"))
power_reps <- as.integer(arg_value("--power-reps", "500"))
cores <- as.integer(arg_value("--cores", "4"))
target_secs <- 60 * as.numeric(arg_value("--target-minutes", "25"))
pack_secs <- 60 * as.numeric(arg_value("--pack-minutes", arg_value("--target-minutes", "25")))
# Amendment E: a shard predicted under --min-shard-minutes (default a third of --target-minutes; 0 = never fold) takes in
# further classes of its cell; a class needs --min-measured-reps completed replicates for its measured cost to count.
fold_secs <- 60 * as.numeric(arg_value("--min-shard-minutes", as.character(as.numeric(arg_value("--target-minutes", "25")) / 3)))
min_measured_reps <- as.integer(arg_value("--min-measured-reps", "20"))
wave_size <- as.integer(arg_value("--wave-size", "64"))
max_dead <- as.integer(arg_value("--max-dead", "3"))
meta_out <- arg_value("--meta-out", "")
plan_out <- arg_value("--plan-out", "")
plan_only <- "--plan-only" %in% args
roster_path <- arg_value("--roster", "")
power_ns <- as.integer(split_csv(arg_value("--power-ns", "50,200")))
slow_null_reps <- as.integer(arg_value("--slow-null-reps", "500"))
slow_reduced_n <- as.integer(arg_value("--slow-reduced-n", "1000"))
slow_power_ns <- as.integer(split_csv(arg_value("--slow-power-ns", "50")))
confirm_reps <- as.integer(arg_value("--confirm-reps", "5000"))
if (confirm_reps >= 10000L) stop("--confirm-reps must be below 10000 (replicates 10001..19999)")
slow_confirm_reps <- as.integer(arg_value("--slow-confirm-reps", "1000"))
CONFIRM_REP0 <- CAL_PLAN_CONFIRM_REP0
stopifnot(all(rts %in% CAL_PLAN_RESPONSE_TYPES), all(effects %in% CAL_PLAN_EFFECTS))

# The class roster is the campaign's own (build_calibration_study_roster.R, the workflow's `roster` job): there is no
# committed default, so a plan without one is refused.
roster <- cal_plan_read_roster(roster_path)
# The designs are the roster's (discovered from the installed EDI by the roster job): "all" = every roster design.
designs <- if (identical(designs, "all")) unique(roster$design) else split_csv(designs)
if (!all(designs %in% roster$design)) stop("--designs not in the campaign roster: ", paste(setdiff(designs, roster$design), collapse = ", "))
units <- cal_plan_units(roster, rts = rts, designs = designs, ns = ns, effects = effects,
	power_ns = power_ns, null_reps = null_reps, power_reps = power_reps, slow_null_reps = slow_null_reps,
	slow_reduced_n = slow_reduced_n, slow_power_ns = slow_power_ns)
if (is.null(units)) stop("the class roster has no unit for the requested response types and designs")
m_total <- cal_plan_m_total(units)

# plan.csv: every screening unit of the campaign, in run order, with its replicates and the upper bound
# on its tests. The analysis reads it (the m of the multiple-testing family, which units are complete,
# class status). It does not depend on the ledger.
if (nzchar(plan_out)) {
	dir.create(dirname(plan_out), recursive = TRUE, showWarnings = FALSE)
	utils::write.csv(units[c("rank", "response_type", "design", "family", "n", "effect", "inf_class", "reps", "n_tests")], plan_out, row.names = FALSE)
}
if (plan_only) {
	if (nzchar(meta_out)) cat(sprintf("m_total=%d\nunits=%d\n", m_total, nrow(units)), file = meta_out, append = TRUE)
	cat(sprintf("m_total=%d units=%d\n", m_total, nrow(units)))
	quit(save = "no", status = 0L)
}

parse_reps <- function(x) {
	x <- x[!is.na(x) & nzchar(x)]
	if (!length(x)) return(integer())
	unlist(lapply(unlist(strsplit(x, ",", fixed = TRUE)), function(r) {
		b <- as.integer(strsplit(r, ":", fixed = TRUE)[[1L]])
		seq.int(b[[1L]], b[[length(b)]])
	}))
}
split_classes <- function(x) {
	x <- sub("^confirm:", "", x)
	x[is.na(x)] <- ""
	lapply(strsplit(x, "[;,]"), function(v) v[nzchar(v)])
}
# Vectorised over unit_key (a pack shard's classes) with one `confirm` per shard. Not ifelse(confirm, ...): that returns
# length(confirm) = 1 values, so only a pack's first class was credited with its replicates and every later class of the
# pack re-ran the same seeds in later waves, its statistics counted once per re-run (campaign 2026-11-11-9d2edc5c).
ckey <- function(unit_key, confirm) paste0(unit_key, if (isTRUE(confirm)) "|confirm" else "")

# Ledger: one row per finished shard (shard.csv, plus id). A shard's `only` is its class list (";"-joined);
# its replicates count for every class in it. Replicates above CONFIRM_REP0 are confirmation replicates.
ledger_path <- file.path(campaign_dir, "ledger.csv")
ledger <- if (nzchar(campaign_dir) && file.exists(ledger_path))
	read_csv_fast(ledger_path, stringsAsFactors = FALSE,
		colClasses = c(reps_done = "character", only = "character", exclude = "character")) else NULL
if (!is.null(ledger) && !nrow(ledger)) ledger <- NULL
done_by_unit <- list()
if (!is.null(ledger)) {
	first_rep <- suppressWarnings(as.integer(sub("[,:].*$", "", ledger$reps_done)))
	conf <- !is.na(first_rep) & first_rep > CONFIRM_REP0
	cls <- split_classes(ledger$only)
	for (i in seq_len(nrow(ledger))) {
		if (!length(cls[[i]])) next   # a shard without a class list belongs to no unit of this plan
		reps_i <- parse_reps(ledger$reps_done[[i]])
		for (k in ckey(cal_plan_key(ledger$response_type[[i]], ledger$design[[i]], ledger$n[[i]], ledger$effect[[i]], cls[[i]]), conf[[i]]))
			done_by_unit[[k]] <- union(done_by_unit[[k]] %||% integer(), reps_i)
	}
}
planned_path <- file.path(campaign_dir, "planned.csv")
planned <- if (nzchar(campaign_dir) && file.exists(planned_path))
	read_csv_fast(planned_path, stringsAsFactors = FALSE, colClasses = c(group = "character")) else NULL
dead_n <- list()
if (!is.null(planned)) {
	dead <- planned[!(planned$id %in% if (is.null(ledger)) character() else ledger$id), , drop = FALSE]
	cls <- split_classes(dead$group)
	for (i in seq_len(nrow(dead))) for (k in ckey(cal_plan_key(dead$response_type[[i]], dead$design[[i]], dead$n[[i]], dead$effect[[i]], cls[[i]]),
		isTRUE(startsWith(dead$group[[i]], "confirm:"))))
		dead_n[[k]] <- (dead_n[[k]] %||% 0L) + 1L
}
dead_of <- function(k) dead_n[[k]] %||% 0L

# ---- Costs (v1.0.5 TODO-203 Amendment E) ----------------------------------------------------------------------------------
# Seconds per replicate (single core) of a unit. Preference, most specific first (the source of every unit is reported on stderr):
#   measured_design   this campaign's own finished shards, same (response type, design, n, class)
#   measured_n        same (response type, n, class) on other designs (median; the same matched / iid family if there is one)
#   measured_class    same (response type, class) at the nearest other n (same design if measured there, else other designs),
#                     scaled to the unit's n by the measured cost table (calibration_study_costs.csv)
#   roster            the roster's secs_n50 (previous campaign, else the 2 s default), scaled to n by that table, times a
#                     correction: the median of (measured / roster estimate) over this campaign's measured units of the
#                     same (response type, n), else of the response type, else 1
# The measured cost of a class is read from stats/tests.csv.gz (calibration_study_stats.R): fit_secs / reps summed over the class's
# (formula, procedure) rows, pooled over effects and stages, the same definition as the roster's secs_n50 -- per-class timing
# exists, so no shard time is apportioned. `reps` there counts replicates actually completed, never planned ones, so a shard
# that hit its deadline contributes what it did; the figure is a lower bound for such a class (replicates still running at the
# deadline are not in it) and the next wave's shards refine it. A class needs --min-measured-reps replicates to count.
# Runner setup is not in these numbers (the shard's elapsed time starts after it). What a measured class cost does not include
# is the work a pack shares (data, design, assignment): the ledger's per-shard secs_per_rep minus the sum of the shard's
# measured class costs is that overhead, taken as the median per (response type, design, n), else per (design, n), else per
# (response type, n), else per n, else 0, and charged once per pack.
costs <- read_csv_fast(file.path(script_dir, "calibration_study_costs.csv"), stringsAsFactors = FALSE)
cost_rest <- function(rt, fam, n) {
	cf <- costs[costs$response_type == rt & costs$family == fam & costs$group == "rest", ]
	v <- cf$secs_per_rep[cf$n == n]
	if (length(v)) return(v[[1L]])
	k <- which.min(abs(cf$n - n))
	cf$secs_per_rep[[k]] * n / cf$n[[k]]
}
# The measured cost table's value at n for a unit (the slow classes have their own rows).
cost_curve <- function(u, n) {
	if (cal_plan_is_slow(u$design, u$inf_class)) {
		cf <- costs[costs$response_type == u$response_type & costs$family == "matched" & costs$group == u$inf_class, ]
		if (nrow(cf)) {
			v <- cf$secs_per_rep[cf$n == n]
			return(if (length(v)) v[[1L]] else cf$secs_per_rep[[which.min(abs(cf$n - n))]] * n / cf$n[[which.min(abs(cf$n - n))]])
		}
	}
	cost_rest(u$response_type, u$family, n)
}
# The roster's estimate (unchanged from before Amendment E).
unit_cost <- function(u) {
	if (cal_plan_is_slow(u$design, u$inf_class) && any(costs$response_type == u$response_type & costs$family == "matched" & costs$group == u$inf_class))
		return(cost_curve(u, u$n))
	max(0.05, u$secs_n50) * cost_curve(u, u$n) / cost_curve(u, 50L)
}

read_measured <- function(dir) {
	p <- file.path(dir, "stats", "tests.csv.gz")
	if (!nzchar(dir) || !file.exists(p) || file.size(p) < 30L) return(NULL)
	t <- tryCatch(cal_stats_prepare(cal_stats_read(p)), error = function(e) NULL)
	if (is.null(t) || !nrow(t) || !all(c("fit_secs", "reps", "inf_class", "inf_procedure") %in% names(t))) return(NULL)
	t$design_label <- cal_plan_design_label(t$design, t$prob_T)
	rk <- paste(t$response_type, t$design_label, t$n_nominal, t$inf_class, t$formula, t$inf_procedure, sep = "\r")
	f <- factor(rk, levels = unique(rk))
	fs <- as.numeric(tapply(t$fit_secs, f, sum, na.rm = TRUE)); rp <- as.numeric(tapply(t$reps, f, sum))
	first <- !duplicated(rk)
	r <- t[first, c("response_type", "design_label", "n_nominal", "inf_class")]
	r$spr <- ifelse(rp > 0, fs / rp, NA_real_); r$reps <- rp
	ck <- paste(r$response_type, r$design_label, r$n_nominal, r$inf_class, sep = "|")
	g <- factor(ck, levels = unique(ck))
	out <- r[!duplicated(ck), c("response_type", "design_label", "n_nominal", "inf_class")]
	names(out) <- c("response_type", "design", "n", "inf_class")
	out$cost <- as.numeric(tapply(r$spr, g, sum, na.rm = TRUE))
	out$reps <- as.numeric(tapply(r$reps, g, max))
	out <- out[out$reps >= min_measured_reps & is.finite(out$cost) & out$cost > 0, , drop = FALSE]
	if (!nrow(out)) return(NULL)
	out$n <- as.integer(out$n)
	out$family <- cal_plan_family(out$design)
	out$key <- cal_plan_key(out$response_type, out$design, out$n, "", out$inf_class)
	rownames(out) <- NULL
	out
}
meas <- read_measured(campaign_dir)
meas_cost <- if (is.null(meas)) numeric() else stats::setNames(meas$cost, meas$key)
mkey <- function(rt, d, n, cls) cal_plan_key(rt, d, n, "", cls)

# Resolve the cost of the rows of df (response_type, design, n, inf_class, family, secs_n50). Returns list(cost, source).
resolve_cost_raw <- function(df, roster_fac = function(rt, n) 1) {
	nr <- nrow(df)
	cost <- rep(NA_real_, nr); src <- rep("roster", nr)
	cache <- new.env(parent = emptyenv())
	for (i in seq_len(nr)) {
		u <- df[i, ]
		ck <- paste(u$response_type, u$design, u$n, u$inf_class, sep = "|")
		if (!is.null(hit <- cache[[ck]])) { cost[[i]] <- hit[[1L]]; src[[i]] <- hit[[2L]]; next }
		v <- NA_real_; s <- "roster"
		if (!is.null(meas)) {
			v1 <- meas_cost[mkey(u$response_type, u$design, u$n, u$inf_class)]
			same <- meas[meas$response_type == u$response_type & meas$inf_class == u$inf_class, , drop = FALSE]
			if (!is.na(v1)) { v <- v1[[1L]]; s <- "measured_design" }
			else if (nrow(sm <- same[same$n == u$n, , drop = FALSE])) {
				fam <- sm[sm$family == u$family, , drop = FALSE]
				v <- stats::median(if (nrow(fam)) fam$cost else sm$cost); s <- "measured_n"
			} else if (nrow(same)) {
				nn <- same$n[[which.min(abs(log(same$n / u$n)))]]
				sm <- same[same$n == nn, , drop = FALSE]
				sd <- sm[sm$design == u$design, , drop = FALSE]
				base <- if (nrow(sd)) sd$cost[[1L]] else stats::median(sm$cost)
				v <- base * cost_curve(u, u$n) / cost_curve(u, nn); s <- "measured_class"
			}
		}
		if (is.na(v)) v <- unit_cost(u) * roster_fac(u$response_type, u$n)
		assign(ck, list(v, s), envir = cache)
		cost[[i]] <- v; src[[i]] <- s
	}
	list(cost = cost, source = src)
}
# The roster correction from this campaign's measured units: median of measured / roster estimate by (response type, n), else by
# response type, else 1; clamped to [0.02, 20].
roster_fac_fn <- function(df) {
	if (is.null(meas)) return(function(rt, n) 1)
	r <- unique(df[c("response_type", "design", "n", "inf_class", "family", "secs_n50")])
	m <- meas_cost[mkey(r$response_type, r$design, r$n, r$inf_class)]
	r <- r[!is.na(m), , drop = FALSE]
	if (!nrow(r)) return(function(rt, n) 1)
	ratio <- m[!is.na(m)] / vapply(seq_len(nrow(r)), function(i) unit_cost(r[i, ]), numeric(1L))
	function(rt, n) {
		v <- ratio[r$response_type == rt & r$n == n]
		if (!length(v)) v <- ratio[r$response_type == rt]
		if (!length(v)) 1 else min(20, max(0.02, stats::median(v)))
	}
}
resolve_cost <- function(df) {
	if (!"family" %in% names(df)) df$family <- cal_plan_family(df$design)
	resolve_cost_raw(df, roster_fac_fn(df))
}
rc <- resolve_cost(units)
units$cost <- rc$cost
units$cost_source <- rc$source
if ("--verbose" %in% args) message("calibration planner: unit costs from ", paste(sprintf("%s %d", names(table(units$cost_source)), as.integer(table(units$cost_source))), collapse = ", "))

# Per-pack overhead (see above) from the ledger.
overhead_fn <- function() {
	none <- function(rt, d, n) 0
	if (is.null(ledger) || is.null(meas)) return(none)
	l <- ledger[is.finite(ledger$secs_per_rep) & ledger$n_done > 0 & !is.na(ledger$only) & nzchar(ledger$only), , drop = FALSE]
	rows <- list()
	for (i in seq_len(nrow(l))) {
		cl <- split_classes(l$only[[i]])[[1L]]
		m <- meas_cost[mkey(l$response_type[[i]], l$design[[i]], l$n[[i]], cl)]
		if (!length(m) || anyNA(m)) next
		rows[[length(rows) + 1L]] <- data.frame(rt = l$response_type[[i]], d = l$design[[i]], n = as.integer(l$n[[i]]),
			ov = max(0, l$secs_per_rep[[i]] - sum(m)), stringsAsFactors = FALSE)
	}
	if (!length(rows)) return(none)
	o <- do.call(rbind, rows)
	function(rt, d, n) {
		for (sel in list(o$rt == rt & o$d == d & o$n == n, o$d == d & o$n == n, o$rt == rt & o$n == n, o$n == n))
			if (any(sel)) return(stats::median(o$ov[sel]))
		0
	}
}

ranges <- function(x) {
	x <- sort(x)
	brk <- c(0L, which(diff(x) != 1L), length(x))
	paste(vapply(seq_len(length(brk) - 1L), function(k) {
		a <- x[[brk[[k]] + 1L]]; b <- x[[brk[[k + 1L]]]]
		if (a == b) as.character(a) else sprintf("%d:%d", a, b)
	}, character(1L)), collapse = ",")
}
slug <- function(d) gsub("[^A-Za-z0-9]+", "", sub("^Design", "", sub("@prob_T=", "p", d)))
cls_short <- function(x) sub("^Inference", "", x)

# Shards of one cell (response type, design, n, effect). A unit is one class with its own set of missing replicates; a
# shard carries ONE replicate set, so only classes whose missing sets contain that set can share it (a class never repeats a
# replicate it has done: the statistics add up).
#  1. Classes with the same missing set, in priority order, are packed next-fit into bins whose whole work (replicates x
#     (summed class costs + the cell's overhead)) fits --pack-minutes on --cores cores (one class per bin when --pack-minutes
#     is 0). A unit that has already lost a shard to a death or timeout always runs alone, and is never folded.
#  2. Fold (Amendment E): a bin whose predicted time is under --min-shard-minutes (typically the leftovers of a shard that hit
#     its deadline) takes in further classes of the cell whose missing set contains the bin's replicates -- fresh classes, or
#     classes with larger leftovers -- in priority order, while the pack budget allows, until it reaches the minimum. The guests'
#     other replicates are planned as usual. Without such a class the bin stays small.
#  3. A bin's replicates are cut into the fewest chunks of about --target-minutes, of equal size (no tiny tail chunk).
# The classes of a pack share every replicate's data and design, so a shard's cost is the sum of its classes' costs plus the
# overhead.
shards <- list()
overhead_of <- overhead_fn()
plan_cell <- function(u, m, confirm) {
	rt <- u$response_type[[1L]]; dd <- u$design[[1L]]; nn <- u$n[[1L]]; ef <- u$effect[[1L]]
	ov <- overhead_of(rt, dd, nn)
	bin_cost <- function(b) ov + sum(u$cost[b])
	emit <- function(b, reps) {
		cost <- bin_cost(b)
		per <- max(cores, floor(target_secs * cores / cost))
		k <- ceiling(length(reps) / per)
		size <- ceiling(length(reps) / k)
		tag <- if (length(b) == 1L) cls_short(u$inf_class[b]) else sprintf("%s-p%d", cls_short(u$inf_class[b[[1L]]]), length(b))
		if (confirm) tag <- paste0("confirm-", tag)
		for (ch in split(reps, ceiling(seq_along(reps) / size))) {
			shards[[length(shards) + 1L]] <<- list(
				id = sprintf("%s-%s-n%d-%s-%s-r%d", rt, slug(dd), nn, ef, tag, ch[[1L]]),
				response_type = rt, design = dd, n = nn, effect = ef, reps = ranges(ch),
				secs_per_rep = round(cost, 1), group = paste0(if (confirm) "confirm:" else "", paste(u$inf_class[b], collapse = ";")),
				only = paste(u$inf_class[b], collapse = ","), exclude = "", priority = u$priority[[b[[1L]]]])
		}
	}
	pack <- function(ix) {   # ix: units with one missing set, in priority order
		bins <- list(); cur <- NULL
		for (i in ix) {
			fits <- !is.null(cur) && pack_secs > 0 && (bin_cost(c(cur, i))) * length(m[[i]]) <= pack_secs * cores
			if (!fits && !is.null(cur)) { bins[[length(bins) + 1L]] <- cur; cur <- NULL }
			cur <- c(cur, i)
		}
		if (!is.null(cur)) bins[[length(bins) + 1L]] <- cur
		bins
	}
	active <- which(lengths(m) > 0L)
	for (i in active[u$dead[active] > 0L]) emit(i, m[[i]])   # a unit that lost a shard runs alone
	pool <- active[u$dead[active] == 0L]
	repeat {
		if (!length(pool) || pack_secs <= 0 || fold_secs <= 0) break
		sets <- vapply(pool, function(i) ranges(m[[i]]), character(1L))
		bins <- unlist(lapply(split(pool, factor(sets, levels = unique(sets))), pack), recursive = FALSE)
		bins <- bins[order(vapply(bins, function(b) u$priority[[b[[1L]]]], numeric(1L)))]
		folded <- FALSE
		for (b in bins) {
			reps <- m[[b[[1L]]]]
			if (length(reps) * bin_cost(b) / cores >= fold_secs) next
			cur <- b
			for (g in setdiff(pool, b)[order(u$priority[setdiff(pool, b)])]) {
				if (!all(reps %in% m[[g]])) next
				if (bin_cost(c(cur, g)) * length(reps) > pack_secs * cores) next
				cur <- c(cur, g)
				if (length(reps) * bin_cost(cur) / cores >= fold_secs) break
			}
			if (length(cur) == length(b)) next
			emit(cur, reps)
			for (i in cur) m[[i]] <- setdiff(m[[i]], reps)
			pool <- pool[lengths(m[pool]) > 0L]
			folded <- TRUE
			break
		}
		if (!folded) break
	}
	if (length(pool)) {
		sets <- vapply(pool, function(i) ranges(m[[i]]), character(1L))
		for (ix in split(pool, factor(sets, levels = unique(sets)))) for (b in pack(ix)) emit(b, m[[b[[1L]]]])
	}
	invisible()
}
plan_unit_set <- function(us, confirm) {
	# us: units with key (for the ledger), reps, rep_from, priority; returns counts.
	cnt <- list(done = 0L, units_done = 0L, abandoned = 0L)
	us$missing_str <- ""
	miss <- vector("list", nrow(us))
	us$dead <- 0L
	for (i in seq_len(nrow(us))) {
		u <- us[i, ]
		k <- ckey(u$key, confirm)
		want <- seq.int(u$rep_from, length.out = u$reps)
		done <- intersect(done_by_unit[[k]] %||% integer(), want)
		cnt$done <- cnt$done + length(done)
		m <- setdiff(want, done)
		us$dead[[i]] <- dead_of(k)
		if (!length(m)) { cnt$units_done <- cnt$units_done + 1L; next }
		if (us$dead[[i]] >= max_dead) { cnt$abandoned <- cnt$abandoned + 1L; miss[[i]] <- integer(); next }
		miss[[i]] <- m
		us$missing_str[[i]] <- ranges(m)
	}
	cell <- paste(us$response_type, us$design, us$n, us$effect)
	for (cg in unique(cell)) {
		ix <- which(cell == cg & nzchar(us$missing_str))
		if (!length(ix)) next
		ix <- ix[order(us$priority[ix])]
		plan_cell(us[ix, , drop = FALSE], miss[ix], confirm)
	}
	list(counts = cnt, miss = miss, unit_dead = us$dead, missing_str = us$missing_str)
}

units$priority <- units$rank
res <- plan_unit_set(units, FALSE)
reps_done_total <- res$counts$done
units_done <- res$counts$units_done
units_abandoned <- res$counts$abandoned

# Confirmation (stage 2 of the gate, analyze_calibration_study.R): a block (effect, response type, class) whose
# screening replicates are all done or abandoned has its flagged tests confirmed on fresh replicates
# CONFIRM_REP0 + 1 on, planned right after the block. summary/confirm_cells.csv (rewritten by each publish) lists the
# flagged tests; a flag is permanent once made (cal_bh_q), so a block's list is final when the block is.
# One unit per (response type, design, n, effect, class), with all its procedures.
confirm_units <- NULL
confirm_path <- file.path(campaign_dir, "summary", "confirm_cells.csv")
if (nzchar(campaign_dir) && file.exists(confirm_path) && file.size(confirm_path) > 1L) {
	cc <- read_csv_fast(confirm_path, stringsAsFactors = FALSE, colClasses = c(formula = "character"))
	if (nrow(cc)) {
		cc$design_label <- cal_plan_design_label(cc$design, cc$prob_T)
		cc$block <- cal_plan_block(cc$effect_label, cc$response_type, cc$inf_class)
		unfinished <- tapply(nzchar(res$missing_str), units$block, any)
		cc <- cc[cc$block %in% names(unfinished)[!unfinished], , drop = FALSE]
		if (nrow(cc)) {
			g <- unique(cc[c("response_type", "design_label", "n_nominal", "effect_label", "inf_class", "block")])
			last_rank <- tapply(units$rank, units$block, max)
			confirm_units <- data.frame(response_type = g$response_type, design = g$design_label, n = as.integer(g$n_nominal),
				effect = g$effect_label, inf_class = g$inf_class, family = cal_plan_family(g$design_label),
				reps = cal_plan_confirm_reps(g$design_label, g$inf_class, confirm_reps, slow_confirm_reps),
				rep_from = CONFIRM_REP0 + 1L, n_tests = 0L, secs_n50 = NA_real_, block = g$block, stringsAsFactors = FALSE)
			confirm_units$key <- cal_plan_key(confirm_units$response_type, confirm_units$design, confirm_units$n, confirm_units$effect, confirm_units$inf_class)
			# Cost of a class on a design is that of the same class's screening unit (the confirmation reuses it).
			ci <- match(confirm_units$key, units$key)
			confirm_units$secs_n50 <- 1
			confirm_units$cost <- ifelse(is.na(ci), resolve_cost(confirm_units)$cost, units$cost[ci])
			o <- order(match(confirm_units$effect, CAL_PLAN_EFFECTS), cal_rt_rank(confirm_units$response_type), confirm_units$inf_class,
				units$design_rank[match(confirm_units$design, units$design)], confirm_units$design, confirm_units$n)
			confirm_units <- confirm_units[o, ]
			confirm_units$priority <- as.numeric(last_rank[confirm_units$block]) + 0.5 + seq_len(nrow(confirm_units)) / (nrow(confirm_units) + 1) / 2
			cres <- plan_unit_set(confirm_units, TRUE)
			reps_done_total <- reps_done_total + cres$counts$done
			units_done <- units_done + cres$counts$units_done
			units_abandoned <- units_abandoned + cres$counts$abandoned
		}
	}
}
units_all_n <- nrow(units) + if (is.null(confirm_units)) 0L else nrow(confirm_units)
reps_all <- sum(units$reps) + if (is.null(confirm_units)) 0L else sum(confirm_units$reps)
shards <- shards[order(vapply(shards, function(s) s$priority, numeric(1L)))]
wave <- utils::head(shards, wave_size)
if (length(wave) > 256L) stop("a wave cannot exceed GitHub's 256-job matrix limit")
esc <- function(x) gsub('"', '\\\\"', x)
json <- vapply(wave, function(s) sprintf(paste0('{"id":"%s","response_type":"%s","design":"%s","n":%d,"effect":"%s","reps":"%s",',
	'"secs_per_rep":%s,"group":"%s","only":"%s","exclude":"%s"}'),
	s$id, s$response_type, esc(s$design), s$n, s$effect, s$reps, format(s$secs_per_rep), s$group, s$only, s$exclude), character(1L))
cat(sprintf('{"include":[%s]}\n', paste(json, collapse = ",")))
if (nzchar(meta_out)) cat(sprintf("units=%d\nunits_done=%d\nunits_abandoned=%d\nreps_total=%d\nreps_done=%d\nwave=%d\nshards_left=%d\nm_total=%d\n",
	units_all_n, units_done, units_abandoned, reps_all, reps_done_total, length(wave), length(shards) - length(wave), m_total),
	file = meta_out, append = TRUE)
