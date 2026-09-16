library(testthat)
library(EDI)

test_that("run_all_inference: survival iBCRD (iid)", {
	skip_if_not_installed("survival")
	set.seed(20260823)
	n = 60L
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rexp(n, 0.1 * exp(-0.3 * w + 0.1 * X$x1))
	dead = rbinom(n, 1, 0.8)
	y_exact = ifelse(dead == 1, y, NA_real_)
	y_L = ifelse(dead == 1, NA_real_, y)
	y_R = ifelse(dead == 1, NA_real_, Inf)
	des$add_all_subject_responses(y_exact, y_L, y_R)
	res = expect_valid_run_all_inference_report(des, "iid", basic_bootstrap = TRUE)
	expect_canonical_class_ok(res, "InferenceSurvivalCoxPHRegr")
})

