find_compare_path_audits_repo_file <- function(path) {
	at <- normalizePath(getwd())
	repeat {
		candidate <- file.path(at, path)
		if (file.exists(candidate)) return(candidate)
		parent <- dirname(at)
		if (identical(parent, at)) break
		at <- parent
	}
	stop("cannot locate repository file: ", path)
}

load_compare_path_audits <- function() {
	env <- new.env(parent = globalenv())
	sys.source(find_compare_path_audits_repo_file(file.path("R", "package_tests", "compare_path_audits.R")), envir = env)
	env
}

# Minimal page shaped like path_audits_source.R's html_from_audit() output:
# 4 header rows (rowspan'd first two columns), a section row, a class whose
# name cell spans two formula rows, and an NTS cell merged over both rows.
synthetic_path_audit_html <- function(cells_row1, cells_row2, title = "Regression Procedures") {
	td <- function(title, text) sprintf('<td style="x" title="%s">%s</td>', title, text)
	paste0(
		"<html><body><h3 style=\"m\">", title, "</h3><table>",
		'<tr class="hdr0"><th rowspan="4">Inference Type</th><th rowspan="4" class="formula-col">Formula</th><th colspan="2">Asymptotic</th><th colspan="1">Exact</th></tr>',
		'<tr class="hdr1"><th colspan="2">Model-Based</th><th colspan="1">Randomization</th></tr>',
		'<tr class="hdr2"><th colspan="2">wald</th><th colspan="1">vanilla</th></tr>',
		'<tr class="hdr3"><th>pval</th><th>ci</th><th>ci</th></tr>',
		'<tr class="section-row"><td colspan="5"><span class="section-label">Continuous</span></td></tr>',
		'<tr><td rowspan="2" style="font-family:monospace">ContinFoo</td><td class="formula-col">~w</td>',
		paste(cells_row1, collapse = ""), "</tr>",
		'<tr><td class="formula-col">~w+.</td>', paste(cells_row2, collapse = ""), "</tr>",
		"</table><h2>&lt;1% Estimable Paths</h2><table><tbody><tr><td>x</td></tr></tbody></table></body></html>"
	)
}

pa_obs <- function(rate, k, n) sprintf(
	"Attempted, [95-100)%% estimable observed; observed approx estimable rate %.1f%%; explicit non-estimable rate %.1f%% (%d/%d rows)",
	100 * rate, 100 * (1 - rate), k, n)

testthat::test_that("path audit HTML parser honours colspan/rowspan and reads cell states and rates", {
	pa <- load_compare_path_audits()
	td <- function(title, text, extra = "") sprintf('<td style="x"%s title="%s">%s</td>', extra, title, text)
	html <- synthetic_path_audit_html(
		c(td(pa_obs(0.99, 1, 100), "[95-100)%"), td("Theoretically guaranteed by the comprehensive-test contract", "&#10003;"),
			td("Not theoretically supported by this model", "NTS", ' rowspan="2"')),
		c(td("Skipped or lightly tested in comprehensive tests because this path is too slow", "SLOW"),
			td("Attempted, empirical estimability unknown; no result rows found", "unknown"))
	)
	d <- pa$parse_path_audits_html(html)
	testthat::expect_identical(nrow(d), 6L)
	testthat::expect_true(all(d$class == "ContinFoo"))
	testthat::expect_true(all(d$section == "Continuous"))
	testthat::expect_true(all(d$table == "Regression Procedures"))
	testthat::expect_setequal(unique(d$column), c("Asymptotic > Model-Based > wald > pval",
		"Asymptotic > Model-Based > wald > ci", "Exact > Randomization > vanilla > ci"))
	get <- function(row, col) d[d$row_label == row & d$column == col, ]
	r1 <- get("~w", "Asymptotic > Model-Based > wald > pval")
	testthat::expect_identical(r1$state, "observed")
	testthat::expect_equal(r1$rate, 0.99)
	testthat::expect_identical(r1$nonestimable, 1L)
	testthat::expect_identical(r1$n, 100L)
	testthat::expect_identical(get("~w", "Asymptotic > Model-Based > wald > ci")$state, "guaranteed")
	# the rowspan'd NTS cell covers the second formula row too
	testthat::expect_identical(get("~w", "Exact > Randomization > vanilla > ci")$state, "nts")
	testthat::expect_identical(get("~w+.", "Exact > Randomization > vanilla > ci")$state, "nts")
	testthat::expect_identical(get("~w+.", "Asymptotic > Model-Based > wald > pval")$state, "slow")
	testthat::expect_identical(get("~w+.", "Asymptotic > Model-Based > wald > ci")$state, "unknown")
	testthat::expect_error(pa$parse_path_audits_html("<html><body>none</body></html>"), "no <table>")
})

