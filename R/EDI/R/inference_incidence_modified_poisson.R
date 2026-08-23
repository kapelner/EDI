IncidenceModifiedPoissonLikelihoodSource = list(
	public = list(

			#' @description Initialize inference for the modified Poisson model
			#'   \eqn{\log E[Y_i \mid w_i, x_i] = \beta_0 + \beta_T w_i + x_i^\top
			#'   \gamma}; see
			#'   \code{\link[EDI:InferenceIncidModifiedPoisson]{InferenceIncidModifiedPoisson}}
			#'   for the model form and the non-robust-SE caveat. Does not fit the
			#'   model; the fit is deferred to the first call to
			#'   \code{compute_estimate()} or a method that requires it.
			#' @param des_obj A completed \code{Design} object with an incidence response.
			#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
			#'   the formula from the design object is used and its pre-computed design matrix is
			#'   reused. If a formula is provided, a new design matrix is constructed from the
			#'   design's imputed covariates.
			#' @param verbose  		Whether to print progress messages.
			#' @param harden  		Whether to apply robustness measures.
			#' @param smart_cold_start_default   Whether to use smart cold start values.
			#' @param max_abs_reasonable_coef Cap for reasonable modified-Poisson coefficients.
			#' @param max_abs_reasonable_linear_predictor Cap for reasonable fitted log means.
			initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL, harden = TRUE, max_abs_reasonable_coef = 25, max_abs_reasonable_linear_predictor = 25){
				if (should_run_asserts()) {
					assertResponseType(des_obj$get_response_type(), "incidence")
				}
				super$initialize(des_obj, verbose = verbose, harden = harden, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
				private$max_abs_reasonable_coef = max_abs_reasonable_coef
				private$max_abs_reasonable_linear_predictor = max_abs_reasonable_linear_predictor
				if (should_run_asserts()) {
					assertNoCensoring(private$any_censoring)
				}
		},
		#' @description Fits the modified Poisson model by maximizing the Poisson
		#'   working log-likelihood on the binary response and returns the
		#'   log-risk-ratio estimate \eqn{\hat\beta_T}.
		#' @param estimate_only If TRUE, skip standard-error computation and cache
		#'   only the point estimate; used by randomization and bootstrap resampling
		#'   paths.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Wald confidence interval for \eqn{\beta_T} using the
		#'   model-based (non-robust) Poisson-working-likelihood standard error; see
		#'   \code{\link[EDI:InferenceIncidModifiedPoisson]{InferenceIncidModifiedPoisson}}'s
		#'   non-robust-SE caveat and
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared Wald
		#'   contract.
		#' @param alpha Two-sided miscoverage rate; the returned interval targets
		#'   \code{1 - alpha} coverage.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Two-sided Wald test of \eqn{H_0: \beta_T = \code{delta}}
		#'   using the model-based (non-robust) Poisson-working-likelihood standard
		#'   error; see
		#'   \code{\link[EDI:InferenceIncidModifiedPoisson]{InferenceIncidModifiedPoisson}}'s
		#'   non-robust-SE caveat.
		#' @param delta Log-risk-ratio value under the null hypothesis.
		compute_asymp_two_sided_pval = function(delta = 0){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		},
		#' @description Refits the modified Poisson model with subject/block-level
		#'   weights applied to the working log-likelihood (Bayesian-bootstrap or
		#'   nonparametric-bootstrap draw weights) via
		#'   \code{\link{fast_poisson_regression_weighted_cpp}}, and returns the
		#'   reweighted log-risk-ratio estimate \eqn{\hat\beta_T^{(w)}}. Uses the
		#'   same QR column-dropping hardening and fit-reasonableness check as
		#'   \code{compute_estimate()}; a hardened-but-still-unreasonable fit is
		#'   cached as nonestimable and returns \code{NA}.
		#' @param subject_or_block_weights Row weights for the bootstrap sample.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
				attempt = private$fit_with_hardened_qr_column_dropping(
					X_full = private$build_design_matrix(),
					required_cols = 2L,
					fit_fun = function(X_fit, keep){
						j_treat = match(2L, keep)
						res = fast_poisson_regression_weighted_cpp(
							X = X_fit,
							y = private$y,
						weights = row_weights,
						warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
						smart_cold_start = private$smart_cold_start_default,
						warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit))
					)
					list(b = res$b, ssq_b_j = NA_real_, j_treat = j_treat, mod = res, XtWX = res$XtWX)
					},
					fit_ok = function(mod, X_fit, keep){
						private$is_modified_poisson_fit_reasonable(mod, X_fit, match(2L, keep))
					}
				)
				private$cached_mod = attempt$fit$mod %||% attempt$fit
				j_treat = match(2L, attempt$keep)
				if (!isTRUE(private$is_modified_poisson_fit_reasonable(attempt$fit, attempt$X, j_treat))) {
					private$cache_nonestimable_estimate("modified_poisson_weighted_fit_unavailable")
					private$cached_values$beta_hat_T = NA_real_
					private$cached_values$s_beta_hat_T = NA_real_
					return(NA_real_)
				}
				private$cached_values$beta_hat_T = as.numeric(attempt$fit$b[j_treat])
				private$cached_values$s_beta_hat_T = NA_real_
				private$set_fit_warm_start(
				as.numeric(attempt$fit$b),
				"beta",
				fisher = attempt$fit$XtWX %||% attempt$fit$fisher_information
			)
			private$cached_values$beta_hat_T
		}
	),
	private = list(
			best_X_colnames = NULL,
			cached_mod = NULL,
			max_abs_reasonable_coef = 25,
			max_abs_reasonable_linear_predictor = 25,
			build_design_matrix = function(){
				X_cov = private$X
				if (is.null(X_cov) || ncol(X_cov) == 0) {
				X = cbind(`(Intercept)` = 1, treatment = private$w)
			} else {
				X = cbind(`(Intercept)` = 1, treatment = private$w, X_cov)
			}
			X
		},
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
			res = tryCatch(
				fast_poisson_regression_cpp(
					X = X, y = as.numeric(private$y),
					warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X)),
					smart_cold_start = private$smart_cold_start_default,
					warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X))
				),
				error = function(e) NULL
			)

				if (is.null(res) || !is.finite(res$b[2])){
					return(NA_real_)
				}
				if (!isTRUE(private$is_modified_poisson_fit_reasonable(res, X, 2L))){
					return(NA_real_)
				}
				private$set_fit_warm_start(res$b, "beta", fisher = res$XtWX)
				as.numeric(res$b[2])
			},
		supports_reusable_bootstrap_worker = function(){
			TRUE
		},
		supports_lik_ratio_param_bootstrap = function(){
			FALSE
		},
		supports_likelihood_tests = function(){
			FALSE
		},
			get_supported_testing_types_impl = function(){
				"wald"
			},
			is_modified_poisson_fit_reasonable = function(mod, X_fit = NULL, j_treat = 2L){
				if (is.null(mod) || is.null(mod$b)) return(FALSE)
				j_treat = as.integer(j_treat %||% mod$j_treat %||% 2L)
				if (length(j_treat) != 1L || !is.finite(j_treat) || j_treat < 1L) return(FALSE)
				b = as.numeric(mod$b)
				if (length(b) < j_treat || any(!is.finite(b))) return(FALSE)
				if (any(abs(b) > private$max_abs_reasonable_coef)) return(FALSE)
				if (!is.null(mod$converged) && !isTRUE(mod$converged)) return(FALSE)
				if (!is.null(X_fit)) {
					eta = tryCatch(as.numeric(as.matrix(X_fit) %*% b), error = function(e) NA_real_)
					if (any(!is.finite(eta))) return(FALSE)
					if (any(abs(eta) > private$max_abs_reasonable_linear_predictor)) return(FALSE)
				}
				TRUE
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
					fast_poisson_regression_with_var_cpp(
						X = X_fit,
						y = y,
						j = j_treat,
						warm_start_beta = start %||% private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
						warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit)),
						fixed_idx = j_treat,
						fixed_values = delta,
						smart_cold_start = private$smart_cold_start_default
					)
				},
				extract_start = function(fit){
					as.numeric(fit$b)
				},
				score = function(fit){
					as.numeric(fit$score %||% get_poisson_regression_score_cpp(X_fit, y, as.numeric(fit$b)))
				},
				observed_information = function(fit){
					-get_poisson_regression_hessian_cpp(X_fit, as.numeric(fit$b))
				},
				fisher_information = function(fit){
					-get_poisson_regression_hessian_cpp(X_fit, as.numeric(fit$b))
				},
				information = function(fit){
					-get_poisson_regression_hessian_cpp(X_fit, as.numeric(fit$b))
				},
				neg_loglik = function(fit){
					eta = as.numeric(X_fit %*% as.numeric(fit$b))
					-sum(y * eta - exp(eta) - lgamma(y + 1))
				}
			)
		},
		generate_mod = function(estimate_only = FALSE){
				# Use the common GLM fitting pattern
				attempt = private$fit_with_hardened_qr_column_dropping(
					X_full = private$build_design_matrix(),
					required_cols = 2L,
					fit_fun = function(X_fit, keep){
						j_treat = match(2L, keep)
						warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit))
						warm_fisher = private$get_fit_warm_start_fisher(ncol(X_fit))
						if (estimate_only) {
						res = fast_poisson_regression_cpp(
							X = X_fit, y = private$y,
							warm_start_beta = warm_start_beta,
							smart_cold_start = private$smart_cold_start_default,
							warm_start_fisher_info = warm_fisher
						)
						list(b = res$b, ssq_b_j = NA_real_, j_treat = j_treat, mod = res, XtWX = res$XtWX)
					} else {
						res = fast_poisson_regression_with_var_cpp(
							X = X_fit, y = private$y, j = j_treat,
							warm_start_beta = warm_start_beta,
							smart_cold_start = private$smart_cold_start_default,
							warm_start_fisher_info = warm_fisher
						)
						res$j_treat = j_treat
						res
					}
					},

					fit_ok = function(mod, X_fit, keep){
						j_treat = match(2L, keep)
						if (!isTRUE(private$is_modified_poisson_fit_reasonable(mod, X_fit, j_treat))) return(FALSE)
						if (estimate_only) return(TRUE)
						is.finite(mod$ssq_b_j) && mod$ssq_b_j > 0
					}
				)
					if (!isTRUE(private$is_modified_poisson_fit_reasonable(attempt$fit, attempt$X, match(2L, attempt$keep)))){
						private$cache_nonestimable_estimate("modified_poisson_fit_unavailable")
						private$cached_values$likelihood_test_context = NULL
						return(NULL)
					}
					if (!is.null(attempt$fit)){
						private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
						private$cached_mod = attempt$fit$mod %||% attempt$fit
					private$cached_values$likelihood_test_context = list(X = attempt$X, j_treat = which(attempt$keep == 2L))
					if (!is.null(attempt$fit$b)) {
						private$set_fit_warm_start(attempt$fit$b, "beta", fisher = attempt$fit$XtWX %||% attempt$fit$fisher_information)
					}
				}
				attempt$fit
			}
	)
)

