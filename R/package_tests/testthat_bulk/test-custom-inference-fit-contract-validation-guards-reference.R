library(testthat)
library(EDI)

# inference_custom_extensions.R's InferenceCustomAsymp has three sibling contract guards around
# user-supplied fit() implementations: the base class's own fit() stop()s "Custom inference
# subclasses must implement public$fit(estimate_only = FALSE)." when a subclass doesn't override it
# at all, and cache_custom_fit_result() -- reached via compute_estimate()/compute_asymp_*() --
# stop()s "Custom inference fit() must return a named list." when fit() doesn't return a list, or
# "Custom inference fit() result must include numeric scalar 'estimate'." when the returned list has
# no numeric scalar $estimate. The success path (a well-formed fit()) is exercised by
# test-custom-extension-contract.R, but none of these three contract-violation guards had any test
# references anywhere.

des_fx <- function() {
	des <- DesignFixedBernoulli$new(n = 20, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(20)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), each = 10))
	des$add_all_subject_responses(c(1:10, 12:21))
	des
}

test_that("the base InferenceCustomAsymp's own unimplemented fit() errors with the documented message", {
	InferenceCustomAsymp <- getFromNamespace("InferenceCustomAsymp", "EDI")
	inf <- InferenceCustomAsymp$new(des_fx(), verbose = FALSE)
	expect_error(
		inf$compute_estimate(),
		"Custom inference subclasses must implement public\\$fit\\(estimate_only = FALSE\\)\\."
	)
})

test_that("a fit() that doesn't return a list errors with the documented message", {
	InferenceCustomAsymp <- getFromNamespace("InferenceCustomAsymp", "EDI")
	BadFitNotList <- R6::R6Class("BadFitNotList", inherit = InferenceCustomAsymp, lock_objects = FALSE,
		public = list(fit = function(estimate_only = FALSE) 42))
	inf <- BadFitNotList$new(des_fx(), verbose = FALSE)
	expect_error(
		inf$compute_estimate(),
		"Custom inference fit\\(\\) must return a named list\\."
	)
})

test_that("a fit() list missing a numeric scalar estimate errors with the documented message", {
	InferenceCustomAsymp <- getFromNamespace("InferenceCustomAsymp", "EDI")
	BadFitNoEstimate <- R6::R6Class("BadFitNoEstimate", inherit = InferenceCustomAsymp, lock_objects = FALSE,
		public = list(fit = function(estimate_only = FALSE) list(se = 1)))
	inf <- BadFitNoEstimate$new(des_fx(), verbose = FALSE)
	expect_error(
		inf$compute_estimate(),
		"Custom inference fit\\(\\) result must include numeric scalar 'estimate'\\."
	)

	BadFitVectorEstimate <- R6::R6Class("BadFitVectorEstimate", inherit = InferenceCustomAsymp, lock_objects = FALSE,
		public = list(fit = function(estimate_only = FALSE) list(estimate = c(1, 2))))
	inf2 <- BadFitVectorEstimate$new(des_fx(), verbose = FALSE)
	expect_error(
		inf2$compute_estimate(),
		"Custom inference fit\\(\\) result must include numeric scalar 'estimate'\\."
	)
})
