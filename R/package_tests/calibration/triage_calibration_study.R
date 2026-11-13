#!/usr/bin/env Rscript
# Drafts release-plan TODOs from a calibration campaign's failure triage (summary/triage.csv, written by
# analyze_calibration_study.R through calibration_study_triage.R). Run locally by the owner, never in CI: it edits
# R/package_metadata/future_release_plans/release_v*.md, which the owner reviews and commits.
#
# For each triage group (response type x class x procedure x metric):
#   skipped  when an open TODO already covers it (an unchecked "- [ ] TODO-" entry naming the class, the procedure and
#            the metric; or one this script drafted earlier, found by its <!-- triage: <group_id> --> marker), when a
#            row of calibration_study_accepted.csv covers it, or (bias groups) when it shows on fewer than two designs
#   drafted  otherwise, as "- [ ] TODO-<next number>" under "## Drafted from calibration campaign <id> (review)" at the
#            end of the release file its category maps to: bug -> the current release (the first release_v*.md after
#            R/EDI/DESCRIPTION's version that is not closed: a "> **Status: CLOSED" line in its first 20 lines marks a
#            release about to ship), small_sample and bias -> the next open one. TODO numbers are global across the
#            release files, so the next number is one past the largest anywhere.
#
# Usage (from the repository root):
#   Rscript R/package_tests/calibration/triage_calibration_study.R [--campaign ID] [--dry-run]
#     [--triage FILE] [--allow-provisional] [--current v1_0_6] [--next v1_1_0] [--plans-dir DIR] [--accepted FILE]
#     [--description FILE] [--date YYYY-MM-DD]
# --campaign: default the newest complete campaign on the calibration-results branch (fetched from origin).
# --triage: read this triage.csv instead of the results branch (the campaign id is then --campaign, or "local").
# --allow-provisional: draft from a campaign that is still running (its failures are provisional).
# --dry-run: print the drafts and the skips, change nothing.

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

args <- commandArgs(TRUE)
arg_value <- function(flag, default = NULL) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
dry_run <- "--dry-run" %in% args
allow_provisional <- "--allow-provisional" %in% args
plans_dir <- arg_value("--plans-dir", "R/package_metadata/future_release_plans")
accepted_path <- arg_value("--accepted", "R/package_tests/calibration/calibration_study_accepted.csv")
results_branch <- "calibration-results"
today <- arg_value("--date", format(Sys.Date()))

git <- function(...) {
	out <- suppressWarnings(system2("git", c(...), stdout = TRUE, stderr = FALSE))
	if (!is.null(attr(out, "status")) && attr(out, "status") != 0) NULL else out
}
repo_url <- local({
	u <- git("remote", "get-url", "origin")
	m <- if (length(u)) regmatches(u, regexpr("github\\.com[:/][^/]+/[^/.]+", u)) else character()
	if (length(m)) paste0("https://", sub(":", "/", m)) else "https://github.com/kapelner/EDI"
})

# The triage table and the campaign it came from.
triage_file <- arg_value("--triage")
campaign <- arg_value("--campaign")
if (!is.null(triage_file)) {
	tr <- read_csv_fast(triage_file, stringsAsFactors = FALSE)
	if (is.null(campaign)) campaign <- "local"
} else {
	if (is.null(git("fetch", "--quiet", "origin", results_branch))) stop("could not fetch ", results_branch, " from origin")
	ref <- paste0("origin/", results_branch)
	show <- function(path) git("show", paste0(ref, ":", path))
	if (is.null(campaign)) {
		cs <- sort(sub("^campaigns/", "", git("ls-tree", "--name-only", ref, "campaigns/")), decreasing = TRUE)
		done <- vapply(cs, function(c) identical(trimws(show(sprintf("campaigns/%s/status.txt", c))), "complete"), logical(1))
		if (!any(done)) stop("no complete campaign on ", results_branch, "; pass --campaign ID --allow-provisional for a running one")
		campaign <- cs[done][1L]
	}
	txt <- show(sprintf("campaigns/%s/summary/triage.csv", campaign))
	if (is.null(txt)) stop("campaign ", campaign, " has no summary/triage.csv on ", results_branch,
		" (analyzed before triage existed: rerun analyze_calibration_study.R on its stats)")
	tr <- read_csv_fast(text = txt, stringsAsFactors = FALSE)
}
if (!nrow(tr)) { cat("Campaign", campaign, "has no failing groups: nothing to draft.\n"); quit(save = "no", status = 0L) }
if (!all(as.logical(tr$campaign_final)) && !allow_provisional)
	stop("campaign ", campaign, " is not complete: its failures are provisional. Pass --allow-provisional to draft anyway.")

