library(testthat)
library(EDI)

test_that("run_all_inference: ordinal blocking design (iid, non-KK)", {
	set.seed(20260824)
	n = 60L
	des = DesignFixedBlocking$new(n = n, response_type = "ordinal", strata_cols = "x2", equal_block_sizes = FALSE)
	X = data.frame(x1 = rnorm(n), x2 = sample(c("a", "b"), n, TRUE))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y_latent = 0.6 * w + rnorm(n)
	y = as.integer(cut(y_latent, breaks = c(-Inf, -0.5, 0.5, Inf), labels = FALSE))
	des$add_all_subject_responses(y)
	expect_valid_run_all_inference_report(des, "iid")
})

