#' Count Composite Likelihood Inference Base
#'
#' Shared branch for count models whose reported estimator is robust or
#' quasi-likelihood based.
#'
#' @keywords internal
CountCompositeLikelihoodSource = list(
	public = list(
		#' @description Computes the treatment estimate.
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		}
		# compute_estimate_with_bootstrap_weights() removed as dead code (2026-09-23): the only two
		# classes that compose CountCompositeLikelihood -- InferenceCountQuasiPoisson and
		# InferenceCountRobustPoisson -- both define their own compute_estimate_with_bootstrap_weights()
		# directly, which always shadows this one, so it was never actually invoked by any class.
	),
	private = list(
		is_a_count_composite_likelihood = function() TRUE,
		generate_mod = function(estimate_only = FALSE) stop(class(self)[1], " must implement generate_mod()"),

		shared = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			
			model_output = private$generate_mod(estimate_only = estimate_only)
			private$cached_mod = model_output$mod %||% model_output
			
			if (is.null(model_output)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(invisible(NULL))
			}
			
			private$cached_values$beta_hat_T = model_output$beta_hat_T %||% model_output$b[2]
			
			if (!is.null(model_output$b)) {
				private$set_fit_warm_start(
					as.numeric(model_output$b),
					type = "beta",
					fisher = model_output$XtWX %||% model_output$fisher_information
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
			private$shared(estimate_only = FALSE)
			private$cached_values$s_beta_hat_T
		},

		get_degrees_of_freedom = function(){
			private$shared(estimate_only = FALSE)
			private$cached_values$df %||% Inf
		},

		get_backend_warm_start_args = function(expected_length, expected_fisher_dim = expected_length) {
			private$get_optimal_warm_start_config(expected_length, expected_fisher_dim)
		},

		supports_likelihood_tests = function(){
			FALSE
		},

		supports_lik_ratio_param_bootstrap = function(){
			FALSE
		},

		get_supported_testing_types_impl = function(){
			"wald"
		},

		compute_score_two_sided_pval_impl = function(delta){
			stop(class(self)[1], " does not support score p-values.", call. = FALSE)
		},

		compute_score_confidence_interval_impl = function(alpha){
			stop(class(self)[1], " does not support score confidence intervals.", call. = FALSE)
		},

		compute_gradient_two_sided_pval_impl = function(delta){
			stop(class(self)[1], " does not support gradient p-values.", call. = FALSE)
		},

		compute_gradient_confidence_interval_impl = function(alpha){
			stop(class(self)[1], " does not support gradient confidence intervals.", call. = FALSE)
		},

		compute_lik_ratio_two_sided_pval_impl = function(delta){
			stop(class(self)[1], " does not support likelihood-ratio p-values.", call. = FALSE)
		},

		compute_lik_ratio_confidence_interval_impl = function(alpha){
			stop(class(self)[1], " does not support likelihood-ratio confidence intervals.", call. = FALSE)
		},

		simulate_under_lik_null = function(spec, delta, null_fit){
			b_null     = as.numeric(null_fit$b)
			mu         = pmax(exp(as.numeric(spec$X %*% b_null)), 0)
			y_sim      = as.numeric(rpois(length(mu), mu))
			X_fit      = spec$X
			j          = spec$j
			full_fit_b = tryCatch(
				fast_poisson_regression_cpp(
					X = X_fit, y = y_sim,
					smart_cold_start = private$smart_cold_start_default
				),
				error = function(e) NULL
			)
			if (is.null(full_fit_b) || length(full_fit_b$b) < j || !is.finite(full_fit_b$b[j])) return(NULL)
			list(
				worker_data = list(y = y_sim),
				full_fit = full_fit_b,
				fit_null = function(d, start = NULL){
					tryCatch(
						fast_poisson_regression_with_var_cpp(
							X = X_fit, y = y_sim, j = j,
							warm_start_beta = start %||% full_fit_b$b,
							fixed_idx = j, fixed_values = d,
							smart_cold_start = TRUE
						),
						error = function(e) NULL
					)
				},
				neg_loglik = function(fit){
					eta_f = as.numeric(X_fit %*% as.numeric(fit$b))
					-sum(y_sim * eta_f - exp(eta_f) - lgamma(y_sim + 1))
				}
			)
		},

		get_likelihood_test_spec = function(){
			NULL
		}
	)
)

# The InferenceCountCompositeLikelihood R6 generator that used to be assembled
# here from the same source lists was deleted 2026-08-17 (fix_inference_
# hierarchy.md, "Base Deletion"): its only concrete descendants
# (InferenceCountQuasiPoisson/InferenceCountRobustPoisson) migrated to
# define_inference_class() composing the CountCompositeLikelihood component,
# which reads CountCompositeLikelihoodSource above directly -- the generator
# had zero remaining inheritors and existed only as legacy ladder surface.
