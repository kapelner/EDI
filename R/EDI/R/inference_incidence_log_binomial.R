inference_incid_log_binomial_public = list(

		#' @description Initialize inference for the log-link binomial risk-ratio
		#'   model \eqn{\log P(Y_i = 1) = \beta_0 + \beta_T W_i + X_i^\top \gamma};
		#'   see \code{\link[EDI:InferenceIncidLogBinomial]{InferenceIncidLogBinomial}}
		#'   for the model form. Does not fit the model; the fit is deferred to the
		#'   first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with an incidence response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose               Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		#' @param harden                Whether to apply robustness measures.
		#' @param max_abs_reasonable_coef Cap for reasonable log-binomial coefficients.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL, harden = TRUE, max_abs_reasonable_coef = 25){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
			}
			super$initialize(des_obj, model_formula = model_formula, verbose = verbose, harden = harden, smart_cold_start_default = smart_cold_start_default)
			private$max_abs_reasonable_coef = max_abs_reasonable_coef
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Refits the log-binomial model with subject/block-level weights
		#'   applied to the fitting log-likelihood (Bayesian-bootstrap or
		#'   nonparametric-bootstrap draw weights, expanded to row level via
		#'   \code{private$expand_subject_or_block_weights_to_row_weights()}) via
		#'   \code{\link{fast_log_binomial_regression_weighted_cpp}}, and returns the
		#'   reweighted log-risk-ratio estimate \eqn{\hat\beta_T^{(w)}}. Uses the same
		#'   QR column-dropping hardening and fit-reasonableness check as
		#'   \code{compute_estimate()}; a hardened-but-still-unreasonable fit is
		#'   cached as nonestimable and returns \code{NA}.
		#' @param subject_or_block_weights Bootstrap weights at the subject or block level.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L,
				fit_fun = function(X_fit, keep){
					j_treat = match(2L, keep)
					res = tryCatch(
						fast_log_binomial_regression_weighted_cpp(
							X = X_fit,
							y = as.numeric(private$y),
							weights = as.numeric(row_weights),
							warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
							warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit)),
							smart_cold_start = private$smart_cold_start_default
						),
						error = function(e) NULL
					)
					if (is.null(res)) return(NULL)
					res$j_treat = j_treat
					ssq_b_j = NA_real_
					if (!estimate_only && !is.null(res$fisher_information) &&
					    is.matrix(res$fisher_information) && nrow(res$fisher_information) >= j_treat) {
						inv_fi = tryCatch(solve(res$fisher_information), error = function(e) NULL)
						if (!is.null(inv_fi) && is.finite(inv_fi[j_treat, j_treat]) && inv_fi[j_treat, j_treat] > 0) {
							ssq_b_j = inv_fi[j_treat, j_treat]
						}
					}
					res$ssq_b_j = ssq_b_j
					res$ssq_b_2 = ssq_b_j
					res
				},
				fit_ok = function(mod, X_fit, keep){
					j_treat = match(2L, keep)
					if (!isTRUE(private$is_log_binomial_fit_reasonable(mod, X_fit, j_treat))) return(FALSE)
					TRUE
				}
			)
			private$cached_mod = attempt$fit
			j_treat = match(2L, attempt$keep)
			if (!isTRUE(private$is_log_binomial_fit_reasonable(attempt$fit, attempt$X, j_treat))){
				private$cache_nonestimable_estimate("log_binomial_weighted_fit_unavailable")
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			private$set_fit_warm_start(attempt$fit$b, "beta", fisher = attempt$fit$fisher_information, force_pd = TRUE)
			private$cached_values$beta_hat_T = as.numeric(attempt$fit$b[j_treat])
			ssq = attempt$fit$ssq_b_j %||% attempt$fit$ssq_b_2
			private$cached_values$s_beta_hat_T = if (!is.null(ssq) && is.finite(ssq) && ssq > 0) sqrt(ssq) else NA_real_
			private$cached_values$df = NA_real_
			private$cached_values$beta_hat_T
		},
		#' @description Score confidence interval for \eqn{\beta_T} by test inversion
		#'   of the score test (find the set of \code{delta} not rejected at level
		#'   \code{alpha}); see \code{\link[EDI:InferenceAsympLik]{InferenceAsympLik}}
		#'   for the shared inversion contract. Falls back to a nonestimable result
		#'   (\code{NA} bounds) if the underlying root-finding fails or degenerates.
		#' @param alpha Two-sided miscoverage rate; the returned interval targets
		#'   \code{1 - alpha} coverage.
		compute_score_confidence_interval = function(alpha = 0.05){
			# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
			# migration ladders): was `super$compute_score_confidence_interval(...)`,
			# relying on classic R6 inheritance reaching InferenceAsympLik's real
			# implementation. Composed classes have no such `super$` chain --
			# calling the same private impl InferenceAsympLik's own public method
			# delegates to directly (see that file's compute_score_confidence_
			# interval) is the behavior-preserving replacement; same fix shape as
			# the identical StandardModelCacheSource super$ breakage documented in
			# inference_all_abstract_asymp_lik_std_mod_cache.R.
			ci = tryCatch(
				private$compute_score_confidence_interval_impl(alpha),
				error = function(e){
					msg = if (length(e$message) == 0L) "" else e$message
					if (grepl("'names' attribute", msg, fixed = TRUE) ||
					    grepl("must be the same length as the vector", msg, fixed = TRUE)) {
						private$cache_nonestimable_se("score_confidence_interval_unavailable")
						return(c(NA_real_, NA_real_))
					}
					stop(e)
				}
			)
			if (length(ci) < 2L || !all(is.finite(ci[1:2]))) {
				private$cache_nonestimable_se("score_confidence_interval_unavailable")
				return(c(NA_real_, NA_real_))
			}
			ci
		},
		#' @description Gradient confidence interval for \eqn{\beta_T} by test
		#'   inversion of the gradient test; see
		#'   \code{\link[EDI:InferenceAsympLik]{InferenceAsympLik}} for the shared
		#'   inversion contract. Falls back to a nonestimable result (\code{NA}
		#'   bounds) if the underlying root-finding fails or degenerates.
		#' @param alpha Two-sided miscoverage rate; the returned interval targets
		#'   \code{1 - alpha} coverage.
		compute_gradient_confidence_interval = function(alpha = 0.05){
			# See compute_score_confidence_interval()'s comment above -- same
			# super$ fix, same reason.
			ci = tryCatch(
				private$compute_gradient_confidence_interval_impl(alpha),
				error = function(e){
					msg = if (length(e$message) == 0L) "" else e$message
					if (grepl("'names' attribute", msg, fixed = TRUE) ||
					    grepl("must be the same length as the vector", msg, fixed = TRUE)) {
						private$cache_nonestimable_se("gradient_confidence_interval_unavailable")
						return(c(NA_real_, NA_real_))
					}
					stop(e)
				}
			)
			if (length(ci) < 2L || !all(is.finite(ci[1:2]))) {
				private$cache_nonestimable_se("gradient_confidence_interval_unavailable")
				return(c(NA_real_, NA_real_))
			}
			ci
		}
	)

