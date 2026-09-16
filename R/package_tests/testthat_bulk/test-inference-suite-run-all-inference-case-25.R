library(testthat)
library(EDI)

test_that("run_all_inference: print()/summary() S3 methods dispatch correctly", {
	set.seed(20260818)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	suite = InferenceSuite$new(des)
	capture.output({
		# methods = "wald" pins this to exactly one row: `methods = NULL`
		# (default) fans out to one row per applicable method sentinel per
		# class, which is beside the point for a print()/summary() dispatch
		# check.
		res <- suite$run_all_inference(screen = TRUE, plots = FALSE, classes = "InferenceContinOLS", methods = "wald")
	})

	printed = capture.output(print(res))
	expect_true(any(grepl("EDIInferenceSuiteResults", printed, fixed = TRUE)))
	# The printed table shows EDI:::inference_class_short_label()'s
	# abbreviation ("OLS"), not the raw class name -- deliberate, for
	# readability.
	expect_true(any(grepl(EDI:::inference_class_short_label("InferenceContinOLS"), printed, fixed = TRUE)))

	smry = summary(res)
	expect_s3_class(smry, "summary.EDIInferenceSuiteResults")
	expect_identical(smry$n_classes, 1L)
	expect_identical(unname(smry$status_counts[["ok"]]), 1L)
	expect_identical(smry$alpha, 0.05)

	smry_printed = capture.output(print(smry))
	expect_true(any(grepl("summary", smry_printed, fixed = TRUE)))
	expect_true(any(grepl("classes:", smry_printed, fixed = TRUE)))
})

