library(testthat)

# Pure-R reference test for the G4-C Type-I summarizer (release_v1_0_5.md,
# "G4-C. Calibration runbook", rule G6 #20). No EDI namespace or native code:
# synthetic p-value rows with known counts are checked against independently
# computed Clopper-Pearson bounds (beta quantiles) and the PASS / FAIL /
# CONSERVATIVE classification.
calibration_dir <- testthat::test_path("..", "calibration")
source(file.path(calibration_dir, "calibration_common.R"), local = TRUE)
source(file.path(calibration_dir, "summarize_type1_calibration.R"), local = TRUE)

cp_reference <- function(k, n, conf = 0.95) {
	a <- (1 - conf) / 2
	c(if (k == 0) 0 else stats::qbeta(a, k, n - k + 1), if (k == n) 1 else stats::qbeta(1 - a, k + 1, n - k))
}

make_cell <- function(method, stratum, n_fin, k, extra_status = character(), seed_start = 1L) {
	# k rejections at p = 0.01, the rest at p = 0.5; one boundary p = 0.05 (not a rejection) when room allows
	p <- c(rep(0.01, k), rep(0.5, n_fin - k))
	if (n_fin - k > 0L) p[k + 1L] <- 0.05
	rows <- data.frame(method = rep(method, n_fin), stratum = rep(stratum, n_fin),
		seed = seed_start + seq_len(n_fin) - 1L, pval = p, status = rep("ok", n_fin), stringsAsFactors = FALSE)
	if (length(extra_status)) {
		extra <- data.frame(method = method, stratum = stratum,
			seed = seed_start + n_fin + seq_along(extra_status) - 1L,
			pval = ifelse(extra_status == "ok_nan", NaN, ifelse(extra_status == "ok_out_of_range", 1.2,
				ifelse(extra_status == "error_finite", 0.001, NA_real_))),
			status = ifelse(extra_status %in% c("ok_nan", "ok_out_of_range"), "ok",
				ifelse(extra_status == "error_finite", "error", extra_status)),
			stringsAsFactors = FALSE)
		rows <- rbind(rows, extra)
	}
	rows
}

test_that("#20 rule: finite-p denominator, strict p < alpha, exact CP bounds and verdicts", {
	rows <- rbind(
		make_cell("lr", "~1", 500L, 25L, extra_status = c("nonestimable", "error", "timeout", "ok_nan", "ok_out_of_range",
			"error_finite")),
		make_cell("lr", "~.", 500L, 50L),
		make_cell("bartlett", "~1", 500L, 5L),
		make_cell("bartlett", "~.", 0L, 0L, extra_status = c("error", "error", "nonestimable"))
	)
	s <- summarize_type1_rows(rows, alpha = 0.05, conf_level = 0.95, target = 500L)
	get <- function(m, st) s[s$method == m & s$stratum == st, , drop = FALSE]

	a <- get("lr", "~1")
	expect_identical(a$n_att, 506L)
	expect_identical(a$n_fin, 500L)
	expect_identical(a$n_not_finite, 6L)
	expect_identical(a$n_nonestimable, 1L)
	expect_identical(a$n_error, 2L)
	expect_identical(a$n_timeout, 1L)
	expect_identical(a$n_ok_nonfinite, 2L)
	expect_identical(a$k, 25L)   # the boundary p = 0.05 row and the error row's finite p are not counted
	expect_equal(a$rate, 25 / 500)
	expect_equal(c(a$cp_lower, a$cp_upper), cp_reference(25, 500), tolerance = 1e-10)
	expect_identical(a$verdict, "PASS")
	expect_true(a$meets_target)

	b <- get("lr", "~.")
	expect_equal(c(b$cp_lower, b$cp_upper), cp_reference(50, 500), tolerance = 1e-10)
	expect_gt(b$cp_lower, 0.05)
	expect_identical(b$verdict, "FAIL_ANTICONSERVATIVE")

	c3 <- get("bartlett", "~1")
	expect_equal(c(c3$cp_lower, c3$cp_upper), cp_reference(5, 500), tolerance = 1e-10)
	expect_lt(c3$cp_upper, 0.05)
	expect_identical(c3$verdict, "CONSERVATIVE")

	d <- get("bartlett", "~.")
	expect_identical(d$n_att, 3L)
	expect_identical(d$n_fin, 0L)
	expect_identical(d$verdict, "NO_FINITE")
	expect_true(is.na(d$rate))
	expect_false(d$meets_target)
	expect_identical(d$target_shortfall, 497L)

	# ~1 and ~. are separate strata: four cells, not two
	expect_identical(nrow(s), 4L)
})

