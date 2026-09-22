library(testthat)
library(EDI)

# InferenceCustomRand and InferenceCustomBoot (inference_custom_extensions.R) each carry their own
# copy of the same fit() contract guards already tested for their sibling InferenceCustomAsymp
# (test-custom-inference-fit-contract-validation-guards-reference.R): the base class's own
# unimplemented fit() stop()s "Custom inference subclasses must implement public$fit(estimate_only =
# FALSE)." and compute_estimate() stop()s "Custom inference fit() result must include numeric scalar
# 'estimate'." when a subclass's fit() doesn't return a list with a numeric scalar $estimate. Same
# message text as the Asymp sibling, but two entirely separate, previously-untriggered code sites
# (inference_custom_extensions.R lines ~166/178 for Rand, ~231/243 for Boot).

des_fx <- function() {
	des <- DesignFixedBernoulli$new(n = 20, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(20)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), each = 10))
	des$add_all_subject_responses(c(1:10, 12:21))
	des
}

test_that("InferenceCustomRand: the base unimplemented fit() errors with the documented message", {
	InferenceCustomRand <- getFromNamespace("InferenceCustomRand", "EDI")
	inf <- InferenceCustomRand$new(des_fx(), verbose = FALSE)
	expect_error(
		inf$compute_estimate(),
		"Custom inference subclasses must implement public\\$fit\\(estimate_only = FALSE\\)\\."
	)
})

test_that("InferenceCustomRand: a fit() result missing a numeric scalar estimate errors with the documented message", {
	InferenceCustomRand <- getFromNamespace("InferenceCustomRand", "EDI")
	BadRandFit <- R6::R6Class("BadRandFit", inherit = InferenceCustomRand, lock_objects = FALSE,
		public = list(fit = function(estimate_only = FALSE) list(se = 1)))
	inf <- BadRandFit$new(des_fx(), verbose = FALSE)
	expect_error(
		inf$compute_estimate(),
		"Custom inference fit\\(\\) result must include numeric scalar 'estimate'\\."
	)
})

test_that("InferenceCustomRand: a well-formed fit() succeeds", {
	InferenceCustomRand <- getFromNamespace("InferenceCustomRand", "EDI")
	GoodRandFit <- R6::R6Class("GoodRandFit", inherit = InferenceCustomRand, lock_objects = FALSE,
		public = list(fit = function(estimate_only = FALSE) list(estimate = mean(self$get_response()[self$get_treatment() == 1]) - mean(self$get_response()[self$get_treatment() == 0]))))
	inf <- GoodRandFit$new(des_fx(), verbose = FALSE)
	expect_equal(inf$compute_estimate(), 11)
})

test_that("InferenceCustomBoot: the base unimplemented fit() errors with the documented message", {
	InferenceCustomBoot <- getFromNamespace("InferenceCustomBoot", "EDI")
	inf <- InferenceCustomBoot$new(des_fx(), verbose = FALSE)
	expect_error(
		inf$compute_estimate(),
		"Custom inference subclasses must implement public\\$fit\\(estimate_only = FALSE\\)\\."
	)
})

test_that("InferenceCustomBoot: a fit() result missing a numeric scalar estimate errors with the documented message", {
	InferenceCustomBoot <- getFromNamespace("InferenceCustomBoot", "EDI")
	BadBootFit <- R6::R6Class("BadBootFit", inherit = InferenceCustomBoot, lock_objects = FALSE,
		public = list(fit = function(estimate_only = FALSE) list(se = 1)))
	inf <- BadBootFit$new(des_fx(), verbose = FALSE)
	expect_error(
		inf$compute_estimate(),
		"Custom inference fit\\(\\) result must include numeric scalar 'estimate'\\."
	)
})

test_that("InferenceCustomBoot: a well-formed fit() succeeds", {
	InferenceCustomBoot <- getFromNamespace("InferenceCustomBoot", "EDI")
	GoodBootFit <- R6::R6Class("GoodBootFit", inherit = InferenceCustomBoot, lock_objects = FALSE,
		public = list(fit = function(estimate_only = FALSE) list(estimate = mean(self$get_response()[self$get_treatment() == 1]) - mean(self$get_response()[self$get_treatment() == 0]))))
	inf <- GoodBootFit$new(des_fx(), verbose = FALSE)
	expect_equal(inf$compute_estimate(), 11)
})