testthat::test_that("cell comparison classifies every worse / improved transition", {
	pa <- load_compare_path_audits()
	mk <- function(column, state, rate = NA_real_, n = NA_integer_) data.frame(
		table = "T", section = "S", class = "ContinFoo", row_label = "~w", column = column, state = state,
		rate = rate, nonestimable = NA_integer_, n = as.integer(n), stringsAsFactors = FALSE)
	base <- rbind(
		mk("a", "observed", 0.99, 1000), mk("b", "observed", 0.99, 1000), mk("c", "observed", 0.99, 10),
		mk("d", "slow"), mk("e", "guaranteed"), mk("f", "observed", 0.5, 100), mk("g", "nts"),
		mk("h", "observed", 0.9, 100), mk("i", "nts"), mk("j", "observed", 0.30, 100), mk("k", "unknown"),
		mk("gone", "observed", 1, 100))
	new <- rbind(
		mk("a", "observed", 0.95, 1000), mk("b", "observed", 0.985, 1000), mk("c", "observed", 0.5, 10),
		mk("d", "nts"), mk("e", "observed", 1, 100), mk("f", "unknown"), mk("g", "observed", 1, 50),
		mk("h", "slow"), mk("i", "not_implemented"), mk("j", "observed", 0, 100), mk("k", "observed", 0.9, 40),
		mk("added", "observed", 1, 100))
	cmp <- pa$compare_path_audit_cells(base, new, rate_tol = 0.02, min_n = 30)
	kind <- setNames(cmp$kind, cmp$column)
	change <- setNames(cmp$change, cmp$column)
	testthat::expect_identical(unname(kind[c("a", "d", "e", "f", "h", "j", "gone")]),
		c("estimability_drop", "support_removed", "guarantee_lost", "lost_observations", "became_slow", "estimability_drop", "cell_removed"))
	testthat::expect_true(all(change[c("a", "d", "e", "f", "h", "j", "gone")] == "worse"))
	# within tolerance, or below min_n, is unchanged
	testthat::expect_identical(unname(change[c("b", "c")]), c("unchanged", "unchanged"))
	testthat::expect_identical(unname(kind[c("g", "k", "added")]), c("support_added", "gained_observations", "cell_added"))
	testthat::expect_true(all(change[c("g", "k", "added")] == "improved"))
	# unsupported -> differently-labelled unsupported never fails
	testthat::expect_identical(unname(change["i"]), "changed")
	rev <- pa$compare_path_audit_cells(new, base, rate_tol = 0.02, min_n = 30)
	testthat::expect_identical(rev$kind[rev$column == "d"], "support_added")
	testthat::expect_identical(rev$kind[rev$column == "h"], "slow_lifted")
	testthat::expect_identical(rev$kind[rev$column == "e"], "guarantee_gained")
})

