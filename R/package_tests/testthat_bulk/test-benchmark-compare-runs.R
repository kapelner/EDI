library(testthat)

# R/benchmark/compare_benchmark_runs.R: the regression check the v1.0.5 G2 runbook
# runs on the regenerated model-fit benchmark reports. Base R only; no benchmark
# is run here.
compare_script = test_path("..", "..", "benchmark", "compare_benchmark_runs.R")
source(compare_script, local = TRUE)

bench_row = function(label, response, edi, pkg, func, canonical, style = "") {
	sprintf('    <tr%s><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>1.00x</td><td>0.5</td><td></td><td>NA</td><td>NA</td></tr>',
	        style, label, response, edi, pkg, func, canonical)
}

bench_table = function(rows, first = "Class") {
	c("<table>", "  <thead>",
	  sprintf("    <tr><th>%s</th><th>Response</th><th>EDI Time (ms)</th><th>Canonical Pkg</th><th>Canonical Func</th><th>Canonical Time (ms)</th><th>Speedup</th><th>Timing Pval</th><th></th><th>EDI Iterations</th><th>Canonical Iterations</th></tr>", first),
	  "  </thead>", "  <tbody>", rows, "  </tbody>", "</table>")
}

# A combined report shaped like R/package_metadata/benchmark_model_fits.md:
# markdown headings, raw HTML tables, an R part and a Python part.
synthetic_md = function(edi = list(), canonical_scale = 1, portable = "0") {
	v = function(name, default) if (is.null(edi[[name]])) default else edi[[name]]
	c("# EDI v1.0.5 Exhaustive C++ Model Fit Benchmarks", "",
	  "## R Benchmarks", "", "_Generated: 2026-10-23 10:00:00 IDT_", "",
	  sprintf("*   **Build env at build:** `EDI_PORTABLE=%s`, `EDI_DISABLE_VECTORIZATION=0`", portable), "",
	  "### Results", "",
	  bench_table(c(
	  	bench_row("InferenceContinOLS", "continuous", v("ols", "0.10"), "stats", "lm.fit", 0.20 * canonical_scale),
	  	bench_row("InferenceIncidLogRegr", "incidence", v("logit", "2.00"), "stats", "glm.fit", 4.00 * canonical_scale),
	  	bench_row("InferenceContinGLMM (pairs)", "continuous", v("glmm1", "1.00"), "lme4", "lmer(ML)", 10 * canonical_scale),
	  	bench_row("InferenceContinGLMM (pairs)", "continuous", v("glmm2", "1.00"), "lme4", "lmer(ML)", 10 * canonical_scale),
	  	bench_row("InferenceCountNegBin", "count", v("negbin", "0.30"), "MASS", "glm.nb", 3.00 * canonical_scale),
	  	bench_row("InferenceTiny", "count", v("tiny", "0.01"), "stats", "x", 1.00 * canonical_scale),
	  	bench_row("InferenceNoCanonical", "ordinal", v("nocan", "NA"), "None", "", "NA")
	  )), "",
	  "### Wald Test Performance (Full Inference)", "",
	  bench_table(bench_row("InferenceContinOLS", "continuous", v("ols_wald", "0.50"), "stats", "lm+summary", 1.00 * canonical_scale)),
	  "",
	  "### Resampling-Based Inference Procedure Performance", "",
	  bench_table(bench_row("Randomization test p-value [R6 X]", "continuous", v("proc", "20.00"), "ri2", "conduct_ri", 100 * canonical_scale),
	              first = "Procedure"),
	  "",
	  "## Python Benchmarks", "", "_Generated: 2026-10-23 08:00:00 UTC_", "",
	  "### Point-Estimate Results (2 of 3 rows timed, 1 Baseline Gaps)", "",
	  "<table>",
	  "<thead><tr><th>Class</th><th>Response</th><th>EDI Time (ms)</th><th>Canonical Pkg</th><th>Canonical Func</th><th>Canonical Time (ms)</th><th>Speedup</th><th>Timing Pval</th><th></th></tr></thead>",
	  "<tbody>",
	  sprintf('<tr style="background-color: #d9fdd3;"><td>InferenceContinOLS</td><td>continuous</td><td>%s</td><td>numpy</td><td>linalg.lstsq</td><td>%.2f</td><td>6x</td><td>1e-5</td><td>***</td></tr>',
	          v("py_ols", "0.02"), 0.11 * canonical_scale),
	  "</tbody></table>", "",
	  "<style>", "  body {}", "</style>")
}

