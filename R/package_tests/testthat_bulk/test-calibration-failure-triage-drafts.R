library(testthat)

# Calibration failure triage (owner request 2026-11-12): analyze_calibration_study.R writes summary/triage.csv, the
# failing cells grouped by response type x class x procedure x metric (calibration_study_triage.R), and
# triage_calibration_study.R drafts one release-plan TODO per group not already covered by an open TODO or an
# accepted row. Synthetic summaries; no EDI needed.

triage_repo_dir = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		d = file.path(dir, "R", "package_tests", "calibration")
		if (file.exists(file.path(d, "calibration_study_triage.R"))) return(d)
		dir = dirname(dir)
	}
	NA_character_
}
cal_dir = triage_repo_dir()
skip_if(is.na(cal_dir), "calibration scripts not found")
rscript = file.path(R.home("bin"), "Rscript")
tenv = new.env()
sys.source(file.path(cal_dir, "calibration_study_triage.R"), envir = tenv)

# calibration_summary.csv rows: one per (class, procedure, design, n), with the columns triage reads.
srow = function(cls, proc, design, n, size, fail_size = FALSE, coverage = 0.95, fail_coverage = FALSE, regime = "asymptotic",
	size_null = 0.05, coverage_null = 0.95, prob_T = 0.5, formula = "~.")
	data.frame(response_type = "continuous", design = design, prob_T = prob_T, inf_class = cls, formula = formula, n = n,
		n_nominal = n, inf_procedure = proc, n_p = 1000L, n_ci = 1000L, size = size, size_null = size_null, rule_size = "rate",
		coverage = coverage, coverage_null = coverage_null, rule_coverage = "rate", regime = regime, accepted = "",
		fail_size = fail_size, fail_coverage = fail_coverage, stringsAsFactors = FALSE)

synthetic_summary = function() {
	d = tempfile("triage")
	dir.create(d)
	s = rbind(
		# A finite-sample rand failing at n = 50 only, on two designs: a bug whatever n.
		srow("InferenceContinA", "rand", "DesignFixedBernoulli", 50, 0.08, TRUE, regime = "finite_sample"),
		srow("InferenceContinA", "rand", "DesignSeqOneByOneKK21", 50, 0.09, TRUE, regime = "finite_sample"),
		srow("InferenceContinA", "rand", "DesignFixedBernoulli", 1000, 0.05, regime = "finite_sample"),
		# Asymptotic wald failing at n = 50 only, passing at 1000: small sample.
		srow("InferenceContinB", "wald", "DesignFixedBernoulli", 50, 0.15, TRUE, size_null = 0.1),
		srow("InferenceContinB", "wald", "DesignFixedBernoulli", 1000, 0.052),
		# Asymptotic wald failing at the largest n: a bug; coverage fails too (its own group).
		srow("InferenceContinC", "wald", "DesignFixedBernoulli", 1000, 0.09, TRUE, coverage = 0.9, fail_coverage = TRUE),
		srow("InferenceContinC", "wald", "DesignFixedBernoulli", 50, 0.06))
	utils::write.csv(s, file.path(d, "calibration_summary.csv"), row.names = FALSE)
	utils::write.csv(data.frame(response_type = "continuous", design = "DesignFixedBernoulli", prob_T = 0.5, inf_class = "InferenceContinA",
		formula = "~.", n = 50, inf_procedure = "rand", effect_label = "null", metric = "size", status = "fail (confirmed)"),
		file.path(d, "confirmation_summary.csv"), row.names = FALSE)
	# Bias at the largest n on one design (not drafted) for class B.
	utils::write.csv(data.frame(response_type = "continuous", design = "DesignFixedBernoulli", prob_T = 0.5, inf_class = "InferenceContinB",
		formula = "~.", n = 1000, n_nominal = 1000, n_est = 1000L, null_bias_std = 0.2, bias_sd_large_n = TRUE),
		file.path(d, "null_bias_summary.csv"), row.names = FALSE)
	d
}

