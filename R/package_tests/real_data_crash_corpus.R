# Real-data crash corpus (v1.0.7-TODO-102): runs every applicable inference class on every
# redistributable CRAN trial of the experimental catalog, with the trial's real treatment
# assignment and real outcomes, and records what each call does. It finds crashes and
# silent NAs on real data (separation, near-constant columns, real missingness, ties, tiny
# arms, unequal allocation, heavy censoring, singleton clusters); it says nothing about
# calibration (that is v1.1.0-TODO-271).
#
# Usage (from the repo root, against the installed EDI):
#   Rscript R/package_tests/real_data_crash_corpus.R [options]
#     --datasets a,b         catalog Dataset names (default: every resolvable row)
#     --classes A,B          inference classes (default: every applicable class)
#     --response-types t,u   outcome response types (the CI shards by these)
#     --out FILE             results CSV (default real_data_crash_corpus_results.csv)
#     --timeout SECS         per-case wall-clock limit (default 60)
#     --r N, --B N           randomization redraws / bootstrap resamples (default 49 / 49)
#     --subsample-above N    subsample trials above N rows (default 5000) ...
#     --n-max N              ... to N rows, per arm, seeded (default 2000)
#     --cores N              (dataset, outcome) units run in parallel (default 1)
#     --shard i/k            run units i, i + k, ... of the selected ones (CI sharding)
#     --compare BASELINE     exit 1 on a regression against BASELINE (see below)
#     --write-baseline FILE  merge these results into FILE (keeps the TODO citations)
#     --summary FILE         markdown summary (default: $GITHUB_STEP_SUMMARY, else none)
#     --from-results F,G     use these results CSVs (e.g. the CI shards' artifacts) instead of
#                            running; with --compare / --write-baseline
#
# One case = (dataset, outcome, inference class). Each runs in a forked child with the
# --timeout limit, so a hanging fit cannot stall the job. Its five calls, each recorded on
# its own row: estimate (compute_estimate), asymp_pval, asymp_ci, rand_pval (seeded, r
# redraws) and boot_ci (seeded, B resamples, percentile type). A call a class does not have is not run.
# Status per call:
#   ok            finite value, no warning
#   warning       finite value, with a warning (message recorded)
#   na            NA or non-finite value with no warning (a silent NA)
#   nonestimable  EDI refused: an edi_* refusal condition, a refusal message, or an NA that
#                 EDI explains with a warning. Expected, counted apart from crashes
#   error         any other error
#   timeout       the case hit --timeout (every call of the case gets it)
# A design that cannot be built is one row with class "<design>" and call "design".
#
# Gate (--compare). The baseline R/package_tests/ci/real_data_crash_corpus_baseline.csv has
# one row per (dataset, outcome, class, call) with its expected status and, for every error /
# na / timeout row, a `todo` column citing an open release TODO (v1.0.7-TODO-102 style). The
# job fails on: a call that is error or timeout now but was not in the baseline; a call that
# is na now where the baseline had a value (ok / warning); a baseline error / na / timeout row
# without an open TODO. Calls that improved are listed. Refresh with --write-baseline after
# a deliberate change (see R/package_tests/ci/README.md).

suppressPackageStartupMessages({
	library(EDI)
	library(parallel)
})
source(file.path(local({
	file_arg <- sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE))
	sourced <- Filter(is.character, lapply(rev(sys.frames()), function(f) f$ofile))
	dirname(normalizePath(c(unlist(sourced), file_arg, "R/package_tests/real_data_crash_corpus.R")[[1L]]))
}), "real_data_catalog.R"))

CRASH_CALLS <- c("estimate", "asymp_pval", "asymp_ci", "rand_pval", "boot_ci")
CRASH_BAD <- c("error", "timeout")
CRASH_VALUED <- c("ok", "warning")
CRASH_REFUSAL_CLASSES <- c("edi_unsupported_procedure", "edi_estimand_not_supported", "edi_wald_mle_boundary_unavailable",
	"edi_rand_ci_exact_zero_one_refused", "edi_rand_ci_estimand_scale_mismatch_refused",
	"edi_rand_bootstrap_ci_scale_mismatch_refused")
CRASH_REFUSAL_PATTERN <- paste(c("not (supported|available|estimable|applicable|defined|identifiable|implemented)",
	"cannot be (estimated|computed|fit|identified)", "non-?estimable", "unavailable", "only (available|supported|defined)",
	"is not identified", "requires (a|an|at least|the|exactly)", "not enough", "too few", "no (events|variation|usable)",
	"does not support", "is undefined", "refus"), collapse = "|")

