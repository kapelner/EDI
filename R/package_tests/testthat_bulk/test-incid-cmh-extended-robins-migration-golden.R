library(testthat)
library(EDI)

# InferenceIncidCMH / InferenceIncidExtendedRobins migration
# (fix_inference_hierarchy.md, "Asymptotic (Wald) No-Likelihood Migration"):
# from `R6::R6Class(inherit = InferenceAllSimpleAverageDiff, ...)` to
# `define_inference_class()` composing
# `BayesianBootstrap`/`Wald`/`SimpleMeanDifference` directly, with all prior
# overrides preserved verbatim. These legacy generators are byte-for-byte
# copies of the pre-migration class bodies, used only to prove the migrated
# classes produce identical outputs.

make_cmh_legacy_generator = function() {
	R6::R6Class(
		"InferenceIncidCMHLegacy",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceAllSimpleAverageDiff,
		public = list(
			compute_asymp_confidence_interval = function(alpha = 0.05){
				self$compute_estimate()
				private$get_standard_error()
				super$compute_asymp_confidence_interval(alpha)
			},
			compute_asymp_two_sided_pval = function(delta = 0){
				self$compute_estimate()
				private$get_standard_error()
				super$compute_asymp_two_sided_pval(delta)
			},
			initialize = function(des_obj, model_formula = NULL, se_est_num_vectors = 5000L, verbose = FALSE){
				if (des_obj$is_blocking_design()) {
					if (des_obj$get_prob_T() != 0.5) {
						stop("InferenceIncidCMH requires even treatment allocation for blocking designs.")
					}
					block_ids = des_obj$get_block_ids()
					block_sizes = as.integer(table(block_ids))
					if (length(block_sizes) > 1L && any(block_sizes != block_sizes[1L])) {
						stop("InferenceIncidCMH requires equal block sizes for blocking designs.")
					}
				} else if (des_obj$get_prob_T() != 0.5) {
					stop("InferenceIncidCMH requires even treatment allocation (prob_T = 0.5) for non-blocking designs.")
				}
				if (EDI:::should_run_asserts()) {
					checkmate::assertChoice(des_obj$get_response_type(), "incidence")
					checkmate::assertCount(se_est_num_vectors, positive = TRUE)
				}
				super$initialize(des_obj, verbose = verbose, model_formula = model_formula)
				if (EDI:::should_run_asserts()) {
					EDI:::assertNoCensoring(private$any_censoring)
				}
				if (!des_obj$is_blocking_design()) {
					n_T = sum(private$w)
					n_C = private$n - n_T
					if (n_T != n_C) {
						warning(
							"InferenceIncidCMH: this non-blocking design's realized treatment allocation ",
							"is not exactly balanced (n_T = ", n_T, ", n_C = ", n_C, "); the standard error ",
							"formula assumes exact balance and may be miscalibrated."
						)
					}
				}
				private$se_est_num_vectors = as.integer(se_est_num_vectors)
			}
		),
		private = list(
			se_est_num_vectors = NULL,
			supports_lik_ratio_param_bootstrap = function() FALSE,
			supports_likelihood_tests = function() FALSE,
			get_supported_testing_types_impl = function(){
				"wald"
			},
			get_standard_error = function(){
				if (!is.null(private$cached_values$cmh_s_beta_hat_T)) {
					se = private$cached_values$cmh_s_beta_hat_T
					if (is.finite(se) && se > 0) return(se)
					private$cache_nonestimable_se("cmh_standard_error_unavailable")
					return(NA_real_)
				}
				if (private$des_obj$is_blocking_design()) {
					private$cached_values$cmh_s_beta_hat_T = EDI:::compute_cmh_block_se_cpp(
						private$des_obj_priv_int$y,
						private$des_obj$get_block_ids(),
						private$des_obj_priv_int$n
					)
				} else {
					# Mirrors the guard added to the real class (2026-08-17): after the
					# design-hierarchy rework, non-blocking designs no longer carry
					# get_cmh_se_w_mat() at all, so the byte-for-byte pre-migration body
					# would error here on the new designs for reasons unrelated to the
					# migration under test.
					precomp = if (is.function(private$des_obj$get_cmh_se_w_mat)) private$des_obj$get_cmh_se_w_mat() else NULL
					w_mat = if (!is.null(precomp)) precomp else private$des_obj$draw_ws_according_to_design(private$se_est_num_vectors)
					w_mat = private$get_w_signed(w_mat)
					ytw      = drop(private$y %*% w_mat)
					K        = length(ytw)
					private$cached_values$cmh_s_beta_hat_T = 2 / private$n * sqrt(max(0, sum(ytw^2) / K))
				}
				if (!is.finite(private$cached_values$cmh_s_beta_hat_T) || private$cached_values$cmh_s_beta_hat_T <= 0) {
					private$cached_values$cmh_s_beta_hat_T = NA_real_
					private$cache_nonestimable_se("cmh_standard_error_unavailable")
					return(NA_real_)
				}
				private$cached_values$s_beta_hat_T = private$cached_values$cmh_s_beta_hat_T
				private$cached_values$df = NA_real_
				private$cached_values$cmh_s_beta_hat_T
			},
			get_degrees_of_freedom = function(){
				NA_real_
			}
		)
	)
}

