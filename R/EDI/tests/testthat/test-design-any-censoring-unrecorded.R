# TODO-117: Design$any_censoring() must judge censoring from recorded censored
# responses (y NA with y_L recorded), not from y being NA (= not yet recorded).

test_that("any_censoring() is FALSE before any response is recorded", {
	for (rt in c("continuous", "ordinal", "survival", "incidence")) {
		des = DesignFixedBernoulli$new(n = 6, response_type = rt, verbose = FALSE)
		expect_false(des$any_censoring(), info = rt)
	}
	seq_des = DesignSeqOneByOneBernoulli$new(n = 6, response_type = "continuous", verbose = FALSE)
	expect_false(seq_des$any_censoring())
})

test_that("applicable_inference_class_names() is unchanged by recording responses", {
	set.seed(1)
	des = DesignFixedBernoulli$new(n = 8, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(a = rnorm(8), b = rnorm(8)))
	des$assign_w_to_all_subjects()
	before = des$applicable_inference_class_names()
	expect_true(all(c("InferenceAllSimpleMeanDiffPooledVar", "InferenceAllSimpleWilcox") %in% before) ||
		length(before) > 0L)
	des$add_all_subject_responses(sample(1:3, 8, TRUE))
	expect_false(des$any_censoring())
	expect_identical(sort(des$applicable_inference_class_names()), sort(before))
})

test_that("any_censoring() ignores unrecorded subjects but detects recorded censoring", {
	set.seed(2)
	des = DesignSeqOneByOneBernoulli$new(n = 6, response_type = "survival", verbose = FALSE)
	for (i in 1:6) des$add_one_subject_to_experiment_and_assign(data.frame(a = rnorm(1)))
	for (i in 1:3) des$add_one_subject_response(i, y = i)
	expect_false(des$any_censoring())
	des$add_one_subject_response(4, y_L = 2, y_R = Inf)
	expect_true(des$any_censoring())

	des2 = DesignFixedBernoulli$new(n = 4, response_type = "survival", verbose = FALSE)
	des2$add_all_subjects_to_experiment(data.frame(a = rnorm(4)))
	des2$assign_w_to_all_subjects()
	des2$add_all_subject_responses(ys = c(1, 2, NA, 4), y_Ls = c(NA, NA, 3, NA), y_Rs = c(NA, NA, Inf, NA))
	expect_true(des2$any_censoring())
	des2$add_all_subject_responses(ys = c(1, 2, 3, 4))
	expect_false(des2$any_censoring())
})
