#!/usr/bin/env Rscript
# Plans the next wave of the published monthly calibration study
# (release_v1_2_0.md TODO-36). No EDI needed.
#
# A campaign is every unit = (response type, design, n, effect) x its replicates
# (--null-reps for effect "null", --power-reps for the power effects). The
# campaign directory (on the calibration-results branch) holds the ledger:
#   ledger.csv    one row per finished shard (its shard.csv, plus id): unit,
#                 reps_done, cost
#   planned.csv   every shard ever planned: id, unit columns, wave, run id
# Missing replicates = all - union(reps_done) per unit. They are cut into shards of
# about --target-minutes on --cores cores, using the unit's measured seconds per
# replicate (median over its finished shards; else the same response type / design
# family / n at any effect; else calibration_study_costs.csv). Shards run
# time-boxed (run_calibration_study.R), so a low estimate costs nothing but an
# extra wave.
#
# A unit is abandoned after --max-dead planned shards that left no shard.csv (the
# job died or hit its timeout), so a replicate that hangs cannot loop forever.
#
# Prints the wave's matrix JSON ({"include": [...]}) on stdout; --meta-out gets
# key=value lines for $GITHUB_OUTPUT: units, units_done, units_abandoned, reps_total,
# reps_done, wave (shards in this wave), shards_left (shards still needed after it,
# at current estimates).
#
# Usage: Rscript R/package_tests/calibration/plan_calibration_study.R --campaign-dir DIR \
#          [--ns 50,200,1000] [--effects null,power20,power50,power80] [--designs all] \
#          [--response-types all] [--null-reps 1000] [--power-reps 500] [--cores 4] \
#          [--target-minutes 25] [--wave-size 64] [--max-dead 3] [--meta-out FILE] [--power-ns 50,200] \
#          [--slow-null-reps 500] [--slow-reduced-n 1000] [--slow-power-ns 50] \
#          [--confirm-reps 5000] [--slow-confirm-reps 1000]
#
# Two-stage gate: once every screening shard is done, the cells the screen flagged
# (<campaign-dir>/summary/confirm_cells.csv, from analyze_calibration_study.R) get
# confirmation units of fresh replicates (10001 on); the campaign is complete when
# those are done too.
#
# --power-ns: the n values that get the power effects (default 50,200). The power
# effects are local alternatives beta_T = h / sqrt(n), so power at n = 1000 is
# asymptotically what n = 200 shows, and it would be a third of the campaign's
# compute (measured 2026-11-09); the null runs at every n in --ns.
#
# Class groups: a unit is also split by class group. On the matched designs the KK
# random-effects fits for count and ordinal (SLOW_CLASSES) each take 4-15 single-core
# minutes per replicate at n = 1000; one KK21 ordinal replicate with every class is
# 57 minutes, past the shard timeout, so it could never finish. Each slow class runs
# in its own shards (--only), group "rest" runs every other class (--exclude), and
# they share replicate numbers, hence data sets. The slow classes also get fewer
# replicates (user decision 2026-11-09, release_v1_2_0.md TODO-36): --slow-null-reps
# at n >= --slow-reduced-n (default 500 at n = 1000; coverage SE still ~1 point) and
# the power effects only at --slow-power-ns (default 50).

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
args <- commandArgs(TRUE)
arg_value <- function(flag, default) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
split_csv <- function(x) trimws(strsplit(x, ",", fixed = TRUE)[[1L]])
`%||%` <- function(a, b) if (is.null(a)) b else a

# Kept in sync with calibration_study_common.R (sourcing it would need EDI).
RESPONSE_TYPES <- c("continuous", "incidence", "proportion", "count", "ordinal", "survival")
DESIGNS <- c(
	"DesignFixedBernoulli", "DesignFixedBernoulli@prob_T=0.2", "DesignFixediBCRD", "DesignFixedBlocking",
	"DesignFixedRerandomization", "DesignFixedMatchingGreedyPairSwitching", "DesignFixedOptimal",
	"DesignFixedBinaryMatch", "DesignFixedGreedy", "DesignFixedGreedyDOptimal", "DesignFixedOptimalBlocks",
	"DesignSeqOneByOneBernoulli", "DesignSeqOneByOneiBCRD", "DesignSeqOneByOneEfron", "DesignSeqOneByOneAtkinson",
	"DesignSeqOneByOnePocockSimon", "DesignSeqOneByOneRandomBlockSize", "DesignSeqOneByOneSPBR",
	"DesignSeqOneByOneUrn", "DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise"
)
EFFECTS <- c("null", "power20", "power50", "power80")
# Designs whose applicable class set is the matched-pair one (more, slower classes).
MATCHED_DESIGNS <- c("DesignFixedBinaryMatch", "DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise")
# Classes that run in their own shards on the matched designs (see the header);
# per-class costs are in calibration_study_costs.csv.
SLOW_CLASSES <- list(
	count = "InferenceCountKKGLMM",
	ordinal = c("InferenceOrdinalKKCLMM", "InferenceOrdinalKKCLMMCauchit", "InferenceOrdinalKKCLMMCloglog",
		"InferenceOrdinalKKCLMMProbit")
)

