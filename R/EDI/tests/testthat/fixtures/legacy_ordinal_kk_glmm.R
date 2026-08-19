#' GLMM Inference for KK Designs with Ordinal Response
#'
#' Fits a cumulative-logit mixed model (proportional odds) for ordinal responses
#' under a KK matching-on-the-fly design. The random intercept per matched pair is
#' integrated out via Gauss-Hermite quadrature.
#'
#' When \code{use_rcpp = TRUE} (default) the likelihood is maximised by an internal
#' Rcpp/L-BFGS routine that requires no external packages. Set \code{use_rcpp = FALSE}
#' to fall back to \pkg{glmmTMB}.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'ordinal')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(sample(1:4, 10, replace = TRUE))
#' inf = InferenceOrdinalKKGLMMLegacyOrig$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceOrdinalKKGLMMLegacyOrig = R6::R6Class("InferenceOrdinalKKGLMM",
	lock_objects = FALSE,
	inherit = InferenceParamBootstrap,
	public = utils::modifyList(as.list(InferenceMixinKKGLMMShared$public), list(
		#' @description Initialize KK ordinal GLMM inference, validate the ordinal
		#'   matched/reservoir design, and prepare the mixed-model likelihood used by
		#'   \code{\link[EDI:InferenceOrdinalKKGLMMLegacyOrig]{InferenceOrdinalKKGLMMLegacyOrig}}.
		#' @param des_obj A completed \code{Design} object with an ordinal response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param use_rcpp Logical. If \code{TRUE} (default), use internal Rcpp.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, use_rcpp = TRUE, verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertFormula(model_formula, null.ok = TRUE)
				assertFlag(use_rcpp)
			}
			if (use_rcpp) private$skip_glmm_pkg_check = TRUE
			super$initialize(des_obj, model_formula = model_formula, verbose = verbose, smart_cold_start_default = smart_cold_start_default)
			private$init_kk_glmm_shared(des_obj)
			private$use_rcpp = use_rcpp
		},
		#' @description Computes the class-specific treatment-effect estimate; see
		#'   \code{\link[EDI:Inference]{Inference}}.
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Uses the shared asymptotic confidence-interval contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param alpha Confidence level.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Uses the shared asymptotic two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param delta Null treatment effect value.
		compute_asymp_two_sided_pval = function(delta = 0){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		},
		#' @description Recomputes the KK ordinal GLMM treatment estimate under
		#'   Bayesian-bootstrap weights.
		#' @param subject_or_block_weights Subject-, block-, cluster-, or matched-set
		#'   bootstrap weights.
		#' @param estimate_only If \code{TRUE}, compute only the weighted point
		#'   estimate.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			if (weights_are_effectively_constant(row_weights)) {
				self$compute_estimate(estimate_only = estimate_only)
				beta_hat_T = as.numeric(private$cached_values$beta_hat_T)[1L]
				if (is.finite(beta_hat_T)) {
					private$cached_values$df = Inf
					private$cached_values$summary_table = NULL
					return(private$cached_values$beta_hat_T)
				}
			}
			pred_df = private$glmm_predictors_df()
			ok = is.finite(row_weights) & row_weights > 0 & is.finite(private$y)
			if (!any(ok)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				return(NA_real_)
			}
			X_fit = as.matrix(pred_df[ok, , drop = FALSE])
			y_fit = as.numeric(private$y[ok])
			n_params = ncol(X_fit) + length(sort(unique(y_fit))) - 1L
			mod = tryCatch(
				fast_ordinal_regression_weighted_cpp(
					X = X_fit,
					y = y_fit,
					weights = as.numeric(row_weights[ok]),
					warm_start_params = private$get_fit_warm_start_for_length("params", n_params),
					warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
					smart_cold_start = private$smart_cold_start_default
				),
				error = function(e) NULL
			)
			if (!is.null(mod) && !is.null(mod$params)) {
				private$set_fit_warm_start(as.numeric(mod$params), "params", fisher = mod$fisher_information)
			}
			beta_hat_T = if (is.null(mod) || length(mod$b) < 1L) NA_real_ else as.numeric(mod$b[1L])
			private$cached_values$beta_hat_T = beta_hat_T
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = Inf
			private$cached_values$summary_table = NULL
			private$cached_values$beta_hat_T
		}
	)),
	private = utils::modifyList(as.list(InferenceMixinKKGLMMShared$private), list(
		use_rcpp = TRUE,
		glmm_response_type  = function() "ordinal",
		glmm_family         = function() glmmTMB::cumulative(link = "logit"),
		supports_likelihood_tests = function(){
			isTRUE(private$use_rcpp)
		},
		shared = function(estimate_only = FALSE){
			if (private$use_rcpp) {
				private$shared_rcpp(estimate_only)
			} else {
				private$shared_glmm_tmb(estimate_only)
			}
		},
		shared_rcpp = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			private$clear_nonestimable_state()
			private$cached_mod = NULL
			private$cached_values$likelihood_test_context = NULL
			m_vec = private$m
			if (is.null(m_vec)) m_vec = rep(NA_integer_, private$n)
			m_vec[is.na(m_vec)] = 0L
			group_id = m_vec
			reservoir_idx = which(group_id == 0L)
			if (length(reservoir_idx) > 0L)
				group_id[reservoir_idx] = max(group_id) + seq_along(reservoir_idx)
			# X WITHOUT intercept (cutpoints serve as intercepts)
			if (ncol(as.matrix(private$X)) > 0){
				X_fit = as.matrix(private$glmm_predictors_df())  # [w, cov1, ...]
			} else {
				X_fit = matrix(private$w, ncol = 1L, dimnames = list(NULL, "w"))
			}
			# Convert y to 1-indexed integers
			y_levels = sort(unique(private$y))
			K = length(y_levels)
			y = as.integer(match(private$y, y_levels))
			n_alpha = K - 1L
			# Treatment is always the first column of X_fit (j_T = 0, 0-based)
			j_T = 0L
			
			start_len = n_alpha + ncol(X_fit) + 1L
			warm_start = private$get_fit_warm_start_for_length("params", start_len)
			
			# Warm start from fixed-effects ordinal MLE to avoid divergence if no cache
			start = if (!is.null(warm_start)) warm_start else tryCatch({
				nore = fast_ordinal_regression_cpp(X_fit, as.numeric(y) - 1L)
				alpha_direct = as.numeric(nore$alpha)  # K-1 direct cutpoints
				beta_nore    = as.numeric(nore$b)      # p betas
				# Convert direct alphas to log-diff parameterization
				alpha_par = numeric(n_alpha)
				if (n_alpha >= 1L) alpha_par[1L] = alpha_direct[1L]
				if (n_alpha >= 2L) {
					for (k in 2L:n_alpha) {
						diff_k = alpha_direct[k] - alpha_direct[k - 1L]
						alpha_par[k] = if (diff_k > 0) log(diff_k) else 0.0
					}
				}
				c(alpha_par, beta_nore, -3.0)  # log_sigma = -3 (small random effect)
			}, error = function(e) NULL)
			
			fit = tryCatch(
				fast_ordinal_glmm_cpp(
					X          = X_fit,
					y          = y,
					group_id   = as.integer(group_id),
					K          = K,
					j_T        = j_T,
					smart_cold_start = private$smart_cold_start_default,
					estimate_only = estimate_only,
					warm_start_params = start,
					eps_g      = 1e-3,
					warm_start_fisher_info = private$get_fit_warm_start_fisher(start_len),
					optimization_alg = private$optimization_alg
				),
				error = function(e) NULL
			)
			if (is.null(fit) || !isTRUE(fit$converged)) {
				private$cache_nonestimable_estimate("kk_glmm_rcpp_failed")
				return(invisible(NULL))
			}
			# b is the beta vector (no cutpoints); treatment is at index j_T+1 (1-based R)
			beta_hat_T = as.numeric(fit$b[j_T + 1L])
			if (!is.finite(beta_hat_T) || abs(beta_hat_T) > private$max_abs_reasonable_coef) {
				private$cache_nonestimable_estimate("kk_glmm_rcpp_nonestimable")
				return(invisible(NULL))
			}
			private$cached_mod = fit
			full_params = as.numeric(c(fit$alpha, fit$b, fit$log_sigma))
			private$set_fit_warm_start(full_params, "params", fisher = fit$fisher_information)

			private$cached_values$likelihood_test_context = list(
				X = X_fit,
				y = y,
				group_id = as.integer(group_id),
				K = K,
				j_treat = length(fit$alpha) + 1L,
				n_gh = 20L,
				start = full_params
			)
			private$cached_values$beta_hat_T = beta_hat_T
			private$cached_values$df   = Inf
			if (estimate_only) return(invisible(NULL))
			ssq = fit$ssq_b_T
			if (!is.null(ssq) && is.finite(ssq) && ssq > 0) {
				private$cached_values$s_beta_hat_T = sqrt(ssq)
			} else {
				j_in_full = length(fit$alpha) + 1L
				hess = tryCatch(
					get_ordinal_glmm_hessian_cpp(X_fit, y, as.integer(group_id), full_params, K, n_gh = 20L),
					error = function(e) NULL
				)
				se_fallback = NA_real_
				if (!is.null(hess) && is.matrix(hess) && nrow(hess) >= j_in_full) {
					vcov_hess = tryCatch(solve(hess), error = function(e) NULL)
					if (!is.null(vcov_hess) && is.finite(vcov_hess[j_in_full, j_in_full]) && vcov_hess[j_in_full, j_in_full] > 0) {
						se_fallback = sqrt(vcov_hess[j_in_full, j_in_full])
					}
				}
				private$cached_values$s_beta_hat_T = se_fallback
			}
		},
		get_likelihood_test_spec = function(){
			if (!isTRUE(private$use_rcpp)) return(NULL)
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			X_fit = ctx$X
			y = as.integer(ctx$y)
			group_id = as.integer(ctx$group_id)
			K = as.integer(ctx$K)
			j_treat = as.integer(ctx$j_treat)
			n_gh = as.integer(ctx$n_gh %||% 20L)
			list(
				X = X_fit,
				y = y,
				group_id = group_id,
				K = K,
				j = j_treat,
				n_gh = n_gh,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					run_fit = function(s){
						n_params = length(ctx$start)
						tryCatch(
							fast_ordinal_glmm_cpp(
								X = X_fit,
								y = y,
								group_id = group_id,
								K = K,
								j_T = 0L,
								smart_cold_start = private$smart_cold_start_default,
								estimate_only = FALSE,
								n_gh = n_gh,
								max_abs_log_sigma = 8.0,
								maxit = 300L,
								eps_g = 1e-3,
								warm_start_params = s,
								warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
								optimization_alg = private$optimization_alg %||% "lbfgs",
								fixed_idx = j_treat,
								fixed_values = delta
							),
							error = function(e) NULL
						)
					}
					warm_start = start %||% private$get_fit_warm_start_for_length("params", length(ctx$start)) %||% ctx$start
					fit = run_fit(warm_start)
					# If warm start caused failure, retry with the canonical default start
					if (is.null(fit) || !isTRUE(fit$converged)) {
						if (!identical(warm_start, ctx$start)) {
							fit2 = run_fit(ctx$start)
							if (!is.null(fit2) && isTRUE(fit2$converged)) fit = fit2
						}
					}
					if (!is.null(fit)) {
						fit$params = tryCatch(as.numeric(c(fit$alpha, fit$b, fit$log_sigma)), error = function(e) NULL)
					}
					fit
				},
				extract_start = function(fit){
					as.numeric(c(fit$alpha, fit$b, fit$log_sigma))
				},
				score = function(fit){
					as.numeric(get_ordinal_glmm_score_cpp(X_fit, y, group_id, as.numeric(c(fit$alpha, fit$b, fit$log_sigma)), K, n_gh = n_gh))
				},
				observed_information = function(fit){
					as.matrix(fit$fisher_information %||% fit$information %||% fit$observed_information %||% get_ordinal_glmm_hessian_cpp(X_fit, y, group_id, as.numeric(c(fit$alpha, fit$b, fit$log_sigma)), K, n_gh = n_gh))
				},
				fisher_information = function(fit){
					as.matrix(fit$fisher_information %||% fit$information %||% fit$observed_information %||% get_ordinal_glmm_hessian_cpp(X_fit, y, group_id, as.numeric(c(fit$alpha, fit$b, fit$log_sigma)), K, n_gh = n_gh))
				},
				information = function(fit){
					as.matrix(fit$fisher_information %||% fit$information %||% fit$observed_information %||% get_ordinal_glmm_hessian_cpp(X_fit, y, group_id, as.numeric(c(fit$alpha, fit$b, fit$log_sigma)), K, n_gh = n_gh))
				},
				neg_loglik = function(fit){
					as.numeric(fit$neg_loglik %||% fit$neg_ll)
				}
			)
		},
		supports_lik_ratio_param_bootstrap = function() isTRUE(private$use_rcpp),
		simulate_under_lik_null = function(spec, delta, null_fit){
			if (!isTRUE(private$use_rcpp)) return(NULL)
			params_null = as.numeric(c(null_fit$alpha, null_fit$b, null_fit$log_sigma))
			y = as.integer(spec$y)
			K = as.integer(spec$K)
			group_id = as.integer(spec$group_id)
			X_fit = spec$X
			j_treat = spec$j
			n = nrow(X_fit)
			G = max(group_id)
			n_alpha = K - 1L
			n_gh = as.integer(spec$n_gh %||% 20L)
			n_params = length(params_null)

			alpha_par = params_null[seq_len(n_alpha)]
			alpha_direct = numeric(n_alpha)
			alpha_direct[1L] = alpha_par[1L]
			if (n_alpha >= 2L) {
				for (k in seq(2L, n_alpha))
					alpha_direct[k] = alpha_direct[k - 1L] + exp(alpha_par[k])
			}
			betas = params_null[(n_alpha + 1L):(n_alpha + ncol(X_fit))]
			log_sigma = params_null[length(params_null)]
			sigma = exp(min(log_sigma, 8.0))
			if (!is.finite(sigma) || sigma <= 0) return(NULL)

			u = rnorm(G, 0, sigma)
			eta = as.numeric(X_fit %*% betas) + u[group_id]
			y_sim = integer(n)
			for (i in seq_len(n)) {
				cum_p = plogis(alpha_direct - eta[i])
				cat_p = pmax(c(cum_p[1L], diff(cum_p), 1 - cum_p[n_alpha]), 0)
				s = sum(cat_p)
				y_sim[i] = if (is.finite(s) && s > 0) sample.int(K, 1L, prob = cat_p / s) else 1L
			}
			if (length(unique(y_sim)) < K) return(NULL)

			warm_start = private$get_fit_warm_start_for_length("params", n_params) %||% params_null
			fit = tryCatch(
				fast_ordinal_glmm_cpp(
					X = X_fit, y = y_sim, group_id = group_id, K = K,
					j_T = 0L,
					smart_cold_start = private$smart_cold_start_default,
					estimate_only = FALSE,
					n_gh = n_gh,
					warm_start_params = warm_start,
					warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
					optimization_alg = private$optimization_alg %||% "lbfgs"
				),
				error = function(e) NULL
			)
			if (is.null(fit) || !isTRUE(fit$converged)) return(NULL)
			full_fit_boot = list(
				alpha = fit$alpha, b = fit$b, log_sigma = fit$log_sigma,
				params = as.numeric(c(fit$alpha, fit$b, fit$log_sigma)),
				neg_loglik = as.numeric(fit$neg_loglik %||% fit$neg_ll)
			)
			if (!is.finite(full_fit_boot$neg_loglik)) return(NULL)

			list(
				full_fit = full_fit_boot,
				fit_null = function(d, start = NULL){
					ws = start %||% private$get_fit_warm_start_for_length("params", n_params) %||% params_null
					fit2 = tryCatch(
						fast_ordinal_glmm_cpp(
							X = X_fit, y = y_sim, group_id = group_id, K = K,
							j_T = 0L,
							smart_cold_start = TRUE,
							estimate_only = FALSE,
							n_gh = n_gh,
							warm_start_params = ws,
							warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
							optimization_alg = private$optimization_alg %||% "lbfgs",
							fixed_idx = j_treat, fixed_values = d
						),
						error = function(e) NULL
					)
					if (is.null(fit2) || !isTRUE(fit2$converged)) return(NULL)
					list(
						alpha = fit2$alpha, b = fit2$b, log_sigma = fit2$log_sigma,
						params = as.numeric(c(fit2$alpha, fit2$b, fit2$log_sigma)),
						neg_loglik = as.numeric(fit2$neg_loglik %||% fit2$neg_ll)
					)
				},
				neg_loglik = function(fit) as.numeric(fit$neg_loglik)
			)
		}
	))
)
