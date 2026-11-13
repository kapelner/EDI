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

# v1.0.5 TODO-203 (new_feature_plans/v1_0_5/calibration_class_major_campaign_order.md): the published calibration
# study runs class by class. Planner order (null before power, response type, class, design, n; a block's
# confirmation right after it), Benjamini-Hochberg over the whole plan with unrun tests as p = 1 (flags never
# withdrawn), the confirmation level 0.01 / m_total, class status, per-class convergence provisional flag, and the
# per-class pages and figures rendered from a synthetic three-n campaign. No EDI needed.

order_cal_dir = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		d = file.path(dir, "R", "package_tests", "calibration")
		if (file.exists(file.path(d, "plan_calibration_study.R"))) return(d)
		dir = dirname(dir)
	}
	NA_character_
}
cal_dir = order_cal_dir()
skip_if(is.na(cal_dir), "calibration scripts not found")
rscript = file.path(R.home("bin"), "Rscript")
run_script = function(script, ...) suppressWarnings(system2(rscript, c(shQuote(file.path(cal_dir, script)), ...), stdout = TRUE, stderr = TRUE))
env = new.env()
sys.source(file.path(cal_dir, "calibration_study_stats.R"), envir = env)
sys.source(file.path(cal_dir, "calibration_study_plan_common.R"), envir = env)
sys.source(file.path(cal_dir, "calibration_study_synthetic_fixture.R"), envir = env)

test_that("the plan is class-major: null before power, then response type, class, design, n", {
	roster = env$cal_synth_roster()
	u = env$cal_plan_units(roster, null_reps = 100L, power_reps = 50L)
	expect_identical(u$rank, seq_len(nrow(u)))
	# Every null unit before any power unit.
	last_null = max(which(u$effect == "null"))
	expect_true(all(u$effect[seq_len(last_null)] == "null"))
	expect_identical(u$effect[(last_null + 1L):nrow(u)][1L], "power20")
	# Effects in order, and within an effect continuous before incidence, classes alphabetical.
	expect_identical(unique(u$effect), c("null", "power20", "power50", "power80"))
	nl = u[u$effect == "null", ]
	cls_seq = unique(paste(nl$response_type, nl$inf_class))
	expect_identical(cls_seq, c("continuous InferenceContinLin", "continuous InferenceContinOLS", "incidence InferenceIncidLogit"))
	# A class's units are contiguous (the class is finished before the next starts); within a class: design, then n.
	for (cl in unique(nl$inf_class)) expect_identical(range(which(nl$inf_class == cl)), c(min(which(nl$inf_class == cl)), max(which(nl$inf_class == cl))) )
	for (cl in unique(nl$inf_class)) expect_identical(diff(range(which(nl$inf_class == cl))) + 1L, sum(nl$inf_class == cl))
	lin = nl[nl$inf_class == "InferenceContinLin", ]
	expect_identical(lin$design, rep(c("DesignFixedBernoulli", "DesignFixediBCRD"), each = 3L))
	expect_identical(lin$n, rep(c(50L, 200L, 1000L), 2L))
	# Power units only at the power sample sizes; m_total is the sum of the units' tests.
	expect_true(all(u$n[u$effect != "null"] %in% c(50L, 200L)))
	expect_identical(env$cal_plan_m_total(u), as.integer(sum(u$n_tests)))
	# Null: size + coverage tests per row; power: coverage only.
	r = u[u$key == u$key[1L], ]
	expect_identical(r$n_tests, 6L)
})

# The roster comes from the installed package (the workflow's `roster` job does the same at the pinned commit).
edi_ok = requireNamespace("EDI", quietly = TRUE)
roster_env = NULL
if (edi_ok) {
	roster_env = new.env()
	roster_env$script_dir = cal_dir
	suppressPackageStartupMessages(library(EDI))
	sys.source(file.path(cal_dir, "calibration_study_stats.R"), envir = roster_env)
	sys.source(file.path(cal_dir, "calibration_study_common.R"), envir = roster_env)
	sys.source(file.path(cal_dir, "build_calibration_study_roster.R"), envir = roster_env)
}

test_that("no roster is committed and the planner refuses to plan without a campaign roster", {
	expect_false(file.exists(file.path(cal_dir, "calibration_study_roster.csv")))
	out = run_script("plan_calibration_study.R", "--plan-only")
	expect_false(is.null(attr(out, "status")))
	expect_true(any(grepl("--roster FILE is required", out, fixed = TRUE)))
	out = run_script("plan_calibration_study.R", "--plan-only", "--roster", shQuote(file.path(tempdir(), "no-such-roster.csv")))
	expect_false(is.null(attr(out, "status")))
	expect_true(any(grepl("class roster not found", out, fixed = TRUE)))
	bad = tempfile(fileext = ".csv")
	utils::write.csv(data.frame(response_type = "continuous"), bad, row.names = FALSE)
	out = run_script("plan_calibration_study.R", "--plan-only", "--roster", shQuote(bad))
	expect_false(is.null(attr(out, "status")))
	expect_true(any(grepl("lacks columns", out, fixed = TRUE)))
	# With a roster it plans (the campaign's roster.csv is --roster).
	ok = tempfile(fileext = ".csv")
	utils::write.csv(env$cal_synth_roster(), ok, row.names = FALSE)
	expect_null(attr(run_script("plan_calibration_study.R", "--plan-only", "--roster", shQuote(ok)), "status"))
})

