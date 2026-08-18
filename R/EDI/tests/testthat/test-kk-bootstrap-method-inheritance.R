# InferenceContinKKOLSIVWC (2026-08-18 session) and InferenceContinKKQuantileRegrIVWC
# / InferencePropKKQuantileRegrIVWC (2026-08-18 session, fix_inference_hierarchy.md
# "KK And IVWC Estimators") were migrated to define_inference_class() composition
# since this test was last touched -- a flattened composed class's public methods
# live directly on $public_methods, never via R6 ancestor walk, so the
# "inherit the shared bootstrap implementation" framing (and the
# find_inherited_public_method() helper it used) no longer applies to them. They
# resolve to the same InferenceMixinKKPassThrough body as the still-ladder-based
# hosts below, so they were simply folded into that group instead.
test_that("KK pass-through hosts retain the directly composed bootstrap implementation", {
	method_name = "approximate_bootstrap_distribution_beta_hat_T"
	expected_body = body(EDI:::InferenceMixinKKPassThrough$public[[method_name]])
	for (generator in list(
		EDI:::InferenceContinKKOLSIVWC,
		EDI:::InferenceContinKKQuantileRegrIVWC,
		EDI:::InferencePropKKQuantileRegrIVWC,
		EDI:::InferenceAbstractKKCondLogitGLMM,
		EDI:::InferenceAbstractKKLWACoxOneLik,
		EDI:::InferenceAbstractKKMarginalIncid,
		EDI:::InferenceAbstractKKOrdinalCLMM,
		EDI:::InferenceOrdinalKKCondAdjCatLogitRegr,
		EDI:::InferenceKKPassThroughCompound,
		EDI:::InferenceKKPassThroughCompoundNoParamBootstrap
	)) {
		method = generator$public_methods[[method_name]]
		expect_true(is.function(method))
		expect_identical(body(method), expected_body)
	}
})
