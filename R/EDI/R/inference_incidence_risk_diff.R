#' Risk Difference Inference for Incidence Responses
#'
#' Fits a linear probability model via OLS for binary (incidence) responses using
#' the treatment indicator and, optionally, all recorded covariates as
#' predictors. The treatment effect is reported as a risk difference.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidRiskDiff$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceIncidRiskDiff = define_inference_class(
	classname = "InferenceIncidRiskDiff",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald"),
	public = list(
		#' @description Uses the randomization-CI layer's two-sided p-value contract
		#'   (\code{InferenceRandCI}'s version, not
		#'   \code{InferenceRand}'s): for incidence responses it dispatches to the
		#'   Zhang exact randomization test rather than refusing outright, matching
		#'   this class's pre-migration old-ladder behavior. This deliberately
		#'   differs from the \code{InferenceAllSimpleMeanDiff}-family precedent of
		#'   pinning \code{InferenceRand}'s version, which would have regressed the
		#'   working Zhang dispatch this class had on the old ladder.
		#' @param r Number of randomization vectors. @param delta Null difference.
		#' @param transform_responses Transformation. @param na.rm Remove NAs.
		#' @param show_progress Show progress. @param permutations Pre-computed permutations.
		#' @param type Optional exact-inference type for incidence dispatch.
		#' @param args_for_type Optional arguments for \code{type}.
		#' @param zero_one_logit_clamp Clamp for exact 0/1 values when logging.
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize a risk-difference inference object.
		#' @param des_obj A completed \code{Design} object with an incidence response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose  		Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Computes the class-specific treatment-effect estimate; see
		#'   \code{\link[EDI:Inference]{Inference}}.
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			if (estimate_only) {
				if (!is.null(private$cached_values$beta_hat_T)) return(private$cached_values$beta_hat_T)
				if (isFALSE(private$harden)) {
					X = private$build_design_matrix()
					fit = stats::lm.fit(x = X, y = as.numeric(private$y))
					b = stats::coef(fit)
					j = 2L
					private$cached_values$beta_hat_T = if (length(b) >= j && is.finite(b[j])) {
						private$best_X_colnames = setdiff(colnames(X), c("(Intercept)", "treatment"))
						as.numeric(b[j])
					} else NA_real_
					return(private$cached_values$beta_hat_T)
				}
			}
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
		#' @description Recomputes the class-specific treatment estimate for a bootstrap sample; see
		#'   \code{\link[EDI:InferenceNonParamBootstrap]{InferenceNonParamBootstrap}}.
		#' @param subject_or_block_weights Row weights for the bootstrap sample.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				fit_fun = function(X_fit, keep){
					w_fit = row_weights
					ok = is.finite(w_fit) & w_fit > 0 & is.finite(private$y)
					if (sum(ok) <= ncol(X_fit)) return(NULL)
					stats::lm.wfit(
						x = X_fit[ok, , drop = FALSE],
						y = as.numeric(private$y[ok]),
						w = as.numeric(w_fit[ok])
					)
				},
				fit_ok = function(mod, X_fit, keep){
					j_treat = which(keep == 2L)
					!is.null(mod) &&
						is.finite(j_treat) &&
						length(mod$coefficients) >= j_treat &&
						is.finite(mod$coefficients[j_treat])
				}
			)
			if (is.null(attempt$fit)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				return(NA_real_)
			}
			j_treat = which(attempt$keep == 2L)
			private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
			private$cached_values$beta_hat_T = as.numeric(attempt$fit$coefficients[j_treat])
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$beta_hat_T
		}
	),
	private = list(
		supports_likelihood_tests = function(){ FALSE },
		supports_lik_ratio_param_bootstrap = function(){ FALSE },
		# Absorbed (verbatim, minus likelihood-only branches) from
		# StandardModelCacheSource when this class migrated off the old
		# InferenceAsympLikStdModCacheNoParamBootstrap ladder: this class is
		# likelihood_tier "none" (its OLS linear-probability objective is a
		# misspecified Gaussian working model for binary y, hence
		# supports_likelihood_tests = FALSE above), so it cannot compose the
		# StandardModelCache component (whose standard_model_cache capability
		# requires likelihood_tests, tier >= quasi). The likelihood-free subset
		# it actually uses -- the shared() model-cache state machine, the
		# cached-SE/df getters, and the design-backed bootstrap-worker
		# delegation -- is small enough to own here directly. get_standard_
		# error() drops the source's information-matrix-preference branch: that
		# branch is gated on supports_information_preference(), which delegates
		# to supports_likelihood_tests() and therefore never fired for this
		# class on the old ladder either.
		shared = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			has_cached_se = !is.null(private$cached_values$s_beta_hat_T) &&
				length(private$cached_values$s_beta_hat_T) == 1L &&
				isTRUE(is.finite(private$cached_values$s_beta_hat_T))
			if (isTRUE(!is.null(private$cached_values$beta_hat_T) && (estimate_only || has_cached_se))) return(invisible(NULL))
			model_output = private$generate_mod(estimate_only = estimate_only)
			private$cached_mod = model_output
			if (is.null(model_output)) {
				private$cache_nonestimable_estimate("model_fit_unavailable")
				private$cached_values$df = NA_real_
				return(invisible(NULL))
			}
			beta_hat_T = as.numeric(model_output$beta_hat_T %||% model_output$b[2])[1L]
			if (!is.finite(beta_hat_T)) {
				private$cache_nonestimable_estimate("model_treatment_estimate_unavailable")
				private$cached_values$df = NA_real_
				return(invisible(NULL))
			}
			private$cached_values$beta_hat_T = beta_hat_T
			if (!is.null(model_output$b)) {
				private$set_fit_warm_start(
					as.numeric(model_output$params %||% model_output$b),
					type = if (!is.null(model_output$params)) "params" else "beta",
					fisher = model_output$fisher_information %||% model_output$XtWX,
					weights = model_output$w %||% model_output$mu,
					force_pd = TRUE
				)
			}
			if (estimate_only) return(invisible(NULL))
			ssq = model_output$ssq_b_2 %||% model_output$ssq_b_j
			ssq = if (length(ssq) >= 1L) as.numeric(ssq)[1L] else NA_real_
			private$cached_values$df = model_output$df %||% NA_real_
			if (is.finite(ssq) && ssq > 0) {
				private$cached_values$s_beta_hat_T = sqrt(ssq)
				private$clear_nonestimable_state()
			} else {
				private$cache_nonestimable_se("model_standard_error_unavailable")
			}
		},
		get_standard_error = function(){
			private$shared(estimate_only = FALSE)
			private$cached_values$s_beta_hat_T
		},
		get_degrees_of_freedom = function(){
			private$shared(estimate_only = FALSE)
			private$cached_values$df
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
			res = tryCatch(fast_ols_cpp(X = X, y = as.numeric(private$y)), error = function(e) NULL)
			if (is.null(res) || !is.finite(res$b[2])){
				return(NA_real_)
			}
			as.numeric(res$b[2])
		},
		supports_reusable_bootstrap_worker = function(){
			TRUE
		},
		get_supported_testing_types_impl = function(){
			"wald"
		},
		generate_mod = function(estimate_only = FALSE){
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = private$build_design_matrix(),
				fit_fun = function(X_fit, keep){
					j_treat = which(keep == 2L)
					if (estimate_only) {
						res = stats::lm.fit(x = X_fit, y = as.numeric(private$y))
						b = as.numeric(stats::coef(res))
						list(b = b, beta_hat_T = as.numeric(b[j_treat]), ssq_b_j = NA_real_, j_treat = j_treat)
					} else {
						res = fast_ols_with_var_cpp(X = X_fit, y = private$y, j = j_treat)
						res$j_treat = j_treat
						res$beta_hat_T = as.numeric(res$b[j_treat])
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
				private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
			}
			attempt$fit
		}
	),
	overrides = list(
		public = c(
			"compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"compute_rand_two_sided_pval"
		),
		private = c(
			"compute_treatment_estimate_during_randomization_inference",
			"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker", "create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker", "compute_bootstrap_worker_estimate",
			"get_standard_error", "get_degrees_of_freedom",
			"supports_likelihood_tests", "supports_lik_ratio_param_bootstrap",
			"get_supported_testing_types_impl"
		)
	),
	metadata = list(likelihood_tier = "none")
)
