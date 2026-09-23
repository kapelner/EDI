#!/usr/bin/env Rscript
# Post-run audit of the raw comprehensive_tests results
# (comprehensive_tests_results_nc_1_<response_type>.csv). The harness writes
# millions of rows; nothing else reads their VALUES, so a wrong-but-plausible
# result (zero-width CI, a swallowed programming error recorded as a routine
# failure) can sit there for days. Added 2026-09-19 after a manual audit of
# these files found four real bugs that had been in them for a week.
#
# Checks, per (response_type, bare class, model_formula, function_run).
# `design` (the randomization mechanism -- Bernoulli/FixedBlocking/etc.) is
# pooled: a correctly-implemented resampling test is valid (p ~ Uniform(0,1)
# under H0) regardless of which design produced the treatment assignment, by
# construction, so mixing designs together costs only which-design
# localization, not validity. `model_formula` (how many covariates the
# INFERENCE class's own fitted model adjusts for -- ~1 vs ~. vs a specific
# formula) is NOT pooled: unlike design, it selects a genuinely different
# computation path inside the class under test, so a bug specific to one
# formula can be diluted below every threshold here if averaged in with a
# working formula's rows. Confirmed real, not hypothetical: InferenceContinLin
# 2026-09-23 -- model_formula=~1 gave a true-null reject rate of 0.00, ~.
# gave 0.88, on the identical dataset/design; pooling formula together is
# exactly what let this sit undetected. (`design_formula`, the formula the
# DESIGN's own matching/blocking machinery consumes, stays pooled with
# `design` -- it's a design-mechanism detail, not an inference-model one.)
#   pval_out_of_range    ok p-value rows outside [0, 1]
#   reversed_ci          ok CI rows with lower > upper
#   degenerate_ci        >= 2% (and >= 5 rows) of >= 10 finite ok CI rows are near-zero-width
#                        (the zero-width-at-the-point-estimate signature of a
#                        silently failed test inversion)
#   low_coverage         >= 50 ok CI rows with a truth indicator and empirical
#                        coverage of beta_T below 0.75
#   biased_estimate      >= 30 ok compute_estimate/compute_jackknife_estimate
#                        rows whose mean (estimate - truth) is >4 Monte Carlo
#                        standard errors from 0 (one-sample t-test on the
#                        per-row error; truth is `coverage_truth` when present
#                        -- the harness's own truth-scale value, e.g. 1 for a
#                        risk ratio's null, not raw beta_T -- falling back to
#                        beta_T otherwise). Pooled across beta_T/design like
#                        every other check here, so a bias present at either
#                        beta_T=0 or beta_T!=0 shows up; a class whose truth
#                        scale differs from beta_T but has no coverage_truth
#                        override will false-positive here -- if that's the
#                        cause, the fix is adding the override, not accepting
#                        an unrelated estimator bug into the baseline.
#   pval_miscalibration  >= 30 ok *_two_sided_pval rows at beta_T=0 (a true
#                        null on any scale), tested four ways on the SAME
#                        per-cell p-value vector: (a) rejection rate at
#                        alpha=.05 vs. its exact two-sided normal p-value,
#                        (b) Fisher's combined-probability method in both
#                        tails (-2*sum(log(p)) and -2*sum(log(1-p)), each
#                        ~ chi-sq(2n) under H0 -- catches excess of very
#                        small p's [inflated Type-I error] or very large p's
#                        [conservative]), (c) an Anderson-Darling test
#                        against Uniform(0,1) (omnibus, tail-weighted --
#                        catches any shape of miscalibration, e.g. mass
#                        concentrated at 0.10-0.30, that (a)/(b) can miss),
#                        (d) a one-sample Kolmogorov-Smirnov test against
#                        Uniform(0,1) (base R stats::ks.test(), no ported
#                        formula -- unlike (c) -- so no approximation-
#                        accuracy question; most sensitive to deviation
#                        concentrated near the MEDIAN of the p-value
#                        distribution, a shape (c) is comparatively less
#                        tuned for since AD upweights the tails). These four
#                        are combined into ONE p-value per cell via the
#                        Cauchy combination test (Liu & Xie 2020, ACAT),
#                        which stays valid without knowing the correlation
#                        between them -- and they ARE correlated (all four
#                        computed from the identical p-value vector, and (c)/
#                        (d) are both omnibus EDF tests of each other's same
#                        general alternative), which is exactly why ACAT
#                        rather than e.g. Bonferroni: ACAT's combination is
#                        provably robust to adding a correlated or even weak
#                        test (bounded power cost), where Bonferroni would
#                        penalize linearly per test added regardless of
#                        redundancy. The combined p-values across every cell
#                        in the run are then FDR-controlled (Benjamini-
#                        Hochberg, q=0.05) to flag findings -- see
#                        PVAL_MISCALIBRATION_FDR_Q below. `detail` reports
#                        the combined p plus every sub-test's own statistic
#                        so a finding can be diagnosed at a glance. Same
#                        delta-shifted-variant exclusion as low_power below.
#                        (This check replaces three earlier separate checks
#                        -- bad_type1_error, fisher_pval_bias, nonuniform_pvals
#                        -- retired 2026-09-23: testing correlated sub-tests
#                        separately, each against its own raw threshold,
#                        inflated the effective per-cell false-positive rate
#                        the same way skipping FDR across cells would.)
#   low_power            >= 30 ok *_two_sided_pval rows at beta_T!=0, tested
#                        via a one-sided exact binomial test of H0: true
#                        rejection rate at alpha=.05 >= LOW_POWER_TARGET
#                        (0.10) against H1: less -- informational, not
#                        necessarily a defect (power is a function of n/
#                        effect size/method, not a fixed target like Type-I
#                        error), but at this harness's fixed signal strength
#                        a near-zero rejection rate across many replicates
#                        is usually either a broken test or a badly
#                        underpowered one worth knowing about either way.
#                        FDR-controlled (Benjamini-Hochberg, q=0.05) across
#                        every cell in the run, its own family separate from
#                        pval_miscalibration's -- these test different
#                        claims (power vs. null-calibration) on disjoint
#                        data (beta_T!=0 vs. beta_T=0 rows), so they don't
#                        belong in the same FDR family or the same Cauchy
#                        combination. (Only one statistic feeds this check
#                        today, so the Cauchy-combine step is a no-op --
#                        ACAT of a single p-value is provably that same
#                        p-value -- but the code path is the same as
#                        pval_miscalibration's so a second power-related
#                        statistic can be added later without restructuring.)
#   programming_error    error_message text that can only be a code defect
#                        ("attempt to apply non-function", "could not find
#                        function", "object 'x' not found", "subscript out
#                        of bounds", "unused argument", ...), NOT a
#                        legitimate refusal or non-estimability report
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