campaign_dir <- arg_value("--campaign-dir", "")
ns <- as.integer(split_csv(arg_value("--ns", "50,200,1000")))
effects <- split_csv(arg_value("--effects", paste(EFFECTS, collapse = ",")))
designs <- arg_value("--designs", "all")
designs <- if (identical(designs, "all")) DESIGNS else split_csv(designs)
rts <- arg_value("--response-types", "all")
rts <- if (identical(rts, "all")) RESPONSE_TYPES else split_csv(rts)
null_reps <- as.integer(arg_value("--null-reps", "1000"))
power_reps <- as.integer(arg_value("--power-reps", "500"))
cores <- as.integer(arg_value("--cores", "4"))
target_secs <- 60 * as.numeric(arg_value("--target-minutes", "25"))
wave_size <- as.integer(arg_value("--wave-size", "64"))
max_dead <- as.integer(arg_value("--max-dead", "3"))
meta_out <- arg_value("--meta-out", "")
power_ns <- as.integer(split_csv(arg_value("--power-ns", "50,200")))
slow_null_reps <- as.integer(arg_value("--slow-null-reps", "500"))
slow_reduced_n <- as.integer(arg_value("--slow-reduced-n", "1000"))
slow_power_ns <- as.integer(split_csv(arg_value("--slow-power-ns", "50")))
confirm_reps <- as.integer(arg_value("--confirm-reps", "5000"))
if (confirm_reps >= 10000L) stop("--confirm-reps must be below 10000 (replicates 10001..19999)")
slow_confirm_reps <- as.integer(arg_value("--slow-confirm-reps", "1000"))
# Kept in sync with calibration_study_common.R (CAL_STUDY_CONFIRM_REP0).
CONFIRM_REP0 <- 10000L
stopifnot(all(designs %in% DESIGNS), all(rts %in% RESPONSE_TYPES), all(effects %in% EFFECTS))

units <- expand.grid(response_type = rts, design = designs, n = ns, effect = effects, stringsAsFactors = FALSE)
units <- units[units$effect == "null" | units$n %in% power_ns, ]
units$family <- ifelse(units$design %in% MATCHED_DESIGNS, "matched", "iid")
units$reps <- ifelse(units$effect == "null", null_reps, power_reps)
units$group <- "rest"
slow_units <- do.call(rbind, lapply(names(SLOW_CLASSES), function(rt) {
	b <- units[units$response_type == rt & units$family == "matched", ]
	if (!nrow(b)) return(NULL)
	b <- b[b$effect == "null" | b$n %in% slow_power_ns, ]
	b$reps[b$effect == "null" & b$n >= slow_reduced_n] <- min(null_reps, slow_null_reps)
	do.call(rbind, lapply(SLOW_CLASSES[[rt]], function(cl) { b$group <- cl; b }))
}))
units <- rbind(units, slow_units)
# --exclude for group "rest": the slow classes of that response type on a matched design.
rest_exclude <- function(rt, family) if (family == "matched") paste(SLOW_CLASSES[[rt]], collapse = ",") else ""
units$rep_from <- 1L
units$only <- ifelse(units$group == "rest", "", units$group)
units$exclude <- ifelse(units$group == "rest", mapply(rest_exclude, units$response_type, units$family), "")
ukey <- function(d) paste(d$response_type, d$design, d$n, d$effect, d$group, sep = "|")
gkey <- function(d) paste(d$response_type, d$design, d$n, d$group, sep = "|")
units$key <- ukey(units)

parse_reps <- function(x) {
	x <- x[!is.na(x) & nzchar(x)]
	if (!length(x)) return(integer())
	unlist(lapply(unlist(strsplit(x, ",", fixed = TRUE)), function(r) {
		b <- as.integer(strsplit(r, ":", fixed = TRUE)[[1L]])
		seq.int(b[[1L]], b[[length(b)]])
	}))
}

