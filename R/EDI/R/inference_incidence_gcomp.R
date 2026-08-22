# Generic-`self$`-aliased overrides for the `IncidenceGComputation` component's
# harvested public methods whose bodies call `super$...` (valid under the old
# `InferenceIncidGCompAbstract` R6 inheritance ladder the component was
# harvested from, but not under the shallow `inherit = Inference` hierarchy).
# Shared verbatim by `InferenceIncidGCompRiskDiff` and
# `InferenceIncidGCompRiskRatio` -- the RD/RR branching happens inside these
# bodies via `private$get_estimand_type()`, not via which class composes them.
incidence_gcomp_generic_alias_overrides = list(
	#' @description Uses the shared randomization two-sided p-value contract; see
	#'   \code{\link[EDI:InferenceRand]{InferenceRand}}.
	compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
	#' @description Uses the shared Wald testing-type contract; see
	#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}. `Wald` is not composed
	#'   directly (its private `get_standard_error` clashes with
	#'   `IncidenceGComputation`'s public `get_standard_error`, an R6-forbidden
	#'   same-name-both-slots collision), so only this piece is aliased.
	get_supported_testing_types = InferenceAsymp$public_methods$get_supported_testing_types,
	compute_bootstrap_confidence_interval_generic = InferenceNonParamBootstrap$public_methods$compute_bootstrap_confidence_interval,
	compute_bootstrap_two_sided_pval_generic = InferenceNonParamBootstrap$public_methods$compute_bootstrap_two_sided_pval,
	approximate_bootstrap_distribution_beta_hat_T_generic = InferenceNonParamBootstrap$public_methods$approximate_bootstrap_distribution_beta_hat_T,
	compute_bayesian_bootstrap_two_sided_pval_generic = InferenceBayesianBootstrap$public_methods$compute_bayesian_bootstrap_two_sided_pval,
	compute_bayesian_bootstrap_confidence_interval_generic = InferenceBayesianBootstrap$public_methods$compute_bayesian_bootstrap_confidence_interval,
	compute_jackknife_wald_two_sided_pval_generic = InferenceJackknife$public_methods$compute_jackknife_wald_two_sided_pval,
	compute_jackknife_wald_confidence_interval_generic = InferenceJackknife$public_methods$compute_jackknife_wald_confidence_interval,
	#' @description Uses the shared nonparametric bootstrap distribution contract; see
	#'   \code{\link[EDI:InferenceNonParamBootstrap]{InferenceNonParamBootstrap}}.
	#' @param B  					Number of bootstrap samples.
	#' @param show_progress Whether to show a progress bar.
	#' @param debug         Whether to return diagnostics.
	#' @param bootstrap_type Optional resampling scheme.
	#' @return A numeric vector of bootstrap estimates.
	approximate_bootstrap_distribution_beta_hat_T = function(B = 501, show_progress = TRUE, debug = FALSE, bootstrap_type = NULL){
		self$approximate_bootstrap_distribution_beta_hat_T_generic(B, show_progress, debug, bootstrap_type)
	},
	#' @description Computes a bootstrap confidence interval for the treatment effect.
	#' @param alpha Significance level. Default 0.05.
	#' @param B Number of bootstrap samples.
	#' @param type Bootstrap CI type. See \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
	#' @param na.rm Whether to remove non-finite bootstrap replicates.
	#' @param show_progress Whether to show a progress bar.
	#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
	compute_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L){
		type_resolved = tolower(type %||% "percentile")
		if (identical(private$get_estimand_type(), "RR") && identical(type_resolved, "basic")) {
			return(private$compute_rr_bootstrap_basic_confidence_interval(alpha = alpha, B = B, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples))
		}
		self$compute_bootstrap_confidence_interval_generic(alpha = alpha, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples)
	},
	#' @description Computes a bootstrap two-sided p-value for the treatment effect.
	#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
	#' @param B Number of bootstrap samples.
	#' @param type Bootstrap p-value type. See \code{InferenceNonParamBootstrap$compute_bootstrap_two_sided_pval}.
	#' @param na.rm Whether to remove non-finite bootstrap replicates.
	#' @param show_progress Whether to show a progress bar.
	#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
	compute_bootstrap_two_sided_pval = function(delta = NULL, B = 501, type = "symmetric", na.rm = FALSE, show_progress = TRUE, min_number_usable_samples = 5L){
		if (is.null(delta)){
			delta = private$default_null_value()
		}
		self$compute_bootstrap_two_sided_pval_generic(delta = delta, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples)
	},
	#' @description Computes a Bayesian-bootstrap two-sided p-value for the treatment effect.
	#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
	#' @param B Number of Bayesian-bootstrap samples.
	#' @param type Bayesian-bootstrap p-value type. See \code{InferenceBayesianBootstrap$compute_bayesian_bootstrap_two_sided_pval}.
	#' @param na.rm Whether to remove non-finite bootstrap replicates.
	#' @param show_progress Whether to show a progress bar.
	#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
	#' @param weighting_unit_type Optional resampling unit override.
	compute_bayesian_bootstrap_two_sided_pval = function(delta = NULL, B = 501, type = NULL, na.rm = FALSE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL){
		if (is.null(delta)){
			delta = private$default_null_value()
		}
		self$compute_bayesian_bootstrap_two_sided_pval_generic(delta = delta, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type)
	},
	#' @description Computes a Bayesian-bootstrap confidence interval for the treatment effect.
	#' @param alpha Significance level. Default 0.05.
	#' @param B Number of Bayesian-bootstrap samples.
	#' @param type Bayesian-bootstrap CI type. See \code{InferenceBayesianBootstrap$compute_bayesian_bootstrap_confidence_interval}.
	#' @param na.rm Whether to remove non-finite bootstrap replicates.
	#' @param show_progress Whether to show a progress bar.
	#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
	#' @param weighting_unit_type Optional resampling unit override.
	compute_bayesian_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL){
		type_resolved = tolower(type %||% "percentile")
		if (identical(private$get_estimand_type(), "RR") && type_resolved %in% c("basic", "wald")) {
			return(private$compute_rr_bayesian_bootstrap_log_confidence_interval(alpha = alpha, B = B, type = type_resolved, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type))
		}
		self$compute_bayesian_bootstrap_confidence_interval_generic(alpha = alpha, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type)
	},
	#' @description Computes a jackknife-Wald two-sided p-value for the treatment effect.
	#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
	#' @param unit Deletion unit. Default \code{"auto"}.
	compute_jackknife_wald_two_sided_pval = function(delta = NULL, unit = "auto"){
		if (is.null(delta)){
			delta = private$default_null_value()
		}
		if (identical(private$get_estimand_type(), "RR")) {
			return(private$compute_rr_jackknife_wald_two_sided_pval(delta = delta, unit = unit))
		}
		self$compute_jackknife_wald_two_sided_pval_generic(delta = delta, unit = unit)
	},
	#' @description Computes a jackknife-Wald confidence interval for the treatment effect.
	#' @param alpha Significance level. Default \code{0.05}.
	#' @param unit Deletion unit. Default \code{"auto"}.
	compute_jackknife_wald_confidence_interval = function(alpha = 0.05, unit = "auto"){
		if (identical(private$get_estimand_type(), "RR")) {
			return(private$compute_rr_jackknife_wald_confidence_interval(alpha = alpha, unit = unit))
		}
		self$compute_jackknife_wald_confidence_interval_generic(alpha = alpha, unit = unit)
	}
)

