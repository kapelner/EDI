#' Robust (Sandwich-Variance) Poisson Regression Inference for Count Responses
#'
#' Fits the same Poisson log-link mean model as
#' \code{\link[EDI:InferenceCountPoisson]{InferenceCountPoisson}} (point
#' estimate via \code{\link{fast_poisson_regression_cpp}}, maximum likelihood),
#' but computes standard errors via a \strong{Huber-White (Eicker-Huber-White)
#' sandwich} estimator instead of the model-based Poisson Fisher information or
#' the quasi-Poisson dispersion scaling used by
#' \code{\link[EDI:InferenceCountQuasiPoisson]{InferenceCountQuasiPoisson}}:
#' \eqn{\widehat{\mathrm{Var}}(\hat\beta) = B\,M\,B}, with "bread" \eqn{B =
#' (X^\top \hat W X)^{-1}} (the Poisson Fisher information at \eqn{\hat\beta})
#' and "meat" \eqn{M = X^\top \mathrm{diag}((y_i-\hat\mu_i)^2) X} (the empirical
#' score outer product), via \code{robust_sandwich_variance_from_xtwx()}. This
#' is robust to arbitrary mean-variance misspecification (not just
#' proportional overdispersion), at the cost of somewhat higher variance in the
#' SE estimate itself for small samples. This class has no likelihood-ratio/
#' score/gradient testing capability (\code{likelihood_tier = "quasi"}): only
#' Wald inference is available. Rank-deficient covariate columns are dropped
#' automatically before fitting.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'count')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rpois(10, 2))
#' inf = InferenceCountRobustPoisson$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceCountRobustPoisson = define_inference_class(
	classname = "InferenceCountRobustPoisson",
	inherit = Inference,
	components = c("CountCompositeLikelihood", "RobustSandwich", "BayesianBootstrap", "Wald"),
	public = list(
		#' @description Uses the shared randomization two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceRand]{InferenceRand}}.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
				
		#' @description Initialize a robust (sandwich-variance) Poisson regression
		#'   inference object for a completed design with a count, uncensored
		#'   response.
		#' @param des_obj A completed \code{Design} object with a count response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose  		Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart starting values for the optimizer.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "count")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Computes the Poisson treatment coefficient \eqn{\hat\beta_T}
		#'   via \code{\link{fast_poisson_regression_cpp}} (see class documentation
		#'   for the sandwich-variance model). Rank-deficient covariate columns are
		#'   dropped before fitting.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the Poisson-mean-model treatment estimate under
		#'   subject/block bootstrap weights (via
		#'   \code{\link{fast_poisson_regression_weighted_cpp}}), used by the
		#'   Bayesian bootstrap and related weighted-resampling machinery; see
		#'   \code{\link[EDI:InferenceBayesianBootstrap]{InferenceBayesianBootstrap}}.
		#'   Always leaves the standard error and degrees of freedom unavailable
		#'   (\code{NA}) regardless of \code{estimate_only} — this weighted-refit
		#'   path never computes the sandwich variance.
		#' @param subject_or_block_weights Bootstrap weights at the subject or block level.
		#' @param estimate_only Present for interface parity; this method never
		#'   computes variance components regardless of its value.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = private$build_design_matrix(),
				required_cols = 2L,
				fit_fun = function(X_fit, keep){
					res = tryCatch(
						fast_poisson_regression_weighted_cpp(
							X = X_fit,
							y = as.numeric(private$y),
							weights = row_weights,
							warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
							smart_cold_start = private$smart_cold_start_default,
							warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit))
						),
						error = function(e) {
							if (is_edi_control_condition(e)) stop(e)
							NULL
						}
					)
					if (is.null(res)) return(NULL)
					list(b = res$b, XtWX = res$XtWX %||% res$fisher_information, ssq_b_2 = NA_real_)
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
			private$set_fit_warm_start(as.numeric(attempt$fit$b), "beta", fisher = attempt$fit$XtWX)
			private$cached_values$beta_hat_T
		},
		#' @description Computes a \eqn{1-\alpha} level confidence interval for the
		#'   robust Poisson treatment coefficient \eqn{\hat\beta_T}, using the
		#'   Huber-White sandwich standard error (see class documentation). See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
		#'   asymptotic confidence-interval contract this delegates to.
		#' @param alpha Confidence level.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Computes a two-sided Wald p-value testing \eqn{H_0:
		#'   \beta_T = \code{delta}}, from the same Huber-White sandwich standard
		#'   error used by \code{$compute_asymp_confidence_interval()}. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
		#'   asymptotic two-sided p-value contract this delegates to.
		#' @param delta Null treatment effect value.
		compute_asymp_two_sided_pval = function(delta = 0){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
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
						warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X)),
						estimate_only = TRUE
					),
					error = function(e) {
						if (is_edi_control_condition(e)) stop(e)
						NULL
					}
				)

			if (is.null(res) || !is.finite(res$b[2])){
				return(NA_real_)
			}
			private$set_fit_warm_start(res$b, "beta", fisher = res$XtWX)
			as.numeric(res$b[2])
		},
		supports_reusable_bootstrap_worker = function(){
			TRUE
		},
		build_design_matrix = function(){
			private$create_design_matrix()
		},
		fit_count_model_with_var = function(X, estimate_only = FALSE){
			reduced = private$reduce_design_matrix_preserving_treatment_fixed_covariates(X)
			X_fit = reduced$X
			j_treat = reduced$j_treat
			if (is.null(X_fit) || !is.finite(j_treat) || nrow(X_fit) <= ncol(X_fit)){
				return(list(b = rep(NA_real_, ncol(X)), ssq_b_2 = NA_real_, X_fit = X_fit, j_treat = j_treat))
			}
			mod = tryCatch(
				fast_poisson_regression_cpp(
					X = X_fit, y = as.numeric(private$y),
					warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
					smart_cold_start = private$smart_cold_start_default,
					warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit)),
					estimate_only = estimate_only
				),
				error = function(e) {
					if (is_edi_control_condition(e)) stop(e)
					NULL
				}
			)

			if (is.null(mod)){
				return(list(b = rep(NA_real_, ncol(X)), ssq_b_2 = NA_real_, X_fit = X_fit, j_treat = j_treat))
			}
			coef_hat = as.numeric(mod$b)
			if (length(coef_hat) != ncol(X_fit) || any(!is.finite(coef_hat))){
				return(list(b = rep(NA_real_, ncol(X)), ssq_b_2 = NA_real_, X_fit = X_fit, j_treat = j_treat))
			}
			
			b_full = rep(NA_real_, ncol(X))
			b_full[reduced$keep] = coef_hat
			names(b_full) = colnames(X)
			if (estimate_only){
				return(list(b = b_full, ssq_b_2 = NA_real_, X_fit = X_fit, j_treat = j_treat, mod = mod, XtWX = mod$XtWX))
			}
			
			mu_hat = as.numeric(mod$mu)
			resid = as.numeric(private$y) - mu_hat
			ssq_b_j = robust_sandwich_variance_from_xtwx(
				X = X_fit,
				residuals = resid,
				XtWX = mod$XtWX,
				j = j_treat
			)
			list(b = b_full, ssq_b_2 = ssq_b_j, mod = mod, XtWX = mod$XtWX, X_fit = X_fit, j_treat = j_treat)
		},
		generate_mod = function(estimate_only = FALSE){
			model_output = private$fit_count_model_with_var(private$build_design_matrix(), estimate_only = estimate_only)
			if (!is.null(model_output$b)) {
				private$cached_values$likelihood_test_context = list(
					X = model_output$X_fit %||% private$build_design_matrix(),
					j_treat = model_output$j_treat %||% 2L
				)
				private$best_X_colnames = setdiff(colnames(model_output$X_fit), c("(Intercept)", "treatment"))
			} else {
				private$cached_values$likelihood_test_context = NULL
			}
			model_output
		}
		),
		metadata = list(likelihood_tier = "quasi"),
		overrides = list(
			public = c(
				"compute_estimate", "compute_estimate_with_bootstrap_weights",
				"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
				"compute_rand_two_sided_pval"
			),
			private = c(
				"best_X_colnames",
				"compute_treatment_estimate_during_randomization_inference",
				"supports_reusable_bootstrap_worker", "build_design_matrix",
				"fit_count_model_with_var", "generate_mod",
				"get_standard_error", "get_degrees_of_freedom",
				"get_supported_testing_types_impl",
				"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
				"mark_jackknife_nonestimable_if_block_unsupported",
				"create_bootstrap_worker_state", "load_bootstrap_sample_into_worker",
				"compute_bootstrap_worker_estimate"
			)
		)
	)
