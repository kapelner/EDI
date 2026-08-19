library(testthat)
library(EDI)

# InferenceIncidKKModifiedPoisson migration (fix_inference_hierarchy.md,
# "Full-Likelihood Estimators", "ModifiedPoisson full-likelihood migration"):
# migrated by migrating the shared abstract grandparent
# InferenceAbstractKKMarginalIncid rather than InferenceAbstractKKModifiedPoisson/
# InferenceIncidKKModifiedPoisson directly (same "migrate the shared base"
# strategy as the KKCondLogitGLMM/KKOrdinalCLMM families earlier this
# stretch). InferenceAbstractKKMarginalIncid flipped from the raw-splice
# `utils::modifyList(as.list(InferenceMixinKKPassThrough$public/private),
# list(...))` state (manual harvesting under `inherit =
# InferenceParamBootstrap`, not even a `define_inference_class()` call) to
# `inherit = Inference` with `components = c("BayesianBootstrap",
# "ParametricLikelihoodBootstrap", "KKPassThrough")` -- ParametricLikelihoodBootstrap
# (not Wald-only) because InferenceAbstractKKModifiedPoisson genuinely
# overrides `supports_likelihood_tests()`/`supports_lik_ratio_param_bootstrap()`
# to TRUE with its own real `get_likelihood_test_spec()`/
# `simulate_under_lik_null()` -- unlike every Wald-only KK partial-likelihood
# class fixed earlier this stretch. `InferenceAbstractKKModifiedPoisson` and
# `InferenceIncidKKModifiedPoisson` themselves needed no changes (no
# `super$...()` calls in either body).
#
# This migration also surfaced two real bugs in the previously-untouched
# InferenceIncidKKGCompAbstract (a sibling descendant of
# InferenceAbstractKKMarginalIncid, already migrated to its own
# define_inference_class() via IncidenceKKGComputation, but deliberately
# kept as a real R6 generator for component harvesting and as the ancestor
# of test-incid-kk-gcomp-migration-golden.R's legacy fixture):
#   (1) six `super$compute_bootstrap_confidence_interval()`/`compute_bootstrap_
#       two_sided_pval()`/`compute_bayesian_bootstrap_*()`/`compute_jackknife_
#       wald_*()` calls in InferenceIncidKKGCompAbstract's OWN class body
#       (distinct from the separately-harvested IncidenceKKGComputationSource,
#       which already had the fix) were valid under the old deep R6 ladder but
#       became infinite self-recursion once their parent flattened -- fixed by
#       applying the same generic-self-aliased-override pattern directly to
#       that class's own body (see inference_incidence_KK_gcomp_abstract.R).
#   (2) InferenceExtCIInversion's `private$get_standard_error()` call (reached
#       via ParametricLikelihoodBootstrap -> LikelihoodTests, now genuinely
#       composed) hits Wald's raw stop()-throwing stub instead of a graceful
#       NA-returning fallback, because InferenceMLEorKMSummaryTable's private
#       override (which provided that gracefully under the old deep ladder)
#       was never extracted into any registered component -- a real,
#       pre-existing architectural gap, but confined entirely to
#       test-incid-kk-gcomp-migration-golden.R's legacy-only score_ci/
#       gradient_ci/lik_ratio_ci probes (the real migrated GComp classes never
#       compose ParametricLikelihoodBootstrap at all); tolerated there via the
#       same maybe_dropped_labels mechanism already used for other leaked
#       ladder surface, not fixed at the component level (out of scope: would
#       require adding a graceful get_standard_error to the Wald/LikelihoodTests
#       component itself, affecting classes far beyond this migration).
#
# The legacy fixture below (fixtures/legacy_incid_kk_modified_poisson.R) is
# the pre-migration file content of InferenceAbstractKKMarginalIncid (from
# inference_incidence_KK_marginal_abstract.R, git HEAD) plus the UNCHANGED
# InferenceAbstractKKModifiedPoisson/InferenceIncidKKModifiedPoisson (from
# inference_incidence_KK_marginal.R, never touched by this migration),
# re-parented to the renamed legacy base -- top-level class bindings renamed
# to avoid colliding with the real migrated classes, literal class-name
# STRINGs kept unchanged for dispatch-by-name policies.
make_incid_kk_modified_poisson_legacy_env = function() {
	env = new.env(parent = asNamespace("EDI"))
	sys.source(testthat::test_path("fixtures", "legacy_incid_kk_modified_poisson.R"), envir = env)
	env
}

incid_kk_modified_poisson_golden_design = function(n = 60L, seed = 20260819L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			des$add_one_subject_response(i, rbinom(1L, 1L, plogis(-0.4 + 0.5 * ((w_i + 1) / 2) + 0.2 * X$x1[i])))
		}
		des
	})
}

test_that("InferenceIncidKKModifiedPoisson migration produces identical outputs", {
	env = make_incid_kk_modified_poisson_legacy_env()
	Legacy = get("InferenceIncidKKModifiedPoissonLegacyOrig", envir = env)
	des = incid_kk_modified_poisson_golden_design()
	legacy = Legacy$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	migrated = InferenceIncidKKModifiedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	for (label in names(inference_migration_method_calls)) {
		spec = inference_migration_method_calls[[label]]
		legacy$set_seed(20260819L)
		legacy_result = inference_migration_with_seed(20260819L,
			inference_migration_call_optional_method(legacy, spec$method, spec$args))
		migrated$set_seed(20260819L)
		migrated_result = inference_migration_with_seed(20260819L,
			inference_migration_call_optional_method(migrated, spec$method, spec$args))
		if (legacy_result$status %in% c("absent", "unsupported") &&
				migrated_result$status %in% c("absent", "unsupported")) {
			next
		}
		expect_identical(legacy_result$status, migrated_result$status, info = label)
		if (identical(legacy_result$status, "ok")) {
			expect_equal(migrated_result$value, legacy_result$value, tolerance = 1e-6, info = label)
		}
	}
})

test_that("InferenceAbstractKKMarginalIncid base is marked migrated", {
	# InferenceAbstractKKModifiedPoisson/InferenceIncidKKModifiedPoisson
	# plain-R6-inherit rather than composing directly, so their own
	# migration_status stays "pending" under
	# build_inference_hierarchy_migration_record()'s heuristic (it only
	# auto-detects "migrated" when a class's *immediate* parent is
	# "Inference") -- same as every other already-migrated
	# InferenceAsympLikStdModCache-style leaf. What matters is the shared
	# abstract base itself.
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceAbstractKKMarginalIncid")
	expect_identical(metadata$parent, "Inference")
})