# Ledger.
ledger_path <- file.path(campaign_dir, "ledger.csv")
ledger <- if (nzchar(campaign_dir) && file.exists(ledger_path))
	utils::read.csv(ledger_path, stringsAsFactors = FALSE,
		colClasses = c(reps_done = "character", only = "character", exclude = "character")) else NULL
if (!is.null(ledger) && !nrow(ledger)) ledger <- NULL
# A shard's group is its --only class (one slow class), else "rest".
# A confirmation shard (replicates above CONFIRM_REP0) is in group "confirm:<only>".
if (!is.null(ledger)) {
	ledger$group <- ifelse(is.na(ledger$only) | !nzchar(ledger$only), "rest", ledger$only)
	first_rep <- suppressWarnings(as.integer(sub("[,:].*$", "", ledger$reps_done)))
	conf <- !is.na(first_rep) & first_rep > CONFIRM_REP0
	ledger$group[conf] <- paste0("confirm:", ledger$only[conf])
}
planned_path <- file.path(campaign_dir, "planned.csv")
planned <- if (nzchar(campaign_dir) && file.exists(planned_path))
	utils::read.csv(planned_path, stringsAsFactors = FALSE, colClasses = c(group = "character")) else NULL
if (!is.null(planned)) planned$group[is.na(planned$group) | !nzchar(planned$group)] <- "rest"

done_by_unit <- if (!is.null(ledger)) tapply(ledger$reps_done, ukey(ledger), function(v) unique(parse_reps(v)), simplify = FALSE) else list()
dead_by_unit <- if (!is.null(planned)) {
	dead <- planned[!(planned$id %in% if (is.null(ledger)) character() else ledger$id), ]
	table(ukey(dead))
} else table(character())

