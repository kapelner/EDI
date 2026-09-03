OrdinalOrderedProbitLikelihoodSource = list(
	public = list(
		#' @description Initialize inference for the ordered probit model; see
		#'   \code{\link[EDI:InferenceOrdinalOrderedProbitRegr]{InferenceOrdinalOrderedProbitRegr}}
		#'   for the model form. Does not fit the model; the fit is deferred to the
		#'   first call to \code{compute_estimate()} or a method that requires it.
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
		#' @description Recomputes the treatment estimate under subject/block-level
		#'   bootstrap weights (Bayesian-bootstrap or nonparametric-bootstrap draw
		#'   weights) via \code{weighted_ordinal_bootstrap_surrogate_fit()}, a fast
		#'   weighted ordinal-probit surrogate fit on the raw design matrix, as an
		#'   approximation to the weighted ordered-probit likelihood. No standard
		#'   error is computed (\code{s_beta_hat_T} is always \code{NA}); the
		#'   surrogate returns \code{NA} if the fit fails.
		#' @param subject_or_block_weights Subject-, block-, cluster-, or matched-set
		#'   bootstrap weights.
		#' @param estimate_only If \code{TRUE}, compute only the weighted point
		#'   estimate.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			X_fit = private$build_design_matrix()
			if (!is.null(private$best_X_colnames)) {
				keep = c("treatment", intersect(private$best_X_colnames, colnames(X_fit)))
				X_fit = X_fit[, keep, drop = FALSE]
			}
			fit = weighted_ordinal_bootstrap_surrogate_fit(X_fit, private$y, row_weights, method = "probit")
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
		get_complexity_tier = function() "heavy",
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
				X = as.matrix(private$w)
				colnames(X) = "treatment"
			} else {
				X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
				X = cbind(treatment = private$w, X_cov)
			}
			n_params = ncol(X) + length(sort(unique(private$y))) - 1L
			ws_args = private$get_backend_warm_start_args(n_params)
			ws_fisher = ws_args$warm_start_fisher_info
			res = fast_ordinal_probit_regression_cpp(
				X = X, y = as.numeric(private$y),
				warm_start_params = ws_args$start_params,
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
			private$set_fit_warm_start(as.numeric(res$params), "params", fisher = ws_fisher)
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
			y_sim       = private$simulate_param_boot_ordinal_y(spec$X, params_null, spec$y, stats::pnorm)
			if (is.null(y_sim)) return(NULL)
			X_fit    = spec$X
			j        = spec$j
			
			# Parametric bootstrap: use observed fit as anchor
			ws_args = private$get_backend_warm_start_args(length(params_null))
			full_res = tryCatch(
				fast_ordinal_probit_regression_cpp(
					X_fit, y_sim,
					warm_start_params = ws_args$start_params,
					warm_start_fisher_info = ws_args$warm_start_fisher_info,
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
					ws_args_null = private$get_backend_warm_start_args(length(params_null))
					res = tryCatch(
						fast_ordinal_probit_regression_cpp(
							X_fit, y_sim,
							warm_start_params = start %||% full_fit_boot$params,
							warm_start_fisher_info = ws_args_null$warm_start_fisher_info,
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
					ws_args = private$get_backend_warm_start_args(length(ctx$full_params))
					res = tryCatch(
						fast_ordinal_probit_regression_cpp(
							X_fit, y,
							fixed_idx = j_treat, fixed_values = delta,
							warm_start_params = start %||% ws_args$start_params,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
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
					get_ordinal_probit_regression_score_cpp(X_fit, y, as.numeric(fit$params))
				},
				observed_information = function(fit){
					-get_ordinal_probit_regression_hessian_cpp(X_fit, y, as.numeric(fit$params))
				},
				fisher_information = function(fit){
					fit$fisher_information %||% -get_ordinal_probit_regression_hessian_cpp(X_fit, y, as.numeric(fit$params))
				},
				information = function(fit){
					fit$information %||% fit$fisher_information %||% -get_ordinal_probit_regression_hessian_cpp(X_fit, y, as.numeric(fit$params))
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
					ws_args = private$get_backend_warm_start_args(n_params)
					if (estimate_only) {
						ws_fisher = ws_args$warm_start_fisher_info
						res = fast_ordinal_probit_regression_cpp(
							X_fit, private$y,
							warm_start_params = ws_args$start_params,
							warm_start_fisher_info = ws_fisher,
							smart_cold_start = private$smart_cold_start_default,
							estimate_only = TRUE
						)
						if (is.null(res) || length(res) == 0) return(NULL)
						list(b = res$b, ssq_b_j = NA_real_, params = res$params, fisher_information = ws_fisher)
					} else {
						res = fast_ordinal_probit_regression_with_var_cpp(
							X_fit, private$y,
							warm_start_params = ws_args$start_params,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
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

#' Ordered Probit Regression Inference for Ordinal Responses
#'
#' Fits a cumulative-probit ("ordered probit") model for ordinal responses:
#' \eqn{\Phi^{-1}(P(Y_i \le k)) = \alpha_k - (\beta_T W_i + X_i^\top \gamma)},
#' for cutpoints \eqn{\alpha_1 < \cdots < \alpha_{K-1}}, where \eqn{\Phi} is
#' the standard normal CDF, \eqn{W_i} is the treatment indicator, and
#' \eqn{X_i} are optional recorded covariates, by maximum likelihood
#' (\code{\link{fast_ordinal_probit_regression_cpp}}/
#' \code{\link{fast_ordinal_probit_regression_with_var_cpp}}). As with binary
#' probit regression, \eqn{\hat\beta_T} is not an odds-ratio-scale parameter:
#' it is the treatment's effect on the latent standard-normal index
#' underlying the ordinal categories. \code{likelihood_tier = "full"}:
#' likelihood-ratio, score, gradient, and Wald tests are all available when
#' the model converges, plus parametric-likelihood-bootstrap calibration of
#' the likelihood-ratio test. Validity requires the proportional/parallel
#' cutpoints assumption (a single \eqn{\beta_T} shared across all cutpoints)
#' in addition to the usual latent-normal-index assumption.
#'
#' @references McCullagh, P. (1980). "Regression Models for Ordinal Data."
#'   \emph{Journal of the Royal Statistical Society, Series B}, 42(2),
#'   109-142, \doi{10.1111/j.2517-6161.1980.tb01109.x}, for the cumulative-link
#'   ordinal model family this class's probit link instantiates.
#'
#' @seealso \code{\link[EDI:InferenceOrdinalCauchitRegr]{InferenceOrdinalCauchitRegr}},
#'   \code{\link[EDI:InferenceOrdinalCloglogRegr]{InferenceOrdinalCloglogRegr}}
#'   for other cumulative-link function choices on the same ordinal model
#'   family. See also:
#'   \href{https://en.wikipedia.org/wiki/Ordinal_regression}{Ordinal
#'   regression} and \href{https://en.wikipedia.org/wiki/Probit_model}{Probit
#'   model} (Wikipedia).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'ordinal')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(sample(1:4, 10, replace = TRUE))
#' inf = InferenceOrdinalOrderedProbitRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceOrdinalOrderedProbitRegr = define_inference_class(
	classname = "InferenceOrdinalOrderedProbitRegr",
	inherit = Inference,
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "OrdinalOrderedProbitLikelihood"),
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio", response_types = "ordinal"),
	overrides = list(
		public = c(
			"compute_estimate", "compute_rand_two_sided_pval",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"get_supported_testing_types", "set_testing_type", "compute_estimate_with_bootstrap_weights"
		),
		private = c(
			"compute_treatment_estimate_during_randomization_inference",
			"supports_likelihood_tests", "supports_reusable_bootstrap_worker",
			"generate_mod", "get_likelihood_test_spec",
			"supports_lik_ratio_param_bootstrap", "simulate_under_lik_null",
			"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"create_bootstrap_worker_state", "load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate", "get_supported_testing_types_impl",
			"get_standard_error", "get_degrees_of_freedom", "make_warm_fit_null_wrapper",
			"compute_likelihood_test_two_sided_pval", "compute_score_two_sided_pval_impl",
			"compute_gradient_two_sided_pval_impl", "compute_lik_ratio_two_sided_pval_impl",
			"supports_bartlett_likelihood_ratio_approx", "get_bartlett_factor_approx",
			"get_complexity_tier", "supports_fisher_information"
		)
	),
	public = list(
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	)
)
