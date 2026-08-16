library(testthat)
library(EDI)

# InferenceIncidWald migration (fix_inference_hierarchy.md, "Asymptotic (Wald)
# No-Likelihood Migration"): from `R6::R6Class(inherit =
# InferenceAllSimpleMeanDiff, ...)` to `define_inference_class()` composing
# `BayesianBootstrap`/`Wald`/`SimpleMeanDifference` directly, with the same
# `initialize`/`get_standard_error`/`get_degrees_of_freedom`/
# `compute_incidence_wald_components` overrides verbatim. This legacy
# generator is a byte-for-byte copy of the pre-migration class body, used only
# to prove the migrated class produces identical outputs.
make_incid_wald_legacy_generator = function() {
	R6::R6Class(
		"InferenceIncidWaldLegacy",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceAllSimpleMeanDiff,
		public = list(
			initialize = function(des_obj, model_formula = NULL, verbose = FALSE){
				if (EDI:::should_run_asserts()) {
					EDI:::assertResponseType(des_obj$get_response_type(), "incidence")
				}
				super$initialize(des_obj, verbose = verbose, model_formula = model_formula)
				if (EDI:::should_run_asserts()) {
					EDI:::assertNoCensoring(private$any_censoring)
				}
			}
		),
		private = list(
			get_standard_error = function(){
				if (is.null(private$cached_values$incidence_wald_se)) {
					private$compute_incidence_wald_components()
				}
				private$cached_values$incidence_wald_se
			},
			get_degrees_of_freedom = function(){
				NA_real_
			},
			compute_incidence_wald_components = function(){
				if (is.null(private$cached_values$beta_hat_T)) {
					self$compute_estimate()
				}
				y_t = private$cached_values$yTs
				y_c = private$cached_values$yCs
				n_t = length(y_t)
				n_c = length(y_c)
				if (n_t == 0L || n_c == 0L) {
					private$cached_values$incidence_wald_se = NA_real_
					return(invisible(NULL))
				}
				p_t = mean(y_t)
				p_c = mean(y_c)
				var_hat = p_t * (1 - p_t) / n_t + p_c * (1 - p_c) / n_c
				private$cached_values$incidence_wald_se =
					if (is.finite(var_hat) && var_hat >= 0) sqrt(var_hat) else NA_real_
				invisible(NULL)
			}
		)
	)
}

test_that("InferenceIncidWald migration produces identical outputs to the pre-migration class", {
	InferenceIncidWaldLegacy = make_incid_wald_legacy_generator()
	des = inference_migration_complete_design("incidence", n = 20L, seed = 20260817L)
	# Excludes the two RNG-order-sensitive stochastic methods
	# (bootstrap_distr/randomization_bootstrap_distr): expect_inference_migration_
	# outputs_equal() calls legacy then migrated back-to-back off the shared
	# global RNG stream with no reset in between, so a class using B>0 random
	# draws will legitimately produce different (not wrong) numbers purely from
	# call order -- covered separately below via explicit set_seed() resets.
	deterministic_method_calls = inference_migration_method_calls[setdiff(
		names(inference_migration_method_calls),
		c("bootstrap_distr", "bootstrap_ci", "bootstrap_pval",
			"randomization_distr", "randomization_ci", "randomization_pval",
			"randomization_bootstrap_distr", "randomization_bootstrap_pval",
			"jackknife_estimate", "jackknife_se", "jackknife_ci", "jackknife_pval")
	)]
	expect_silent(expect_inference_migration_outputs_equal(
		legacy_class = InferenceIncidWaldLegacy,
		migrated_class = InferenceIncidWald,
		design = des,
		method_calls = deterministic_method_calls
	))
})

test_that("InferenceIncidWald migration produces identical stochastic (bootstrap/randomization/jackknife) outputs under a shared explicit seed", {
	InferenceIncidWaldLegacy = make_incid_wald_legacy_generator()
	des = inference_migration_complete_design("incidence", n = 20L, seed = 20260817L)
	legacy = InferenceIncidWaldLegacy$new(des)
	migrated = InferenceIncidWald$new(des)

	stochastic_labels = c(
		"bootstrap_distr", "bootstrap_ci", "bootstrap_pval",
		"randomization_distr", "randomization_ci", "randomization_pval",
		"randomization_bootstrap_distr", "randomization_bootstrap_pval",
		"jackknife_estimate", "jackknife_se", "jackknife_ci", "jackknife_pval"
	)
	for (label in stochastic_labels) {
		spec = inference_migration_method_calls[[label]]
		legacy$set_seed(20260817L)
		legacy_result = inference_migration_call_optional_method(legacy, spec$method, spec$args)
		migrated$set_seed(20260817L)
		migrated_result = inference_migration_call_optional_method(migrated, spec$method, spec$args)
		if (legacy_result$status %in% c("absent", "unsupported") &&
				migrated_result$status %in% c("absent", "unsupported")) {
			next
		}
		expect_identical(legacy_result$status, migrated_result$status, info = label)
		if (identical(legacy_result$status, "ok")) {
			expect_equal(migrated_result$value, legacy_result$value, tolerance = 1e-7, info = label)
		}
	}
})

test_that("InferenceIncidWald retains the same public method surface and no new private-owner duplicates", {
	InferenceIncidWaldLegacy = make_incid_wald_legacy_generator()
	before = list(
		public_methods = inference_migration_public_methods(InferenceIncidWaldLegacy),
		dupes = inference_migration_duplicate_private_owners(InferenceIncidWaldLegacy)
	)
	after = list(
		public_methods = inference_migration_public_methods(InferenceIncidWald),
		dupes = inference_migration_duplicate_private_owners(InferenceIncidWald)
	)
	expect_true(all(before$public_methods %in% after$public_methods))
	expect_no_new_inference_migration_private_owner_duplicates(before$dupes, after$dupes)
})

test_that("InferenceIncidWald is marked migrated in the class registry", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceIncidWald")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceIncidWald"]]$migration_status, "migrated")
})
