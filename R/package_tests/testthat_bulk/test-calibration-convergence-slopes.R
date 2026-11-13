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

# v1.0.5 TODO-199: convergence_calibration_study.R compares how fast the calibration
# study's size / coverage / bias error shrinks with n against the registry's expected order
# (TODO-193). Synthetic stats with a known truth; the script is run as the publish job
# runs it (Rscript, no EDI). Reported, never gated.

conv_repo_dir = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		d = file.path(dir, "R", "package_tests", "calibration")
		if (file.exists(file.path(d, "convergence_calibration_study.R"))) return(d)
		dir = dirname(dir)
	}
	NA_character_
}
cal_dir = conv_repo_dir()
skip_if(is.na(cal_dir), "calibration scripts not found")
cv_env = new.env(parent = globalenv())
sys.source(file.path(cal_dir, "convergence_calibration_study.R"), envir = cv_env)

test_that("conv_fit recovers the order of a clean binomial power law and the LR test separates orders", {
	neff = c(50, 200, 1000)
	m = rep(1e6, 3)
	k = round(m * (0.05 + 2.5 / neff))
	f = cv_env$conv_fit(neff, k, m, 0.05, "binom", 1)
	expect_equal(f$a_hat, 1, tolerance = 0.01)
	expect_lt(f$a_lo, 1); expect_gt(f$a_hi, 1)
	expect_gt(f$lr_p, 0.05)
	# d is the error at the smallest n_eff.
	expect_equal(f$d_hat, 2.5 / 50, tolerance = 1e-3)
	k2 = round(m * (0.05 + 0.3 / sqrt(neff)))
	f2 = cv_env$conv_fit(neff, k2, m, 0.05, "binom", 1)
	expect_equal(f2$a_hat, 0.5, tolerance = 0.01)
	expect_lt(f2$lr_p, 1e-6)
	expect_lt(f2$a_hi, 1)
	# fewer than 2 sizes: no fit
	expect_null(cv_env$conv_fit(50, 1000, 1e6, 0.05, "binom", 1))
})

test_that("conv_fit handles the normal (bias) likelihood", {
	neff = c(50, 200, 1000)
	f = cv_env$conv_fit(neff, 2 / neff, rep(1e-4, 3), 0, "normal", 1)
	expect_equal(f$a_hat, 1, tolerance = 0.01)
	expect_equal(f$d_hat, 2 / 50, tolerance = 1e-3)
})

test_that("conv_loglog gives slope -a with an SE, drops zero errors, and flags a sign change", {
	neff = c(50, 200, 1000)
	ll = cv_env$conv_loglog(neff, 2.5 / neff, rep(1e-4, 3))
	expect_equal(ll$slope, -1, tolerance = 1e-8)
	expect_true(is.finite(ll$se) && ll$se > 0)
	expect_false(ll$sign_change)
	expect_equal(ll$n, 3L)
	expect_null(cv_env$conv_loglog(neff, c(0.1, 0, 0), rep(1e-3, 3)))
	expect_true(cv_env$conv_loglog(neff, c(0.1, 0.02, -0.01), rep(1e-3, 3))$sign_change)
})

test_that("n_eff follows the registry rule (nominal), and flags the proxies", {
	expect_equal(cv_env$conv_n_eff(c("n", "n_pairs", "n_min_arm", "n_events"), c(100, 100, 100, 100), c(0.5, 0.5, 0.2, 0.5)), c(100, 50, 20, 100))
	expect_equal(cv_env$conv_n_eff_flag(c("n", "n_pairs_plus_reservoir", "n_events", "n_nonzero")),
		c("nominal", "nominal (pairs only: lower bound)", "proxy_n", "proxy_n"))
})

# One null cell per scenario (different procedures, so each gets its own verdict).
synthetic_cell = function(proc, n, rej = NULL, cov = NULL, inf_class = "InferenceContinLin", formula = "~.", prob_T = 0.5,
		n_p = 1e6, effect = "null") {
	u = cv_env_stats$cal_stats_u_cols()
	d = data.frame(response_type = "continuous", design = "DesignFixedBernoulli", prob_T = prob_T, inf_class = inf_class, formula = formula,
		n = n, n_nominal = n, effect_label = effect, stage = "screen", inf_procedure = proc, reps = n_p, n_p = n_p,
		rej = if (is.null(rej)) round(0.05 * n_p) else rej, rej10 = 0, n_ci = n_p, cov = if (is.null(cov)) round(0.95 * n_p) else cov,
		fit_secs = 1, stringsAsFactors = FALSE)
	d[u] = lapply(seq_along(u), function(j) 0L)
	d
}
cv_env_stats = new.env(parent = globalenv())
sys.source(file.path(cal_dir, "calibration_study_stats.R"), envir = cv_env_stats)

