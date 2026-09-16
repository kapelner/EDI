library(testthat)
library(EDI)

test_that("run_all_inference: incidence blocking design (iid, non-KK)", {
	set.seed(20260818)
	n = 30L
	des = DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "x2", equal_block_sizes = FALSE)
	X = data.frame(x1 = rnorm(n), x2 = sample(c("a", "b"), n, TRUE))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.2 + 0.6 * w)))
	expect_valid_run_all_inference_report(des, "iid")
})

