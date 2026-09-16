library(testthat)
library(EDI)

test_that("run_all_inference: methods list-shape rejects a type request for a non-typed sentinel", {
	set.seed(20260819)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	suite = InferenceSuite$new(des)

	expect_error(
		suite$run_all_inference(
			screen = TRUE, plots = FALSE,
			classes = "InferenceAllSimpleAverageDiff",
			methods = list(wald = c("percentile"))
		),
		"has no `type` axis"
	)
})