test_that("failing cells group by class x procedure x metric with pattern, category and the worst cell", {
	tr = tenv$cal_triage_groups(synthetic_summary(), max_n = 1000, final = TRUE)
	expect_setequal(tr$group_id, c("continuous/ContinA/rand/size", "continuous/ContinB/wald/size", "continuous/ContinC/wald/size",
		"continuous/ContinC/wald/coverage", "continuous/ContinB/estimate/bias"))
	g = function(id) tr[tr$group_id == id, ]
	a = g("continuous/ContinA/rand/size")
	expect_equal(a$category, "bug")
	expect_equal(a$suggested_release, "current")
	expect_equal(a$n_cells, 2L)
	expect_equal(a$n_designs, 2L)
	expect_equal(a$n_confirmed, 1L)
	expect_equal(a$failing_ns, "50")
	expect_equal(a$tested_ns, "50;1000")
	expect_match(a$worst_cell, "^KK21, ~\\., n = 50, null: size 0\\.09 vs level 0\\.05$")
	expect_match(a$repro, "--design 'DesignSeqOneByOneKK21' --n 50 --effect null --only InferenceContinA", fixed = TRUE)
	b = g("continuous/ContinB/wald/size")
	expect_equal(b$category, "small_sample")
	expect_equal(b$suggested_release, "next")
	expect_match(b$pattern, "^small n only")
	expect_equal(g("continuous/ContinC/wald/size")$category, "bug")
	expect_match(g("continuous/ContinC/wald/size")$pattern, "^persistent")
	expect_equal(g("continuous/ContinC/wald/coverage")$category, "bug")
	expect_equal(g("continuous/ContinB/estimate/bias")$category, "bias")
	# Bugs first.
	expect_true(all(head(tr$category, 3) == "bug"))
})

test_that("a largest n that never ran is not called small-sample", {
	tr = tenv$cal_triage_groups(synthetic_summary(), max_n = 5000, final = TRUE)
	b = tr[tr$group_id == "continuous/ContinB/wald/size", ]
	expect_equal(b$pattern, "largest n not run")
	expect_equal(b$category, "bug")
})

test_that("triage_calibration_study.R drafts uncovered groups into the right release file and skips covered ones", {
	root = tempfile("triageplans")
	plans = file.path(root, "plans")
	dir.create(plans, recursive = TRUE)
	writeLines(c("# v9.0.1", "", "## Implementation TODOs", "",
		"- [ ] TODO-40 (owner): **`InferenceContinC`'s `wald` is oversized at n = 1000.** Investigate.",
		"- [x] TODO-41 (owner): **`InferenceContinA` `rand` size.** Closed."), file.path(plans, "release_v9_0_1.md"))
	writeLines(c("# v9.0.2", "", "- [ ] TODO-57 (owner): unrelated."), file.path(plans, "release_v9_0_2.md"))
	acc = file.path(root, "accepted.csv")
	utils::write.csv(data.frame(response_type = character(), design = character(), prob_T = numeric(), inf_class = character(),
		inf_procedure = character(), formula = character(), n = integer(), metric = character(), accepted_level = numeric(),
		reason = character()), acc, row.names = FALSE)
	tf = file.path(root, "triage.csv")
	utils::write.csv(tenv$cal_triage_groups(synthetic_summary(), max_n = 1000, final = TRUE), tf, row.names = FALSE)
	run = function(...) suppressWarnings(system2(rscript, c(shQuote(file.path(cal_dir, "triage_calibration_study.R")), "--triage", tf,
		"--campaign", "2026-11-12-abcdef12", "--plans-dir", plans, "--accepted", acc, "--current", "v9_0_1", "--next", "v9_0_2",
		"--date", "2026-11-12", ...), stdout = TRUE, stderr = TRUE))
	out = run()
	expect_null(attr(out, "status"))
	cur = readLines(file.path(plans, "release_v9_0_1.md"))
	nxt = readLines(file.path(plans, "release_v9_0_2.md"))
	# Numbers continue past the largest TODO in any release file (57), bugs first into the current release.
	expect_equal(sum(grepl("^- \\[ \\] TODO-58 \\(added 2026-11-12, drafted by", cur)), 1L)
	expect_true(any(grepl("^- \\[ \\] TODO-[0-9]+ .*InferenceContinA`'s `rand` fails its null size gate.*<!-- triage: continuous/ContinA/rand/size -->$", cur)))
	expect_true(any(grepl("<!-- triage: continuous/ContinC/wald/coverage -->", cur, fixed = TRUE)))
	expect_true(any(grepl("<!-- triage: continuous/ContinB/wald/size -->", nxt, fixed = TRUE)))
	expect_equal(sum(cur == "## Drafted from calibration campaign 2026-11-12-abcdef12 (review)"), 1L)
	# Covered by open TODO-40 (class, procedure, "oversized"); the closed TODO-41 covers nothing; one-design bias is skipped.
	expect_false(any(grepl("triage: continuous/ContinC/wald/size", c(cur, nxt), fixed = TRUE)))
	expect_true(any(grepl("covered by open TODO-40", out, fixed = TRUE)))
	expect_false(any(grepl("ContinB/estimate/bias -->", c(cur, nxt), fixed = TRUE)))
	# Rerun: everything drafted is now covered by its marker, so nothing new and no second heading.
	out2 = run()
	expect_true(any(grepl("0 drafted", out2, fixed = TRUE)))
	expect_identical(readLines(file.path(plans, "release_v9_0_1.md")), cur)
	expect_identical(readLines(file.path(plans, "release_v9_0_2.md")), nxt)
})