write_stats = function(tests, est) {
	dir = tempfile("convstats")
	dir.create(dir)
	utils::write.csv(tests, gzfile(file.path(dir, "tests.csv.gz")), row.names = FALSE)
	utils::write.csv(est, gzfile(file.path(dir, "est.csv.gz")), row.names = FALSE)
	dir
}
run_conv = function(dir, extra = character()) {
	out = file.path(dir, "out")
	res = suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
		c(shQuote(file.path(cal_dir, "convergence_calibration_study.R")), "--stats-dir", shQuote(dir), "--out-dir", shQuote(out), extra),
		stdout = TRUE, stderr = TRUE))
	list(res = res, out = out, status = attr(res, "status"))
}
synthetic_est = function(inf_class, formula, n, bias, n_est = 1e6, effect = "null", prob_T = 0.5) {
	data.frame(response_type = "continuous", design = "DesignFixedBernoulli", prob_T = prob_T, inf_class = inf_class, formula = formula,
		n = n, n_nominal = n, effect_label = effect, stage = "screen", null_value = 0, estimand_true = 0, reps = n_est, n_est = n_est,
		n_below = n_est / 2, n_above = n_est / 2, sum_d = bias * n_est, sum_d2 = n_est * (1 + bias^2), stringsAsFactors = FALSE)
}

test_that("the script reaches the planned verdicts on synthetic stats with known truth", {
	ns = c(50, 200, 1000)
	k_cons = round(1e6 * (0.05 + 2.5 / ns))
	k_slow = round(1e6 * (0.05 + 0.3 / sqrt(ns)))
	tests = rbind(
		synthetic_cell("wald", ns, rej = k_cons),                                  # consistent with order 1
		synthetic_cell("score", ns, rej = k_slow),                                 # slower (order 1/2 vs 1)
		synthetic_cell("gradient", ns),                                            # constant 0.05: undetermined
		synthetic_cell("rand", ns, rej = k_cons),                                  # finite-sample: not applicable
		synthetic_cell("wald", ns, cov = round(1e6 * (0.95 - 2.5 / ns)), inf_class = "InferenceContinOLS"),   # coverage error 2.5/n
		synthetic_cell("wald", ns, rej = round(1e6 * (0.05 + 2.5 / (ns * 0.2))), inf_class = "InferenceContinLin", formula = "~1",
			prob_T = 0.2))                                                         # n_min_arm: n_eff = 0.2 n
	est = rbind(
		synthetic_est("InferenceContinLin", "~.", ns, 2 / ns),                     # bias c / n
		synthetic_est("InferenceContinLin", "~1", ns, rep(0, 3)),                  # unbiased
		synthetic_est("InferenceAllSimpleAverageDiff", "~.", ns, 2 / ns))          # bias Inf in the registry: not applicable
	r = run_conv(write_stats(tests, est))
	expect_true(is.null(r$status) || r$status == 0L, info = paste(r$res, collapse = "\n"))
	s = read_csv_fast(file.path(r$out, "convergence_summary.csv"), stringsAsFactors = FALSE, colClasses = c(formula = "character"))
	pick = function(proc, metric, cls = "InferenceContinLin", formula = "~.", prob_T = 0.5) {
		x = s[s$inf_procedure == proc & s$metric == metric & s$inf_class == cls & s$formula == formula & s$prob_T == prob_T, ]
		expect_equal(nrow(x), 1L)
		x
	}
	a = pick("wald", "size")
	expect_identical(a$verdict, "consistent")
	expect_equal(a$a_hat, 1, tolerance = 0.02)
	expect_equal(a$expected_order, 1)
	expect_equal(a$loglog_slope, -1, tolerance = 0.02)    # both estimators agree on a noiseless cell
	expect_true(a$loglog_slope_se > 0)
	expect_identical(a$n_values, "50;200;1000")
	expect_identical(a$n_eff_rule, "n")
	expect_identical(a$basis, "assumed_default")
	expect_true(a$provisional)
	b = pick("score", "size")
	expect_identical(b$verdict, "slower")
	expect_equal(b$a_hat, 0.5, tolerance = 0.02)
	expect_lt(b$lr_p, 0.001)
	expect_equal(b$loglog_a, 0.5, tolerance = 0.1)
	expect_identical(pick("gradient", "size")$verdict, "undetermined")
	expect_identical(pick("rand", "size")$verdict, "not_applicable")
	expect_match(pick("rand", "size")$note, "finite-sample")
	cvg = pick("wald", "coverage", "InferenceContinOLS")
	expect_identical(cvg$verdict, "consistent")
	expect_equal(cvg$a_hat, 1, tolerance = 0.02)
	expect_gt(cvg$err_at_n_ref, 0)                       # undercoverage reported as a positive error
	nm = pick("wald", "size", formula = "~1", prob_T = 0.2)
	expect_identical(nm$n_eff_rule, "n_min_arm")
	expect_identical(nm$n_eff_values, "10;40;200")
	expect_identical(nm$verdict, "consistent")
	expect_equal(nm$a_hat, 1, tolerance = 0.02)
	bias = pick("(estimator)", "bias")
	expect_identical(bias$verdict, "consistent")
	expect_equal(bias$a_hat, 1, tolerance = 0.05)
	expect_identical(pick("(estimator)", "bias", formula = "~1")$verdict, "undetermined")
	expect_identical(pick("(estimator)", "bias", cls = "InferenceAllSimpleAverageDiff")$verdict, "not_applicable")
	pts = read_csv_fast(file.path(r$out, "convergence_points.csv"), stringsAsFactors = FALSE)
	expect_equal(sum(pts$cell_id == a$cell_id), 3L)
	md = readLines(file.path(r$out, "convergence_summary.md"))
	expect_true(any(grepl("slower", md)))
	expect_true(any(grepl("Provisional", md)))
	expect_true(any(grepl("0.007", md, fixed = TRUE)))   # the Monte Carlo noise floor is stated
	# --final drops the provisional flag
	r2 = run_conv(write_stats(tests, est), "--final")
	s2 = read_csv_fast(file.path(r2$out, "convergence_summary.csv"), stringsAsFactors = FALSE)
	expect_false(any(s2$provisional))
})

