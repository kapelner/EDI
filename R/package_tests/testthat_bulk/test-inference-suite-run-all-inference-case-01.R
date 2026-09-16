library(testthat)
library(EDI)

test_that("run_all_inference: continuous iBCRD (iid)", {
	set.seed(20260818)
	n = 30L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	expect_valid_run_all_inference_report(des, "iid")
})