parse_md = function(...) parse_benchmark_report(synthetic_md(...), "benchmark_model_fits.md")

test_that("the parser keys rows by part, canonical section, label and comparator", {
	d = parse_md()
	expect_setequal(unique(d$part), c("R", "Python"))
	expect_setequal(unique(d$section), c("models", "wald", "procedures"))
	expect_identical(sum(d$part == "R" & d$section == "models"), 7L)
	# The Python heading's run-dependent count is stripped, so it maps to "models".
	expect_identical(d$section[d$part == "Python"], "models")
	glmm = d$key[grepl("GLMM", d$key)]
	expect_length(glmm, 2L)
	expect_true(any(grepl(" #2$", glmm)))
	expect_identical(length(unique(d$key)), nrow(d))
	ols = d[d$part == "R" & d$section == "models" & d$label == "InferenceContinOLS", ]
	expect_equal(ols$edi_ms, 0.10)
	expect_equal(ols$canonical_ms, 0.20)
	expect_identical(ols$canonical_func, "lm.fit")
	expect_true(is.na(d$edi_ms[d$label == "InferenceNoCanonical"]))
	ctx = attr(d, "context")
	expect_identical(ctx$R$edi_portable, "0")
	expect_identical(ctx$R$generated, "2026-10-23 10:00:00 IDT")
	expect_identical(ctx$Python$generated, "2026-10-23 08:00:00 UTC")
})

test_that("an HTML-only Python report defaults to the Python part via its file name", {
	html = c("<html><body>", "<h1>EDI Python benchmark</h1>",
	         "<h2 id=\"results\">Point-Estimate Results (1 of 1 rows timed, 0 Baseline Gaps)</h2>",
	         "<table><thead><tr><th>Class</th><th>Response</th><th>EDI Time (ms)</th><th>Canonical Pkg</th><th>Canonical Func</th><th>Canonical Time (ms)</th></tr></thead>",
	         "<tbody><tr><td><code>InferenceContinOLS</code></td><td>continuous</td><td>0.02</td><td>numpy</td><td>linalg.lstsq</td><td>0.11</td></tr></tbody></table>",
	         "<h2 id=\"wald\">Wald Test Performance / Full Inference (0 of 0 rows timed, 0 Baseline Gaps)</h2>",
	         "</body></html>")
	d = parse_benchmark_report(html, "python/benchmark/benchmark_model_fits_python.html")
	expect_identical(d$part, "Python")
	expect_identical(d$section, "models")
	expect_identical(d$label, "InferenceContinOLS")
	expect_identical(d$canonical_func, "linalg.lstsq")
	expect_identical(benchmark_compare_strip_html("<code>a &amp; b</code> &lt;c&gt;"), "a & b <c>")
	# Same row from the combined markdown matches the same key.
	md = parse_md()
	expect_true(d$key %in% md$key)
})

test_that("a report compared with itself has no regressions", {
	d = parse_md()
	res = compare_benchmark_reports(d, d)
	expect_identical(res$n_regressions, 0L)
	expect_identical(res$n_removed, 0L)
	expect_true(all(res$rows$status %in% c("ok", "na-both")))
	expect_equal(unname(res$host_factor), c(1, 1))
})