test_that("a single sample size leaves every asymptotic cell undetermined, and the script says so", {
	tests = rbind(synthetic_cell("wald", 50, rej = 100000), synthetic_cell("rand", 50))
	r = run_conv(write_stats(tests, synthetic_est("InferenceContinLin", "~.", 50, 0.04)))
	s = read_csv_fast(file.path(r$out, "convergence_summary.csv"), stringsAsFactors = FALSE)
	expect_true(all(s$verdict %in% c("undetermined", "not_applicable")))
	expect_true(all(s$n_points == 1L))
	expect_true(any(grepl("No cell has run at two sample sizes", readLines(file.path(r$out, "convergence_summary.md")))))
})

test_that("an empty stats table writes a 'no results' note and does not fail", {
	tests = synthetic_cell("wald", 50)[0, ]
	r = run_conv(write_stats(tests, synthetic_est("InferenceContinLin", "~.", 50, 0)[0, ]))
	expect_true(is.null(r$status) || r$status == 0L)
	expect_true(any(grepl("No results yet", readLines(file.path(r$out, "convergence_summary.md")))))
})

test_that("the script runs on a published campaign when one is available", {
	d = Sys.getenv("EDI_CAL_PUBLISHED_STATS_DIR", "")
	skip_if(!nzchar(d) || !file.exists(file.path(d, "tests.csv.gz")), "no published stats dir (set EDI_CAL_PUBLISHED_STATS_DIR)")
	out = tempfile("convpub")
	res = suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
		c(shQuote(file.path(cal_dir, "convergence_calibration_study.R")), "--stats-dir", shQuote(d), "--out-dir", shQuote(out)), stdout = TRUE, stderr = TRUE))
	expect_true(is.null(attr(res, "status")) || attr(res, "status") == 0L)
	s = read_csv_fast(file.path(out, "convergence_summary.csv"), stringsAsFactors = FALSE, colClasses = c(formula = "character"))
	expect_gt(nrow(s), 0L)
})