# Release files: current = the first release_v*.md after DESCRIPTION's version, next = the one after it.
rel_files <- list.files(plans_dir, pattern = "^release_v[0-9]+_[0-9]+_[0-9]+\\.md$", full.names = TRUE)
rel_ver <- package_version(gsub("_", ".", sub("^release_v(.*)\\.md$", "\\1", basename(rel_files))))
rel_files <- rel_files[order(rel_ver)]; rel_ver <- sort(rel_ver)
# A release closed to new TODOs (a "> **Status: CLOSED" line in its header, e.g. one about to ship) is never a target;
# its open TODOs still count as covering a group.
is_closed <- vapply(rel_files, function(f) any(grepl("^> \\*\\*Status: CLOSED", utils::head(readLines(f, warn = FALSE), 20L))), logical(1))
pick <- function(flag, default) {
	v <- arg_value(flag)
	if (is.null(v)) return(default)
	f <- file.path(plans_dir, sprintf("release_%s.md", sub("^v?", "v", gsub("\\.", "_", v))))
	if (!file.exists(f)) stop("no release file ", f)
	if (is_closed[[match(normalizePath(f), normalizePath(rel_files))]]) stop(basename(f), " is closed to new TODOs (its Status: CLOSED line)")
	f
}
after <- if (is.null(arg_value("--current")) || is.null(arg_value("--next"))) {
	pkg_ver <- package_version(read.dcf(arg_value("--description", "R/EDI/DESCRIPTION"), fields = "Version")[1L, 1L])
	a <- which(rel_ver > pkg_ver & !is_closed)
	if (length(a) < 2L) stop("cannot find two release files after version ", pkg_ver, "; pass --current and --next")
	a
} else integer()
current_file <- pick("--current", rel_files[after[1L]])
next_file <- pick("--next", rel_files[after[2L]])

# Open TODOs (one entry per "- [ ] TODO-" line) across every release file, and the largest TODO number anywhere.
plan_lines <- lapply(rel_files, readLines, warn = FALSE)
names(plan_lines) <- rel_files
all_text <- unlist(plan_lines, use.names = FALSE)
nums <- as.integer(sub("TODO-", "", unlist(regmatches(all_text, gregexpr("TODO-[0-9]+", all_text)))))
next_num <- max(c(0L, nums), na.rm = TRUE) + 1L
open_idx <- grepl("^\\s*- \\[ \\] TODO-[0-9]+", all_text)
open_todos <- all_text[open_idx]
open_ids <- sub("^\\s*- \\[ \\] (TODO-[0-9]+).*$", "\\1", open_todos)
open_file <- rep(basename(names(plan_lines)), lengths(plan_lines))[open_idx]

metric_words <- c(size = "size|oversized|undersized|reject|type[- ]i\\b", coverage = "cover", bias = "bias")
word <- function(x) paste0("(^|[^A-Za-z0-9_])", x, "($|[^A-Za-z0-9_])")
covering_todo <- function(g) {
	marker <- grepl(sprintf("<!-- triage: %s -->", g$group_id), open_todos, fixed = TRUE)
	short <- sub("^Inference", "", g$inf_class)
	cls <- grepl(word(g$inf_class), open_todos) | grepl(word(short), open_todos)
	proc <- if (g$inf_procedure == "estimate") TRUE else grepl(word(g$inf_procedure), open_todos, ignore.case = TRUE)
	met <- grepl(metric_words[[g$metric]], open_todos, ignore.case = TRUE)
	hit <- which(marker | (cls & proc & met))
	if (length(hit)) sprintf("%s (%s)", open_ids[hit[1L]], open_file[hit[1L]]) else NA_character_
}
acc <- if (file.exists(accepted_path)) read_csv_fast(accepted_path, stringsAsFactors = FALSE) else NULL
covering_accept <- function(g) {
	if (is.null(acc) || !nrow(acc)) return(FALSE)
	any(acc$response_type == g$response_type & acc$inf_class == g$inf_class &
		(acc$inf_procedure == g$inf_procedure | g$inf_procedure == "estimate") & acc$metric == g$metric)
}

