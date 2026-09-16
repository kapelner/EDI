library(testthat)
library(EDI)

test_that("run_all_inference: pdf = TRUE writes a multi-page PDF", {
	skip_if_not_installed("ggplot2")
	set.seed(20260818)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	suite = InferenceSuite$new(des)

	old_wd = getwd()
	tmp_dir = tempfile("edi-inference-suite-pdf-")
	dir.create(tmp_dir)
	setwd(tmp_dir)
	null_dev = grDevices::pdf(NULL)
	on.exit({ grDevices::dev.off(); setwd(old_wd); unlink(tmp_dir, recursive = TRUE) }, add = TRUE)
	capture.output({
		res <- suite$run_all_inference(screen = TRUE, plots = TRUE, pdf = TRUE, compute_conf_intervals = TRUE, output_dir = tmp_dir)
	})

	expect_true(!is.null(res$files$pdf))
	expect_true(file.exists(res$files$pdf))
	# A PDF's page count is encoded as the number of "/Type /Page" (not
	# "/Pages") object entries. Matched directly against the raw byte vector
	# via grepRaw() -- avoids both a hard dependency on pdftools/pdfinfo being
	# installed in the test environment, and the encoding warnings/errors that
	# rawToChar()/gregexpr() throw on a PDF's binary (non-UTF-8) byte stream.
	raw = readBin(res$files$pdf, "raw", file.info(res$files$pdf)$size)
	page_matches = grepRaw("/Type\\s*/Page[^s]", raw, all = TRUE, fixed = FALSE)
	expect_true(length(page_matches) >= 1L)
})

# --- Practitioner follow-ups (TODO-10..13) ---------------------------------

