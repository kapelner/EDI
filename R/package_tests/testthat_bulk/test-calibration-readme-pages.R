library(testthat)

# v1.0.5 TODO-201: render_calibration_study_readme.R writes each campaign's README.md as a short
# master page plus generated sub-pages (failing cells per response type, screen flags, bias,
# designs, convergence, figures per response type, data, about). Every sub-page starts and ends with
# a link back to README.md; every link in the master resolves to a generated file; relative links
# only. Synthetic campaign; no EDI needed (the analyze job has none). With
# EDI_CAL_PUBLISHED_CAMPAIGN_DIR set to a published campaign directory (its stats/ is re-analysed
# into scratch) the last test renders that one.

page_repo_dir = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		d = file.path(dir, "R", "package_tests", "calibration")
		if (file.exists(file.path(d, "render_calibration_study_readme.R"))) return(d)
		dir = dirname(dir)
	}
	NA_character_
}
cal_dir = page_repo_dir()
skip_if(is.na(cal_dir), "calibration scripts not found")
rscript = file.path(R.home("bin"), "Rscript")
run_script = function(script, ...) suppressWarnings(system2(rscript, c(shQuote(file.path(cal_dir, script)), ...), stdout = TRUE, stderr = TRUE))

# A results tree with one campaign: failing cells in two response types, a figures fragment, a status.
synthetic_campaign = function(final = FALSE) {
	root = tempfile("calpages")
	cdir = file.path(root, "campaigns", "2026-11-10-abcd1234")
	dir.create(file.path(cdir, "stats"), recursive = TRUE)
	env = new.env()
	sys.source(file.path(cal_dir, "calibration_study_stats.R"), envir = env)
	u = env$cal_stats_u_cols()
	spec = data.frame(response_type = c("continuous", "incidence", "incidence"), inf_class = c("InferenceContinLin", "InferenceIncidLogit", "InferenceIncidLogit"),
		inf_procedure = c("rand", "rand", "wald"), stringsAsFactors = FALSE)
	tests = cbind(spec, design = "DesignFixedBernoulli", prob_T = 0.5, formula = "~.", n = 50, n_nominal = 50, effect_label = "null",
		stage = "screen", reps = 3000L, n_p = 3000L, rej = c(300L, 300L, 100L), rej10 = 300L, n_ci = 3000L, cov = c(2700L, 2700L, 2900L), fit_secs = 1)
	tests[u] = lapply(seq_along(u), function(j) 0L)
	est = unique(cbind(tests[c("response_type", "design", "prob_T", "inf_class", "formula", "n", "n_nominal", "effect_label", "stage")],
		null_value = 0, estimand_true = 0, reps = 3000L, n_est = 3000L, n_below = 1500L, n_above = 1500L, sum_d = 0, sum_d2 = 3000))
	utils::write.csv(tests, gzfile(file.path(cdir, "stats", "tests.csv.gz")), row.names = FALSE)
	utils::write.csv(est, gzfile(file.path(cdir, "stats", "est.csv.gz")), row.names = FALSE)
	writeLines(c("SHA=0123456789abcdef0123456789abcdef01234567", "STARTED=2026-11-10T00:00Z", "ANALYSIS_SHA=fedcba9876543210fedcba9876543210fedcba98"), file.path(cdir, "campaign.env"))
	writeLines(if (final) "complete" else "running", file.path(cdir, "status.txt"))
	writeLines("12345", file.path(cdir, "runs.txt"))
	writeLines(c("### Null treatment effect (beta_T = 0)", "", "#### Continuous", "", "<picture>c</picture>", "", "#### Incidence", "", "<picture>i</picture>", "",
		"### Non-null treatment effect (beta_T != 0)", "", "No power cells.", ""), file.path(cdir, "figures.md"))
	args = c("--stats-dir", shQuote(file.path(cdir, "stats")), "--out-dir", shQuote(file.path(cdir, "summary")), if (final) "--final")
	expect_null(attr(run_script("convergence_calibration_study.R", args[1:4]), "status"))
	expect_null(attr(run_script("analyze_calibration_study.R", args), "status"))
	list(root = root, cdir = cdir)
}
render = function(cc, id = "2026-11-10-abcd1234") {
	res = run_script("render_calibration_study_readme.R", "--results-dir", shQuote(cc$root), "--campaign", id, "--repo", "owner/repo", "--progress", shQuote("Progress: test"))
	expect_null(attr(res, "status"), info = paste(res, collapse = "\n"))
}
check_pages = function(cdir, id = "2026-11-10-abcd1234") {
	master = readLines(file.path(cdir, "README.md"))
	back = sprintf("[← Campaign %s summary](README.md)", id)
	md_links = function(x) {
		m = regmatches(x, gregexpr("\\]\\(([^)]+)\\)", x))
		sub("^\\]\\((.*)\\)$", "\\1", unlist(m))
	}
	toc = unique(md_links(master))
	toc_local = toc[!grepl("^https?://", toc)]
	# Every master link resolves to a generated file; relative links only (no absolute path or branch URL to a page).
	expect_true(all(file.exists(file.path(cdir, toc_local))), info = paste(toc_local[!file.exists(file.path(cdir, toc_local))], collapse = ", "))
	expect_false(any(grepl("^/", toc_local)))
	pages = setdiff(toc_local[grepl("\\.md$", toc_local)], "README.md")
	expect_gte(length(pages), 18L)   # 6 failing + flags + 3 bias / designs / convergence + 6 figures + data + about
	for (pg in pages) {
		x = readLines(file.path(cdir, pg))
		expect_identical(x[[1L]], back, info = pg)
		expect_identical(x[[length(x)]], back, info = pg)
		# No runs of blank lines (absent optional paragraphs must not leave gaps).
		blank = !nzchar(trimws(x))
		expect_false(any(blank[-1L] & blank[-length(x)]), info = pg)
		# Every link in a sub-page that is not http(s) or an anchor resolves too.
		l = unique(md_links(x))
		l = l[!grepl("^(https?:|#)", l)]
		expect_true(all(file.exists(file.path(cdir, sub("#.*$", "", l)))), info = pg)
	}
	mb = !nzchar(trimws(master))
	expect_false(any(mb[-1L] & mb[-length(master)]), info = "README.md")
	list(master = master, pages = pages)
}

