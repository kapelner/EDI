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

# v1.0.5 TODO-200: the calibration gate (R/package_tests/calibration/analyze_calibration_study.R)
# tests a cell against a rate-derived level (new_feature_plans/v1_0_5/calibration_rate_derived_gate.md)
# that replaces TODO-192's step schedule: finite-sample procedures 0.05 / 0.95 at every n;
# asymptotic procedures with a known order a size min(0.10, 0.05 + c_a n_eff^-a) (cap reached at
# n_eff = 50), coverage 1 minus that; unknown order the cap below the campaign's largest n and the
# a = 1 level at it; expected order 0 (design mismatch) one-sided; a `slower` convergence verdict
# is held to the nominal level at the largest n. No EDI needed (the analyze job has none).

gate_repo_dir = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		d = file.path(dir, "R", "package_tests", "calibration")
		if (file.exists(file.path(d, "analyze_calibration_study.R"))) return(d)
		dir = dirname(dir)
	}
	NA_character_
}
cal_dir = gate_repo_dir()
skip_if(is.na(cal_dir), "calibration scripts not found")
cal_env = new.env(parent = globalenv())
sys.source(file.path(cal_dir, "..", "..", "EDI", "R", "inference_procedure_regime.R"), envir = cal_env)
sys.source(file.path(cal_dir, "calibration_study_stats.R"), envir = cal_env)

lv = function(regime, order, n_eff, basis = "assumed_default", largest = FALSE) {
	cal_env$cal_gate_levels(regime, order, rep(basis, length(regime)), n_eff, rep(largest, length(regime)))
}

test_that("the step schedule is gone and the two constants are named", {
	expect_false(exists("CAL_GATE_ASYMPTOTIC_SCHEDULE", envir = cal_env))
	expect_equal(cal_env$CAL_GATE_CAP, 0.10)
	expect_equal(cal_env$CAL_GATE_N_CAP, 50)
})

test_that("cal_gate_levels() gives the rate-derived levels", {
	a1 = lv(rep("asymptotic", 6), 1, c(10, 50, 100, 200, 1000, 1e6))
	expect_equal(a1$size, c(0.10, 0.10, 0.075, 0.0625, 0.0525, 0.05 + 0.05 * 50 / 1e6))
	expect_equal(a1$coverage, 1 - a1$size)
	expect_identical(a1$rule, c("cap", "cap", "rate", "rate", "rate", "rate"))
	a05 = lv(rep("asymptotic", 3), 0.5, c(50, 200, 1000))
	expect_equal(a05$size, c(0.10, 0.05 + 0.05 * sqrt(50 / 200), 0.05 + 0.05 * sqrt(50 / 1000)))
	fin = lv(rep("finite_sample", 3), Inf, c(50, 200, 1000), basis = "theory")
	expect_equal(fin$size, rep(0.05, 3))
	expect_equal(fin$coverage, rep(0.95, 3))
	expect_identical(fin$rule, rep("finite", 3))
	expect_equal(nrow(lv(character(0), numeric(0), numeric(0))), 0L)
})

test_that("unknown order: the cap below the campaign's largest n, the a = 1 level at it; mismatch uses a = 1", {
	u = cal_env$cal_gate_levels(rep("asymptotic", 4), c(NA, NA, 1, NA), c("unknown", "unknown", "unknown", "assumed_default"),
		c(200, 1000, 1000, 1000), c(FALSE, TRUE, TRUE, TRUE))
	expect_equal(u$size[1:2], c(0.10, 0.0525))
	expect_identical(u$rule[1:3], rep("unknown", 3))
	expect_equal(u$size[3], 0.0525)   # basis unknown wins over a numeric order
	expect_identical(u$rule[4], "unknown")   # NA order is unknown whatever the basis says
	m = lv(rep("asymptotic", 2), 0, c(50, 200), basis = "literature")
	expect_identical(m$rule, rep("mismatch", 2))
	expect_equal(m$size, c(0.10, 0.0625))
})

test_that("an unknown procedure label errors", {
	expect_error(cal_env$cal_gate_regime("mystery", regimes = cal_env$EDI_INFERENCE_PROCEDURE_REGIME), "mystery")
	expect_identical(cal_env$cal_gate_regime(c("wald", "rand"), regimes = cal_env$EDI_INFERENCE_PROCEDURE_REGIME),
		c("asymptotic", "finite_sample"))
})

