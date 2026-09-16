library(testthat)
library(EDI)

test_that("run_all_inference: count iBCRD (iid)", {
	set.seed(20260823)
	n = 40L
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(rpois(n, exp(0.5 + 0.4 * w + 0.2 * X$x1)))
	res = expect_valid_run_all_inference_report(des, "iid", basic_bootstrap = TRUE)
	expect_canonical_class_ok(res, "InferenceCountPoisson")
})

