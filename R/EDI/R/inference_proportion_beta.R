#' Beta Regression Inference for Proportion Responses
#'
#' Fits Ferrari and Cribari-Neto's (2004) beta regression for proportion
#' responses \eqn{Y_i \in (0, 1)}: \eqn{\mathrm{logit}(E[Y_i \mid W_i, X_i]) =
#' \beta_0 + \beta_T W_i + X_i^\top \gamma}, \eqn{Y_i \mid W_i, X_i \sim
#' \mathrm{Beta}(\mu_i \phi, (1-\mu_i)\phi)} for fitted mean \eqn{\mu_i} and a
#' single (constant, not covariate-dependent) precision parameter \eqn{\phi},
#' by maximum likelihood (\code{\link{fast_beta_regression_cpp}}/
#' \code{\link{fast_beta_regression_weighted_cpp}}). \eqn{\hat\beta_T} is a
#' log-odds-ratio on the conditional-mean scale: \eqn{\exp(\hat\beta_T)} is
#' the odds ratio for the expected proportion. Unlike
#' \code{\link[EDI:InferencePropFractionalLogit]{InferencePropFractionalLogit}}'s
#' quasi-likelihood (which specifies only the conditional mean), beta
#' regression also specifies the conditional variance/shape via \eqn{\phi} —
#' a correctly specified beta model yields a fully efficient likelihood-based
#' fit and genuine likelihood-ratio/score/gradient tests, at the cost of
#' requiring the beta-distribution shape assumption to actually hold.
#' \code{likelihood_tier = "full"}: likelihood-ratio, score, gradient, and
#' Wald tests are all available when the model converges, plus
#' parametric-likelihood-bootstrap calibration of the likelihood-ratio test.
#' \eqn{Y_i} values of exactly 0 or 1 are not supported by the beta density
#' and are handled by \code{sanitize_beta_response()}'s boundary adjustment
#' before fitting.
#'
#' @references Ferrari, S., and Cribari-Neto, F. (2004). "Beta regression for
#'   modelling rates and proportions." \emph{Journal of Applied Statistics},
#'   31(7), 799-815, \doi{10.1080/0266476042000214501}.
#'
#' @seealso \code{\link[EDI:InferencePropFractionalLogit]{InferencePropFractionalLogit}}
#'   for a quasi-likelihood proportion model that specifies only the
#'   conditional mean. Comparable Python API: no direct beta-regression
#'   equivalent in \pkg{statsmodels}; see
#'   \href{https://www.statsmodels.org/stable/glm.html}{statsmodels GLM} for
#'   the general exponential-family GLM framework. See also:
#'   \href{https://en.wikipedia.org/wiki/Beta_distribution}{Beta
#'   distribution} (Wikipedia).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'proportion')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(runif(10))
#' inf = InferencePropBetaRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferencePropBetaRegr = define_inference_class(
	classname = "InferencePropBetaRegr",
	inherit = Inference,
	# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
	# migration ladders): unlike its 10 AsympLikStdModCache siblings, this
	# class has no pre-registered per-class component (no `*Source`
	# extraction line existed in this file before this migration), so its
	# public=/private= content is declared inline directly rather than
	# hoisted into a separate registered component.
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "StandardModelCache"),
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
			"get_complexity_tier"
		)
	),
	public = list(
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize inference for the beta regression model
		#'   \eqn{\mathrm{logit}(E[Y_i \mid W_i, X_i]) = \beta_0 + \beta_T W_i +
		#'   X_i^\top \gamma}, \eqn{Y_i \sim \mathrm{Beta}(\mu_i \phi, (1-\mu_i)
		#'   \phi)}; see
		#'   \code{\link[EDI:InferencePropBetaRegr]{InferencePropBetaRegr}} for the
		#'   model form. Does not fit the model; the fit is deferred to the first
		#'   call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with a proportion response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values by default.
		#' @param optimization_alg Character scalar specifying the optimization algorithm. 
		#'   Default is dispatched via policy.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL, optimization_alg = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "proportion")
				assertFormula(model_formula, null.ok = TRUE)
			}
			self$set_optimization_alg(optimization_alg, allow_irls = FALSE)
			super$initialize(des_obj, model_formula = model_formula, verbose = verbose, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Fits the beta regression model by maximum likelihood
		#'   (jointly estimating the mean coefficients and the precision parameter
		#'   \eqn{\phi}) and returns the log-odds-ratio estimate \eqn{\hat\beta_T}
		#'   on the conditional-mean scale.
		#' @param estimate_only If TRUE, skip standard-error computation and cache
		#'   only the point estimate; used by randomization and bootstrap resampling
		#'   paths.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Refits the beta model with subject/block-level weights
		#'   applied to the fitting log-likelihood (Bayesian-bootstrap or
		#'   nonparametric-bootstrap draw weights, expanded to row level via
		#'   \code{private$expand_subject_or_block_weights_to_row_weights()}) via
		#'   \code{\link{fast_beta_regression_weighted_cpp}}, and returns the
		#'   reweighted estimate \eqn{\hat\beta_T^{(w)}}. Uses the same QR
		#'   column-dropping hardening as \code{compute_estimate()}; a
		#'   hardened-but-still-unreasonable fit is cached as nonestimable.
		#' @param subject_or_block_weights Bootstrap weights at the subject or block level.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L,
				fit_fun = function(X_fit, keep){
					y_fit = sanitize_beta_response(as.numeric(private$y))
					res = tryCatch({
						n_params = ncol(X_fit) + 1L
						ws_args = private$get_backend_warm_start_args(n_params)
						start_params = ws_args$start_params
						start_beta = if (!is.null(start_params) && length(start_params) >= ncol(X_fit)) {
							start_params[seq_len(ncol(X_fit))]
						} else {
							ws_args$start_beta
						}
						start_phi = if (!is.null(start_params) && length(start_params) >= n_params) {
							exp(start_params[n_params])
						} else {
							10
						}
						fast_beta_regression_weighted_cpp(
							X = X_fit,
							y = y_fit,
							weights = row_weights,
							warm_start_beta = start_beta,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default,
							start_phi = start_phi,
							estimate_only = estimate_only,
							optimization_alg = private$optimization_alg
						)
					}, error = function(e) NULL)
					if (!is.null(res)) {
						coef_vec = as.numeric(res$coefficients)
						if (all(is.finite(coef_vec))) {
							ssq_b_2 = NA_real_
							if (!estimate_only && !is.null(res$fisher_information) &&
							    is.matrix(res$fisher_information) && nrow(res$fisher_information) >= 2L) {
								inv_fi = tryCatch(solve(res$fisher_information), error = function(e) NULL)
								if (!is.null(inv_fi) && is.finite(inv_fi[2L, 2L]) && inv_fi[2L, 2L] > 0) {
									ssq_b_2 = inv_fi[2L, 2L]
								}
							}
							return(list(
								b = coef_vec,
								phi = as.numeric(res$phi),
								fisher_information = res$fisher_information,
								ssq_b_2 = ssq_b_2
							))
						}
					}
					lm_fit = tryCatch(
						stats::lm.wfit(x = X_fit, y = logit(y_fit), w = row_weights),
						error = function(e) NULL
					)
					if (is.null(lm_fit) || length(lm_fit$coefficients) < 2L) return(NULL)
					list(
						b = as.numeric(lm_fit$coefficients),
						phi = NA_real_,
						fisher_information = NULL,
						ssq_b_2 = NA_real_
					)
				},
				fit_ok = function(mod, X_fit, keep){
					!is.null(mod) && length(mod$b) >= 2L && is.finite(mod$b[2L])
				}
			)
			private$cached_mod = attempt$fit
			if (is.null(attempt$fit) || is.null(attempt$fit$b) || length(attempt$fit$b) < 2L || !is.finite(attempt$fit$b[2L])) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			private$cached_values$beta_hat_T = as.numeric(attempt$fit$b[2L])
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = NA_real_
			private$set_fit_warm_start(
				c(as.numeric(attempt$fit$b), if (is.finite(attempt$fit$phi)) log(as.numeric(attempt$fit$phi)) else 0),
				"params",
				fisher = attempt$fit$fisher_information
			)
			private$cached_values$beta_hat_T
		}
	),
	private = list(
		# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
		# migration ladders): see inference_incid_log_regr_private's
		# cached_mod entry (inference_incidence_logit.R) for the eager-NULL-
		# dropping explanation this applies to as well. cached_vc_params was
		# previously undeclared entirely (created dynamically on first
		# assignment, harmless only because lock_objects=FALSE let it spring
		# into existence) -- declared explicitly for the same reason.
		cached_mod = NULL,
		cached_vc_params = NULL,
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
				X = cbind(`(Intercept)` = 1, treatment = private$w)
			} else {
				X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
				X = cbind(`(Intercept)` = 1, treatment = private$w, X_cov)
			}
			n_params = ncol(X) + 1L
			ws_args = private$get_backend_warm_start_args(n_params)
			has_vc = isTRUE(is.finite(private$cached_vc_params))
			res = fast_beta_regression_cpp(
				X = X, y = sanitize_beta_response(as.numeric(private$y)),
				warm_start_beta = ws_args$start_beta,
				warm_start_fisher_info = ws_args$warm_start_fisher_info,
				compute_std_errs = FALSE,
				smart_cold_start = private$smart_cold_start_default,
				optimization_alg = private$optimization_alg,
				fixed_idx    = if (has_vc) as.integer(ncol(X) + 1L) else NULL,
				fixed_values = if (has_vc) as.numeric(private$cached_vc_params) else NULL
			)

			if (is.null(res) || !is.finite(res$coefficients[2])){
				return(NA_real_)
			}
			private$set_fit_warm_start(c(as.numeric(res$coefficients), log(as.numeric(res$phi))), "params", fisher = res$fisher_information)
			as.numeric(res$coefficients[2])
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
		simulate_under_lik_null = function(spec, delta, null_fit){
			b_null = as.numeric(null_fit$b)
			phi    = as.numeric(null_fit$phi)
			if (!is.finite(phi) || phi <= 0) return(NULL)
			mu     = pmin(pmax(plogis(as.numeric(spec$X %*% b_null)), 1e-8), 1 - 1e-8)
			y_sim  = rbeta(length(mu), shape1 = mu * phi, shape2 = (1 - mu) * phi)
			y_sim  = pmin(pmax(y_sim, 1e-8), 1 - 1e-8)
			X_fit  = spec$X
			j      = spec$j
			
			# Parametric bootstrap: use observed fit as anchor for the full fit
			ws_args = private$get_backend_warm_start_args(ncol(X_fit) + 1L)
			full_res = tryCatch(
				fast_beta_regression_cpp(
					X = X_fit, y = y_sim,
					warm_start_beta = ws_args$start_beta,
					warm_start_fisher_info = ws_args$warm_start_fisher_info,
					smart_cold_start = private$smart_cold_start_default,
					optimization_alg = private$optimization_alg
				),
				error = function(e) NULL
			)
			if (is.null(full_res) || length(full_res$coefficients) < j || !is.finite(full_res$coefficients[j])) return(NULL)
			full_fit_boot = list(
				b          = as.numeric(full_res$coefficients),
				phi        = as.numeric(full_res$phi),
				neg_loglik = as.numeric(full_res$neg_loglik)
			)
			list(
				full_fit = full_fit_boot,
				fit_null = function(d, start = NULL){
					ws_args_null = private$get_backend_warm_start_args(ncol(X_fit) + 1L)
					res = tryCatch(
						fast_beta_regression_cpp(
							X = X_fit, y = y_sim,
							warm_start_beta = (if (!is.null(start)) start[seq_len(ncol(X_fit))] else full_fit_boot$b),
							warm_start_fisher_info = ws_args_null$warm_start_fisher_info,
							fixed_idx = j, fixed_values = d,
							smart_cold_start = TRUE,
							optimization_alg = private$optimization_alg
						),
						error = function(e) NULL
					)
					if (is.null(res)) return(NULL)
					list(b = as.numeric(res$coefficients), phi = as.numeric(res$phi), neg_loglik = as.numeric(res$neg_loglik))
				},
				neg_loglik = function(fit) as.numeric(fit$neg_loglik)
			)
		},
		get_likelihood_test_spec = function(){
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			X_fit = ctx$X
			y = sanitize_beta_response(as.numeric(private$y))
			j_treat = as.integer(ctx$j_treat)
			list(
				X = X_fit, y = y, j = j_treat,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					ws_args = private$get_backend_warm_start_args(ncol(X_fit) + 1L)
					res = fast_beta_regression_cpp(
						X_fit, y,
						fixed_idx = j_treat, fixed_values = delta,
						warm_start_beta = if (!is.null(start)) start[1:ncol(X_fit)] else ws_args$start_beta,
						warm_start_fisher_info = ws_args$warm_start_fisher_info,
						smart_cold_start = private$smart_cold_start_default,
						optimization_alg = private$optimization_alg
					)
					if (is.null(res)) return(NULL)
					list(b = as.numeric(res$coefficients), phi = res$phi, neg_loglik = res$neg_loglik, fisher_information = res$fisher_information)
				},
				extract_start = function(fit){
					c(as.numeric(fit$b), log(as.numeric(fit$phi)))
				},
				score = function(fit){
					params = c(as.numeric(fit$b), log(as.numeric(fit$phi)))
					get_beta_regression_score_cpp(X_fit, y, params)
				},
				observed_information = function(fit){
					params = c(as.numeric(fit$b), log(as.numeric(fit$phi)))
					-get_beta_regression_hessian_cpp(X_fit, y, params)
				},
				fisher_information = function(fit){
					fit$fisher_information %||% {
						params = c(as.numeric(fit$b), log(as.numeric(fit$phi)))
						-get_beta_regression_hessian_cpp(X_fit, y, params)
					}
				},
				information = function(fit){
					fit$information %||% fit$fisher_information %||% {
						params = c(as.numeric(fit$b), log(as.numeric(fit$phi)))
						-get_beta_regression_hessian_cpp(X_fit, y, params)
					}
				},
				neg_loglik = function(fit){ as.numeric(fit$neg_loglik) }
			)
		},
		generate_mod = function(estimate_only = FALSE){
			X_full = private$build_design_matrix()
			y_san = sanitize_beta_response(as.numeric(private$y))
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L,
				fit_fun = function(X_fit){
					n_params = ncol(X_fit) + 1L
					ws_args = private$get_backend_warm_start_args(n_params)
					if (estimate_only) {
						res = fast_beta_regression_cpp(
							X_fit, y_san,
							warm_start_beta = ws_args$start_beta,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							compute_std_errs = FALSE,
							smart_cold_start = private$smart_cold_start_default,
							optimization_alg = private$optimization_alg
						)
						if (is.null(res)) return(NULL)
						list(b = res$coefficients, ssq_b_2 = NA_real_, phi = res$phi, neg_loglik = res$neg_loglik, fisher_information = res$fisher_information)
					} else {
						res = fast_beta_regression_with_var_cpp(
							X_fit, y_san,
							warm_start_beta = ws_args$start_beta,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default,
							optimization_alg = private$optimization_alg
						)
						if (is.null(res)) return(NULL)
						list(b = res$coefficients,
						     ssq_b_2 = if (!is.null(res$vcov) && nrow(res$vcov) >= 2L) res$vcov[2L, 2L] else NA_real_,
						     phi = res$phi, neg_loglik = res$neg_loglik, fisher_information = res$fisher_information)
					}
				},

				fit_ok = function(mod, X_fit, keep){
					!is.null(mod) && length(mod$b) >= 2L && is.finite(mod$b[2L]) && max(abs(mod$b), na.rm = TRUE) <= 100
				}
			)
			if (!is.null(attempt$fit)){
				private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
				log_phi = log(as.numeric(attempt$fit$phi))
				if (isTRUE(is.finite(log_phi))) private$cached_vc_params = log_phi
				private$set_fit_warm_start(c(as.numeric(attempt$fit$b), log_phi), "params", fisher = attempt$fit$fisher_information)
				private$cached_values$likelihood_test_context = list(
					X = attempt$X,
					j_treat = which(attempt$keep == 2L)
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