make_extended_robins_legacy_generator = function() {
	R6::R6Class(
		"InferenceIncidExtendedRobinsLegacy",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceAllSimpleAverageDiff,
		public = list(
			compute_asymp_confidence_interval = function(alpha = 0.05){
				private$get_standard_error()
				super$compute_asymp_confidence_interval(alpha)
			},
			compute_asymp_two_sided_pval = function(delta = 0){
				private$get_standard_error()
				super$compute_asymp_two_sided_pval(delta)
			},
			initialize = function(des_obj, model_formula = NULL, verbose = FALSE){
				if (!des_obj$is_blocking_design()) {
					stop("InferenceIncidExtendedRobins requires a blocking design with equal block sizes and even allocation.")
				}
				if (des_obj$get_prob_T() != 0.5) {
					stop("InferenceIncidExtendedRobins requires a blocking design with even allocation.")
				}
				block_ids = des_obj$get_block_ids()
				block_sizes = as.integer(table(block_ids))
				if (length(block_sizes) > 1L && any(block_sizes != block_sizes[1L])) {
					stop("InferenceIncidExtendedRobins requires a blocking design with equal block sizes.")
				}
				if (EDI:::should_run_asserts()) {
					checkmate::assertChoice(des_obj$get_response_type(), "incidence")
				}
				super$initialize(des_obj, verbose = verbose, model_formula = model_formula)
				if (EDI:::should_run_asserts()) {
					EDI:::assertNoCensoring(private$any_censoring)
				}
			}
		),
		private = list(
			supports_lik_ratio_param_bootstrap = function() FALSE,
			supports_likelihood_tests = function() FALSE,
			get_supported_testing_types_impl = function(){
				"wald"
			},
			get_standard_error = function(){
				if (!is.null(private$cached_values$robins_s_beta_hat_T)) {
					se = private$cached_values$robins_s_beta_hat_T
					if (is.finite(se) && se > 0) return(se)
					private$cache_nonestimable_se("extended_robins_standard_error_unavailable")
					return(NA_real_)
				}
				private$cached_values$robins_s_beta_hat_T = EDI:::compute_extended_robins_block_se_cpp(
					private$des_obj_priv_int$y,
					private$get_w_signed(private$w),
					private$des_obj$get_block_ids(),
					private$des_obj_priv_int$n
				)
				if (!is.finite(private$cached_values$robins_s_beta_hat_T) || private$cached_values$robins_s_beta_hat_T <= 0) {
					private$cached_values$robins_s_beta_hat_T = NA_real_
					private$cache_nonestimable_se("extended_robins_standard_error_unavailable")
					return(NA_real_)
				}
				private$cached_values$s_beta_hat_T = private$cached_values$robins_s_beta_hat_T
				private$cached_values$df = NA_real_
				private$cached_values$robins_s_beta_hat_T
			},
			get_degrees_of_freedom = function(){
				NA_real_
			}
		)
	)
}

# Every method call is seeded fresh on both sides before being invoked --
# not just the obviously-stochastic ones (approximate_*_distribution_*,
# jackknife). InferenceIncidCMH's own get_standard_error() draws random
# reference vectors via draw_ws_according_to_design() on the non-blocking
# path (when no design-level cmh_se_w_mat precompute is available), so even
# "asymp_ci"/"wald_ci" are effectively stochastic for this class -- seeding
# unconditionally before every call is the only safe, general approach and
# costs nothing for genuinely deterministic methods.
expect_migration_outputs_equal_deterministic_and_seeded_stochastic = function(legacy_class, migrated_class, design) {
	legacy = legacy_class$new(design)
	migrated = migrated_class$new(design)
	for (label in names(inference_migration_method_calls)) {
		spec = inference_migration_method_calls[[label]]
		legacy$set_seed(20260817L)
		legacy_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(legacy, spec$method, spec$args))
		migrated$set_seed(20260817L)
		migrated_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(migrated, spec$method, spec$args))
		if (legacy_result$status %in% c("absent", "unsupported") &&
				migrated_result$status %in% c("absent", "unsupported")) {
			next
		}
		expect_identical(legacy_result$status, migrated_result$status, info = label)
		if (identical(legacy_result$status, "ok")) {
			expect_equal(migrated_result$value, legacy_result$value, tolerance = 1e-7, info = label)
		}
	}
}

test_that("InferenceIncidCMH migration produces identical outputs (blocking design)", {
	InferenceIncidCMHLegacy = make_cmh_legacy_generator()
	set.seed(20260817L)
	n = 20L
	des = DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "x2", equal_block_sizes = TRUE)
	X = data.frame(x1 = rnorm(n), x2 = rep(c("a", "b"), n / 2L))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	expect_migration_outputs_equal_deterministic_and_seeded_stochastic(InferenceIncidCMHLegacy, InferenceIncidCMH, des)
})

test_that("InferenceIncidCMH migration produces identical outputs (non-blocking, balanced design)", {
	skip_on_cran()
	InferenceIncidCMHLegacy = make_cmh_legacy_generator()
	set.seed(20260817L)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", prob_T = 0.5)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	w = rep(c(0L, 1L), n / 2L)
	des$assign_w_to_all_subjects(w_precomputed = w)
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	expect_migration_outputs_equal_deterministic_and_seeded_stochastic(InferenceIncidCMHLegacy, InferenceIncidCMH, des)
})

test_that("InferenceIncidExtendedRobins migration produces identical outputs", {
	InferenceIncidExtendedRobinsLegacy = make_extended_robins_legacy_generator()
	set.seed(20260817L)
	n = 20L
	des = DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "x2", equal_block_sizes = TRUE)
	X = data.frame(x1 = rnorm(n), x2 = rep(c("a", "b"), n / 2L))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	expect_migration_outputs_equal_deterministic_and_seeded_stochastic(
		InferenceIncidExtendedRobinsLegacy, InferenceIncidExtendedRobins, des
	)
})

test_that("InferenceIncidCMH / InferenceIncidExtendedRobins are marked migrated in the class registry", {
	EDI:::populate_inference_class_registry()
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceIncidCMH"]]$migration_status, "migrated")
	expect_identical(manifest[["InferenceIncidExtendedRobins"]]$migration_status, "migrated")
})
