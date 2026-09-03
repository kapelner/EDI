#' Cauchit Regression Inference for Ordinal Responses
#'
#' Cauchit-link cumulative-odds ordinal regression: \eqn{P(Y \le k \mid w, x) =
#' F_{\mathrm{Cauchy}}(\alpha_k - \beta_T w - \beta_X^\top x)}, where
#' \eqn{F_{\mathrm{Cauchy}}} is the standard Cauchy CDF, \eqn{\alpha_k} are
#' category-specific cutpoints, and \eqn{\beta_T} is the treatment log-odds
#' coefficient on the cauchit scale (proportional-odds-style shift common to all
#' categories). Fit by maximum likelihood. The heavy-tailed Cauchy link is
#' markedly less sensitive to outlying/extreme response categories than the
#' logit or probit link, at the cost of a less familiar effect-size
#' interpretation. \code{likelihood_tier = "full"}: exposes likelihood-ratio,
#' score, gradient, and parametric-likelihood-bootstrap inference in addition to
#' the Wald/asymptotic and Bayesian-bootstrap paths.
#'
#' @references Agresti, A. (2010). \emph{Analysis of Ordinal Categorical Data}
#'   (2nd ed.). Wiley. Ch. 3-4 (cumulative link models).
#' @seealso \url{https://en.wikipedia.org/wiki/Ordinal_regression},
#'   \url{https://www.statsmodels.org/stable/discretemod.html} for an analogous
#'   Python cumulative-link API.
#'
#' @export
InferenceOrdinalCauchitRegr = R6::R6Class("InferenceOrdinalCauchitRegr",
	lock_objects = FALSE,
	inherit = InferenceAsympLikStdModCache,
	public = list(
		#' @description Initialize a cauchit ordinal inference object.
		#' @param des_obj A completed \code{Design} object with an ordinal response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values by default.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "ordinal")
				assertFormula(model_formula, null.ok = TRUE)
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Refits the cauchit cumulative-link model under subject/block
		#'   resampling weights via \code{weighted_ordinal_bootstrap_surrogate_fit()}
		#'   (a weighted-likelihood surrogate fit, not full IRLS re-optimization from
		#'   cold start) and returns the re-estimated treatment coefficient
		#'   \eqn{\hat\beta_T} on the cauchit-link scale. Used to build the
		#'   nonparametric- and Bayesian-bootstrap distributions of \eqn{\hat\beta_T}.
		#'   If the surrogate fit fails or yields a non-finite estimate, the
		#'   replicate's estimate, standard error, and degrees of freedom are all set
		#'   to \code{NA}.
		#' @param subject_or_block_weights Numeric vector of resampling weights, one
		#'   per subject or resampling block.
		#' @param estimate_only Accepted for interface compatibility; standard errors
		#'   are never computed for a single bootstrap replicate regardless of this flag.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			X_fit = private$build_design_matrix()
			if (!is.null(private$best_X_colnames)) {
				keep = c("treatment", intersect(private$best_X_colnames, colnames(X_fit)))
				X_fit = X_fit[, keep, drop = FALSE]
			}
			fit = weighted_ordinal_bootstrap_surrogate_fit(X_fit, private$y, row_weights, method = "cauchit")
			if (is.null(fit) || !is.finite(fit$beta_hat)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			private$cached_values$beta_hat_T = as.numeric(fit$beta_hat)
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = NA_real_
			private$cached_values$full_coefficients = fit$coefficients
			private$cached_values$summary_table = NULL
			private$cached_values$beta_hat_T
		}
	),
	private = list(
		best_X_colnames = NULL,
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			if (is.null(private$best_X_colnames)){
				private$shared(estimate_only = TRUE)
			}
			if (is.null(private$best_X_colnames)){
				return(self$compute_estimate(estimate_only = estimate_only))
			}
			X_cols = private$best_X_colnames
			X_data = private$get_X()
			if (length(X_cols) == 0L){
				X = matrix(private$w, ncol = 1L)
				colnames(X) = "treatment"
			} else {
				X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
				X = cbind(treatment = private$w, X_cov)
			}
			n_params = ncol(X) + length(sort(unique(private$y))) - 1L
			ws_fisher = private$get_fit_warm_start_fisher(n_params)
			res = fast_ordinal_cauchit_regression_cpp(
				X = X, y = as.numeric(private$y),
				warm_start_params = private$get_fit_warm_start_for_length("params", n_params),
				warm_start_fisher_info = ws_fisher,
				smart_cold_start = private$smart_cold_start_default,
				estimate_only = TRUE
			)
			# treatment is X's first column (cbind(treatment = ..., X_cov)
			# above); res$b[1] is the treatment slope, matching generate_mod()'s
			# own extraction. res$b[length(res$b)] (the last covariate's slope
			# whenever design_formula includes covariates) fed the
			# randomization test a covariate's coefficient instead of
			# treatment's.
			if (is.null(res) || length(res$b) < 1L || !is.finite(res$b[1])){
				return(NA_real_)
			}
			private$set_fit_warm_start(res$params, "params", fisher = ws_fisher)
			as.numeric(res$b[1])
		},
		supports_reusable_bootstrap_worker = function(){
			TRUE
		},
		supports_lik_ratio_param_bootstrap = function(){
			TRUE
		},
		supports_likelihood_tests = function(){
			TRUE
		},
		supports_fisher_information = function(){
			TRUE
		},
		simulate_under_lik_null = function(spec, delta, null_fit){
			params_null = as.numeric(null_fit$params)
			y_sim       = private$simulate_param_boot_ordinal_y(spec$X, params_null, spec$y, stats::pcauchy)
			if (is.null(y_sim)) return(NULL)
			X_fit    = spec$X
			j        = spec$j
			full_res = tryCatch(
				fast_ordinal_cauchit_regression_cpp(
					X_fit, y_sim,
					smart_cold_start = private$smart_cold_start_default
				),
				error = function(e) NULL
			)
			if (is.null(full_res) || length(full_res$params) == 0L) return(NULL)
			full_fit_boot = list(params = as.numeric(full_res$params), neg_loglik = as.numeric(full_res$neg_loglik))
			if (!is.finite(full_fit_boot$neg_loglik)) return(NULL)
			list(
				worker_data = list(y = y_sim),
				full_fit = full_fit_boot,
				fit_null = function(d, start = NULL){
					res = tryCatch(
						fast_ordinal_cauchit_regression_cpp(
							X_fit, y_sim,
							warm_start_params = start %||% full_fit_boot$params,
							fixed_idx = j, fixed_values = d,
							smart_cold_start = TRUE
						),
						error = function(e) NULL
					)
					if (is.null(res) || length(res) == 0L) return(NULL)
					list(params = as.numeric(res$params), neg_loglik = as.numeric(res$neg_loglik))
				},
				neg_loglik = function(fit) as.numeric(fit$neg_loglik)
			)
		},
		get_likelihood_test_spec = function(){
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx)) return(NULL)
			X_fit = ctx$X
			y = as.numeric(private$y)
			j_treat = as.integer(ctx$j_treat)
			full_fit = list(params = ctx$full_params, neg_loglik = ctx$full_neg_loglik)
			list(
				X = X_fit, y = y, j = j_treat,
				full_fit = full_fit,
				fit_null = function(delta, start = NULL){
					res = tryCatch(
						fast_ordinal_cauchit_regression_cpp(
							X_fit, y,
							fixed_idx = j_treat, fixed_values = delta,
							warm_start_params = start %||% private$get_fit_warm_start_for_length("params", length(ctx$full_params)),
							warm_start_fisher_info = private$get_fit_warm_start_fisher(length(ctx$full_params)),
							smart_cold_start = private$smart_cold_start_default
						),
						error = function(e) NULL
					)
					if (is.null(res) || length(res) == 0) return(NULL)
					list(params = as.numeric(res$params), neg_loglik = as.numeric(res$neg_loglik), fisher_information = res$fisher_information)
				},
				extract_start = function(fit){
					as.numeric(fit$params)
				},
				score = function(fit){
					get_ordinal_cauchit_regression_score_cpp(X_fit, y, as.numeric(fit$params))
				},
				observed_information = function(fit){
					-get_ordinal_cauchit_regression_hessian_cpp(X_fit, y, as.numeric(fit$params))
				},
				fisher_information = function(fit){
					fit$fisher_information %||% -get_ordinal_cauchit_regression_hessian_cpp(X_fit, y, as.numeric(fit$params))
				},
				information = function(fit){
					fit$information %||% fit$fisher_information %||% -get_ordinal_cauchit_regression_hessian_cpp(X_fit, y, as.numeric(fit$params))
				},
				neg_loglik = function(fit){ as.numeric(fit$neg_loglik) }
			)
		},
		generate_mod = function(estimate_only = FALSE){
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 1L,
				fit_fun = function(X_fit){
					n_params = ncol(X_fit) + length(sort(unique(private$y))) - 1L
					warm_start_params = private$get_fit_warm_start_for_length("params", n_params)
					warm_fisher = private$get_fit_warm_start_fisher(n_params)
					if (estimate_only) {
						res = fast_ordinal_cauchit_regression_cpp(
							X_fit, private$y,
							warm_start_params = warm_start_params,
							warm_start_fisher_info = warm_fisher,
							smart_cold_start = private$smart_cold_start_default,
							estimate_only = TRUE
						)
						if (is.null(res) || length(res) == 0) return(NULL)
						list(b = res$b, ssq_b_j = NA_real_, params = res$params, fisher_information = warm_fisher)
					} else {
						res = fast_ordinal_cauchit_regression_with_var_cpp(
							X_fit, private$y,
							warm_start_params = warm_start_params,
							warm_start_fisher_info = warm_fisher,
							smart_cold_start = private$smart_cold_start_default
						)
						if (is.null(res) || length(res$b) == 0 || is.na(res$b[1])) return(NULL)
						list(b = res$b, ssq_b_j = res$ssq_b_j, params = res$params, neg_loglik = res$neg_loglik, fisher_information = res$fisher_information)
					}
				},
				fit_ok = function(mod, X_fit, keep){
					# treatment is b[1] (X's first column); see the comment on
					# compute_treatment_estimate_during_randomization_inference()
					# above -- this used to gate on b[length(mod$b)], the last
					# covariate's coefficient, not treatment's.
					if (is.null(mod) || length(mod$b) < 1L || !is.finite(mod$b[1])) return(FALSE)
					if (estimate_only) return(TRUE)
					ssq = mod$ssq_b_j
					!is.null(ssq) && is.finite(ssq) && ssq > 0
				}
			)
			if (!is.null(attempt$fit)){
				private$set_fit_warm_start(attempt$fit$params, "params", fisher = attempt$fit$fisher_information)
				private$best_X_colnames = setdiff(colnames(attempt$X), "treatment")
				if (!estimate_only) {
					n_alpha = length(attempt$fit$params) - ncol(attempt$X)
					private$cached_values$likelihood_test_context = list(
						X = attempt$X,
						j_treat = as.integer(n_alpha + 1L),
						full_params = attempt$fit$params,
						full_neg_loglik = attempt$fit$neg_loglik
					)
				}
				list(b = c(0, attempt$fit$b[1]), ssq_b_2 = attempt$fit$ssq_b_j)
			} else {
				private$cached_values$likelihood_test_context = NULL
				NULL
			}
		},
		build_design_matrix = function(){
			X_cov = private$X
			if (is.null(X_cov) || ncol(X_cov) == 0) {
				X = matrix(private$w, ncol = 1L)
				colnames(X) = "treatment"
			} else {
				X = cbind(treatment = private$w, X_cov)
			}
			X
		}
	)
)

