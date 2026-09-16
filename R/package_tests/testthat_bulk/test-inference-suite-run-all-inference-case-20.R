library(testthat)
library(EDI)

test_that("run_all_inference: screen/html both FALSE is a hard error, not a silent no-op", {
	set.seed(20260818)
	n = 10L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	suite = InferenceSuite$new(des)
	expect_error(
		suite$run_all_inference(screen = FALSE, html = FALSE),
		"at least one of `screen`/`html` must be TRUE",
		fixed = TRUE
	)
})