test_that("the roster built from the installed package plans every class on every design, with the slow-class replicate rules", {
	skip_if_not(edi_ok, "EDI not installed")
	roster = roster_env$cal_roster_build(get("CAL_RESPONSE_TYPES", envir = globalenv()), roster_env$cal_study_designs(), 50L)
	tmp = tempfile(fileext = ".csv")
	utils::write.csv(roster, tmp, row.names = FALSE)
	u = env$cal_plan_units(env$cal_plan_read_roster(tmp))
	expect_gte(length(unique(u$inf_class)), 88L)
	slow = u[u$inf_class == "InferenceCountKKGLMM", ]
	expect_true(all(slow$reps[slow$effect == "null" & slow$n == 1000L] == 500L))
	expect_true(all(slow$n[slow$effect != "null"] == 50L))
	expect_true(all(u$reps[u$effect == "null" & !(u$inf_class %in% unlist(env$CAL_PLAN_SLOW_CLASSES))] == 1000L))
	expect_identical(order(u$rank), seq_len(nrow(u)))
	# Without previous statistics every class gets the documented default cost.
	expect_true(all(roster$secs_n50 == roster_env$CAL_ROSTER_DEFAULT_SECS_N50))
	expect_identical(roster_env$CAL_ROSTER_DEFAULT_SECS_N50, 2)
	# Matched designs come from the package's predicate, recorded per design in the roster: exactly the designs
	# whose class set has the KK (matched-pair) classes, and the planner's family agrees with it.
	m = tapply(roster$matched, roster$design, unique)
	expect_true(is.logical(m) && !anyNA(m))
	has_kk = tapply(grepl("KK", roster$inf_class, fixed = TRUE), roster$design, any)
	expect_identical(as.logical(m[names(has_kk)]), as.logical(has_kk))
	expect_setequal(names(m)[m], c("DesignFixedBinaryMatch", "DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise"))
	expect_identical(unname(u$family == "matched"), unname(as.logical(m[u$design])))
})

test_that("the planner keeps no matched-design list: family comes from the roster's `matched` column", {
	pc = readLines(file.path(cal_dir, "calibration_study_plan_common.R"))
	expect_false(any(grepl("CAL_PLAN_MATCHED_DESIGNS", pc, fixed = TRUE)))
	expect_false(any(grepl("\"DesignSeqOneByOneKK21\"|\"DesignFixedBinaryMatch\"", pc)))
	r = env$cal_synth_roster()
	r$matched[r$design == "DesignFixediBCRD"] = TRUE
	f = tempfile(fileext = ".csv"); utils::write.csv(r, f, row.names = FALSE)
	env$cal_plan_read_roster(f)
	expect_identical(env$cal_plan_family(c("DesignFixediBCRD", "DesignFixedBernoulli")), c("matched", "iid"))
	# `matched` is a required, logical roster column.
	f2 = tempfile(fileext = ".csv"); utils::write.csv(r[setdiff(names(r), "matched")], f2, row.names = FALSE)
	expect_error(env$cal_plan_read_roster(f2), "matched")
	r$matched = "maybe"
	f3 = tempfile(fileext = ".csv"); utils::write.csv(r, f3, row.names = FALSE)
	expect_error(env$cal_plan_read_roster(f3), "TRUE / FALSE")
	# Before any roster or plan.csv is read the family is refused, not guessed.
	e2 = new.env(); sys.source(file.path(cal_dir, "calibration_study_plan_common.R"), envir = e2)
	expect_error(e2$cal_plan_family("DesignSeqOneByOneKK21"), "matched designs unknown")
})

test_that("roster enumeration matches the classes and rows the runner runs, without fitting", {
	skip_if_not(edi_ok, "EDI not installed")
	samples = list(list("continuous", "DesignFixedBernoulli", c(50L, 200L)), list("incidence", "DesignFixedBinaryMatch", 50L),
		list("ordinal", "DesignSeqOneByOneKK21", 50L), list("count", "DesignFixedBernoulli@prob_T=0.2", c(50L, 200L)),
		list("survival", "DesignFixedMatchingGreedyPairSwitching", 50L))
	for (s in samples) {
		rt = s[[1L]]; dl = s[[2L]]
		r = roster_env$cal_roster_enumerate(rt, dl, 50L)
		for (n in s[[3L]]) {
			# The runner's class set (run_calibration_study.R: cal_study_classes()) at the shard's n.
			expect_identical(r$inf_class, roster_env$cal_study_classes(rt, dl, n), info = paste(rt, dl, n))
			des = roster_env$cal_study_throwaway_design(rt, dl, n)
			for (k in seq_len(nrow(r))) {
				# One class alone (the runner's --only) enumerates the same rows as the roster counts.
				tk = get("cal_task_list", envir = globalenv())(des, r$inf_class[[k]], roster_env$CAL_STUDY_TIER1_METHODS)
				expect_identical(length(tk), r$n_size[[k]], info = paste(rt, dl, n, r$inf_class[[k]]))
				expect_identical(sum(vapply(tk, function(t) t$method != "rand", logical(1L))), r$n_cov[[k]], info = paste(rt, dl, n, r$inf_class[[k]]))
			}
		}
		expect_true(all(r$n_cov <= r$n_size))
		expect_true(all(r$n_size >= 1L))
	}
})

