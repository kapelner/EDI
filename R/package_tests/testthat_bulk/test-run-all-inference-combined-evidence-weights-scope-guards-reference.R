library(testthat)
library(EDI)

# Two more sibling combined_evidence_weights guards on InferenceSuite$run_all_inference(), both
# previously untested (distinct from the negative-weight guard closed last iteration): a
# combined_evidence_weighting = "custom" call whose weight-vector names include a class not among
# the ones being fit ("`combined_evidence_weights` names not among the classes being fit: ..."), and
# supplying combined_evidence_weights at all under a non-"custom" weighting scheme ("`combined_
# evidence_weights` is only used when combined_evidence_weighting = \"custom\"; got weighting = ...").
# Both fire before any model fitting.

fx <- function(seed = 1L, n = 10L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	InferenceSuite$new(des)
}

test_that("run_all_inference(): a custom weight naming a class not being fit errors with the documented message", {
	suite <- fx(seed = 1L)
	expect_error(
		suite$run_all_inference(combined_evidence_weighting = "custom", combined_evidence_weights = c(InferenceNoSuchClassXyz = 1)),
		"`combined_evidence_weights` names not among the classes being fit: InferenceNoSuchClassXyz"
	)
})

test_that("run_all_inference(): supplying combined_evidence_weights under a non-custom weighting scheme errors with the documented message", {
	suite <- fx(seed = 2L)
	expect_error(
		suite$run_all_inference(combined_evidence_weighting = "equal", combined_evidence_weights = c(InferenceContinLin = 1)),
		"`combined_evidence_weights` is only used when combined_evidence_weighting = \"custom\"; got weighting = \"equal\"\\."
	)
})