test_that("the campaign README is a short master with every sub-page linked, each with back-links at both ends", {
	cc = synthetic_campaign()
	render(cc)
	r = check_pages(cc$cdir)
	expect_lt(length(r$master), 80L)
	for (f in c("failing-continuous.md", "failing-incidence.md", "failing-count.md", "failing-proportion.md", "failing-survival.md", "failing-ordinal.md",
		"flags.md", "null-bias.md", "nonnull.md", "designs.md", "convergence.md", "figures-continuous.md", "figures-ordinal.md", "data.md", "about.md"))
		expect_true(f %in% r$pages, info = f)
	# The display order of the response types.
	idx = vapply(c("failing-continuous.md", "failing-incidence.md", "failing-count.md", "failing-proportion.md", "failing-survival.md", "failing-ordinal.md"),
		function(f) grep(f, r$master, fixed = TRUE)[1L], integer(1L))
	expect_identical(order(idx), 1:6)
	# Both commits and the red-X meaning are on the master.
	expect_true(any(grepl("Simulated at EDI commit", r$master)) && any(grepl("analysed at", r$master)))
	expect_true(any(grepl("Gate verdict", r$master, fixed = TRUE)))
})

test_that("failing cells are split by response type and add up to the gate's count", {
	cc = synthetic_campaign(final = FALSE)
	render(cc)
	n_fail = as.integer(readLines(file.path(cc$cdir, "summary", "gate_failures.txt")))
	count_rows = function(f) sum(grepl("^\\| (continuous|incidence|count|proportion|survival|ordinal) \\|", readLines(file.path(cc$cdir, f))))
	per = c(continuous = count_rows("failing-continuous.md"), incidence = count_rows("failing-incidence.md"), count = count_rows("failing-count.md"))
	expect_equal(sum(per), n_fail)
	expect_equal(per[["continuous"]], 1L)
	expect_equal(per[["incidence"]], 1L)
	expect_equal(per[["count"]], 0L)
	# Figures are regrouped by response type, with the section headings kept.
	fc = readLines(file.path(cc$cdir, "figures-continuous.md"))
	expect_true(any(grepl("<picture>c</picture>", fc, fixed = TRUE)))
	expect_false(any(grepl("<picture>i</picture>", fc, fixed = TRUE)))
	expect_true(any(grepl("^### Null treatment effect", fc)))
})

test_that("the branch's top-level README links each campaign's master", {
	cc = synthetic_campaign()
	render(cc)
	top = readLines(file.path(cc$root, "README.md"))
	expect_true(any(grepl("(campaigns/2026-11-10-abcd1234/README.md)", top, fixed = TRUE)))
})

test_that("a published campaign renders into scratch with all links resolving", {
	src = Sys.getenv("EDI_CAL_PUBLISHED_CAMPAIGN_DIR")
	skip_if(!nzchar(src) || !dir.exists(src), "EDI_CAL_PUBLISHED_CAMPAIGN_DIR not set")
	id = basename(src)
	root = tempfile("calpub")
	cdir = file.path(root, "campaigns", id)
	dir.create(cdir, recursive = TRUE)
	file.copy(file.path(src, c("stats", "campaign.env", "status.txt", "runs.txt", "figures.md", "figures")), cdir, recursive = TRUE)
	expect_null(attr(run_script("convergence_calibration_study.R", "--stats-dir", shQuote(file.path(cdir, "stats")), "--out-dir", shQuote(file.path(cdir, "summary"))), "status"))
	expect_null(attr(run_script("analyze_calibration_study.R", "--stats-dir", shQuote(file.path(cdir, "stats")), "--out-dir", shQuote(file.path(cdir, "summary"))), "status"))
	render(list(root = root), id)
	check_pages(cdir, id)
})
