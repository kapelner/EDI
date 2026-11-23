#' Wald Incidence Inference
#'
#' Unadjusted incidence inference using the empirical risk difference
#' \eqn{\hat\theta = \bar Y_T - \bar Y_C} (sample proportions in the treatment
#' and control arms) together with the standard unpooled Wald standard error
#' \eqn{\hat s(\hat\theta) = \sqrt{\bar Y_T(1-\bar Y_T)/n_T +
#' \bar Y_C(1-\bar Y_C)/n_C}} and normal-approximation confidence interval /
#' hypothesis test \eqn{\hat\theta \pm z_{1-\alpha/2}\,\hat s(\hat\theta)}. This
#' is the classical two-proportion Wald interval (e.g. Wald 1943; see
#' \code{\link[EDI:InferenceIncidNewcombeRiskDiff]{InferenceIncidNewcombeRiskDiff}}
#' for a small-sample-robust alternative). \code{likelihood_tier = "none"}: no
#' likelihood is fit, so no likelihood-ratio or parametric-bootstrap methods are
#' exposed; covariates and any matching structure are ignored, unlike
#' \code{\link[EDI:InferenceIncidRiskDiff]{InferenceIncidRiskDiff}}'s covariate-
#' adjusted linear-probability model. Non-estimable if either arm has zero
#' subjects.
#'
#' \strong{Small samples.} With unequal allocation (\code{prob_T = 0.2}, about
#' 10 treated subjects at n = 50), the Wald test rejected a true null 10.2\% of
#' the time at a nominal 5\% level (intervals covered 89.8\%). The excess is
#' expected to shrink as n grows. With so few subjects in one arm, use a larger
#' or more balanced sample, or a randomization or bootstrap test. Source: the
#' first calibration campaign (2026-11-09-8c32d060; provisional, 1000 screening
#' replicates per cell, Monte Carlo standard error about 0.007; measured at n =
#' 50 only), \url{https://github.com/kapelner/EDI/tree/calibration-results}.
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
#' @eval rd_small_sample_section("InferenceIncidWald")
#' @export
InferenceIncidWald = define_inference_class(
	classname = "InferenceIncidWald",
	inherit = Inference,
	components = c(
		"RandomizationCI",
		"RandomizationBootstrapCI",
		"BayesianBootstrap",
		"Jackknife",
		"Wald",
		"SimpleMeanDifference"
	),
	public = list(
		# Uses the randomization-CI layer's two-sided p-value contract
		#   (\code{InferenceRandCI}'s version, not \code{InferenceRand}'s): for
		#   incidence responses it does not refuse outright; the default p-value
		#   comes from the randomization draws, and the Zhang exact randomization
		#   test is used only when \code{type = "Zhang"} is passed explicitly
		#   (where applicable). This matches this class's pre-migration
		#   old-ladder behavior of not refusing (it inherited from
		#   \code{InferenceAllSimpleAverageDiff}, whose own pin was already
		#   corrected to \code{InferenceRandCI} -- see that file's identical
		#   rationale). This class independently composes the same components
		#   rather than truly inheriting \code{InferenceAllSimpleAverageDiff}, so it
		#   had its own stale copy of the old \code{InferenceRand} pin, which
		#   silently regressed Zhang dispatch (`compute_rand_two_sided_pval()`
		#   started throwing "Randomization tests are not supported for
		#   incidence" for the same designs the old ladder handled correctly) --
		#   found via \code{test-incid-wald-migration-golden.R}'s
		#   \code{randomization_pval} case going from `"ok"` to `"unsupported"`.
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval,
		# Pins asymptotic CI dispatch to the composed \code{Wald}
		#   component's implementation (\code{InferenceAsymp}), which uses
		#   \code{private$get_standard_error()} (this class's two-proportion
		#   Wald SE) and \code{private$get_degrees_of_freedom()}. Without this
		#   explicit pin, the \code{SimpleMeanDifference} component -- composed
		#   after \code{Wald} in this class's \code{components} list -- silently
		#   wins the assembly-order collision and dispatches its own Welch's
		#   t-test on raw \code{y} instead, making the documented Wald formula
		#   dead code. See class documentation.
		compute_asymp_confidence_interval = InferenceAsymp$public_methods$compute_asymp_confidence_interval,
		# Pins asymptotic p-value dispatch to the composed
		#   \code{Wald} component's implementation; see
		#   \code{$compute_asymp_confidence_interval()} for the rationale.
		compute_asymp_two_sided_pval = InferenceAsymp$public_methods$compute_asymp_two_sided_pval,
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

#' @R6method InferenceIncidWald$compute_rand_two_sided_pval
#' @description Randomization two-sided p-value for the risk difference. For incidence
#'   responses the default p-value comes from the randomization draws; the Zhang exact
#'   randomization test is used only when \code{type = "Zhang"} is passed explicitly
#'   (where applicable).
#' @template randci-compute-rand-two-sided-pval-params
#' @return A two-sided p-value (a single-tail p-value when \code{alternative} is not \code{"two.sided"}).
NULL

#' @R6method InferenceIncidWald$compute_asymp_confidence_interval
#' @description Two-proportion Wald confidence interval for the risk difference,
#'   \eqn{\hat\theta \pm z_{1-\alpha/2}\,\hat s(\hat\theta)}, with the unpooled
#'   standard error given in the class description.
#' @param alpha The confidence level in the computed confidence
#'   interval is 1 - \code{alpha}. The default is 0.05.
#' @return A length-2 numeric vector of lower and upper bounds.
NULL

#' @R6method InferenceIncidWald$compute_asymp_two_sided_pval
#' @description Two-sided Wald test of \eqn{H_0: \theta = \delta}, using the
#'   statistic \eqn{(\hat\theta - \delta) / \hat s(\hat\theta)} referred to the
#'   standard normal distribution.
#' @param delta Null treatment effect value. The default is 0.
#' @return A two-sided p-value.
NULL
