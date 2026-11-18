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
			val = private$compute_jackknife_summary(unit = unit)$estimate
			if (!is.finite(val)) edi_warn_jackknife_na(self, private, "compute_jackknife_estimate()")
			val
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
			val = private$compute_jackknife_summary(unit = unit)$bias
			if (!is.finite(val)) edi_warn_jackknife_na(self, private, "compute_jackknife_bias_estimate()")
			val
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
			val = private$compute_jackknife_summary(unit = unit)$std_error
			if (!is.finite(val)) edi_warn_jackknife_na(self, private, "compute_jackknife_std_error()")
			val
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
				assertNumeric(delta, len = 1, finite = TRUE, any.missing = FALSE)
			}
			jack_summary = private$compute_jackknife_summary(unit = unit)
			se_j = jack_summary$std_error
			if (!is.finite(jack_summary$estimate)) {
				edi_warn_jackknife_na(self, private, "compute_jackknife_wald_two_sided_pval()", fallback_reason = "jackknife_estimate_unavailable")
				if (isTRUE(private$harden)) private$cache_procedure_failure("jackknife", "jackknife_estimate_unavailable")
				return(NA_real_)
			}
			if (!is.finite(se_j) || se_j <= 0) {
				edi_warn_jackknife_na(self, private, "compute_jackknife_wald_two_sided_pval()", fallback_reason = "jackknife_standard_error_unavailable")
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
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
			}
			jack_summary = private$compute_jackknife_summary(unit = unit)
			se_j = jack_summary$std_error
			ci = c(NA_real_, NA_real_)
			names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
			if (!is.finite(jack_summary$estimate)) {
				edi_warn_jackknife_na(self, private, "compute_jackknife_wald_confidence_interval()", fallback_reason = "jackknife_estimate_unavailable")
				if (isTRUE(private$harden)) private$cache_procedure_failure("jackknife", "jackknife_estimate_unavailable")
				return(ci)
			}
			if (!is.finite(se_j) || se_j <= 0) {
				edi_warn_jackknife_na(self, private, "compute_jackknife_wald_confidence_interval()", fallback_reason = "jackknife_standard_error_unavailable")
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
		# v1.0.6-TODO-122: TRUE when the full-data fit is (quasi-)completely
		# separated, so compute_jackknife_summary() returns NA (reason
		# "jackknife_full_data_separation") instead of jackknifing a fit with no
		# finite solution. Default FALSE; the KK GEE classes override it.
		jackknife_full_fit_is_separated = function(){
			FALSE
		},
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
			# v1.0.6-TODO-122: when the full-data fit is (quasi-)completely
			# separated, every leave-one-unit-out fit stops wherever the fitter
			# gave up too, so the jackknife bias, SE and bias-corrected estimate
			# describe the fitter's stopping rule, not the data (KK incidence GEE
			# repro: estimate 50.5, jackknife estimate -384, SE 434, p 0.38).
			# Classes that can tell override jackknife_full_fit_is_separated().
			if (isTRUE(private$jackknife_full_fit_is_separated())) {
				private$cache_procedure_failure("jackknife", "jackknife_full_data_separation")
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
			# v1.0.6-TODO-135: with G deletion units the delete-1 jackknife variance
			# has G - 1 degrees of freedom, but the Wald p-value and CI below use
			# the normal reference. See EDI_JACKKNIFE_MIN_DELETION_UNITS.
			if (n_units < EDI_JACKKNIFE_MIN_DELETION_UNITS) {
				private$cached_values$jackknife_n_deletion_units = list(n = n_units, unit = private$resolve_jackknife_unit(unit))
				private$cache_procedure_failure("jackknife", "jackknife_too_few_deletion_units")
				summary = list(estimate = NA_real_, bias = NA_real_, std_error = NA_real_, distribution = jack)
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

# v1.0.6-TODO-135: fewest deletion units (blocks, clusters, pairs, matched sets
# or observations) for which compute_jackknife_summary() reports a jackknife
# estimate, bias and SE; below it they are NA with an edi_procedure_na_warning.
# With G units the delete-1 jackknife variance behaves like a chi-square with
# G - 1 df (Efron & Stein 1981; Shao & Tu 1995, ch. 2), so the SE's own
# coefficient of variation is about sqrt(2 / (G - 1)): 1.41, 1.00, 0.82 at
# G = 2, 3, 4. The jackknife-Wald p-value and CI use the normal reference
# (qnorm / pnorm), not t_{G-1}, so even in the ideal case (studentized
# estimate exactly t_{G-1}) a nominal 95% interval covers only 70%, 81% and
# 86% at G = 2, 3, 4 (88% at 5, 92% at 10). The small-G cluster literature
# (Cameron & Miller 2015; Bell & McCaffrey 2002) draws the line at about 5
# units. Fewer than 5 is therefore NA; 5 or more is unchanged.
EDI_JACKKNIFE_MIN_DELETION_UNITS = 5L

# Warn when a public jackknife method hands back NA (v1.0.6-TODO-113, the
# v1.0.6-TODO-95 rule). Names the specific reason compute_jackknife_summary()
# recorded (the public methods overwrite it with the generic
# "jackknife_estimate_unavailable" right after this call), or fallback_reason. Silent during
# resampling (see edi_warn_procedure_na()).
edi_warn_jackknife_na = function(self, private, method, fallback_reason = "jackknife_estimate_unavailable"){
	why = private$cached_values$procedure_failure_reason$jackknife
	if (!is.character(why) || !length(why) || is.na(why[1L])) why = private$cached_values$nonestimable_reason
	if (!is.character(why) || !length(why) || is.na(why[1L])) why = fallback_reason
	why = why[1L]
	# Later calls see the generic reason the first call wrote over the specific
	# one; reuse the specific one remembered here.
	if (why %in% c("jackknife_estimate_unavailable", "jackknife_standard_error_unavailable") &&
		is.character(private$cached_values$jackknife_na_specific_reason)) {
		why = private$cached_values$jackknife_na_specific_reason
	} else if (!why %in% c("jackknife_estimate_unavailable", "jackknife_standard_error_unavailable")) {
		private$cached_values$jackknife_na_specific_reason = why
	}
	detail = switch(why,
		jackknife_extreme_summary = paste0("The jackknife bias exceeds twice its standard error, or the jackknife ",
			"estimate or standard error is extreme; this is typical when the full-data fit is at or near separation ",
			"(e.g. one arm almost entirely in one outcome category), where no finite estimate is trustworthy."),
		jackknife_extreme_finite_estimates = "Some leave-one-unit-out estimates are extreme (near separation).",
		jackknife_full_data_separation = paste0("The full-data fit is (quasi-)completely separated (fitted ",
			"probabilities numerically 0 or 1), so the estimate and every leave-one-unit-out estimate are where the ",
			"fitter stopped, and the jackknife bias and standard error are not meaningful. Use a randomization test ",
			"(compute_rand_two_sided_pval())."),
		jackknife_nonfinite_replicate_estimates = "Some leave-one-unit-out fits failed.",
		jackknife_too_few_replicate_estimates = "There are too few deletion units for a jackknife.",
		jackknife_too_few_deletion_units = paste0("The jackknife has only ",
			as.integer(private$cached_values$jackknife_n_deletion_units$n %||% NA_integer_), " deletion units (unit = \"",
			private$cached_values$jackknife_n_deletion_units$unit %||% "auto", "\"); at least ",
			EDI_JACKKNIFE_MIN_DELETION_UNITS, " are needed. With G units the jackknife variance has only G - 1 degrees ",
			"of freedom, so the standard error is too unstable for a normal-reference Wald test or interval. ",
			"Use a randomization test (compute_rand_two_sided_pval()) or the model-based standard error."),
		jackknife_original_estimate_unavailable = "The full-data estimate is not available.",
		NULL
	)
	edi_warn_procedure_na(self, private, procedure = method, reason = why, detail = detail)
}
