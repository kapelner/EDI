library(testthat)
library(EDI)

# print.EDIInferenceSuiteResults() / summary.EDIInferenceSuiteResults() / print.summary.EDIInferenceSuiteResults(): the S3 methods a user sees when printing
# or summarizing an InferenceSuite$run_all_inference() return value. Each is checked against a hand-built EDIInferenceSuiteResults object and reconstructed
# independently from already-tested pieces: design_class_short_label() for the header line, run_all_inference_format_pretty_table() / _per_estimand_
# breakdown_lines() / _combined_evidence_summary_line() for the body (print.*), and direct table()/range()/sum() arithmetic for summary()'s own computation
# (formatC() reproduces print.summary's number formatting, including formatC's own leading-space-for-sign convention on a negative range endpoint).

ns <- asNamespace("EDI")
class_label <- get("design_class_short_label", envir = ns)
format_pretty <- get("run_all_inference_format_pretty_table", envir = ns)
breakdown_lines <- get("run_all_inference_per_estimand_breakdown_lines", envir = ns)
summary_line <- get("run_all_inference_combined_evidence_summary_line", envir = ns)

mk_results <- function() {
	tbl <- data.frame(
		inference_class = c("InferenceContinOLS", "InferenceAllSimpleMeanDiffPooledVar", "InferenceIncidLogRegr"),
		cov_model = c("y ~ x1 + x2", NA, "y ~ x1 + x2"),
		estimand = c("mean_difference", "mean_difference", "log_odds_ratio_marginal"),
		tau = c(NA_real_, NA_real_, NA_real_),
		estimate = c(1.2345, 2.5, -0.5), se = c(0.2, 0.3, 0.1),
		ci_a = c(0.8, 2.0, -0.7), ci_b = c(1.7, 3.0, -0.3), ci_method = c("wald", "wald", "wald"),
		pval = c(0.045, 0.2, 0.01), pval_method = c("wald", "wald", "wald"), type = c(NA_character_, NA_character_, NA_character_),
		weight = c(0.5, 0.5, 1), status = c("ok", "error", "ok"), stringsAsFactors = FALSE
	)
	structure(list(
		results_table = tbl,
		design = list(design_class = "DesignFixedBernoulli", response_type = "continuous", n = 40L),
		combined_evidence = list(weighting = "estimand_grouped", n_estimand_groups = 2L, n_classes_used = 3L, pval = 0.05),
		alpha = 0.05
	), class = "EDIInferenceSuiteResults")
}

test_that("print.EDIInferenceSuiteResults: header line, table, breakdown and combined-evidence summary match an independent reconstruction; returns x invisibly", {
	x <- mk_results()
	out <- capture.output(r <- print(x))
	ref_header <- sprintf("<EDIInferenceSuiteResults> %d class(es) -- Design: %s (response: %s), n = %s",
		nrow(x$results_table), class_label(x$design$design_class), x$design$response_type, x$design$n)
	expect_identical(out[1], ref_header)
	expect_identical(out[2:15], format_pretty(x$results_table))
	bd <- breakdown_lines(x$results_table)
	expect_identical(out[16], ""); expect_identical(out[17:18], bd)
	tail_expected <- c("", strsplit(summary_line(x$combined_evidence), "\n")[[1]])
	expect_identical(out[19:length(out)], tail_expected)
	expect_identical(withVisible(print(x))$visible, FALSE)
	invisible(capture.output(expect_identical(print(x), x)))
})

test_that("summary.EDIInferenceSuiteResults: n_classes/status_counts/estimate_range/n_significant match direct table()/range()/sum() arithmetic", {
	x <- mk_results(); s <- summary(x)
	expect_s3_class(s, "summary.EDIInferenceSuiteResults")
	tbl <- x$results_table; ok <- tbl[tbl$status == "ok", ]
	expect_equal(s$n_classes, length(unique(tbl$inference_class)))
	expect_equal(as.integer(s$status_counts), c(2L, 0L, 1L, 0L))
	expect_identical(names(s$status_counts), c("ok", "nonest", "error", "timeout"))
	expect_equal(s$estimate_range, range(ok$estimate))
	expect_equal(s$alpha, x$alpha)
	expect_equal(s$n_significant, sum(ok$pval < x$alpha))
})

test_that("summary(): a table with no 'ok' rows gives NA estimate_range and 0 significant, without erroring", {
	x <- mk_results(); x$results_table$status <- rep("error", nrow(x$results_table))
	s <- summary(x)
	expect_true(all(is.na(s$estimate_range)))
	expect_equal(s$n_significant, 0L)
})

test_that("print.summary.EDIInferenceSuiteResults: every line matches sprintf/formatC applied directly to the summary object's own fields", {
	x <- mk_results(); s <- summary(x)
	out <- capture.output(r <- print(s))
	expect_identical(out[1], "InferenceSuite$run_all_inference() summary")
	expect_identical(out[2], sprintf("  classes:            %d", s$n_classes))
	for (i in seq_along(s$status_counts)) {
		expect_identical(out[2 + i], sprintf("    %-13s %d", paste0(names(s$status_counts)[i], ":"), s$status_counts[[i]]))
	}
	range_line <- sprintf("  estimate range:     [%s, %s]", formatC(s$estimate_range[1], digits = 4, format = "g"), formatC(s$estimate_range[2], digits = 4, format = "g"))
	expect_identical(out[7], range_line)
	expect_identical(out[8], sprintf("  significant (alpha = %g): %d", s$alpha, s$n_significant))
	expect_identical(withVisible(print(s))$visible, FALSE)
})

test_that("print.summary.EDIInferenceSuiteResults: an all-NA estimate range prints as '[NA, NA]'", {
	x <- mk_results(); x$results_table$status <- rep("error", nrow(x$results_table))
	s <- summary(x)
	out <- capture.output(print(s))
	expect_identical(out[7], "  estimate range:     [NA, NA]")
})
