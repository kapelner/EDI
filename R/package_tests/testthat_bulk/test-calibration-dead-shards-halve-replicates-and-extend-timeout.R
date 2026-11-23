library(testthat)

# v1.0.6-TODO-409 (owner decision 2026-11-22): a calibration shard that dies or hits its job timeout halves its unit's next
# shards (down to 1 replicate), which also get the longer job timeout (matrix timeout_minutes); only dead 1-replicate shards
# count toward --max-dead abandonment. Campaign 2026-11-15-e36c7710 abandoned InferenceOrdinalKKCLMM at n = 1000 on three
# designs (~870 s per replicate) under the old rule (every death counted, the same shard size re-planned). No EDI needed.

dead_halve_cal_dir = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		d = file.path(dir, "R", "package_tests", "calibration")
		if (file.exists(file.path(d, "plan_calibration_study.R"))) return(d)
		dir = dirname(dir)
	}
	NA_character_
}
cal_dir = dead_halve_cal_dir()
skip_if(is.na(cal_dir), "calibration scripts not found")
skip_if_not_installed("jsonlite")
rscript = file.path(R.home("bin"), "Rscript")
env = new.env()
sys.source(file.path(cal_dir, "calibration_study_synthetic_fixture.R"), envir = env)

bern = "DesignFixedBernoulli"
lin = "InferenceContinLin"

# A campaign with the synthetic roster. `planned`: data frame of planned shards (id, design, cls, run_id, and reps unless
# `legacy`, a planned.csv written before the reps column); `finished`: ids of planned shards that wrote a ledger row, with
# their reps_done and planned size (n_done + n_skipped).
dead_halve_campaign = function(planned = NULL, finished = NULL, legacy = FALSE) {
	root = tempfile("caldead"); dir.create(file.path(root, "c"), recursive = TRUE)
	roster = file.path(root, "roster.csv")
	utils::write.csv(env$cal_synth_roster(), roster, row.names = FALSE)
	cdir = file.path(root, "c")
	if (!is.null(planned)) {
		p = data.frame(id = planned$id, response_type = "continuous", design = planned$design, n = 50L, effect = "null",
			group = planned$cls, wave = 1L, run_id = planned$run_id, stringsAsFactors = FALSE)
		if (!legacy) p$reps = planned$reps
		utils::write.csv(p, file.path(cdir, "planned.csv"), row.names = FALSE)
	}
	if (!is.null(finished)) {
		l = data.frame(response_type = "continuous", design = finished$design, n = 50L, effect = "null", only = finished$cls, exclude = "",
			reps_done = finished$reps_done, n_done = finished$n_done, n_failed = 0L, n_skipped = finished$n_skipped, cores = 4L,
			elapsed_sec = 10, secs_per_rep = 0.1, id = finished$id, stringsAsFactors = FALSE)
		utils::write.csv(l, file.path(cdir, "ledger.csv"), row.names = FALSE)
	}
	list(cdir = cdir, roster = roster)
}
dead_halve_plan = function(cp, ...) {
	meta = tempfile("meta")
	out = suppressWarnings(system2(rscript, c(shQuote(file.path(cal_dir, "plan_calibration_study.R")), "--campaign-dir", shQuote(cp$cdir), "--roster", shQuote(cp$roster),
		"--ns", "50", "--effects", "null", "--null-reps", "100", "--pack-minutes", "0", "--wave-size", "256", "--meta-out", shQuote(meta), ...),
		stdout = TRUE, stderr = FALSE))
	expect_null(attr(out, "status"))
	m = readLines(meta)
	list(w = jsonlite::fromJSON(out[[1L]])$include, abandoned = as.integer(sub("^units_abandoned=", "", grep("^units_abandoned=", m, value = TRUE))))
}
n_reps = function(r) vapply(strsplit(r, ",", fixed = TRUE), function(p) sum(vapply(strsplit(p, ":", fixed = TRUE), function(b) {
	b = as.integer(b); b[[length(b)]] - b[[1L]] + 1L }, integer(1L))), integer(1L))
unit_shards = function(w, design = bern, cls = lin) w[w$design == design & w$n == 50L & w$only == cls, , drop = FALSE]
dead_rows = function(sizes, cls = lin, design = bern) {
	starts = cumsum(c(1L, utils::head(sizes, -1L)))
	data.frame(id = sprintf("d-%s-r%d", cls, starts), design = design, cls = cls, run_id = "1",
		reps = ifelse(sizes == 1L, as.character(starts), sprintf("%d:%d", starts, starts + sizes - 1L)), stringsAsFactors = FALSE)
}

test_that("without deaths every shard gets the normal timeout and the usual size", {
	r = dead_halve_plan(dead_halve_campaign())
	expect_true(all(r$w$timeout_minutes == 75L))
	expect_equal(unit_shards(r$w)$reps, "1:100")
	expect_equal(r$abandoned, 0L)
})

