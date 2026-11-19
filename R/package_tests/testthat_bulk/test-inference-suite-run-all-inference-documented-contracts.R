library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-d3906c9d4 (InferenceSuite): the constructor ignores
# model_formula; num_cores > 1 on a non-Unix platform falls back to sequential with a warning;
# ci_method/pval_method always match the row's own method (or are NA), and a class with no
# applicable sentinel still gets exactly one row with method NA; run_all_inference() returns
# invisibly.

suite_design <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	des
}

quiet_run <- function(suite, ...) {
	res <- NULL
	capture.output(res <- suite$run_all_inference(screen = TRUE, plots = FALSE, ...))
	res
}

small_classes <- c("InferenceAllSimpleAverageDiff", "InferenceContinOLS")
cols <- c("inference_class", "method", "type", "estimate", "se", "pval", "pval_method", "status")

test_that("InferenceSuite$new ignores model_formula: same applicable classes and same results", {
	des <- suite_design()
	s0 <- InferenceSuite$new(des)
	s1 <- InferenceSuite$new(des, model_formula = ~ 1)
	expect_identical(s1$applicable_design_classes, s0$applicable_design_classes)
	expect_identical(s1$unavailable_due_to_missing_packages, s0$unavailable_due_to_missing_packages)
	set.seed(5) # task seeds are drawn from the global RNG
	r0 <- quiet_run(s0, classes = small_classes, methods = c("wald", "rand"), r = 19)
	set.seed(5)
	r1 <- quiet_run(s1, classes = small_classes, methods = c("wald", "rand"), r = 19)
	expect_identical(r1$results_table[, cols], r0$results_table[, cols])
})

test_that("num_cores > 1 on a non-Unix platform warns and falls back to sequential", {
	des <- suite_design()
	s <- InferenceSuite$new(des)
	# run_all_inference() reads .Platform$OS.type from its enclosing environment; shadow it there.
	assign(".Platform", modifyList(base::.Platform, list(OS.type = "windows")), envir = s$.__enclos_env__)
	res <- NULL
	expect_warning(
		capture.output(res <- s$run_all_inference(screen = TRUE, plots = FALSE, classes = small_classes,
			methods = "wald", num_cores = 2L)),
		"falling back to num_cores = 1"
	)
	expect_setequal(unique(res$results_table$inference_class), small_classes)
	expect_true(all(res$results_table$status == "ok"))
})

test_that("ci_method/pval_method match the row's own method; a class with no applicable sentinel gets one NA-method row", {
	des <- suite_design()
	s <- InferenceSuite$new(des)
	res <- quiet_run(s, classes = small_classes, methods = c("wald", "rand"), r = 19, compute_conf_intervals = TRUE)
	tbl <- res$results_table
	expect_gt(nrow(tbl), 2L)
	expect_true(all(is.na(tbl$pval_method) | tbl$pval_method == tbl$method))
	expect_true(all(is.na(tbl$ci_method) | tbl$ci_method == tbl$method))

	# InferenceAllSimpleAverageDiff has no parametric-bootstrap capability.
	res_none <- quiet_run(s, classes = "InferenceAllSimpleAverageDiff", methods = "param_boot", B = 19)
	t2 <- res_none$results_table
	expect_identical(nrow(t2), 1L)
	expect_true(is.na(t2$method))
	expect_true(is.na(t2$type))
})

test_that("run_all_inference returns its EDIInferenceSuiteResults object invisibly", {
	des <- suite_design()
	s <- InferenceSuite$new(des)
	capture.output(
		expect_invisible(res <- s$run_all_inference(screen = TRUE, plots = FALSE, classes = "InferenceAllSimpleAverageDiff", methods = "wald"))
	)
	expect_s3_class(res, c("EDIInferenceSuiteResults", "list"), exact = TRUE)
})
