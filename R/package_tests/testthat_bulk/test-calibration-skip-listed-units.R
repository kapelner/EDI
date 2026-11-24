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

# Owner 2026-11-24: plan_calibration_study.R --skip-units (calibration_skip_units.csv) leaves listed (campaign,
# response_type, inf_class, n) units out of a campaign: planned like abandoned units (no shards, counted in
# units_abandoned); rows naming another campaign are ignored. No EDI needed.

skip_cal_dir = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		d = file.path(dir, "R", "package_tests", "calibration")
		if (file.exists(file.path(d, "plan_calibration_study.R"))) return(d)
		dir = dirname(dir)
	}
	NA_character_
}
cal_dir = skip_cal_dir()
skip_if(is.na(cal_dir), "calibration scripts not found")
skip_if_not_installed("jsonlite")
rscript = file.path(R.home("bin"), "Rscript")
env = new.env()
sys.source(file.path(cal_dir, "calibration_study_stats.R"), envir = env)
sys.source(file.path(cal_dir, "calibration_study_plan_common.R"), envir = env)
sys.source(file.path(cal_dir, "calibration_study_synthetic_fixture.R"), envir = env)

BERN = "DesignFixedBernoulli"
# An empty campaign directory named `name` (the skip list matches on the directory's basename).
skip_campaign = function(name = "c") {
	root = tempfile("calskip"); cdir = file.path(root, name); dir.create(file.path(cdir, "stats"), recursive = TRUE)
	roster_path = file.path(root, "roster.csv")
	utils::write.csv(env$cal_synth_roster(), roster_path, row.names = FALSE)
	list(root = root, cdir = cdir, roster = roster_path)
}
skip_file = function(campaign, cls = "InferenceContinOLS", n = 200L) {
	p = tempfile(fileext = ".csv")
	writeLines(c("# test skip list", "campaign,response_type,inf_class,n,reason",
		sprintf('%s,continuous,%s,%d,"test"', campaign, cls, n)), p)
	p
}
run_plan = function(cp, ...) {
	meta = tempfile(fileext = ".txt")
	out = suppressWarnings(system2(rscript, c(shQuote(file.path(cal_dir, "plan_calibration_study.R")), "--campaign-dir", shQuote(cp$cdir),
		"--roster", shQuote(cp$roster), "--ns", "50,200", "--effects", "null", "--null-reps", 100, "--wave-size", 100000,
		"--meta-out", shQuote(meta), ...), stdout = TRUE, stderr = FALSE))
	expect_null(attr(out, "status"))
	m = readLines(meta)
	list(wave = jsonlite::fromJSON(out[[1L]])$include,
		meta = stats::setNames(as.numeric(sub("^.*=", "", m)), sub("=.*$", "", m)))
}
has_cls = function(w, cls, n) w$n == n & vapply(strsplit(w$only, ","), function(v) cls %in% v, logical(1L))
ols_units = function(cp) {
	p = tempfile(fileext = ".csv")
	system2(rscript, c(shQuote(file.path(cal_dir, "plan_calibration_study.R")), "--roster", shQuote(cp$roster), "--ns", "50,200",
		"--effects", "null", "--null-reps", 100, "--plan-only", "--plan-out", shQuote(p), "--meta-out", shQuote(tempfile())), stdout = FALSE, stderr = FALSE)
	pl = read_csv_fast(p, stringsAsFactors = FALSE)
	sum(pl$inf_class == "InferenceContinOLS" & pl$n == 200)
}

test_that("a listed (campaign, class, n) gets no shards and counts as abandoned; other n and classes still run", {
	cp = skip_campaign("c")
	base = run_plan(cp, "--skip-units", "")
	expect_true(any(has_cls(base$wave, "InferenceContinOLS", 200)))
	expect_identical(unname(base$meta[["units_abandoned"]]), 0)
	x = run_plan(cp, "--skip-units", shQuote(skip_file("c")))
	expect_false(any(has_cls(x$wave, "InferenceContinOLS", 200)))
	expect_true(any(has_cls(x$wave, "InferenceContinOLS", 50)))
	expect_identical(unname(x$meta[["units_abandoned"]]), as.numeric(ols_units(cp)))
	expect_identical(unname(x$meta[["units"]]), unname(base$meta[["units"]]))
})

test_that("rows naming another campaign are ignored", {
	cp = skip_campaign("c")
	x = run_plan(cp, "--skip-units", shQuote(skip_file("other-campaign")))
	expect_true(any(has_cls(x$wave, "InferenceContinOLS", 200)))
	expect_identical(unname(x$meta[["units_abandoned"]]), 0)
})

test_that("the checked-in skip list parses and names only known columns", {
	sk = utils::read.csv(file.path(cal_dir, "calibration_skip_units.csv"), stringsAsFactors = FALSE, comment.char = "#")
	expect_identical(names(sk), c("campaign", "response_type", "inf_class", "n", "reason"))
	expect_true(all(nzchar(sk$reason)))
	expect_false(anyNA(as.integer(sk$n)))
})
