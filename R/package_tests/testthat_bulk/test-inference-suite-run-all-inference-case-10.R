library(testthat)
library(EDI)

test_that("run_all_inference: proportion iBCRD (iid)", {
	set.seed(20260823)
	n = 40L
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	mu = plogis(0.3 + 0.5 * w + 0.2 * X$x1)
	y = pmax(pmin(rbeta(n, mu * 10, (1 - mu) * 10), 1 - 1e-6), 1e-6)
	des$add_all_subject_responses(y)
	res = expect_valid_run_all_inference_report(des, "iid", basic_bootstrap = TRUE)
	expect_canonical_class_ok(res, "InferencePropBetaRegr")
})