# Synthetic stats dir from a spec: one null cell per row (rep counts, rejections, coverage hits, bias).
synthetic_gate = function(spec, accepted = NULL, convergence = NULL, final = FALSE) {
	dir = tempfile("calgate")
	dir.create(dir)
	u = cal_env$cal_stats_u_cols()
	def = list(response_type = "continuous", design = "DesignFixedBernoulli", prob_T = 0.5, inf_class = "InferenceContinLin",
		formula = "~.", reps = 1000L, effect_label = "null", bias = 0)
	for (nm in names(def)) if (is.null(spec[[nm]])) spec[[nm]] = def[[nm]]
	if (is.null(spec$cov_miss)) spec$cov_miss = spec$rej
	tests = data.frame(response_type = spec$response_type, design = spec$design, prob_T = spec$prob_T, inf_class = spec$inf_class,
		formula = spec$formula, n = spec$n, n_nominal = spec$n, effect_label = spec$effect_label, stage = "screen",
		inf_procedure = spec$inf_procedure, reps = spec$reps, n_p = spec$reps, rej = spec$rej, rej10 = spec$rej, n_ci = spec$reps,
		cov = spec$reps - spec$cov_miss, fit_secs = 1, stringsAsFactors = FALSE)
	tests[u] = lapply(seq_along(u), function(j) 0L)
	est = unique(cbind(tests[c("response_type", "design", "prob_T", "inf_class", "formula", "n", "n_nominal", "effect_label", "stage")],
		bias = spec$bias, reps = spec$reps))
	est = transform(est, null_value = 0, estimand_true = 0, n_est = reps, n_below = reps / 2, n_above = reps / 2,
		sum_d = reps * bias, sum_d2 = reps * (1 + bias^2))
	est$bias = NULL
	utils::write.csv(tests, gzfile(file.path(dir, "tests.csv.gz")), row.names = FALSE)
	utils::write.csv(est, gzfile(file.path(dir, "est.csv.gz")), row.names = FALSE)
	out = file.path(dir, "out")
	dir.create(out)
	acc = file.path(dir, "accepted.csv")
	if (is.null(accepted)) writeLines("response_type,design,prob_T,inf_class,inf_procedure,formula,n,metric,accepted_level,reason", acc)
	else utils::write.csv(accepted, acc, row.names = FALSE)
	if (!is.null(convergence)) {
		# The convergence study on the same stats, as the analyze job runs it before the gate.
		system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(cal_dir, "convergence_calibration_study.R")),
			"--stats-dir", shQuote(dir), "--out-dir", shQuote(out)), stdout = TRUE, stderr = TRUE)
	}
	res = suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
		c(shQuote(file.path(cal_dir, "analyze_calibration_study.R")), "--stats-dir", shQuote(dir), "--out-dir", shQuote(out),
			"--accepted", shQuote(acc), if (final) "--final"), stdout = TRUE, stderr = TRUE))
	list(res = res, out = out, status = attr(res, "status"))
}
summary_of = function(g) read_csv_fast(file.path(g$out, "calibration_summary.csv"), stringsAsFactors = FALSE, colClasses = c(formula = "character"))
failing = function(g) {
	s = summary_of(g)
	stats::setNames(s$fail_size | s$fail_coverage, paste(s$inf_procedure, s$n))
}

test_that("size 0.07 passes for an asymptotic procedure at n = 50, fails at n = 1000 and for a finite-sample one", {
	spec = data.frame(inf_procedure = rep(c("wald", "rand"), each = 2), n = rep(c(50, 1000), 2), rej = 210L, reps = 3000L)
	g = synthetic_gate(spec)
	expect_null(g$status)
	f = failing(g)
	expect_false(f[["wald 50"]])
	expect_true(f[["rand 50"]])
	expect_true(f[["wald 1000"]])
	expect_true(f[["rand 1000"]])
	s = summary_of(g)
	expect_equal(s$size_null[s$inf_procedure == "wald" & s$n == 50], 0.10)
	expect_equal(s$size_null[s$inf_procedure == "wald" & s$n == 1000], 0.0525)
	expect_equal(s$size_null[s$inf_procedure == "rand" & s$n == 50], 0.05)
	expect_identical(s$rule_size[s$inf_procedure == "wald" & s$n == 50], "cap")
	expect_identical(s$rule_size[s$inf_procedure == "wald" & s$n == 1000], "rate")
	expect_identical(s$rule_size[s$inf_procedure == "rand"], c("finite", "finite"))
	expect_true(all(c("regime", "size_null", "coverage_null", "n_eff", "n_eff_rule", "expected_order", "basis", "rule_size", "rule_coverage") %in% names(s)))
	expect_equal(s$n_eff[s$inf_procedure == "wald" & s$n == 1000], 1000)
	md = readLines(file.path(g$out, "calibration_summary.md"))
	expect_true(any(grepl("level 0.0525, rate", md, fixed = TRUE)))
})

