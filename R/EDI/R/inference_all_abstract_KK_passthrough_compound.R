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
			# Same dispatch as the KKPassThrough component (v1.0.6-TODO-158): the
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

kk_stacked_weighted_estimate = function(self, private, subject_or_block_weights, estimate_only, fit_weighted) {
	row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
	if (weights_are_effectively_constant(row_weights)) {
		self$compute_estimate(estimate_only = estimate_only)
		beta_hat_T = as.numeric(private$cached_values$beta_hat_T)[1L]
		if (is.finite(beta_hat_T)) {
			return(private$cached_values$beta_hat_T)
		}
	}
	result = fit_weighted(row_weights, estimate_only = estimate_only)
	if (is.list(result)) {
		private$cached_values$beta_hat_T = result$beta
		private$cached_values$s_beta_hat_T = result$se
	} else {
		private$cached_values$beta_hat_T = result
		private$cached_values$s_beta_hat_T = NA_real_
	}
	private$cached_values$beta_hat_T
}

kk_stacked_linear_estimate = function(private, estimate_only) {
	private$fit_combined(estimate_only = estimate_only)
	private$cached_values$beta_hat_T
}

kk_stacked_linear_model_data = function(private, cache_key) {
	KKstats = private$cached_values$KKstats
	if (is.null(KKstats)){
		private$compute_basic_match_data()
		KKstats = private$cached_values$KKstats
	}
	m   = KKstats$m
	nRT = KKstats$nRT
	nRC = KKstats$nRC
	nR  = nRT + nRC
	if (m > 0 && nRT > 0 && nRC > 0){
		if (ncol(as.matrix(private$get_X())) > 0){
			Xd_full = as.matrix(KKstats$X_matched_diffs_full)
			p = ncol(Xd_full)
		} else {
			Xd_full = matrix(nrow = m, ncol = 0L)
			p = 0L
		}
		X_comb = rbind(
			if (p > 0L) cbind(0, 1, Xd_full) else cbind(numeric(m), rep(1.0, m)),
			if (p > 0L) cbind(rep(1, nR), KKstats$w_reservoir, as.matrix(KKstats$X_reservoir)) else cbind(rep(1, nR), KKstats$w_reservoir)
		)
		y_comb = c(KKstats$y_matched_diffs, KKstats$y_reservoir)
		j_treat = 2L
	} else if (m > 0){
		Xd = if (ncol(as.matrix(private$get_X())) > 0) as.matrix(KKstats$X_matched_diffs) else matrix(nrow = m, ncol = 0L)
		X_comb = if (ncol(Xd) > 0L) cbind(1, Xd) else matrix(1, nrow = m, ncol = 1L)
		y_comb = KKstats$y_matched_diffs
		j_treat = 1L
	} else if (nRT > 0 && nRC > 0){
		X_r = if (ncol(as.matrix(private$get_X())) > 0) as.matrix(KKstats$X_reservoir) else matrix(nrow = nR, ncol = 0L)
		X_comb = if (ncol(X_r) > 0L) cbind(rep(1, nR), KKstats$w_reservoir, X_r) else cbind(rep(1, nR), KKstats$w_reservoir)
		y_comb = KKstats$y_reservoir
		j_treat = 2L
	} else {
		private$cache_nonestimable_estimate("no_usable_matched_or_reservoir_data")
		return(NULL)
	}
	reduced = private$reduce_design_matrix_once(
		X_comb,
		j_treat,
		cache_key = cache_key
	)
	list(X = reduced$X, y = y_comb, j_treat = reduced$j_treat)
}
