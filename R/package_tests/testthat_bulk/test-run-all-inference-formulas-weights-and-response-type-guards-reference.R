library(testthat)
library(EDI)

# Three sibling early-argument guards in inference_suite.R, all previously untested:
#
# 1. run_all_inference_build_tasks() -- the internal task-list builder InferenceSuite$run_all_inference()
#    delegates to -- stop()s "`response_type` is required when excluding comprehensive slow paths."
#    when exclude_comprehensive_slow_paths = TRUE and no response_type can be resolved (neither
#    supplied directly nor inferred from a design object). Directly callable, no InferenceSuite
#    object needed.
#
# 2. InferenceSuite$run_all_inference()'s own `formulas` argument, if supplied as a non-NULL but
#    zero-length list/vector, stop()s "`formulas` must have at least one element if not NULL."
#    before any model fitting.
#
# 3. InferenceSuite$run_all_inference()'s combined_evidence_weighting = "custom" path stop()s
#    "`combined_evidence_weights` must be non-negative." for any negative weight, before any model
#    fitting.
#
# The sibling "screen"/"html" guard on the same method is already covered
# (test-inference-suite-run-all-inference-case-20.R).

test_that("run_all_inference_build_tasks(): excluding comprehensive slow paths with no resolvable response_type errors with the documented message", {
	build_tasks <- getFromNamespace("run_all_inference_build_tasks", "EDI")
	expect_error(
		build_tasks(
			cls_names = "InferenceOrdinalStereotypeLogitRegr",
			formulas = NULL,
			methods = c("wald"),
			des_obj = NULL,
			inference_params = list(),
			type_requests = list(),
			basic_bootstrap = FALSE,
			exclude_comprehensive_slow_paths = TRUE,
			response_type = NULL
		),
		"`response_type` is required when excluding comprehensive slow paths\\.",
	)
})

fx <- function(seed = 1L, n = 10L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	InferenceSuite$new(des)
}

test_that("run_all_inference(): an empty (non-NULL) formulas list errors with the documented message", {
	suite <- fx(seed = 1L)
	expect_error(
		suite$run_all_inference(formulas = list()),
		"`formulas` must have at least one element if not NULL\\.",
	)
})

test_that("run_all_inference(): a negative custom combined_evidence_weights entry errors with the documented message", {
	suite <- fx(seed = 2L)
	expect_error(
		suite$run_all_inference(combined_evidence_weighting = "custom", combined_evidence_weights = c(InferenceContinLin = -1)),
		"`combined_evidence_weights` must be non-negative\\.",
	)
})
