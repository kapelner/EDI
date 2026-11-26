#' m-out-of-n Bootstrap Extension
#'
#' Public and private methods for m-out-of-n bootstrap inference. Pattern-1
#' file-split extension, spliced into exactly one class
#' (\code{InferenceNonParamBootstrap}) -- not a reusable mixin.
#'
#' @keywords internal
#' @noRd
InferenceExtMOutOfNBootstrap = list(
	public = list(),
	private = list(
		#' @description Creates the m-out-of-n bootstrap distribution of the
		#'   treatment-effect estimate.
		#'
		#' @param B Number of resamples. Default 501.
		#' @param m Number of exchangeable resampling units drawn with replacement.
		#'   If \code{NULL} (default), use the deterministic intermediate-size rule
		#'   \code{floor(n_units^0.7)}, where \code{n_units} is the number of
		#'   exchangeable units used by the design (observations, clusters, pairs, or
		#'   matched sets). The resolved value must satisfy
		#'   \code{max(5, p_eff + 2) <= m <= floor(n_units / 2)}.
		#' @param show_progress A flag indicating whether a progress bar should be
		#'   displayed.
		#' @param debug If \code{TRUE}, return distribution diagnostics in addition
		#'   to the resampled estimates.
		#' @param bootstrap_type Optional empirical-resampling scheme. See
		#'   \code{approximate_bootstrap_distribution_beta_hat_T()}.
		#' @param scaling Scaling sequence for centered m-out-of-n pivots. The
		#'   default \code{"sqrt_n"} uses \code{sqrt(m)} for the m-sample
		#'   distribution and converts back to the full-sample scale using
		#'   \code{sqrt(n_units)}.
		#' @param center Centering convention for diagnostics and cache keys.
		#'
		#' @details The default \code{m = NULL} rule is a cheap deterministic
		#'   intermediate sequence: \eqn{m \to \infty} and \eqn{m / n \to 0}, as
		#'   required by the standard m-out-of-n bootstrap asymptotic setup
		#'   (Bickel, Gotze, and van Zwet; Bickel and Sakov). The exponent 0.7 is a
		#'   pragmatic interior point in \eqn{(0, 1)}; it is not a silver-bullet
		#'   optimal choice. Use \code{select_optimal_m_out_of_n_bootstrap()} for
		#'   data-adaptive minimum-volatility selection.
		#'
		#' @return A numeric vector of bootstrap estimates, or when
		#'   \code{debug = TRUE}, a diagnostic list.
		#'
		#' @references Bickel, P. J., Gotze, F., and van Zwet, W. R. (1997).
		#'   Resampling fewer than n observations: gains, losses, and remedies for
		#'   losses. \emph{Statistica Sinica}.
		#'
		#' @references Bickel, P. J. and Sakov, A. (2008). On the choice of m in
		#'   the m out of n bootstrap. \emph{The Annals of Statistics}.
		approximate_m_out_of_n_bootstrap_distribution_beta_hat_T_impl = function(B = 501, m = NULL, show_progress = TRUE, debug = FALSE, bootstrap_type = NULL, scaling = "sqrt_n", center = "full_estimate"){
			private$check_bootstrap_replicate_deadline("m-out-of-n bootstrap setup")
			if (should_run_asserts()) {
				private$assert_design_supports_resampling("m-out-of-n bootstrap inference")
				private$assert_valid_bootstrap_type(bootstrap_type)
				assertCount(B, positive = TRUE)
				assertFlag(show_progress)
				assertFlag(debug)
			}
			unit_info = private$get_exchangeable_units(unit = "auto", resampling_type = bootstrap_type)
			if (is.list(m)) {
				selection = do.call(self$select_optimal_m_out_of_n_bootstrap, c(list(
					B = as.integer(m$B %||% min(as.integer(B), 251L)),
					alpha = as.numeric(m$alpha %||% 0.05),
					bootstrap_type = bootstrap_type,
					scaling = scaling,
					show_progress = show_progress
				), m[setdiff(names(m), c("method", "B", "alpha"))]))
				m = selection$m_optimal
				if (!is.finite(m)) stop("m-out-of-n bootstrap m selection failed.", call. = FALSE)
			}
			m = private$resolve_resampling_size(m, unit_info$n_units, "m")
			cache_key = private$m_out_of_n_bootstrap_cache_key(B = B, m = m, bootstrap_type = bootstrap_type, scaling = scaling, center = center)
			if (!isTRUE(debug)) {
				private$ensure_resampling_distribution_cache("m_out_of_n_boot")
				cached = private$get_cached_resampling_distribution("m_out_of_n_boot", cache_key)
				if (!is.null(cached)) return(cached)
			}
			edi_exchangeable_resample_distribution(self, private, unit_info, B, m, bootstrap_type, scaling,
				show_progress, debug, cache_key, operation = "m_out_of_n_boot", family = "m-out-of-n bootstrap",
				size_label = "m", replace = TRUE)
		},
		#' @description Computes a centered m-out-of-n bootstrap two-sided p-value.
		#'
		#' @param delta Null treatment effect. Default 0.
		#' @param B Number of resamples. Default 501.
		#' @param m Number of exchangeable units drawn with replacement. If
		#'   \code{NULL} (default), use \code{floor(n_units^0.7)} subject to the
		#'   validation bounds documented for
		#'   \code{approximate_m_out_of_n_bootstrap_distribution_beta_hat_T()}.
		#' @param type P-value type. Currently only \code{"centered"} is supported.
		#' @param show_progress A flag indicating whether a progress bar should be
		#'   displayed.
		#' @param min_number_usable_samples Minimum number of finite resampled
		#'   estimates required after filtering. Default 5.
		#' @param bootstrap_type Optional empirical-resampling scheme.
		#' @param scaling Scaling sequence for centered m-out-of-n pivots.
		#'
		#' @details The default \code{m = NULL} follows the intermediate-sequence
		#'   convention from the m-out-of-n bootstrap literature:
		#'   \eqn{m \to \infty} and \eqn{m / n \to 0}. The deterministic exponent
		#'   0.7 is a first-pass default; for unstable paths prefer the
		#'   minimum-volatility selector.
		#'
		#' @return A numeric two-sided p-value, or \code{NA_real_} if the procedure
		#'   fails (recorded as a failure of this procedure only; the Wald estimate
		#'   and standard error are kept).
		compute_m_out_of_n_bootstrap_two_sided_pval_impl = function(delta = 0, B = 501, m = NULL, type = "centered", show_progress = TRUE, min_number_usable_samples = 5L, bootstrap_type = NULL, scaling = "sqrt_n", min_fraction_usable_samples = ratio_resampling_min_fraction_usable){
			if (should_run_asserts()) {
				assertNumeric(delta, len = 1, finite = TRUE, any.missing = FALSE)
				assertCount(B, positive = TRUE)
				assertCount(min_number_usable_samples, positive = TRUE)
				assertChoice(type, c("centered"))
			}
			setup = private$resampling_centered_pivot_for_inference("m_out_of_n", "pval", B = B, size = m, alpha = NULL, show_progress = show_progress,
				min_number_usable_samples = min_number_usable_samples, resampling_type = bootstrap_type, scaling = scaling, min_fraction_usable_samples = min_fraction_usable_samples)
			if (is.null(setup$pivot)) return(setup$value)
			pivot = setup$pivot
			# v1.0.6-TODO-164: ratio estimands (classes with a degenerate-draw rule) use the symmetric p-value.
			private$resampling_centered_pval(pivot$centered_scaled, est = pivot$est, delta = delta, n_units = pivot$n_units, scaling = scaling,
				symmetric = !is.null(edi_ratio_resampling_degenerate_rule(self, private)))
		},
		#' @description Computes a basic m-out-of-n bootstrap confidence interval.
		#'
		#' @param alpha Significance level. Default 0.05.
		#' @param B Number of resamples. Default 501.
		#' @param m Number of exchangeable units drawn with replacement. If
		#'   \code{NULL} (default), use \code{floor(n_units^0.7)} subject to the
		#'   validation bounds documented for
		#'   \code{approximate_m_out_of_n_bootstrap_distribution_beta_hat_T()}.
		#' @param type Confidence-interval type. Currently only \code{"basic"} is
		#'   supported.
		#' @param show_progress A flag indicating whether a progress bar should be
		#'   displayed.
		#' @param min_number_usable_samples Minimum number of finite resampled
		#'   estimates required after filtering. Default 5.
		#' @param bootstrap_type Optional empirical-resampling scheme.
		#' @param scaling Scaling sequence for centered m-out-of-n pivots.
		#'
		#' @details The \code{NULL} default is grounded in the standard m-out-of-n
		#'   asymptotic condition \eqn{m \to \infty} and \eqn{m / n \to 0}. The
		#'   minimum-volatility selector is available when a fixed deterministic
		#'   exponent is too brittle for a specific estimator/design path.
		#'
		#' @return A length-2 numeric confidence interval, or
		#'   \code{c(NA_real_, NA_real_)} if the procedure fails (recorded as a
		#'   failure of this procedure only; the Wald estimate and standard error are
		#'   kept).
		compute_m_out_of_n_bootstrap_confidence_interval_impl = function(alpha = 0.05, B = 501, m = NULL, type = "basic", show_progress = TRUE, min_number_usable_samples = 5L, bootstrap_type = NULL, scaling = "sqrt_n", min_fraction_usable_samples = ratio_resampling_min_fraction_usable){
			if (should_run_asserts()) {
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
				assertCount(B, positive = TRUE)
				assertCount(min_number_usable_samples, positive = TRUE)
				assertChoice(type, c("basic"))
			}
			setup = private$resampling_centered_pivot_for_inference("m_out_of_n", "ci", B = B, size = m, alpha = alpha, show_progress = show_progress,
				min_number_usable_samples = min_number_usable_samples, resampling_type = bootstrap_type, scaling = scaling, min_fraction_usable_samples = min_fraction_usable_samples)
			if (is.null(setup$pivot)) return(setup$value)
			pivot = setup$pivot
			ci = private$resampling_ci_from_centered_distribution(pivot$centered_scaled, alpha = alpha, est = pivot$est, n_units = pivot$n_units, scaling = scaling)
			if (!all(is.finite(ci[1:2])) || private$bootstrap_confidence_interval_extreme(ci, est = pivot$est)) {
				if (isTRUE(private$harden)) return(private$missing_bootstrap_ci(alpha, "m_out_of_n_extreme_confidence_interval", stage = "estimate"))
			}
			ci
		},
		#' @description Selects an m-out-of-n bootstrap size by minimum volatility.
		#'
		#' @param B Number of resamples per candidate size. Default 251.
		#' @param alpha Significance level for interval-width objectives.
		#' @param m_pow_of_n_grid Candidate exponent grid used when
		#'   \code{m_grid = NULL}. Defaults to \code{seq(0.5, 0.9, by = 0.05)}.
		#' @param m_grid Optional explicit integer candidate sizes.
		#' @param objective Selection objective. Currently \code{"ci_width"}.
		#' @param target Target summary. Currently \code{"ci"}.
		#' @param volatility_window Rolling window size used to measure local
		#'   volatility across candidate sizes.
		#' @param bootstrap_type Optional empirical-resampling scheme.
		#' @param scaling Scaling sequence for centered m-out-of-n pivots.
		#' @param show_progress A flag indicating whether a progress bar should be
		#'   displayed.
		#' @param min_finite_fraction Minimum finite-resample fraction required for a
		#'   candidate size to be eligible.
		#'
		#' @details This implements the same minimum-volatility idea used in PTE's
		#'   m-selection workflow: scan admissible intermediate sizes and choose a
		#'   stable region of the target statistic rather than assuming one exponent
		#'   is uniformly optimal.
		#'
		#' @return An \code{EDIMOutOfNBootstrapMSelection} list with the selected
		#'   \code{m}, mapped exponent, candidate table, status, and reason.
		select_optimal_m_out_of_n_bootstrap_impl = function(B = 251, alpha = 0.05, m_pow_of_n_grid = seq(0.5, 0.9, by = 0.05), m_grid = NULL, objective = "ci_width", target = "ci", volatility_window = 3L, bootstrap_type = NULL, scaling = "sqrt_n", show_progress = TRUE, min_finite_fraction = 0.8){
			if (should_run_asserts()) {
				assertCount(B, positive = TRUE)
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
				assertChoice(target, c("ci"))
			}
			unit_info = private$get_exchangeable_units(unit = "auto", resampling_type = bootstrap_type)
			if (is.null(m_grid)) {
				m_grid_raw = floor(unit_info$n_units ^ m_pow_of_n_grid)
				grid_df = unique(data.frame(m = as.integer(m_grid_raw), pow = as.numeric(m_pow_of_n_grid), stringsAsFactors = FALSE))
				m_grid = grid_df$m
				m_pow_mapped = grid_df$pow
			} else {
				m_grid = as.integer(m_grid)
				m_pow_mapped = rep(NA_real_, length(m_grid))
			}
			evaluator = function(m_size) private$evaluate_m_out_of_n_bootstrap_size(m = m_size, B = B, alpha = alpha, bootstrap_type = bootstrap_type, scaling = scaling, show_progress = FALSE)
			private$select_optimal_resample_size(
				size_grid = m_grid,
				evaluator = evaluator,
				objective = objective,
				volatility_window = volatility_window,
				min_finite_fraction = min_finite_fraction,
				size_name = "m",
				exponent_grid = m_pow_mapped,
				selection_class = "EDIMOutOfNBootstrapMSelection"
			)
		}
		,
		m_out_of_n_bootstrap_cache_key = function(B, m, bootstrap_type = NULL, scaling = "sqrt_n", center = "full_estimate"){
			# v1.0.7-TODO-190: re-imputed resamples are cached apart from the default ones.
			paste(as.integer(B), as.integer(m), bootstrap_type %||% "NULL", private$resampling_scaling_key(scaling), center,
				if (edi_bootstrap_reimputes(private)) "reimpute" else NULL, sep = "|")
		},
		m_out_of_n_bootstrap_centered_pivot = function(B, m, unit_info, show_progress = TRUE, bootstrap_type = NULL, scaling = "sqrt_n", min_fraction_usable_samples = ratio_resampling_min_fraction_usable){
			private$check_bootstrap_replicate_deadline("m-out-of-n bootstrap centered pivot")
			cache_key = private$m_out_of_n_bootstrap_cache_key(B = B, m = m, bootstrap_type = bootstrap_type, scaling = scaling, center = "full_estimate")
			pivot = private$get_cached_centered_resampling_pivot("m_out_of_n_boot", cache_key)
			if (is.null(pivot)) {
				# Builds the pivot from fresh draws; a failure (ok = FALSE) is returned uncached.
				pivot = (function(){
					est = tryCatch(as.numeric(self$compute_estimate(estimate_only = TRUE))[1L], error = private$resampling_error_to_na)
					if (!is.finite(est)) {
						return(list(ok = FALSE, reason = "m_out_of_n_original_estimate_unavailable"))
					}
					boot = self$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(
						B = B,
						m = m,
						show_progress = show_progress,
						bootstrap_type = bootstrap_type,
						scaling = scaling
					)
					finite = boot[is.finite(boot)]
					# Fraction-based failure gate (2026-09-06): min_number_usable_samples
					# at the two call sites only checks the ABSOLUTE count of finite
					# replicates (default 5) -- with B in the hundreds, even a large
					# majority of resampled fits failing/degenerating still clears
					# that bar, so the resulting pivot silently gets built from a
					# small, unrepresentative surviving subset. Found on
					# InferenceIncidKKGEE under model_formula = ~. (7 covariates,
					# m sized only to p_eff + 2): ~24% of resampled GEE refits failed
					# to converge at that m, and the surviving-subset pivot produced
					# a degenerate two-sided p-value (~0% rejection under BOTH H0 and
					# H1). Requiring a majority of replicates to succeed converts
					# this from a silently wrong, falsely-precise p-value into an
					# honest non-estimable result.
					# A class with a degenerate-draw rule (ratio estimands) uses
					# min_fraction_usable_samples instead (m_out_of_n_bootstrap_centered_pivot();
					# v1.0.6-TODO-204; default 0.8, stricter than this gate).
					has_ratio_rule = !is.null(edi_ratio_resampling_degenerate_rule(self, private))
					if (!has_ratio_rule && length(boot) > 0L && length(finite) / length(boot) < 0.5) {
						return(list(ok = FALSE, reason = "m_out_of_n_high_replicate_failure_rate"))
					}
					pivot = list(
						ok = TRUE,
						reason = NA_character_,
						est = est,
						finite = finite,
						centered_scaled = private$resampling_scaling_factor(m, scaling) * (finite - est),
						m = as.integer(m),
						n_units = unit_info$n_units,
						scaling = scaling,
						n_draws = length(boot),
						n_degenerate = sum(is.nan(boot))
					)
					pivot
				})()
				if (!isTRUE(pivot$ok)) return(pivot)
				private$set_cached_centered_resampling_pivot("m_out_of_n_boot", cache_key, pivot)
			}
			# v1.0.6-TODO-164 / 269: a ratio estimand with degenerate (NaN) or failed (NA) draws needs
			# min_fraction_usable_samples of the B resamples to be usable. Checked after the cache so a
			# pivot built under one cap is judged under the cap of each call.
			too_few_usable = edi_ratio_resampling_usable_fraction_failure(self, private, "m_out_of_n",
				n_total = pivot$n_draws %||% length(pivot$finite), n_usable = length(pivot$finite),
				n_degenerate = pivot$n_degenerate %||% 0L, min_fraction = min_fraction_usable_samples)
			if (!is.null(too_few_usable)) return(too_few_usable)
			pivot
		},
		resampling_scaling_key = function(scaling){
			if (is.character(scaling)) return(paste(scaling, collapse = ","))
			if (is.list(scaling)) return(paste(names(scaling), unlist(scaling), collapse = ","))
			if (is.function(scaling)) return("<function>")
			as.character(scaling)[1L]
		},
		m_out_of_n_bootstrap_sample_indices = function(m, bootstrap_type = NULL){
			unit_info = private$get_exchangeable_units(unit = "auto", resampling_type = bootstrap_type)
			selected = private$sample_exchangeable_unit_ids(
				unit_info = unit_info,
				size = as.integer(m),
				replace = TRUE,
				stratified = !identical(bootstrap_type, "resample_blocks")
			)
			private$build_resampling_draw_from_units(unit_info, selected, size_label = "m", preserve_order = FALSE)
		},
		load_m_out_of_n_bootstrap_draw_into_worker = function(worker_state, draw, ...){
			private$load_bootstrap_sample_into_worker(worker_state, draw)
			invisible(worker_state)
		},
		evaluate_m_out_of_n_bootstrap_size = function(m, B, alpha, bootstrap_type = NULL, scaling = "sqrt_n", show_progress = FALSE){
			private$check_bootstrap_replicate_deadline("m-out-of-n bootstrap m selection")
			unit_info = private$get_exchangeable_units(unit = "auto", resampling_type = bootstrap_type)
			m = private$resolve_resampling_size(m, unit_info$n_units, "m")
			est = tryCatch(as.numeric(self$compute_estimate(estimate_only = TRUE))[1L], error = private$resampling_error_to_na)
			if (!is.finite(est)) {
				return(list(status = "nonestimable", dominant_failure_reason = "m_out_of_n_original_estimate_unavailable", finite_fraction = 0, n_finite = 0L))
			}
			boot = self$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = B, m = m, show_progress = show_progress, bootstrap_type = bootstrap_type, scaling = scaling)
			finite = boot[is.finite(boot)]
			centered_scaled = private$resampling_scaling_factor(m, scaling) * (finite - est)
			ci = private$resampling_ci_from_centered_distribution(centered_scaled, alpha = alpha, est = est, n_units = unit_info$n_units, scaling = scaling)
			pval = private$resampling_centered_pval(centered_scaled, est = est, delta = 0, n_units = unit_info$n_units, scaling = scaling)
			ci_ok = length(finite) > 0L &&
				all(is.finite(ci[1:2])) &&
				!private$bootstrap_confidence_interval_extreme(ci, est = est)
			list(
				status = if (ci_ok) "ok" else "nonestimable",
				estimate = est,
				ci = ci,
				pval = pval,
				n_finite = length(finite),
				finite_fraction = length(finite) / as.integer(B),
				dominant_failure_reason = if (!length(finite)) {
					"m_out_of_n_too_few_finite_estimates"
				} else if (!isTRUE(ci_ok)) {
					"m_out_of_n_extreme_confidence_interval"
				} else {
					NA_character_
				}
			)
		}
	)
)
