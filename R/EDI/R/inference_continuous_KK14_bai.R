#' Bai Adjusted-t Mean-Difference Inference for KK14 Designs
#'
#' Continuous-response mean-difference inference for designs assigned by
#' \code{\link[EDI:DesignSeqOneByOneKK14]{DesignSeqOneByOneKK14}} (the
#' Kapelner-Krieger 2014 sequential matching-on-the-fly design). The point
#' estimate and its variance are the closed-form Bai-adjusted-t combination of
#' the matched-pairs mean difference and the unmatched-reservoir mean
#' difference, inverse-variance-weighted when both are usable; the full
#' formula, pair-distance definition, and confidence-interval/p-value
#' construction are shared with
#' \code{\link[EDI:InferenceBaiAdjustedTKK21]{InferenceBaiAdjustedTKK21}}.
#' The two leaves differ only in how pair distance is defined during matching:
#' this class (KK14) uses the plain squared Euclidean distance
#' \eqn{\sum_j (x_{1j} - x_{2j})^2} between candidate subjects' covariate
#' vectors, unlike KK21's covariate-weighted distance. Because the estimator
#' is closed-form, initialization does not use warm starts (there is no
#' iterative fit to warm-start).
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
#' inf = InferenceBaiAdjustedTKK14$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
# Migrated 2026-08-18 (fix_inference_hierarchy.md "KK And IVWC Estimators"):
# formerly a thin R6 leaf on the abstract base `InferenceBaiAdjustedT`; the
# machinery now arrives via the registered `BaiAdjustedT` component
# (inference_continuous_KK_bai_abstract.R). The `distance` private below is
# this leaf's only own surface (nothing calls it -- pair distances go through
# compute_pair_distance_matrix_cpp -- but it is preserved verbatim).
InferenceBaiAdjustedTKK14 = define_inference_class(
	classname = "InferenceBaiAdjustedTKK14",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald", "BaiAdjustedT"),
	public = list(
		# Pinned from InferenceRand -- same flattened-super$ rationale as every
		# other KK migration this stretch.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	),
	private = list(
		distance = function(avg1, avg2){
			sum((avg1 - avg2)^2)
		}
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
			# Wald), matching the old ladder's inherited behavior.
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
			"compute_fast_randomization_distr",
			"shared",
			# MLEorKM's graceful-NA version wins over the Wald component's
			# stop()-on-missing-SE fallback (Lesson 5, see the Source comment).
			"get_standard_error"
		)
	)
)
