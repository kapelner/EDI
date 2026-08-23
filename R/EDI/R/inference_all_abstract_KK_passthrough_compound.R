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
			w_info = kk_pair_and_reservoir_bootstrap_weights(private, row_weights)
			
			# Weight-aware component estimation: most IVWC paths re-fit using raw data.
			# For now, we use a weighted fallback that is statistically valid for Jackknife.
			# We delegate to the specific class implementation if possible, or use a surrogate.
			
			if (is.function(private$compute_weighted_estimate_ivwc)) {
				return(private$compute_weighted_estimate_ivwc(w_info, estimate_only))
			}
			
			# Fallback: Many IVWC paths combine matched differences and reservoir OLS.
			# We can approximate this for Jackknife by re-calculating the means.
			if (is.null(private$cached_values$KKstats)) {
				private$compute_basic_match_data()
			}
			stats = private$cached_values$KKstats
			if (is.null(stats)) return(NA_real_)
			
			# 1. Matched differences mean
			d_bar_w = if (length(w_info$pair_weights) > 0) {
				sum(stats$y_matched_diffs * w_info$pair_weights) / sum(w_info$pair_weights)
			} else NA_real_
			
			# 2. Reservoir mean diff
			r_idx = w_info$reservoir_idx
			r_w = w_info$reservoir_weights
			if (length(r_idx) > 0 && !is.null(stats$y_reservoir)) {
				y_r = stats$y_reservoir; w_r = stats$w_reservoir
				
				num_t = sum(y_r[w_r == 1] * r_w[w_r == 1], na.rm = TRUE)
				den_t = sum(r_w[w_r == 1], na.rm = TRUE)
				num_c = sum(y_r[w_r == 0] * r_w[w_r == 0], na.rm = TRUE)
				den_c = sum(r_w[w_r == 0], na.rm = TRUE)
				
				r_bar_t = if (is.finite(den_t) && den_t > 0) num_t / den_t else NA_real_
				r_bar_c = if (is.finite(den_c) && den_c > 0) num_c / den_c else NA_real_
				r_bar_w = r_bar_t - r_bar_c
			} else r_bar_w = NA_real_
			
			# combine using fixed weights from observed fit (standard Jackknife practice for complex estimators)
			w_star = stats$w_star
			if (is.null(w_star) || is.na(w_star)) {
				if (!is.na(d_bar_w)) return(d_bar_w)
				return(r_bar_w)
			}
			if (is.na(d_bar_w)) return(r_bar_w)
			if (is.na(r_bar_w)) return(d_bar_w)
			
			as.numeric(w_star * d_bar_w + (1 - w_star) * r_bar_w)
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
