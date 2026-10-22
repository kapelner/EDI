#' Jackknife-based Inference
#'
#' Abstract class for delete-1 jackknife estimate correction and jackknife-Wald
#' inference layered on top of bootstrap-capable inference classes.
#'
#' @keywords internal
InferenceJackknife = R6::R6Class("InferenceJackknife",
	lock_objects = FALSE,
	inherit = InferenceBayesianBootstrap,
	public = list(
		#' @description Returns the leave-one-out jackknife estimate distribution.
		#'
		#' @param unit Deletion unit. Default `\"auto\"`, which chooses a design-aware
		#'   unit automatically.
		#'
		#' @return A numeric vector of jackknife replicate estimates.
		approximate_jackknife_distribution_beta_hat_T = function(unit = "auto"){
			unit = private$normalize_jackknife_unit(unit)
			if (private$mark_jackknife_nonestimable_if_block_unsupported(unit = unit)) return(numeric(0))
			private$assert_jackknife_supported(unit = unit)
			as.numeric(private$approximate_jackknife_distribution_beta_hat_T_private(unit = unit))
		},
		#' @description Computes the delete-1 jackknife bias-corrected treatment estimate.
		#'
		#' For blocking designs, this uses leave-one-block-out deletion units. For
		#' matching designs, it uses leave-match-out deletion units. For KK designs,
		#' it uses leave-match-out for matched pairs and leave-one-out for reservoir
		#' subjects.
		#'
		#' @param unit Deletion unit. Default `\"auto\"`, which chooses a design-aware
		#'   unit automatically.
		#'
		#' @return A numeric jackknife bias-corrected treatment estimate.
		compute_jackknife_estimate = function(unit = "auto"){
			unit = private$normalize_jackknife_unit(unit)
			if (private$mark_jackknife_nonestimable_if_block_unsupported(unit = unit)) return(NA_real_)
			private$assert_jackknife_supported(unit = unit)
			private$compute_jackknife_summary(unit = unit)$estimate
		},
		#' @description Computes the jackknife bias estimate.
		#'
		#' @param unit Deletion unit. Default `\"auto\"`.
		#'
		#' @return A numeric jackknife bias estimate.
		compute_jackknife_bias_estimate = function(unit = "auto"){
			unit = private$normalize_jackknife_unit(unit)
			if (private$mark_jackknife_nonestimable_if_block_unsupported(unit = unit)) return(NA_real_)
			private$assert_jackknife_supported(unit = unit)
			private$compute_jackknife_summary(unit = unit)$bias
		},
		#' @description Computes the delete-1 jackknife standard error.
		#'
		#' For blocking designs, this uses leave-one-block-out deletion units. For
		#' matching designs, it uses leave-match-out deletion units. For KK designs,
		#' it uses leave-match-out for matched pairs and leave-one-out for reservoir
		#' subjects.
		#'
		#' @param unit Deletion unit. Default `\"auto\"`, which chooses a design-aware
		#'   unit automatically.
		#'
		#' @return A numeric jackknife standard error.
		compute_jackknife_std_error = function(unit = "auto"){
			unit = private$normalize_jackknife_unit(unit)
			if (private$mark_jackknife_nonestimable_if_block_unsupported(unit = unit)) return(NA_real_)
			private$assert_jackknife_supported(unit = unit)
			private$compute_jackknife_summary(unit = unit)$std_error
		},
		#' @description Computes a two-sided Wald p-value using the jackknife estimate
		#'   and jackknife standard error.
		#'
		#' For blocking designs, this uses leave-one-block-out deletion units. For
		#' matching designs, it uses leave-match-out deletion units. For KK designs,
		#' it uses leave-match-out for matched pairs and leave-one-out for reservoir
		#' subjects.
		#'
		#' @param delta Null treatment-effect value. Default 0.
		#' @param unit Deletion unit. Default `\"auto\"`, which chooses a design-aware
		#'   unit automatically.
		#'
		#' @return A two-sided jackknife-Wald p-value.
		compute_jackknife_wald_two_sided_pval = function(delta = 0, unit = "auto"){
			unit = private$normalize_jackknife_unit(unit)
			if (private$mark_jackknife_nonestimable_if_block_unsupported(unit = unit)) return(NA_real_)
			private$assert_jackknife_supported(unit = unit)
			if (should_run_asserts()) {
				assertNumeric(delta, len = 1)
			}
			jack_summary = private$compute_jackknife_summary(unit = unit)
			se_j = jack_summary$std_error
			if (!is.finite(jack_summary$estimate)) {
				if (isTRUE(private$harden)) private$cache_procedure_failure("jackknife", "jackknife_estimate_unavailable")
				return(NA_real_)
			}
			if (!is.finite(se_j) || se_j <= 0) {
				if (isTRUE(private$harden)) private$cache_procedure_failure("jackknife", "jackknife_standard_error_unavailable")
				return(NA_real_)
			}
			theta_j = as.numeric(jack_summary$estimate)[1L]
			2 * stats::pnorm(-abs((theta_j - delta) / se_j))
		},
		#' @description Computes a normal-approximation confidence interval using the
		#'   jackknife estimate and jackknife standard error.
		#'
		#' For blocking designs, this uses leave-one-block-out deletion units. For
		#' matching designs, it uses leave-match-out deletion units. For KK designs,
		#' it uses leave-match-out for matched pairs and leave-one-out for reservoir
		#' subjects.
		#'
		#' @param alpha Significance level. Default 0.05.
		#' @param unit Deletion unit. Default `\"auto\"`, which chooses a design-aware
		#'   unit automatically.
		#'
		#' @return A jackknife-Wald confidence interval.
		compute_jackknife_wald_confidence_interval = function(alpha = 0.05, unit = "auto"){
			unit = private$normalize_jackknife_unit(unit)
			if (private$mark_jackknife_nonestimable_if_block_unsupported(unit = unit)) {
				ci = c(NA_real_, NA_real_)
				names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
				return(ci)
			}
			private$assert_jackknife_supported(unit = unit)
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
			}
			jack_summary = private$compute_jackknife_summary(unit = unit)
			se_j = jack_summary$std_error
			ci = c(NA_real_, NA_real_)
			names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
			if (!is.finite(jack_summary$estimate)) {
				if (isTRUE(private$harden)) private$cache_procedure_failure("jackknife", "jackknife_estimate_unavailable")
				return(ci)
			}
			if (!is.finite(se_j) || se_j <= 0) {
				if (isTRUE(private$harden)) private$cache_procedure_failure("jackknife", "jackknife_standard_error_unavailable")
				return(ci)
			}
			theta_j = as.numeric(jack_summary$estimate)[1L]
			z = stats::qnorm(1 - alpha / 2)
			ci[] = c(theta_j - z * se_j, theta_j + z * se_j)
			ci
		}
	),
	private = list(
		# Whether jackknife is *permanently* unsupported for this class --
		# a per-class constant, true for every dataset, as opposed to a
		# particular fit happening to be data-dependently nonestimable
		# (e.g. insufficient block structure for THIS design instance).
		# Default `FALSE`; the Hodges-Lehmann Wilcoxon-shift families
		# (`InferenceAllSimpleWilcox`/`InferenceAllKKWilcoxIVWC`) override
		# `TRUE` -- their delete-1 jackknife always reports non-estimable
		# regardless of data (the median-of-pairwise-differences functional
		# isn't smooth enough for it), so `run_all_inference()` can skip
		# generating a doomed "jackknife" task for them entirely (per user
		# report, 2026-08-24: "it seems this class-method is never
		# estimable") rather than every fit predictably landing on
		# `status = "nonest"`.
		jackknife_always_nonestimable = function(){
			FALSE
		},
		# normalize_jackknife_unit() and assert_jackknife_supported() moved
		# unchanged to ResamplingCore (v1.0.5 TODO-97, 2026-10-22): both this
		# component and NonparametricBootstrap call them, and they were the
		# NonparametricBootstrap -> Jackknife half of the old dependency cycle.
		# resolve_jackknife_unit(), jackknife_block_size_gt_one_unsupported() and
		# mark_jackknife_nonestimable_if_block_unsupported() live only in
		# NonparametricBootstrap (every class with Jackknife also has it). The
		# duplicate copies here were removed 2026-10-22 so there is one path: the
		# NonparametricBootstrap body re-raises EDI resampling control conditions
		# (interrupts/timeouts) from get_block_ids() and swallows only other errors.
		jackknife_cache_key = function(unit = "auto"){
			private$resolve_jackknife_unit(unit)
		},
		compute_jackknife_summary = function(unit = "auto"){
			unit = private$normalize_jackknife_unit(unit)
			if (private$mark_jackknife_nonestimable_if_block_unsupported(unit = unit)) {
				return(list(estimate = NA_real_, bias = NA_real_, std_error = NA_real_, distribution = numeric(0)))
			}
			cache_key = private$jackknife_cache_key(unit)
			if (is.null(private$cached_values$jackknife_summary)) {
				private$cached_values$jackknife_summary = list()
			}
			if (!is.null(private$cached_values$jackknife_summary[[cache_key]])) {
				return(private$cached_values$jackknife_summary[[cache_key]])
			}
			theta_hat = tryCatch(as.numeric(self$compute_estimate(estimate_only = TRUE))[1L], error = function(e) NA_real_)
			if (is.function(self$is_nonestimable) && isTRUE(self$is_nonestimable("estimate"))) {
				theta_hat = NA_real_
			}
			if (!is.finite(theta_hat)) {
				private$cache_nonestimable_estimate("jackknife_original_estimate_unavailable")
				summary = list(estimate = NA_real_, bias = NA_real_, std_error = NA_real_, distribution = numeric(0))
				private$cached_values$jackknife_summary[[cache_key]] = summary
				return(summary)
			}
			jack = as.numeric(private$approximate_jackknife_distribution_beta_hat_T_private(unit = unit))
			n_units = length(jack)
			if (n_units <= 1L) {
				private$cache_procedure_failure("jackknife", "jackknife_too_few_replicate_estimates")
				summary = list(estimate = NA_real_, bias = NA_real_, std_error = NA_real_, distribution = numeric(0))
				private$cached_values$jackknife_summary[[cache_key]] = summary
				return(summary)
			}
			if (any(!is.finite(jack))) {
				private$cache_procedure_failure("jackknife", "jackknife_nonfinite_replicate_estimates")
				summary = list(estimate = NA_real_, bias = NA_real_, std_error = NA_real_, distribution = jack)
				private$cached_values$jackknife_summary[[cache_key]] = summary
				return(summary)
			}
			if (private$bootstrap_estimates_extreme(jack, est = theta_hat)) {
				private$cache_procedure_failure("jackknife", "jackknife_extreme_finite_estimates")
				summary = list(estimate = NA_real_, bias = NA_real_, std_error = NA_real_, distribution = jack)
				private$cached_values$jackknife_summary[[cache_key]] = summary
				return(summary)
			}
			jack_bar = mean(jack)
			bias_j = (n_units - 1) * (jack_bar - theta_hat)
			theta_j = theta_hat - bias_j
			var_j = ((n_units - 1) / n_units) * sum((jack - jack_bar)^2)
			se_j = if (is.finite(var_j) && var_j >= 0) sqrt(var_j) else NA_real_
			if (!is.finite(theta_j) || !is.finite(se_j) ||
			    abs(theta_j) > private$bootstrap_extreme_estimate_threshold ||
			    se_j > private$bootstrap_extreme_estimate_threshold ||
			    abs(bias_j) > 2 * se_j) {
				private$cache_procedure_failure("jackknife", "jackknife_extreme_summary")
				summary = list(estimate = NA_real_, bias = NA_real_, std_error = NA_real_, distribution = jack)
				private$cached_values$jackknife_summary[[cache_key]] = summary
				return(summary)
			}
			summary = list(estimate = theta_j, bias = bias_j, std_error = se_j, distribution = jack)
			private$cached_values$jackknife_summary[[cache_key]] = summary
			summary
		}
	)
)
