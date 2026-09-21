#!/usr/bin/env Rscript
# Expire stale ERROR rows from the raw comprehensive_tests results CSVs
# (comprehensive_tests_results_nc_1_<response_type>.csv).
#
# Why: the CSVs are append-only and the harness resumes from them
# (is_row_completed() caches only status == "ok" rows), so an error row is
# retried on the next run -- unless the call is no longer made at all
# (slow-path skip, capability/design refusal added, method removed). Then the
# error row is never re-run, never replaced, and outlives the fix that made it
# unreproducible: 231,632 such rows had accumulated in one file, distorting
# path_audits.html's estimability and every value audit.
#
# Rule: an error row is trusted only if it was recorded on a source tree at or
# after the last commit that touched the package source
# (R/EDI/R, R/EDI/src). Older error rows are expired. Nothing of value is
# lost: if a call still fails, the next harness run re-creates its row on the
# current source; if it is skipped now, the row should not exist. "ok" rows are
# never touched (they are the resume cache and the data the audits read).
#
# Second pass -- explicit "ok"-row rules (stale_ok_row_rules.csv): "ok" rows are the harness's
# resume cache, so they are never expired wholesale. Each rule names one (response_type, class,
# function_run) cell, a timestamp cutoff, and the reason the older rows are known-stale (a fix
# landed after they were recorded). Rows in that cell recorded BEFORE the cutoff are removed;
# the harness recomputes them on its next run. Add a rule only with evidence (the reason column).
#
# Caveat: rows carry the commit id of HEAD at run time, so a run made with
# uncommitted source edits is attributed to HEAD.
#
# Usage (from anywhere; default is a DRY RUN that only reports):
#   Rscript R/package_tests/prune_stale_result_rows.R           # report counts
#   Rscript R/package_tests/prune_stale_result_rows.R --apply   # rewrite CSVs
# Each rewritten file is written to a temp file and renamed, so an interrupt
# never leaves a half-written CSV. Not part of the pre-push hook: the raw CSVs
# are gitignored and only exist where the suite has been run.

suppressPackageStartupMessages(library(data.table))

apply_changes = "--apply" %in% commandArgs(trailingOnly = TRUE)

script_arg = grep("^--file=", commandArgs(FALSE), value = TRUE)[1]
here = if (is.na(script_arg)) "R/package_tests" else dirname(normalizePath(sub("^--file=", "", script_arg)))
repo_root = normalizePath(file.path(here, "..", ".."))

git = function(...) suppressWarnings(system2("git", c("-C", repo_root, ...), stdout = TRUE, stderr = FALSE))

source_paths = c("R/EDI/R", "R/EDI/src")
last_src_commit = git("log", "-1", "--format=%H", "--", source_paths)
if (!length(last_src_commit) || !nzchar(last_src_commit[1L])) stop("could not determine the last commit touching ", paste(source_paths, collapse = ", "))
last_src_commit = last_src_commit[1L]

# A commit is "current" iff it is the last source-touching commit or a
# descendant of it. Unknown/NA commits (not in this repo) count as stale.
commit_is_current_cache = new.env(parent = emptyenv())
commit_is_current = function(sha) {
	if (is.na(sha) || !nzchar(sha)) return(FALSE)
	hit = commit_is_current_cache[[sha]]
	if (!is.null(hit)) return(hit)
	status = suppressWarnings(system2("git", c("-C", repo_root, "merge-base", "--is-ancestor", last_src_commit, sha), stdout = FALSE, stderr = FALSE))
	commit_is_current_cache[[sha]] = identical(as.integer(status), 0L)
	commit_is_current_cache[[sha]]
}

response_types = c("continuous", "incidence", "proportion", "count", "survival", "ordinal")
files = file.path(here, sprintf("comprehensive_tests_results_nc_1_%s.csv", response_types))
files = files[file.exists(files)]
if (!length(files)) {
	cat("prune_stale_result_rows: no raw comprehensive_tests_results_nc_1_*.csv present -- nothing to do.\n")
	quit(status = 0L)
}

rules_path = file.path(here, "stale_ok_row_rules.csv")
rules = if (file.exists(rules_path)) fread(rules_path) else data.table(response_type = character(), class = character(), function_run = character(), before_timestamp = character(), reason = character())
bare_class = function(x) sub("^Inference", "", trimws(sub("^([^ (\\[]+).*$", "\\1", x)))

cat(sprintf("prune_stale_result_rows: last source-touching commit is %s; %d explicit ok-row rule(s)\n", substr(last_src_commit, 1L, 10L), nrow(rules)))
total_stale = 0L; total_rule = 0L
for (f in files) {
	rt = sub("^comprehensive_tests_results_nc_1_(.*)\\.csv$", "\\1", basename(f))
	probe = fread(f, select = c("status", "github_commit_id", "inference_class", "function_run", "timestamp"), showProgress = FALSE)
	shas = unique(probe$github_commit_id[probe$status == "error"])
	current = vapply(shas, commit_is_current, logical(1))
	is_stale = probe$status == "error" & !(probe$github_commit_id %in% shas[current])
	is_rule = rep(FALSE, nrow(probe))
	rule_counts = integer()
	if (nrow(rules)) {
		cls = bare_class(probe$inference_class)
		for (k in which(rules$response_type == rt)) {
			hit = probe$status == "ok" & cls == rules$class[k] & probe$function_run == rules$function_run[k] & substr(probe$timestamp, 1L, 10L) < rules$before_timestamp[k]
			rule_counts[paste(rules$class[k], rules$function_run[k])] = sum(hit)
			is_rule = is_rule | hit
		}
	}
	drop = is_stale | is_rule
	total_stale = total_stale + sum(is_stale); total_rule = total_rule + sum(is_rule & !is_stale)
	cat(sprintf("  %-52s rows=%9d error=%9d stale-error=%9d rule-expired-ok=%6d\n", basename(f), nrow(probe), sum(probe$status == "error"), sum(is_stale), sum(is_rule)))
	for (nm in names(rule_counts)) cat(sprintf("      rule: %-90s %6d row(s)\n", nm, rule_counts[[nm]]))
	if (apply_changes && any(drop)) {
		full = fread(f, showProgress = FALSE)
		tmp = paste0(f, ".prune_tmp")
		fwrite(full[!drop], tmp, quote = TRUE, showProgress = FALSE)
		if (!file.rename(tmp, f)) stop("could not replace ", f)
		cat(sprintf("    removed %d rows -> %d remain\n", sum(drop), nrow(full) - sum(drop)))
	}
}
total_stale = total_stale + total_rule
if (!apply_changes && total_stale > 0L) cat(sprintf("prune_stale_result_rows: %d stale row(s) (error rows + rule-matched ok rows) would be removed; re-run with --apply.\n", total_stale))
if (total_stale == 0L) cat("prune_stale_result_rows: no stale error rows.\n")
