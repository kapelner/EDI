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

library(testthat)

# v1.1.0-TODO-269: the calibration planner's opt-in slow-unit cap (plan_calibration_study.R --slow-unit-cap-secs /
# --slow-unit-cap-reps; off by default, owner decision DECISION-v1.1.0-TODO-269). A screening unit whose measured
# single-core cost per replicate is above the threshold runs at most the capped number of replicates; plan.csv records
# it (rep_cap, rep_cap_secs) for the analysis and the campaign README. No EDI needed.

cap_cal_dir = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		d = file.path(dir, "R", "package_tests", "calibration")
		if (file.exists(file.path(d, "plan_calibration_study.R"))) return(d)
		dir = dirname(dir)
	}
	NA_character_
}
cal_dir = cap_cal_dir()
skip_if(is.na(cal_dir), "calibration scripts not found")
skip_if_not_installed("jsonlite")
rscript = file.path(R.home("bin"), "Rscript")
env = new.env()
sys.source(file.path(cal_dir, "calibration_study_stats.R"), envir = env)
sys.source(file.path(cal_dir, "calibration_study_plan_common.R"), envir = env)
sys.source(file.path(cal_dir, "calibration_study_synthetic_fixture.R"), envir = env)

BERN = "DesignFixedBernoulli"
# A campaign whose ContinOLS unit on Bernoulli at n = 200 has `done` screening replicates at `fit` s each (one finished
# shard), everything else unmeasured (roster costs, 0.1-0.3 s).
cap_campaign = function(done = 40L, fit = 400) {
	root = tempfile("calcap"); dir.create(file.path(root, "c", "stats"), recursive = TRUE)
	roster_path = file.path(root, "roster.csv")
	utils::write.csv(env$cal_synth_roster(), roster_path, row.names = FALSE)
	cdir = file.path(root, "c")
	u = env$cal_stats_u_cols()
	tests = do.call(rbind, lapply(c("wald", "rand"), function(pr) {
		t = data.frame(response_type = "continuous", design = BERN, prob_T = 0.5, inf_class = "InferenceContinOLS", formula = "~.", n = 200L,
			n_nominal = 200L, effect_label = "null", stage = "screen", inf_procedure = pr, reps = done, n_p = done, rej = 0L, rej10 = 0L,
			n_ci = done, cov = done, fit_secs = fit / 2 * done, stringsAsFactors = FALSE)
		t[u] = lapply(u, function(j) 0L)
		t
	}))
	utils::write.csv(tests, gzfile(file.path(cdir, "stats", "tests.csv.gz")), row.names = FALSE)
	utils::write.csv(data.frame(response_type = "continuous", design = BERN, n = 200L, effect = "null", only = "InferenceContinOLS", exclude = "",
		reps_done = sprintf("1:%d", done), n_done = done, n_failed = 0L, n_skipped = 0L, cores = 4L, elapsed_sec = 10, secs_per_rep = fit,
		id = "s1", stringsAsFactors = FALSE), file.path(cdir, "ledger.csv"), row.names = FALSE)
	list(root = root, cdir = cdir, roster = roster_path)
}
run_plan = function(cp, ..., plan_only = FALSE) {
	plan_out = tempfile(fileext = ".csv"); meta = tempfile(fileext = ".txt")
	out = suppressWarnings(system2(rscript, c(shQuote(file.path(cal_dir, "plan_calibration_study.R")), "--campaign-dir", shQuote(cp$cdir),
		"--roster", shQuote(cp$roster), "--ns", "50,200", "--effects", "null", "--null-reps", 100, "--wave-size", 256,
		"--plan-out", shQuote(plan_out), "--meta-out", shQuote(meta), if (plan_only) "--plan-only", ...), stdout = TRUE, stderr = FALSE))
	expect_null(attr(out, "status"))
	m = readLines(meta)
	list(wave = if (plan_only) NULL else jsonlite::fromJSON(out[[1L]])$include,
		plan = read_csv_fast(plan_out, stringsAsFactors = FALSE),
		meta = stats::setNames(as.numeric(sub("^.*=", "", m)), sub("=.*$", "", m)))
}
ols_shards = function(w) w[w$design == BERN & w$n == 200 & vapply(strsplit(w$only, ","), function(v) "InferenceContinOLS" %in% v, logical(1L)), , drop = FALSE]
reps_of = function(w) sort(unlist(lapply(strsplit(w$reps, ","), function(r) { b = as.integer(strsplit(r, ":")[[1L]]); seq.int(b[[1L]], b[[length(b)]]) })))
ols_row = function(p) p[p$inf_class == "InferenceContinOLS" & p$design == BERN & p$n == 200, , drop = FALSE]

test_that("off by default: a slow unit plans all its replicates and plan.csv has no cap columns", {
	cp = cap_campaign()
	x = run_plan(cp)
	expect_identical(reps_of(ols_shards(x$wave)), 41:100)
	expect_false(any(c("rep_cap", "rep_cap_secs") %in% names(x$plan)))
	expect_identical(as.integer(ols_row(x$plan)$reps), 100L)
	# Explicit 0 is the same as off.
	x0 = run_plan(cp, "--slow-unit-cap-secs", 0)
	expect_identical(x0$wave, x$wave)
	expect_identical(x0$plan, x$plan)
})