testthat::test_that("defaults CSV comparison flags rate increases, removed rows and new design refusals", {
	pa <- load_compare_path_audits()
	base <- pa$read_path_audits_defaults(c(
		'"base_class","function_run","n","nonestimable","rate"',
		'"InferenceA","compute_x",100,1,0.01', '"InferenceA","compute_y",100,1,0.01',
		'"InferenceA","compute_z",100,50,0.5', '"InferenceB","compute_x",10,0,0',
		'"InferenceB","compute_gone",100,0,0', '"InferenceC","compute_r",100,0,0'))
	testthat::expect_false(any(base$design_refused))
	new <- pa$read_path_audits_defaults(c(
		'"base_class","function_run","n","nonestimable","rate","design_refused"',
		'"InferenceA","compute_x",100,10,0.1,FALSE', '"InferenceA","compute_y",100,2,0.02,FALSE',
		'"InferenceA","compute_z",100,10,0.1,FALSE', '"InferenceB","compute_x",10,10,1,FALSE',
		'"InferenceC","compute_r",0,0,NA,TRUE', '"InferenceD","compute_new",100,0,0,FALSE'))
	cmp <- pa$compare_path_audit_defaults(base, new, rate_tol = 0.02, min_n = 30)
	k <- setNames(cmp$kind, paste(cmp$class, cmp$column))
	testthat::expect_identical(unname(k["InferenceA compute_x"]), "nonestimable_rate_up")
	testthat::expect_identical(unname(k["InferenceA compute_y"]), "")
	testthat::expect_identical(unname(k["InferenceA compute_z"]), "nonestimable_rate_down")
	# below min_n but newly 100% nonestimable still fails
	testthat::expect_identical(unname(k["InferenceB compute_x"]), "nonestimable_rate_up")
	testthat::expect_identical(unname(k["InferenceB compute_gone"]), "row_removed")
	testthat::expect_identical(unname(k["InferenceC compute_r"]), "became_design_refused")
	testthat::expect_identical(unname(k["InferenceD compute_new"]), "row_added")
	testthat::expect_error(pa$read_path_audits_defaults(c('"base_class","n"', '"A",1')), "lacks columns")
})

testthat::test_that("allowlist matching respects source, kinds, regexes and the Inference prefix", {
	pa <- load_compare_path_audits()
	f <- tempfile(fileext = ".csv")
	on.exit(unlink(f), add = TRUE)
	writeLines(c(
		"id,source,class_regex,row_regex,column_regex,kinds,tracked_in,reason",
		"rows_only,cells,.+,^Incidence$,^col_ci$,support_removed,TODO-1,cells only",
		"cls_any,*,^ContinFoo$,^Nope$,^(col_ci|compute_ci)$,support_removed|nonestimable_rate_up,TODO-2,both sources"
	), f)
	allow <- pa$read_path_audit_allowlist(f)
	cells <- data.frame(class = c("AllSimpleX", "AllSimpleX", "ContinFoo", "ContinFoo"),
		row_label = c("Incidence", "Count", "~w", "~w"), column = c("col_ci", "col_ci", "col_ci", "col_pval"),
		change = "worse", kind = c("support_removed", "support_removed", "support_removed", "support_removed"),
		stringsAsFactors = FALSE)
	ac <- pa$apply_path_audit_allowlist(cells, allow, "cells")
	# row_regex applies to cells: ContinFoo's ~w row does not match ^Nope$
	testthat::expect_identical(ac$cmp$allowlisted, c("rows_only", "", "", ""))
	defs <- data.frame(class = c("InferenceContinFoo", "InferenceAllSimpleX", "InferenceContinFoo"), row_label = "",
		column = c("compute_ci", "compute_ci", "compute_ci"), change = "worse",
		kind = c("nonestimable_rate_up", "nonestimable_rate_up", "row_removed"), stringsAsFactors = FALSE)
	ad <- pa$apply_path_audit_allowlist(defs, allow, "defaults")
	# defaults: row_regex ignored, "Inference" prefix stripped, cells-only entry skipped, kind must match
	testthat::expect_identical(ad$cmp$allowlisted, c("cls_any", "", ""))
	testthat::expect_identical(ad$used, "cls_any")
	writeLines(c("id,source,class_regex,row_regex,column_regex,kinds,tracked_in,reason",
		"blank,*,,,.+,*,TODO-1,no class regex"), f)
	testthat::expect_error(pa$read_path_audit_allowlist(f), "non-empty class_regex")
})