PVAL_CLAMP_EPS = 1e-10 # see note at first use, below
LOW_POWER_TARGET = 0.10
PVAL_MISCALIBRATION_FDR_Q = 0.05
LOW_POWER_FDR_Q = 0.05
AD_MIN_N = 30L # below the row-count floor every sub-test in this family already uses

bare_class = function(x) trimws(sub("^([^ (\\[]+).*$", "\\1", x))
# Extracts the "(model_formula=~X)" tag `inference_class` carries for classes
# that support model-level covariate adjustment; NA for classes that don't
# have the concept (they end up as one pooled group, same as before this
# axis existed).
extract_model_formula = function(x) {
	out = rep(NA_character_, length(x))
	has = grepl("(model_formula=", x, fixed = TRUE)
	out[has] = sub(".*\\(model_formula=([^)]*)\\).*", "\\1", x[has])
	out
}
finding = function(check, rt, cls, fml, fn, detail) {
	data.table(check = check, response_type = rt, class = cls, formula = fml, function_run = fn, detail = detail)
}

# Ported directly (not reproduced from memory -- a transcription error in a
# p-value formula would silently corrupt every finding built on it) from
# ADGofTest::ad.test.pvalue(), the Marsaglia & Marsaglia (2004) asymptotic
# CDF approximation for the Anderson-Darling statistic under a fully-
# specified null (our ad_stat_unif() below produces the identical statistic
# ADGofTest::ad.test.statistic() does -- verified directly against its
# source). This reproduces ADGofTest::ad.test()'s p-value exactly without
# adding it as a runtime dependency to this script.
ad_cdf_marsaglia = function(x, n) {
	if (x < 2) {
		x = exp(-1.2337141 / x) / sqrt(x) * (2.00012 + (0.247105 - (0.0649821 - (0.0347962 - (0.011672 - 0.00168691 * x) * x) * x) * x) * x)
	} else {
		x = exp(-exp(1.0776 - (2.30695 - (0.43424 - (0.082433 - (0.008056 - 0.0003146 * x) * x) * x) * x) * x))
	}
	if (x > 0.8) {
		return(x + (-130.2137 + (745.2337 - (1705.091 - (1950.646 - (1116.36 - 255.7844 * x) * x) * x) * x) * x) / n)
	}
	z = 0.01265 + 0.1757 / n
	if (x < z) {
		v = x / z
		v = sqrt(v) * (1 - v) * (49 * v - 102)
		return(x + v * (0.0037 / (n * n) + 0.00078 / n + 6e-05) / n)
	}
	v = (x - z) / (0.8 - z)
	v = -0.00022633 + (6.54034 - (14.6538 - (14.458 - (8.259 - 1.91864 * v) * v) * v) * v) * v
	x + v * (0.04213 + 0.01365 / n) / n
}
ad_pvalue = function(stat, n) 1 - ad_cdf_marsaglia(stat, n)