metric_text <- c(size = "null size", coverage = "coverage", bias = "bias at the largest n (|bias| / SD > 0.1; reported, not gated)")
draft_entry <- function(g, num) {
	cls <- sub("^Inference", "", g$inf_class)
	what <- if (g$metric == "bias") sprintf("`%s`'s estimate is biased at the largest n", g$inf_class)
		else sprintf("`%s`'s `%s` fails its %s gate", g$inf_class, g$inf_procedure, metric_text[[g$metric]])
	conf <- if (as.logical(g$campaign_final)) sprintf("%d confirmed", g$n_confirmed)
		else sprintf("%d confirmed, %d awaiting confirmation (campaign still running when drafted)", g$n_confirmed, g$n_provisional)
	investigate <- switch(g$category,
		bug = if (identical(g$regime, "finite_sample")) "A finite-sample procedure should hold its level at every n, so this is most likely a bug."
			else if (g$pattern == "largest n not run") "Its largest n never ran (abandoned or skipped), so whether it is a small-sample effect is unknown: run that n first."
			else "It still fails at the largest n, where the level is nearly nominal, so this is most likely a bug, not a small-sample effect.",
		small_sample = "It passes at the largest n, so this looks like a small-sample effect: fix it, or document the small-sample behaviour and accept the cells.",
		bias = "Check whether the estimator is consistent for the estimand the study uses, or the truth is wrong.")
	sprintf(paste0("- [ ] TODO-%d (added %s, drafted by `triage_calibration_study.R` from calibration campaign `%s`; owner to review): ",
		"**%s; %s.** %d failing cell(s) (%s) on %d design(s): %s; formulas %s; failing at n = %s (tested at n = %s); effects %s. ",
		"Worst cell: %s (%s replicates). %s Reproduce: `%s`. Campaign summary: %s/blob/%s/campaigns/%s/README.md. ",
		"Any calibration_study_accepted.csv row for these cells cites this TODO. <!-- triage: %s -->"),
		num, today, campaign, what, g$pattern, g$n_cells, conf, g$n_designs, gsub(";", ", ", g$designs),
		gsub(";", ", ", g$formulas), gsub(";", ", ", g$failing_ns), gsub(";", ", ", g$tested_ns), gsub(";", ", ", g$effects),
		g$worst_cell, g$worst_reps, investigate, g$repro, repo_url, results_branch, campaign, g$group_id)
}

decisions <- data.frame(group_id = tr$group_id, category = tr$category, action = "", detail = "", target = "", stringsAsFactors = FALSE)
drafts <- list()
for (i in seq_len(nrow(tr))) {
	g <- tr[i, ]
	cov <- covering_todo(g)
	if (!is.na(cov)) { decisions$action[i] <- "skip"; decisions$detail[i] <- paste("covered by open", cov); next }
	if (isTRUE(as.logical(g$accepted)) || covering_accept(g)) {
		decisions$action[i] <- "skip"; decisions$detail[i] <- "covered by calibration_study_accepted.csv"; next
	}
	if (g$category == "bias" && g$n_designs < 2L) {
		decisions$action[i] <- "skip"; decisions$detail[i] <- "bias on one design only"; next
	}
	target <- if (g$suggested_release == "current") current_file else next_file
	decisions$action[i] <- "draft"; decisions$detail[i] <- sprintf("TODO-%d", next_num); decisions$target[i] <- basename(target)
	drafts[[target]] <- c(drafts[[target]], draft_entry(g, next_num))
	next_num <- next_num + 1L
}

heading <- sprintf("## Drafted from calibration campaign %s (review)", campaign)
intro <- paste("Drafted by `R/package_tests/calibration/triage_calibration_study.R` from the campaign's `summary/triage.csv`:",
	"one TODO per failing class x procedure x metric. Review each: edit, merge or delete it, and move kept ones into the",
	"implementation list.")
for (target in names(drafts)) {
	if (dry_run) { cat(sprintf("\n### %s\n", basename(target)), paste0(drafts[[target]], "\n\n"), sep = ""); next }
	x <- readLines(target, warn = FALSE)
	h <- match(heading, x)
	if (is.na(h)) {
		x <- c(x, if (length(x) && nzchar(x[length(x)])) "" else NULL, heading, "", intro, "", drafts[[target]])
	} else {
		# Append to the existing section of this campaign, before the next "## " heading (or at the end).
		nxt <- which(grepl("^## ", x) & seq_along(x) > h)
		at <- if (length(nxt)) nxt[1L] - 1L else length(x)
		while (at > h && !nzchar(x[at])) at <- at - 1L
		x <- append(x, drafts[[target]], after = at)
	}
	writeLines(x, target)
}
cat(sprintf("Campaign %s: %d group(s), %d drafted, %d skipped%s.\n", campaign, nrow(tr), sum(decisions$action == "draft"),
	sum(decisions$action == "skip"), if (dry_run) " (dry run: nothing written)" else ""))
cat(sprintf("  %-5s %-60s %-13s %s%s\n", decisions$action, decisions$group_id, decisions$category, decisions$detail,
	ifelse(nzchar(decisions$target), paste0(" -> ", decisions$target), "")), sep = "")