OrdinalCauchitLikelihoodSource = inference_component_source_parts(InferenceOrdinalCauchitRegr)

InferenceOrdinalCauchitRegr = define_inference_class(
	classname = "InferenceOrdinalCauchitRegr",
	inherit = Inference,
	components = c(
		"BayesianBootstrap",
		"ParametricLikelihoodBootstrap",
		"OrdinalCauchitLikelihood"
	),
	public = list(
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	),
	metadata = list(
		response_types = "ordinal",
		likelihood_tier = "full",
		capabilities = "likelihood_ratio"
	),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"get_supported_testing_types", "set_testing_type"
		),
		private = c(
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl",
			"supports_bartlett_likelihood_ratio_approx",
			"get_bartlett_factor_approx",
			"compute_treatment_estimate_during_randomization_inference",
			"get_standard_error",
			"get_degrees_of_freedom",
			"make_warm_fit_null_wrapper",
			"compute_likelihood_test_two_sided_pval",
			"compute_score_two_sided_pval_impl",
			"compute_gradient_two_sided_pval_impl",
			"compute_lik_ratio_two_sided_pval_impl",
			"get_likelihood_test_spec",
			"supports_likelihood_tests",
			"supports_fisher_information",
			"supports_lik_ratio_param_bootstrap",
			"simulate_under_lik_null",
			"generate_mod"
		)
	)
)
