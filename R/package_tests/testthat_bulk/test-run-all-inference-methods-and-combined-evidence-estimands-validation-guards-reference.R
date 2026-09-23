library(testthat)
library(EDI)

# InferenceSuite$run_all_inference()'s `methods` and `combined_evidence_estimands` arguments each
# carry more validation guards beyond the ones already closed (screen/html, formulas,
# combined_evidence_weights). All four below had zero test references anywhere:
#
# 1. A list-valued `methods` with no elements (or an element with an empty-string name) errors
#    "a list-valued `methods` must have every element named by the sentinel it requests."
# 2. A `type` value requested for a sentinel that has no `type` axis (only bootstrap/bayes_boot/
#    rand_bootstrap do) errors "which has no `type` axis".
# 3. A `methods` value that isn't one of the recognized sentinels errors "unknown `methods` value(s)".
# 4. A `combined_evidence_estimands` value not among the declared estimands of the classes being fit
#    errors "unknown `combined_evidence_estimands` value(s)".
#
# All four fire before any model fitting.

fx <- function(seed = 1L, n = 10L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	InferenceSuite$new(des)
}

test_that("run_all_inference(): an empty list-valued methods errors with the documented message", {
	suite <- fx(seed = 1L)
	expect_error(
		suite$run_all_inference(methods = list()),
		"a list-valued `methods` must have every element named by the sentinel it requests"
	)
})

test_that("run_all_inference(): a type value for a non-typed sentinel errors with the documented message", {
	suite <- fx(seed = 2L)
	expect_error(
		suite$run_all_inference(methods = list(wald = "percentile")),
		"which has no `type` axis"
	)
})

test_that("run_all_inference(): an unrecognized methods sentinel errors with the documented message", {
	suite <- fx(seed = 3L)
	expect_error(
		suite$run_all_inference(methods = c("not_a_real_sentinel")),
		"unknown `methods` value\\(s\\): not_a_real_sentinel"
	)
})

test_that("run_all_inference(): an undeclared combined_evidence_estimands value errors with the documented message", {
	suite <- fx(seed = 4L)
	expect_error(
		suite$run_all_inference(combined_evidence_estimands = "not_a_real_estimand_xyz"),
		"unknown `combined_evidence_estimands` value\\(s\\): not_a_real_estimand_xyz"
	)
})
