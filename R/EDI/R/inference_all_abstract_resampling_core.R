#' Shared resampling support for inference components
#'
#' Internal component source for `ResamplingCore` (v1.0.5 TODO-97, Option A,
#' 2026-10-22). It holds the helpers that several resampling components call:
#' the resampling-draw contract lookup and distribution cache shared by the
#' randomization, nonparametric-bootstrap and Bayesian-bootstrap paths; the
#' jackknife-unit validators shared by the jackknife and bootstrap paths; the
#' extreme-estimate guard and its threshold; and the `NULL` default of the
#' reusable bootstrap-worker hook. The methods were moved here unchanged from
#' `InferenceRand`, `InferenceJackknife` and `InferenceNonParamBootstrap`, so
#' that the component dependency graph is acyclic and every declared edge is
#' a real call. Every method here calls only package functions, root state
#' (`cached_values`, `des_obj`) or other methods of this component.
#'
#' In the retained legacy ladder this generator sits between `Inference` and
#' `InferenceRand`, so every ladder generator still has these methods.
#'
#' @keywords internal
InferenceResamplingCore = R6::R6Class("InferenceResamplingCore",
	lock_objects = FALSE,
	inherit = Inference,
	private = list(
		# Moved from NonparametricBootstrap. Hosts may override the value (e.g.
		# the KK conditional-logit GLMM classes use 8).
		bootstrap_extreme_estimate_threshold = EDI_SEPARATION_THRESHOLD,
		# Moved from RandomizationTest.
		get_resampling_draw_contract = function(operation){
			resampling_draw_contract(operation)
		},
		ensure_resampling_distribution_cache = function(operation){
			private$cached_values = resampling_distribution_cache_ensure(
				private$cached_values,
				operation
			)
			invisible(private$cached_values)
		},
		get_cached_resampling_distribution = function(operation, cache_key){
			resampling_distribution_cache_get(
				private$cached_values,
				operation,
				cache_key
			)
		},
		set_cached_resampling_distribution = function(operation, cache_key, value){
			private$cached_values = resampling_distribution_cache_set(
				private$cached_values,
				operation,
				cache_key,
				value
			)
			invisible(value)
		},
		# Moved from Jackknife.
		normalize_jackknife_unit = function(unit = "auto"){
			unit = tolower(as.character(unit)[1L])
			valid = c("auto", "observation", "cluster", "block", "pair", "matched_set")
			if (should_run_asserts()) {
				assertChoice(unit, valid)
			}
			unit
		},
		assert_jackknife_supported = function(unit = "auto"){
			unit = private$normalize_jackknife_unit(unit)
			design_obj = private$des_obj
			is_blocking_design = isTRUE(design_obj$is_blocking_design())
			is_matching_design = isTRUE(design_obj$is_matching_design())
			is_cluster_design = design_obj$is_a_cluster_capable()
			if (should_run_asserts()) {
				if (unit == "block" && !is_blocking_design) {
					stop("jackknife unit = 'block' requires a blocking design.", call. = FALSE)
				}
				if (unit %in% c("pair", "matched_set") && !is_matching_design) {
					stop("jackknife unit = '", unit, "' requires a matching design.", call. = FALSE)
				}
				if (unit == "cluster" && !is_cluster_design) {
					stop("jackknife unit = 'cluster' requires a clustered design.", call. = FALSE)
				}
			}
			invisible(NULL)
		},
		# Moved from NonparametricBootstrap.
		bootstrap_estimates_extreme = function(theta, est = NA_real_, max_abs = private$bootstrap_extreme_estimate_threshold){
			theta = as.numeric(theta)
			theta = theta[is.finite(theta)]
			if (!length(theta)) return(FALSE)
			max_abs = as.numeric(max_abs)[1L]
			if (!is.finite(max_abs) || max_abs <= 0) max_abs = EDI_SEPARATION_THRESHOLD
			if (any(abs(theta) > max_abs)) return(TRUE)
			scale_ref = max(1, abs(as.numeric(est)[1L]), stats::median(abs(theta)), na.rm = TRUE)
			if (!is.finite(scale_ref) || scale_ref <= 0) scale_ref = 1
			theta_width = diff(stats::quantile(theta, probs = c(0.025, 0.975), names = FALSE, type = 8))
			is.finite(theta_width) && theta_width > max_abs * scale_ref
		},
		# Default of the reusable bootstrap-worker hook (moved from
		# NonparametricBootstrap). It is called by RandomizationTest,
		# NonparametricBootstrap, RandomizationBootstrap and BayesianBootstrap.
		# Wald, the cached-likelihood base and several leaf classes override it;
		# they compose after this component, so their overrides still win.
		create_bootstrap_worker_state = function(){
			NULL
		}
	)
)
