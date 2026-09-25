library(testthat)
library(EDI)

# inference_class_registry.R's build_partial_likelihood_behavior_record()/build_full_likelihood_
# behavior_record() each guard against being called on a class outside their own target set:
#   1. build_partial_likelihood_behavior_record(name): name must be a key in
#      EDI_PARTIAL_LIKELIHOOD_TARGETS -- "<name> is not a registered partial-likelihood migration
#      target."
#   2. build_full_likelihood_behavior_record(name): metadata$likelihood_tier must be "full" and the
#      class must be concrete (not abstract) -- "<name> is not a concrete full-likelihood inference
#      class." A non-full-tier class (e.g. InferenceAllSimpleAverageDiff, likelihood_tier = "none")
#      is rejected by this guard.
# A codebase-wide grep confirmed both exact messages had zero test references anywhere, distinct
# from the sibling "is not a registered X migration target"/"is not a registered custom
# randomization host" guards on OTHER functions (build_quasi_robust_behavior_record,
# build_custom_randomization_behavior_record) that are already covered in
# test-inference-registry-quasi-robust-and-custom-randomization-behavior-records-reference.R.
# Exercised via direct namespace calls, no fixture registration needed.

test_that("build_partial_likelihood_behavior_record() rejects a name that isn't a registered partial-likelihood target", {
	expect_error(
		EDI:::build_partial_likelihood_behavior_record("NotARealClassXYZ"),
		"NotARealClassXYZ is not a registered partial-likelihood migration target\\.",
	)
})

test_that("build_full_likelihood_behavior_record() rejects a class whose likelihood_tier isn't 'full'", {
	metadata <- EDI:::get_inference_class_metadata("InferenceAllSimpleAverageDiff")
	expect_false(identical(metadata$likelihood_tier, "full"))
	expect_error(
		EDI:::build_full_likelihood_behavior_record("InferenceAllSimpleAverageDiff"),
		"InferenceAllSimpleAverageDiff is not a concrete full-likelihood inference class\\.",
	)
})
