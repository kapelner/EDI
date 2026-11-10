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
# --cores cores, using the class's seconds per replicate (roster, scaled to n by calibration_study_costs.csv, corrected by
# the shards that have run). Shards run time-boxed (run_calibration_study.R), so a low estimate costs nothing but an extra
# wave.
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
#          [--target-minutes 25] [--pack-minutes 25] [--wave-size 64] [--max-dead 3] [--meta-out FILE] [--power-ns 50,200] \
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
ckey <- function(unit_key, confirm) ifelse(confirm, paste0(unit_key, "|confirm"), unit_key)

# Ledger: one row per finished shard (shard.csv, plus id). A shard's `only` is its class list (";"-joined);
# its replicates count for every class in it. Replicates above CONFIRM_REP0 are confirmation replicates.
ledger_path <- file.path(campaign_dir, "ledger.csv")
ledger <- if (nzchar(campaign_dir) && file.exists(ledger_path))
	utils::read.csv(ledger_path, stringsAsFactors = FALSE,
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
	utils::read.csv(planned_path, stringsAsFactors = FALSE, colClasses = c(group = "character")) else NULL
dead_n <- list()
if (!is.null(planned)) {
	dead <- planned[!(planned$id %in% if (is.null(ledger)) character() else ledger$id), , drop = FALSE]
	cls <- split_classes(dead$group)
	for (i in seq_len(nrow(dead))) for (k in ckey(cal_plan_key(dead$response_type[[i]], dead$design[[i]], dead$n[[i]], dead$effect[[i]], cls[[i]]),
		isTRUE(startsWith(dead$group[[i]], "confirm:"))))
		dead_n[[k]] <- (dead_n[[k]] %||% 0L) + 1L
}
dead_of <- function(k) dead_n[[k]] %||% 0L

# Seconds per replicate (single core) of a unit: the class's n = 50 cost from the roster, scaled to its n
# by the measured cost table; the slow classes have their own rows there.
costs <- utils::read.csv(file.path(script_dir, "calibration_study_costs.csv"), stringsAsFactors = FALSE)
cost_rest <- function(rt, fam, n) {
	cf <- costs[costs$response_type == rt & costs$family == fam & costs$group == "rest", ]
	v <- cf$secs_per_rep[cf$n == n]
	if (length(v)) return(v[[1L]])
	k <- which.min(abs(cf$n - n))
	cf$secs_per_rep[[k]] * n / cf$n[[k]]
}
unit_cost <- function(u) {
	if (cal_plan_is_slow(u$design, u$inf_class)) {
		cf <- costs[costs$response_type == u$response_type & costs$family == "matched" & costs$group == u$inf_class, ]
		if (nrow(cf)) {
			v <- cf$secs_per_rep[cf$n == u$n]
			return(if (length(v)) v[[1L]] else cf$secs_per_rep[[which.min(abs(cf$n - u$n))]] * u$n / cf$n[[which.min(abs(cf$n - u$n))]])
		}
	}
	max(0.05, u$secs_n50) * cost_rest(u$response_type, u$family, u$n) / cost_rest(u$response_type, u$family, 50L)
}
units$cost <- vapply(seq_len(nrow(units)), function(i) unit_cost(units[i, ]), numeric(1L))
# Correction from the shards that have run: median of measured / estimated seconds per replicate by (response type, n),
# so the estimates follow the real machine. Time-boxed shards make a low estimate cost only an extra wave.
cost_factor <- function() {
	if (is.null(ledger)) return(function(rt, n) 1)
	l <- ledger[is.finite(ledger$secs_per_rep) & ledger$n_done > 0 & !is.na(ledger$only) & nzchar(ledger$only), , drop = FALSE]
	ratios <- list()
	for (i in seq_len(nrow(l))) {
		ks <- cal_plan_key(l$response_type[[i]], l$design[[i]], l$n[[i]], l$effect[[i]], split_classes(l$only[[i]])[[1L]])
		est <- sum(units$cost[match(ks, units$key)], na.rm = TRUE)
		if (est > 0) ratios[[paste(l$response_type[[i]], l$n[[i]])]] <- c(ratios[[paste(l$response_type[[i]], l$n[[i]])]], l$secs_per_rep[[i]] / est)
	}
	function(rt, n) {
		v <- ratios[[paste(rt, n)]]
		if (is.null(v)) 1 else min(20, max(0.2, stats::median(v)))
	}
}
cfac <- cost_factor()

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

# Shards of a set of units that share (response type, design, n, effect) and a missing-replicate set:
# classes in priority order are packed next-fit into bins whose whole work (replicates x summed cost)
# fits --pack-minutes on --cores cores (one class per bin when --pack-minutes is 0; a unit that has
# already lost a shard to a death or timeout always runs alone, so one hanging class cannot take its
# neighbours down). Each bin's replicates are cut into chunks of about --target-minutes. A class that
# does not fit one chunk is cut by replicates exactly as before. The classes of a bin share every
# replicate's data and design, so a shard's cost is the sum of its classes' costs.
shards <- list()
make_shards <- function(u, missing, confirm) {
	rt <- u$response_type[[1L]]; nn <- u$n[[1L]]
	cur <- NULL; cur_cost <- 0
	flush <- function() {
		if (is.null(cur)) return(invisible())
		cost <- cur_cost
		per <- max(cores, floor(target_secs * cores / cost))
		chunks <- split(missing, ceiling(seq_along(missing) / per))
		tag <- if (length(cur) == 1L) cls_short(u$inf_class[cur]) else sprintf("%s-p%d", cls_short(u$inf_class[cur[[1L]]]), length(cur))
		if (confirm) tag <- paste0("confirm-", tag)
		for (ch in chunks) {
			shards[[length(shards) + 1L]] <<- list(
				id = sprintf("%s-%s-n%d-%s-%s-r%d", rt, slug(u$design[[1L]]), nn, u$effect[[1L]], tag, ch[[1L]]),
				response_type = rt, design = u$design[[1L]], n = nn, effect = u$effect[[1L]], reps = ranges(ch),
				secs_per_rep = round(cost, 1), group = paste0(if (confirm) "confirm:" else "", paste(u$inf_class[cur], collapse = ";")),
				only = paste(u$inf_class[cur], collapse = ","), exclude = "", priority = u$priority[[cur[[1L]]]])
		}
		cur <<- NULL; cur_cost <<- 0
	}
	for (i in seq_len(nrow(u))) {
		c_i <- u$cost[[i]] * cfac(rt, nn)
		alone <- u$dead[[i]] > 0L
		fits <- !alone && !is.null(cur) && pack_secs > 0 && (cur_cost + c_i) * length(missing) <= pack_secs * cores
		if (!fits) flush()
		cur <- c(cur, i)
		cur_cost <- cur_cost + c_i
		if (alone) flush()
	}
	flush()
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
	for (cg in unique(cell)) for (ms in unique(us$missing_str[cell == cg & nzchar(us$missing_str)])) {
		ix <- which(cell == cg & us$missing_str == ms)
		ix <- ix[order(us$priority[ix])]
		make_shards(us[ix, , drop = FALSE], miss[[ix[[1L]]]], confirm)
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
	cc <- utils::read.csv(confirm_path, stringsAsFactors = FALSE, colClasses = c(formula = "character"))
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
			confirm_units$cost <- ifelse(is.na(ci), vapply(seq_len(nrow(confirm_units)), function(i) {
				x <- confirm_units[i, ]; x$secs_n50 <- 1; unit_cost(x)
			}, numeric(1L)), units$cost[ci])
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