# Anderson-Darling statistic against Uniform(0,1), "Case 0" (distribution
# completely specified -- no parameters estimated from the sample, so no
# small-sample correction to the STATISTIC itself is needed, only to its
# p-value via ad_pvalue() above; D'Agostino & Stephens 1986, Table 4.2).
# A2 = -n - (1/n) * sum_{i=1}^n (2i-1) * [log(p_(i)) + log(1-p_(n+1-i))] for
# sorted p_(1) <= ... <= p_(n).
ad_stat_unif = function(v) {
	p = sort(pmin(pmax(v, PVAL_CLAMP_EPS), 1 - PVAL_CLAMP_EPS))
	n = length(p)
	i = seq_len(n)
	s = sum((2 * i - 1) * (log(p) + log1p(-rev(p))))
	-n - s / n
}

# Cauchy combination test (Liu & Xie 2020, "Cauchy combination test: a
# powerful test with analytic p-value calculation under arbitrary
# dependency structures"). Combines possibly-correlated p-values from
# multiple tests on the SAME data into one p-value without needing to know
# or estimate the correlation between them -- unlike Fisher's method, which
# assumes independence. ACAT of a single p-value is provably that exact
# p-value again (verified: for n=1, 1-pcauchy(tan((0.5-p)*pi)) simplifies to
# p via atan(tan(theta))=theta on theta in (-pi/2,pi/2)), so calling this
# with one input is always safe and never changes that input.
acat_combine = function(p) {
	p = pmin(pmax(p, 1e-300), 1 - 1e-16)
	is_tiny = p < 1e-16
	terms = ifelse(is_tiny, 1 / (p * pi), tan((0.5 - p) * pi))
	stat = mean(terms)
	if (stat > 1e15) (1 / stat) / pi else 1 - pcauchy(stat)
}

# Standard Benjamini-Hochberg step-up FDR procedure. Returns a logical
# vector, TRUE for the entries that pass FDR control at level q.
bh_reject = function(p, q) {
	n = length(p)
	if (n == 0L) return(logical(0))
	ord = order(p)
	p_sorted = p[ord]
	below = p_sorted <= (seq_len(n) / n) * q
	k = suppressWarnings(max(which(below)))
	pass = rep(FALSE, n)
	if (is.finite(k) && k > 0L) pass[ord[seq_len(k)]] = TRUE
	pass
}

