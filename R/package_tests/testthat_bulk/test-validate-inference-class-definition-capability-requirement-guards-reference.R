library(testthat)
library(EDI)

# contracts_mixins.R's validate_inference_class_definition() cross-checks a class's advertised
# capabilities (metadata$capabilities) against capability_requires: a disallowed likelihood_tier, a
# missing required public method, or a missing required private method each stop() with a
# capability-specific message. test-mixin-contracts.R only exercises the success path
# (expect_silent), and the "root-owned state" sibling guard is already covered dynamically by
# test-static-cleanup-guardrails.R -- but these three capability-requirement guards had no test
# triggering them. Reachable directly on the exported-internal validator with just a `metadata`
# argument, no component registration needed.

test_that("a capability advertised with a disallowed likelihood_tier errors with the documented message", {
	validate <- getFromNamespace("validate_inference_class_definition", "EDI")
	expect_error(
		validate("Cls", metadata = list(capabilities = "likelihood_tests", likelihood_tier = "none")),
		"Cls advertises capability likelihood_tests with disallowed likelihood tier `none`\\."
	)
})

test_that("a capability missing its required private method errors with the documented message", {
	validate <- getFromNamespace("validate_inference_class_definition", "EDI")
	expect_error(
		validate("Cls", metadata = list(capabilities = "likelihood_tests", likelihood_tier = "quasi")),
		"Cls advertises capability likelihood_tests without required private method\\(s\\): get_likelihood_test_spec"
	)
})

test_that("a capability missing its required public method errors with the documented message", {
	validate <- getFromNamespace("validate_inference_class_definition", "EDI")
	expect_error(
		validate("Cls", metadata = list(capabilities = "bayesian_bootstrap")),
		"Cls advertises capability bayesian_bootstrap without required public method\\(s\\): compute_estimate_with_bootstrap_weights"
	)
})
