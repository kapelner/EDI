library(testthat)

# v1.0.5 TODO-203 Amendment E (new_feature_plans/v1_0_5/calibration_class_major_campaign_order.md): the calibration wave planner
# takes each class's cost from the campaign's own finished shards (stats/tests.csv.gz; the ledger's per-shard time gives the
# per-pack overhead), falling back by decreasing specificity, and tops up shards that would come out well under the target
# with further classes of the same cell. No EDI needed.

amend_e_cal_dir = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		d = file.path(dir, "R", "package_tests", "calibration")
		if (file.exists(file.path(d, "plan_calibration_study.R"))) return(d)
		dir = dirname(dir)
	}
	NA_character_
}
cal_dir = amend_e_cal_dir()
skip_if(is.na(cal_dir), "calibration scripts not found")
skip_if_not_installed("jsonlite")
rscript = file.path(R.home("bin"), "Rscript")
env = new.env()
sys.source(file.path(cal_dir, "calibration_study_stats.R"), envir = env)
sys.source(file.path(cal_dir, "calibration_study_plan_common.R"), envir = env)
sys.source(file.path(cal_dir, "calibration_study_synthetic_fixture.R"), envir = env)

# A campaign dir with the synthetic roster (continuous: ContinLin 0.1 s, ContinOLS 0.2 s; incidence: IncidLogit 0.3 s, roster
# secs_n50) and, optionally, finished shards: `done` is a list of list(cls, design, n, reps_done, reps_stat, fit) giving one
# ledger row and the class's statistics rows (wald and rand, `fit` seconds per replicate in all); reps_stat is the number of
# replicates the statistics hold (the ones actually done).
amend_e_campaign = function(done = list(), dead = list(), ledger_spr = NULL) {
	root = tempfile("calamende"); dir.create(file.path(root, "c", "stats"), recursive = TRUE)
	roster_path = file.path(root, "roster.csv")
	utils::write.csv(env$cal_synth_roster(), roster_path, row.names = FALSE)
	cdir = file.path(root, "c")
	u = env$cal_stats_u_cols()
	tests = list(); led = list()
	for (i in seq_along(done)) {
		d = done[[i]]
		for (pr in c("wald", "rand")) {
			t = data.frame(response_type = "continuous", design = d$design, prob_T = 0.5, inf_class = d$cls, formula = "~.", n = d$n, n_nominal = d$n,
				effect_label = "null", stage = "screen", inf_procedure = pr, reps = d$reps_stat, n_p = d$reps_stat, rej = 0L, rej10 = 0L,
				n_ci = d$reps_stat, cov = d$reps_stat, fit_secs = d$fit / 2 * d$reps_stat, stringsAsFactors = FALSE)
			t[u] = lapply(u, function(j) 0L)
			tests[[length(tests) + 1L]] = t
		}
		nd = d$reps_stat
		led[[i]] = data.frame(response_type = "continuous", design = d$design, n = d$n, effect = "null", only = d$cls, exclude = "", reps_done = d$reps_done,
			n_done = nd, n_failed = 0L, n_skipped = 0L, cores = 4L, elapsed_sec = 10, secs_per_rep = if (is.null(ledger_spr)) d$fit else ledger_spr,
			id = paste0("s", i), stringsAsFactors = FALSE)
	}
	if (length(tests)) {
		utils::write.csv(do.call(rbind, tests), gzfile(file.path(cdir, "stats", "tests.csv.gz")), row.names = FALSE)
		utils::write.csv(do.call(rbind, led), file.path(cdir, "ledger.csv"), row.names = FALSE)
	}
	if (length(dead)) {
		planned = do.call(rbind, lapply(seq_along(dead), function(i) data.frame(id = paste0("dead", i), response_type = "continuous", design = dead[[i]]$design,
			n = dead[[i]]$n, effect = "null", group = dead[[i]]$cls, wave = 1L, run_id = "1", stringsAsFactors = FALSE)))
		utils::write.csv(planned, file.path(cdir, "planned.csv"), row.names = FALSE)
	}
	list(cdir = cdir, roster = roster_path)
}
amend_e_plan = function(cp, ..., null_reps = 100) {
	out = suppressWarnings(system2(rscript, c(shQuote(file.path(cal_dir, "plan_calibration_study.R")), "--campaign-dir", shQuote(cp$cdir), "--roster", shQuote(cp$roster),
		"--ns", "50,200", "--effects", "null", "--null-reps", null_reps, "--wave-size", 256, ...), stdout = TRUE, stderr = FALSE))
	expect_null(attr(out, "status"))
	jsonlite::fromJSON(out[[1L]])$include
}
# The shard of a cell carrying a class (first in its pack) with the given first replicate.
find_shard = function(w, design, n, cls, first = NULL) {
	hit = w$design == design & w$n == n & vapply(strsplit(w$only, ","), function(v) cls %in% v, logical(1L))
	if (!is.null(first)) hit = hit & grepl(paste0("^", first, "[:,]|^", first, "$"), w$reps)
	w[hit, , drop = FALSE]
}

