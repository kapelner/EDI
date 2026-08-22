#' LWA-style Marginal Cox IVWC Compound Inference for KK Designs
#'
#' Fits a compound (IVWC) estimator for KK matching-on-the-fly designs with
#' survival responses: matched pairs are analyzed with a marginal Cox model
#' \eqn{\lambda(t \mid W) = \lambda_0(t)\exp(\beta_T W)} whose robust variance
#' uses the Lee-Wei-Amato (1992) cluster-robust sandwich (treating each matched
#' pair as an independent cluster of correlated failure times), while reservoir
#' subjects are analyzed with a standard (independent-subjects) Cox partial
#' likelihood; the two log-hazard-ratio estimates are then combined by
#' inverse-variance weighting. \code{likelihood_tier = "partial"} (Cox partial
#' likelihood), but likelihood-ratio/score/gradient tests are not exposed on
#' this IVWC compound (only on the
#' \code{\link[EDI:InferenceSurvivalKKLWACoxPHOneLik]{OneLik}} sibling, which
#' fits one combined partial likelihood across both sources instead of pooling
#' two separate fits).
#'
#' \strong{Legacy class.} Not fully tested in \code{comprehensive_tests.R}.
#'
#' @references Lee, E. W., Wei, L. J., and Amato, D. A. (1992). "Cox-Type
#'   Regression Analysis for Large Numbers of Small Groups of Correlated
#'   Failure Time Observations." In \emph{Survival Analysis: State of the Art},
#'   237-247. Springer. \doi{10.1007/978-94-015-7983-4_14}
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'survival')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(runif(10))
#' inf = InferenceSurvivalKKLWACoxPHIVWC$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
# Migrated 2026-08-18 (fix_inference_hierarchy.md "KK And IVWC Estimators"):
# formerly a thin R6 leaf on the abstract base `InferenceAbstractKKLWACoxIVWC`;
# abstract + leaf were merged into the (previously shim-only) registered
# component source `KKLWACoxIVWCPartialLikelihoodSource` in
# inference_survival_KK_lwa_cox_ivwc_abstract.R (that file Collates before
# this one), composed here with `dependencies = "KKCompound"`.
InferenceSurvivalKKLWACoxPHIVWC = define_inference_class(
	classname = "InferenceSurvivalKKLWACoxPHIVWC",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald", "KKLWACoxIVWCPartialLikelihood"),
	public = list(
		# Pinned from InferenceRand -- same flattened-super$ rationale as every
		# other survival/count KK migration this stretch.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	),
	metadata = list(likelihood_tier = "partial"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"initialize",
			"compute_estimate",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			# KKCompound chain vs bootstrap/Wald chain: the KK-aware versions win
			# via component order (KKCompound resolves after BayesianBootstrap/
			# Wald), matching the old ladder's inherited behavior -- the merged
			# source dropped the abstract's no-op eval(body(...)) restatement of
			# approximate_bootstrap_distribution_beta_hat_T.
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
			"shared",
			"assert_finite_se",
			# MLEorKM's graceful-NA version wins over the Wald component's
			# stop()-on-missing-SE fallback (Lesson 5, see the Source comment).
			"get_standard_error"
		)
	)
)
#' LWA-style Marginal Cox Combined-Likelihood Inference for KK Designs
#'
#' Fits a single combined Cox partial likelihood
#' \eqn{\lambda(t \mid W, X) = \lambda_0(t)\exp(\beta_T W + \beta_X^\top X)}
#' jointly over matched-pair and reservoir subjects for KK matching-on-the-fly
#' designs with survival responses (a marginal, not stratified, Cox model:
#' matched pairs do not get pair-specific baseline hazards). This is the
#' one-likelihood combined-fit analog of
#' \code{\link[EDI:InferenceSurvivalKKLWACoxPHIVWC]{InferenceSurvivalKKLWACoxPHIVWC}},
#' which instead fits and pools two separate estimators. \code{likelihood_tier
#' = "partial"}: exposes likelihood-ratio and parametric-likelihood-bootstrap
#' inference in addition to Wald/asymptotic and Bayesian-bootstrap paths.
#'
#' @references Cox, D. R. (1972). "Regression Models and Life-Tables."
#'   \emph{Journal of the Royal Statistical Society, Series B}, 34(2), 187-220.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'survival')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(runif(10))
#' inf = InferenceSurvivalKKLWACoxPHOneLik$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
# Migrated 2026-08-18 (fix_inference_hierarchy.md "Partial-Likelihood
# Estimators" / "KK And IVWC Estimators"): formerly a thin R6 leaf on the
# abstract base `InferenceAbstractKKLWACoxOneLik`; abstract + leaf were merged
# into the (previously shim-only) registered component source
# `KKLWACoxOneLikPartialLikelihoodSource` in
# inference_survival_KK_lwa_cox_one_lik_abstract.R (that file Collates before
# this one), composed here with `dependencies = c("KKPassThrough",
# "ParametricLikelihoodBootstrap")`.
InferenceSurvivalKKLWACoxPHOneLik = define_inference_class(
	classname = "InferenceSurvivalKKLWACoxPHOneLik",
	inherit = Inference,
	components = c("BayesianBootstrap", "KKLWACoxOneLikPartialLikelihood"),
	public = list(
		# Pinned from InferenceRand -- same flattened-super$ rationale as every
		# other survival/count KK migration this stretch.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	),
	# capabilities = "likelihood_ratio" is required explicitly: no component
	# spec declares provides_capabilities = "likelihood_ratio" anywhere in
	# this codebase (unlike "likelihood_tests"/"standard_model_cache"), so a
	# class composing ParametricLikelihoodBootstrap directly (bypassing
	# StandardModelCache, which this class does -- it never fits a summary-
	# table model) must advertise it on the class itself, same as
	# InferenceOrdinalCauchitRegr/InferenceOrdinalCloglogRegr.
	metadata = list(likelihood_tier = "partial", capabilities = "likelihood_ratio"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"initialize",
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"approximate_bootstrap_distribution_beta_hat_T",
			"get_supported_testing_types", "set_testing_type"
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
			"get_standard_error",
			"get_degrees_of_freedom",
			"assert_finite_se",
			"supports_likelihood_tests",
			"supports_lik_ratio_param_bootstrap",
			"simulate_under_lik_null",
			"get_likelihood_test_spec",
			"design_matrix_candidates",
			"shared_combined_likelihood",
			"max_abs_reasonable_coef",
			"optimization_alg",
			"supports_information_preference",
			"supports_observed_information",
			"get_supported_information_preferences_impl",
			"supports_bartlett_likelihood_ratio_approx",
			"get_bartlett_factor_approx"
		)
	)
)