# Returns list(findings = <already-decided findings, data.table>,
# pval_candidates = <every eligible cell's combined p-value for the
# pval_miscalibration family, NOT yet FDR-filtered>, power_candidates =
# <same, for low_power>). The two candidate tables are pooled across every
# response_type file before FDR is applied (see below the loop) --
# Benjamini-Hochberg needs the full set of tests in its family to compute
# the right threshold, not just one file's.
audit_one = function(path, rt) {
	need = c("inference_class", "function_run", "status", "result", "result_1", "result_2",
		"beta_T", "coverage_truth", "beta_T_in_confidence_interval", "error_message")
	dt = fread(path, select = need, showProgress = FALSE)
	dt[, `:=`(class = bare_class(inference_class), formula = extract_model_formula(inference_class))]
	out = list()

	pv = dt[grepl("pval", function_run, fixed = TRUE) & status == "ok"]
	pv[, v := suppressWarnings(as.numeric(result_1))]
	bad = pv[is.finite(v) & (v < 0 | v > 1), .(n = .N), by = .(class, formula, function_run)]
	if (nrow(bad)) out[[length(out) + 1L]] = bad[, finding("pval_out_of_range", rt, class, formula, function_run, sprintf("%d rows", n))]

	# Exclude delta-shifted pval variants (function_run containing
	# "(delta=...)", e.g. compute_rand_two_sided_pval(delta=0.5)) from the
	# two beta_T-partitioned families below: those test H0: beta_T == <delta>,
	# not H0: beta_T == 0, so at beta_T == 0 rows a high rejection rate is
	# correct POWER against a false null (delta != 0), not inflated Type-I
	# error, and the reverse partitioning problem holds for beta_T ==
	# <delta> rows. Confirmed empirically 2026-09-22: including them here
	# produced z up to 89 driven entirely by this scale confound.
	pvf = pv[is.finite(v) & v >= 0 & v <= 1 & !grepl("(delta=", function_run, fixed = TRUE)]

	# --- pval_miscalibration candidates (beta_T == 0) ---
	pm = pvf[beta_T == 0, {
		vv = pmin(pmax(v, PVAL_CLAMP_EPS), 1 - PVAL_CLAMP_EPS)
		n = .N
		reject05 = mean(v < 0.05)
		se = sqrt(0.05 * 0.95 / n)
		z = (reject05 - 0.05) / se
		p_bad = 2 * pnorm(-abs(z))
		stat_small = -2 * sum(log(vv))       # large => excess of small p's (inflated Type-I error)
		stat_large = -2 * sum(log1p(-vv))    # large => excess of large p's (conservative)
		p_small = pchisq(stat_small, df = 2 * n, lower.tail = FALSE)
		p_large = pchisq(stat_large, df = 2 * n, lower.tail = FALSE)
		A2 = ad_stat_unif(v)
		p_ad = ad_pvalue(A2, n)
		# stats::ks.test() -- base R, no ported formula, no dependency, no
		# approximation-accuracy question at all, unlike ad_pvalue() above.
		# Our per-cell p-values are resampling-based with a small number of
		# achievable distinct values (k/(r+1) for r draws), so ties are
		# essentially guaranteed at these row counts -- ks.test() reliably
		# falls back to its asymptotic branch with a "cannot compute exact
		# p-value with ties" warning, suppressed here same as elsewhere in
		# this script. Included alongside Fisher/AD because ACAT's
		# combination is robust to adding a correlated or even weak test
		# (bounded power cost, not a Bonferroni-style linear penalty), and
		# KS is most sensitive to deviation concentrated near the median of
		# the p-value distribution -- a shape AD (which upweights the
		# tails) is comparatively less tuned for.
		ks_res = suppressWarnings(stats::ks.test(vv, "punif"))
		ks_stat = unname(ks_res$statistic)
		p_ks = ks_res$p.value
		list(n = n, reject05 = reject05, z = z, p_bad = p_bad, stat_small = stat_small, stat_large = stat_large,
			p_small = p_small, p_large = p_large, A2 = A2, p_ad = p_ad, ks_stat = ks_stat, p_ks = p_ks)
	}, by = .(class, formula, function_run)][n >= AD_MIN_N]
	if (nrow(pm)) {
		pm[, p_combined := mapply(function(a, b, c, d, e) acat_combine(c(a, b, c, d, e)), p_bad, p_small, p_large, p_ad, p_ks)]
		pm[, response_type := rt]
	}

	# --- low_power candidates (beta_T != 0) ---
	lp = pvf[beta_T != 0, {
		n = .N
		reject05 = mean(v < 0.05)
		k = sum(v < 0.05)
		p_low = pbinom(k, n, LOW_POWER_TARGET, lower.tail = TRUE) # H0: true power >= target
		list(n = n, reject05 = reject05, p_low = p_low)
	}, by = .(class, formula, function_run)][n >= AD_MIN_N]
	if (nrow(lp)) {
		lp[, p_combined := vapply(p_low, function(p) acat_combine(p), numeric(1))]
		lp[, response_type := rt]
	}

	ci = dt[grepl("confidence_interval", function_run, fixed = TRUE) & status == "ok"]
	ci[, `:=`(lo = suppressWarnings(as.numeric(result_1)), hi = suppressWarnings(as.numeric(result_2)))]
	fin = ci[is.finite(lo) & is.finite(hi)]
	rev = fin[lo > hi, .(n = .N), by = .(class, formula, function_run)]
	if (nrow(rev)) out[[length(out) + 1L]] = rev[, finding("reversed_ci", rt, class, formula, function_run, sprintf("%d rows", n))]

	# Near-zero width (< 1e-6), not exact equality, and a low share threshold: a failed
	# inversion that collapses onto the estimate only some of the time (5.6% and 28% of
	# OrdinalStereotypeLogitRegr's lik_ratio / lik_ratio_bootstrap rows) wrecks coverage
	# without ever reaching the old 50% rule.
	deg = fin[, .(n = .N, nz = sum((hi - lo) < 1e-6), frac = mean((hi - lo) < 1e-6)), by = .(class, formula, function_run)][n >= 10L & nz >= 5L & frac >= 0.02]
	if (nrow(deg)) out[[length(out) + 1L]] = deg[, finding("degenerate_ci", rt, class, formula, function_run, sprintf("%.0f%% of %d rows zero-width", 100 * frac, n))]

	cov = ci[!is.na(beta_T_in_confidence_interval), .(n = .N, coverage = mean(as.logical(beta_T_in_confidence_interval))), by = .(class, formula, function_run)][n >= 50L & coverage < 0.75]
	if (nrow(cov)) out[[length(out) + 1L]] = cov[, finding("low_coverage", rt, class, formula, function_run, sprintf("coverage %.3f over %d rows", coverage, n))]

	est = dt[status == "ok" & function_run %in% c("compute_estimate", "compute_jackknife_estimate")]
	est[, `:=`(est_val = suppressWarnings(as.numeric(result)), truth = fifelse(is.na(coverage_truth), beta_T, coverage_truth))]
	est = est[is.finite(est_val) & is.finite(truth)]
	if (nrow(est)) {
		bias_tbl = est[, {
			d = est_val - truth
			n = .N; b = mean(d); s = sd(d)
			se = if (is.finite(s) && s > 0) s / sqrt(n) else NA_real_
			list(n = n, bias = b, rmse = sqrt(mean(d^2)), tstat = if (is.finite(se) && se > 0) b / se else NA_real_)
		}, by = .(class, formula, function_run)][n >= 30L & is.finite(tstat) & abs(tstat) > 4]
		if (nrow(bias_tbl)) out[[length(out) + 1L]] = bias_tbl[, finding("biased_estimate", rt, class, formula, function_run, sprintf("mean bias %+.4f (rmse %.4f) over %d rows, t=%.1f", bias, rmse, n, tstat))]
	}

	er = dt[status == "error" & !is.na(error_message) & grepl(programming_error_regex, error_message, perl = TRUE)]
	if (nrow(er)) {
		er[, msg := substr(gsub("\\s+", " ", error_message), 1L, 120L)]
		pe = er[, .(n = .N), by = .(class, formula, function_run, msg)]
		out[[length(out) + 1L]] = pe[, finding("programming_error", rt, class, formula, function_run, sprintf("%s (%d rows)", msg, n))]
	}

	list(
		findings = if (length(out)) rbindlist(out) else data.table(),
		pval_candidates = if (nrow(pm)) pm else data.table(),
		power_candidates = if (nrow(lp)) lp else data.table()
	)
}