# Reusable-bootstrap-worker wiring, shared by `InferenceIncidGCompRiskDiff`
# and `InferenceIncidGCompRiskRatio`. `gcomp_boot_beta` (the warm-start cache
# `weighted_gcomp_fit()` chains across resampling replicates -- see
# `inference_incidence_gcomp_abstract.R`) only ever does anything useful when
# the SAME worker object is reused across an entire bootstrap run instead of
# being freshly re-cloned per replicate; without this, every replicate starts
# from a cold IRLS fit regardless of `gcomp_boot_beta`'s bookkeeping. `Wald`
# provides exactly this same 4-method pattern for the classes that compose
# it (see `inference_all_abstract_asymp.R`), reusing the same generic,
# component-agnostic worker helpers (`create_design_backed_bootstrap_worker_
# state`/`load_bootstrap_sample_into_design_backed_worker`/
# `compute_bootstrap_worker_estimate_via_compute_treatment_estimate`, all
# provided by the transitively-composed `NonparametricBootstrap` component)
# -- since `Wald` itself can't be composed here (see the `get_standard_error`
# clash note above), these are copied directly rather than aliased.
incidence_gcomp_worker_overrides = list(
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
	}
)

incidence_gcomp_overrides = list(
	public = c(
		"initialize", "compute_estimate", "get_standard_error",
		"compute_estimate_with_bootstrap_weights", "compute_asymp_confidence_interval",
		"compute_asymp_two_sided_pval", "compute_wald_two_sided_pval", "compute_wald_confidence_interval",
		"approximate_bootstrap_distribution_beta_hat_T", "compute_rand_two_sided_pval",
		"get_supported_testing_types", "set_testing_type",
		"compute_bootstrap_confidence_interval", "compute_bootstrap_two_sided_pval",
		"compute_bayesian_bootstrap_two_sided_pval", "compute_bayesian_bootstrap_confidence_interval",
		"compute_jackknife_wald_two_sided_pval", "compute_jackknife_wald_confidence_interval"
	),
	private = c(
		"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
		"mark_jackknife_nonestimable_if_block_unsupported",
		"compute_treatment_estimate_during_randomization_inference",
		"get_supported_testing_types_impl",
		"build_design_matrix", "get_estimand_type",
		"supports_reusable_bootstrap_worker", "create_bootstrap_worker_state",
		"load_bootstrap_sample_into_worker", "compute_bootstrap_worker_estimate"
	)
)

