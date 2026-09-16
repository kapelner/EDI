library(testthat)
library(EDI)

test_that("run_all_inference: survival blocking design (iid, non-KK)", {
	skip_if_not_installed("survival")
	set.seed(20260824)
	n = 60L
	des = DesignFixedBlocking$new(n = n, response_type = "survival", strata_cols = "x2", equal_block_sizes = FALSE)
	X = data.frame(x1 = rnorm(n), x2 = sample(c("a", "b"), n, TRUE))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rexp(n, 0.1 * exp(-0.3 * w))
	dead = rbinom(n, 1, 0.8)
	y_exact = ifelse(dead == 1, y, NA_real_)
	y_L = ifelse(dead == 1, NA_real_, y)
	y_R = ifelse(dead == 1, NA_real_, Inf)
	des$add_all_subject_responses(y_exact, y_L, y_R)
	expect_valid_run_all_inference_report(des, "iid")
})

