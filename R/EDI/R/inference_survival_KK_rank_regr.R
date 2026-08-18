#' Rank Regression Inference for Survival Responses under KK Designs
#'
#' Fits a multivariate Gehan-Wilcoxon rank regression for survival outcomes under
#' a KK matching-on-the-fly design. The model adjusts for the treatment indicator
#' and, optionally, all recorded covariates.
#'
#' \strong{Legacy class.} Not fully tested in \code{comprehensive_tests.R}.
#'
#' @examples
#' \dontrun{
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'survival')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(runif(10))
#' inf = InferenceSurvivalKKRankRegrIVWC$new(seq_des)
#' inf$compute_estimate()
#' }
#' }
#' @export
# Migrated 2026-08-18 (fix_inference_hierarchy.md "KK And IVWC Estimators"):
# formerly a thin R6 leaf on the abstract base
# `InferenceAbstractKKSurvivalRankRegrIVWC`; abstract + leaf were merged into
# the static `SurvivalKKRankRegrIVWCSource` in
# inference_survival_KK_rank_regr_ivwc_abstract.R (that file Collates before
# this one), composed here via the registered `SurvivalKKRankRegrIVWC`
# component (`dependencies = "KKCompound"`).
InferenceSurvivalKKRankRegrIVWC = define_inference_class(
	classname = "InferenceSurvivalKKRankRegrIVWC",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald", "SurvivalKKRankRegrIVWC"),
	public = list(
		# Pinned from InferenceRand -- same flattened-super$ rationale as every
		# other survival/count KK migration this stretch.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	),
	metadata = list(likelihood_tier = "none"),
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
			# stop()-on-missing-SE fallback (see the Source comment).
			"get_standard_error",
			"build_design_matrix"
		)
	)
)