test_that("ratio and absolute floor must both be exceeded to flag a slowdown", {
	old = parse_md()
	new = parse_md(edi = list(
		logit = "2.60",   # 1.30x, +0.60 ms -> regression
		ols = "0.12",     # 1.20x -> below ratio
		tiny = "0.04",    # 4x but +0.03 ms -> below the 0.05 ms floor
		negbin = "0.10",  # 0.33x, -0.20 ms -> improved
		proc = "40.00",   # 2x, +20 ms -> regression
		ols_wald = "NA",  # had a time, now NA -> lost
		nocan = "5.00"    # was NA, now timed -> gained
	))
	res = compare_benchmark_reports(old, new)
	st = setNames(res$rows$status, paste(res$rows$part, res$rows$section, res$rows$label))
	expect_identical(st[["R models InferenceIncidLogRegr"]], "regression")
	expect_identical(st[["R models InferenceContinOLS"]], "ok")
	expect_identical(st[["R models InferenceTiny"]], "ok")
	expect_identical(st[["R models InferenceCountNegBin"]], "improved")
	expect_identical(st[["R procedures Randomization test p-value [R6 X]"]], "regression")
	expect_identical(st[["R wald InferenceContinOLS"]], "lost")
	expect_identical(st[["R models InferenceNoCanonical"]], "gained")
	expect_identical(res$n_regressions, 3L)
	expect_equal(res$rows$ratio[res$rows$label == "InferenceIncidLogRegr"], 1.3)

	# A zero floor flags the tiny row; a higher ratio spares the 1.30x row.
	expect_identical(compare_benchmark_reports(old, new, min_delta_ms = 0)$rows$status[
		res$rows$label == "InferenceTiny"], "regression")
	strict = compare_benchmark_reports(old, new, ratio = 1.5)
	expect_identical(strict$rows$status[strict$rows$label == "InferenceIncidLogRegr"], "ok")
	expect_identical(strict$n_regressions, 2L)

	# --sections / --part filters.
	expect_identical(compare_benchmark_reports(old, new, sections = "models")$n_regressions, 1L)
	expect_identical(compare_benchmark_reports(old, new, parts = "Python")$n_regressions, 0L)
})

test_that("allow patterns mark flagged rows as explained without failing", {
	old = parse_md()
	new = parse_md(edi = list(logit = "4.00", ols_wald = "NA"))
	res = compare_benchmark_reports(old, new, allow = c("IncidLogRegr", "^R \\| wald \\| InferenceContinOLS"))
	expect_identical(res$n_regressions, 0L)
	expect_identical(res$n_explained, 2L)
	expect_true(all(res$rows$explained[res$rows$status %in% c("regression", "lost")]))
	out = format_benchmark_comparison(res, old, new)
	expect_true(any(grepl("^regression\\*", out)))
	expect_match(out[length(out)], "^RESULT: PASS")
})

test_that("renamed rows are reported as removed and added", {
	old = parse_md()
	new_lines = sub("Randomization test p-value [R6 X]", "Randomization test p-value [R6 X, renamed]",
	                synthetic_md(), fixed = TRUE)
	new = parse_benchmark_report(new_lines, "benchmark_model_fits.md")
	res = compare_benchmark_reports(old, new)
	expect_identical(res$n_removed, 1L)
	expect_identical(sum(res$rows$status == "added"), 1L)
	expect_identical(res$n_regressions, 0L)
})

test_that("host normalization divides by the median canonical ratio", {
	old = parse_md()
	# Everything, canonical included, is 1.4x slower: a slower host, not a regression.
	slow = parse_md(edi = list(ols = "0.14", logit = "2.80", glmm1 = "1.40", glmm2 = "1.40",
	                           negbin = "0.42", tiny = "0.014", ols_wald = "0.70", proc = "28.00",
	                           py_ols = "0.028"),
	                canonical_scale = 1.4)
	raw = compare_benchmark_reports(old, slow)
	expect_gt(raw$n_regressions, 0L)
	norm = compare_benchmark_reports(old, slow, normalize_host = TRUE)
	expect_equal(unname(norm$host_factor[["R"]]), 1.4, tolerance = 1e-6)
	expect_identical(norm$n_regressions, 0L)
	expect_true(all(abs(norm$rows$adj_ratio[is.finite(norm$rows$adj_ratio)] - 1) < 0.05))
})