parse_args <- function(argv) {
	opt <- list(datasets = NULL, classes = NULL, response_types = NULL, out = "real_data_crash_corpus_results.csv",
		timeout = 60, r = 49L, B = 49L, n_max = 2000L, subsample_above = 5000L, cores = 1L, shard = NULL, compare = NULL, write_baseline = NULL, from_results = NULL,
		summary = Sys.getenv("GITHUB_STEP_SUMMARY", ""))
	i <- 1L
	while (i <= length(argv)) {
		a <- argv[[i]]
		key <- gsub("-", "_", sub("^--", "", a))
		if (!key %in% names(opt) || i == length(argv)) stop("unknown or valueless argument: ", a, call. = FALSE)
		val <- argv[[i + 1L]]
		opt[[key]] <- switch(key,
			datasets = , classes = , response_types = , from_results = trimws(strsplit(val, ",", fixed = TRUE)[[1L]]),
			timeout = as.numeric(val), r = , B = , n_max = , subsample_above = , cores = as.integer(val),
			val)
		i <- i + 2L
	}
	opt
}

clean_msg <- function(m) {
	m <- gsub("[\r\n\t]+", " ", m)
	m <- gsub("\\s+", " ", trimws(m))
	substr(m, 1L, 300L)
}

# Run one call, classify it.
run_call <- function(fun) {
	warn <- NULL
	t0 <- proc.time()[["elapsed"]]
	res <- tryCatch(withCallingHandlers(list(value = fun()), warning = function(w) {
		if (is.null(warn)) warn <<- conditionMessage(w)
		invokeRestart("muffleWarning")
	}), error = function(e) list(error = e))
	secs <- round(proc.time()[["elapsed"]] - t0, 3L)
	if (!is.null(res$error)) {
		e <- res$error
		msg <- clean_msg(conditionMessage(e))
		refusal <- inherits(e, CRASH_REFUSAL_CLASSES) || grepl(CRASH_REFUSAL_PATTERN, msg, ignore.case = TRUE)
		return(list(status = if (refusal) "nonestimable" else "error", message = msg, value = NA_real_, secs = secs))
	}
	v <- suppressWarnings(as.numeric(unlist(res$value)))
	if (!length(v) || any(!is.finite(v))) {
		# An NA that EDI explains with a warning is its documented refusal; a silent NA is the finding.
		return(list(status = if (is.null(warn)) "na" else "nonestimable", message = if (is.null(warn)) "" else clean_msg(warn),
			value = NA_real_, secs = secs))
	}
	list(status = if (is.null(warn)) "ok" else "warning", message = if (is.null(warn)) "" else clean_msg(warn),
		value = v[1L], secs = secs)
}

# The five calls of one case, in a forked child bounded by `timeout` seconds.
run_case <- function(des, cls, seed, opt) {
	body <- function() {
		set.seed(seed)
		gen <- get(cls, envir = asNamespace("EDI"))
		inf <- NULL
		built <- run_call(function() { inf <<- gen$new(des); 0 })
		if (built$status != "ok" && built$status != "warning") {
			return(lapply(CRASH_CALLS, function(cl) built))
		}
		calls <- list(
			estimate = function() inf$compute_estimate(),
			asymp_pval = if (is.function(inf$compute_asymp_two_sided_pval)) function() inf$compute_asymp_two_sided_pval(),
			asymp_ci = if (is.function(inf$compute_asymp_confidence_interval)) function() inf$compute_asymp_confidence_interval(),
			rand_pval = if (is.function(inf$compute_rand_two_sided_pval)) function() { set.seed(seed); inf$compute_rand_two_sided_pval(r = opt$r, show_progress = FALSE) },
			# Percentile intervals: the default BCa refuses (NA) at a crash-test B by design. A class
			# without a percentile type runs its default.
			boot_ci = if (is.function(inf$compute_bootstrap_confidence_interval)) function() {
				set.seed(seed)
				tryCatch(inf$compute_bootstrap_confidence_interval(B = opt$B, type = "percentile", show_progress = FALSE),
					error = function(e) {
						if (!grepl("Must be element of set|unused argument|type", conditionMessage(e))) stop(e)
						set.seed(seed)
						inf$compute_bootstrap_confidence_interval(B = opt$B, show_progress = FALSE)
					})
			})
		out <- lapply(CRASH_CALLS, function(cl) if (is.null(calls[[cl]])) NULL else run_call(calls[[cl]]))
		names(out) <- CRASH_CALLS
		out
	}
	job <- mcparallel(body(), silent = TRUE)
	res <- mccollect(job, wait = FALSE, timeout = opt$timeout)
	if (is.null(res)) {
		tools::pskill(job$pid, tools::SIGKILL)
		mccollect(job, wait = TRUE)
		# The case's wall time goes on its first call only, so per-class sums stay right.
		return(setNames(lapply(CRASH_CALLS, function(cl) list(status = "timeout", message = sprintf("case exceeded %gs", opt$timeout),
			value = NA_real_, secs = if (cl == CRASH_CALLS[1L]) opt$timeout else NA_real_)), CRASH_CALLS))
	}
	res <- res[[1L]]
	if (inherits(res, "try-error") || is.null(res)) {
		msg <- if (inherits(res, "try-error")) clean_msg(attr(res, "condition")$message %||% as.character(res)) else "child process died"
		return(setNames(lapply(CRASH_CALLS, function(cl) list(status = "error", message = msg, value = NA_real_, secs = NA_real_)), CRASH_CALLS))
	}
	names(res) <- CRASH_CALLS
	res
}

