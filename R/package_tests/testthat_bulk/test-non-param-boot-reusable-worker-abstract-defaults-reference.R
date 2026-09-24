library(testthat)
library(EDI)

# InferenceNonParamBootstrap's own base-class private methods load_bootstrap_sample_into_worker()/
# compute_bootstrap_worker_estimate() (inference_all_abstract_non_param_boot.R) are abstract defaults:
# every concrete bootstrap-capable class that actually supports the reusable-bootstrap-worker
# mechanism overrides both (confirmed: InferenceAllSimpleAverageDiff's own private$
# has_private_method("load_bootstrap_sample_into_worker") reports TRUE, dispatching to its own
# design-backed/compute-treatment-estimate implementations, never reaching this base default). A
# codebase-wide grep confirmed the shared message "Reusable bootstrap workers are not implemented for
# this class." had zero test references anywhere. Real, directly-callable code -- not dead -- reached
# by pulling the two functions straight off the InferenceNonParamBootstrap R6 generator's own
# private_methods list (EDI:::InferenceNonParamBootstrap$private_methods$<name>), independent of any
# concrete subclass's own override.

test_that("InferenceNonParamBootstrap's own load_bootstrap_sample_into_worker() default raises the documented not-implemented error", {
	fn <- EDI:::InferenceNonParamBootstrap$private_methods$load_bootstrap_sample_into_worker
	expect_error(
		fn(list(), 1:5),
		"Reusable bootstrap workers are not implemented for this class.",
		fixed = TRUE
	)
})

test_that("InferenceNonParamBootstrap's own compute_bootstrap_worker_estimate() default raises the same documented error", {
	fn <- EDI:::InferenceNonParamBootstrap$private_methods$compute_bootstrap_worker_estimate
	expect_error(
		fn(list()),
		"Reusable bootstrap workers are not implemented for this class.",
		fixed = TRUE
	)
})
