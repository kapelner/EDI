library(testthat)
library(EDI)

test_that("run_all_inference: save_results_as_JSON writes a file that round-trips", {
	skip_if_not_installed("jsonlite")
	set.seed(20260818)
	n = 10L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	suite = InferenceSuite$new(des)

	old_wd = getwd()
	tmp_dir = tempfile("edi-inference-suite-json-")
	dir.create(tmp_dir)
	setwd(tmp_dir)
	on.exit({ setwd(old_wd); unlink(tmp_dir, recursive = TRUE) }, add = TRUE)
	capture.output({
		res <- suite$run_all_inference(screen = TRUE, save_results_as_JSON = TRUE, plots = FALSE, output_dir = tmp_dir)
	})

	expect_true(!is.null(res$files$json))
	expect_true(file.exists(res$files$json))
	parsed = jsonlite::fromJSON(res$files$json)
	expect_identical(nrow(parsed$results_table), nrow(res$results_table))
	expect_identical(sort(names(parsed$results)), sort(names(res$results)))
})

