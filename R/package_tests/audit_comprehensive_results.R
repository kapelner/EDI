#!/usr/bin/env Rscript
# Post-run audit of the raw comprehensive_tests results
# (comprehensive_tests_results_nc_1_<response_type>.csv). The harness writes
# millions of rows; nothing else reads their VALUES, so a wrong-but-plausible
# result (zero-width CI, a swallowed programming error recorded as a routine
# failure) can sit there for days. Added 2026-09-19 after a manual audit of
# these files found four real bugs that had been in them for a week.
#
# Checks, per (response_type, bare class, function_run) -- formula/design
# slices are pooled, matching path_audits.html's granularity:
#   pval_out_of_range   ok p-value rows outside [0, 1]
#   reversed_ci         ok CI rows with lower > upper
#   degenerate_ci       >= 2% (and >= 5 rows) of >= 10 finite ok CI rows are near-zero-width
#                       (the zero-width-at-the-point-estimate signature of a
#                       silently failed test inversion)
#   low_coverage        >= 50 ok CI rows with a truth indicator and empirical
#                       coverage of beta_T below 0.75
#   biased_estimate     >= 30 ok compute_estimate/compute_jackknife_estimate
#                       rows whose mean (estimate - truth) is >4 Monte Carlo
#                       standard errors from 0 (one-sample t-test on the
#                       per-row error; truth is `coverage_truth` when present
#                       -- the harness's own truth-scale value, e.g. 1 for a
#                       risk ratio's null, not raw beta_T -- falling back to
#                       beta_T otherwise). Pooled across beta_T/design like
#                       every other check here, so a bias present at either
#                       beta_T=0 or beta_T!=0 shows up; a class whose truth
#                       scale differs from beta_T but has no coverage_truth
#                       override will false-positive here -- if that's the
#                       cause, the fix is adding the override, not accepting
#                       an unrelated estimator bug into the baseline.
#   bad_type1_error     >= 30 ok *_two_sided_pval rows at beta_T=0 (a true
#                       null on any scale) whose rejection rate at alpha=.05
#                       differs from .05 by >4 SEs of a Binomial(n, .05)
#                       (two-sided: catches both inflated and deflated size)
#   low_power           >= 30 ok *_two_sided_pval rows at beta_T!=0 whose
#                       rejection rate at alpha=.05 is <10% -- informational,
#                       not necessarily a defect (power is a function of n/
#                       effect size/method, not a fixed target like Type-I
#                       error), but at this harness's fixed signal strength a
#                       near-zero rejection rate across many replicates is
#                       usually either a broken test or a badly underpowered
#                       one worth knowing about either way
#   programming_error   error_message text that can only be a code defect
#                       ("attempt to apply non-function", "could not find
#                       function", "object 'x' not found", "subscript out of
#                       bounds", "unused argument", ...), NOT a legitimate
#                       refusal or non-estimability report
#
# Gate semantics (same idea as scripts/check_doc_links.py's baseline): the run
# FAILS only on findings absent from comprehensive_results_audit_baseline.csv,
# so accepted historical debt doesn't block pushes but every NEW regression
# does. Findings in the baseline that no longer occur are reported as
# resolved (delete them with --write-baseline); they don't fail the run --
# the CSVs are append-only, so an old row can keep a fixed bug's finding alive
# until the affected rows are regenerated.
#
# Usage:
#   Rscript R/package_tests/audit_comprehensive_results.R                 # gate
#   Rscript R/package_tests/audit_comprehensive_results.R --write-baseline
#   Rscript R/package_tests/audit_comprehensive_results.R --force         # ignore stamp
#
# The raw CSVs are gitignored and only exist where the suite has been run, so
# with none present this exits 0 with a note. Unchanged files (same size and
# mtime as the last passing audit) are not re-read.

suppressPackageStartupMessages(library(data.table))

args = commandArgs(trailingOnly = TRUE)
write_baseline = "--write-baseline" %in% args
force_run = "--force" %in% args || write_baseline

script_arg = grep("^--file=", commandArgs(FALSE), value = TRUE)[1]
here = if (is.na(script_arg)) "R/package_tests" else dirname(normalizePath(sub("^--file=", "", script_arg)))
baseline_path = file.path(here, "comprehensive_results_audit_baseline.csv")
stamp_path = file.path(here, ".comprehensive_results_audit_stamp")

response_types = c("continuous", "incidence", "proportion", "count", "survival", "ordinal")
files = file.path(here, sprintf("comprehensive_tests_results_nc_1_%s.csv", response_types))
names(files) = response_types
files = files[file.exists(files)]
if (!length(files)) {
	cat("audit_comprehensive_results: no raw comprehensive_tests_results_nc_1_*.csv present -- nothing to audit.\n")
	quit(status = 0L)
}