test_that("roster costs come from the previous campaign where the class existed, else the default", {
	skip_if_not(edi_ok, "EDI not installed")
	root = tempfile("calcost"); dir.create(root)
	x = env$cal_synth_campaign(root, "2026-11-01-prev0000", cal_dir)
	prev = roster_env$cal_roster_costs(env$cal_stats_read(file.path(x$cdir, "stats", "tests.csv.gz")))
	expect_setequal(prev$inf_class, c("InferenceContinLin", "InferenceContinOLS"))
	expect_true(all(prev$secs_n50 > 0))
	r = roster_env$cal_roster_build("continuous", c("DesignFixedBernoulli", "DesignFixediBCRD"), 50L, prev)
	hit = r$design == "DesignFixedBernoulli" & r$inf_class %in% prev$inf_class
	expect_true(any(hit))
	for (k in which(hit)) expect_equal(r$secs_n50[[k]], prev$secs_n50[prev$design == r$design[[k]] & prev$inf_class == r$inf_class[[k]]])
	# A class the previous campaign never ran gets the default.
	new_cls = r[!(r$inf_class %in% prev$inf_class), ]
	expect_gt(nrow(new_cls), 0L)
	expect_true(all(new_cls$secs_n50 == roster_env$CAL_ROSTER_DEFAULT_SECS_N50))
	# A real published campaign's statistics, when available.
	pub = Sys.getenv("EDI_CAL_PUBLISHED_CAMPAIGN_DIR")
	if (nzchar(pub) && file.exists(file.path(pub, "stats", "tests.csv.gz"))) {
		pc = roster_env$cal_roster_costs(env$cal_stats_read(file.path(pub, "stats", "tests.csv.gz")))
		rr = roster_env$cal_roster_build("continuous", roster_env$cal_study_designs(), 50L, pc)
		expect_true(any(rr$secs_n50 != roster_env$CAL_ROSTER_DEFAULT_SECS_N50))
	}
})

test_that("the workflow's job graph is plan -> build -> roster -> shards -> analyze -> publish", {
	wf_path = NA_character_
	d = cal_dir
	for (i in 1:8) { f = file.path(d, ".github", "workflows", "calibration-study.yml"); if (file.exists(f)) { wf_path = f; break }; d = dirname(d) }
	skip_if(is.na(wf_path), "workflow not found")
	wf = readLines(wf_path)
	job_start = grep("^  [a-z]+:$", wf)
	jobs = sub("^  ([a-z]+):$", "\\1", wf[job_start])
	jobs = jobs[job_start > grep("^jobs:", wf)]
	expect_identical(jobs, c("plan", "build", "roster", "shards", "analyze", "publish"))
	block = function(j) { i = grep(paste0("^  ", j, ":$"), wf); e = c(job_start[job_start > i], length(wf) + 1L)[[1L]]; wf[i:(e - 1L)] }
	needs = function(j) {
		l = grep("^    needs:", block(j), value = TRUE)
		if (!length(l)) return(character())
		trimws(strsplit(gsub("[][]|needs:", "", l[[1L]]), ",")[[1L]])
	}
	expect_identical(needs("plan"), character())
	expect_identical(needs("build"), "plan")
	expect_identical(needs("roster"), c("plan", "build"))
	expect_identical(needs("shards"), c("plan", "roster"))
	expect_identical(needs("analyze"), c("plan", "roster", "shards"))
	expect_identical(needs("publish"), c("plan", "roster", "analyze"))
	# plan no longer computes the matrix; roster does, and shards read it from roster.
	expect_false(any(grepl("matrix:|wave:|plan_calibration_study.R", block("plan"))))
	expect_true(any(grepl("matrix: ${{ steps.plan.outputs.matrix }}", block("roster"), fixed = TRUE)))
	expect_true(any(grepl("fromJSON(needs.roster.outputs.matrix)", block("shards"), fixed = TRUE)))
	expect_true(any(grepl("build_calibration_study_roster.R", block("roster"), fixed = TRUE)))
	# The EDI build cache is keyed per runner OS; on a miss (an image rollout) roster compiles EDI itself rather than
	# failing (owner ruling 2026-11-11, d05eee79; it used to be fail-on-cache-miss).
	expect_false(any(grepl("fail-on-cache-miss", block("roster"), fixed = TRUE)))
	expect_true(any(grepl("calibration-study-edi-${ImageOS:-unknown}-", block("roster"), fixed = TRUE)))
	expect_true(any(grepl("if: steps.edic.outputs.cache-hit != 'true'", block("roster"), fixed = TRUE)))
	# A failing roster job is a check bug, never a statistical failure; a roster failure stops analyze and publish.
	expect_true(any(grepl("Calibration CI bug", block("roster"), fixed = TRUE)))
	expect_true(any(grepl("needs.roster.result == 'success'", block("analyze"), fixed = TRUE)))
	expect_true(any(grepl("needs.roster.result == 'success'", block("publish"), fixed = TRUE)))
	# The roster is published with the campaign and the analysis plans from it.
	expect_true(any(grepl('roster.csv "results/campaigns/$C/roster.csv"', block("analyze"), fixed = TRUE)))
	expect_true(any(grepl('--roster "$d/roster.csv"', block("analyze"), fixed = TRUE)))
	# Only the Gate verdict step can fail for a statistical reason: it stays the analyze job's last step.
	an = block("analyze")
	expect_identical(tail(grep("^      - ", an, value = TRUE), 1L), "      - name: Gate verdict")
})

