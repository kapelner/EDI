library(testthat)
library(EDI)

# Two more InferenceSuite$run_all_inference() argument guards, both previously untested:
#
# 1. Each element of a supplied `formulas` list must be a formula object or a single formula
#    string; any other type errors "every element of `formulas` must be a formula object or a
#    single formula string, e.g. ...". Distinct from the already-covered zero-length-formulas guard.
#
# 2. combined_evidence_weighting = "custom" requires `combined_evidence_weights` to be supplied (a
#    named numeric vector); omitting it entirely errors "combined_evidence_weighting = \"custom\"
#    requires `combined_evidence_weights`, ...". Distinct from the already-covered negative-weight,
#    unknown-class-name, and wrong-weighting-scheme guards on the same argument.
#
# Both fire before any model fitting.

fx <- function(seed = 1L, n = 10L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	InferenceSuite$new(des)
}

test_that("run_all_inference(): a formulas element that's neither a formula nor a formula string errors with the documented message", {
	suite <- fx(seed = 1L)
	expect_error(
		suite$run_all_inference(formulas = list(123)),
		"every element of `formulas` must be a formula object or a single formula string"
	)
})

test_that("run_all_inference(): combined_evidence_weighting = \"custom\" with no weights supplied errors with the documented message", {
	suite <- fx(seed = 2L)
	expect_error(
		suite$run_all_inference(combined_evidence_weighting = "custom"),
		"combined_evidence_weighting = \"custom\" requires `combined_evidence_weights`"
	)
})
