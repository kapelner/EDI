#' Wald Incidence Inference
#'
#' Unadjusted incidence inference using the empirical risk difference together
#' with the standard unpooled Wald standard error and normal-approximation
#' confidence interval / hypothesis test.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidWald$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceIncidWald = define_inference_class(
	classname = "InferenceIncidWald",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald", "SimpleMeanDifference"),
	public = list(
		#' @description Uses the randomization-CI layer's two-sided p-value contract
		#'   (\code{InferenceRandCI}'s version, not \code{InferenceRand}'s): for
		#'   incidence responses this dispatches to the Zhang exact randomization
		#'   test where applicable rather than refusing outright, matching this
		#'   class's pre-migration old-ladder behavior (it inherited from
		#'   \code{InferenceAllSimpleMeanDiff}, whose own pin was already
		#'   corrected to \code{InferenceRandCI} -- see that file's identical
		#'   rationale). This class independently composes the same components
		#'   rather than truly inheriting \code{InferenceAllSimpleMeanDiff}, so it
		#'   had its own stale copy of the old \code{InferenceRand} pin, which
		#'   silently regressed Zhang dispatch (`compute_rand_two_sided_pval()`
		#'   started throwing "Randomization tests are not supported for
		#'   incidence" for the same designs the old ladder handled correctly) --
		#'   found via \code{test-incid-wald-migration-golden.R}'s
		#'   \code{randomization_pval} case going from `"ok"` to `"unsupported"`.
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize Wald risk-difference incidence inference and
		#'   prepare the treatment/control binomial summaries used by
		#'   \code{\link[EDI:InferenceIncidWald]{InferenceIncidWald}} and related
		#'   \code{\link[EDI:InferenceIncidRiskDiff]{InferenceIncidRiskDiff}}
		#'   methods.
		#' @param des_obj A completed design object.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @return A new \code{InferenceIncidWald} object.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		}
	),
	private = list(
		get_standard_error = function(){
			if (is.null(private$cached_values$incidence_wald_se)) {
				private$compute_incidence_wald_components()
			}
			private$cached_values$incidence_wald_se
		},
		get_degrees_of_freedom = function(){
			NA_real_
		},
		compute_incidence_wald_components = function(){
			if (is.null(private$cached_values$beta_hat_T)) {
				self$compute_estimate()
			}
			y_t = private$cached_values$yTs
			y_c = private$cached_values$yCs
			n_t = length(y_t)
			n_c = length(y_c)
			if (n_t == 0L || n_c == 0L) {
				private$cached_values$incidence_wald_se = NA_real_
				return(invisible(NULL))
			}
			p_t = mean(y_t)
			p_c = mean(y_c)
			var_hat = p_t * (1 - p_t) / n_t + p_c * (1 - p_c) / n_c
			private$cached_values$incidence_wald_se =
				if (is.finite(var_hat) && var_hat >= 0) sqrt(var_hat) else NA_real_
			invisible(NULL)
		}
	),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"initialize"
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
			"compute_fast_bootstrap_distr",
			"compute_fast_randomization_distr",
			"compute_fast_rand_bootstrap_distr",
			"compute_rand_bootstrap_ci_affine_coefs",
			"shared",
			"supports_lik_ratio_param_bootstrap",
			"supports_likelihood_tests",
			"get_supported_testing_types_impl",
			"simulate_under_lik_null",
			"compute_brt_null_statistics_with_se",
			"get_likelihood_test_spec"
		)
	)
)
