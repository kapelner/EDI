#' Internal Resampling Draw Contracts
#'
#' These contracts keep the draw-loader and distribution-cache vocabulary aligned
#' across randomization, nonparametric bootstrap, bootstrap randomization, and
#' Bayesian bootstrap execution paths.
#'
#' @keywords internal
#' @noRd
EDI_RESAMPLING_DRAW_CONTRACTS = list(
	rand = list(
		operation = "rand",
		draw_type = "assignment",
		loader = "load_randomization_draw_into_worker",
		estimator = "compute_randomization_worker_estimate",
		cache_name = "rand_distr_cache",
		cache_key_method = "build_randomization_distribution_cache_key"
	),
	non_param_boot = list(
		operation = "non_param_boot",
		draw_type = "row_sample",
		loader = "load_non_param_bootstrap_draw_into_worker",
		estimator = "compute_bootstrap_worker_estimate",
		cache_name = "boot_distr_cache",
		cache_key_method = NULL
	),
	m_out_of_n_boot = list(
		operation = "m_out_of_n_boot",
		draw_type = "unit_sample_with_replacement_size_m",
		loader = "load_m_out_of_n_bootstrap_draw_into_worker",
		estimator = "compute_bootstrap_worker_estimate",
		cache_name = "m_out_of_n_boot_distr_cache",
		cache_key_method = "m_out_of_n_bootstrap_cache_key"
	),
	subsampling = list(
		operation = "subsampling",
		draw_type = "unit_subsample_without_replacement",
		loader = "load_subsampling_draw_into_worker",
		estimator = "compute_subsampling_worker_estimate",
		cache_name = "subsampling_distr_cache",
		cache_key_method = "subsampling_cache_key"
	),
	rand_bootstrap = list(
		operation = "rand_bootstrap",
		draw_type = "row_sample_plus_assignment",
		loader = "load_rand_bootstrap_draw_into_worker",
		estimator = "compute_bootstrap_worker_estimate",
		cache_name = "rand_boot_distr_cache",
		cache_key_method = NULL
	),
	bayesian_boot = list(
		operation = "bayesian_boot",
		draw_type = "weights_plus_context",
		loader = "load_bayesian_bootstrap_draw_into_worker",
		estimator = "compute_bayesian_bootstrap_worker_estimate",
		cache_name = "bayes_boot_distr_cache",
		cache_key_method = "bayesian_bootstrap_cache_key"
	)
)

#' Cache keys a reused resampling worker keeps between draws.
#'
#' The reused-worker resampling loaders must leave a worker in the same state a
#' freshly duplicated worker would be in, because every class's
#' \code{shared()}-style estimate cache is guarded on \emph{its own} cache key
#' (\code{beta_hat_T} for most classes, but also \code{md}, \code{rd}/\code{rr},
#' \code{lin_estimate_only_complete}, ...). Resetting a hand-maintained
#' allowlist of keys silently skips the refit for any class whose guard key is
#' not on that list, so the loaders reset \emph{everything} except the keys
#' listed here (plus whatever a class declares via its own
#' \code{reused_worker_preserved_cache_keys()} hook).
#'
#' These two keys match what \code{Inference$duplicate()} carries over into a
#' fresh worker, and are the only ones that are independent of the treatment
#' assignment and responses a draw installs:
#' \describe{
#'   \item{\code{m_cache}}{matched-set bookkeeping derived from the design's
#'     \code{m} vector, which no reused-worker draw changes.}
#'   \item{\code{t0s_rand}}{the delta-zero randomization statistics reused by
#'     the affine-shift fast path; keyed to the original data, never written by
#'     a per-draw refit.}
#' }
#'
#' @keywords internal
#' @noRd
EDI_REUSED_WORKER_CACHE_KEEP_KEYS = c("m_cache", "t0s_rand")

#' Rebuilds a reused resampling worker's `cached_values` for the next draw.
#'
#' Keeps \code{EDI_REUSED_WORKER_CACHE_KEEP_KEYS} plus any class-declared
#' \code{preserve_cache_keys} (structural caches such as the
#' \code{reduce_design_matrix_once()} column selections, which are deliberately
#' computed once per worker), and drops everything else so the next draw refits
#' from scratch.
#'
#' @keywords internal
#' @noRd
reused_worker_cached_values_for_next_draw = function(cached_values, preserve_cache_keys = character()){
	keep = unique(c(EDI_REUSED_WORKER_CACHE_KEEP_KEYS, as.character(preserve_cache_keys)))
	fresh = list()
	for (nm in keep) {
		value = cached_values[[nm]]
		if (!is.null(value)) fresh[[nm]] = value
	}
	fresh
}

#' Returns a resampling draw-loader/cache contract.
#'
#' @keywords internal
#' @noRd
resampling_draw_contract = function(operation){
	if (!is.character(operation) || length(operation) != 1L || is.na(operation)) {
		stop("operation must be one resampling operation name.", call. = FALSE)
	}
	contract = EDI_RESAMPLING_DRAW_CONTRACTS[[operation]]
	if (is.null(contract)) {
		stop("Unknown resampling operation: ", operation, call. = FALSE)
	}
	contract
}

#' Reads a resampling distribution from the operation-specific cache.
#'
#' @keywords internal
#' @noRd
resampling_distribution_cache_get = function(cached_values, operation, cache_key){
	cache_name = resampling_draw_contract(operation)$cache_name
	cache = cached_values[[cache_name]]
	if (is.null(cache)) return(NULL)
	cache[[cache_key]]
}

#' Writes a resampling distribution to the operation-specific cache.
#'
#' @keywords internal
#' @noRd
resampling_distribution_cache_set = function(cached_values, operation, cache_key, value){
	cache_name = resampling_draw_contract(operation)$cache_name
	if (is.null(cached_values[[cache_name]])) cached_values[[cache_name]] = list()
	cached_values[[cache_name]][[cache_key]] = value
	cached_values
}

#' Ensures an operation-specific resampling distribution cache exists.
#'
#' @keywords internal
#' @noRd
resampling_distribution_cache_ensure = function(cached_values, operation){
	cache_name = resampling_draw_contract(operation)$cache_name
	if (is.null(cached_values[[cache_name]])) cached_values[[cache_name]] = list()
	cached_values
}