test_that("the planner puts a finished block's confirmation right after it and packs cheap classes into one shard", {
	root = tempfile("calplan"); dir.create(root)
	roster_path = file.path(root, "roster.csv")
	utils::write.csv(env$cal_synth_roster(), roster_path, row.names = FALSE)
	cdir = file.path(root, "c"); dir.create(file.path(cdir, "summary"), recursive = TRUE)
	args = function(...) c("--campaign-dir", shQuote(cdir), "--roster", shQuote(roster_path), "--null-reps", 100, "--power-reps", 50, "--wave-size", 256,
		"--confirm-reps", 200, ...)
	ids = function(out) regmatches(out, gregexpr('"id":"[^"]+"', out))[[1L]]
	out = run_script("plan_calibration_study.R", args())
	expect_null(attr(out, "status"))
	first = ids(out[[1L]])
	# Packed: one shard holds both continuous classes of a cell (cheap), so there are fewer shards than units.
	expect_true(any(grepl("-p2-", first)))
	groups = regmatches(out[[1L]], gregexpr('"group":"[^"]*"', out[[1L]]))[[1L]]
	expect_true(any(grepl("InferenceContinLin;InferenceContinOLS", groups, fixed = TRUE)))
	# --pack-minutes 0: one class per shard.
	one = run_script("plan_calibration_study.R", args("--pack-minutes", 0))
	expect_false(any(grepl(";", regmatches(one[[1L]], gregexpr('"group":"[^"]*"', one[[1L]]))[[1L]], fixed = TRUE)))
	# Finish ContinLin's null block (every design and n) and flag one of its tests.
	plan = read_csv_fast(text = run_plan_csv <- {
		f = tempfile(fileext = ".csv")
		run_script("plan_calibration_study.R", args("--plan-only", "--plan-out", shQuote(f)))
		paste(readLines(f), collapse = "\n")
	}, stringsAsFactors = FALSE)
	blk = plan[plan$inf_class == "InferenceContinLin" & plan$effect == "null", ]
	ledger = data.frame(response_type = blk$response_type, design = blk$design, n = blk$n, effect = blk$effect, only = "InferenceContinLin", exclude = "",
		reps_done = "1:100", n_done = 100L, n_failed = 0L, n_skipped = 0L, cores = 4L, elapsed_sec = 10, secs_per_rep = 0.4, id = paste0("s", seq_len(nrow(blk))),
		stringsAsFactors = FALSE)
	utils::write.csv(ledger, file.path(cdir, "ledger.csv"), row.names = FALSE)
	utils::write.csv(data.frame(response_type = "continuous", design = "DesignFixedBernoulli", prob_T = 0.5, inf_class = "InferenceContinLin", formula = "~.",
		n_nominal = 200L, effect_label = "null", inf_procedure = "wald", metric = "size"), file.path(cdir, "summary", "confirm_cells.csv"), row.names = FALSE)
	out2 = run_script("plan_calibration_study.R", args())
	expect_null(attr(out2, "status"))
	i2 = ids(out2[[1L]])
	conf = grep("confirm", i2)
	expect_length(conf, 1L)
	expect_true(grepl("confirm-ContinLin", i2[conf]))
	expect_true(grepl('"reps":"10001:10200"', out2[[1L]], fixed = TRUE))
	# Right after its block: before every shard of the next class (OLS) and of the incidence class.
	expect_lt(conf, min(grep("OLS|Logit", i2)))
	# A flag in a block that is NOT finished plans no confirmation.
	utils::write.csv(data.frame(response_type = "continuous", design = "DesignFixedBernoulli", prob_T = 0.5, inf_class = "InferenceContinOLS", formula = "~.",
		n_nominal = 200L, effect_label = "null", inf_procedure = "wald", metric = "size"), file.path(cdir, "summary", "confirm_cells.csv"), row.names = FALSE)
	out3 = run_script("plan_calibration_study.R", args())
	expect_length(grep("confirm", ids(out3[[1L]])), 0L)
})

