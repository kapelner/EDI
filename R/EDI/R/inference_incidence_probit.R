IncidenceProbitLikelihoodSource = list(
	public = list(
		#' @description Initialize inference for the probit regression model
		#'   \eqn{\Phi^{-1}(P(Y_i = 1)) = \beta_0 + \beta_T W_i + X_i^\top \gamma};
		#'   see \code{\link[EDI:InferenceIncidProbitRegr]{InferenceIncidProbitRegr}}
		#'   for the model form. Does not fit the model; the fit is deferred to the
		#'   first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with an incidence response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values by default.
		#' @param harden  		Whether to apply robustness measures.
		#' @param optimization_alg  Optimization algorithm to use. Default is dispatched via policy.
		#' @param max_abs_reasonable_coef Cap for reasonable probit coefficients.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL, harden = TRUE, optimization_alg = NULL, max_abs_reasonable_coef = 10){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
				assertFormula(model_formula, null.ok = TRUE)
			}
			self$set_optimization_alg(optimization_alg, allow_irls = TRUE)
			super$initialize(des_obj, model_formula = model_formula, verbose = verbose, harden = harden, smart_cold_start_default = smart_cold_start_default)
			private$max_abs_reasonable_coef = max_abs_reasonable_coef
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Refits the probit model with subject/block-level weights
		#'   applied to the fitting log-likelihood (Bayesian-bootstrap or
		#'   nonparametric-bootstrap draw weights, expanded to row level via
		#'   \code{private$expand_subject_or_block_weights_to_row_weights()}) via
		#'   \code{fast_probit_regression_weighted_cpp}, and returns the
		#'   reweighted estimate \eqn{\hat\beta_T^{(w)}} on the latent
		#'   standard-normal-index scale. Uses the same QR column-dropping hardening
		#'   and fit-reasonableness check as \code{compute_estimate()}; a
		#'   hardened-but-still-unreasonable fit is cached as nonestimable and
		#'   returns \code{NA}.
		#' @param subject_or_block_weights Row weights for the bootstrap sample.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L,
				fit_fun = function(X_fit){
					res = fast_probit_regression_weighted_cpp(
						X = X_fit,
						y = private$y,
						weights = row_weights,
						warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
						smart_cold_start = private$smart_cold_start_default,
						warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit)),
						optimization_alg = private$optimization_alg
					)
					ssq_b_2 = NA_real_
					if (!estimate_only && !is.null(res$fisher_information) && is.matrix(res$fisher_information) && nrow(res$fisher_information) >= 2L) {
						inv_fi = tryCatch(solve(res$fisher_information), error = function(e) NULL)
						if (!is.null(inv_fi) && is.finite(inv_fi[2L, 2L]) && inv_fi[2L, 2L] > 0) ssq_b_2 = inv_fi[2L, 2L]
					}
					list(b = res$b, fisher_information = res$fisher_information, ssq_b_2 = ssq_b_2)
				},
				fit_ok = function(mod, X_fit, keep){
					isTRUE(private$is_probit_fit_reasonable(mod))
				}
			)
			private$cached_mod = attempt$fit
			if (!isTRUE(private$is_probit_fit_reasonable(attempt$fit))) {
				private$cache_nonestimable_estimate("probit_regression_weighted_extreme_coefficients")
				return(NA_real_)
			}
			private$cached_values$beta_hat_T = as.numeric(attempt$fit$b[2])
			ssq = attempt$fit$ssq_b_2
			private$cached_values$s_beta_hat_T = if (!is.null(ssq) && is.finite(ssq) && ssq > 0) sqrt(ssq) else NA_real_
			private$set_fit_warm_start(
				as.numeric(attempt$fit$b),
				"beta",
				fisher = attempt$fit$fisher_information
			)
			private$cached_values$beta_hat_T
		}
	),
	private = list(
		# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
		# migration ladders): re-declared here even though Wald's own source
		# already declares cached_mod = NULL -- see the identical comment on
		# inference_incid_log_regr_private's cached_mod entry
		# (inference_incidence_logit.R) for the full explanation.
		cached_mod = NULL,
		best_X_colnames = NULL,
		max_abs_reasonable_coef = 10,
		is_probit_fit_reasonable = function(mod){
			if (is.null(mod) || is.null(mod$b) || length(mod$b) < 2L) return(FALSE)
			b = as.numeric(mod$b)
			all(is.finite(b)) && all(abs(b) <= private$max_abs_reasonable_coef)
		},
		get_complexity_tier = function() "medium",
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
				X = cbind(1, private$w)
			} else {
				X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
				X = cbind(1, treatment = private$w, X_cov)
			}
			res = fast_probit_regression_cpp(
				X = X, y = as.numeric(private$y),
				warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X)),
				smart_cold_start = private$smart_cold_start_default,
				warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X)),
				estimate_only = TRUE,
				optimization_alg = private$optimization_alg
			)
			if (!isTRUE(private$is_probit_fit_reasonable(res))){
				return(NA_real_)
			}
			private$set_fit_warm_start(res$b, "beta", fisher = res$fisher_information)
			as.numeric(res$b[2])
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
			b_null = as.numeric(null_fit$b)
			eta    = as.numeric(spec$X %*% b_null)
			mu     = pmin(pmax(pnorm(eta), 0), 1)
			y_sim  = private$simulate_param_boot_bernoulli_y(mu)
			if (is.null(y_sim)) return(NULL)
			X_fit  = spec$X
			j      = spec$j

			ws_args = private$get_backend_warm_start_args(ncol(X_fit))
			full_fit_b = tryCatch(
				fast_probit_regression_cpp(
					X = X_fit, y = y_sim,
					warm_start_beta = ws_args$warm_start_beta,
					warm_start_weights = ws_args$warm_start_weights,
					warm_start_fisher_info = ws_args$warm_start_fisher_info,
					smart_cold_start = private$smart_cold_start_default,
					optimization_alg = private$optimization_alg
				),
				error = function(e) NULL
			)
			if (!isTRUE(private$is_probit_fit_reasonable(full_fit_b))) return(NULL)
			list(
				worker_data = list(y = y_sim),
				full_fit = full_fit_b,
				fit_null = function(d, start = NULL){
					ws_args_null = private$get_backend_warm_start_args(ncol(X_fit))
					tryCatch(
						fast_probit_regression_with_var_cpp(
							X = X_fit, y = y_sim, j = j,
							warm_start_beta = start %||% full_fit_b$b,
							warm_start_weights = ws_args_null$warm_start_weights,
							warm_start_fisher_info = ws_args_null$warm_start_fisher_info,
							fixed_idx = j, fixed_values = d,
							smart_cold_start = TRUE,
							optimization_alg = private$optimization_alg
						),
						error = function(e) NULL
					)
				},
				neg_loglik = function(fit){
					eta_f = as.numeric(X_fit %*% as.numeric(fit$b))
					-sum(y_sim * pnorm(eta_f, log.p = TRUE) + (1 - y_sim) * pnorm(-eta_f, log.p = TRUE))
				}
			)
		},
		get_likelihood_test_spec = function(){
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			X_fit = ctx$X
			y = as.numeric(private$y)
			j_treat = as.integer(ctx$j_treat)
			list(
				X = X_fit,
				y = y,
				j = j_treat,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					ws_args = private$get_backend_warm_start_args(ncol(X_fit))
					fast_probit_regression_with_var_cpp(
						X = X_fit,
						y = y,
						j = j_treat,
						warm_start_beta = start %||% ws_args$warm_start_beta,
						smart_cold_start = private$smart_cold_start_default,
						warm_start_weights = ws_args$warm_start_weights,
						warm_start_fisher_info = ws_args$warm_start_fisher_info,
						fixed_idx = j_treat,
						fixed_values = delta,
						optimization_alg = private$optimization_alg
					)
				},
				extract_start = function(fit){
					as.numeric(fit$b)
				},
				score = function(fit){
					get_probit_regression_score_cpp(X_fit, y, as.numeric(fit$b))
				},
				observed_information = function(fit){
					-get_probit_regression_hessian_cpp(X_fit, as.numeric(fit$b))
				},
				fisher_information = function(fit){
					-get_probit_regression_hessian_cpp(X_fit, as.numeric(fit$b))
				},
				information = function(fit){
					-get_probit_regression_hessian_cpp(X_fit, as.numeric(fit$b))
				},
				neg_loglik = function(fit){
					if (!is.null(fit$neg_ll)) return(fit$neg_ll)
					if (!is.null(fit$neg_loglik)) return(fit$neg_loglik)
					eta = as.numeric(X_fit %*% as.numeric(fit$b))
					-sum(y * pnorm(eta, log.p = TRUE) + (1 - y) * pnorm(-eta, log.p = TRUE))
				}
			)
		},
		generate_mod = function(estimate_only = FALSE){
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L, # intercept and treatment
				fit_fun = function(X_fit){
					ws_args = private$get_backend_warm_start_args(ncol(X_fit))
					if (estimate_only) {
						res = fast_probit_regression_cpp(
							X_fit, private$y,
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_weights = ws_args$warm_start_weights,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default,
							estimate_only = TRUE,
							optimization_alg = private$optimization_alg
						)
						list(b = res$b, fisher_information = res$fisher_information, ssq_b_2 = NA_real_)
					} else {
						fast_probit_regression_with_var_cpp(
							X_fit, private$y,
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_weights = ws_args$warm_start_weights,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default,
							optimization_alg = private$optimization_alg
						)
					}
				},
				fit_ok = function(mod, X_fit, keep){
					if (!isTRUE(private$is_probit_fit_reasonable(mod))) return(FALSE)
					if (estimate_only) return(TRUE)
					is.finite(mod$ssq_b_2) && mod$ssq_b_2 > 0
				}
			)
			if (!isTRUE(private$is_probit_fit_reasonable(attempt$fit))) {
				private$cache_nonestimable_estimate("probit_regression_extreme_coefficients")
				private$cached_values$likelihood_test_context = NULL
				return(NULL)
			}
			if (!is.null(attempt$fit)){
				private$set_fit_warm_start(attempt$fit$b, "beta", fisher = attempt$fit$fisher_information, weights = attempt$fit$w)
				private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
				private$cached_values$likelihood_test_context = list(
					X = attempt$X,
					j_treat = match(2L, attempt$keep)
				)
			} else {
				private$cached_values$likelihood_test_context = NULL
			}
			attempt$fit
		},
		build_design_matrix = function(){
			X_cov = private$X
			if (is.null(X_cov) || ncol(X_cov) == 0) {
				X = cbind(`(Intercept)` = 1, treatment = private$w)
			} else {
				X = cbind(`(Intercept)` = 1, treatment = private$w, X_cov)
			}
			X
		}
	)
)