testthat::test_that("checked-in allowlist is well formed and every entry names a TODO or NEWS source", {
	pa <- load_compare_path_audits()
	allow <- pa$read_path_audit_allowlist(find_compare_path_audits_repo_file(
		file.path("R", "package_tests", "path_audits_regression_allowlist.csv")))
	testthat::expect_gt(nrow(allow), 10L)
	testthat::expect_true(all(grepl("^(release_v1_0_5\\.md:TODO-[0-9]+|NEWS\\.md:1\\.0\\.5)$", allow$tracked_in)))
	known_kinds <- c("support_removed", "cell_removed", "guarantee_lost", "became_slow", "lost_observations",
		"estimability_drop", "row_removed", "became_design_refused", "nonestimable_rate_up")
	for (i in seq_len(nrow(allow))) {
		for (rx in c(allow$class_regex[i], allow$row_regex[i], allow$column_regex[i])) {
			if (nzchar(rx)) testthat::expect_silent(grepl(rx, "x", perl = TRUE))
		}
		kinds <- strsplit(allow$kinds[i], "|", fixed = TRUE)[[1L]]
		testthat::expect_true(all(kinds %in% c("*", known_kinds)), info = allow$id[i])
		# a counting-rule-change row may only excuse rate moves (enforced by the
		# reader too) and only while the baseline's counting rule differs
		if (nzchar(allow$counting_rule_change[i])) {
			testthat::expect_true(all(kinds %in% c("estimability_drop", "nonestimable_rate_up")), info = allow$id[i])
			next
		}
		# a broad class regex must be confined by row_regex, which only cells honour
		if (allow$class_regex[i] %in% c(".+", ".*", ".")) {
			testthat::expect_identical(allow$source[i], "cells", info = allow$id[i])
			testthat::expect_true(nzchar(allow$row_regex[i]), info = allow$id[i])
		}
	}
	# every rand-CI refusal entry matches the real column label and function_run spelling
	rand_ci <- allow[grepl("^todo119_", allow$id), ]
	testthat::expect_true(all(vapply(rand_ci$column_regex, grepl, logical(1), x = "Exact > Randomization > vanilla > ci", perl = TRUE)))
	no_fn <- rand_ci$source == "cells"
	testthat::expect_true(all(vapply(rand_ci$column_regex[!no_fn], grepl, logical(1), x = "compute_rand_confidence_interval", perl = TRUE)))
})

testthat::test_that("counting_rule_change allowlist rows apply only across a counting-rule change and only to rate kinds", {
	pa <- load_compare_path_audits()
	testthat::expect_identical(pa$pa_html_counting_rule("<html><head><meta charset=\"utf-8\"></head></html>"), "pre-2026-10-23")
	testthat::expect_identical(pa$pa_html_counting_rule("<html><head>\n  <!-- edi-path-audit-counting-rule: 2026-10-23 -->\n<title>x</title>"), "2026-10-23")
	testthat::expect_identical(pa$pa_defaults_counting_rule(c('"base_class","function_run","n","nonestimable","rate"', '"A","f",1,0,0')), "pre-2026-10-23")
	testthat::expect_identical(pa$pa_defaults_counting_rule(c('"base_class","function_run","n","nonestimable","rate","design_refused","counting_rule"',
		'"A","f",1,0,0,FALSE,"2026-10-23"')), "2026-10-23")
	f <- tempfile(fileext = ".csv")
	on.exit(unlink(f), add = TRUE)
	writeLines(c(
		"id,source,class_regex,row_regex,column_regex,kinds,tracked_in,reason,counting_rule_change",
		"specific,cells,^ContinFoo$,,^col_a$,support_removed,TODO-1,specific,",
		"rule,*,.+,,.+,estimability_drop|nonestimable_rate_up,TODO-2,rule change,2026-10-23"
	), f)
	allow <- pa$read_path_audit_allowlist(f)
	cells <- data.frame(class = "ContinFoo", row_label = "~w", column = c("col_a", "col_b", "col_c"), change = "worse",
		kind = c("support_removed", "estimability_drop", "support_removed"), stringsAsFactors = FALSE)
	same <- pa$apply_path_audit_allowlist(cells, allow, "cells", NULL)
	testthat::expect_identical(same$cmp$allowlisted, c("specific", "", ""))
	changed <- pa$apply_path_audit_allowlist(cells, allow, "cells", "2026-10-23")
	# the rule row excuses only the rate drop, never a support removal
	testthat::expect_identical(changed$cmp$allowlisted, c("specific", "rule", ""))
	other <- pa$apply_path_audit_allowlist(cells, allow, "cells", "2099-01-01")
	testthat::expect_identical(other$cmp$allowlisted, c("specific", "", ""))
	defs <- data.frame(class = "InferenceContinFoo", row_label = "", column = "compute_x", change = "worse",
		kind = "nonestimable_rate_up", stringsAsFactors = FALSE)
	testthat::expect_identical(pa$apply_path_audit_allowlist(defs, allow, "defaults", "2026-10-23")$cmp$allowlisted, "rule")
	testthat::expect_identical(pa$apply_path_audit_allowlist(defs, allow, "defaults", NULL)$cmp$allowlisted, "")
	writeLines(c("id,source,class_regex,row_regex,column_regex,kinds,tracked_in,reason,counting_rule_change",
		"bad,*,.+,,.+,support_removed,TODO-1,too broad,2026-10-23"), f)
	testthat::expect_error(pa$read_path_audit_allowlist(f), "rate kinds")
})

