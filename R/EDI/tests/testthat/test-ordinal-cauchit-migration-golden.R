library(testthat)
library(EDI)

make_ordinal_cauchit_legacy_generator <- function(){
	source = EDI:::OrdinalCauchitLikelihoodSource
	R6::R6Class(
		"InferenceOrdinalCauchitRegrLegacy",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceAsympLikStdModCache,
		public = source$public,
		private = source$private
	)
}

test_that("InferenceOrdinalCauchitRegr migration preserves deterministic likelihood outputs", {
	legacy_class = make_ordinal_cauchit_legacy_generator()
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
		migrated_class = InferenceOrdinalCauchitRegr,
		design = des,
		method_calls = method_calls,
		tolerance = 1e-7
	))
})

test_that("InferenceOrdinalCauchitRegr migration preserves seeded resampling outputs", {
	legacy_class = make_ordinal_cauchit_legacy_generator()
	des = inference_migration_complete_design("ordinal", n = 32L, seed = 20260817L)
	legacy = legacy_class$new(des)
	migrated = InferenceOrdinalCauchitRegr$new(des)
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

test_that("InferenceOrdinalCauchitRegr migration preserves methods without new private-owner duplicates", {
	legacy_class = make_ordinal_cauchit_legacy_generator()
	before = list(
		methods = inference_migration_public_methods(legacy_class),
		dupes = inference_migration_duplicate_private_owners(legacy_class)
	)
	after = list(
		methods = inference_migration_public_methods(InferenceOrdinalCauchitRegr),
		dupes = inference_migration_duplicate_private_owners(InferenceOrdinalCauchitRegr)
	)

	expect_true(all(before$methods %in% after$methods))
	expect_true(all(
		inference_migration_expected_capability_methods("InferenceOrdinalCauchitRegr") %in%
			after$methods
	))
	expect_no_new_inference_migration_private_owner_duplicates(before$dupes, after$dupes)
})

test_that("InferenceOrdinalCauchitRegr passes the shallow migration gate", {
	EDI:::populate_inference_component_registry()
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceOrdinalCauchitRegr")
	record = EDI:::mark_inference_class_migrated("InferenceOrdinalCauchitRegr")

	expect_identical(metadata$parent, "Inference")
	expect_identical(record$migration_status, "migrated")
	expect_identical(record$algorithmic_compatibility_ancestors, character())
	expect_identical(
		EDI:::get_effective_components("InferenceOrdinalCauchitRegr"),
		c(
			"RandomizationTest",
			"RandomizationCI",
			"NonparametricBootstrap",
			"RandomizationBootstrap",
			"BayesianBootstrap",
			"Jackknife",
			"Wald",
			"LikelihoodTests",
			"ParametricLikelihoodBootstrap",
			"StandardModelCache",
			"OrdinalCauchitLikelihood"
		)
	)
})