# Seconds per replicate (single core).
costs <- utils::read.csv(file.path(script_dir, "calibration_study_costs.csv"), stringsAsFactors = FALSE)
measured <- if (!is.null(ledger)) {
	l <- ledger[is.finite(ledger$secs_per_rep) & ledger$n_done > 0, ]
	l$family <- ifelse(l$design %in% MATCHED_DESIGNS, "matched", "iid")
	list(unit = tapply(l$secs_per_rep, ukey(l), stats::median),
		group = tapply(l$secs_per_rep, gkey(l), stats::median))
} else list(unit = numeric(), group = numeric())
spr <- function(u) {
	v <- measured$unit[u$key]
	if (length(v) && is.finite(v)) return(unname(v))
	v <- measured$group[gkey(u)]
	if (length(v) && is.finite(v)) return(unname(v))
	cf <- costs[costs$response_type == u$response_type & costs$family == u$family & costs$group == u$group, ]
	if (!nrow(cf)) cf <- costs[costs$response_type == u$response_type & costs$family == u$family & costs$group == "rest", ]
	v <- cf$secs_per_rep[cf$n == u$n]
	if (length(v)) return(v[[1L]])
	# n outside the table: scale the nearest tabulated n linearly.
	k <- which.min(abs(cf$n - u$n))
	cf$secs_per_rep[[k]] * u$n / cf$n[[k]]
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

# Smallest n first, null before power, so a campaign's cheap size/coverage cells
# publish early.
units <- units[order(units$n, match(units$effect, EFFECTS), match(units$design, DESIGNS), match(units$response_type, RESPONSE_TYPES),
	units$group != "rest", units$group), ]
shards <- list()
reps_done_total <- 0L
units_done <- 0L
units_abandoned <- 0L
group_tag <- function(g) {
	if (identical(g, "rest")) return("")
	if (startsWith(g, "confirm:")) {
		cl <- strsplit(sub("^confirm:", "", g), ";", fixed = TRUE)[[1L]]
		return(sprintf("-confirm%d-%s", length(cl), sub("^Inference", "", cl[[1L]])))
	}
	paste0("-", sub("^Inference", "", g))
}
plan_units <- function(units) {
	for (i in seq_len(nrow(units))) {
		u <- units[i, ]
		want <- seq.int(u$rep_from, length.out = u$reps)
		done <- intersect(done_by_unit[[u$key]] %||% integer(), want)
		reps_done_total <<- reps_done_total + length(done)
		missing <- setdiff(want, done)
		if (!length(missing)) { units_done <<- units_done + 1L; next }
		if (isTRUE(dead_by_unit[u$key] >= max_dead)) { units_abandoned <<- units_abandoned + 1L; next }
		cost <- spr(u)
		# At least one replicate per core: a replicate longer than the slot still starts
		# on every core (the runner always runs each worker's first one).
		per <- max(cores, floor(target_secs * cores / cost))
		chunks <- split(missing, ceiling(seq_along(missing) / per))
		for (ch in chunks) {
			shards[[length(shards) + 1L]] <<- list(
				id = sprintf("%s-%s-n%d-%s%s-r%d", u$response_type, slug(u$design), u$n, u$effect, group_tag(u$group), ch[[1L]]),
				response_type = u$response_type, design = u$design, n = u$n, effect = u$effect, reps = ranges(ch),
				secs_per_rep = round(cost, 1), group = u$group, only = u$only, exclude = u$exclude)
		}
	}
}
plan_units(units)

# Stage 2 of the gate (analyze_calibration_study.R): once no screening shard is
# left, every cell the screen flagged (summary/confirm_cells.csv, rewritten by each
# publish from the screening totals, so fixed once screening is done) gets fresh
# replicates CONFIRM_REP0 + 1 on: --confirm-reps, or --slow-confirm-reps for a
# SLOW_CLASSES class on a matched design. One unit per (response type, design, n,
# effect) runs the flagged classes together (--only); each slow class runs alone.
confirm_units <- NULL
confirm_path <- file.path(campaign_dir, "summary", "confirm_cells.csv")
if (!length(shards) && nzchar(campaign_dir) && file.exists(confirm_path)) {
	cc <- utils::read.csv(confirm_path, stringsAsFactors = FALSE, colClasses = c(formula = "character"))
	if (nrow(cc)) {
		cc$design_label <- ifelse(abs(cc$prob_T - 0.5) > 1e-9, sprintf("%s@prob_T=%s", cc$design, cc$prob_T), cc$design)
		cc$family <- ifelse(cc$design %in% MATCHED_DESIGNS, "matched", "iid")
		cc$slow <- mapply(function(rt, cl, fam) fam == "matched" && cl %in% SLOW_CLASSES[[rt]], cc$response_type,
			cc$inf_class, cc$family)
		cc$sub <- ifelse(cc$slow, cc$inf_class, "fast")
		g <- unique(cc[c("response_type", "design_label", "n_nominal", "effect_label", "family", "sub")])
		confirm_units <- do.call(rbind, lapply(seq_len(nrow(g)), function(i) {
			x <- g[i, ]
			cl <- sort(unique(cc$inf_class[cc$response_type == x$response_type & cc$design_label == x$design_label &
				cc$n_nominal == x$n_nominal & cc$effect_label == x$effect_label & cc$sub == x$sub]))
			data.frame(response_type = x$response_type, design = x$design_label, n = as.integer(x$n_nominal),
				effect = x$effect_label, family = x$family, reps = if (x$sub == "fast") confirm_reps else slow_confirm_reps,
				group = paste0("confirm:", paste(cl, collapse = ";")), rep_from = CONFIRM_REP0 + 1L,
				only = paste(cl, collapse = ","), exclude = "", stringsAsFactors = FALSE)
		}))
		confirm_units$key <- ukey(confirm_units)
		plan_units(confirm_units)
	}
}
units_all <- rbind(units[names(units) %in% names(confirm_units %||% units)], confirm_units)
wave <- utils::head(shards, wave_size)
if (length(wave) > 256L) stop("a wave cannot exceed GitHub's 256-job matrix limit")
esc <- function(x) gsub('"', '\\\\"', x)
json <- vapply(wave, function(s) sprintf(paste0('{"id":"%s","response_type":"%s","design":"%s","n":%d,"effect":"%s","reps":"%s",',
	'"secs_per_rep":%s,"group":"%s","only":"%s","exclude":"%s"}'),
	s$id, s$response_type, esc(s$design), s$n, s$effect, s$reps, format(s$secs_per_rep), s$group, s$only, s$exclude), character(1L))
cat(sprintf('{"include":[%s]}\n', paste(json, collapse = ",")))
if (nzchar(meta_out)) cat(sprintf("units=%d\nunits_done=%d\nunits_abandoned=%d\nreps_total=%d\nreps_done=%d\nwave=%d\nshards_left=%d\n",
	nrow(units_all), units_done, units_abandoned, sum(units_all$reps), reps_done_total, length(wave), length(shards) - length(wave)),
	file = meta_out, append = TRUE)
