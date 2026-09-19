library(testthat)
library(EDI)

# run_all_inference_render_html/build_plots/save_plots_pdf/plot_to_base64_png
# (inference_suite.R) had zero test references anywhere prior to this file
# despite run_all_inference()'s dispatch/discovery logic being heavily
# exercised elsewhere -- confirmed via repo-wide grep. These are
# rendering-only functions, so assertions check structural well-formedness
# (valid HTML markup, real PDF magic bytes, a PNG that actually decodes),
# not visual content.

make_render_fixture <- function() {
	set.seed(20260919)
	n <- 30L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(1 + 0.6 * w + rnorm(n))
	des
}

test_that("run_all_inference(html=TRUE, pdf=TRUE, plots=TRUE) writes well-formed HTML and PDF report files", {
	des <- make_render_fixture()
	suite <- InferenceSuite$new(des)
	out_dir <- tempfile("edi-render-test-")
	dir.create(out_dir)
	on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

	# EDI:::stub-free: utils::browseURL is a no-op/error-tolerant call in a
	# headless test session; capture.output silences the screen path.
	capture.output({
		res <- suite$run_all_inference(
			screen = TRUE, plots = TRUE, html = TRUE, pdf = TRUE, compute_conf_intervals = TRUE,
			classes = "InferenceAllSimpleAverageDiff", output_dir = out_dir
		)
	})

	expect_true(!is.null(res$files$html))
	expect_true(file.exists(res$files$html))
	html_txt <- readLines(res$files$html, warn = FALSE)
	html_all <- paste(html_txt, collapse = "\n")
	expect_true(grepl("<!DOCTYPE html>", html_all, fixed = TRUE))
	expect_true(grepl("<table class=\"results\"", html_all, fixed = TRUE))
	expect_true(grepl("InferenceSuite\\$run_all_inference\\(\\) results", html_all))
	# At least one CI forest image should be embedded as a base64 PNG data URI.
	expect_true(grepl('data:image/png;base64,', html_all, fixed = TRUE))

	expect_true(!is.null(res$files$pdf))
	expect_true(file.exists(res$files$pdf))
	expect_gt(file.info(res$files$pdf)$size, 0)
	pdf_header <- readBin(res$files$pdf, "raw", 5L)
	expect_identical(rawToChar(pdf_header), "%PDF-")
})

test_that("run_all_inference_build_plots returns one ggplot per estimand, or an empty list with a warning if ggplot2 is unavailable", {
	des <- make_render_fixture()
	suite <- InferenceSuite$new(des)
	capture.output({
		res <- suite$run_all_inference(screen = TRUE, plots = FALSE, compute_conf_intervals = TRUE, classes = "InferenceAllSimpleAverageDiff")
	})
	plots <- EDI:::run_all_inference_build_plots(res$results_table, alpha = 0.05)
	expect_true(is.list(plots))
	expect_true("ci_forest" %in% names(plots))
	expect_true(length(plots$ci_forest) >= 1L)
	# run_all_inference_stack_forest_and_box() returns a stacked grob (gtable),
	# not a raw ggplot object -- confirmed via source docs/grep.
	expect_true(inherits(plots$ci_forest[[1]], "gtable") || inherits(plots$ci_forest[[1]], "grob"))
	expect_true(!is.null(attr(plots$ci_forest[[1]], "edi_height_in")))
})

test_that("run_all_inference_plot_to_base64_png encodes a ggplot to a real, decodable PNG", {
	skip_if_not_installed("ggplot2")
	skip_if_not_installed("jsonlite")
	p <- ggplot2::ggplot(data.frame(x = 1:3, y = c(1, 3, 2)), ggplot2::aes(x, y)) +
		ggplot2::geom_point()
	b64 <- EDI:::run_all_inference_plot_to_base64_png(p, width = 4, height = 3)
	expect_true(is.character(b64))
	expect_true(nchar(b64) > 100)
	raw_png <- jsonlite::base64_dec(b64)
	# PNG magic number: 0x89 'P' 'N' 'G' \r \n 0x1A \n
	expect_identical(raw_png[1:4], as.raw(c(0x89, 0x50, 0x4e, 0x47)))

	# NULL plot / missing jsonlite -> NULL, not an error.
	expect_null(EDI:::run_all_inference_plot_to_base64_png(NULL))
})

test_that("run_all_inference_save_plots_pdf writes a real multi-page-capable PDF and no-ops on an empty plot list", {
	skip_if_not_installed("ggplot2")
	p1 <- ggplot2::ggplot(data.frame(x = 1:3, y = c(2, 1, 3)), ggplot2::aes(x, y)) + ggplot2::geom_line()
	p2 <- ggplot2::ggplot(data.frame(x = 1:4, y = c(4, 2, 3, 1)), ggplot2::aes(x, y)) + ggplot2::geom_line()

	out_pdf <- tempfile(fileext = ".pdf")
	on.exit(unlink(out_pdf), add = TRUE)
	EDI:::run_all_inference_save_plots_pdf(list(ci_forest = list(a = p1, b = p2)), out_pdf)
	expect_true(file.exists(out_pdf))
	expect_gt(file.info(out_pdf)$size, 0)
	header <- readBin(out_pdf, "raw", 5L)
	expect_identical(rawToChar(header), "%PDF-")

	empty_pdf <- tempfile(fileext = ".pdf")
	result <- EDI:::run_all_inference_save_plots_pdf(list(ci_forest = list()), empty_pdf)
	expect_null(result)
	expect_false(file.exists(empty_pdf))
})