test_that("on: a unit measured above the threshold runs at most the capped replicates; cheaper units are untouched", {
	cp = cap_campaign()
	off = run_plan(cp)
	on = run_plan(cp, "--slow-unit-cap-secs", 300, "--slow-unit-cap-reps", 50, "--slow-unit-cap-scope", "all")
	expect_identical(reps_of(ols_shards(on$wave)), 41:50)
	r = ols_row(on$plan)
	expect_identical(as.integer(r$reps), 50L)
	expect_identical(as.integer(r$rep_cap), 50L)
	expect_equal(r$rep_cap_secs, 300)
	# The cap reads the planner's cost, so ContinOLS at n = 200 on the other design (priced from the Bernoulli measurement,
	# measured_n) is capped too; at n = 50 its cost scales to 400 x 8 / 12 = 267 s (calibration_study_costs.csv), under the
	# threshold. Every other unit keeps its replicates and no cap.
	capped = !is.na(on$plan$rep_cap)
	expect_identical(sort(unique(on$plan$inf_class[capped])), "InferenceContinOLS")
	expect_true(all(on$plan$n[capped] == 200L))
	expect_identical(sum(capped), 2L)
	others = on$plan[!capped, ]
	expect_identical(others$reps, off$plan$reps[match(paste(others$inf_class, others$design, others$n), paste(off$plan$inf_class, off$plan$design, off$plan$n))])
	expect_equal(on$meta[["reps_total"]], off$meta[["reps_total"]] - 2 * 50)
	# The tests of the plan (the gate's m) do not depend on replicate counts.
	expect_equal(on$meta[["m_total"]], off$meta[["m_total"]])
	# A threshold above the measured cost caps nothing.
	hi = run_plan(cp, "--slow-unit-cap-secs", 500, "--slow-unit-cap-reps", 50, "--slow-unit-cap-scope", "all")
	expect_identical(reps_of(ols_shards(hi$wave)), 41:100)
	expect_false("rep_cap" %in% names(hi$plan))
})

test_that("default scope caps only the planner's slow-list classes (DECISION-v1.1.0-TODO-269 (d))", {
	cp = cap_campaign()
	off = run_plan(cp)
	on = run_plan(cp, "--slow-unit-cap-secs", 300, "--slow-unit-cap-reps", 50)
	# ContinOLS is not in CAL_PLAN_SLOW_CLASSES, so although it costs 400 s per replicate it keeps all its replicates.
	expect_identical(reps_of(ols_shards(on$wave)), 41:100)
	expect_false("rep_cap" %in% names(on$plan))
	expect_identical(on$plan, off$plan)
	expect_false("InferenceContinOLS" %in% unlist(env$CAL_PLAN_SLOW_CLASSES))
	expect_error(suppressWarnings(run_plan(cp, "--slow-unit-cap-secs", 300, "--slow-unit-cap-scope", "bogus")))
})

test_that("a unit already past its cap is complete, and --plan-only writes the same plan.csv as the wave planner", {
	cp = cap_campaign(done = 60L)
	on = run_plan(cp, "--slow-unit-cap-secs", 300, "--slow-unit-cap-reps", 50, "--slow-unit-cap-scope", "all")
	expect_identical(nrow(ols_shards(on$wave)), 0L)
	off = run_plan(cp)
	expect_equal(on$meta[["units_done"]], off$meta[["units_done"]] + 1)
	po = run_plan(cp, "--slow-unit-cap-secs", 300, "--slow-unit-cap-reps", 50, "--slow-unit-cap-scope", "all", plan_only = TRUE)
	expect_identical(po$plan, on$plan)
	# Confirmation replicates are never capped: no confirmation unit is in plan.csv, and the cap reads only screening units.
	expect_true(all(on$plan$reps[!is.na(on$plan$rep_cap)] == 50L))
	expect_error(suppressWarnings(run_plan(cp, "--slow-unit-cap-secs", -1)))
})

test_that("the campaign README names the capped units", {
	root = tempfile("calcapreadme"); dir.create(root)
	x = env$cal_synth_campaign(root, "2026-11-10-abcd1234", cal_dir)
	p = read_csv_fast(file.path(x$cdir, "plan.csv"), stringsAsFactors = FALSE)
	p$rep_cap = ifelse(p$inf_class == "InferenceContinLin" & p$n == 1000L, 50L, NA_integer_)
	p$rep_cap_secs = ifelse(is.na(p$rep_cap), NA_real_, 300)
	utils::write.csv(p, file.path(x$cdir, "plan.csv"), row.names = FALSE)
	run = function(script, ...) suppressWarnings(system2(rscript, c(shQuote(file.path(cal_dir, script)), ...), stdout = TRUE, stderr = TRUE))
	a = c("--stats-dir", shQuote(file.path(x$cdir, "stats")), "--out-dir", shQuote(file.path(x$cdir, "summary")))
	expect_null(attr(run("convergence_calibration_study.R", a), "status"))
	res = run("analyze_calibration_study.R", a)
	expect_null(attr(res, "status"), info = paste(res, collapse = "\n"))
	res = run("render_calibration_study_readme.R", "--results-dir", shQuote(root), "--campaign", "2026-11-10-abcd1234", "--repo", "owner/repo")
	expect_null(attr(res, "status"), info = paste(res, collapse = "\n"))
	md = paste(readLines(file.path(x$cdir, "README.md")), collapse = "\n")
	n_capped = sum(!is.na(p$rep_cap))
	expect_match(md, sprintf("Slow-unit cap: %d screening unit(s) (ContinLin) run at most 50 replicates", n_capped), fixed = TRUE)
	expect_match(md, "300 single-core seconds per replicate", fixed = TRUE)
	# Without the columns (every campaign so far) there is no such line.
	p$rep_cap = NULL; p$rep_cap_secs = NULL
	utils::write.csv(p, file.path(x$cdir, "plan.csv"), row.names = FALSE)
	res = run("render_calibration_study_readme.R", "--results-dir", shQuote(root), "--campaign", "2026-11-10-abcd1234", "--repo", "owner/repo")
	expect_null(attr(res, "status"))
	expect_false(grepl("Slow-unit cap", paste(readLines(file.path(x$cdir, "README.md")), collapse = "\n"), fixed = TRUE))
})
