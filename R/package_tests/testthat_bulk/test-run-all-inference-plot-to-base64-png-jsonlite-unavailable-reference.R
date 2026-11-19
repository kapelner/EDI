library(testthat)
library(EDI)

# inference_suite.R's run_all_inference_plot_to_base64_png(plot, width, height) returns NULL for
# two distinct reasons: plot is NULL, OR jsonlite (used for base64 encoding) is unavailable. The
# existing test-inference-suite-html-pdf-png-render-layer.R (test_that "run_all_inference_plot_to_
# base64_png encodes a ggplot to a real, decodable PNG") has a comment claiming "NULL plot /
# missing jsonlite -> NULL, not an error" but its actual assertion only calls the function with a
# NULL plot -- the jsonlite-unavailable branch, with a real non-NULL plot, was never exercised.
# Confirmed via direct probing before writing this test (the existing file's comment is aspirational,
# not actually tested). Mocked with .package = "base" for requireNamespace(), the same technique
# established earlier this session for the sibling ggplot2-unavailable guard on run_all_inference_
# build_plots() and other requireNamespace()-direct guards.

test_that("run_all_inference_plot_to_base64_png() returns NULL (not an error) for a real plot when jsonlite is (mocked as) unavailable", {
	skip_if_not_installed("ggplot2")
	p <- ggplot2::ggplot(data.frame(x = 1:3, y = c(1, 3, 2)), ggplot2::aes(x, y)) + ggplot2::geom_point()

	res <- with_mocked_bindings(
		requireNamespace = function(pkg, ...) FALSE,
		.package = "base",
		EDI:::run_all_inference_plot_to_base64_png(p, width = 4, height = 3)
	)
	expect_null(res)
})

# docs-claims audit, finding docs-claims-d3906c9d4: without jsonlite, run_all_inference(save_results_as_JSON
# = TRUE) warns and skips the JSON file instead of erroring.
test_that("run_all_inference(save_results_as_JSON = TRUE) warns and leaves files$json NULL when jsonlite is (mocked as) unavailable", {
	set.seed(1)
	des <- DesignSeqOneByOneBernoulli$new(n = 16L, response_type = "continuous", verbose = FALSE)
	for (i in 1:16) des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	des$add_all_subject_responses(rnorm(16))
	s <- InferenceSuite$new(des)
	out_dir <- withr::local_tempdir()
	real_rn <- base::requireNamespace
	res <- NULL
	with_mocked_bindings(
		requireNamespace = function(package, ...) if (identical(package, "jsonlite")) FALSE else real_rn(package, ...),
		.package = "base",
		expect_warning(
			capture.output(res <- s$run_all_inference(screen = TRUE, plots = FALSE, classes = "InferenceAllSimpleAverageDiff",
				methods = "wald", save_results_as_JSON = TRUE, output_dir = out_dir)),
			"jsonlite"
		)
	)
	expect_s3_class(res, "EDIInferenceSuiteResults")
	expect_null(res$files$json)
	expect_length(list.files(out_dir, pattern = "\\.json$"), 0L)
})