test_that("Benjamini-Hochberg over the whole plan never withdraws a flag as tests come in", {
	set.seed(20261110)
	for (rep in 1:200) {
		m_total = sample(20:300, 1L)
		p_all = stats::runif(m_total)^sample(1:4, 1L)
		order_in = sample(m_total)
		flagged_prev = integer()
		step = sort(unique(c(sample(m_total, 6L), m_total)))
		for (k in step) {
			entered = order_in[seq_len(k)]
			q = env$cal_bh_q(p_all[entered], m_total)
			# Same as padding the family with p = 1 for every test that has not run.
			expect_equal(q, stats::p.adjust(c(p_all[entered], rep(1, m_total - k)), "BH")[seq_len(k)])
			flagged = entered[q < 0.05]
			expect_true(all(flagged_prev %in% flagged))
			flagged_prev = flagged
		}
	}
	# The family size is the plan's, never smaller than the tests that have run.
	expect_equal(env$cal_bh_q(c(0.001, 0.2), 2), stats::p.adjust(c(0.001, 0.2), "BH"))
	expect_equal(env$cal_bh_q(c(0.001, 0.2), 1000), pmin(1, c(0.001 * 1000 / 1, 0.2 * 1000 / 2)))
	expect_equal(env$cal_bh_q(c(0.001, 0.2), NULL), stats::p.adjust(c(0.001, 0.2), "BH"))
	expect_identical(env$cal_bh_q(numeric(), 10), numeric())
})

synth = function(final = FALSE, id = "2026-11-10-abcd1234") {
	root = tempfile("calsyn"); dir.create(root)
	x = env$cal_synth_campaign(root, id, cal_dir)
	d = x$cdir
	a = c("--stats-dir", shQuote(file.path(d, "stats")), "--out-dir", shQuote(file.path(d, "summary")), if (final) "--final")
	expect_null(attr(run_script("convergence_calibration_study.R", a[1:4], if (final) "--final"), "status"))
	res = run_script("analyze_calibration_study.R", a)
	expect_null(attr(res, "status"), info = paste(res, collapse = "\n"))
	list(root = root, cdir = d, plan = x$plan)
}

test_that("a campaign's gate uses m_total, enters only completed cells, and its confirmation level is fixed in advance", {
	s = synth()
	m_total = sum(s$plan$n_tests)
	conf = read_csv_fast(file.path(s$cdir, "summary", "confirmation_summary.csv"), stringsAsFactors = FALSE)
	expect_gt(nrow(conf), 0L)
	expect_true(all(abs(conf$confirm_alpha - 0.01 / m_total) < 1e-15))
	# Only the classes with a completed cell have tests in the family: ContinLin (all) and OLS (n = 50, 200 null); never Logit.
	expect_false("InferenceIncidLogit" %in% conf$inf_class)
	expect_false(any(conf$inf_class == "InferenceContinOLS" & conf$n == 1000))
	# q-values use the plan's m: the smallest possible q is p * m_total / rank.
	expect_true(all(conf$q * 1 >= conf$p * m_total / nrow(conf) - 1e-12))
	# Adding flags (a second campaign with more results) leaves the level unchanged.
	s2 = synth(id = "2026-11-10-ffff0000")
	conf2 = read_csv_fast(file.path(s2$cdir, "summary", "confirmation_summary.csv"), stringsAsFactors = FALSE)
	expect_true(all(abs(conf2$confirm_alpha - 0.01 / m_total) < 1e-15))
	# Flagged tests are not decided without their confirmation replicates (not final, none run).
	expect_true(all(grepl("pending", conf$status)))
	md = paste(readLines(file.path(s$cdir, "summary", "calibration_summary.md")), collapse = "\n")
	expect_match(md, sprintf("over all %d tests of the plan", m_total), fixed = TRUE)
	expect_match(md, "a flag is never withdrawn", fixed = TRUE)
})

test_that("class status and the convergence provisional flag are per class", {
	s = synth()
	cs = read_csv_fast(file.path(s$cdir, "summary", "class_status.csv"), stringsAsFactors = FALSE)
	row = function(cl) cs[cs$inf_class == cl, ]
	expect_identical(row("InferenceContinLin")$status, "complete")
	expect_identical(row("InferenceContinLin")$verdict, "pass")
	expect_identical(row("InferenceContinOLS")$null_status, "in progress")
	expect_identical(row("InferenceContinOLS")$nonnull_status, "not started")
	expect_identical(row("InferenceContinOLS")$verdict, "pending confirmation")
	expect_identical(row("InferenceIncidLogit")$status, "not started")
	cv = read_csv_fast(file.path(s$cdir, "summary", "convergence_summary.csv"), stringsAsFactors = FALSE, colClasses = c(formula = "character"))
	expect_false(any(cv$provisional[cv$inf_class == "InferenceContinLin"]))
	expect_true(all(cv$provisional[cv$inf_class == "InferenceContinOLS"]))
})

