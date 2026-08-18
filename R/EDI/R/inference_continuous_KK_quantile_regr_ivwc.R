#' Quantile Regression Compound Estimator for KK Matching-on-the-Fly Designs
#'
#' A variance-weighted compound quantile regression estimator for KK
#' matching-on-the-fly designs with continuous responses. The estimator
#' combines:
#' \enumerate{
#'   \item Quantile regression on within-pair differences (matched pairs)
#'   \item Quantile regression on reservoir subjects (treatment vs control)
#' }
#' using the same variance-weighted combination logic as the OLS compound estimator.
#'
#' \strong{Default quantile: \code{tau = 0.5} (median regression).}
#' At \code{tau = 0.5} this estimates the median treatment effect, which is the canonical
#' nonparametric location estimator and is more robust to outliers and heavy-tailed
#' response distributions than the OLS mean-based estimator. To target a different
#' quantile of the treatment effect distribution --- for example the 25th or 75th
#' percentile --- pass \code{tau = 0.25} or \code{tau = 0.75} to the constructor:
#' \preformatted{
#'   inf = InferenceContinKKQuantileRegrIVWC$
#'   new(seq_des, tau = 0.75)
#' }
#' Any value strictly between 0 and 1 is accepted.
#'
#' Standard errors use Powell's "nid" sandwich estimator (non-iid), which is more robust
#' than the "iid" (constant-density) assumption; the implementation falls back to "iid"
#' on failure. Asymptotic z-based inference is used throughout.
#'
#' The randomization-based confidence interval is inherited from the base class and is
#' valid for location-shift models at all quantiles: shifting y by delta maps the
#' tau-th quantile treatment effect to delta under the null.
#'
#' This class requires the \pkg{quantreg} package, which is listed in Suggests
#' and is not installed automatically with \pkg{EDI}.
#' Install \pkg{quantreg} before using this class.
#'
#' \strong{Legacy class.} Not fully tested in \code{comprehensive_tests.R}.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'continuous')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rnorm(10))
#' inf = InferenceContinKKQuantileRegrIVWC$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
# Migrated 2026-08-18 (fix_inference_hierarchy.md "KK And IVWC Estimators"):
# formerly a thin R6 leaf on the abstract base
# `InferenceAbstractKKQuantileRegrIVWC`; the machinery now arrives via the
# registered `KKQuantileRegrIVWC` component (which itself depends on
# `KKCompound` and `QuantileRandomizationCI` -- see
# inference_all_KK_quantile_regr_ivwc_abstract.R). `compute_rand_two_sided_
# pval` is pinned from `InferenceRand`, same rationale as every other
# continuous/survival KK migration this stretch (RandCI's Zhang dispatch
# never applies to continuous data).
InferenceContinKKQuantileRegrIVWC = define_inference_class(
	classname = "InferenceContinKKQuantileRegrIVWC",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald", "KKQuantileRegrIVWC"),
	metadata = list(likelihood_tier = "none"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"initialize",
			"compute_estimate",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_rand_confidence_interval",
			"approximate_bootstrap_distribution_beta_hat_T",
			"compute_estimate_with_bootstrap_weights"
		),
		private = c(
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl",
			"compute_treatment_estimate_during_randomization_inference",
			"compute_basic_match_data",
			"shared"
		)
	),
	public = list(
		# Pinned from InferenceRand -- same flattened-super$ rationale as every
		# other continuous/survival KK migration this stretch.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize continuous-response KK IVWC quantile-regression
		#'   inference; see
		#'   \code{\link[EDI:InferenceContinKKQuantileRegrIVWC]{InferenceContinKKQuantileRegrIVWC}}.
		#' @param des_obj A DesignSeqOneByOne object whose entire n subjects
		#'   are assigned and response y is recorded within.
		#' @param tau                             The quantile level for regression, strictly between
		#'   0 and 1. The default \code{tau = 0.5}
		#'                                                         estimates the median treatment
		#' effect. Pass a different value (e.g. \code{tau = 0.25} or
		#'                                                         \code{tau = 0.75}) to target the
		#' corresponding percentile of the treatment effect distribution.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose A flag indicating whether messages should be
		#'   displayed to the user. Default is \code{FALSE}.
		#' @examples
		#' set.seed(1)
		#' x_dat <- data.frame(
		#'   x1 = c(-1.2, -0.7, -0.2, 0.3, 0.8, 1.3, 1.8, 2.3),
		#'   x2 = c(0, 1, 0, 1, 0, 1, 0, 1)
		#' )
		#' seq_des <- DesignSeqOneByOneKK14$new(n = nrow(x_dat), response_type = "continuous", verbose =
		#' FALSE)
		#' for (i in seq_len(nrow(x_dat))) {
		#'   seq_des$add_one_subject_to_experiment_and_assign(x_dat[i, , drop = FALSE])
		#' }
		#' seq_des$add_all_subject_responses(c(1.2, 0.9, 1.5, 1.8, 2.1, 1.7, 2.6, 2.2))
		#' infer <- InferenceContinKKQuantileRegrIVWC$new(seq_des, verbose = FALSE)
		#' infer
		#'
		initialize = function(des_obj, model_formula = NULL, tau = 0.5,  verbose = FALSE){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "continuous")
			}
			# Calls the KKQuantileRegrIVWC component's shared init logic via the
			# free-function helper, not super$initialize() -- see
			# .init_kk_quantile_regr_ivwc()'s comment in
			# inference_all_KK_quantile_regr_ivwc_abstract.R (Lesson 1 corollary
			# for two leaves sharing one component).
			.init_kk_quantile_regr_ivwc(self, private, super, des_obj, model_formula, tau, identity, verbose, NULL)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		}
	)
)