test_that("differing build flags are called out in the summary", {
	old = parse_md(portable = "0")
	new = parse_md(portable = "1")
	out = format_benchmark_comparison(compare_benchmark_reports(old, new), old, new)
	expect_true(any(grepl("WARNING: R build flags differ \\(EDI_PORTABLE 0 -> 1\\)", out)))
})

test_that("the committed benchmark reports parse and compare clean against themselves", {
	md_path = test_path("..", "..", "package_metadata", "benchmark_model_fits.md")
	r_html = test_path("..", "..", "package_metadata", "benchmark_model_fits_R.html")
	py_html = test_path("..", "..", "..", "python", "benchmark", "benchmark_model_fits_python.html")
	skip_if_not(file.exists(md_path))
	md = parse_benchmark_report(readLines(md_path, warn = FALSE), md_path)
	expect_gt(sum(md$part == "R" & md$section == "models"), 20L)
	expect_gt(sum(md$part == "R" & md$section == "wald"), 20L)
	expect_gt(sum(md$part == "Python"), 20L)
	expect_true(all(c("models", "wald", "utility", "procedures", "designs") %in% md$section[md$part == "R"]))
	expect_identical(length(unique(md$key)), nrow(md))
	expect_identical(compare_benchmark_reports(md, md)$n_regressions, 0L)
	if (file.exists(r_html)) {
		rh = parse_benchmark_report(readLines(r_html, warn = FALSE), r_html)
		expect_true(all(rh$part == "R"))
		expect_identical(compare_benchmark_reports(rh, rh)$n_regressions, 0L)
		# The R HTML and the combined markdown use the same row keys for the model tables.
		expect_true(all(rh$key[rh$section == "models"] %in% md$key))
	}
	if (file.exists(py_html)) {
		ph = parse_benchmark_report(readLines(py_html, warn = FALSE), py_html)
		expect_true(all(ph$part == "Python"))
		expect_identical(compare_benchmark_reports(ph, ph)$n_regressions, 0L)
		expect_true(all(ph$key %in% md$key))
	}
})

test_that("the command line exits 0 on a pass, 1 on a regression and 2 on bad input", {
	rscript = file.path(R.home("bin"), "Rscript")
	dir = tempfile("bench_compare_")
	dir.create(dir)
	on.exit(unlink(dir, recursive = TRUE), add = TRUE)
	old_f = file.path(dir, "old.md")
	new_f = file.path(dir, "new.md")
	tsv = file.path(dir, "rows.tsv")
	writeLines(synthetic_md(), old_f)
	writeLines(synthetic_md(edi = list(logit = "3.00")), new_f)
	run = function(...) {
		out = suppressWarnings(system2(rscript, c(shQuote(compare_script), ...), stdout = TRUE, stderr = TRUE))
		list(status = if (is.null(attr(out, "status"))) 0L else attr(out, "status"), out = out)
	}
	pass = run("--old", shQuote(old_f), "--new", shQuote(old_f))
	expect_identical(pass$status, 0L)
	expect_true(any(grepl("^RESULT: PASS", pass$out)))
	fail = run("--old", shQuote(old_f), "--new", shQuote(new_f), "--tsv", shQuote(tsv))
	expect_identical(fail$status, 1L)
	expect_true(any(grepl("^RESULT: REGRESSIONS FOUND", fail$out)))
	expect_true(file.exists(tsv))
	rows = utils::read.delim(tsv, stringsAsFactors = FALSE)
	expect_identical(rows$status[rows$label == "InferenceIncidLogRegr"], "regression")
	allowed = run("--old", shQuote(old_f), "--new", shQuote(new_f), "--allow=IncidLogRegr")
	expect_identical(allowed$status, 0L)
	expect_identical(run("--old", shQuote(old_f), "--ratio", "1.25")$status, 2L)
	expect_identical(run("--old", shQuote(old_f), "--new", shQuote(file.path(dir, "missing.md")))$status, 2L)
	expect_identical(run("--bogus")$status, 2L)
})