case_seed <- function(...) {
	s <- paste(..., sep = "|")
	h <- 0
	for (b in utf8ToInt(s)) h <- (h * 31 + b) %% 2147483647
	as.integer(h)
}

# Every case of one (trial, outcome) unit.
run_unit <- function(trial, k, opt) {
	s <- rdc_outcome_subset(trial, k)
	rt <- s$type
	row0 <- data.frame(dataset = trial$dataset, outcome = s$name, response_type = rt, design = trial$design,
		n = nrow(s$X), p = ncol(s$X), stringsAsFactors = FALSE)
	des <- NULL
	# get_X() builds the design's imputed covariate matrix once, here, before the per-class forks; otherwise every
	# forked case re-imputes (missRanger), ~125 s per class on `opt` (v1.0.7-TODO-184).
	built <- run_call(function() { des <<- rdc_new_design(trial, s, rt); rdc_add_responses(des, s); des$get_X(); 0 })
	if (!built$status %in% CRASH_VALUED) {
		return(cbind(row0, class = "<design>", call = "design", status = built$status, message = built$message,
			value = NA_real_, secs = built$secs, stringsAsFactors = FALSE))
	}
	classes <- tryCatch(sort(EDI:::applicable_inference_class_names_for_design(des)), error = function(e) character())
	if (!is.null(opt$classes)) classes <- intersect(classes, opt$classes)
	rows <- lapply(classes, function(cls) {
		res <- run_case(des, cls, case_seed(trial$dataset, s$name, cls), opt)
		do.call(rbind, lapply(CRASH_CALLS, function(cl) {
			r <- res[[cl]]
			if (is.null(r)) return(NULL)
			cbind(row0, class = cls, call = cl, status = r$status, message = r$message, value = r$value, secs = r$secs,
				stringsAsFactors = FALSE)
		}))
	})
	do.call(rbind, rows)
}

# ---------------------------------------------------------------------------
# Baseline compare / refresh
# ---------------------------------------------------------------------------

CRASH_KEY <- c("dataset", "outcome", "class", "call")
key_of <- function(d) do.call(paste, c(unname(as.list(d[CRASH_KEY])), sep = "\r"))

open_todos <- function() {
	files <- Sys.glob(file.path(RDC_ROOT, "R", "package_metadata", "future_release_plans", "release_v*.md"))
	out <- character()
	for (f in files) {
		ver <- gsub("_", ".", sub("^release_v(.*)\\.md$", "\\1", basename(f)))
		n <- sub("^- \\[ \\] TODO-([0-9]+[a-z]?).*$", "\\1", grep("^- \\[ \\] TODO-[0-9]+", readLines(f, warn = FALSE), value = TRUE))
		out <- c(out, sprintf("v%s-TODO-%s", ver, n))
	}
	out
}

read_baseline <- function(path) {
	if (!file.exists(path)) return(NULL)
	b <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = character(), colClasses = "character")
	if (!"todo" %in% names(b)) b$todo <- ""
	b
}

compare_to_baseline <- function(res, baseline_path) {
	b <- read_baseline(baseline_path)
	if (is.null(b)) stop("baseline not found: ", baseline_path, call. = FALSE)
	bk <- key_of(b)
	rk <- key_of(res)
	old <- b$status[match(rk, bk)]
	new_bad <- res$status %in% CRASH_BAD & !(old %in% CRASH_BAD)
	new_na <- res$status == "na" & old %in% CRASH_VALUED
	improved <- !is.na(old) & (old %in% c(CRASH_BAD, "na")) & res$status %in% CRASH_VALUED
	todos <- open_todos()
	need_todo <- b$status %in% c(CRASH_BAD, "na")
	cited <- vapply(strsplit(b$todo, "[;, ]+"), function(t) any(t %in% todos), logical(1))
	uncited <- b[need_todo & !cited, , drop = FALSE]
	list(regressions = res[new_bad | new_na, , drop = FALSE], old_status = old[new_bad | new_na],
		improved = res[improved, , drop = FALSE], uncited = uncited)
}

