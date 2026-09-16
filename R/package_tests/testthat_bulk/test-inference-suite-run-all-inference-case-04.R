library(testthat)
library(EDI)

test_that("run_all_inference: continuous KK14 (matched pair)", {
	set.seed(20260818)
	n = 16L
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	}
	des$add_all_subject_responses(rnorm(n))
	expect_valid_run_all_inference_report(des, "kk_matched_pair")
})

