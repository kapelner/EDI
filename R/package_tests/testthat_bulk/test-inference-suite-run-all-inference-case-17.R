library(testthat)
library(EDI)

test_that("run_all_inference: ordinal KK14 (matched pair)", {
	set.seed(20260823)
	n = 20L
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	}
	y_latent = rnorm(n)
	y = as.integer(cut(y_latent, breaks = c(-Inf, -0.5, 0.5, Inf), labels = FALSE))
	des$add_all_subject_responses(y)
	expect_valid_run_all_inference_report(des, "kk_matched_pair", basic_bootstrap = TRUE)
})