inference_incid_log_binomial_private = list(
		# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
		# migration ladders): see inference_incid_log_regr_private's cached_mod
		# entry (inference_incidence_logit.R) for the full explanation.
		cached_mod = NULL,
		best_X_colnames = NULL,
		logbin_X_full_cache = NULL,
		logbin_w_cache = NULL,
		max_abs_reasonable_coef = 25,
		is_log_binomial_fit_reasonable = function(mod, X_fit = NULL, j_treat = 2L){
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
				if (any(eta > 1e-6)) return(FALSE)
			} else if (!is.null(mod$mu_hat)) {
				mu = as.numeric(mod$mu_hat)
				if (any(!is.finite(mu)) || any(mu < -1e-10) || any(mu > 1 + 1e-10)) return(FALSE)
			}
			TRUE
		},
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
				X = cbind(1, private$w)
			} else {
				X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
				X = cbind(1, treatment = private$w, X_cov)
			}
			ws_args = private$get_backend_warm_start_args(ncol(X))
			res = tryCatch(
				fast_log_binomial_regression_cpp(
					X = X, y = as.numeric(private$y),
					warm_start_beta = ws_args$warm_start_beta,
					warm_start_fisher_info = ws_args$warm_start_fisher_info,
					smart_cold_start = private$smart_cold_start_default
				),
				error = function(e) NULL
			)

			if (!isTRUE(private$is_log_binomial_fit_reasonable(res, X, 2L))){
				return(NA_real_)
			}
			private$set_fit_warm_start(res$b, "beta", fisher = res$fisher_information, force_pd = TRUE)
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
		compute_gradient_confidence_interval_impl = function(alpha){
			ci = private$invert_gradient_ci_uniroot(alpha)
			if (length(ci) >= 2L && all(is.finite(ci[1:2]))) return(ci)

			# Log-binomial fixed-effect profiles can be infeasible on one side of
			# the treatment coefficient.  Use the finite likelihood-ratio profile
			# interval rather than returning an NA gradient CI.
			ci_fallback = tryCatch(private$invert_lik_ratio_ci_newton(alpha), error = function(e) c(NA_real_, NA_real_))
			if (length(ci_fallback) >= 2L && all(is.finite(ci_fallback[1:2]))) {
				names(ci_fallback) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
				return(ci_fallback)
			}
			ci
		},
		simulate_under_lik_null = function(spec, delta, null_fit){
			b_null     = as.numeric(null_fit$b)
			mu         = pmin(pmax(exp(as.numeric(spec$X %*% b_null)), 0), 1)
			y_sim      = as.numeric(rbinom(length(mu), 1L, mu))
			X_fit      = spec$X
			j          = spec$j

			# Parametric bootstrap: use observed fit as anchor
			ws_args = private$get_backend_warm_start_args(ncol(X_fit))
			full_fit_b = tryCatch(
				fast_log_binomial_regression_cpp(
					X = X_fit, y = y_sim,
					warm_start_beta = ws_args$warm_start_beta,
					warm_start_fisher_info = ws_args$warm_start_fisher_info,
					smart_cold_start = private$smart_cold_start_default
				),
				error = function(e) NULL
			)
			if (!isTRUE(private$is_log_binomial_fit_reasonable(full_fit_b, X_fit, j))) return(NULL)
			list(
				full_fit = full_fit_b,
				fit_null = function(d, start = NULL){
					ws_args_null = private$get_backend_warm_start_args(ncol(X_fit))
					res = tryCatch(
						fast_log_binomial_regression_cpp(
							X = X_fit, y = y_sim,
							warm_start_beta = start %||% full_fit_b$b,
							warm_start_fisher_info = ws_args_null$warm_start_fisher_info,
							fixed_idx = j, fixed_values = d,
							smart_cold_start = TRUE
						),
						error = function(e) NULL
					)
					if (!isTRUE(private$is_log_binomial_fit_reasonable(res, X_fit, j))) return(NULL)
					res
				},
				neg_loglik = function(fit){
					eta_f  = as.numeric(X_fit %*% as.numeric(fit$b))
					mu_fit = exp(eta_f)
					-sum(y_sim * log(pmax(mu_fit, 1e-15)) + (1 - y_sim) * log(pmax(1 - mu_fit, 1e-15)))
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
				X = X_fit, y = y, j = j_treat,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					ws_args = private$get_backend_warm_start_args(ncol(X_fit))
					res = tryCatch(
						fast_log_binomial_regression_cpp(
							X_fit, y,
							warm_start_beta = start %||% ws_args$warm_start_beta,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							fixed_idx = j_treat, fixed_values = delta,
							smart_cold_start = private$smart_cold_start_default
						),
						error = function(e) NULL
					)

					if (!isTRUE(private$is_log_binomial_fit_reasonable(res, X_fit, j_treat))) return(NULL)
					res
				},
				extract_start = function(fit){
					as.numeric(fit$b)
				},
				score = function(fit){
					get_log_binomial_regression_score_cpp(X_fit, y, as.numeric(fit$b))
				},
				observed_information = function(fit){
					-get_log_binomial_regression_hessian_cpp(X_fit, y, as.numeric(fit$b))
				},
				fisher_information = function(fit){
					-get_log_binomial_regression_hessian_cpp(X_fit, y, as.numeric(fit$b))
				},
				information = function(fit){
					-get_log_binomial_regression_hessian_cpp(X_fit, y, as.numeric(fit$b))
				},
				neg_loglik = function(fit){
					eta = as.numeric(X_fit %*% as.numeric(fit$b))
					mu = exp(eta)
					-sum(y * log(pmax(mu, 1e-15)) + (1 - y) * log(pmax(1 - mu, 1e-15)))
				}
			)
		},
		generate_mod = function(estimate_only = FALSE){
			if (is.null(private$logbin_X_full_cache) || !identical(private$w, private$logbin_w_cache)) {
				X_data = private$get_X()
				private$logbin_X_full_cache = if (is.null(X_data) || ncol(X_data) == 0) {
					cbind(`(Intercept)` = 1, treatment = private$w)
				} else {
					cbind(`(Intercept)` = 1, treatment = private$w, X_data)
				}
				private$logbin_w_cache = private$w
			}
			X_full = private$logbin_X_full_cache
			
			if (!private$harden) {
				ws_args = private$get_backend_warm_start_args(ncol(X_full))
				if (estimate_only) {
					res = tryCatch(
						fast_log_binomial_regression_cpp(
							X_full, private$y,
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default,
							estimate_only = TRUE
						),
						error = function(e) NULL
					)
					if (is.null(res)) return(NULL)
					res$beta_hat_T = as.numeric(res$b[2L])
					res$ssq_b_j = NA_real_
					res$ssq_b_2 = NA_real_
				} else {
					res = tryCatch(
						fast_log_binomial_regression_with_var_cpp(
							X_full, private$y, j = 2L,
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default
						),
						error = function(e) NULL
					)
					if (is.null(res)) return(NULL)
					res$j_treat = 2L
					res$beta_hat_T = as.numeric(res$b[2L])
					res$ssq_b_2 = res$ssq_b_j
				}
				if (!isTRUE(private$is_log_binomial_fit_reasonable(res, X_full, 2L))) {
					private$cache_nonestimable_estimate("log_binomial_fit_unavailable")
					private$cached_values$likelihood_test_context = NULL
					return(NULL)
				}
				private$best_X_colnames = setdiff(colnames(X_full), c("(Intercept)", "treatment"))
				private$cached_values$likelihood_test_context = list(
					X = X_full,
					j_treat = 2L,
					full_neg_loglik = res$neg_ll
				)
				return(res)
			}

			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L, # intercept and treatment
				fit_fun = function(X_fit, keep){
					j_treat = which(keep == 2L)
					ws_args = private$get_backend_warm_start_args(ncol(X_fit))
					if (estimate_only) {
						res = tryCatch(
							fast_log_binomial_regression_cpp(
								X = X_fit, y = private$y,
								warm_start_beta = ws_args$warm_start_beta,
								warm_start_fisher_info = ws_args$warm_start_fisher_info,
								smart_cold_start = private$smart_cold_start_default
							),
							error = function(e) NULL
						)
						if (is.null(res)) return(NULL)
						list(b = res$b, beta_hat_T = as.numeric(res$b[j_treat]), ssq_b_j = NA_real_, j_treat = j_treat, fisher_information = res$fisher_information, neg_ll = res$neg_ll, converged = res$converged, mu_hat = res$mu_hat)
					} else {
						res = tryCatch(
							fast_log_binomial_regression_with_var_cpp(
								X = X_fit, y = private$y, j = j_treat,
								warm_start_beta = ws_args$warm_start_beta,
								warm_start_fisher_info = ws_args$warm_start_fisher_info,
								smart_cold_start = private$smart_cold_start_default
							),
							error = function(e) NULL
						)
						if (is.null(res)) return(NULL)
						res$j_treat = j_treat
						res$beta_hat_T = as.numeric(res$b[j_treat])
						res$ssq_b_2 = res$ssq_b_j
						res
					}
				},

				fit_ok = function(mod, X_fit, keep){
					j_treat = mod$j_treat
					if (!isTRUE(private$is_log_binomial_fit_reasonable(mod, X_fit, j_treat))) return(FALSE)
					if (estimate_only) return(TRUE)
					is.finite(mod$ssq_b_j %||% mod$ssq_b_2)
				}
			)
			if (!isTRUE(private$is_log_binomial_fit_reasonable(attempt$fit, attempt$X, attempt$fit$j_treat %||% match(2L, attempt$keep)))) {
				private$cache_nonestimable_estimate("log_binomial_fit_unavailable")
				private$cached_values$likelihood_test_context = NULL
				return(NULL)
			}
			if (!is.null(attempt$fit)){
				private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
				private$cached_values$likelihood_test_context = list(
					X = attempt$X,
					j_treat = attempt$fit$j_treat,
					full_neg_loglik = attempt$fit$neg_ll
				)
			} else {
				private$cached_values$likelihood_test_context = NULL
			}
			attempt$fit
		},
		build_design_matrix = function(){
			X_data = private$get_X()
			if (is.null(X_data) || ncol(X_data) == 0) {
				cbind(`(Intercept)` = 1, treatment = private$w)
			} else {
				cbind(`(Intercept)` = 1, treatment = private$w, X_data)
			}
		}
	)

