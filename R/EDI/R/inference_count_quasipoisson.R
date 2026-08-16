#' Quasi-Poisson Regression Inference for Count Responses
#'
#' Fits a Poisson log-link mean model, \eqn{\log E[Y_i \mid x_i] =
#' x_i^\top\beta}, for count responses using the treatment indicator and,
#' optionally, all recorded covariates as predictors, via
#' \code{\link{fast_quasipoisson_regression_with_var_cpp}} — see that page for
#' the full model and the Pearson-dispersion-scaled ("quasi-Poisson") variance
#' formula, \eqn{\widehat{\mathrm{Var}}(\hat\beta_k) = \hat\phi\,[(X^\top
#' \hat{W}X)^{-1}]_{kk}}, which corrects standard errors for overdispersion
#' (\eqn{\mathrm{Var}(Y_i) > E[Y_i]}) relative to the strict Poisson assumption
#' without changing the point estimate \eqn{\hat\beta}. This class has no
#' likelihood-ratio/score/gradient testing capability
#' (\code{likelihood_tier = "quasi"}): the dispersion-scaled quasi-likelihood is
#' not a normalized model likelihood, so only Wald inference is available.
#' Rank-deficient covariate columns are dropped automatically before fitting
#' (via \code{private$fit_with_hardened_qr_column_dropping()}).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'count')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rpois(10, 2))
#' inf = InferenceCountQuasiPoisson$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceCountQuasiPoisson = define_inference_class(
	classname = "InferenceCountQuasiPoisson",
	inherit = Inference,
	components = c("CountCompositeLikelihood", "BayesianBootstrap", "Wald"),
	public = list(
		#' @description Uses the shared randomization two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceRand]{InferenceRand}}.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
				
		#' @description Initialize a quasi-Poisson regression inference object for a
		#'   completed design with a count, uncensored response.
		#' @param des_obj A completed \code{Design} object with a count response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose  		Whether to print progress messages.
		#' @param harden  		Whether to apply robustness measures.
		#' @param smart_cold_start_default Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL, harden = TRUE){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "count")
			}
			super$initialize(des_obj, verbose = verbose, harden = harden, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Computes the quasi-Poisson treatment coefficient
		#'   \eqn{\hat\beta_T} via \code{\link{fast_quasipoisson_regression_with_var_cpp}}
		#'   (see class documentation for the full model). Rank-deficient covariate
		#'   columns are dropped before fitting.
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
		#'   path never computes the quasi-Poisson dispersion correction.
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
						error = function(e) NULL
					)
					if (is.null(res)) return(NULL)
					list(b = res$b, XtWX = res$XtWX %||% res$fisher_information, ssq_b_j = NA_real_, j_treat = which(keep == 2L))
				},
				fit_ok = function(mod, X_fit, keep){
					j_treat = mod$j_treat
					!is.null(mod) && length(mod$b) >= j_treat && is.finite(mod$b[j_treat])
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
		#'   quasi-Poisson treatment coefficient \eqn{\hat\beta_T}, using the
		#'   Pearson-dispersion-scaled standard error from
		#'   \code{\link{fast_quasipoisson_regression_with_var_cpp}} (see class
		#'   documentation). See \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}
		#'   for the shared asymptotic confidence-interval contract this delegates to.
		#' @param alpha Confidence level.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Computes a two-sided Wald p-value testing \eqn{H_0:
		#'   \beta_T = \code{delta}}, from the same dispersion-scaled standard
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
			res = tryCatch(fast_poisson_regression_cpp(X = X, y = as.numeric(private$y), estimate_only = TRUE), error = function(e) NULL)
			if (is.null(res) || !is.finite(res$b[2])){
				return(NA_real_)
			}
			as.numeric(res$b[2])
		},
		supports_reusable_bootstrap_worker = function(){
			TRUE
		},
		generate_mod = function(estimate_only = FALSE){
			# Use the common GLM fitting pattern
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = private$build_design_matrix(),
				fit_fun = function(X_fit, keep){
					j_treat = which(keep == 2L)
					ws_args = private$get_backend_warm_start_args(ncol(X_fit))
					if (estimate_only) {
						res = fast_poisson_regression_cpp(
							X = X_fit, y = private$y,
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_weights = ws_args$warm_start_weights,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default,
							estimate_only = TRUE
						)
						list(b = res$b, XtWX = res$XtWX, w = res$w, ssq_b_j = NA_real_, j_treat = j_treat)
					} else {
						res = fast_quasipoisson_regression_with_var_cpp(
							X = X_fit, y = private$y, j = j_treat,
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_weights = ws_args$warm_start_weights,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default
						)
						res$j_treat = j_treat
						res
					}
				},
				fit_ok = function(mod, X_fit, keep){
					j_treat = mod$j_treat
					if (is.null(mod) || length(mod$b) < j_treat || !is.finite(mod$b[j_treat])) return(FALSE)
					if (estimate_only) return(TRUE)
					is.finite(mod$ssq_b_j) && mod$ssq_b_j > 0
				}
			)
			if (!is.null(attempt$fit)){
				private$cached_values$likelihood_test_context = list(
					X = attempt$X,
					j_treat = which(attempt$keep == 2L)
				)
				private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
			} else {
				private$cached_values$likelihood_test_context = NULL
			}
			attempt$fit
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
				"best_X_colnames", "build_design_matrix",
				"compute_treatment_estimate_during_randomization_inference",
				"supports_reusable_bootstrap_worker", "generate_mod",
				"get_standard_error", "get_degrees_of_freedom",
				"get_supported_testing_types_impl",
				"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
				"mark_jackknife_nonestimable_if_block_unsupported",
				"create_bootstrap_worker_state", "load_bootstrap_sample_into_worker",
				"compute_bootstrap_worker_estimate"
			)
		)
	)
