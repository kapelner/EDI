library(testthat)
library(EDI)

# run_all_inference_build_live_table_header(tasks, des_obj, compute_conf_intervals, inference_params): assembles the live table's header (via
# run_all_inference_fmt_wrapped_row(), the already-tested wrapper) plus a "=" rule sized to the header's own width, the per-column width caps for the
# selected header set, and one enriched "static" entry per task (run_all_inference_static_row_fields()'s three fields plus cov_model_disp, a formula's
# distinguishing letter key or a passed-through sentinel "~1"/"~."). The set of headers is exactly EDI_INFERENCE_SUITE_LIVE_TABLE_HEADERS[_NO_CI] depending
# on compute_conf_intervals. Two tasks sharing the same non-sentinel formula string get the same letter. Letters are assigned in
# estimand-then-class-name SORTED order (cov_model_display()'s own processing order), NOT the raw task list order -- so a task earlier in the estimand/
# class sort gets the earlier letter even if it appears later in `tasks`. statics preserve the tasks' own (unsorted) order.

ns <- asNamespace("EDI")
build_header <- get("run_all_inference_build_live_table_header", envir = ns)
fmt_row <- get("run_all_inference_fmt_wrapped_row", envir = ns)
full_headers <- get("EDI_INFERENCE_SUITE_LIVE_TABLE_HEADERS", envir = ns)
no_ci_headers <- get("EDI_INFERENCE_SUITE_LIVE_TABLE_HEADERS_NO_CI", envir = ns)

set.seed(1); n <- 10L
d <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rnorm(n))

test_that("the header lines and rule match an independent fmt_wrapped_row(headers, headers) call, plus a '=' rule sized to that width", {
	tasks <- list(list(cls_name = "InferenceContinOLS", model_formula = y ~ x1 + x2))
	r <- build_header(tasks, d)
	ref_header <- fmt_row(full_headers, full_headers)
	expect_identical(r$header_lines[1:2], ref_header)
	expect_identical(r$total_width, max(nchar(ref_header)))
	expect_identical(r$header_lines[3], strrep("=", r$total_width))
	expect_identical(r$headers, full_headers)
})

test_that("compute_conf_intervals = FALSE selects the no-CI header set and its own header lines", {
	tasks <- list(list(cls_name = "InferenceContinOLS", model_formula = y ~ x1))
	r <- build_header(tasks, d, compute_conf_intervals = FALSE)
	expect_identical(r$headers, no_ci_headers)
	expect_false("ci_a" %in% r$headers)
	expect_identical(r$header_lines[1:2], fmt_row(no_ci_headers, no_ci_headers))
})

test_that("two tasks sharing the same non-sentinel formula string get the same letter key; a class with adjusts_for_covariates = FALSE gets a blank disp", {
	tasks <- list(
		list(cls_name = "InferenceContinOLS", model_formula = y ~ x1 + x2),
		list(cls_name = "InferenceAllSimpleMeanDiffPooledVar", model_formula = NULL),
		list(cls_name = "InferenceContinOLS", model_formula = y ~ x1 + x2)
	)
	r <- build_header(tasks, d)
	expect_identical(r$statics[[1]]$cov_model_disp, r$statics[[3]]$cov_model_disp)
	expect_match(r$statics[[1]]$cov_model_disp, "^\\([A-Z]\\)$")
	expect_length(r$cov_key, 1L)                                                    # only one distinct non-sentinel formula among the tasks
	expect_identical(r$statics[[2]]$cov_model_disp, "")                             # adjusts_for_covariates = FALSE -> blank, not a letter
})

test_that("letters are assigned in estimand-then-class SORTED order, not the raw task list order", {
	tasks <- list(
		list(cls_name = "InferenceContinOLS", model_formula = y ~ zzz),             # estimand "mean_difference" -- sorts AFTER log_odds_ratio_marginal
		list(cls_name = "InferenceIncidLogRegr", model_formula = y ~ aaa)           # estimand "log_odds_ratio_marginal" -- sorts first
	)
	r <- build_header(tasks, d)
	expect_identical(r$statics[[2]]$cov_model_disp, "(A)")                          # LogRegr, sorts first, gets the first letter
	expect_identical(r$statics[[1]]$cov_model_disp, "(B)")                          # OLS is task #1 in the list but sorts second
})

test_that("a sentinel formula ('~.', the design's own default) never enters the letter key", {
	tasks <- list(list(cls_name = "InferenceContinOLS", model_formula = NULL))       # falls back to des_obj$get_design_formula(), which is ~.
	r <- build_header(tasks, d)
	expect_identical(r$statics[[1]]$cov_model_disp, "~.")
	expect_length(r$cov_key, 0L)
})