test_that("an accepted row overrides the rate-derived level and is labelled", {
	acc = data.frame(response_type = "continuous", design = "DesignFixedBernoulli", prob_T = 0.5, inf_class = "InferenceContinLin",
		inf_procedure = "rand", formula = "~.", n = 50, metric = c("size", "coverage"), accepted_level = c(0.10, 0.90), reason = "test",
		stringsAsFactors = FALSE)
	spec = data.frame(inf_procedure = "rand", n = c(50, 1000), rej = 210L, reps = 3000L)
	g = synthetic_gate(spec, accepted = acc)
	f = failing(g)
	expect_false(f[["rand 50"]])
	expect_true(f[["rand 1000"]])
	s = summary_of(g)
	expect_identical(s$rule_size[s$n == 50], "accepted")
	expect_identical(s$rule_coverage[s$n == 50], "accepted")
})

test_that("unknown-rate cells: the cap below the campaign's largest n, the regular level at it, with the TODO note", {
	spec = data.frame(inf_procedure = "wald", inf_class = "InferenceCountZeroInflatedPoisson", response_type = "count",
		n = c(50, 200, 1000), rej = 270L, reps = 3000L)   # size 0.09
	g = synthetic_gate(spec)
	f = failing(g)
	expect_false(f[["wald 50"]])
	expect_false(f[["wald 200"]])
	expect_true(f[["wald 1000"]])
	s = summary_of(g)
	expect_identical(s$rule_size, rep("unknown", 3))
	expect_match(s$note[s$n == 1000], "rate unknown: open a TODO to establish it", fixed = TRUE)
})

test_that("a design-mismatch cell is gated one-sided: conservative passes (reported), anticonservative fails", {
	spec = data.frame(inf_procedure = "wald", inf_class = "InferenceAllSimpleAverageDiff", design = "DesignFixedBinaryMatch",
		n = c(50, 1000), rej = c(60L, 600L), cov_miss = c(60L, 600L), reps = c(3000L, 3000L))   # size 0.02 (conservative) and 0.20
	g = synthetic_gate(spec)
	s = summary_of(g)
	expect_identical(s$rule_size, c("mismatch", "mismatch"))
	f = failing(g)
	expect_false(f[["wald 50"]])
	expect_true(f[["wald 1000"]])
	expect_match(s$note[s$n == 50], "conservative (expected: model SE ignores the design)", fixed = TRUE)
	spec$rej = 60L; spec$cov_miss = 60L
	g2 = synthetic_gate(spec)
	expect_false(any(failing(g2)))
})

test_that("the rate check fails a cell converging slower than expected with a significant excess at its largest n", {
	# Wald, order 1 expected. Error 0.0025 * sqrt(1000 / n): order 1/2, and 0.0525 at n = 1000, exactly the
	# a = 1 level, so only the rate check (nominal 0.05 at the largest n) can fail it.
	ns = c(50, 200, 1000)
	reps = 400000L
	spec = data.frame(inf_procedure = "wald", n = ns, reps = reps, rej = as.integer(round(reps * (0.05 + 0.0025 * sqrt(1000 / ns)))),
		cov_miss = as.integer(round(reps * (0.05 + 0.0025 * sqrt(1000 / ns)))))
	g = synthetic_gate(spec, convergence = TRUE)
	expect_null(g$status)
	s = summary_of(g)
	s = s[order(s$n), ]
	expect_identical(s$rate_verdict_size, rep("slower", 3))
	expect_identical(s$rule_size, c("cap", "rate", "rate_check"))
	expect_equal(s$size_null[3], 0.05)
	expect_true(s$fail_size[3])
	expect_false(any(s$fail_size[1:2]))
	# Same cell at order 1: consistent, passes at the a = 1 level.
	spec$rej = as.integer(round(reps * (0.05 + 0.0025 * 1000 / ns))); spec$cov_miss = spec$rej
	g1 = synthetic_gate(spec, convergence = TRUE)
	s1 = summary_of(g1)
	expect_false(any(s1$fail_size))
	expect_false(any(s1$rule_size == "rate_check"))
	# Without the convergence file the rate check is off: the slower cell then passes.
	spec$rej = as.integer(round(reps * (0.05 + 0.0025 * sqrt(1000 / ns)))); spec$cov_miss = spec$rej
	g0 = synthetic_gate(spec, convergence = NULL)
	expect_null(g0$status)
	expect_false(any(summary_of(g0)$fail_size))
	expect_true(any(grepl("rate check off", g0$res)))
})