signature = paste(sprintf("%s:%d:%d", basename(files), as.integer(file.size(files)), as.integer(file.mtime(files))), collapse = "|")
if (!force_run && file.exists(stamp_path) && identical(readLines(stamp_path, warn = FALSE)[1L], signature)) {
	cat("audit_comprehensive_results: result files unchanged since the last passing audit -- skipping.\n")
	quit(status = 0L)
}

PROGRAMMING_ERROR_PATTERNS = c(
	"attempt to apply non-function",
	"could not find function",
	"object '[^']+' not found",
	"subscript out of bounds",
	"argument \"[^\"]+\" is missing, with no default",
	"unused argument",
	"non-numeric argument to (binary|mathematical) (operator|function)",
	"\\$ operator is invalid for atomic vectors",
	"is not a function",
	"invalid 'type' \\(closure\\)"
)
programming_error_regex = paste(sprintf("(%s)", PROGRAMMING_ERROR_PATTERNS), collapse = "|")

bare_class = function(x) trimws(sub("^([^ (\\[]+).*$", "\\1", x))
finding = function(check, rt, cls, fn, detail) {
	data.table(check = check, response_type = rt, class = cls, function_run = fn, detail = detail)
}

audit_one = function(path, rt) {
	need = c("inference_class", "function_run", "status", "result", "result_1", "result_2",
		"beta_T", "coverage_truth", "beta_T_in_confidence_interval", "error_message")
	dt = fread(path, select = need, showProgress = FALSE)
	dt[, class := bare_class(inference_class)]
	out = list()

	pv = dt[grepl("pval", function_run, fixed = TRUE) & status == "ok"]
	pv[, v := suppressWarnings(as.numeric(result_1))]
	bad = pv[is.finite(v) & (v < 0 | v > 1), .(n = .N), by = .(class, function_run)]
	if (nrow(bad)) out[[length(out) + 1L]] = bad[, finding("pval_out_of_range", rt, class, function_run, sprintf("%d rows", n))]

	# Exclude delta-shifted pval variants (function_run containing
	# "(delta=...)", e.g. compute_rand_two_sided_pval(delta=0.5)) from the
	# two beta_T-partitioned checks below: those test H0: beta_T == <delta>,
	# not H0: beta_T == 0, so at beta_T == 0 rows a high rejection rate is
	# correct POWER against a false null (delta != 0), not inflated Type-I
	# error, and the reverse partitioning problem holds for beta_T ==
	# <delta> rows. Confirmed empirically 2026-09-22: including them here
	# produced z up to 89 driven entirely by this scale confound.
	pvf = pv[is.finite(v) & v >= 0 & v <= 1 & !grepl("(delta=", function_run, fixed = TRUE)]
	t1 = pvf[beta_T == 0, .(n = .N, reject05 = mean(v < 0.05)), by = .(class, function_run)][n >= 30L]
	if (nrow(t1)) {
		t1[, `:=`(se = sqrt(0.05 * 0.95 / n))]
		t1[, z := (reject05 - 0.05) / se]
		t1 = t1[abs(z) > 4]
		if (nrow(t1)) out[[length(out) + 1L]] = t1[, finding("bad_type1_error", rt, class, function_run, sprintf("reject-rate %.3f at alpha=.05 over %d beta_T=0 rows (z=%.1f)", reject05, n, z))]
	}
	lp = pvf[beta_T != 0, .(n = .N, reject05 = mean(v < 0.05)), by = .(class, function_run)][n >= 30L & reject05 < 0.10]
	if (nrow(lp)) out[[length(out) + 1L]] = lp[, finding("low_power", rt, class, function_run, sprintf("reject-rate %.3f at alpha=.05 over %d beta_T!=0 rows", reject05, n))]

	ci = dt[grepl("confidence_interval", function_run, fixed = TRUE) & status == "ok"]
	ci[, `:=`(lo = suppressWarnings(as.numeric(result_1)), hi = suppressWarnings(as.numeric(result_2)))]
	fin = ci[is.finite(lo) & is.finite(hi)]
	rev = fin[lo > hi, .(n = .N), by = .(class, function_run)]
	if (nrow(rev)) out[[length(out) + 1L]] = rev[, finding("reversed_ci", rt, class, function_run, sprintf("%d rows", n))]

	# Near-zero width (< 1e-6), not exact equality, and a low share threshold: a failed
	# inversion that collapses onto the estimate only some of the time (5.6% and 28% of
	# OrdinalStereotypeLogitRegr's lik_ratio / lik_ratio_bootstrap rows) wrecks coverage
	# without ever reaching the old 50% rule.
	deg = fin[, .(n = .N, nz = sum((hi - lo) < 1e-6), frac = mean((hi - lo) < 1e-6)), by = .(class, function_run)][n >= 10L & nz >= 5L & frac >= 0.02]
	if (nrow(deg)) out[[length(out) + 1L]] = deg[, finding("degenerate_ci", rt, class, function_run, sprintf("%.0f%% of %d rows zero-width", 100 * frac, n))]

	cov = ci[!is.na(beta_T_in_confidence_interval), .(n = .N, coverage = mean(as.logical(beta_T_in_confidence_interval))), by = .(class, function_run)][n >= 50L & coverage < 0.75]
	if (nrow(cov)) out[[length(out) + 1L]] = cov[, finding("low_coverage", rt, class, function_run, sprintf("coverage %.3f over %d rows", coverage, n))]

	est = dt[status == "ok" & function_run %in% c("compute_estimate", "compute_jackknife_estimate")]
	est[, `:=`(est_val = suppressWarnings(as.numeric(result)), truth = fifelse(is.na(coverage_truth), beta_T, coverage_truth))]
	est = est[is.finite(est_val) & is.finite(truth)]
	if (nrow(est)) {
		bias_tbl = est[, {
			d = est_val - truth
			n = .N; b = mean(d); s = sd(d)
			se = if (is.finite(s) && s > 0) s / sqrt(n) else NA_real_
			list(n = n, bias = b, rmse = sqrt(mean(d^2)), tstat = if (is.finite(se) && se > 0) b / se else NA_real_)
		}, by = .(class, function_run)][n >= 30L & is.finite(tstat) & abs(tstat) > 4]
		if (nrow(bias_tbl)) out[[length(out) + 1L]] = bias_tbl[, finding("biased_estimate", rt, class, function_run, sprintf("mean bias %+.4f (rmse %.4f) over %d rows, t=%.1f", bias, rmse, n, tstat))]
	}

	er = dt[status == "error" & !is.na(error_message) & grepl(programming_error_regex, error_message, perl = TRUE)]
	if (nrow(er)) {
		er[, msg := substr(gsub("\\s+", " ", error_message), 1L, 120L)]
		pe = er[, .(n = .N), by = .(class, function_run, msg)]
		out[[length(out) + 1L]] = pe[, finding("programming_error", rt, class, function_run, sprintf("%s (%d rows)", msg, n))]
	}
	if (length(out)) rbindlist(out) else data.table()
}

