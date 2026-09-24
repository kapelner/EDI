library(testthat)
library(EDI)

# SimulationFrameworkReport$summarize()/print() (simulation_framework_report.R) each have a dedicated
# "no results" branch, reached when private$valid_combos is empty: summarize() issues message("No
# results.") and returns invisible(NULL) immediately, without building the reference grid or
# aggregating anything; print() calls summarize() and, when it returns NULL (or a 0-row table), prints
# "  No results.\n" instead of a summary table. A codebase-wide grep confirmed neither exact string had
# any test reference anywhere -- every existing SimulationFrameworkReport reference (constructed either
# from a real, completed SimulationFramework or from a real results file with actual rows) has a
# non-empty valid_combos, so this branch was never exercised. .init_from_file() (the file-loading
# constructor path, itself already covered by test-simulation-framework-report-constructor-argument-
# guards-reference.R's error-guard tests) explicitly sets private$valid_combos = list() when the loaded
# results file has zero rows -- reached here via a real, well-formed but header-only (zero-row) results
# CSV file.

empty_results_csv <- function() {
	tmp <- tempfile(fileext = ".csv")
	cols <- c("rep", "response_type", "cond_exp_func_model", "n", "p", "betaT",
		"design", "inference", "inference_type", "estimate", "ci_lo", "ci_hi", "pval", "true_estimand")
	data.table::fwrite(
		data.table::data.table(matrix(nrow = 0, ncol = length(cols), dimnames = list(NULL, cols))),
		tmp
	)
	tmp
}

test_that("summarize() on an empty results file messages 'No results.' and returns NULL", {
	report <- SimulationFrameworkReport$new(empty_results_csv())
	expect_message(res <- report$summarize(), "No results.", fixed = TRUE)
	expect_null(res)
})

test_that("print() on an empty results file prints the documented 'No results.' line instead of a summary table", {
	report <- SimulationFrameworkReport$new(empty_results_csv())
	out <- capture.output(suppressMessages(report$print()))
	expect_true(any(grepl("No results.", out, fixed = TRUE)))
	expect_false(any(grepl("^Summary \\(alpha", out)))
})

test_that("a non-empty results file does NOT trigger either 'No results.' branch", {
	tmp <- tempfile(fileext = ".csv")
	dt <- data.table::data.table(
		rep = 1:5, response_type = "continuous", cond_exp_func_model = "linear",
		n = 20L, p = 1L, betaT = 0.5, design = "DesignFixedBernoulli",
		inference = "InferenceAllSimpleAverageDiff", inference_type = "asymp_ci",
		estimate = rnorm(5), ci_lo = rnorm(5) - 1, ci_hi = rnorm(5) + 1,
		pval = runif(5), true_estimand = 0.5
	)
	data.table::fwrite(dt, tmp)
	report <- SimulationFrameworkReport$new(tmp)
	expect_no_message(res <- report$summarize())
	expect_false(is.null(res))
	expect_gt(nrow(res), 0L)

	out <- capture.output(report$print())
	expect_false(any(grepl("No results.", out, fixed = TRUE)))
})
