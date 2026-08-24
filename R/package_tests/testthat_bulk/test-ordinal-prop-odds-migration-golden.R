library(testthat)
library(EDI)

# InferenceOrdinalPropOddsRegr migration (fix_inference_hierarchy.md,
# "Full-Likelihood Estimators"): from `define_inference_class(inherit =
# InferenceParamBootstrap, components = "OrdinalProportionalOddsLikelihood")`
# -- a hybrid state that still R6-inherited the algorithmic compatibility
# base while ALSO composing its own likelihood component -- to `inherit =
# Inference` with `components = c("BayesianBootstrap",
# "ParametricLikelihoodBootstrap", "OrdinalProportionalOddsLikelihood")`.
# This class's own `overrides` list was already comprehensive from an
# earlier partial migration pass, so no new collisions surfaced; the class
# registry's static `infer_inference_direct_components()` mapping (still
# listing the single old component) and this class's entry in the shared
# `test-full-likelihood-migration-baseline.R` expected-components table
# (missing `RandomizationBootstrapCI`, same staleness already fixed for
# Cauchit/Cloglog) were the only things that needed updating. Same golden
# shape as `test-ordinal-cauchit-migration-golden.R`: legacy fixture
# self-harvests `OrdinalProportionalOddsLikelihoodSource` onto the real
# original ancestor `InferenceAsympLikStdModCache`.
make_ordinal_prop_odds_legacy_generator <- function(){
	source = EDI:::OrdinalProportionalOddsLikelihoodSource
	R6::R6Class(
		"InferenceOrdinalPropOddsRegrLegacy",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceAsympLikStdModCache,
		public = source$public,
		private = source$private
	)
}

test_that("InferenceOrdinalPropOddsRegr migration preserves deterministic likelihood outputs", {
	legacy_class = make_ordinal_prop_odds_legacy_generator()
	des = inference_migration_complete_design("ordinal", n = 32L, seed = 20260817L)
	method_calls = inference_migration_method_calls[c(
		"estimate",
		"asymp_ci",
		"asymp_pval",
		"wald_ci",
		"wald_pval",
		"score_pval",
		"lik_ratio_pval",
		"gradient_pval"
	)]

	expect_silent(expect_inference_migration_outputs_equal(
		legacy_class = legacy_class,
		migrated_class = InferenceOrdinalPropOddsRegr,
		design = des,
		method_calls = method_calls,
		tolerance = 1e-7
	))
})

test_that("InferenceOrdinalPropOddsRegr migration preserves seeded resampling outputs", {
	legacy_class = make_ordinal_prop_odds_legacy_generator()
	des = inference_migration_complete_design("ordinal", n = 32L, seed = 20260817L)
	legacy = legacy_class$new(des)
	migrated = InferenceOrdinalPropOddsRegr$new(des)
	method_calls = list(
		bootstrap = list(
			method = "approximate_bootstrap_distribution_beta_hat_T",
			args = list(B = 9L, show_progress = FALSE)
		),
		randomization = list(
			method = "approximate_randomization_distribution_beta_hat_T",
			args = list(r = 9L, show_progress = FALSE)
		),
		bayesian_bootstrap = list(
			method = "approximate_bayesian_bootstrap_distribution_beta_hat_T",
			args = list(B = 9L, show_progress = FALSE)
		),
		parametric_likelihood_bootstrap = list(
			method = "compute_lik_ratio_bootstrap_two_sided_pval",
			args = list(
				delta = 0,
				B = 3L,
				show_progress = FALSE,
				min_number_usable_samples = 1L,
				max_attempts_per_replicate = 3L
			)
		)
	)

	for (label in names(method_calls)) {
		spec = method_calls[[label]]
		legacy$set_seed(20260818L)
		legacy_result = inference_migration_call_optional_method(legacy, spec$method, spec$args)
		migrated$set_seed(20260818L)
		migrated_result = inference_migration_call_optional_method(migrated, spec$method, spec$args)
		expect_identical(migrated_result$status, legacy_result$status, info = label)
		if (identical(legacy_result$status, "ok")) {
			expect_equal(migrated_result$value, legacy_result$value, tolerance = 1e-7, info = label)
		}
	}
})

test_that("InferenceOrdinalPropOddsRegr migration preserves methods without new private-owner duplicates", {
	legacy_class = make_ordinal_prop_odds_legacy_generator()
	before = list(
		methods = inference_migration_public_methods(legacy_class),
		dupes = inference_migration_duplicate_private_owners(legacy_class)
	)
	after = list(
		methods = inference_migration_public_methods(InferenceOrdinalPropOddsRegr),
		dupes = inference_migration_duplicate_private_owners(InferenceOrdinalPropOddsRegr)
	)

	expect_true(all(before$methods %in% after$methods))
	expect_true(all(
		inference_migration_expected_capability_methods("InferenceOrdinalPropOddsRegr") %in%
			after$methods
	))
	expect_no_new_inference_migration_private_owner_duplicates(before$dupes, after$dupes)
})

test_that("InferenceOrdinalPropOddsRegr passes the shallow migration gate", {
	EDI:::populate_inference_component_registry()
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceOrdinalPropOddsRegr")
	record = EDI:::mark_inference_class_migrated("InferenceOrdinalPropOddsRegr")

	expect_identical(metadata$parent, "Inference")
	expect_identical(record$migration_status, "migrated")
	expect_identical(record$algorithmic_compatibility_ancestors, character())
	expect_identical(
		EDI:::get_effective_components("InferenceOrdinalPropOddsRegr"),
		c(
			"RandomizationTest",
			"RandomizationCI",
			"NonparametricBootstrap",
			"RandomizationBootstrap",
			"RandomizationBootstrapCI",
			"BayesianBootstrap",
			"Jackknife",
			"Wald",
			"LikelihoodTests",
			"ParametricLikelihoodBootstrap",
			"StandardModelCache",
			"OrdinalProportionalOddsLikelihood"
		)
	)
})
