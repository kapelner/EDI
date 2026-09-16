library(testthat)
library(EDI)

test_that("run_all_inference: incidence iBCRD (iid)", {
	set.seed(20260818)
	n = 30L
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.2 + 0.6 * w)))
	expect_valid_run_all_inference_report(des, "iid")
})