#' Probit Regression Inference for Incidence Responses
#'
#' Fits a probit regression model for binary (incidence) responses:
#' \eqn{\Phi^{-1}(P(Y_i = 1)) = \beta_0 + \beta_T W_i + X_i^\top \gamma},
#' where \eqn{\Phi} is the standard normal CDF, \eqn{W_i} is the treatment
#' indicator, and \eqn{X_i} are optional recorded covariates, by maximum
#' likelihood (\code{\link{fast_probit_regression_cpp}}/
#' \code{fast_probit_regression_weighted_cpp}). Unlike
#' \code{\link[EDI:InferenceIncidLogRegr]{InferenceIncidLogRegr}}'s logit
#' link, \eqn{\hat\beta_T} here is not an odds-ratio scale parameter: it is
#' the treatment's additive effect on the latent standard-normal index
#' underlying the binary outcome. \code{likelihood_tier = "full"}: Wald,
#' score, gradient, and likelihood-ratio tests are all available when the
#' model converges, plus parametric-likelihood-bootstrap calibration of the
#' likelihood-ratio test. A fit whose coefficients exceed
#' \code{max_abs_reasonable_coef} in magnitude (a proxy for near-perfect
#' separation) is cached as nonestimable rather than returned. Validity
#' requires the usual probit assumptions: correctly specified linear
#' predictor on the latent-normal scale, independence across subjects
#' conditional on covariates, and no perfect/quasi-complete separation.
#'
#' @references McCullagh, P., and Nelder, J. A. (1989). \emph{Generalized
#'   Linear Models} (2nd ed.). Chapman and Hall/CRC, for the binomial GLM
#'   family and probit link.
#'
#' @seealso \code{\link[EDI:InferenceIncidLogRegr]{InferenceIncidLogRegr}}
#'   for the logit-link alternative with a log-odds-ratio estimand.
#'   Comparable Python API:
#'   \href{https://www.statsmodels.org/stable/glm.html}{statsmodels GLM}
#'   (\code{family=Binomial(link=probit())}). See also:
#'   \href{https://en.wikipedia.org/wiki/Probit_model}{Probit model}
#'   (Wikipedia).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidProbitRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceIncidProbitRegr = define_inference_class(
	classname = "InferenceIncidProbitRegr",
	inherit = Inference,
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "IncidenceProbitLikelihood"),
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio"),
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
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval
	)
)