testthat::test_that("CLI exits 0 on allowlisted-only worsening, 1 otherwise, 2 on bad input", {
	script <- find_compare_path_audits_repo_file(file.path("R", "package_tests", "compare_path_audits.R"))
	root <- tempfile("edi-compare-path-audits-")
	dir.create(file.path(root, "base"), recursive = TRUE)
	dir.create(file.path(root, "new"))
	on.exit(unlink(root, recursive = TRUE), add = TRUE)
	td <- function(title, text) sprintf('<td style="x" title="%s">%s</td>', title, text)
	ok <- td(pa_obs(1, 0, 100), "100%")
	nts <- td("Not theoretically supported by this model", "NTS")
	writeLines(synthetic_path_audit_html(c(ok, ok, ok), c(ok, ok, ok)), file.path(root, "base", "path_audits.html"))
	writeLines(synthetic_path_audit_html(c(ok, ok, nts), c(ok, ok, ok)), file.path(root, "new", "path_audits.html"))
	csv <- c('"base_class","function_run","n","nonestimable","rate"', '"InferenceContinFoo","compute_x",100,0,0')
	writeLines(csv, file.path(root, "base", "path_audits_nonestimability_defaults.csv"))
	writeLines(csv, file.path(root, "new", "path_audits_nonestimability_defaults.csv"))
	allow <- file.path(root, "allow.csv")
	none <- file.path(root, "none.csv")
	writeLines(c("id,source,class_regex,row_regex,column_regex,kinds,tracked_in,reason",
		"x,cells,^ContinFoo$,^~w$,^Exact > Randomization > vanilla > ci$,support_removed,TODO-1,test"), allow)
	writeLines("id,source,class_regex,row_regex,column_regex,kinds,tracked_in,reason", none)
	rscript <- file.path(R.home("bin"), "Rscript")
	run <- function(...) {
		out <- suppressWarnings(system2(rscript, c(shQuote(script), ...), stdout = TRUE, stderr = TRUE))
		list(status = if (is.null(attr(out, "status"))) 0L else attr(out, "status"), out = out)
	}
	base_args <- c("--baseline-dir", shQuote(file.path(root, "base")), "--new-dir", shQuote(file.path(root, "new")))
	r_ok <- run(base_args, "--allowlist", shQuote(allow), "--out-dir", shQuote(file.path(root, "out")))
	testthat::expect_identical(r_ok$status, 0L)
	testthat::expect_true(any(grepl("RESULT: PASS", r_ok$out, fixed = TRUE)))
	written <- utils::read.csv(file.path(root, "out", "path_audits_compare_cells.csv"), stringsAsFactors = FALSE)
	testthat::expect_identical(written$allowlisted, "x")
	r_bad <- run(base_args, "--allowlist", shQuote(none))
	testthat::expect_identical(r_bad$status, 1L)
	testthat::expect_true(any(grepl("support_removed", r_bad$out, fixed = TRUE)))
	testthat::expect_identical(run("--no-such-flag")$status, 2L)
	testthat::expect_identical(run("--baseline-dir", shQuote(file.path(root, "missing")), "--new-dir", shQuote(file.path(root, "new")))$status, 2L)
})

