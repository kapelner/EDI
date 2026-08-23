# Until 2026-08-23 this file hoisted `inference_count_likelihood_public/
# _private` list objects that were spliced both into this Source (with 12
# composition-safe public overrides layered on via `utils::modifyList()`) and
# into the classic `InferenceCountLikelihood` R6 ladder generator, which had
# zero remaining inheritors (every count class composes CountLikelihoodPlumbing
# through define_inference_class()). fix_inference_hierarchy.md "Static
# Cleanup" / "Ban raw component splicing" (2026-08-23): the ladder generator
# is deleted, the 12 superseded base bodies (whose `super$compute_X(...)`
# fallbacks only resolved through the deleted ladder) are dropped, and the
# Source is now one plain literal: `compute_estimate` plus the 12
# composition-safe methods (private$..._impl direct calls, with the two
# compute_lik_ratio_bootstrap_* methods and the two asymp dispatchers pinned
# from their real source generators under `cl_plumbing_*` names), plus the
# count-specific private helpers. The `@name InferenceCountLikelihood` roxygen
# topic is kept so existing `\link[EDI:InferenceCountLikelihood]` cross-
# references stay valid.
#' Count-Specific Likelihood Inference
#'
#' @name InferenceCountLikelihood
#' @description Component source (\code{CountLikelihoodPlumbingSource}) for the
#' count-based likelihood families (Poisson, Negative Binomial, Zero-Inflated,
#' Hurdle): centralizes count-specific parameter packing, warm starts, and
#' likelihood dispatch. Composed by every count class through the registered
#' \code{CountLikelihoodPlumbing} component.
#'
#' @keywords internal
CountLikelihoodPlumbingSource = list(
	public = list(
		#' @description Computes the treatment-effect estimate using the underlying
		#'   count likelihood model. Concrete subclasses fit a Poisson, negative
		#'   binomial, zero-inflated, hurdle, or combined likelihood model and cache
		#'   the treatment coefficient for related
		#'   \code{\link[EDI:InferenceCountLikelihood]{InferenceCountLikelihood}}
		#'   p-value and confidence-interval methods.
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(private$count_likelihood_missing_ci(alpha))
			if (private$testing_type == "wald") {
				private$shared(estimate_only = FALSE)
				if (is.finite(private$cached_values$s_beta_hat_T %||% NA_real_)) {
					return(private$compute_z_or_t_ci_from_s_and_df(alpha))
				}
			}
			private$cl_plumbing_asymp_lik_compute_asymp_confidence_interval(alpha)
		},
		compute_asymp_two_sided_pval = function(delta = 0){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(NA_real_)
			if (private$testing_type == "wald") {
				private$shared(estimate_only = FALSE)
				if (is.finite(private$cached_values$s_beta_hat_T %||% NA_real_)) {
					return(private$compute_z_or_t_two_sided_pval_from_s_and_df(delta))
				}
			}
			private$cl_plumbing_asymp_lik_compute_asymp_two_sided_pval(delta)
		},
		compute_wald_two_sided_pval = function(delta = 0){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(NA_real_)
			private$compute_wald_two_sided_pval_impl(delta)
		},
		compute_wald_confidence_interval = function(alpha = 0.05){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(private$count_likelihood_missing_ci(alpha))
			private$compute_wald_confidence_interval_impl(alpha)
		},
		compute_score_two_sided_pval = function(delta = 0){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(NA_real_)
			private$compute_score_two_sided_pval_impl(delta)
		},
		compute_score_confidence_interval = function(alpha = 0.05){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(private$count_likelihood_missing_ci(alpha))
			private$compute_score_confidence_interval_impl(alpha)
		},
		compute_lik_ratio_two_sided_pval = function(delta = 0){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(NA_real_)
			private$compute_lik_ratio_two_sided_pval_impl(delta)
		},
		compute_lik_ratio_confidence_interval = function(alpha = 0.05){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(private$count_likelihood_missing_ci(alpha))
			private$compute_lik_ratio_confidence_interval_impl(alpha)
		},
		compute_gradient_two_sided_pval = function(delta = 0){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(NA_real_)
			private$compute_gradient_two_sided_pval_impl(delta)
		},
		compute_gradient_confidence_interval = function(alpha = 0.05){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(private$count_likelihood_missing_ci(alpha))
			private$compute_gradient_confidence_interval_impl(alpha)
		},
		compute_lik_ratio_bootstrap_two_sided_pval = function(delta = 0, B = 199, show_progress = FALSE, min_number_usable_samples = 5L, max_attempts_per_replicate = 2L){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(NA_real_)
			private$cl_plumbing_param_boot_compute_lik_ratio_bootstrap_two_sided_pval(
				delta = delta,
				B = B,
				show_progress = show_progress,
				min_number_usable_samples = min_number_usable_samples,
				max_attempts_per_replicate = max_attempts_per_replicate
			)
		},
		compute_lik_ratio_bootstrap_confidence_interval = function(alpha = 0.05, B = 199, show_progress = FALSE, min_number_usable_samples = 5L, max_attempts_per_replicate = 2L, root_tolerance = NULL, max_root_iterations = 8L){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(private$count_likelihood_missing_ci(alpha))
			private$cl_plumbing_param_boot_compute_lik_ratio_bootstrap_confidence_interval(
				alpha = alpha,
				B = B,
				show_progress = show_progress,
				min_number_usable_samples = min_number_usable_samples,
				max_attempts_per_replicate = max_attempts_per_replicate,
				root_tolerance = root_tolerance,
				max_root_iterations = max_root_iterations
			)
		}
	),
	private = list(

		shared = function(estimate_only = FALSE){
			if (estimate_only &&
					!is.null(private$cached_values$beta_hat_T) &&
					is.finite(as.numeric(private$cached_values$beta_hat_T)[1L])) {
				return(invisible(NULL))
			}
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T) && is.finite(private$cached_values$s_beta_hat_T)) return(invisible(NULL))

			model_output = private$generate_mod(estimate_only = estimate_only)
			private$cached_mod = model_output

			if (is.null(model_output)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(invisible(NULL))
			}

			# Count models usually return treatment effect at index 2 of the cond component
			# or in a specific field. We allow models to set beta_hat_T directly in output.
			private$cached_values$beta_hat_T = model_output$beta_hat_T %||% model_output$b[2]

			if (!is.null(model_output$params) || !is.null(model_output$b)) {
				private$set_fit_warm_start(
					as.numeric(model_output$params %||% model_output$b),
					type = if (!is.null(model_output$params)) "params" else "beta",
					fisher = model_output$fisher_information %||% model_output$XtWX,
					weights = model_output$w %||% model_output$mu,
					force_pd = TRUE
				)
			}

			if (estimate_only) return(invisible(NULL))

			ssq = model_output$ssq_b_j %||% model_output$ssq_b_2
			if (!is.null(ssq) && is.finite(ssq) && ssq > 0) {
				private$cached_values$s_beta_hat_T = sqrt(ssq)
			} else {
				private$cached_values$s_beta_hat_T = NA_real_
			}
			private$cached_values$df = model_output$df %||% Inf
		},

		get_standard_error = function(){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(NA_real_)
			private$shared(estimate_only = FALSE)
			# Try information-based SE first if supported
			if (isTRUE(private$supports_information_preference())) {
				se = tryCatch(private$compute_standard_error_from_information_matrix(), error = function(e) NA_real_)
				if (is.finite(se)) return(se)
			}
			private$cached_values$s_beta_hat_T
		},

		get_degrees_of_freedom = function(){
			private$shared(estimate_only = FALSE)
			private$cached_values$df %||% Inf
		},
		get_backend_warm_start_args = function(expected_length, expected_fisher_dim = expected_length) {
			private$get_optimal_warm_start_config(expected_length, expected_fisher_dim)
		},

		# --- Likelihood test support ---

		supports_lik_ratio_param_bootstrap = function() TRUE,
		supports_likelihood_tests = function(){
			TRUE
		},

		get_likelihood_test_spec = function(){
			# This is still abstract, but we provide the structure
			NULL
		},

		compute_score_two_sided_pval_impl = function(delta){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(NA_real_)
			private$compute_likelihood_test_two_sided_pval(delta = delta, testing_type = "score")
		},
		compute_gradient_two_sided_pval_impl = function(delta){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(NA_real_)
			private$compute_likelihood_test_two_sided_pval(delta = delta, testing_type = "gradient")
		},
		compute_lik_ratio_two_sided_pval_impl = function(delta){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(NA_real_)
			private$compute_likelihood_test_two_sided_pval(delta = delta, testing_type = "lik_ratio")
		},
		compute_score_confidence_interval_impl = function(alpha){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(private$count_likelihood_missing_ci(alpha))
			private$invert_test_pval_confidence_interval(alpha)
		},
		compute_gradient_confidence_interval_impl = function(alpha){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(private$count_likelihood_missing_ci(alpha))
			private$invert_test_pval_confidence_interval(alpha)
		},
		compute_lik_ratio_confidence_interval_impl = function(alpha){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(private$count_likelihood_missing_ci(alpha))
			private$invert_test_pval_confidence_interval(alpha)
		},
		count_likelihood_block_asymp_unsupported = function(){
			private$jackknife_block_size_gt_one_unsupported(unit = "auto")
		},
		mark_count_likelihood_block_asymp_nonestimable = function(){
			if (!private$count_likelihood_block_asymp_unsupported()) return(FALSE)
			if (is.null(private$cached_values$beta_hat_T)) {
				try(private$shared(estimate_only = TRUE), silent = TRUE)
			}
			private$cache_nonestimable_se("count_likelihood_asymp_block_size_gt_one_not_supported")
			TRUE
		},
			count_likelihood_missing_ci = function(alpha = 0.05){
				ci = c(NA_real_, NA_real_)
				names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
				ci
			},
		is_a_count_likelihood = function() TRUE,
		cl_plumbing_asymp_lik_compute_asymp_confidence_interval = InferenceAsympLik$public_methods$compute_asymp_confidence_interval,
		cl_plumbing_asymp_lik_compute_asymp_two_sided_pval = InferenceAsympLik$public_methods$compute_asymp_two_sided_pval,
		cl_plumbing_param_boot_compute_lik_ratio_bootstrap_two_sided_pval = InferenceParamBootstrap$public_methods$compute_lik_ratio_bootstrap_two_sided_pval,
		cl_plumbing_param_boot_compute_lik_ratio_bootstrap_confidence_interval = InferenceParamBootstrap$public_methods$compute_lik_ratio_bootstrap_confidence_interval
	)
)

# The InferenceCountLikelihoodNoParamBootstrap R6 generator that used to be
# assembled here (inherit = InferenceAsympLik, same public/private lists as
# CountLikelihoodPlumbingSource above plus an is_a_ marker) was deleted
# 2026-08-17 (fix_inference_hierarchy.md, "Base Deletion"): it had zero
# remaining inheritors anywhere in the package -- every count class either
# still descends through InferenceCountLikelihood (the with-param-bootstrap
# base, which stays until those classes migrate) or has already migrated to
# define_inference_class() composing the CountLikelihoodPlumbing/
# CountCompositeLikelihood components, which read the Source lists directly.