per_file = lapply(names(files), function(rt) {
	cat(sprintf("audit_comprehensive_results: reading %s ...\n", basename(files[[rt]])))
	audit_one(files[[rt]], rt)
})

rule_findings = rbindlist(lapply(per_file, `[[`, "findings"), fill = TRUE)

pval_candidates = rbindlist(lapply(per_file, `[[`, "pval_candidates"), fill = TRUE)
pval_findings = data.table()
if (nrow(pval_candidates)) {
	pval_candidates[, pass := bh_reject(p_combined, PVAL_MISCALIBRATION_FDR_Q)]
	flagged = pval_candidates[pass == TRUE]
	if (nrow(flagged)) {
		flagged[, detail := sprintf(
			"ACAT-combined p=%.2e over %d beta_T=0 rows (rejection-rate p=%.2e: reject=%.3f z=%.1f; Fisher p_small=%.2e p_large=%.2e; Anderson-Darling A2=%.2f p=%.2e; KS D=%.3f p=%.2e); FDR q=%.2f",
			p_combined, n, p_bad, reject05, z, p_small, p_large, A2, p_ad, ks_stat, p_ks, PVAL_MISCALIBRATION_FDR_Q
		)]
		pval_findings = flagged[, finding("pval_miscalibration", response_type, class, formula, function_run, detail)]
	}
}

