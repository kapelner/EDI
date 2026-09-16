library(testthat)
library(EDI)

test_that("run_all_inference: classes/exclude_classes filter and validate", {
	set.seed(20260818)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	suite = InferenceSuite$new(des)

	capture.output({
		res_allow <- suite$run_all_inference(screen = TRUE, plots = FALSE,
			classes = c("InferenceContinOLS", "InferenceContinLin"))
	})
	expect_identical(sort(unique(res_allow$results_table$inference_class)), c("InferenceContinLin", "InferenceContinOLS"))

	capture.output({
		res_deny <- suite$run_all_inference(screen = TRUE, plots = FALSE,
			exclude_classes = "InferenceContinOLS")
	})
	expect_false("InferenceContinOLS" %in% res_deny$results_table$inference_class)
	expect_identical(length(unique(res_deny$results_table$inference_class)), length(suite$applicable_design_classes) - 1L)

	expect_error(
		suite$run_all_inference(screen = TRUE, classes = "NotARealInferenceClass"),
		"unknown/inapplicable class"
	)
	expect_error(
		suite$run_all_inference(screen = TRUE, exclude_classes = "NotARealInferenceClass"),
		"unknown/inapplicable class"
	)
})