all_findings = rbindlist(lapply(names(files), function(rt) {
	cat(sprintf("audit_comprehensive_results: reading %s ...\n", basename(files[[rt]])))
	audit_one(files[[rt]], rt)
}), fill = TRUE)
if (!nrow(all_findings)) all_findings = data.table(check = character(), response_type = character(), class = character(), function_run = character(), detail = character())
all_findings[, key := paste(check, response_type, class, function_run, sep = "|")]
# programming_error rows share a key across distinct messages; keep one key per message.
all_findings[check == "programming_error", key := paste(key, sub(" \\(\\d+ rows\\)$", "", detail), sep = "|")]
all_findings = unique(all_findings, by = "key")
setorder(all_findings, check, response_type, class, function_run)

if (write_baseline) {
	fwrite(all_findings[, .(key, check, response_type, class, function_run, detail)], baseline_path)
	writeLines(signature, stamp_path)
	cat(sprintf("audit_comprehensive_results: wrote baseline with %d accepted finding(s) to %s\n", nrow(all_findings), baseline_path))
	quit(status = 0L)
}

# NB: data.table(key = ...) would set the table's sort key, not a column named "key".
baseline = if (file.exists(baseline_path)) fread(baseline_path) else setnames(data.table(character()), "key")
new_findings = all_findings[!key %in% baseline$key]
resolved = baseline[!key %in% all_findings$key]

if (nrow(resolved)) {
	cat(sprintf("audit_comprehensive_results: %d baseline finding(s) no longer occur (fixed, or their rows regenerated) -- prune with --write-baseline:\n", nrow(resolved)))
	print(resolved[, .(check, response_type, class, function_run)], nrows = 20L)
}

if (nrow(new_findings)) {
	cat(sprintf("\naudit_comprehensive_results: %d NEW finding(s) not in the accepted baseline:\n", nrow(new_findings)))
	print(new_findings[, .(check, response_type, class, function_run, detail)], nrows = 200L, trunc.cols = FALSE)
	cat("\nEither fix the underlying defect, or -- if the finding is understood and accepted -- record it with:\n")
	cat("  Rscript R/package_tests/audit_comprehensive_results.R --write-baseline\n")
	quit(status = 1L)
}

writeLines(signature, stamp_path)
cat(sprintf("audit_comprehensive_results: OK -- %d finding(s), all in the accepted baseline.\n", nrow(all_findings)))
