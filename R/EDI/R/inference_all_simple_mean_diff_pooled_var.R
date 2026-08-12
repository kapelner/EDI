#' Simple Mean Difference Inference with Pooled Variance
#'
#' Unadjusted mean-difference inference using the simple treated-minus-control
#' difference with pooled equal-variance t inference. Note that warm starts are
#' disabled for this class as the simple mean difference is a closed-form
#' estimator and does not benefit from initialization.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'continuous')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rnorm(10))
#' inf = InferenceAllSimpleMeanDiffPooledVar$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
SimpleMeanDifferencePooledVarSource = list(
	public = list(
		#' @description Initialize simple pooled-variance mean-difference inference
		#'   for continuous responses and prepare the pooled standard-error
		#'   calculation used by
		#'   \code{\link[EDI:InferenceAllSimpleMeanDiffPooledVar]{InferenceAllSimpleMeanDiffPooledVar}}.
		#' @param des_obj A completed design object.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values.
		#' @return A new \code{InferenceAllSimpleMeanDiffPooledVar} object.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL){
			super$initialize(
				des_obj = des_obj,
				verbose = verbose,
				harden = TRUE,
				model_formula = model_formula,
				smart_cold_start_default = smart_cold_start_default
			)
			private$fit_warm_start_enabled = FALSE
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Uses the shared asymptotic confidence-interval contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param alpha Confidence level.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
			}
			pooled_stats = private$compute_direct_pooled_t_components()
			if (!is.finite(pooled_stats$estimate) || !is.finite(pooled_stats$se) || pooled_stats$se <= 0) return(c(NA_real_, NA_real_))
			critical_val = stats::qt(1 - alpha / 2, df = pooled_stats$df)
			ci = c(pooled_stats$estimate - critical_val * pooled_stats$se, pooled_stats$estimate + critical_val * pooled_stats$se)
			names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
			ci
		},
		#' @description Uses the shared asymptotic two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param delta Null treatment effect value.
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta)
			}
			pooled_stats = private$compute_direct_pooled_t_components()
			if (!is.finite(pooled_stats$estimate) || !is.finite(pooled_stats$se) || pooled_stats$se <= 0) return(NA_real_)
			t_stat = (pooled_stats$estimate - delta) / pooled_stats$se
			2 * stats::pt(-abs(t_stat), df = pooled_stats$df)
		}
	),
	private = list(
		get_standard_error = function(){
			if (is.null(private$cached_values$simple_mean_diff_pooled_se)) {
				private$compute_simple_mean_diff_pooled_components()
			}
			private$cached_values$simple_mean_diff_pooled_se
		},
		get_degrees_of_freedom = function(){
			if (is.null(private$cached_values$simple_mean_diff_pooled_df)) {
				private$compute_simple_mean_diff_pooled_components()
			}
			private$cached_values$simple_mean_diff_pooled_df
		},
		compute_simple_mean_diff_pooled_components = function(){
			private$compute_direct_pooled_t_components()
			invisible(NULL)
		},
		compute_direct_pooled_t_components = function(){
			if (!is.null(private$cached_values$simple_mean_diff_pooled_t_components)) {
				return(private$cached_values$simple_mean_diff_pooled_t_components)
			}
			if (is.null(private$cached_values$beta_hat_T)) {
				self$compute_estimate()
			}
			y_t = private$cached_values$yTs
			y_c = private$cached_values$yCs
			n_t = length(y_t)
			n_c = length(y_c)
			if (n_t <= 1L || n_c <= 1L) {
				private$cached_values$simple_mean_diff_pooled_se = NA_real_
				private$cached_values$simple_mean_diff_pooled_df = NA_real_
				out = list(estimate = NA_real_, se = NA_real_, df = NA_real_)
				private$cached_values$simple_mean_diff_pooled_t_components = out
				return(out)
			}
			s2_t = stats::var(y_t)
			s2_c = stats::var(y_c)
			df = n_t + n_c - 2L
			s2_pooled = ((n_t - 1L) * s2_t + (n_c - 1L) * s2_c) / df
			var_hat = s2_pooled * (1 / n_t + 1 / n_c)
			se = if (is.finite(var_hat) && var_hat >= 0) sqrt(var_hat) else NA_real_
			df = if (is.finite(var_hat) && is.finite(df) && df > 0) as.numeric(df) else NA_real_
			out = list(
				estimate = private$cached_values$beta_hat_T,
				se = se,
				df = df
			)
			private$cached_values$simple_mean_diff_pooled_se = se
			private$cached_values$simple_mean_diff_pooled_df = df
			private$cached_values$simple_mean_diff_pooled_t_components = out
			out
		}
	)
)

InferenceAllSimpleMeanDiffPooledVar = define_inference_class(
	classname = "InferenceAllSimpleMeanDiffPooledVar",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald", "SimpleMeanDifferencePooledVar"),
	public = list(
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	),
	metadata = list(likelihood_tier = "none"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"initialize",
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval"
		),
		private = c(
			"compute_treatment_estimate_during_randomization_inference",
			"get_standard_error",
			"get_degrees_of_freedom",
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl",
			"compute_brt_null_statistics_with_se"
		)
	)
)