test_that("a class's measured cost from this campaign replaces the roster's, per pack with the ledger's overhead", {
	bern = "DesignFixedBernoulli"
	# No measurements: the roster's secs_n50 (ContinLin 0.1), one class per shard.
	w0 = amend_e_plan(amend_e_campaign(), "--pack-minutes", 0)
	expect_equal(find_shard(w0, bern, 50L, "InferenceContinLin")$secs_per_rep, 0.1)
	# ContinLin measured at 1.0 s per replicate (wald + rand) on Bernoulli, n = 50, 100 replicates; the ledger says its shard took
	# 1.4 s per replicate, so the cell's overhead is 0.4 s per replicate, charged once per pack.
	cp = amend_e_campaign(list(list(cls = "InferenceContinLin", design = bern, n = 50L, reps_done = "1:100", reps_stat = 100L, fit = 1)), ledger_spr = 1.4)
	# Planned 150 replicates: the 50 missing ones are re-planned (no -- leftover), and the cost is the measured one + overhead.
	w = amend_e_plan(cp, "--pack-minutes", 0, null_reps = 150)
	s = find_shard(w, bern, 50L, "InferenceContinLin")
	expect_equal(s$secs_per_rep, 1.4)
	expect_equal(s$reps, "101:150")
	# A different design of the same class and n takes the median of the other designs' measurements (measured_n) plus the overhead of
	# the nearest cell with one (same n, any design: 0.4).
	s2 = find_shard(w, "DesignFixediBCRD", 50L, "InferenceContinLin")
	expect_equal(s2$secs_per_rep, 1.4)
})

test_that("cost fallback: other designs, then another n scaled by the cost table, then the roster corrected by the measured/roster ratio", {
	bern = "DesignFixedBernoulli"
	cp = amend_e_campaign(list(list(cls = "InferenceContinLin", design = bern, n = 50L, reps_done = "1:100", reps_stat = 100L, fit = 1)))
	w = amend_e_plan(cp, "--pack-minutes", 0, null_reps = 150)
	# (1) same design, class, n: 1.0.  (2) other design, same n: median of the others = 1.0.
	expect_equal(find_shard(w, bern, 50L, "InferenceContinLin")$secs_per_rep, 1)
	expect_equal(find_shard(w, "DesignFixediBCRD", 50L, "InferenceContinLin")$secs_per_rep, 1)
	# (3) same class, other n (200): 1.0 x cost table (continuous iid) at 200 / at 50 = 12 / 8 = 1.5, on the measured design and on the other.
	expect_equal(find_shard(w, bern, 200L, "InferenceContinLin")$secs_per_rep, 1.5)
	expect_equal(find_shard(w, "DesignFixediBCRD", 200L, "InferenceContinLin")$secs_per_rep, 1.5)
	# (4) a class with no measurement (ContinOLS, roster 0.2): the roster times measured / roster of this response type (1.0 / 0.1 = 10) = 2.0 at n = 50.
	expect_equal(find_shard(w, bern, 50L, "InferenceContinOLS")$secs_per_rep, 2)
	# Another response type has no measurements: the roster as it is (IncidLogit 0.3).
	expect_equal(find_shard(w, bern, 50L, "InferenceIncidLogit")$secs_per_rep, 0.3)
	# Too few measured replicates: ignored (the roster again).
	w2 = amend_e_plan(cp, "--pack-minutes", 0, "--min-measured-reps", 101, null_reps = 150)
	expect_equal(find_shard(w2, bern, 50L, "InferenceContinLin")$secs_per_rep, 0.1)
})

test_that("a shard that hit its deadline counts for the replicates it did, not the replicates planned", {
	bern = "DesignFixedBernoulli"
	# Planned 1:100, done 1:40 (60 skipped): the statistics hold 40 replicates and 80 s of fit time per procedure's 2 s.
	cp = amend_e_campaign(list(list(cls = "InferenceContinLin", design = bern, n = 50L, reps_done = "1:40", reps_stat = 40L, fit = 4)))
	w = amend_e_plan(cp, "--pack-minutes", 0)
	s = find_shard(w, bern, 50L, "InferenceContinLin")
	expect_equal(s$reps, "41:100")                 # only the replicates not done are re-planned
	expect_equal(s$secs_per_rep, 4)                # 4 s per replicate measured, not 4 x 40 / 100
})

