library(testthat)
library(EDI)

test_that("run_all_inference: survival KK14 (matched pair)", {
	skip_if_not_installed("survival")
	set.seed(20260823)
	n = 20L
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	}
	y = rexp(n, 0.2)
	dead = rbinom(n, 1, 0.8)
	y_exact = ifelse(dead == 1, y, NA_real_)
	y_L = ifelse(dead == 1, NA_real_, y)
	y_R = ifelse(dead == 1, NA_real_, Inf)
	des$add_all_subject_responses(y_exact, y_L, y_R)
	expect_valid_run_all_inference_report(des, "kk_matched_pair", basic_bootstrap = TRUE)
})

