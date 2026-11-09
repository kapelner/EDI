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
#          [--target-minutes 25] [--wave-size 64] [--max-dead 3] [--meta-out FILE] [--power-ns 50,200]
#
# --power-ns: the n values that get the power effects (default 50,200). The power
# effects are local alternatives beta_T = h / sqrt(n), so power at n = 1000 is
# asymptotically what n = 200 shows, and it would be a third of the campaign's
# compute (measured 2026-11-09); the null runs at every n in --ns.

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
stopifnot(all(designs %in% DESIGNS), all(rts %in% RESPONSE_TYPES), all(effects %in% EFFECTS))

units <- expand.grid(response_type = rts, design = designs, n = ns, effect = effects, stringsAsFactors = FALSE)
units <- units[units$effect == "null" | units$n %in% power_ns, ]
units$family <- ifelse(units$design %in% MATCHED_DESIGNS, "matched", "iid")
units$reps <- ifelse(units$effect == "null", null_reps, power_reps)
ukey <- function(d) paste(d$response_type, d$design, d$n, d$effect, sep = "|")
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
	utils::read.csv(ledger_path, stringsAsFactors = FALSE, colClasses = c(reps_done = "character")) else NULL
if (!is.null(ledger) && !nrow(ledger)) ledger <- NULL
planned_path <- file.path(campaign_dir, "planned.csv")
planned <- if (nzchar(campaign_dir) && file.exists(planned_path)) utils::read.csv(planned_path, stringsAsFactors = FALSE) else NULL

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
		group = tapply(l$secs_per_rep, paste(l$response_type, l$design, l$n, sep = "|"), stats::median))
} else list(unit = numeric(), group = numeric())
spr <- function(u) {
	v <- measured$unit[u$key]
	if (length(v) && is.finite(v)) return(unname(v))
	v <- measured$group[paste(u$response_type, u$design, u$n, sep = "|")]
	if (length(v) && is.finite(v)) return(unname(v))
	v <- costs$secs_per_rep[costs$response_type == u$response_type & costs$family == u$family & costs$n == u$n]
	if (length(v)) return(v[[1L]])
	# n outside the table: scale the nearest tabulated n linearly.
	cf <- costs[costs$response_type == u$response_type & costs$family == u$family, ]
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
units <- units[order(units$n, match(units$effect, EFFECTS), match(units$design, DESIGNS), match(units$response_type, RESPONSE_TYPES)), ]
shards <- list()
reps_done_total <- 0L
units_done <- 0L
units_abandoned <- 0L
for (i in seq_len(nrow(units))) {
	u <- units[i, ]
	done <- done_by_unit[[u$key]] %||% integer()
	done <- intersect(done, seq_len(u$reps))
	reps_done_total <- reps_done_total + length(done)
	missing <- setdiff(seq_len(u$reps), done)
	if (!length(missing)) { units_done <- units_done + 1L; next }
	if (isTRUE(dead_by_unit[u$key] >= max_dead)) { units_abandoned <- units_abandoned + 1L; next }
	cost <- spr(u)
	per <- max(1L, floor(target_secs * cores / cost))
	chunks <- split(missing, ceiling(seq_along(missing) / per))
	for (ch in chunks) {
		shards[[length(shards) + 1L]] <- list(
			id = sprintf("%s-%s-n%d-%s-r%d", u$response_type, slug(u$design), u$n, u$effect, ch[[1L]]),
			response_type = u$response_type, design = u$design, n = u$n, effect = u$effect, reps = ranges(ch),
			secs_per_rep = round(cost, 1))
	}
}
wave <- utils::head(shards, wave_size)
if (length(wave) > 256L) stop("a wave cannot exceed GitHub's 256-job matrix limit")
esc <- function(x) gsub('"', '\\\\"', x)
json <- vapply(wave, function(s) sprintf('{"id":"%s","response_type":"%s","design":"%s","n":%d,"effect":"%s","reps":"%s","secs_per_rep":%s}',
	s$id, s$response_type, esc(s$design), s$n, s$effect, s$reps, format(s$secs_per_rep)), character(1L))
cat(sprintf('{"include":[%s]}\n', paste(json, collapse = ",")))
if (nzchar(meta_out)) cat(sprintf("units=%d\nunits_done=%d\nunits_abandoned=%d\nreps_total=%d\nreps_done=%d\nwave=%d\nshards_left=%d\n",
	nrow(units), units_done, units_abandoned, sum(units$reps), reps_done_total, length(wave), length(shards) - length(wave)),
	file = meta_out, append = TRUE)
