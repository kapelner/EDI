library(testthat)
library(EDI)

test_that("run_all_inference: proportion blocking design (iid, non-KK)", {
	set.seed(20260824)
	n = 30L
	des = DesignFixedBlocking$new(n = n, response_type = "proportion", strata_cols = "x2", equal_block_sizes = FALSE)
	X = data.frame(x1 = rnorm(n), x2 = sample(c("a", "b"), n, TRUE))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	y = pmax(pmin(rbeta(n, 5, 5), 1 - 1e-6), 1e-6)
	des$add_all_subject_responses(y)
	expect_valid_run_all_inference_report(des, "iid")
})