#' Modified Poisson Regression Inference for Incidence Responses
#'
#' Fits Zou's (2004) modified Poisson regression for binary (incidence)
#' responses: \eqn{\log E[Y_i \mid w_i, x_i] = \beta_0 + \beta_T w_i +
#' x_i^\top \gamma}, fit by maximizing the ordinary Poisson log-likelihood
#' treating the binary \eqn{Y_i} as if it were Poisson-distributed (a valid
#' estimating equation for the conditional mean regardless of the true
#' outcome distribution, exactly as
#' \code{\link[EDI:InferencePropFractionalLogit]{InferencePropFractionalLogit}}'s
#' quasi-binomial fit is for fractional responses). \eqn{\hat\beta_T} is a
#' \strong{log risk ratio}: \eqn{\exp(\hat\beta_T)} is the estimated treatment
#' relative risk, the same estimand as
#' \code{\link[EDI:InferenceIncidLogBinomial]{InferenceIncidLogBinomial}}'s
#' log-binomial model, but modified Poisson never produces a fit failure from
#' the \eqn{[0,1]}-probability constraint that a genuine binomial log-link
#' model can hit. \strong{Caveat:} this implementation's standard error comes
#' from the ordinary (model-based) Poisson Fisher information
#' (\code{\link{fast_poisson_regression_with_var_cpp}}'s \code{ssq_b_j}), not
#' a robust/sandwich correction — Zou's (2004) original proposal specifically
#' pairs the misspecified Poisson working model with a robust sandwich
#' variance estimator to obtain valid standard errors under the resulting
#' overdispersion; users needing the fully robust modified-Poisson variance
#' should treat this class's standard errors/CIs/p-values as approximate.
#' \code{likelihood_tier = "full"} metadata is set for component-composition
#' purposes, but \code{private$supports_likelihood_tests()} is hard
#' \code{FALSE} — only Wald inference is exposed
#' (\code{get_supported_testing_types_impl()} returns \code{"wald"} only), not
#' likelihood-ratio/score/gradient tests. Fits with implausible coefficients
#' or fitted linear predictors (checked via
#' \code{private$is_modified_poisson_fit_reasonable()}, capped by
#' \code{max_abs_reasonable_coef}/\code{max_abs_reasonable_linear_predictor})
#' are cached as nonestimable rather than returned.
#'
#' @references Zou, G. (2004). "A Modified Poisson Regression Approach to
#'   Prospective Studies with Binary Data." \emph{American Journal of
#'   Epidemiology}, 159(7), 702-706, \doi{10.1093/aje/kwh090}.
#'
#' @seealso \code{\link[EDI:InferenceIncidLogBinomial]{InferenceIncidLogBinomial}}
#'   for the genuine log-binomial alternative with the same log-risk-ratio
#'   estimand. Comparable Python API:
#'   \href{https://www.statsmodels.org/stable/discretemod.html}{statsmodels
#'   discrete models} (\code{Poisson} family on binary data). See also:
#'   \href{https://en.wikipedia.org/wiki/Poisson_regression}{Poisson
#'   regression} (Wikipedia).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidModifiedPoisson$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceIncidModifiedPoisson = define_inference_class(
	classname = "InferenceIncidModifiedPoisson",
	inherit = Inference,
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "IncidenceModifiedPoissonLikelihood"),
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

#' Multi-subject Modified Poisson Inference for Incidence Responses
#'
#' Historical public alias for the modified Poisson implementation.
#'
#' @export