write_baseline <- function(res, path) {
	old <- read_baseline(path)
	out <- res[, c(CRASH_KEY, "response_type", "status", "message")]
	out$todo <- ""
	if (!is.null(old)) {
		i <- match(key_of(out), key_of(old))
		carry <- !is.na(i) & out$status %in% c(CRASH_BAD, "na")
		out$todo[carry] <- old$todo[i[carry]]
		# Rows of the old baseline this run did not cover (another shard, a --datasets subset) stay.
		out <- rbind(out, old[!key_of(old) %in% key_of(out), names(out), drop = FALSE])
	}
	out <- out[order(out$response_type, out$dataset, out$outcome, out$class, match(out$call, c("design", CRASH_CALLS))), ]
	utils::write.csv(out, path, row.names = FALSE)
	invisible(out)
}

summary_md <- function(res, skips, cmp = NULL) {
	tab <- function(by) {
		st <- c("ok", "warning", "na", "nonestimable", "error", "timeout")
		x <- table(factor(res[[by]]), factor(res$status, levels = st))
		x <- x[order(-x[, "error"] - x[, "timeout"] - x[, "na"]), , drop = FALSE]
		lines <- c(sprintf("| %s | %s |", by, paste(st, collapse = " | ")), paste0("|", strrep("---|", length(st) + 1L)))
		bad <- x[, "error"] + x[, "timeout"] + x[, "na"] > 0
		x <- x[bad, , drop = FALSE]
		c(lines, vapply(seq_len(nrow(x)), function(i) sprintf("| %s | %s |", rownames(x)[i], paste(x[i, ], collapse = " | ")), ""))
	}
	n_cases <- nrow(unique(res[, c("dataset", "outcome", "class")]))
	c("## Real-data crash corpus", "",
		sprintf("%d cases (dataset x outcome x class), %d calls, %d datasets, %.1f min of fitting.", n_cases, nrow(res),
			length(unique(res$dataset)), sum(res$secs, na.rm = TRUE) / 60), "",
		"Status counts: ", paste(sprintf("%s %d", names(table(res$status)), table(res$status)), collapse = ", "), "",
		if (!is.null(cmp)) c(sprintf("**Regressions: %d. Uncited baseline rows: %d. Improved: %d.**", nrow(cmp$regressions),
			nrow(cmp$uncited), nrow(cmp$improved)), ""),
		"### Classes with an error, timeout or NA", "", tab("class"), "",
		"### Datasets with an error, timeout or NA", "", tab("dataset"), "",
		sprintf("### Skipped catalog rows (%d)", nrow(skips)), "",
		if (nrow(skips)) c("| dataset | reason |", "|---|---|", sprintf("| %s | %s |", skips$dataset, gsub("\\|", "/", skips$reason))))
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function(argv = commandArgs(trailingOnly = TRUE)) {
	opt <- parse_args(argv)
	if (!is.null(opt$from_results)) {
		res <- do.call(rbind, lapply(opt$from_results, utils::read.csv, stringsAsFactors = FALSE, na.strings = c("NA")))
		res$message[is.na(res$message)] <- ""
		if (!is.null(opt$write_baseline)) write_baseline(res, opt$write_baseline)
		if (!is.null(opt$compare)) {
			cmp <- compare_to_baseline(res, opt$compare)
			message(sprintf("%d regression(s), %d uncited baseline row(s), %d improved", nrow(cmp$regressions), nrow(cmp$uncited), nrow(cmp$improved)))
			if (nrow(cmp$regressions) || nrow(cmp$uncited)) quit(status = 1L)
		}
		return(invisible(res))
	}
	cat_df <- rdc_catalog()
	if (!is.null(opt$datasets)) {
		miss <- setdiff(opt$datasets, cat_df$dataset)
		if (length(miss)) stop("not in the redistributable CRAN catalog rows: ", paste(miss, collapse = ", "), call. = FALSE)
		cat_df <- cat_df[cat_df$dataset %in% opt$datasets, , drop = FALSE]
	}
	trials <- list()
	skips <- data.frame(dataset = character(), reason = character(), stringsAsFactors = FALSE)
	for (i in seq_len(nrow(cat_df))) {
		row <- cat_df[i, ]
		tr <- tryCatch(rdc_resolve(row, n_max = opt$n_max, subsample_above = opt$subsample_above), error = function(e) list(dataset = row$dataset, skip = paste("fetch failed:", conditionMessage(e))))
		if (!is.null(tr[["skip"]])) { skips[nrow(skips) + 1L, ] <- list(row$dataset, tr[["skip"]]); next }
		trials[[row$dataset]] <- tr
	}
	units <- list()
	for (tr in trials) for (k in seq_along(tr$outcomes)) {
		if (is.null(opt$response_types) || tr$outcomes[[k]]$type %in% opt$response_types) units[[length(units) + 1L]] <- list(tr = tr, k = k)
	}
	if (!is.null(opt$shard)) {
		ik <- as.integer(strsplit(opt$shard, "/", fixed = TRUE)[[1L]])
		units <- units[seq_along(units) %% ik[2L] == (ik[1L] - 1L) %% ik[2L]]
	}
	message(sprintf("%d units (dataset x outcome) from %d trials; %d catalog rows skipped", length(units), length(trials), nrow(skips)))
	t0 <- proc.time()[["elapsed"]]
	one <- function(u) {
		t1 <- proc.time()[["elapsed"]]
		r <- tryCatch(run_unit(u$tr, u$k, opt), error = function(e) {
			data.frame(dataset = u$tr$dataset, outcome = u$tr$outcomes[[u$k]]$name, response_type = u$tr$outcomes[[u$k]]$type,
				design = u$tr$design, n = u$tr$n, p = ncol(u$tr$X), class = "<runner>", call = "unit", status = "error",
				message = clean_msg(conditionMessage(e)), value = NA_real_, secs = NA_real_, stringsAsFactors = FALSE)
		})
		message(sprintf("  %-40s %-28s %4d calls %6.1fs", u$tr$dataset, u$tr$outcomes[[u$k]]$name, NROW(r), proc.time()[["elapsed"]] - t1))
		r
	}
	res_list <- if (opt$cores > 1L) mclapply(units, one, mc.cores = opt$cores, mc.preschedule = FALSE) else lapply(units, one)
	res <- do.call(rbind, Filter(is.data.frame, res_list))
	if (is.null(res)) res <- data.frame()
	message(sprintf("done: %d calls in %.1f min", nrow(res), (proc.time()[["elapsed"]] - t0) / 60))
	utils::write.csv(res, opt$out, row.names = FALSE)
	utils::write.csv(skips, sub("\\.csv$", "_skips.csv", opt$out), row.names = FALSE)
	cmp <- NULL
	if (!is.null(opt$compare)) cmp <- compare_to_baseline(res, opt$compare)
	if (!is.null(opt$write_baseline)) write_baseline(res, opt$write_baseline)
	md <- summary_md(res, skips, cmp)
	if (!is.null(cmp) && nrow(cmp$regressions)) {
		reg <- cmp$regressions
		md <- c(md, "", "### Regressions", "", "| dataset | outcome | class | call | baseline | now | message |", "|---|---|---|---|---|---|---|",
			sprintf("| %s | %s | %s | %s | %s | %s | %s |", reg$dataset, reg$outcome, reg$class, reg$call,
				ifelse(is.na(cmp$old_status), "(new case)", cmp$old_status), reg$status, gsub("\\|", "/", reg$message)))
	}
	if (!is.null(cmp) && nrow(cmp$uncited)) {
		u <- cmp$uncited
		md <- c(md, "", "### Baseline error / NA / timeout rows without an open TODO", "",
			sprintf("- %s / %s / %s / %s: %s (todo: '%s')", u$dataset, u$outcome, u$class, u$call, u$status, u$todo))
	}
	if (!is.null(cmp) && nrow(cmp$improved)) {
		im <- cmp$improved
		md <- c(md, "", "### Improved (refresh the baseline)", "", sprintf("- %s / %s / %s / %s: now %s", im$dataset, im$outcome, im$class, im$call, im$status))
	}
	if (nzchar(opt$summary)) cat(md, sep = "\n", file = opt$summary, append = TRUE)
	else writeLines(md, sub("\\.csv$", "_summary.md", opt$out))
	if (!is.null(cmp) && (nrow(cmp$regressions) || nrow(cmp$uncited))) {
		message(sprintf("FAIL: %d regression(s), %d baseline row(s) without an open TODO", nrow(cmp$regressions), nrow(cmp$uncited)))
		quit(status = 1L)
	}
	invisible(res)
}

if (sys.nframe() == 0L) main()
