context("TODO-116: suite rows explain NA from unsupported/gated procedures")

test_that("a jackknife row of an unsupported-jackknife class stays ok but carries the recorded reason", {
	set.seed(116)
	n = 60L
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(as.integer(rnbinom(n, size = 2, mu = 3)))
	row = EDI:::run_all_inference_one_class(
		"InferenceCountNegBin", des, params = list(), alpha = 0.05,
		design_family = "DesignSeqOneByOneBernoulli", response_type = "count",
		method = "jackknife"
	)
	expect_identical(row$status, "ok")
	expect_true(is.na(row$ci_a))
	expect_true(is.finite(row$estimate))
	expect_true(is.finite(row$se))
	expect_match(row$message, "negbin_jackknife_not_supported", fixed = TRUE)
})