test_that("small leftovers are folded into one shard with a fresh class of the cell; the rest of the guest is planned as usual", {
	bern = "DesignFixedBernoulli"
	# ContinLin did 1:60, so its 40 missing replicates would make a tiny shard; ContinOLS is fresh in the same cell (missing 1:100).
	cp = amend_e_campaign(list(list(cls = "InferenceContinLin", design = bern, n = 50L, reps_done = "1:60", reps_stat = 60L, fit = 0.5)))
	w = amend_e_plan(cp)
	cell = w[w$design == bern & w$n == 50L & w$response_type == "continuous", ]
	fold = cell[cell$only == "InferenceContinLin,InferenceContinOLS" & cell$reps == "61:100", ]
	expect_equal(nrow(fold), 1L)
	expect_equal(fold$group, "InferenceContinLin;InferenceContinOLS")
	# OLS's other replicates are planned in a shard of their own: together exactly 1:100, no replicate twice.
	ols = cell[grepl("InferenceContinOLS", cell$only, fixed = TRUE), ]
	covered = unlist(lapply(strsplit(ols$reps, ","), function(r) unlist(lapply(strsplit(r, ":"), function(b) seq.int(as.integer(b[[1L]]), as.integer(b[[length(b)]]))))))
	expect_identical(sort(covered), 1:100)
	expect_equal(nrow(ols), 2L)
	# No folding: --min-shard-minutes 0 (or one class per shard) gives the old shape.
	for (a in list(c("--min-shard-minutes", 0), c("--pack-minutes", 0))) {
		w0 = amend_e_plan(cp, a)
		c0 = w0[w0$design == bern & w0$n == 50L & w0$response_type == "continuous", ]
		expect_false(any(c0$only == "InferenceContinLin,InferenceContinOLS" & c0$reps == "61:100"))
		expect_true(any(c0$only == "InferenceContinLin" & c0$reps == "61:100"))
	}
})

test_that("a unit that lost a shard still runs alone: it is neither a host nor a guest of a fold", {
	bern = "DesignFixedBernoulli"
	# OLS has a small leftover (did 1:60); Lin is fresh (it would be an eligible guest) but lost a shard to a death.
	cp = amend_e_campaign(list(list(cls = "InferenceContinOLS", design = bern, n = 50L, reps_done = "1:60", reps_stat = 60L, fit = 0.5)),
		dead = list(list(design = bern, n = 50L, cls = "InferenceContinLin")))
	w = amend_e_plan(cp)
	cell = w[w$design == bern & w$n == 50L & w$response_type == "continuous", ]
	lin = cell[grepl("InferenceContinLin", cell$only, fixed = TRUE), ]
	expect_equal(nrow(lin), 1L)
	expect_equal(lin$only, "InferenceContinLin")
	expect_equal(lin$reps, "1:100")
	ols = cell[grepl("InferenceContinOLS", cell$only, fixed = TRUE), ]
	expect_equal(ols$only, "InferenceContinOLS")
	expect_equal(ols$reps, "61:100")
	# And a dead unit with a small missing set is not topped up either.
	cp2 = amend_e_campaign(list(list(cls = "InferenceContinLin", design = bern, n = 50L, reps_done = "1:60", reps_stat = 60L, fit = 0.5)),
		dead = list(list(design = bern, n = 50L, cls = "InferenceContinLin")))
	w2 = amend_e_plan(cp2)
	c2 = w2[w2$design == bern & w2$n == 50L & w2$response_type == "continuous", ]
	expect_equal(c2$only[c2$reps == "61:100"], "InferenceContinLin")
})

test_that("class-major priority order is kept with folding: null before power, response type, then class", {
	bern = "DesignFixedBernoulli"
	cp = amend_e_campaign(list(list(cls = "InferenceContinLin", design = bern, n = 50L, reps_done = "1:60", reps_stat = 60L, fit = 0.5)))
	out = suppressWarnings(system2(rscript, c(shQuote(file.path(cal_dir, "plan_calibration_study.R")), "--campaign-dir", shQuote(cp$cdir), "--roster", shQuote(cp$roster),
		"--ns", "50,200", "--effects", "null,power20", "--null-reps", 100, "--power-reps", 50, "--wave-size", 256), stdout = TRUE, stderr = FALSE))
	w = jsonlite::fromJSON(out[[1L]])$include
	expect_true(all(diff(match(w$effect, c("null", "power20"))) >= 0))                    # null before the power effect
	nul = w[w$effect == "null", ]
	rt = match(nul$response_type, c("continuous", "incidence"))
	expect_true(all(diff(rt) >= 0))                                                       # continuous before incidence
	# The folded shard (Lin + OLS, 61:100) comes before OLS's own remaining shard, and every continuous shard before any incidence one.
	i_fold = which(nul$only == "InferenceContinLin,InferenceContinOLS" & nul$reps == "61:100")
	i_rest = which(nul$only == "InferenceContinOLS" & nul$design == bern & nul$n == 50L)
	expect_length(i_fold, 1L)
	expect_true(all(i_fold < i_rest))
	# The plan itself (plan.csv: the multiple-testing family) does not depend on any of this.
	f = tempfile(fileext = ".csv"); f0 = tempfile(fileext = ".csv")
	for (cdir in list(cp$cdir, file.path(tempdir(), "no-such-campaign")))
		suppressWarnings(system2(rscript, c(shQuote(file.path(cal_dir, "plan_calibration_study.R")), "--plan-only", "--roster", shQuote(cp$roster), "--campaign-dir", shQuote(cdir),
			"--plan-out", shQuote(if (identical(cdir, cp$cdir)) f else f0)), stdout = TRUE, stderr = TRUE))
	expect_identical(readLines(f), readLines(f0))
})