testthat::test_that("committed path audit compared with itself has no change", {
	testthat::skip_if(Sys.which("git") == "", "git is required to read the committed baseline")
	html_path <- find_compare_path_audits_repo_file(file.path("R", "package_tests", "path_audits.html"))
	here <- dirname(html_path)
	repo <- tryCatch(system2("git", c("-C", here, "rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE),
		warning = function(w) character(), error = function(e) character())
	testthat::skip_if(!length(repo), "not inside a git checkout")
	shown <- suppressWarnings(system2("git", c("-C", repo, "show", "HEAD:R/package_tests/path_audits.html"), stdout = TRUE, stderr = FALSE))
	testthat::skip_if(!is.null(attr(shown, "status")), "path_audits.html is not committed at HEAD")
	pa <- load_compare_path_audits()
	base <- pa$parse_path_audits_html(shown)
	testthat::expect_gt(nrow(base), 1000L)
	testthat::expect_setequal(unique(base$table), c("Non-Regression Procedures", "Regression Procedures"))
	testthat::expect_false(any(grepl("^other:|^blank$", base$state)))
	testthat::expect_true("Exact > Randomization > vanilla > ci" %in% base$column)
	cmp <- pa$compare_path_audit_cells(base, base)
	testthat::expect_true(all(cmp$change == "unchanged"))
	csv <- suppressWarnings(system2("git", c("-C", repo, "show", "HEAD:R/package_tests/path_audits_nonestimability_defaults.csv"), stdout = TRUE, stderr = FALSE))
	d <- pa$read_path_audits_defaults(csv)
	testthat::expect_gt(nrow(d), 1000L)
	testthat::expect_true(all(pa$compare_path_audit_defaults(d, d)$change == "unchanged"))
})

# load_nonestimability_stats() and its row classifier live in
# path_audits_source.R, whose top level renders the whole audit (it needs the
# installed EDI). Evaluate only the definitions this test needs.
load_path_audit_counting <- function() {
	src <- find_compare_path_audits_repo_file(file.path("R", "package_tests", "path_audits_source.R"))
	exprs <- parse(src, keep.source = FALSE)
	want <- c("PATH_AUDIT_COUNTING_RULE", "PATH_AUDIT_REFUSAL_MESSAGE_RE", "classify_nonestimability_rows", "load_nonestimability_stats")
	env <- new.env(parent = globalenv())
	for (e in exprs) {
		if (is.call(e) && (identical(e[[1L]], as.name("=")) || identical(e[[1L]], as.name("<-"))) &&
			is.name(e[[2L]]) && as.character(e[[2L]]) %in% want) eval(e, env)
	}
	testthat::expect_true(all(vapply(want, exists, logical(1), envir = env, inherits = FALSE)))
	env
}

testthat::test_that("load_nonestimability_stats counts unflagged NA results as non-estimable but not refusals or skips", {
	testthat::skip_if_not_installed("data.table")
	pc <- load_path_audit_counting()
	dir <- tempfile("edi-path-audit-counting-")
	dir.create(dir)
	on.exit(unlink(dir, recursive = TRUE), add = TRUE)
	ci <- "compute_bootstrap_confidence_interval"
	pv <- "compute_bootstrap_two_sided_pval"
	cls <- "InferenceContinFoo (model_formula=~x)"
	row <- function(fn, status, r1, r2, msg, klass = cls) data.frame(function_run = fn, inference_class = klass,
		result_1 = r1, result_2 = r2, error_message = msg, status = status, stringsAsFactors = FALSE)
	rows <- rbind(
		row(ci, "ok", -0.3, 0.4, NA),                                                           # finite: estimable
		row(ci, "ok", NA, NA, paste0("Invalid output detected (NA/NaN/Inf) in ", ci)),         # TODO-116 NA: FAILED (new)
		row(ci, "ok", NA, NA, paste0("Explicitly non-estimable in ", ci, "; stage=se; reason=x")), # FAILED
		row(ci, "error", NA, NA, "boom"),                                                      # FAILED
		row(ci, "error", NA, NA, "This method is not supported for DesignSeqOneByOne designs."), # out of n
		row(ci, "ok", NA, NA, "Randomization confidence intervals are not supported for InferenceContinFoo due to x"), # refusal
		row(ci, "ok", NA, NA, "Skipped due to timeout after 60 seconds"),                      # skip
		row(ci, "ok", NA, NA, "Skipping InferenceIncidExactBinomial: design has no realized matched pairs."), # skip
		row(ci, "ok", NA, NA, paste0("Truth-based anomaly filter in ", ci)),                   # accuracy filter, not NA output
		row(ci, "ok", NA, NA, "InferenceContinFoo must implement get_standard_error() to support Wald-type inference"), # refusal
		row(ci, "ok", NA, NA, NA),                                                             # bare NA: FAILED (fallback)
		row(ci, "ok", -0.3, NA, ""),                                                           # half a CI: FAILED
		row(ci, "ok", NA, NA, paste0("Degenerate confidence interval [0, 0] detected in ", ci)), # FAILED
		row(pv, "ok", 0.2, NA, NA),                                                            # scalar: result_2 NA is fine
		row(pv, "ok", NA, NA, "Allowed missing output: ordinal asymptotic p-value not estimable"), # FAILED
		row(pv, "ok", NA, NA, "Weibull regression failed to converge")                         # numerical non-fatal: FAILED
	)
	utils::write.csv(rows, file.path(dir, "comprehensive_tests_results_nc_1_continuous.csv"), row.names = FALSE)
	# focused runs are never pooled
	utils::write.csv(row(ci, "ok", NA, NA, "Invalid output detected (NA/NaN/Inf)"),
		file.path(dir, "comprehensive_tests_results_nc_1_continuous_filtered_rep-1.csv"), row.names = FALSE)
	# a larger snapshot written under the old rule (no counting_rule column)
	defaults <- file.path(dir, "path_audits_nonestimability_defaults.csv")
	writeLines(c('"base_class","function_run","n","nonestimable","rate","design_refused"',
		'"InferenceContinFoo","compute_bootstrap_confidence_interval",1000,0,0,FALSE'), defaults)
	st <- pc$load_nonestimability_stats(dir)
	got <- get("InferenceContinFoo||compute_bootstrap_confidence_interval", envir = st)
	testthat::expect_identical(got$n, 12L)
	testthat::expect_identical(got$nonestimable, 6L)
	testthat::expect_equal(got$rate, 6 / 12)
	testthat::expect_false(got$design_refused)
	got_pv <- get("InferenceContinFoo||compute_bootstrap_two_sided_pval", envir = st)
	testthat::expect_identical(c(got_pv$n, got_pv$nonestimable), c(3L, 2L))
	# formula-scoped key uses the same rule
	got_f <- get("InferenceContinFoo||~x||compute_bootstrap_confidence_interval", envir = st)
	testthat::expect_identical(c(got_f$n, got_f$nonestimable), c(12L, 6L))
	# an old-rule snapshot is replaced even though its row count was larger
	d <- utils::read.csv(defaults, stringsAsFactors = FALSE)
	testthat::expect_true(all(d$counting_rule == pc$PATH_AUDIT_COUNTING_RULE))
	testthat::expect_identical(d$n[d$function_run == ci], 12L)
	# same rule: the high-water mark holds again (a larger same-rule snapshot is kept)
	d$n[d$function_run == ci] <- 5000L
	utils::write.csv(d, defaults, row.names = FALSE)
	pc$load_nonestimability_stats(dir)
	testthat::expect_identical(utils::read.csv(defaults, stringsAsFactors = FALSE)$n[d$function_run == ci], 5000L)
	# classifier directly: refusal rows are flagged, never failed
	dt <- data.table::as.data.table(rows)
	pc$classify_nonestimability_rows(dt)
	testthat::expect_false(any(dt$failed_row & dt$refused_row))
	testthat::expect_identical(sum(dt$refused_row), 5L)
	testthat::expect_identical(sum(dt$design_refused_row), 1L)
})
