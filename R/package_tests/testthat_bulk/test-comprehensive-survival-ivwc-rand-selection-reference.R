library(testthat)
library(EDI)

# Parse the harness without sourcing it: sourcing starts the comprehensive
# suite and writes result CSVs. The selector is exercised with the exact class
# filter used by a filtered comprehensive invocation.
comprehensive_path <- testthat::test_path("..", "comprehensive_tests.R")
comprehensive_exprs <- parse(comprehensive_path)

comprehensive_assignment <- function(name) {
	for (expr in comprehensive_exprs) {
		if (!is.call(expr) || !(identical(expr[[1L]], as.name("=")) || identical(expr[[1L]], as.name("<-"))) || !is.name(expr[[2L]])) next
		if (identical(as.character(expr[[2L]]), name)) return(expr)
	}
	stop("Missing comprehensive assignment: ", name)
}

test_that("the Weibull-frailty loggamma IVWC class is explicitly selected for KK survival rand rows", {
	e <- new.env(parent = globalenv())
	eval(comprehensive_assignment("select_kk_survival_class_generators"), envir = e)
	eval(comprehensive_assignment("is_skipped_inference_label"), envir = e)

	target <- "InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC"
	selected <- e$select_kk_survival_class_generators(function(class_name) identical(class_name, target))
	expect_identical(vapply(selected, `[[`, character(1), "classname"), target)
	# IVWC remains excluded from the exhaustive sweep, so the explicit KK
	# survival selector above is the path that must retain this class.
	expect_true(e$is_skipped_inference_label(target))

	response_runner <- paste(deparse(comprehensive_assignment("run_tests_for_response")), collapse = "\n")
	rand_runner <- paste(deparse(comprehensive_assignment("run_inference_checks_impl")), collapse = "\n")
	expect_match(response_runner, "select_kk_survival_class_generators\\(should_run_inference_label\\)")
	expect_match(response_runner, "run_inference_checks\\(kk_surv_class\\$new")
	expect_match(rand_runner, "should_run_test_family\\(\\\"rand\\\"\\)")
	expect_match(rand_runner, "compute_rand_two_sided_pval")
	expect_match(rand_runner, "compute_rand_confidence_interval")
})