test_that("target basis and small-n Clopper-Pearson bounds match the closed form", {
	rows <- make_cell("m", "s", 40L, 3L, extra_status = rep("error", 470L))
	att <- summarize_type1_rows(rows, target = 500L, target_basis = "attempted")
	fin <- summarize_type1_rows(rows, target = 500L, target_basis = "finite")
	expect_true(att$meets_target)
	expect_false(fin$meets_target)
	expect_identical(fin$target_shortfall, 460L)
	expect_equal(c(att$cp_lower, att$cp_upper), cp_reference(3, 40), tolerance = 1e-10)
	expect_equal(c(att$cp_lower, att$cp_upper), as.numeric(stats::binom.test(3, 40)$conf.int), tolerance = 1e-12)
	# k = 0 and k = n edges
	expect_equal(calib_cp_interval(0L, 20L), cp_reference(0, 20), tolerance = 1e-10)
	expect_equal(calib_cp_interval(20L, 20L), cp_reference(20, 20), tolerance = 1e-10)
	expect_identical(type1_verdict(0L, 20L), "PASS")        # [0, 0.168] contains 0.05
	expect_identical(type1_verdict(0L, 100L), "CONSERVATIVE")  # [0, 0.036]
})

test_that("duplicate outer datasets within a cell are refused", {
	rows <- make_cell("m", "s", 10L, 1L)
	rows <- rbind(rows, rows[1L, ])
	expect_error(summarize_type1_rows(rows), "duplicate")
})

test_that("raw comprehensive rows map to method x (dataset|design|formula) strata at beta_T = 0", {
	df <- data.frame(
		function_run = c("compute_lik_ratio_two_sided_pval", "compute_lik_ratio_two_sided_pval",
			"compute_lik_ratio_two_sided_pval", "compute_asymp_confidence_interval", "compute_lik_ratio_two_sided_pval",
			"compute_lik_ratio_two_sided_pval"),
		rep = c(1L, 2L, 1L, 1L, 3L, 1L),
		beta_T = c(0, 0, 0, 0, 0, 0.5),
		dataset = "diamonds", design = "Bernoulli",
		inference_class = c("InferenceOrdinalCloglogRegr [design_formula=~1]", "InferenceOrdinalCloglogRegr [design_formula=~1]",
			"InferenceOrdinalCloglogRegr [design_formula=~.]", "InferenceOrdinalCloglogRegr [design_formula=~1]",
			"InferenceOrdinalCloglogRegr [design_formula=~1]", "InferenceOrdinalCloglogRegr [design_formula=~1]"),
		result = c("0.01", "0.6", "0.2", "-1", NA, "0.001"),
		result_1 = c(0.01, 0.6, 0.2, -1, NA, 0.001),
		status = c("ok", "ok", "ok", "ok", "error", "ok"),
		skip_reason = c("", "", "", "", "error", ""),
		error_message = c("", "", "", "", "boom", ""),
		stringsAsFactors = FALSE
	)
	rows <- type1_rows_from_comprehensive(df)
	expect_identical(nrow(rows), 4L)  # CI row and beta_T = 0.5 row dropped
	expect_setequal(unique(rows$stratum), c("diamonds|Bernoulli|~1", "diamonds|Bernoulli|~."))
	s <- summarize_type1_rows(rows)
	one <- s[s$stratum == "diamonds|Bernoulli|~1", ]
	expect_identical(one$method, "InferenceOrdinalCloglogRegr::compute_lik_ratio_two_sided_pval")
	expect_identical(one$n_att, 3L)
	expect_identical(one$n_fin, 2L)
	expect_identical(one$n_error, 1L)
	expect_identical(one$k, 1L)

	map <- data.frame(function_run = "compute_lik_ratio_two_sided_pval", method = "direct_LR",
		class_pattern = "Cloglog", stringsAsFactors = FALSE)
	mapped <- type1_rows_from_comprehensive(df, map = map)
	expect_true(all(mapped$method == "direct_LR"))
})

test_that("summary files are written once and never overwritten", {
	out <- tempfile("type1-summary-")
	dir.create(out)
	s <- summarize_type1_rows(make_cell("m", "s", 30L, 2L))
	files <- write_type1_summary(s, out)
	expect_true(all(file.exists(files)))
	back <- utils::read.csv(files[["csv"]], stringsAsFactors = FALSE)
	expect_identical(names(back), TYPE1_SUMMARY_COLUMNS)
	expect_identical(back$verdict, "PASS")
	expect_error(write_type1_summary(s, out), "refusing to overwrite")
	unlink(out, recursive = TRUE)
})
