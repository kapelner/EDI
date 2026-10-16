library(testthat)
library(EDI)

# Parse the harness without sourcing it: sourcing starts the comprehensive
# suite and writes result CSVs. These pure selectors are exercised directly.
comprehensive_path <- testthat::test_path("..", "comprehensive_tests.R")
comprehensive_exprs <- parse(comprehensive_path)

comprehensive_assignment <- function(name) {
	for (expr in comprehensive_exprs) {
		if (!is.call(expr) || !(identical(expr[[1L]], as.name("=")) || identical(expr[[1L]], as.name("<-"))) || !is.name(expr[[2L]])) next
		if (identical(as.character(expr[[2L]]), name)) return(expr)
	}
	stop("Missing comprehensive assignment: ", name)
}

test_that("the KK incidence IVWC GLMM class is explicitly selected", {
	e <- new.env(parent = globalenv())
	eval(comprehensive_assignment("select_kk_incidence_glmm_ivwc_generator"), envir = e)
	eval(comprehensive_assignment("is_skipped_inference_label"), envir = e)

	wanted <- "InferenceIncidKKCondLogitGLMMIVWC"
	selected <- e$select_kk_incidence_glmm_ivwc_generator(function(class_name) identical(class_name, wanted))
	expect_identical(vapply(selected, `[[`, character(1), "classname"), wanted)

	# Keep the exhaustive namespace exclusion for unrelated IVWC classes.
	expect_false(e$is_skipped_inference_label("InferenceIncidKKCondLogitGLMMIVWC"))
	expect_true(e$is_skipped_inference_label("InferenceIncidOtherIVWC"))
})

test_that("Bayesian-bootstrap skipping depends on its own capability, not nonparametric bootstrap", {
	e <- new.env(parent = globalenv())
	eval(comprehensive_assignment("should_skip_bayesian_bootstrap"), envir = e)

	# Independent truth table for the three policy gates: class-specific
	# bootstrap slow-list membership, registry slow-list membership, and BB
	# capability. In particular, absent nonparametric_bootstrap is irrelevant.
	expect_false(e$should_skip_bayesian_bootstrap(FALSE, FALSE, "bayesian_bootstrap"))
	expect_true(e$should_skip_bayesian_bootstrap(TRUE, FALSE, "bayesian_bootstrap"))
	expect_true(e$should_skip_bayesian_bootstrap(FALSE, TRUE, "bayesian_bootstrap"))
	expect_true(e$should_skip_bayesian_bootstrap(FALSE, FALSE, "randomization_test"))

	runner <- paste(deparse(comprehensive_assignment("run_inference_checks_impl")), collapse = "\n")
	response_runner <- paste(deparse(comprehensive_assignment("run_tests_for_response")), collapse = "\n")
	expect_match(runner, "should_skip_bayesian_bootstrap\\(")
	expect_match(response_runner, "select_kk_incidence_glmm_ivwc_generator\\(should_run_inference_label\\)")
})