power_candidates = rbindlist(lapply(per_file, `[[`, "power_candidates"), fill = TRUE)
power_findings = data.table()
if (nrow(power_candidates)) {
	power_candidates[, pass := bh_reject(p_combined, LOW_POWER_FDR_Q)]
	flagged = power_candidates[pass == TRUE]
	if (nrow(flagged)) {
		flagged[, detail := sprintf(
			"reject-rate %.3f at alpha=.05 over %d beta_T!=0 rows, p=%.2e (H0: true rate >= %.2f); FDR q=%.2f",
			reject05, n, p_low, LOW_POWER_TARGET, LOW_POWER_FDR_Q
		)]
		power_findings = flagged[, finding("low_power", response_type, class, formula, function_run, detail)]
	}
}

all_findings = rbindlist(list(rule_findings, pval_findings, power_findings), fill = TRUE)
if (!nrow(all_findings)) all_findings = data.table(check = character(), response_type = character(), class = character(), formula = character(), function_run = character(), detail = character())
# formula is frequently NA (classes with no model_formula concept); paste()
# on an NA column turns it into the literal string "NA", which is fine as a
# stable, distinct key component -- just don't let it collide with a class
# that legitimately has the formula text "NA" (none do; formulas are R
# formula deparse text, never bare "NA").
all_findings[, key := paste(check, response_type, class, formula, function_run, sep = "|")]
# programming_error rows share a key across distinct messages; keep one key per message.
all_findings[check == "programming_error", key := paste(key, sub(" \\(\\d+ rows\\)$", "", detail), sep = "|")]
all_findings = unique(all_findings, by = "key")
setorder(all_findings, check, response_type, class, formula, function_run)

if (write_baseline) {
	fwrite(all_findings[, .(key, check, response_type, class, formula, function_run, detail)], baseline_path)
	writeLines(signature, stamp_path)
	cat(sprintf("audit_comprehensive_results: wrote baseline with %d accepted finding(s) to %s\n", nrow(all_findings), baseline_path))
	quit(status = 0L)
}

# NB: data.table(key = ...) would set the table's sort key, not a column named "key".
baseline = if (file.exists(baseline_path)) fread(baseline_path) else setnames(data.table(character()), "key")
# Defensive against reading an older baseline written before the `formula`
# column existed: without this, `resolved[, .(..., formula, ...)]` below
# would silently resolve the bare symbol `formula` to base R's formula()
# function (since data.table falls back to the calling scope for a name
# that isn't an actual column) instead of erroring -- confirmed this
# actually happens, not just a hypothetical, when auditing against this
# session's pre-migration baseline file.
if (!"formula" %in% names(baseline)) baseline[, formula := NA_character_]
new_findings = all_findings[!key %in% baseline$key]
resolved = baseline[!key %in% all_findings$key]

if (nrow(resolved)) {
	cat(sprintf("audit_comprehensive_results: %d baseline finding(s) no longer occur (fixed, or their rows regenerated) -- prune with --write-baseline:\n", nrow(resolved)))
	print(resolved[, .(check, response_type, class, formula, function_run)], nrows = 20L)
}

if (nrow(new_findings)) {
	cat(sprintf("\naudit_comprehensive_results: %d NEW finding(s) not in the accepted baseline:\n", nrow(new_findings)))
	print(new_findings[, .(check, response_type, class, formula, function_run, detail)], nrows = 200L, trunc.cols = FALSE)
	cat("\nEither fix the underlying defect, or -- if the finding is understood and accepted -- record it with:\n")
	cat("  Rscript R/package_tests/audit_comprehensive_results.R --write-baseline\n")
	quit(status = 1L)
}

writeLines(signature, stamp_path)
cat(sprintf("audit_comprehensive_results: OK -- %d finding(s), all in the accepted baseline.\n", nrow(all_findings)))