test_that("per-class pages and figures render from a three-n campaign: links resolve, back-links at both ends, no double blanks", {
	s = synth()
	d = s$cdir
	expect_null(attr(run_script("plot_calibration_study.R", "--summary-dir", shQuote(file.path(d, "summary")), "--out-dir", shQuote(file.path(d, "figures")),
		"--fragment", shQuote(file.path(d, "figures.md")), "--fig-prefix", "figures/", "--class-figures"), "status"))
	for (f in c("class-ContinLin.png", "class-ContinLin-dark.png", "class-ContinOLS.png", "class-ContinOLS-dark.png"))
		expect_true(file.exists(file.path(d, "figures", f)), info = f)
	res = run_script("render_calibration_study_readme.R", "--results-dir", shQuote(s$root), "--campaign", "2026-11-10-abcd1234", "--repo", "owner/repo")
	expect_null(attr(res, "status"), info = paste(res, collapse = "\n"))
	back = "[← Campaign 2026-11-10-abcd1234 summary](README.md)"
	md_links = function(x) sub("^\\]\\((.*)\\)$", "\\1", unlist(regmatches(x, gregexpr("\\]\\(([^)]+)\\)", x))))
	master = readLines(file.path(d, "README.md"))
	expect_true(any(grepl("(classes.md)", master, fixed = TRUE)))
	expect_true(any(grepl("Classes: 1 complete, 1 in progress, 1 not started", master, fixed = TRUE)))
	pages = c("classes.md", "class-ContinLin.md", "class-ContinOLS.md", "class-IncidLogit.md")
	for (pg in pages) {
		expect_true(file.exists(file.path(d, pg)), info = pg)
		x = readLines(file.path(d, pg))
		expect_identical(x[[1L]], back, info = pg)
		expect_identical(x[[length(x)]], back, info = pg)
		blank = !nzchar(trimws(x))
		expect_false(any(blank[-1L] & blank[-length(x)]), info = pg)
		l = unique(md_links(x)); l = l[!grepl("^(https?:|#)", l)]
		expect_true(all(file.exists(file.path(d, sub("#.*$", "", l)))), info = pg)
		# Embedded figures exist (the picture element's src / srcset).
		src = unlist(regmatches(x, gregexpr('(src|srcset)="[^"]+"', x)))
		src = sub('^[a-z]+="(.*)"$', "\\1", src)
		expect_true(all(file.exists(file.path(d, src))), info = pg)
	}
	idx = readLines(file.path(d, "classes.md"))
	expect_true(all(vapply(c("class-ContinLin.md", "class-ContinOLS.md", "class-IncidLogit.md"), function(f) any(grepl(f, idx, fixed = TRUE)), logical(1L))))
	ols = readLines(file.path(d, "class-ContinOLS.md"))
	expect_true(any(grepl("^\\| Fixed:Bernoulli \\| 200 \\|", ols)))
	expect_true(any(grepl("**FAIL**", ols, fixed = TRUE)))
	expect_true(any(grepl("No results for this class yet", readLines(file.path(d, "class-IncidLogit.md")), fixed = TRUE)))
})

# ---- Amendments B and C: the designs are discovered from the installed package --------------------------------------

BASE_DESIGNS = c("DesignFixedBernoulli", "DesignFixediBCRD", "DesignFixedBlocking", "DesignFixedRerandomization",
	"DesignFixedMatchingGreedyPairSwitching", "DesignFixedOptimal", "DesignFixedBinaryMatch", "DesignFixedGreedy",
	"DesignFixedGreedyDOptimal", "DesignFixedOptimalBlocks", "DesignSeqOneByOneBernoulli", "DesignSeqOneByOneiBCRD",
	"DesignSeqOneByOneEfron", "DesignSeqOneByOneAtkinson", "DesignSeqOneByOnePocockSimon", "DesignSeqOneByOneRandomBlockSize",
	"DesignSeqOneByOneSPBR", "DesignSeqOneByOneUrn", "DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise")
UNEQUAL_DESIGNS = c("DesignFixedBernoulli", "DesignFixediBCRD", "DesignFixedBlocking", "DesignFixedGreedy", "DesignFixedGreedyDOptimal",
	"DesignFixedOptimal", "DesignFixedOptimalBlocks", "DesignFixedRerandomization", "DesignSeqOneByOneBernoulli", "DesignSeqOneByOneiBCRD",
	"DesignSeqOneByOneRandomBlockSize", "DesignSeqOneByOneSPBR")

