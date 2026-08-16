#' Robust (M/MM-Estimator) Regression Inference for Continuous Responses
#'
#' Fits a robust linear regression — by default via this package's
#' \code{\link{fast_robust_regression_cpp}} C++ backend (\code{use_rcpp = TRUE};
#' see that page for the full M/MM-estimator model, weight functions, and
#' asymptotic variance formula), or via \code{MASS::rlm} when \code{use_rcpp =
#' FALSE} — for a continuous response using the treatment indicator and,
#' optionally, all recorded covariates as predictors. This provides a
#' Huber/MM-style robustness upgrade over ordinary least squares when outcomes
#' are heavy-tailed or outlier-prone, down-weighting large residuals rather
#' than letting them dominate the fit the way squared-error loss does.
#'
#' @details
#' The \code{method} argument is passed through to either backend and may be
#' either \code{"M"} (Huber's psi function) or \code{"MM"} (Tukey's bisquare
#' weight, the default — higher breakdown point than \code{"M"} at some cost
#' in asymptotic efficiency under normality). When \code{use_rcpp = TRUE}
#' (the default), coefficient standard errors come from the C++ backend's own
#' M-estimator asymptotic variance (\code{ssq_b_j}); when \code{FALSE}, they
#' come from the coefficient table returned by \code{summary.rlm()}. Either
#' way, confidence intervals and p-values use that standard error with
#' residual degrees of freedom \eqn{n - p} in a normal-theory Wald
#' approximation (not an exact finite-sample distribution).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'continuous')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rnorm(10))
#' inf = InferenceContinRobustRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceContinRobustRegr = define_inference_class(
	classname = "InferenceContinRobustRegr",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald"),
	public = list(
		#' @description Uses the shared randomization two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceRand]{InferenceRand}}.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
				
		#' @description Initialize a robust-regression inference object for a
		#'   completed design with a continuous, uncensored response.
		#' @param des_obj A completed \code{Design} object with a continuous response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param method Robust estimation method, \code{"M"} (Huber) or \code{"MM"}
		#'   (Tukey bisquare, higher breakdown point). Default \code{"MM"}.
		#' @param use_rcpp Whether to use the \code{\link{fast_robust_regression_cpp}}
		#'   C++ backend (\code{TRUE}, default) instead of \code{MASS::rlm} (\code{FALSE}).
		#' @param verbose Whether to print progress messages. Default \code{FALSE}.
		#' @param smart_cold_start_default Whether to use smart starting values for the optimizer.
		initialize = function(des_obj, model_formula = NULL, method = "MM", use_rcpp = TRUE, verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "continuous")
				assertChoice(method, c("M", "MM"))
				assertFormula(model_formula, null.ok = TRUE)
				assertFlag(use_rcpp)
			}
			super$initialize(des_obj, model_formula = model_formula, verbose = verbose, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
			
			
			private$rlm_method = method
			private$use_rcpp = use_rcpp
		},
		#' @description Computes the robust-regression treatment coefficient
		#'   \eqn{\hat\beta_T} from an M/MM-estimator fit (see class documentation
		#'   for the full model and \code{use_rcpp} backend choice). Rank-deficient
		#'   covariate columns are dropped before fitting via
		#'   \code{private$fit_with_hardened_qr_column_dropping()}.
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the robust-regression treatment estimate under
		#'   subject/block bootstrap weights, used by the Bayesian bootstrap and
		#'   related weighted-resampling machinery; see
		#'   \code{\link[EDI:InferenceBayesianBootstrap]{InferenceBayesianBootstrap}}.
		#'   When \code{use_rcpp = TRUE}, reproduces \code{MASS::rlm}'s default
		#'   \code{wt.method = "inv.var"} weighting exactly by pre-multiplying
		#'   \code{X} and \code{y} by \eqn{\sqrt{\text{weight}}} and running
		#'   unweighted M-estimation on the transformed data via the C++ backend
		#'   (rather than adding native weight support to that backend); when
		#'   \code{use_rcpp = FALSE}, passes \code{weights} directly to
		#'   \code{MASS::rlm}. This variant never populates a standard error or
		#'   degrees of freedom (both left \code{NA}) — it is estimate-only by
		#'   construction, matching the \code{estimate_only} default of the fast
		#'   path it always uses internally.
		#' @param subject_or_block_weights Bootstrap weights at the subject or block level.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			X_fit = private$build_design_matrix()
			if (private$use_rcpp) {
				# MASS::rlm's default wt.method = "inv.var" transforms (X, y) by sqrt(weight)
				# and runs ordinary (unweighted) M-estimation on the transformed data; this
				# reproduces that exactly using the existing unweighted C++ IRLS kernel.
				sw = sqrt(row_weights)
				Xs = X_fit * sw
				ys = as.numeric(private$y) * sw
				fit_cpp = tryCatch(
					fast_robust_regression_cpp(
						X = Xs,
						y = ys,
						method = private$rlm_method,
						warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
						estimate_only = TRUE
					),
					error = function(e) NULL
				)
				coef_vec = if (!is.null(fit_cpp)) as.numeric(fit_cpp$coefficients) else NULL
				if (!is.null(coef_vec) && length(coef_vec) >= 2L && is.finite(coef_vec[2L])) {
					private$set_fit_warm_start(coef_vec, "beta")
					private$cached_values$beta_hat_T = coef_vec[2L]
					private$cached_values$s_beta_hat_T = NA_real_
					private$cached_values$df = NA_real_
					return(private$cached_values$beta_hat_T)
				}
			}
			warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit))
			fit = tryCatch(
				suppressWarnings(MASS::rlm(
					x = X_fit,
					y = as.numeric(private$y),
					weights = row_weights,
					method = private$rlm_method,
					init = if (is.null(warm_start_beta)) "ls" else warm_start_beta
				)),
				error = function(e) NULL
			)
			if (is.null(fit) || is.null(stats::coef(fit)) || length(stats::coef(fit)) < 2L || !is.finite(stats::coef(fit)[2L])) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			private$set_fit_warm_start(as.numeric(stats::coef(fit)), "beta")
			private$cached_values$beta_hat_T = as.numeric(stats::coef(fit)[2L])
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = NA_real_
			private$cached_values$beta_hat_T
		},
		#' @description Computes a \eqn{1-\alpha} level confidence interval for the
		#'   robust-regression treatment coefficient \eqn{\hat\beta_T}, using the
		#'   M/MM-estimator's asymptotic standard error (see class documentation
		#'   for its source depending on \code{use_rcpp}) and residual degrees of
		#'   freedom \eqn{n - p} in a normal-theory Wald approximation. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
		#'   asymptotic confidence-interval contract this delegates to.
		#' @param alpha The confidence level in the computed confidence
		#'   interval is 1 - \code{alpha}. The default is 0.05.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
			}
			private$shared()
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Computes a two-sided Wald p-value testing \eqn{H_0:
		#'   \beta_T = \code{delta}}, from the same M/MM-estimator standard error
		#'   and residual degrees of freedom used by
		#'   \code{$compute_asymp_confidence_interval()}. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
		#'   asymptotic two-sided p-value contract this delegates to.
		#' @param delta The null difference to test against. Default is zero.
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta)
			}
			private$shared()
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		}
	),
	private = list(
		use_rcpp = TRUE,
		get_complexity_tier = function() "medium",
		get_backend_warm_start_args = function(expected_length, expected_fisher_dim = expected_length) {
			private$get_optimal_warm_start_config(expected_length, expected_fisher_dim)
		},
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			# Ensure we have the best design from the original data
			if (is.null(private$best_X_colnames)){
				private$shared(estimate_only = TRUE)
			}
			# Fallback if initial fit failed
			if (is.null(private$best_X_colnames)){
				return(self$compute_estimate(estimate_only = estimate_only))
			}
			# Use the same design matrix structure as the original fit
			X_cols = private$best_X_colnames
			X_data = private$get_X()
			if (length(X_cols) == 0L){
				# Univariate case
				X_fit = cbind(1, treatment = private$w)
			} else {
				# Multivariate case
				X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
				X_fit = cbind(1, treatment = private$w, X_cov)
			}
			if (private$use_rcpp) {
				fit = private$fit_rlm_model(X_fit, estimate_only = estimate_only, warm_start = TRUE)
				if (is.null(fit)) return(NA_real_)
				return(as.numeric(fit$coefficients[2]))
			} else {
				fit = tryCatch(
					suppressWarnings(MASS::rlm(x = X_fit, y = as.numeric(private$y), method = private$rlm_method, scale.est = "mad", maxit = 20)),
					error = function(e) NULL
				)
				if (is.null(fit) || !is.finite(stats::coef(fit)[2])){
					return(NA_real_)
				}
				return(as.numeric(stats::coef(fit)[2]))
			}
		},
		supports_reusable_bootstrap_worker = function(){
			TRUE
		},
		create_bootstrap_worker_state = function(){
			private$create_design_backed_bootstrap_worker_state()
		},
		load_bootstrap_sample_into_worker = function(worker_state, indices){
			private$load_bootstrap_sample_into_design_backed_worker(worker_state, indices)
		},
		compute_bootstrap_worker_estimate = function(worker_state){
			private$compute_bootstrap_worker_estimate_via_compute_treatment_estimate(worker_state)
		},
		build_design_matrix = function(){
			private$create_design_matrix()
		},
		compute_fast_randomization_distr = function(y, permutations, delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps){
			private$compute_fast_randomization_distr_via_reused_worker(y, permutations, delta, transform_responses, zero_one_logit_clamp = zero_one_logit_clamp)
		},
		get_standard_error = function(){
			private$shared(estimate_only = FALSE)
			private$cached_values$s_beta_hat_T
		},
		get_degrees_of_freedom = function(){
			private$shared(estimate_only = FALSE)
			private$cached_values$df
		},
		set_failed_fit_cache = function(){
			private$cached_values$beta_hat_T = NA_real_
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = NA_real_
		},
		get_ci_fit_controls = function(){
			ctrl = private$randomization_mc_control
			list(
				warm_start = !is.null(ctrl) && isTRUE(ctrl$fit_warm_start_enable),
				reuse_factorizations = !is.null(ctrl) && isTRUE(ctrl$fit_reuse_factorizations)
			)
		},
		fit_rlm_model = function(X_fit, estimate_only = FALSE, warm_start = FALSE){
			ws_args = if (warm_start) private$get_backend_warm_start_args(ncol(X_fit)) else list()
			
			if (private$use_rcpp) {
				tryCatch(
					fast_robust_regression_cpp(
						X = X_fit,
						y = as.numeric(private$y),
						warm_start_beta = ws_args$start_beta,
						smart_cold_start = private$smart_cold_start_default,
						warm_start_fisher_info = ws_args$warm_start_fisher_info,
						method = private$rlm_method,
						j = 2L
					),
					error = function(e) NULL
				)
			} else {
				tryCatch(
					suppressWarnings(MASS::rlm(x = X_fit, y = as.numeric(private$y), method = private$rlm_method, init = ws_args$start_beta)),
					error = function(e) NULL
				)
			}
		},
		shared = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			fit_controls = private$get_ci_fit_controls()
			
			if (is.null(private$best_X_colnames)) {
				X_full = private$build_design_matrix()
				attempt = private$fit_with_hardened_qr_column_dropping(
					X_full = X_full,
					required_cols = match("treatment", colnames(X_full)),
					fit_fun = function(X_fit, keep){
						mod = private$fit_rlm_model(X_fit, estimate_only = estimate_only, warm_start = fit_controls$warm_start)
						if (is.null(mod)) return(NULL)
						mod$j_treat = which(keep == match("treatment", colnames(X_full)))
						mod
					},
					fit_ok = function(mod, X_fit, keep){
						j_treat = mod$j_treat
						beta_hat = as.numeric(if (private$use_rcpp) mod$coefficients else stats::coef(mod))
						if (is.null(mod) || length(beta_hat) < j_treat || !is.finite(beta_hat[j_treat])) return(FALSE)
						if (estimate_only) return(TRUE)
						
						if (private$use_rcpp) {
							se_w = as.numeric(sqrt(mod$ssq_b_j))
						} else {
							st = tryCatch(summary(mod), error = function(e) NULL)
							if (is.null(st)) return(FALSE)
							se_w = as.numeric(st$coefficients[j_treat, "Std. Error"])
						}
						is.finite(se_w) && se_w > 0
					}
				)
				if (is.null(attempt$fit)){
					private$set_failed_fit_cache()
					return(invisible(NULL))
				}
				
				fit = attempt$fit
				X_fit = attempt$X
				j_treat = fit$j_treat
				private$best_X_colnames = setdiff(colnames(X_fit), c("(Intercept)", "treatment"))
				private$set_fit_warm_start(
					as.numeric(if (private$use_rcpp) fit$coefficients else stats::coef(fit)),
					"beta",
					fisher = if (private$use_rcpp) fit$fisher_information else NULL
				)
			} else {
				# Reuse structure
				X_data = private$get_X()
				X_cols = private$best_X_colnames
				if (length(X_cols) == 0L){
					X_fit = cbind(1, treatment = private$w)
				} else {
					X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
					X_fit = cbind(1, treatment = private$w, X_cov)
				}
				j_treat = 2L
				fit = private$fit_rlm_model(X_fit, estimate_only = estimate_only, warm_start = fit_controls$warm_start)
				if (is.null(fit)) {
					private$set_failed_fit_cache()
					return(invisible(NULL))
				}
				private$set_fit_warm_start(
					as.numeric(if (private$use_rcpp) fit$coefficients else stats::coef(fit)),
					"beta",
					fisher = if (private$use_rcpp) fit$fisher_information else NULL
				)
			}
			beta_hat = as.numeric(if (private$use_rcpp) fit$coefficients else stats::coef(fit))
			private$cached_values$beta_hat_T = beta_hat[j_treat]
			if (estimate_only) return(invisible(NULL))
			if (private$use_rcpp) {
				private$cached_values$s_beta_hat_T = as.numeric(sqrt(fit$ssq_b_j))
			} else {
				st = summary(fit)
				private$cached_values$s_beta_hat_T = as.numeric(st$coefficients[j_treat, "Std. Error"])
			}
			private$cached_values$df = nrow(X_fit) - ncol(X_fit)
		},
		compute_fast_rand_bootstrap_distr = function(y0_full, rand_bootstrap_draws, delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps){
			if (!is.null(private[["custom_randomization_statistic_function"]]) || !is.null(private[["compiled_cpp_stat_fn"]])) return(NULL)
			mats = private$rand_bootstrap_draw_matrices(rand_bootstrap_draws)
			if (is.null(mats)) return(NULL)
			X_data = private$get_X()
			Xc = if (!is.null(private$best_X_colnames) && length(private$best_X_colnames) > 0L) {
				cols = intersect(private$best_X_colnames, colnames(X_data))
				if (length(cols) > 0L) as.matrix(X_data[, cols, drop = FALSE]) else matrix(numeric(0), nrow = private$n, ncol = 0L)
			} else if (!is.null(X_data) && ncol(as.matrix(X_data)) > 0L) {
				as.matrix(X_data)
			} else {
				matrix(numeric(0), nrow = private$n, ncol = 0L)
			}
			compute_robust_rand_bootstrap_parallel_cpp(
				as.numeric(y0_full), Xc, mats$i_mat, mats$w_mat,
				as.numeric(delta), private$rlm_method, mats$noise_mat, private$n_cpp_threads(ncol(mats$w_mat))
			)
		}
	),
	overrides = list(
		public = c(
			"compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"compute_rand_two_sided_pval"
		),
		private = c(
			"get_standard_error", "get_degrees_of_freedom",
			"supports_reusable_bootstrap_worker", "create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker", "compute_bootstrap_worker_estimate",
			"compute_fast_randomization_distr",
			"compute_treatment_estimate_during_randomization_inference",
			"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported", "get_complexity_tier"
		)
	),
	metadata = list(likelihood_tier = "quasi")
)
