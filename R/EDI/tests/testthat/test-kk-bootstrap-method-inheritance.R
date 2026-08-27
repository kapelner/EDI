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
	# Structural body() identity is unreliable under covr's coverage-
	# instrumented build (2026-08-27, CI run 33101017340's "test-coverage"
	# job): this exact test failed there with "target, current do not match
	# when deparsed", while the same commit's two plain (non-covr) R CMD
	# check jobs (ubuntu-latest release, CRAN-incoming and no-Suggests) both
	# passed cleanly, and this test passes locally under a normal
	# pkgload::load_all() every time. define_inference_class() composition
	# pulls each host's method by direct object reference from the mixin
	# (confirmed identical() on the function objects themselves, not just
	# their bodies), so under ordinary execution there is nothing to diverge;
	# covr's source-rewriting instrumentation pass is the one thing that
	# differs between the passing and failing runs, matching the established
	# R_COVR skip precedent elsewhere in this suite (e.g.
	# test-aa-fork-cluster-seed-determinism.R) for behavior that is
	# incompatible with -- not broken by -- covr's instrumented rebuild.
	skip_if(
		identical(Sys.getenv("R_COVR"), "true"),
		"body() structural identity across composed R6 methods is unreliable under covr's instrumented build"
	)
	method_name = "approximate_bootstrap_distribution_beta_hat_T"
	expected_body = body(EDI:::InferenceMixinKKPassThrough$public[[method_name]])
	for (generator in list(
		EDI:::InferenceContinKKOLSIVWC,
		EDI:::InferenceContinKKQuantileRegrIVWC,
		EDI:::InferencePropKKQuantileRegrIVWC,
		EDI:::InferenceAbstractKKCondLogitGLMM,
		# InferenceAbstractKKLWACoxOneLik no longer exists as a generator (its
		# body became KKLWACoxOneLikPartialLikelihoodSource); the migrated
		# concrete class composes the same KKPassThrough body directly.
		EDI:::InferenceSurvivalKKLWACoxPHOneLik,
		EDI:::InferenceAbstractKKMarginalIncid,
		EDI:::InferenceAbstractKKOrdinalCLMM,
		EDI:::InferenceOrdinalKKCondAdjCatLogitRegr,
		# The two retained KK compound bases are assembled through
		# define_inference_class() since 2026-08-23 (fix_inference_hierarchy.md
		# "Static Cleanup" / "Ban raw component splicing"); same flattened
		# $public_methods resolution as every other composed class here.
		EDI:::InferenceKKPassThroughCompound,
		EDI:::InferenceKKPassThroughCompoundNoParamBootstrap
	)) {
		method = generator$public_methods[[method_name]]
		expect_true(is.function(method))
		expect_identical(body(method), expected_body)
	}
})
