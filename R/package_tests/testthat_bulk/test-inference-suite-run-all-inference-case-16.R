library(testthat)
library(EDI)

test_that("run_all_inference: ordinal iBCRD (iid)", {
	set.seed(20260823)
	n = 60L
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y_latent = 0.6 * w + 0.3 * X$x1 + rnorm(n)
	y = as.integer(cut(y_latent, breaks = c(-Inf, -0.5, 0.5, Inf), labels = FALSE))
	des$add_all_subject_responses(y)
	res = expect_valid_run_all_inference_report(des, "iid", basic_bootstrap = TRUE)
	expect_canonical_class_ok(res, "InferenceOrdinalPropOddsRegr")
})