test_that("bias_sd_large_n flags |bias| / SD > 0.1 at the campaign's largest n only", {
	spec = data.frame(inf_procedure = "wald", n = c(50, 1000), rej = 150L, reps = 3000L, bias = 0.3)
	g = synthetic_gate(spec)
	b = read_csv_fast(file.path(g$out, "null_bias_summary.csv"), stringsAsFactors = FALSE)
	expect_true("bias_sd_large_n" %in% names(b))
	expect_identical(b$bias_sd_large_n[b$n_nominal == 1000], TRUE)
	expect_identical(b$bias_sd_large_n[b$n_nominal == 50], FALSE)
	spec$bias = 0.05
	b2 = read_csv_fast(file.path(synthetic_gate(spec)$out, "null_bias_summary.csv"), stringsAsFactors = FALSE)
	expect_false(any(b2$bias_sd_large_n))
	# Not part of the gate.
	expect_identical(readLines(file.path(g$out, "gate_failures.txt")), "0")
	expect_true(any(grepl("bias_sd_large_n", readLines(file.path(g$out, "calibration_summary.md")), fixed = TRUE)))
})

test_that("statistical edge cases never crash the analysis: no testable cell, a cell without finite results", {
	# Ten replicates: below MIN_FINITE, so every p is NA and the gate is empty.
	g = synthetic_gate(data.frame(inf_procedure = "wald", n = 50, rej = 1L, reps = 10L))
	expect_null(g$status)
	expect_identical(readLines(file.path(g$out, "gate_failures.txt")), "0")
	# A cell with no finite results at all (every fit failed): n_p = n_ci = 0.
	spec = data.frame(inf_procedure = c("wald", "score"), n = 50, rej = c(0L, 40L), reps = 1000L)
	dir = NULL
	g2 = synthetic_gate(spec)
	tf = file.path(dirname(g2$out), "tests.csv.gz")
	t = read_csv_fast(tf, stringsAsFactors = FALSE, colClasses = c(formula = "character"))
	t[t$inf_procedure == "wald", c("n_p", "n_ci", "rej", "rej10", "cov")] = 0
	cal_env$cal_stats_write(t, tf)
	res = suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(cal_dir, "analyze_calibration_study.R")),
		"--stats-dir", shQuote(dirname(g2$out)), "--out-dir", shQuote(g2$out), "--accepted", shQuote(file.path(dirname(g2$out), "accepted.csv"))),
		stdout = TRUE, stderr = TRUE))
	expect_null(attr(res, "status"), info = paste(res, collapse = "\n"))
	s = summary_of(g2)
	expect_true(is.na(s$size[s$inf_procedure == "wald"]))
	# Stats files absent: "No results yet", exit 0.
	empty = tempfile("calempty"); dir.create(empty)
	res3 = suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(cal_dir, "analyze_calibration_study.R")),
		"--stats-dir", shQuote(empty), "--out-dir", shQuote(file.path(empty, "out"))), stdout = TRUE, stderr = TRUE))
	expect_null(attr(res3, "status"))
	expect_identical(readLines(file.path(empty, "out", "gate_failures.txt")), "0")
})

test_that("an unknown procedure label stops the gate", {
	g = synthetic_gate(data.frame(inf_procedure = c("wald", "mystery"), n = 50, rej = 210L, reps = 3000L))
	expect_false(is.null(g$status))
	expect_true(any(grepl("mystery", g$res)))
})
