# Host-side public methods shared by the two retained KK compound bases below
# (not a component: these are the bases' own `initialize` and bootstrap-weight
# estimator, passed to define_inference_class() as the host `public =`).
#' Internal Base Class for KK Matching-on-the-Fly Designs
#'
#' @name InferenceKKPassThroughCompound
#' @description Internal method.
#' An abstract R6 class that provides relevant methods when the designs are KK matching-on-the-fly.
#'
#' @keywords internal
kk_passthrough_compound_host_public = list(
		#' @description Initialize
		#' @param des_obj         A DesignSeqOneByOne object.
		#' @param model_formula   Optional formula for covariate adjustment.
		#' @param verbose         Whether to print messages.
		#' @param harden          Whether to apply robustness measures.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		initialize = function(des_obj, verbose = FALSE, harden = TRUE, model_formula = NULL, smart_cold_start_default = NULL){
			super$initialize(des_obj, verbose = verbose, harden = harden, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			private$init_kk_passthrough(des_obj)
		},
		#' @description Recomputes the class-specific treatment estimate under bootstrap weights; see
		#'   \code{\link[EDI:InferenceBayesianBootstrap]{InferenceBayesianBootstrap}}.
		#' @param subject_or_block_weights Bootstrap weights at the subject or block level.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE) {
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			# Same dispatch as the KKPassThrough component (v1.0.6-TODO-217): the
			# class's own weighted refit, or a refusal, never a raw mean difference.
			if (is.function(private$compute_weighted_estimate_ivwc)) {
				w_info = kk_pair_and_reservoir_bootstrap_weights(private, row_weights)
				w_info$row_weights = row_weights
				return(private$compute_weighted_estimate_ivwc(w_info, estimate_only))
			}
			stop(class(self)[1L], " has no weighted refit of its estimator, so it cannot compute a ",
				"Bayesian-bootstrap replicate.", call. = FALSE)
		}
)

# Retained legacy ladder generators (fix_inference_hierarchy.md "Static
# Cleanup" / "Ban raw component splicing", 2026-08-23): assembled through
# define_inference_class() -- the same factory every migrated class uses --
# instead of the former compose_inference_mixins() result spliced in by hand
# as `$public`/`$private`. The host-side methods shared by both sibling bases
# live once in `kk_passthrough_compound_host_public` above (host methods, not
# a component). These bases are kept only as the `inherit =` target of
# InferenceAbstractQuantileRandCI and of the KK migration golden tests'
# legacy generators; zero concrete registered classes descend from them.
InferenceKKPassThroughCompound = define_inference_class(
	classname = "InferenceKKPassThroughCompound",
	inherit = InferenceParamBootstrap,
	components = "KKCompound",
	public = kk_passthrough_compound_host_public,
	private = list(
		is_a_kk_passthrough_compound = function() TRUE
	),
	overrides = list(
		public = c(
			"initialize", "approximate_bootstrap_distribution_beta_hat_T",
			"compute_estimate_with_bootstrap_weights"
		),
		private = "compute_basic_match_data"
	)
)

#' Internal Base Class for KK Designs Without Parametric LR Bootstrap
#'
#' @name InferenceKKPassThroughCompoundNoParamBootstrap
#' @description Internal method. Parallel branch for KK matching-on-the-fly
#' designs that should not expose the parametric LR bootstrap API.
#'
#' @keywords internal
#' @noRd
InferenceKKPassThroughCompoundNoParamBootstrap = define_inference_class(
	classname = "InferenceKKPassThroughCompoundNoParamBootstrap",
	inherit = InferenceAsympLik,
	components = "KKCompound",
	public = kk_passthrough_compound_host_public,
	private = list(
		is_a_kk_passthrough_compound_no_param_bootstrap = function() TRUE
	),
	overrides = list(
		public = c(
			"initialize", "approximate_bootstrap_distribution_beta_hat_T",
			"compute_estimate_with_bootstrap_weights"
		),
		private = "compute_basic_match_data"
	)
)
