# Generic-`self$`-aliased overrides for the `IncidenceGComputation` component's
# harvested public methods whose bodies call `super$...` (valid under the old
# `InferenceIncidGCompAbstract` R6 inheritance ladder the component was
# harvested from, but not under the shallow `inherit = Inference` hierarchy).
# Shared verbatim by `InferenceIncidGCompRiskDiff` and
# `InferenceIncidGCompRiskRatio` -- the RD/RR branching happens inside these
# bodies via `private$get_estimand_type()`, not via which class composes them.
#' Generic aliased overrides for the incidence g-computation component
#'
#' Shared \code{self$}-aliased public overrides for methods of the \code{IncidenceGComputation} component whose bodies call \code{super$...}; composed by \code{InferenceIncidGCompRiskDiff} and \code{InferenceIncidGCompRiskRatio}.
#'
#' @keywords internal
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
	compute_subsampling_two_sided_pval_generic = InferenceNonParamBootstrap$public_methods$compute_subsampling_two_sided_pval,
	compute_subsampling_confidence_interval_generic = InferenceNonParamBootstrap$public_methods$compute_subsampling_confidence_interval,
	compute_m_out_of_n_bootstrap_two_sided_pval_generic = InferenceNonParamBootstrap$public_methods$compute_m_out_of_n_bootstrap_two_sided_pval,
	compute_m_out_of_n_bootstrap_confidence_interval_generic = InferenceNonParamBootstrap$public_methods$compute_m_out_of_n_bootstrap_confidence_interval,
	compute_bayesian_bootstrap_two_sided_pval_generic = InferenceBayesianBootstrap$public_methods$compute_bayesian_bootstrap_two_sided_pval,
	compute_bayesian_bootstrap_confidence_interval_generic = InferenceBayesianBootstrap$public_methods$compute_bayesian_bootstrap_confidence_interval,
	compute_jackknife_wald_two_sided_pval_generic = InferenceJackknife$public_methods$compute_jackknife_wald_two_sided_pval,
	compute_jackknife_wald_confidence_interval_generic = InferenceJackknife$public_methods$compute_jackknife_wald_confidence_interval,
	# Uses the shared nonparametric bootstrap distribution contract; see
	# InferenceNonParamBootstrap. Documented via @R6method (see
	# gcomp-bootstrap-distribution-beta-hat-t template).
	approximate_bootstrap_distribution_beta_hat_T = function(B = 501, show_progress = TRUE, debug = FALSE, bootstrap_type = NULL){
		self$approximate_bootstrap_distribution_beta_hat_T_generic(B, show_progress, debug, bootstrap_type)
	},
	# Computes a bootstrap confidence interval for the treatment effect.
	# Documented via @R6method (see gcomp-bootstrap-confidence-interval template).
	compute_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L){
		type_resolved = tolower(type %||% "percentile")
		if (identical(private$get_estimand_type(), "RR") && identical(type_resolved, "basic")) {
			return(private$compute_rr_bootstrap_basic_confidence_interval(alpha = alpha, B = B, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples))
		}
		self$compute_bootstrap_confidence_interval_generic(alpha = alpha, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples)
	},
	# Computes a bootstrap two-sided p-value for the treatment effect.
	# Documented via @R6method (see gcomp-bootstrap-two-sided-pval template).
	compute_bootstrap_two_sided_pval = function(delta = NULL, B = 501, type = "symmetric", na.rm = FALSE, show_progress = TRUE, min_number_usable_samples = 5L, min_fraction_usable_samples = 0.95){
		if (is.null(delta)){
			delta = private$default_null_value()
		}
		self$compute_bootstrap_two_sided_pval_generic(delta = delta, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, min_fraction_usable_samples = min_fraction_usable_samples)
	},
	# Computes a Bayesian-bootstrap two-sided p-value for the treatment effect.
	# Documented via @R6method (see gcomp-bayesian-bootstrap-two-sided-pval template).
	compute_bayesian_bootstrap_two_sided_pval = function(delta = NULL, B = 501, type = NULL, na.rm = FALSE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL, min_fraction_usable_samples = 0.95){
		if (is.null(delta)){
			delta = private$default_null_value()
		}
		self$compute_bayesian_bootstrap_two_sided_pval_generic(delta = delta, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type, min_fraction_usable_samples = min_fraction_usable_samples)
	},
	# Computes a Bayesian-bootstrap confidence interval for the treatment effect.
	# Documented via @R6method (see gcomp-bayesian-bootstrap-confidence-interval template).
	compute_bayesian_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL){
		type_resolved = tolower(type %||% "percentile")
		# v1.0.6-TODO-168 (a): symmetric studentized interval on log(RR) (RR classes only).
		if (identical(private$get_estimand_type(), "RR") && identical(type_resolved, "symmetric-percentile-t")) {
			return(edi_rr_bayesian_bootstrap_symmetric_studentized_ci(self, private, alpha = alpha, B = B, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type))
		}
		if (identical(private$get_estimand_type(), "RR") && type_resolved %in% c("basic", "wald")) {
			return(private$compute_rr_bayesian_bootstrap_log_confidence_interval(alpha = alpha, B = B, type = type_resolved, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type))
		}
		self$compute_bayesian_bootstrap_confidence_interval_generic(alpha = alpha, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type)
	},
	# Computes a jackknife-Wald two-sided p-value for the treatment effect.
	# Documented via @R6method (see gcomp-jackknife-wald-two-sided-pval template).
	compute_jackknife_wald_two_sided_pval = function(delta = NULL, unit = "auto"){
		if (is.null(delta)){
			delta = private$default_null_value()
		}
		if (identical(private$get_estimand_type(), "RR")) {
			return(private$compute_rr_jackknife_wald_two_sided_pval(delta = delta, unit = unit))
		}
		self$compute_jackknife_wald_two_sided_pval_generic(delta = delta, unit = unit)
	},
	# Computes a jackknife-Wald confidence interval for the treatment effect.
	# Documented via @R6method (see gcomp-jackknife-wald-confidence-interval template).
	compute_jackknife_wald_confidence_interval = function(alpha = 0.05, unit = "auto"){
		if (identical(private$get_estimand_type(), "RR")) {
			return(private$compute_rr_jackknife_wald_confidence_interval(alpha = alpha, unit = unit))
		}
		self$compute_jackknife_wald_confidence_interval_generic(alpha = alpha, unit = unit)
	},
	# Computes a PRW subsampling two-sided p-value for the treatment effect.
	# Documented via @R6method (see gcomp-subsampling-two-sided-pval template).
	compute_subsampling_two_sided_pval = function(delta = NULL, B = 501, b = NULL, type = "centered", show_progress = TRUE, min_number_usable_samples = 5L, subsampling_type = NULL, min_fraction_usable_samples = 0.95){
		# v1.0.6-TODO-191: risk ratio only (the risk difference ignores it).
		if (should_run_asserts()) assert_min_fraction_usable_samples(min_fraction_usable_samples)
		if (is.null(delta)){
			delta = private$default_null_value()
		}
		if (identical(private$get_estimand_type(), "RR")) {
			return(private$compute_rr_subsampling_two_sided_pval(delta = delta, B = B, b = b, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, subsampling_type = subsampling_type, min_fraction_usable_samples = min_fraction_usable_samples))
		}
		self$compute_subsampling_two_sided_pval_generic(delta = delta, B = B, b = b, type = type, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, subsampling_type = subsampling_type)
	},
	# Computes a PRW subsampling confidence interval for the treatment effect.
	# Documented via @R6method (see gcomp-subsampling-confidence-interval template).
	compute_subsampling_confidence_interval = function(alpha = 0.05, B = 501, b = NULL, type = "basic", show_progress = TRUE, min_number_usable_samples = 5L, subsampling_type = NULL, min_fraction_usable_samples = 0.95){
		# v1.0.6-TODO-191: risk ratio only (the risk difference ignores it).
		if (should_run_asserts()) assert_min_fraction_usable_samples(min_fraction_usable_samples)
		if (identical(private$get_estimand_type(), "RR")) {
			return(private$compute_rr_subsampling_confidence_interval(alpha = alpha, B = B, b = b, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, subsampling_type = subsampling_type, min_fraction_usable_samples = min_fraction_usable_samples))
		}
		self$compute_subsampling_confidence_interval_generic(alpha = alpha, B = B, b = b, type = type, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, subsampling_type = subsampling_type)
	},
	# Computes an m-out-of-n bootstrap two-sided p-value for the treatment effect.
	# Documented via @R6method (see gcomp-m-out-of-n-bootstrap-two-sided-pval template).
	compute_m_out_of_n_bootstrap_two_sided_pval = function(delta = NULL, B = 501, m = NULL, type = "centered", show_progress = TRUE, min_number_usable_samples = 5L, bootstrap_type = NULL, min_fraction_usable_samples = 0.95){
		# v1.0.6-TODO-191: risk ratio only (the risk difference ignores it).
		if (should_run_asserts()) assert_min_fraction_usable_samples(min_fraction_usable_samples)
		if (is.null(delta)){
			delta = private$default_null_value()
		}
		if (identical(private$get_estimand_type(), "RR")) {
			return(private$compute_rr_m_out_of_n_bootstrap_two_sided_pval(delta = delta, B = B, m = m, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, bootstrap_type = bootstrap_type, min_fraction_usable_samples = min_fraction_usable_samples))
		}
		self$compute_m_out_of_n_bootstrap_two_sided_pval_generic(delta = delta, B = B, m = m, type = type, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, bootstrap_type = bootstrap_type)
	},
	# Computes an m-out-of-n bootstrap confidence interval for the treatment effect.
	# Documented via @R6method (see gcomp-m-out-of-n-bootstrap-confidence-interval template).
	compute_m_out_of_n_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, m = NULL, type = "basic", show_progress = TRUE, min_number_usable_samples = 5L, bootstrap_type = NULL, min_fraction_usable_samples = 0.95){
		# v1.0.6-TODO-191: risk ratio only (the risk difference ignores it).
		if (should_run_asserts()) assert_min_fraction_usable_samples(min_fraction_usable_samples)
		if (identical(private$get_estimand_type(), "RR")) {
			return(private$compute_rr_m_out_of_n_bootstrap_confidence_interval(alpha = alpha, B = B, m = m, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, bootstrap_type = bootstrap_type, min_fraction_usable_samples = min_fraction_usable_samples))
		}
		self$compute_m_out_of_n_bootstrap_confidence_interval_generic(alpha = alpha, B = B, m = m, type = type, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, bootstrap_type = bootstrap_type)
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
	# v1.0.6-TODO-191: marks degenerate risk-ratio subsampling / m-out-of-n draws as unusable.
	compute_bootstrap_worker_estimate = function(worker_state){
		gcomp_bootstrap_worker_estimate(private, worker_state)
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
		"compute_jackknife_wald_two_sided_pval", "compute_jackknife_wald_confidence_interval",
		"compute_subsampling_two_sided_pval", "compute_subsampling_confidence_interval",
		"compute_m_out_of_n_bootstrap_two_sided_pval", "compute_m_out_of_n_bootstrap_confidence_interval"
	),
	private = c(
		"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
		"mark_jackknife_nonestimable_if_block_unsupported",
		"compute_treatment_estimate_during_randomization_inference",
		"get_supported_testing_types_impl",
		"build_design_matrix", "get_estimand_type",
		"supports_reusable_bootstrap_worker", "create_bootstrap_worker_state",
		"load_bootstrap_sample_into_worker", "compute_bootstrap_worker_estimate",
		"compute_rr_resampling_pivot",
		"compute_rr_subsampling_two_sided_pval", "compute_rr_subsampling_confidence_interval",
		"compute_rr_m_out_of_n_bootstrap_two_sided_pval", "compute_rr_m_out_of_n_bootstrap_confidence_interval"
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
#' formula. Wald inference uses the fitted logistic model's sandwich covariance
#' and the delta method.  This standard error conditions on the observed
#' covariates used for standardization: it quantifies uncertainty in the
#' fitted coefficients for the sample-conditional standardized risk
#' difference, and does not add sampling variability from a target population's
#' covariate distribution.  Bootstrap, randomization, and jackknife methods
#' remain available.  \code{likelihood_tier = "none"} means that this class
#' does not provide likelihood-ratio or score tests; it does not preclude its
#' Wald inference.
#'
#' \strong{Small samples.} With unequal allocation (\code{prob_T = 0.2}, about
#' 10 treated subjects at n = 50), the Wald test of the risk difference rejected
#' a true null 12.3\% of the time at a nominal 5\% level with covariate
#' adjustment (intervals covered 87.7\%) and 10.2\% treatment-only; for the risk
#' ratio the figures were 9.6\% and 6.0\%. The excess is expected to shrink as n
#' grows. With so few subjects in one arm, use a larger or more balanced sample,
#' or a randomization or bootstrap test. Source: the first calibration campaign
#' (2026-11-09-8c32d060; provisional, 1000 screening replicates per cell, Monte
#' Carlo standard error about 0.007; measured at n = 50 only),
#' \url{https://github.com/kapelner/EDI/tree/calibration-results}.
#'
#' \strong{Separation.} When the logistic working model's fitted probabilities
#' are numerically 0 or 1 (the data look (quasi-)completely separated) the
#' working-model MLE does not exist and the fitted risks sit where the fitter
#' stopped. The class then raises one warning of class
#' \code{edi_logistic_separation_warning} per object (silent inside resampling);
#' the returned values are unchanged. A randomization test or an exact incidence
#' method is safer there.
#'
#' @seealso \code{\link[EDI:InferenceIncidGCompRiskRatio]{InferenceIncidGCompRiskRatio}}
#'   for the risk-ratio version of this same standardized logistic working model.
#'
#' @examples
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 30, response_type = 'incidence')
#' \donttest{
#' for (i in 1:30) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(30, 1, 0.5))
#' inf = InferenceIncidGCompRiskDiff$new(seq_des)
#' inf$compute_estimate()
#' }
#' @inheritSection InferenceContinOLS Blocking designs
#' @eval rd_small_sample_section("InferenceIncidGCompRiskDiff")
#' @export
InferenceIncidGCompRiskDiff = define_inference_class(
	classname = "InferenceIncidGCompRiskDiff",
	inherit = Inference,
	components = c(
		"RandomizationCI",
		"RandomizationBootstrapCI",
		"BayesianBootstrap",
		"Jackknife",
		"IncidenceGComputation"
	),
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

#' @R6method InferenceIncidGCompRiskDiff$approximate_bootstrap_distribution_beta_hat_T
#' @template gcomp-bootstrap-distribution-beta-hat-t
NULL

#' @R6method InferenceIncidGCompRiskDiff$compute_bootstrap_confidence_interval
#' @template gcomp-bootstrap-confidence-interval
NULL

#' @R6method InferenceIncidGCompRiskDiff$compute_bootstrap_two_sided_pval
#' @template gcomp-bootstrap-two-sided-pval
NULL

#' @R6method InferenceIncidGCompRiskDiff$compute_bayesian_bootstrap_two_sided_pval
#' @template gcomp-bayesian-bootstrap-two-sided-pval
NULL

#' @R6method InferenceIncidGCompRiskDiff$compute_bayesian_bootstrap_confidence_interval
#' @template gcomp-bayesian-bootstrap-confidence-interval
NULL

#' @R6method InferenceIncidGCompRiskDiff$compute_jackknife_wald_two_sided_pval
#' @template gcomp-jackknife-wald-two-sided-pval
NULL

#' @R6method InferenceIncidGCompRiskDiff$compute_jackknife_wald_confidence_interval
#' @template gcomp-jackknife-wald-confidence-interval
NULL

#' @R6method InferenceIncidGCompRiskDiff$compute_subsampling_two_sided_pval
#' @template gcomp-subsampling-two-sided-pval
NULL

#' @R6method InferenceIncidGCompRiskDiff$compute_subsampling_confidence_interval
#' @template gcomp-subsampling-confidence-interval
NULL

#' @R6method InferenceIncidGCompRiskDiff$compute_m_out_of_n_bootstrap_two_sided_pval
#' @template gcomp-m-out-of-n-bootstrap-two-sided-pval
NULL

#' @R6method InferenceIncidGCompRiskDiff$compute_m_out_of_n_bootstrap_confidence_interval
#' @template gcomp-m-out-of-n-bootstrap-confidence-interval
NULL

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
#' distributed on the log scale. Wald inference uses the fitted logistic
#' model's sandwich covariance and the delta method on the log risk-ratio
#' scale.  This standard error conditions on the observed covariates used for
#' standardization: it quantifies uncertainty in the fitted coefficients for
#' the sample-conditional standardized risk ratio, and does not add sampling
#' variability from a target population's covariate distribution.  Bootstrap,
#' randomization, and jackknife methods remain available.
#' \code{likelihood_tier = "none"} means that this class does not provide
#' likelihood-ratio or score tests; it does not preclude its Wald inference.
#'
#' \strong{Bayesian-bootstrap intervals.} The \code{type = "studentized"}
#' (\code{"bootstrap-t"}) interval of
#' \code{$compute_bayesian_bootstrap_confidence_interval()} is studentized on the
#' raw risk-ratio scale and undercovers in small samples: in a simulation with a
#' logistic outcome model, two covariates and a true risk ratio of about 1.4, a nominal
#' 95\% interval covered about 89\% of the time at \eqn{n = 60} and about 93\% at
#' \eqn{n = 200}. Large replicate estimates come with large replicate standard
#' errors, which compresses the upper tail of the pivot, so the interval misses
#' mostly on one side (the true ratio falls below the lower bound). For small
#' samples prefer \code{type = "symmetric-percentile-t"}, a symmetric studentized
#' interval built on the log risk-ratio scale and back-transformed (about 92\%
#' in the same simulation, against 90\% for \code{"studentized"}), or the
#' log-scale \code{type = "wald"} or \code{type = "basic"} intervals or
#' \code{type = "percentile"}.
#' \code{"symmetric-percentile-t"} is available only for the risk-ratio classes.
#'
#' \strong{Separation.} When the logistic working model's fitted probabilities
#' are numerically 0 or 1 (the data look (quasi-)completely separated) the
#' working-model MLE does not exist and the fitted risks sit where the fitter
#' stopped. The class then raises one warning of class
#' \code{edi_logistic_separation_warning} per object (silent inside resampling);
#' the returned values are unchanged. A randomization test or an exact incidence
#' method is safer there.
#'
#' \strong{Subsampling and m-out-of-n.} The subsampling and m-out-of-n bootstrap
#' p-values and intervals use the log-scale pivot \eqn{\sqrt{b}(\log\widehat{RR}^* -
#' \log\widehat{RR})}. At the default size \eqn{b = m = \lfloor n^{0.7} \rfloor} (21 at
#' \eqn{n = 80}) a draw has only a few events per arm, so with non-negligible probability
#' it is \emph{degenerate}: (i) an arm of the draw has no events or only events, (ii) the
#' logistic fit reports that it did not converge, or (iii) the fit is (quasi-)separated, i.e.
#' some fitted probability is numerically 0 or 1 (\eqn{|x_i^\top\hat\beta| \ge
#' \mathrm{logit}(1 - 10^{-8})}, the criterion of the separation warning). A degenerate
#' draw's log risk ratio is about \eqn{\pm 20}, where the fitter stopped. Subsampling
#' estimates the sampling law of the estimator at size \eqn{b} and relies on it being close
#' to the law at size \eqn{n} (Politis, Romano and Wolf 1999, Theorem 2.2.1; 2001); at small
#' \eqn{b} that law puts a few percent of its mass on these atoms, which land in the tail the
#' test uses and put a floor of about twice their fraction under the p-value. Kept, they made
#' the tests almost never reject (null size 0.005 for subsampling and 0.000 for m-out-of-n at
#' \eqn{n = 80}, nominal 0.05). Degenerate draws are therefore unusable: the
#' \code{approximate_subsampling_distribution_beta_hat_T()} and
#' \code{approximate_m_out_of_n_bootstrap_distribution_beta_hat_T()} replicates are
#' \code{NaN} for them. If fewer than \code{min_fraction_usable_samples} (default 0.95) of
#' the \code{B} draws are usable (not degenerate and not failed), the p-value or interval is
#' \code{NA}, the reason (\code{"subsampling_too_few_usable_draws_fraction"} or
#' \code{"m_out_of_n_too_few_usable_draws_fraction"}) is recorded and one warning of class
#' \code{edi_procedure_na_warning} is raised (silent inside resampling); otherwise the
#' usable draws are used. In a null simulation at \eqn{n = 80} (200 data sets, event rate
#' about 0.41, \code{B = 199}) dropping the degenerate draws alone gave null sizes of 0.040
#' (subsampling) and 0.030 (m-out-of-n), but degenerate draws concentrate in data sets with an
#' extreme estimate, so the default 0.95 returned \code{NA} for 9\% (subsampling) and 29\%
#' (m-out-of-n) of them, most of the ones the Wald test rejects, and the size among the rest was
#' 0.016 and 0.000; with \code{min_fraction_usable_samples = 0.8} no data set was \code{NA}.
#' The 0.95 default is under review and may change in a later release; until then, expect
#' \code{NA} from these two methods on small samples and set
#' \code{min_fraction_usable_samples} lower only if the dropped draws are acceptable.
#' For the risk ratio the ordinary bootstrap
#' (\code{compute_bootstrap_two_sided_pval()}, \code{compute_bootstrap_confidence_interval()})
#' is the recommended resampling method: the estimator is smooth, the \eqn{n}-out-of-\eqn{n}
#' bootstrap is consistent, and resampling fewer than \eqn{n} units only adds these
#' small-sample failures. Firth-penalized fits inside the draws are planned as an option.
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
#' @inheritSection InferenceContinOLS Blocking designs
#' @eval rd_small_sample_section("InferenceIncidGCompRiskRatio")
#' @export
InferenceIncidGCompRiskRatio = define_inference_class(
	classname = "InferenceIncidGCompRiskRatio",
	inherit = Inference,
	components = c(
		"RandomizationCI",
		"RandomizationBootstrapCI",
		"BayesianBootstrap",
		"Jackknife",
		"IncidenceGComputation"
	),
	public = incidence_gcomp_generic_alias_overrides,
	private = c(incidence_gcomp_worker_overrides, list(
		get_supported_testing_types_impl = function() "wald",
		build_design_matrix = function(){
			private$create_design_matrix()
		},
		get_estimand_type = function() "RR",
		# v1.0.6-TODO-168 (a): adds the log(RR) symmetric studentized interval.
		bayesian_bootstrap_ci_types = c("percentile", "basic", "wald", "studentized", "bootstrap-t", "bca", "symmetric-percentile-t")
	)),
	overrides = list(
		public = incidence_gcomp_overrides$public,
		private = c(incidence_gcomp_overrides$private, "bayesian_bootstrap_ci_types")
	),
	metadata = list(likelihood_tier = "none")
)

#' @R6method InferenceIncidGCompRiskRatio$approximate_bootstrap_distribution_beta_hat_T
#' @template gcomp-bootstrap-distribution-beta-hat-t
NULL

#' @R6method InferenceIncidGCompRiskRatio$compute_bootstrap_confidence_interval
#' @template gcomp-bootstrap-confidence-interval
NULL

#' @R6method InferenceIncidGCompRiskRatio$compute_bootstrap_two_sided_pval
#' @template gcomp-bootstrap-two-sided-pval
NULL

#' @R6method InferenceIncidGCompRiskRatio$compute_bayesian_bootstrap_two_sided_pval
#' @template gcomp-bayesian-bootstrap-two-sided-pval
NULL

#' @R6method InferenceIncidGCompRiskRatio$compute_bayesian_bootstrap_confidence_interval
#' @template gcomp-bayesian-bootstrap-confidence-interval
NULL

#' @R6method InferenceIncidGCompRiskRatio$compute_jackknife_wald_two_sided_pval
#' @template gcomp-jackknife-wald-two-sided-pval
NULL

#' @R6method InferenceIncidGCompRiskRatio$compute_jackknife_wald_confidence_interval
#' @template gcomp-jackknife-wald-confidence-interval
NULL

#' @R6method InferenceIncidGCompRiskRatio$compute_subsampling_two_sided_pval
#' @template gcomp-subsampling-two-sided-pval
NULL

#' @R6method InferenceIncidGCompRiskRatio$compute_subsampling_confidence_interval
#' @template gcomp-subsampling-confidence-interval
NULL

#' @R6method InferenceIncidGCompRiskRatio$compute_m_out_of_n_bootstrap_two_sided_pval
#' @template gcomp-m-out-of-n-bootstrap-two-sided-pval
NULL

#' @R6method InferenceIncidGCompRiskRatio$compute_m_out_of_n_bootstrap_confidence_interval
#' @template gcomp-m-out-of-n-bootstrap-confidence-interval
NULL
