library(testthat)
library(EDI)

# InferenceSuite$initialize()'s inference_params validation block (inference_suite.R, ~line 4400) has
# three sibling guards, all previously untested: a class name not applicable to the design's
# response_type ("is not applicable for this design/response_type combination"), a params entry that
# isn't itself a list ("params for '<class>' must be a list."), and a params entry with an argument
# name that isn't a formal of that class's initialize() ("unknown argument(s) for '<class>': ...").
# All three fire at construction time, before any inference is run.

fx <- function(seed = 1L, n = 10L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	des
}

test_that("InferenceSuite$new(): a class not applicable to the design's response_type errors with the documented message", {
	des <- fx(seed = 1L)
	expect_error(
		InferenceSuite$new(des, inference_params = list(InferenceIncidRiskDiff = list())),
		"InferenceSuite: 'InferenceIncidRiskDiff' is not applicable for this design/response_type combination\\."
	)
})

test_that("InferenceSuite$new(): a non-list inference_params entry errors with the documented message", {
	des <- fx(seed = 2L)
	expect_error(
		InferenceSuite$new(des, inference_params = list(InferenceContinLin = "not_a_list")),
		"InferenceSuite: params for 'InferenceContinLin' must be a list\\."
	)
})

test_that("InferenceSuite$new(): an unknown constructor argument name errors with the documented message", {
	des <- fx(seed = 3L)
	expect_error(
		InferenceSuite$new(des, inference_params = list(InferenceContinLin = list(bogus_arg_xyz = 1))),
		"InferenceSuite: unknown argument\\(s\\) for 'InferenceContinLin': bogus_arg_xyz"
	)
})

test_that("InferenceSuite$new(): well-formed inference_params for an applicable class constructs without error", {
	des <- fx(seed = 4L)
	expect_no_error(InferenceSuite$new(des, inference_params = list(InferenceContinLin = list(verbose = FALSE))))
})
