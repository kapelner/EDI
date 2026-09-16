library(testthat)
library(EDI)

test_that("run_all_inference: html writes a self-contained file and returns its path", {
	set.seed(20260818)
	n = 10L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	suite = InferenceSuite$new(des)

	old_wd = getwd()
	old_browser = getOption("browser")
	tmp_dir = tempfile("edi-inference-suite-html-")
	dir.create(tmp_dir)
	setwd(tmp_dir)
	options(browser = function(url) invisible(NULL))
	on.exit({ setwd(old_wd); options(browser = old_browser); unlink(tmp_dir, recursive = TRUE) }, add = TRUE)
	res = suite$run_all_inference(screen = FALSE, html = TRUE, plots = FALSE, output_dir = tmp_dir)

	expect_true(!is.null(res$files$html))
	expect_true(file.exists(res$files$html))
	html_txt = paste(readLines(res$files$html, warn = FALSE), collapse = "\n")
	expect_true(grepl("<!DOCTYPE html>", html_txt, fixed = TRUE))
	expect_false(grepl("<script", html_txt, fixed = TRUE))
	expect_false(grepl("http://", html_txt, fixed = TRUE))
	expect_false(grepl("https://", html_txt, fixed = TRUE))
})