#' G-Computation Risk-Difference Inference for Binary Responses
#'
#' Fits a logistic working model, \eqn{\mathrm{logit}\,\Pr(Y_i=1\mid x_i) =
#' x_i^\top\hat\beta}, for an incidence outcome using treatment and, optionally,
#' all recorded covariates, then estimates the marginal (standardized) risk
#' difference \eqn{\mathrm{RD} = \overline{\mathrm{risk}}_1 -
#' \overline{\mathrm{risk}}_0} by G-computation: setting every subject's
#' treatment indicator to 1 (respectively 0) while holding their other observed
#' covariates fixed, averaging the model-implied risk over the empirical
#' covariate distribution under each counterfactual, and differencing — see
#' \code{\link{gcomp_logistic_point_estimate_cpp}} for the exact standardization
#' formula. Inference is nonparametric-bootstrap/randomization/jackknife-based
#' (\code{likelihood_tier = "none"}): no closed-form asymptotic standard error
#' is used.
#'
#' @seealso \code{\link[EDI:InferenceIncidGCompRiskRatio]{InferenceIncidGCompRiskRatio}}
#'   for the risk-ratio version of this same standardized logistic working model.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidGCompRiskDiff$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceIncidGCompRiskDiff = define_inference_class(
	classname = "InferenceIncidGCompRiskDiff",
	inherit = Inference,
	components = c("BayesianBootstrap", "Jackknife", "IncidenceGComputation"),
	public = incidence_gcomp_generic_alias_overrides,
	private = c(incidence_gcomp_worker_overrides, list(
		get_supported_testing_types_impl = function() "wald",
		build_design_matrix = function(){
			private$create_design_matrix()
		},
		get_estimand_type = function() "RD"
	)),
	overrides = incidence_gcomp_overrides,
	metadata = list(likelihood_tier = "none")
)

#' G-Computation Risk-Ratio Inference for Binary Responses
#'
#' Fits a logistic working model, \eqn{\mathrm{logit}\,\Pr(Y_i=1\mid x_i) =
#' x_i^\top\hat\beta}, for an incidence outcome using treatment and, optionally,
#' all recorded covariates, then estimates the marginal (standardized) risk
#' ratio \eqn{\mathrm{RR} = \overline{\mathrm{risk}}_1 / \overline{\mathrm{risk}}_0}
#' by G-computation: setting every subject's treatment indicator to 1
#' (respectively 0) while holding their other observed covariates fixed,
#' averaging the model-implied risk over the empirical covariate distribution
#' under each counterfactual, and taking the ratio — see
#' \code{\link{gcomp_logistic_point_estimate_cpp}} for the exact standardization
#' formula (\code{mean1}/\code{mean0}). Bootstrap/jackknife inference on this
#' estimand is generally done on the \strong{log} risk-ratio scale internally
#' (see \code{$compute_bootstrap_confidence_interval()},
#' \code{$compute_bayesian_bootstrap_confidence_interval()}, and the
#' jackknife-Wald methods, whose \code{"basic"}/\code{"wald"} interval types
#' route through log-scale-specific helpers for this estimand), then
#' back-transformed, since ratio estimators are typically closer to normally
#' distributed on the log scale. Inference is nonparametric-bootstrap/
#' randomization/jackknife-based (\code{likelihood_tier = "none"}): no
#' closed-form asymptotic standard error is used.
#'
#' @seealso \code{\link[EDI:InferenceIncidGCompRiskDiff]{InferenceIncidGCompRiskDiff}}
#'   for the risk-difference version of this same standardized logistic working model.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidGCompRiskRatio$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceIncidGCompRiskRatio = define_inference_class(
	classname = "InferenceIncidGCompRiskRatio",
	inherit = Inference,
	components = c("BayesianBootstrap", "Jackknife", "IncidenceGComputation"),
	public = incidence_gcomp_generic_alias_overrides,
	private = c(incidence_gcomp_worker_overrides, list(
		get_supported_testing_types_impl = function() "wald",
		build_design_matrix = function(){
			private$create_design_matrix()
		},
		get_estimand_type = function() "RR"
	)),
	overrides = incidence_gcomp_overrides,
	metadata = list(likelihood_tier = "none")
)
