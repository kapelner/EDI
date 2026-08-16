#' Simple Mean-Difference Inference with Pooled Variance
#'
#' Fits the same unadjusted mean-difference point estimate as
#' \code{\link[EDI:InferenceAllSimpleMeanDiff]{InferenceAllSimpleMeanDiff}},
#' \eqn{\hat\beta_T = \bar y_T - \bar y_C}, but performs inference via the
#' classical \strong{pooled equal-variance} Student's t-test instead of
#' Welch's unequal-variance version: pooled variance \eqn{s_p^2 =
#' \left((n_T-1)s_T^2 + (n_C-1)s_C^2\right)/(n_T+n_C-2)}, standard error
#' \eqn{s_p\sqrt{1/n_T + 1/n_C}}, and exact degrees of freedom \eqn{n_T+n_C-2}
#' — see \code{$compute_asymp_confidence_interval()} for the full formula.
#' This assumes the two arms have equal population variance; prefer
#' \code{\link[EDI:InferenceAllSimpleMeanDiff]{InferenceAllSimpleMeanDiff}}
#' when that assumption is doubtful, since the pooled estimator's nominal
#' coverage degrades under heteroskedasticity with unequal arm sizes. This
#' class does not support censored survival data (enforced at construction).
#' This class has no likelihood tier (\code{likelihood_tier = "none"}) and
#' provides asymptotic Wald, randomization, and bootstrap (including Bayesian
#' bootstrap) confidence intervals and p-values. Warm starts are disabled for
#' this class, since the simple mean difference is a closed-form estimator
#' (no iterative fit to warm-start).
#'
#' @references Student [Gosset, W. S.] (1908). "The Probable Error of a Mean."
#'   \emph{Biometrika}, 6(1), 1-25, \doi{10.1093/biomet/6.1.1}, for the
#'   pooled-variance two-sample t-test used here.
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
#' @name InferenceAllSimpleMeanDiffPooledVar
#' @export
SimpleMeanDifferencePooledVarSource = list(
	public = list(
		#' @description Initialize simple pooled-variance mean-difference inference
		#'   for continuous responses and prepare the pooled standard-error
		#'   calculation used by
		#'   \code{\link[EDI:InferenceAllSimpleMeanDiffPooledVar]{InferenceAllSimpleMeanDiffPooledVar}}.
		#'   Disables warm starts (closed-form estimator) and asserts
		#'   \code{des_obj} has no censored observations (unsupported by this
		#'   class).
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
		#' @description Computes a \eqn{1-\alpha} level confidence interval for the
		#'   simple (unadjusted) mean-difference treatment effect
		#'   \eqn{\hat\beta_T = \bar y_T - \bar y_C}, using the classical
		#'   \strong{pooled equal-variance} Student's t-test formula (unlike
		#'   \code{\link[EDI:InferenceAllSimpleMeanDiff]{InferenceAllSimpleMeanDiff}}'s
		#'   Welch unequal-variance version): the pooled variance estimate
		#'   \eqn{s_p^2 = \left((n_T-1)s_T^2 + (n_C-1)s_C^2\right) / (n_T+n_C-2)}
		#'   gives standard error \eqn{\widehat{\mathrm{SE}}(\hat\beta_T) =
		#'   s_p\sqrt{1/n_T + 1/n_C}} with exact degrees of freedom \eqn{n_T + n_C -
		#'   2}; the interval is \eqn{\hat\beta_T \pm t_{\mathrm{df}, 1-\alpha/2}\,
		#'   \widehat{\mathrm{SE}}(\hat\beta_T)}. Assumes equal population
		#'   variances in the two arms — use
		#'   \code{\link[EDI:InferenceAllSimpleMeanDiff]{InferenceAllSimpleMeanDiff}}
		#'   instead when that assumption is doubtful. Requires at least 2
		#'   observations per arm; otherwise returns \code{c(NA, NA)}. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
		#'   asymptotic confidence-interval contract this participates in.
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
		#' @description Computes a two-sided pooled-variance Student's t-test
		#'   p-value testing \eqn{H_0: \beta_T = \code{delta}}, from the same
		#'   pooled standard error and exact \eqn{n_T+n_C-2} degrees of freedom
		#'   used by \code{$compute_asymp_confidence_interval()} — see that
		#'   method's documentation for the full formula. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
		#'   asymptotic two-sided p-value contract this participates in.
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