test_that("a provisional triage is refused unless asked for, and an accepted row covers its group", {
	root = tempfile("triageprov")
	plans = file.path(root, "plans")
	dir.create(plans, recursive = TRUE)
	writeLines("# v9.0.1", file.path(plans, "release_v9_0_1.md"))
	writeLines("# v9.0.2", file.path(plans, "release_v9_0_2.md"))
	tf = file.path(root, "triage.csv")
	utils::write.csv(tenv$cal_triage_groups(synthetic_summary(), max_n = 1000, final = FALSE), tf, row.names = FALSE)
	acc = file.path(root, "accepted.csv")
	utils::write.csv(data.frame(response_type = "continuous", design = "DesignFixedBernoulli", prob_T = 0.5, inf_class = "InferenceContinA",
		inf_procedure = "rand", formula = "~.", n = 50, metric = "size", accepted_level = 0.1, reason = "v9.0.1 TODO-1"), acc, row.names = FALSE)
	run = function(...) suppressWarnings(system2(rscript, c(shQuote(file.path(cal_dir, "triage_calibration_study.R")), "--triage", tf,
		"--plans-dir", plans, "--accepted", acc, "--current", "v9_0_1", "--next", "v9_0_2", ...), stdout = TRUE, stderr = TRUE))
	out = run()
	expect_false(is.null(attr(out, "status")))
	expect_true(any(grepl("not complete", out)))
	out = run("--allow-provisional", "--dry-run")
	expect_null(attr(out, "status"))
	expect_true(any(grepl("ContinA/rand/size.*covered by calibration_study_accepted.csv", out)))
	expect_identical(readLines(file.path(plans, "release_v9_0_1.md")), "# v9.0.1")
})

test_that("a release marked Status: CLOSED is never a draft target", {
	root = tempfile("triageclosed")
	plans = file.path(root, "plans")
	dir.create(plans, recursive = TRUE)
	writeLines(c("# v9.0.1", "", "> **Status: CLOSED to new TODOs (owner): soon to be released.**"), file.path(plans, "release_v9_0_1.md"))
	writeLines("# v9.0.2", file.path(plans, "release_v9_0_2.md"))
	writeLines("# v9.1.0", file.path(plans, "release_v9_1_0.md"))
	desc = file.path(root, "DESCRIPTION")
	writeLines(c("Package: X", "Version: 9.0.0"), desc)
	tf = file.path(root, "triage.csv")
	utils::write.csv(tenv$cal_triage_groups(synthetic_summary(), max_n = 1000, final = TRUE), tf, row.names = FALSE)
	acc = file.path(root, "none.csv")
	run = function(...) suppressWarnings(system2(rscript, c(shQuote(file.path(cal_dir, "triage_calibration_study.R")), "--triage", tf,
		"--plans-dir", plans, "--accepted", acc, "--description", desc, ...), stdout = TRUE, stderr = TRUE))
	out = run()
	expect_null(attr(out, "status"))
	expect_identical(readLines(file.path(plans, "release_v9_0_1.md"))[1], "# v9.0.1")
	expect_length(readLines(file.path(plans, "release_v9_0_1.md")), 3L)
	expect_true(any(grepl("triage: continuous/ContinA/rand/size", readLines(file.path(plans, "release_v9_0_2.md")), fixed = TRUE)))
	expect_true(any(grepl("triage: continuous/ContinB/wald/size", readLines(file.path(plans, "release_v9_1_0.md")), fixed = TRUE)))
	# Naming the closed file explicitly is refused.
	out = run("--current", "v9_0_1", "--next", "v9_0_2")
	expect_false(is.null(attr(out, "status")))
	expect_true(any(grepl("closed to new TODOs", out)))
})