test_that("a dead shard halves the unit's next shards and gives them the longer timeout; other units are unchanged", {
	r = dead_halve_plan(dead_halve_campaign(dead_rows(8L)))
	s = unit_shards(r$w)
	expect_true(all(n_reps(s$reps) <= 4L))
	expect_equal(sum(n_reps(s$reps)), 100L)        # every missing replicate is still planned
	expect_true(all(s$timeout_minutes == 180L))
	other = r$w[!(r$w$design == bern & r$w$only == lin), ]
	expect_gt(nrow(other), 0L)
	expect_true(all(other$timeout_minutes == 75L))
	# The smallest dead shard sets the cap; the timeout is a flag.
	r2 = dead_halve_plan(dead_halve_campaign(dead_rows(c(8L, 3L))), "--dead-timeout-minutes", "240")
	s2 = unit_shards(r2$w)
	expect_true(all(n_reps(s2$reps) == 1L))
	expect_true(all(s2$timeout_minutes == 240L))
})

test_that("deaths of multi-replicate shards never abandon a unit; three dead 1-replicate shards do", {
	# Five deaths of 4-replicate shards (the old rule abandoned at three): still planned, 2 replicates per shard.
	r = dead_halve_plan(dead_halve_campaign(dead_rows(rep(4L, 5L))))
	s = unit_shards(r$w)
	expect_gt(nrow(s), 0L)
	expect_true(all(n_reps(s$reps) == 2L))
	expect_equal(r$abandoned, 0L)
	# The halving reaches 1 and stays there: two dead 1-replicate shards (plus larger ones) keep the unit alive.
	r1 = dead_halve_plan(dead_halve_campaign(dead_rows(c(4L, 2L, 1L, 1L))))
	s1 = unit_shards(r1$w)
	expect_true(all(n_reps(s1$reps) == 1L))
	expect_equal(r1$abandoned, 0L)
	# The third dead 1-replicate shard abandons it (--max-dead 3); a fourth larger death changes nothing.
	r3 = dead_halve_plan(dead_halve_campaign(dead_rows(c(4L, 1L, 1L, 1L))))
	expect_equal(nrow(unit_shards(r3$w)), 0L)
	expect_equal(r3$abandoned, 1L)
	# --max-dead still sets the number.
	r4 = dead_halve_plan(dead_halve_campaign(dead_rows(c(1L, 1L, 1L))), "--max-dead", "4")
	expect_gt(nrow(unit_shards(r4$w)), 0L)
})

test_that("a planned.csv from before the reps column sizes a dead shard from its finished siblings, else the id gaps", {
	# Run 7 planned Lin in 1:40 and 41:80; 1:40 finished (40 planned = n_done + n_skipped, 30 done), 41:80 died: size 40.
	planned = data.frame(id = c("s-Lin-r1", "s-Lin-r41"), design = bern, cls = lin, run_id = "7", stringsAsFactors = FALSE)
	finished = data.frame(id = "s-Lin-r1", design = bern, cls = lin, reps_done = "1:30", n_done = 30L, n_skipped = 10L, stringsAsFactors = FALSE)
	r = dead_halve_plan(dead_halve_campaign(planned, finished, legacy = TRUE))
	s = unit_shards(r$w)
	expect_equal(sum(n_reps(s$reps)), 70L)          # 31:100 missing
	expect_true(all(n_reps(s$reps) <= 20L))
	expect_true(all(s$timeout_minutes == 180L))
	# No finished sibling: the gap to the next shard's first replicate (30), so at most 15 per shard.
	p2 = data.frame(id = c("s-Lin-r1", "s-Lin-r31"), design = bern, cls = lin, run_id = "7", stringsAsFactors = FALSE)
	s2 = unit_shards(dead_halve_plan(dead_halve_campaign(p2, legacy = TRUE))$w)
	expect_equal(sum(n_reps(s2$reps)), 100L)
	expect_true(all(n_reps(s2$reps) <= 15L))
	# Unknown size (a lone legacy shard): halves the size it would be planned at now, and never counts toward --max-dead.
	p3 = data.frame(id = sprintf("x%d", 1:4), design = bern, cls = lin, run_id = as.character(1:4), stringsAsFactors = FALSE)
	r3 = dead_halve_plan(dead_halve_campaign(p3, legacy = TRUE))
	expect_equal(sort(unit_shards(r3$w)$reps), c("1:50", "51:100"))
	expect_equal(r3$abandoned, 0L)
})

test_that("a job timeout above GitHub's 360-minute limit is refused", {
	cp = dead_halve_campaign()
	out = suppressWarnings(system2(rscript, c(shQuote(file.path(cal_dir, "plan_calibration_study.R")), "--campaign-dir", shQuote(cp$cdir),
		"--roster", shQuote(cp$roster), "--ns", "50", "--effects", "null", "--dead-timeout-minutes", "400"), stdout = TRUE, stderr = TRUE))
	expect_false(is.null(attr(out, "status")))
})