IncidenceLogBinomialLikelihoodSource = list(
	public = inference_incid_log_binomial_public,
	private = inference_incid_log_binomial_private
)

#' Log-Binomial Regression Inference for Incidence Responses
#'
#' Fits a binomial regression with the \strong{log} link for binary
#' (incidence) responses: \eqn{\log P(Y_i = 1) = \beta_0 + \beta_T W_i +
#' X_i^\top \gamma}, where \eqn{W_i} is the treatment indicator and \eqn{X_i}
#' are optional recorded covariates, by maximum likelihood
#' (\code{\link{fast_log_binomial_regression_cpp}}/
#' \code{\link{fast_log_binomial_regression_weighted_cpp}}). \eqn{\hat\beta_T}
#' is a \strong{log risk ratio}: \eqn{\exp(\hat\beta_T)} is the estimated
#' treatment risk ratio (relative risk) directly, unlike the log-odds-ratio
#' from \code{\link[EDI:InferenceIncidLogRegr]{InferenceIncidLogRegr}}'s logit
#' link. \code{likelihood_tier = "full"}: Wald, score, gradient, and
#' likelihood-ratio tests are all available when the model converges, plus
#' parametric-likelihood-bootstrap calibration of the likelihood-ratio test.
#' Because the log link does not constrain fitted probabilities to
#' \eqn{[0,1]} (only to \eqn{[0,\infty)}), fits are hardened by QR
#' column-dropping and a coefficient-magnitude cap
#' (\code{max_abs_reasonable_coef}) and rejected as nonestimable when the fit
#' is implausible — the same practical limitation as the identity-link
#' sibling \code{\link[EDI:InferenceIncidBinomialIdentityRiskDiff]{
#' InferenceIncidBinomialIdentityRiskDiff}}, here applying to the upper rather
#' than both tails of the probability scale. Validity requires the
#' multiplicative log-linear risk model to be correctly specified over the
#' covariate range observed.
#'
#' @references McCullagh, P., and Nelder, J. A. (1989). \emph{Generalized
#'   Linear Models} (2nd ed.). Chapman and Hall/CRC, for the binomial GLM
#'   family and log-link relative-risk parameterization.
#'
#' @seealso \code{\link[EDI:InferenceIncidLogRegr]{InferenceIncidLogRegr}}
#'   (logit link, log-odds-ratio estimand),
#'   \code{\link[EDI:InferenceIncidBinomialIdentityRiskDiff]{
#'   InferenceIncidBinomialIdentityRiskDiff}} (identity link, risk-difference
#'   estimand) for alternative link/estimand choices on the same response
#'   type. Comparable Python API:
#'   \href{https://www.statsmodels.org/stable/glm.html}{statsmodels GLM}
#'   (\code{family=Binomial(link=log())}). See also:
#'   \href{https://en.wikipedia.org/wiki/Generalized_linear_model}{Generalized
#'   linear model} (Wikipedia).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidLogBinomial$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceIncidLogBinomial = define_inference_class(
	classname = "InferenceIncidLogBinomial",
	inherit = Inference,
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "IncidenceLogBinomialLikelihood"),
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio"),
	overrides = list(
		public = c(
			"compute_estimate", "compute_rand_two_sided_pval",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"get_supported_testing_types", "compute_estimate_with_bootstrap_weights",
			"compute_score_confidence_interval", "compute_gradient_confidence_interval"
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
			"get_complexity_tier", "compute_gradient_confidence_interval_impl"
		)
	),
	public = list(
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval
	)
)
