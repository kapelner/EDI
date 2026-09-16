library(testthat)
library(EDI)

test_that("run_all_inference: proportion KK14 (matched pair)", {
	set.seed(20260823)
	n = 20L
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "proportion", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	}
	y = pmax(pmin(rbeta(n, 5, 5), 1 - 1e-6), 1e-6)
	des$add_all_subject_responses(y)
	expect_valid_run_all_inference_report(des, "kk_matched_pair", basic_bootstrap = TRUE)
})

