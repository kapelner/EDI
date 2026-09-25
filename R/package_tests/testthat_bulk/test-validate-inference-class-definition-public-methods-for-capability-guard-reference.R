library(testthat)
library(EDI)

# contracts_mixins.R's validate_inference_class_definition() has TWO separate public-method-
# presence checks for a class's advertised capabilities, cross-referencing two different tables:
#   1. Against `capability_requires[[capability]]$public_methods` -- "advertises capability %s
#      WITHOUT REQUIRED public method(s): %s" -- already covered (test-validate-inference-class-
#      definition-capability-requirement-guards-reference.R, using the "bayesian_bootstrap"
#      capability).
#   2. Against `public_methods_for_capability[[capability]]` -- a SEPARATE table -- "advertises
#      capability %s WITHOUT public method(s): %s" (no "required"). A codebase-wide grep confirmed
#      this second, textually-similar-but-distinct message had zero test references anywhere.
# Reached directly on the exported-internal validator with just a `metadata` argument declaring
# the "exact_test" capability (whose required methods, compute_exact_confidence_interval /
# compute_exact_two_sided_pval_for_treatment_effect, are listed in public_methods_for_capability),
# no component registration needed.

test_that("a capability advertised in metadata, but missing its public_methods_for_capability entries, errors with the documented (non-'required') message", {
	validate <- getFromNamespace("validate_inference_class_definition", "EDI")
	expect_error(
		validate("Cls", metadata = list(capabilities = "exact_test")),
		"Cls advertises capability exact_test without public method\\(s\\): compute_exact_confidence_interval, compute_exact_two_sided_pval_for_treatment_effect"
	)
})

test_that("supplying both required public methods satisfies the guard", {
	validate <- getFromNamespace("validate_inference_class_definition", "EDI")
	expect_true(validate(
		"Cls",
		public = list(
			compute_exact_confidence_interval = function() NULL,
			compute_exact_two_sided_pval_for_treatment_effect = function() NULL
		),
		metadata = list(capabilities = "exact_test")
	))
})
