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

# The calibration study's covariate balance (calibration_study_balance.R, owner 2026-11-17): the per-replicate
# metrics, their mergeable statistics, and the summary script the analyze job runs (Rscript, no EDI).

bal_repo_dir = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		d = file.path(dir, "R", "package_tests", "calibration")
		if (file.exists(file.path(d, "calibration_study_balance.R"))) return(d)
		dir = dirname(dir)
	}
	NA_character_
}
cal_dir = bal_repo_dir()
skip_if(is.na(cal_dir), "calibration scripts not found")
bal_env = new.env()
sys.source(file.path(cal_dir, "calibration_study_balance.R"), envir = bal_env)

bal_X = function(n, seed) {
	set.seed(seed)
	data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n), x4 = factor(rbinom(n, 1, 0.5), levels = 0:1),
		x5 = factor(rbinom(n, 1, 0.5), levels = 0:1))
}

test_that("balance metrics match their textbook formulas", {
	X = bal_X(60, 1)
	w = rep(0:1, 30)
	b = bal_env$cal_balance_metrics(X, w)
	Z = cbind(X$x1, X$x2, X$x3, as.integer(X$x4) - 1L, as.integer(X$x5) - 1L)
	t = w == 1L
	d = colMeans(Z[t, ]) - colMeans(Z[!t, ])
	smd = d / sqrt((apply(Z[t, ], 2, var) + apply(Z[!t, ], 2, var)) / 2)
	M = drop(t(d) %*% solve(cov(Z) * (1 / 30 + 1 / 30)) %*% d)
	expect_equal(b$mean_abs_smd, mean(abs(smd)))
	expect_equal(b$max_abs_smd, max(abs(smd)))
	expect_equal(b$mahal_p, M / 5)
	expect_equal(b$max_ks, max(vapply(1:5, function(j) suppressWarnings(ks.test(Z[t, j], Z[!t, j])$statistic), 0)), tolerance = 1e-12)
	expect_equal(b$max_abs_log_vr, max(abs(log(apply(Z[t, ], 2, var) / apply(Z[!t, ], 2, var)))))
	expect_gt(b$energy, 0)
})

test_that("a balanced assignment scores lower than a confounded one", {
	X = bal_X(80, 2)
	bad = as.integer(X$x1 > median(X$x1))
	good = integer(80); good[order(X$x1)[seq(1, 80, 2)]] = 1L
	b_bad = bal_env$cal_balance_metrics(X, bad)
	b_good = bal_env$cal_balance_metrics(X, good)
	# Location and distribution metrics only: a median split leaves both arms' x1 spread about equal, so the
	# variance ratios cannot tell the two apart.
	for (m in setdiff(bal_env$CAL_BALANCE_METRICS, c("mean_abs_log_vr", "max_abs_log_vr"))) expect_lt(b_good[[m]], b_bad[[m]], label = m)
})

test_that("merged statistics give the replicates' mean, SD and quantiles; a one-arm assignment is NA", {
	reps = do.call(rbind, lapply(1:200, function(r) {
		X = bal_X(40, 100 + r)
		w = sample(rep(0:1, 20))
		data.frame(response_type = "continuous", design = "DesignFixedBernoulli", prob_T = 0.5, n = 40L, n_nominal = 40L,
			effect_label = "null", rep = r, bal_env$cal_balance_metrics(X, w))
	}))
	# Statistics split over two shards and merged equal the statistics of all replicates at once.
	st = bal_env$cal_balance_merge(list(bal_env$cal_balance_stats(reps[1:70, ]), bal_env$cal_balance_stats(reps[71:200, ])))
	expect_equal(st, bal_env$cal_balance_stats(reps), ignore_attr = TRUE)
	s = bal_env$cal_balance_summary(st)
	expect_equal(s$reps, 200)
	expect_equal(s$mahal_p, mean(reps$mahal_p))
	expect_equal(s$mahal_p_sd, sd(reps$mahal_p))
	expect_equal(s$max_abs_smd, mean(reps$max_abs_smd))
	# Quantiles come from a log grid with 12% steps.
	expect_equal(s$mahal_p_q50, unname(quantile(reps$mahal_p, 0.5)), tolerance = 0.12)
	expect_equal(s$max_abs_smd_q95, unname(quantile(reps$max_abs_smd, 0.95)), tolerance = 0.12)
	# Complete randomization: M/p is about chi2_5 / 5, mean 1.
	expect_gt(s$mahal_p, 0.7); expect_lt(s$mahal_p, 1.3)
	expect_true(all(is.na(unlist(bal_env$cal_balance_metrics(bal_X(10, 3), c(1L, rep(0L, 9)))))))
})

test_that("the summary script writes the table and page from shard statistics", {
	cdir = file.path(tempfile("calbal"), "campaigns", "c1")
	dir.create(file.path(cdir, "stats"), recursive = TRUE)
	rows = do.call(rbind, lapply(c("DesignFixedBernoulli", "DesignFixedGreedy"), function(des) do.call(rbind, lapply(1:30, function(r) {
		X = bal_X(50, r)
		w = if (des == "DesignFixedBernoulli") rbinom(50, 1, 0.5) else { o = integer(50); o[order(X$x1)[seq(1, 50, 2)]] = 1L; o }
		data.frame(response_type = "count", design = des, prob_T = 0.5, n = 50L, n_nominal = 50L, effect_label = "null",
			rep = r, bal_env$cal_balance_metrics(X, w))
	}))))
	con = gzfile(file.path(cdir, "stats", "balance.csv.gz"), "w")
	write.csv(bal_env$cal_balance_stats(rows), con, row.names = FALSE)
	close(con)
	out = system2(file.path(R.home("bin"), "Rscript"), c(file.path(cal_dir, "summarize_balance_calibration_study.R"),
		"--campaign-dir", cdir, "--out-dir", file.path(cdir, "summary")), stdout = TRUE, stderr = TRUE)
	expect_null(attr(out, "status"), info = paste(out, collapse = "\n"))
	s = read_csv_fast(file.path(cdir, "summary", "balance_summary.csv"), stringsAsFactors = FALSE)
	expect_setequal(unique(s$response_type), c("count", "all"))
	md = readLines(file.path(cdir, "summary", "balance_summary.md"))
	expect_true(any(grepl("recorded by the shards", md)))
	tab = md[grepl("^\\| Fixed", md)]
	expect_length(tab, 2L)
	expect_match(tab[1], "^\\| FixedGreedy ")   # ordered by M/p: Greedy before Bernoulli
})