test_that("discovery on the installed EDI: the 21 designs plus @prob_T=0.2 for exactly the unequal-allocation-capable ones", {
	skip_if_not(edi_ok, "EDI not installed")
	got = roster_env$cal_study_designs()
	expect_setequal(got, c(BASE_DESIGNS, paste0(UNEQUAL_DESIGNS, "@prob_T=0.2")))
	expect_length(got, 33L)
	expect_false(anyDuplicated(got) > 0L)
	# The registry is read by name: designs that refuse unequal allocation get no 0.2 label.
	for (d in setdiff(BASE_DESIGNS, UNEQUAL_DESIGNS)) expect_false(paste0(d, "@prob_T=0.2") %in% got, info = d)
	expect_false(roster_env$cal_study_supports_unequal("DesignSeqOneByOneEfron"))
	expect_false(roster_env$cal_study_supports_unequal("DesignSeqOneByOneKK21"))
	expect_true(roster_env$cal_study_supports_unequal("DesignFixediBCRD"))
	# Every kept design really accepts prob_T = 0.2 (an instance, not the name).
	for (d in UNEQUAL_DESIGNS) {
		des = do.call(get(d, asNamespace("EDI"))$new, c(list(n = 20, response_type = "continuous", prob_T = 0.2), roster_env$cal_study_design_extras(d, 0.2)))
		expect_true(EDI:::design_supports_unequal_allocation(des), info = d)
	}
	# Run order: Fixed before Seq, the known order, a design's 0.2 variant next to it.
	base_order = sub("@.*$", "", got)
	expect_identical(unique(base_order), BASE_DESIGNS)
	expect_identical(got[1:2], c("DesignFixedBernoulli", "DesignFixedBernoulli@prob_T=0.2"))
	r = roster_env$cal_study_design_rank(got)
	expect_false(is.unsorted(r))
	# Exported Design* generators are all concrete: nothing slips through but the documented exclusions.
	ex = sort(grep("^Design", getNamespaceExports("EDI"), value = TRUE))
	expect_setequal(setdiff(ex, roster_env$cal_study_design_names()), names(roster_env$CAL_STUDY_EXCLUDED_DESIGNS))
	expect_true(all(names(roster_env$CAL_STUDY_EXCLUDED_DESIGNS) %in% ex))
	expect_true(all(nzchar(roster_env$CAL_STUDY_EXCLUDED_DESIGNS)))
})

test_that("a newly exported design is included automatically; non-generators, abstract bases and exclusions are filtered by inspection", {
	skip_if_not(edi_ok, "EDI not installed")
	gen = get("DesignFixedBernoulli", asNamespace("EDI"))
	resolve = function(n) if (n %in% c("DesignHelperFunction")) function() NULL else if (n == "DesignNotThere") NULL else gen
	exports = c(getNamespaceExports("EDI"), "DesignFixedNewcomer", "DesignSeqOneByOneNewcomer", "DesignHelperFunction", "DesignNotThere")
	supports = function(n) roster_env$cal_study_supports_unequal(sub("Newcomer$", "Bernoulli", n))
	real = function(n) get0(n, asNamespace("EDI"), inherits = FALSE)
	res = function(n) if (n %in% c("DesignFixedNewcomer", "DesignSeqOneByOneNewcomer")) gen else if (n %in% c("DesignHelperFunction", "DesignNotThere")) resolve(n) else real(n)
	got = roster_env$cal_study_designs(exports = exports, resolve = res, supports_unequal = supports)
	expect_true(all(c("DesignFixedNewcomer", "DesignFixedNewcomer@prob_T=0.2", "DesignSeqOneByOneNewcomer") %in% got))
	expect_false(any(grepl("HelperFunction|NotThere", got)))
	# New designs follow the known ones of their family, alphabetically; Fixed still before Seq.
	b = unique(sub("@.*$", "", got))
	expect_identical(b[11L], "DesignFixedNewcomer")  # after the 10 known Fixed designs (index 11)
	expect_identical(tail(b, 1L), "DesignSeqOneByOneNewcomer")
	# Abstract bases are filtered by the package's own flag, not by name.
	abs_got = roster_env$cal_study_designs(exports = c(getNamespaceExports("EDI"), "DesignFixedAbstractish"), resolve = function(n) if (n == "DesignFixedAbstractish") gen else real(n),
		is_abstract = function(n) n == "DesignFixedAbstractish")
	expect_false("DesignFixedAbstractish" %in% abs_got)
	# A discovered design that cannot be built on the study's data fails loudly, naming it and the remedy.
	expect_identical(roster_env$cal_study_smoke_check_designs(c("DesignFixedBernoulli", "DesignSeqOneByOneUrn")), TRUE)
	err = tryCatch(roster_env$cal_study_smoke_check_designs(c("DesignFixedBernoulli", "DesignFixedNewcomer")), error = function(e) conditionMessage(e))
	expect_match(err, "Calibration CI bug", fixed = TRUE)
	expect_match(err, "DesignFixedNewcomer", fixed = TRUE)
	expect_match(err, "CAL_STUDY_EXCLUDED_DESIGNS", fixed = TRUE)
	expect_false(grepl("DesignFixedBernoulli (", err, fixed = TRUE))
})

test_that("the planner has no hard-coded design list: designs and their order come from the campaign roster", {
	for (f in c("calibration_study_plan_common.R", "plan_calibration_study.R", "analyze_calibration_study.R", "convergence_calibration_study.R",
			"render_calibration_study_readme.R", "plot_calibration_study.R", "run_calibration_study.R", "build_calibration_study_roster.R")) {
		txt = paste(readLines(file.path(cal_dir, f)), collapse = "\n")
		expect_false(grepl("CAL_PLAN_DESIGNS|CAL_STUDY_DESIGNS", txt), info = f)
	}
	expect_false(exists("CAL_PLAN_DESIGNS", envir = env))
	# A roster naming a design the code never heard of plans it, ordered by the roster's design_rank.
	r = env$cal_synth_roster()
	r$design[r$design == "DesignFixediBCRD"] = "DesignFixedBrandNew"
	r$design_rank[r$design == "DesignFixedBrandNew"] = 1L
	r$design_rank[r$design == "DesignFixedBernoulli"] = 2L
	u = env$cal_plan_units(r, null_reps = 10L, power_reps = 5L)
	lin = u[u$inf_class == "InferenceContinLin" & u$effect == "null", ]
	expect_identical(unique(lin$design), c("DesignFixedBrandNew", "DesignFixedBernoulli"))
	# The planner CLI takes "all" from the roster and refuses designs that are not in it.
	f = tempfile(fileext = ".csv"); utils::write.csv(r, f, row.names = FALSE)
	expect_null(attr(run_script("plan_calibration_study.R", "--plan-only", "--roster", shQuote(f)), "status"))
	out = run_script("plan_calibration_study.R", "--plan-only", "--roster", shQuote(f), "--designs", "DesignFixedNotInRoster")
	expect_false(is.null(attr(out, "status")))
	expect_true(any(grepl("not in the campaign roster", out, fixed = TRUE)))
	# design_rank is a required roster column.
	f2 = tempfile(fileext = ".csv"); utils::write.csv(r[setdiff(names(r), "design_rank")], f2, row.names = FALSE)
	out = run_script("plan_calibration_study.R", "--plan-only", "--roster", shQuote(f2))
	expect_true(any(grepl("lacks columns", out, fixed = TRUE)))
})

test_that("the roster carries the discovered designs with their rank, and every @prob_T=0.2 label is handled by the consumers generically", {
	skip_if_not(edi_ok, "EDI not installed")
	labels = c("DesignFixedBernoulli", "DesignFixedBernoulli@prob_T=0.2", "DesignFixediBCRD@prob_T=0.2", "DesignSeqOneByOneSPBR@prob_T=0.2")
	ro = roster_env$cal_roster_build("continuous", labels, 50L)
	expect_setequal(unique(ro$design), labels)
	expect_true(all(c("design_rank", "design") %in% names(ro)))
	expect_identical(ro$design_rank, roster_env$cal_study_design_rank(ro$design))
	# Construction: the label becomes class + prob_T, whatever the design; the effective n ignores prob_T except pair-switching.
	for (l in labels) {
		e = get("cal_plan_entry", envir = globalenv())(l)
		expect_identical(e$prob_T, if (grepl("@", l)) 0.2 else 0.5)
		des = roster_env$cal_study_throwaway_design("continuous", l, 50L)
		expect_equal(des$get_prob_T(), e$prob_T)
		w = des$get_w()
		expect_lt(abs(mean(w == 1) - e$prob_T), 0.2)
	}
	# Registry: unequal allocation uses the smaller arm for any design label; balanced labels do not.
	conv = new.env(parent = baseenv())
	sys.source(file.path(dirname(dirname(dirname(cal_dir))), "R", "EDI", "R", "inference_procedure_regime.R"), envir = conv)
	for (d in UNEQUAL_DESIGNS) {
		x = conv$inference_convergence_expectation(paste0(d, "@prob_T=0.2"), "InferenceContinLin", c("wald", "score"))
		expect_identical(x$n_eff, c("n_min_arm", "n_min_arm"), info = d)
		expect_identical(x$n_eff_layer, c("design", "design"), info = d)
	}
	expect_identical(conv$inference_convergence_expectation("DesignFixediBCRD", "InferenceContinLin", "wald")$n_eff, "n")
	expect_identical(conv$inference_convergence_expectation("DesignFixedBernoulli@prob_T=0.3", "InferenceContinLin", "wald")$n_eff, "n_min_arm")
	# Finite-sample procedures stay exact-n (the entry is restricted to the asymptotic ones).
	expect_false(conv$inference_convergence_expectation("DesignFixediBCRD@prob_T=0.2", "InferenceContinLin", "rand")$n_eff == "n_min_arm")
	expect_identical(conv$inference_convergence_validate(), character(0))
})
