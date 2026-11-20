#' Jackknife-based Inference
#'
#' Abstract class for delete-1 jackknife estimate correction and jackknife-Wald
#' inference layered on top of bootstrap-capable inference classes.
#'
#' @details
#' \strong{Deletion units.} With \code{unit = "auto"} each replicate deletes one unit
#' of the design's randomization structure:
#' \itemize{
#'   \item matching designs: one matched pair (\code{"pair"}), or for KK designs one
#'     matched set or one reservoir subject (\code{"matched_set"});
#'   \item cluster designs: one cluster (\code{"cluster"});
#'   \item \code{\link[EDI:DesignSeqOneByOneSPBR]{DesignSeqOneByOneSPBR}}: one permuted
#'     block (\code{"permuted_block"}), the \code{block_size} consecutive enrollees of
#'     a stratum that the design randomized together; a trailing partial block of a
#'     stratum is merged into that stratum's previous block;
#'   \item \code{\link[EDI:DesignSeqOneByOneRandomBlockSize]{DesignSeqOneByOneRandomBlockSize}}:
#'     one permuted block (\code{"permuted_block"}), as recorded when the design drew it
#'     (block sizes are random), with the same rule for a stratum's trailing unfilled block;
#'     a design object saved before EDI 1.0.6 has no such record and uses \code{"block"};
#'   \item on both of these designs, when any stratum holds fewer than 5 permuted-block
#'     units, one subject grouped by its stratum (\code{"observation_within_block"})
#'     instead: with 3-4 blocks in a stratum the permuted-block jackknife-Wald test
#'     rejected a true null too often (size 0.082 at a nominal 0.05, against 0.055
#'     deleting single subjects; v1.0.6-TODO-270);
#'   \item \code{\link[EDI:DesignFixedBlocking]{DesignFixedBlocking}}: one subject,
#'     grouped by its stratum (\code{"observation_within_block"});
#'   \item \code{\link[EDI:ObservationalDesignBlocks]{ObservationalDesignBlocks}}: one whole
#'     block (\code{"block"}, right for matched sets and clusters) when there are at least
#'     5 blocks; with fewer, one subject grouped by its block as a stratum
#'     (\code{"observation_within_block"}), since leave-one-block-out would have too few
#'     units (v1.0.6-TODO-231);
#'   \item other blocking designs: one whole block (\code{"block"});
#'   \item all other designs: one subject (\code{"observation"}).
#' }
#' Any of these can also be requested explicitly through \code{unit}
#' (\code{"permuted_block"} only on SPBR and RandomBlockSize; \code{"block"} and
#' \code{"observation_within_block"} on any blocking design).
#'
#' \strong{Formulas.} With \eqn{\hat\theta} the full-data estimate and
#' \eqn{\hat\theta_{(i)}} the estimate with unit \eqn{i} deleted, an unstratified unit
#' (\eqn{G} units, mean \eqn{\bar\theta}) gives bias
#' \eqn{(G - 1)(\bar\theta - \hat\theta)} and variance
#' \eqn{\frac{G - 1}{G} \sum_i (\hat\theta_{(i)} - \bar\theta)^2}. The two stratified
#' units (\code{"permuted_block"}, \code{"observation_within_block"}) use the stratified
#' delete-1 ("JKn") jackknife of Wolter (2007, Sec. 4.5). Wolter's replicate deletes unit
#' \eqn{i} of stratum \eqn{h} and reweights that stratum's other \eqn{n_h - 1} units by
#' \eqn{n_h/(n_h - 1)}; EDI's replicates are refits on the remaining rows without
#' reweighting, so each replicate's departure from \eqn{\hat\theta} is first scaled by
#' \eqn{r_h = n_h (N - 1) / \{N (n_h - 1)\}} (\eqn{N} units in all), its first-order
#' reweighted equivalent: \eqn{\theta^*_{(h,i)} = \hat\theta + r_h (\hat\theta_{(h,i)} - \hat\theta)}.
#' With \eqn{\bar\theta^*_h} the stratum mean of these, Wolter's formulas give bias
#' \eqn{\sum_h (n_h - 1)(\bar\theta^*_h - \hat\theta)} and variance
#' \eqn{\sum_h \frac{n_h - 1}{n_h} \sum_{i \in h} (\theta^*_{(h,i)} - \bar\theta^*_h)^2
#' = (\frac{N - 1}{N})^2 \sum_h \frac{n_h}{n_h - 1} \sum_{i \in h} (\hat\theta_{(h,i)} - \bar\theta_h)^2};
#' with no single-unit stratum the bias equals the ordinary \eqn{(N - 1)(\bar\theta - \hat\theta)},
#' and with one stratum both reduce to the unstratified formulas.
#'
#' \emph{Why the replicates are rescaled, and what that does to the bias.} Deleting unit
#' \eqn{(h, i)} and refitting on the other \eqn{N - 1} units moves the estimate by about
#' \eqn{1/(N - 1)} of that unit's influence and also shifts every stratum's share of the
#' data; Wolter's reweighted replicate keeps stratum \eqn{h}'s share and moves the estimate
#' by \eqn{n_h / \{N (n_h - 1)\}} of the unit's influence measured from its stratum mean. To
#' first order the two differ, within a stratum, by the factor \eqn{r_h} and a constant,
#' and the constant cancels in the within-stratum variance; so the rescaled variance is
#' Wolter's to first order, while Wolter's weight \eqn{(n_h - 1)/n_h} applied to the raw
#' refits would understate it by about \eqn{((n_h - 1)/n_h)^2} per stratum. The bias form
#' \eqn{\sum_h (n_h - 1)(\bar\theta^*_h - \hat\theta)} is the stratified jackknife bias
#' of Jones (1974), as in Wolter (2007, Sec. 4.5): on genuinely reweighted replicates it
#' estimates the bias of a smooth function of the stratum means from the within-stratum
#' spread alone. The bias is a second-order quantity, though, and the first-order
#' rescaling does not carry it over: on the rescaled refits the formula equals the
#' ordinary unstratified bias \eqn{(N - 1)(\bar\theta - \hat\theta)}, which also counts the
#' spread of the outcome between strata. For a linear estimator (a difference in means)
#' both are 0; for a nonlinear one with strongly different strata the bias correction can
#' be too large (v1.0.6-TODO-231). The jackknife-Wald test and interval are centred at the
#' bias-corrected estimate.
#' The strata are fixed by the design and treatment is randomized within them, so only
#' the within-stratum spread of the replicates enters the variance. A stratum with a
#' single unit contributes nothing to either sum. The bias-corrected jackknife estimate is
#' \eqn{\hat\theta} minus the bias, and the jackknife-Wald test and interval use it with
#' the jackknife standard error. The reference distribution is the normal for the
#' unstratified units and, since EDI 1.0.6, the t distribution with
#' \eqn{\sum_h (n_h - 1)} degrees of freedom (the degrees of freedom of the stratified
#' variance) for the stratified units \code{"permuted_block"} and
#' \code{"observation_within_block"} (v1.0.6-TODO-231: on SPBR with about 31 degrees of
#' freedom the normal-reference 95\% interval covered 0.930 and the t interval 0.943).
#' They are \code{NA} when the variance has fewer than 4 degrees of freedom
#' (\eqn{G - 1}, or \eqn{\sum_h (n_h - 1)} for the stratified units).
#'
#' Before EDI 1.0.6 the automatic unit on SPBR and \code{DesignFixedBlocking} was the
#' block, which on these designs is the stratum, so a replicate deleted a whole stratum
#' and the jackknife had only 2-4 units (v1.0.6-TODO-4).
#'
#' \strong{BCa acceleration.} The BCa bootstrap interval and p-value of the nonparametric
#' bootstrap take their acceleration from the same jackknife. On the stratified units it is
#' the skewness of the empirical influence values centred within strata,
#' \eqn{a = \sum_h c_h^3 \sum_i d_{hi}^3 / \{6 (\sum_h c_h^2 \sum_i d_{hi}^2)^{3/2}\}} with
#' \eqn{d_{hi} = \bar\theta^*_h - \theta^*_{(h,i)}} and \eqn{c_h = (n_h - 1)/n_h} (the
#' stratified form of the influence-function acceleration, Davison and Hinkley 1997); with
#' one stratum this is Efron's formula, and other units keep it unchanged.
#'
#' @references Jones, H. L. (1974). Jackknife estimation of functions of stratum means.
#'   \emph{Biometrika}, 61(2), 343-348, \doi{10.1093/biomet/61.2.343}.
#'
#'   Krewski, D. and Rao, J. N. K. (1981). Inference from stratified samples: properties of
#'   the linearization, jackknife and balanced repeated replication methods. \emph{The
#'   Annals of Statistics}, 9(5), 1010-1019, \doi{10.1214/aos/1176345580}.
#'
#'   Davison, A. C. and Hinkley, D. V. (1997). \emph{Bootstrap Methods and their
#'   Application}. Cambridge University Press, \doi{10.1017/CBO9780511802843}.
#'
#'   Wolter, K. M. (2007). \emph{Introduction to Variance Estimation}, 2nd ed.
#'   Springer, New York, ch. 4 "The Jackknife Method" (pp. 151-193), Sec. 4.5 (stratified
#'   sampling), \doi{10.1007/978-0-387-35099-8}.
#'
#' @keywords internal
InferenceJackknife = R6::R6Class("InferenceJackknife",
	lock_objects = FALSE,
	inherit = InferenceBayesianBootstrap,
	public = list(
		#' @description Returns the leave-one-out jackknife estimate distribution.
		#'
		#' @param unit Deletion unit: \code{"auto"} (default, design-aware), \code{"observation"},
		#'   \code{"block"}, \code{"cluster"}, \code{"pair"}, \code{"matched_set"},
		#'   \code{"permuted_block"} or \code{"observation_within_block"}; see
		#'   \strong{Deletion units} in \code{\link[EDI:InferenceJackknife]{InferenceJackknife}}.
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
		#' The automatic deletion unit (\code{unit = "auto"}) follows the design: see
		#' \strong{Deletion units} in \code{\link[EDI:InferenceJackknife]{InferenceJackknife}}.
		#' The estimate is the full-data estimate minus
		#' \code{$compute_jackknife_bias_estimate()}; see that method for a caveat on the
		#' stratified units (\code{"permuted_block"}, \code{"observation_within_block"}).
		#'
		#' @param unit Deletion unit: \code{"auto"} (default, design-aware), \code{"observation"},
		#'   \code{"block"}, \code{"cluster"}, \code{"pair"}, \code{"matched_set"},
		#'   \code{"permuted_block"} or \code{"observation_within_block"}; see
		#'   \strong{Deletion units} in \code{\link[EDI:InferenceJackknife]{InferenceJackknife}}.
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
		#' Unstratified units: \eqn{(G - 1)(\bar\theta - \hat\theta)}. Stratified units
		#' (\code{"permuted_block"}, \code{"observation_within_block"}): the stratified
		#' jackknife bias \eqn{\sum_h (n_h - 1)(\bar\theta^*_h - \hat\theta)} (Jones 1974;
		#' Wolter 2007, Sec. 4.5) applied to EDI's leave-unit-out refits rescaled to their
		#' first-order reweighted equivalents. That rescaling is exact enough for the variance
		#' but not for this second-order quantity: the result equals the ordinary
		#' \eqn{(N - 1)(\bar\theta - \hat\theta)}, which also counts the spread of the outcome
		#' between strata. It is 0 for a difference in means; for a nonlinear estimator
		#' (log odds ratio, log hazard ratio, ...) with strongly different strata it can be
		#' too large (in simulations up to about 0.4 standard errors), and so can the shift of
		#' \code{$compute_jackknife_estimate()} and of the jackknife-Wald interval centre.
		#' See \strong{Formulas} in \code{\link[EDI:InferenceJackknife]{InferenceJackknife}}.
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
		#' The automatic deletion unit (\code{unit = "auto"}) follows the design: see
		#' \strong{Deletion units} in \code{\link[EDI:InferenceJackknife]{InferenceJackknife}}.
		#'
		#' @param unit Deletion unit: \code{"auto"} (default, design-aware), \code{"observation"},
		#'   \code{"block"}, \code{"cluster"}, \code{"pair"}, \code{"matched_set"},
		#'   \code{"permuted_block"} or \code{"observation_within_block"}; see
		#'   \strong{Deletion units} in \code{\link[EDI:InferenceJackknife]{InferenceJackknife}}.
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
		#' The automatic deletion unit (\code{unit = "auto"}) follows the design: see
		#' \strong{Deletion units} in \code{\link[EDI:InferenceJackknife]{InferenceJackknife}}.
		#' The reference distribution is the normal, except for the stratified units
		#' (\code{"permuted_block"}, \code{"observation_within_block"}), which use t with
		#' \eqn{\sum_h (n_h - 1)} degrees of freedom (EDI 1.0.6). The statistic is centred at
		#' the bias-corrected estimate; see \code{$compute_jackknife_bias_estimate()}.
		#'
		#' @param delta Null treatment-effect value. Default 0.
		#' @param unit Deletion unit: \code{"auto"} (default, design-aware), \code{"observation"},
		#'   \code{"block"}, \code{"cluster"}, \code{"pair"}, \code{"matched_set"},
		#'   \code{"permuted_block"} or \code{"observation_within_block"}; see
		#'   \strong{Deletion units} in \code{\link[EDI:InferenceJackknife]{InferenceJackknife}}.
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
			edi_jackknife_wald_pval((theta_j - delta) / se_j, jack_summary$df)
		},
		#' @description Computes a Wald confidence interval using the jackknife estimate
		#'   and jackknife standard error.
		#'
		#' The automatic deletion unit (\code{unit = "auto"}) follows the design: see
		#' \strong{Deletion units} in \code{\link[EDI:InferenceJackknife]{InferenceJackknife}}.
		#' The interval is estimate \eqn{\pm} quantile \eqn{\times} SE with the normal
		#' quantile, except for the stratified units (\code{"permuted_block"},
		#' \code{"observation_within_block"}), which use the t quantile with
		#' \eqn{\sum_h (n_h - 1)} degrees of freedom (EDI 1.0.6). It is centred at the
		#' bias-corrected estimate; see \code{$compute_jackknife_bias_estimate()}.
		#'
		#' @param alpha Significance level. Default 0.05.
		#' @param unit Deletion unit: \code{"auto"} (default, design-aware), \code{"observation"},
		#'   \code{"block"}, \code{"cluster"}, \code{"pair"}, \code{"matched_set"},
		#'   \code{"permuted_block"} or \code{"observation_within_block"}; see
		#'   \strong{Deletion units} in \code{\link[EDI:InferenceJackknife]{InferenceJackknife}}.
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
			z = edi_jackknife_wald_quantile(alpha, jack_summary$df)
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
			jack_strata = private$jackknife_replicate_strata(unit)
			if (n_units <= 1L) {
				private$cache_procedure_failure("jackknife", "jackknife_too_few_replicate_estimates")
				summary = list(estimate = NA_real_, bias = NA_real_, std_error = NA_real_, distribution = numeric(0))
				private$cached_values$jackknife_summary[[cache_key]] = summary
				return(summary)
			}
			# v1.0.6-TODO-135: with G deletion units the delete-1 jackknife variance
			# has G - 1 degrees of freedom, but the Wald p-value and CI below use
			# the normal reference. See EDI_JACKKNIFE_MIN_DELETION_UNITS.
			if (edi_jackknife_effective_units(n_units, jack_strata) < EDI_JACKKNIFE_MIN_DELETION_UNITS) {
				private$cached_values$jackknife_n_deletion_units = list(n = n_units, unit = private$resolve_jackknife_unit(unit),
					df = if (!is.null(jack_strata)) edi_jackknife_effective_units(n_units, jack_strata) - 1L)
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
			moments = edi_jackknife_bias_variance(jack, theta_hat, jack_strata)
			bias_j = moments$bias
			theta_j = theta_hat - bias_j
			var_j = moments$variance
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
			# v1.0.6-TODO-231 (owner decision 2026-11-20): the stratified units' Wald test and interval
			# use t with sum_h (n_h - 1) degrees of freedom; every other unit keeps the normal (df = Inf).
			df_j = if (is.null(jack_strata)) Inf else edi_jackknife_effective_units(n_units, jack_strata) - 1L
			summary = list(estimate = theta_j, bias = bias_j, std_error = se_j, distribution = jack, df = df_j)
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

# v1.0.6-TODO-270 (owner decision 2026-11-20): on DesignSeqOneByOneSPBR and
# DesignSeqOneByOneRandomBlockSize the automatic jackknife unit is the permuted
# block only when every stratum holds at least this many permuted-block units;
# otherwise resolve_jackknife_unit("auto") deletes one subject within its stratum
# ("observation_within_block", the stratified JKn jackknife of Wolter 2007,
# Sec. 4.5). With 3-4 blocks in the smallest stratum the permuted-block
# jackknife-Wald test was too liberal even with its t reference
# (InferenceCountPoisson, RandomBlockSize, prob_T 0.2, n 200, ~1: size 0.082
# [0.066, 0.101], against 0.055 deleting single subjects). 5 matches
# EDI_JACKKNIFE_MIN_DELETION_UNITS.
EDI_JACKKNIFE_MIN_PERMUTED_BLOCKS_PER_STRATUM = 5L

# v1.0.6-TODO-4: jackknife bias and variance from the replicate estimates `jack`
# (theta_(i), one per deletion unit) and the full-data estimate `theta_hat`.
# strata = NULL: the ordinary delete-1 / delete-a-group jackknife with G units,
#   bias = (G - 1) (theta_bar - theta_hat), v = ((G - 1) / G) sum_i (theta_(i) - theta_bar)^2
#   (the expressions are kept exactly as before, so these results are unchanged).
# strata = stratum id per replicate: the stratified delete-1 jackknife ("JKn"; Wolter
#   2007, Introduction to Variance Estimation, 2nd ed., ch. 4 pp. 151-193, Sec. 4.5).
#   With n_h units in stratum h, Wolter's replicate theta_(h,i) deletes unit i of stratum h
#   AND reweights the stratum's other units by n_h / (n_h - 1), so the stratum keeps its
#   weight; then
#     v = sum_h ((n_h - 1) / n_h) sum_i (theta_(h,i) - theta_bar_h)^2,
#     bias = sum_h (n_h - 1) (theta_bar_h - theta_hat)   (jackknife estimate theta_hat - bias).
#   EDI's replicates are refits on the remaining rows, with no reweighting, so a deletion
#   moves the estimate by about 1/(N - 1) of the unit's influence (N = all units) instead of
#   W_h / (n_h - 1) = n_h / (N (n_h - 1)). Each replicate's departure from theta_hat is
#   therefore scaled by r_h = n_h (N - 1) / (N (n_h - 1)), its first-order reweighted
#   equivalent, before Wolter's formulas are applied:
#     theta*_(h,i) = theta_hat + r_h (theta_(h,i) - theta_hat).
#   Then v = sum_h ((N - 1) / N)^2 (n_h / (n_h - 1)) sum_i (theta_(h,i) - theta_bar_h)^2, and
#   the bias is (N - 1)/N sum_h n_h (theta_bar_h - theta_hat), which is the ordinary
#   (N - 1)(theta_bar - theta_hat) when no stratum is a singleton. With one stratum both
#   reduce to the unstratified formulas. Applying (n_h - 1)/n_h to the unreweighted
#   replicates directly understates the variance by about ((n_h - 1)/n_h)^2 per stratum
#   (2026-11-19 study: SPBR, ~37 permuted blocks in 4 strata of 2-19 blocks, jackknife-Wald
#   coverage at beta 0 was 0.89-0.92 that way and 0.92-0.94 rescaled).
#   Centring at theta_bar_h drops the between-stratum spread of the replicate means, which
#   is not randomization variance when strata are fixed by the design. A stratum with one
#   unit (n_h = 1) contributes 0 to both sums (its weight n_h - 1 is 0).
#   v1.0.6-TODO-231 check of the bias (2026-11-19): sum_h (n_h - 1)(theta_bar_h - theta_hat) on
#   REWEIGHTED replicates is the stratified jackknife bias of Jones (1974) / Krewski & Rao (1981),
#   the form Wolter Sec. 4.5 uses; a second-order Taylor expansion of g(sum_h W_h ybar_h) gives
#   (n_h - 1) E(theta_bar_h - theta_hat) = g''/2 W_h^2 s_h^2 / n_h, stratum h's own bias term.
#   The r_h rescaling is first order only, so on rescaled refits the formula is the ordinary
#   bias above, which also carries the between-stratum spread of the data. Simulation (exp and
#   logistic g of a mean, 3-4 strata, 40000 reps): Jones on reweighted replicates 0.0854 / 0.0061 /
#   -0.0005 vs true 0.0815 / 0.0067 / -0.0004; this rescaled form 0.108 / 0.036 / -0.0028 (too
#   large when strata differ; 0 for a difference in means). Applying Jones to the raw refits is
#   worse (-0.10 / -0.088: the first-order term no longer cancels). Kept; owner decision filed.
edi_jackknife_bias_variance = function(jack, theta_hat, strata = NULL){
	n_units = length(jack)
	if (is.null(strata) || length(strata) != n_units) {
		jack_bar = mean(jack)
		return(list(
			bias = (n_units - 1) * (jack_bar - theta_hat),
			variance = ((n_units - 1) / n_units) * sum((jack - jack_bar)^2)
		))
	}
	bias = 0
	variance = 0
	for (h in unique(strata)) {
		th = jack[strata == h]
		n_h = length(th)
		if (n_h < 2L) next
		r_h = n_h * (n_units - 1) / (n_units * (n_h - 1))
		th_star = theta_hat + r_h * (th - theta_hat)
		th_star_bar = mean(th_star)
		bias = bias + (n_h - 1) * (th_star_bar - theta_hat)
		variance = variance + ((n_h - 1) / n_h) * sum((th_star - th_star_bar)^2)
	}
	list(bias = bias, variance = variance)
}

# v1.0.6-TODO-231: BCa acceleration from the jackknife replicates `jack` (finite, one per deletion
# unit). strata = NULL: Efron's a = sum (theta_bar - theta_(i))^3 / (6 (sum (theta_bar - theta_(i))^2)^(3/2))
#   (the expressions are kept exactly as before, so these results are unchanged).
# strata = stratum id per replicate (the stratified units of v1.0.6-TODO-4): the acceleration is the
#   skewness of the empirical influence values, and with strata fixed by the design those are centred
#   within their stratum, l_(h,i) = (n_h - 1)(theta_bar*_h - theta*_(h,i)), with theta* the
#   reweighting-equivalent replicates of edi_jackknife_bias_variance() (theta* - theta_bar*_h =
#   r_h (theta_(h,i) - theta_bar_h)). The stratified influence form (Davison & Hinkley 1997,
#   Bootstrap Methods and their Application, stratified case of the empirical influence values) is
#     a = sum_h n_h^-3 sum_i l_(h,i)^3 / (6 (sum_h n_h^-2 sum_i l_(h,i)^2)^(3/2)),
#   i.e. with d = theta_bar*_h - theta*_(h,i) and c_h = (n_h - 1)/n_h,
#     a = sum_h c_h^3 sum_i d^3 / (6 (sum_h c_h^2 sum_i d^2)^(3/2)).
#   With one stratum c_h cancels and this is Efron's formula. The unstratified formula instead centres
#   every replicate at the overall mean, so between-stratum differences of the replicate means (the
#   strata's different shares of the estimate, not sampling variation) entered the skewness.
#   Singleton strata contribute nothing (their within-stratum deviation is 0).
edi_jackknife_acceleration = function(jack, strata = NULL){
	if (is.null(strata) || length(strata) != length(jack)) {
		jack_bar = mean(jack)
		num = sum((jack_bar - jack)^3)
		den = 6 * (sum((jack_bar - jack)^2)^(3/2))
		return(if (is.finite(den) && den > 0) num / den else 0)
	}
	n_units = length(jack)
	num = 0
	ss = 0
	for (h in unique(strata)) {
		th = jack[strata == h]
		n_h = length(th)
		if (n_h < 2L) next
		r_h = n_h * (n_units - 1) / (n_units * (n_h - 1))
		d = r_h * (mean(th) - th)
		c_h = (n_h - 1) / n_h
		num = num + c_h^3 * sum(d^3)
		ss = ss + c_h^2 * sum(d^2)
	}
	den = 6 * ss^(3/2)
	if (is.finite(den) && den > 0) num / den else 0
}

# v1.0.6-TODO-231 (owner decision 2026-11-20): reference distribution of the jackknife-Wald test and
# interval. df = Inf (every unstratified unit) keeps the normal, with the exact expressions used before
# (pnorm / qnorm), so those results are unchanged; a finite df (the stratified units, df = sum_h (n_h - 1))
# uses t_df. With ~31 df on SPBR (n = 148, 4 strata) the z interval covered 0.930 and t_31 0.943.
edi_jackknife_wald_quantile = function(alpha, df = Inf){
	df = as.numeric(df %||% Inf)[1L]
	if (is.finite(df) && df > 0) stats::qt(1 - alpha / 2, df) else stats::qnorm(1 - alpha / 2)
}
edi_jackknife_wald_pval = function(stat, df = Inf){
	df = as.numeric(df %||% Inf)[1L]
	if (is.finite(df) && df > 0) 2 * stats::pt(-abs(stat), df) else 2 * stats::pnorm(-abs(stat))
}

# v1.0.6-TODO-4: the unit count compared with EDI_JACKKNIFE_MIN_DELETION_UNITS. With G
# unstratified units the jackknife variance has G - 1 degrees of freedom; with strata it
# has sum_h (n_h - 1), so the stratified count is that plus 1 (the same df threshold).
edi_jackknife_effective_units = function(n_units, strata = NULL){
	if (is.null(strata) || length(strata) != n_units) return(n_units)
	n_h = tabulate(match(strata, unique(strata)))
	sum(n_h - 1L) + 1L
}

# Warn when a public jackknife method hands back NA (v1.0.6-TODO-113, the
# v1.0.6-TODO-95 rule). Names the specific reason compute_jackknife_summary()
# recorded (the public methods overwrite it with the generic
# "jackknife_estimate_unavailable" right after this call), or fallback_reason. Silent during
# resampling (see edi_warn_procedure_na()).
edi_warn_jackknife_na = function(self, private, method, fallback_reason = "jackknife_estimate_unavailable", reason = NULL){
	# `reason`: the caller knows the reason it just recorded (the g-computation
	# risk-ratio path, v1.0.6-TODO-137), so a stale cached reason cannot be named.
	why = reason %||% private$cached_values$procedure_failure_reason$jackknife
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
		jackknife_too_few_deletion_units = if (!is.null(private$cached_values$jackknife_n_deletion_units$df)) paste0(
			"The stratified jackknife has ", as.integer(private$cached_values$jackknife_n_deletion_units$n), " deletion units (unit = \"",
			private$cached_values$jackknife_n_deletion_units$unit, "\") but only sum_h (n_h - 1) = ",
			as.integer(private$cached_values$jackknife_n_deletion_units$df), " degrees of freedom within strata; at least ",
			EDI_JACKKNIFE_MIN_DELETION_UNITS - 1L, " are needed, so the standard error is too unstable for a normal-reference ",
			"Wald test or interval. Use a randomization test (compute_rand_two_sided_pval()) or the model-based standard error.")
		else paste0("The jackknife has only ",
			as.integer(private$cached_values$jackknife_n_deletion_units$n %||% NA_integer_), " deletion units (unit = \"",
			private$cached_values$jackknife_n_deletion_units$unit %||% "auto", "\"); at least ",
			EDI_JACKKNIFE_MIN_DELETION_UNITS, " are needed. With G units the jackknife variance has only G - 1 degrees ",
			"of freedom, so the standard error is too unstable for a normal-reference Wald test or interval. ",
			"Use a randomization test (compute_rand_two_sided_pval()) or the model-based standard error."),
		jackknife_original_estimate_unavailable = "The full-data estimate is not available.",
		jackknife_original_risk_ratio_unavailable = paste0("The full-data risk-ratio estimate is not finite and ",
			"positive, so its log (the scale of the jackknife-Wald test and interval) is undefined."),
		jackknife_nonpositive_risk_ratio_replicates = paste0("Some leave-one-unit-out risk ratios are 0 or negative ",
			"(e.g. no events left in one arm), so their log is undefined and the log-scale jackknife standard error ",
			"cannot be formed."),
		jackknife_log_risk_ratio_standard_error_unavailable = paste0("The leave-one-unit-out log risk ratios have ",
			"no spread, so the jackknife standard error is 0."),
		jackknife_log_risk_ratio_null_unavailable = "The null risk ratio (delta) must be finite and positive.",
		NULL
	)
	edi_warn_procedure_na(self, private, procedure = method, reason = why, detail = detail)
}

# v1.0.6-TODO-137: jackknife-Wald inference for a risk-ratio estimand on the log
# scale, shared by the incidence g-computation classes
# (inference_incidence_gcomp_abstract.R and inference_incidence_KK_gcomp_abstract.R,
# whose private compute_rr_jackknife_* methods delegate here). It applies the
# same guards, in the same order, as compute_jackknife_summary(): full-data
# estimate, full-data separation, at least two replicates, at least
# EDI_JACKKNIFE_MIN_DELETION_UNITS units, every replicate finite, no extreme
# replicate (bootstrap_estimates_extreme() on the risk-ratio scale), and no
# extreme summary (on the log scale, where the SE is used). Replicates are no
# longer dropped silently: a non-finite or non-positive replicate makes the
# result NA. Returns list(log_est, se_log, reason); reason is NULL on success,
# NA when the block-size guard already warned, else the recorded reason.
edi_rr_jackknife_log_summary = function(self, private, unit = "auto"){
	fail = function(reason, record = TRUE){
		if (record) private$cache_procedure_failure("jackknife", reason)
		list(log_est = NA_real_, se_log = NA_real_, reason = reason)
	}
	unit = private$normalize_jackknife_unit(unit)
	if (private$mark_jackknife_nonestimable_if_block_unsupported(unit = unit)) {
		return(list(log_est = NA_real_, se_log = NA_real_, reason = NA_character_))
	}
	private$assert_jackknife_supported(unit = unit)
	est = as.numeric(self$compute_estimate(estimate_only = TRUE))[1L]
	if (!is.finite(est) || est <= 0) {
		private$cache_nonestimable_estimate("jackknife_original_risk_ratio_unavailable")
		return(fail("jackknife_original_risk_ratio_unavailable", record = FALSE))
	}
	if (isTRUE(private$jackknife_full_fit_is_separated())) return(fail("jackknife_full_data_separation"))
	jack = as.numeric(private$approximate_jackknife_distribution_beta_hat_T_private(unit = unit))
	n_units = length(jack)
	jack_strata = private$jackknife_replicate_strata(unit)
	if (n_units <= 1L) return(fail("jackknife_too_few_replicate_estimates"))
	if (edi_jackknife_effective_units(n_units, jack_strata) < EDI_JACKKNIFE_MIN_DELETION_UNITS) {
		private$cached_values$jackknife_n_deletion_units = list(n = n_units, unit = private$resolve_jackknife_unit(unit),
			df = if (!is.null(jack_strata)) edi_jackknife_effective_units(n_units, jack_strata) - 1L)
		return(fail("jackknife_too_few_deletion_units"))
	}
	if (any(!is.finite(jack))) return(fail("jackknife_nonfinite_replicate_estimates"))
	if (any(jack <= 0)) return(fail("jackknife_nonpositive_risk_ratio_replicates"))
	if (private$bootstrap_estimates_extreme(jack, est = est)) return(fail("jackknife_extreme_finite_estimates"))
	log_est = log(est)
	log_jack = log(jack)
	moments = edi_jackknife_bias_variance(log_jack, log_est, jack_strata)
	var_j = moments$variance
	if (!is.finite(var_j) || var_j <= 0) return(fail("jackknife_log_risk_ratio_standard_error_unavailable"))
	se_log = sqrt(var_j)
	bias_log = moments$bias
	theta_j_log = log_est - bias_log
	if (!is.finite(theta_j_log) || !is.finite(se_log) ||
	    abs(theta_j_log) > private$bootstrap_extreme_estimate_threshold ||
	    se_log > private$bootstrap_extreme_estimate_threshold ||
	    abs(bias_log) > 2 * se_log) {
		return(fail("jackknife_extreme_summary"))
	}
	df = if (is.null(jack_strata)) Inf else edi_jackknife_effective_units(n_units, jack_strata) - 1L
	list(log_est = log_est, se_log = se_log, reason = NULL, df = df)
}

# Warns (unless the block-size guard already did) for a failed edi_rr_jackknife_log_summary().
edi_rr_jackknife_warn = function(self, private, method, summary){
	if (is.character(summary$reason) && !is.na(summary$reason)) {
		edi_warn_jackknife_na(self, private, method, reason = summary$reason)
	}
	invisible(NULL)
}

edi_rr_jackknife_wald_two_sided_pval = function(self, private, delta = 1, unit = "auto"){
	method = "compute_jackknife_wald_two_sided_pval()"
	if (length(delta) != 1L || !is.finite(delta) || delta <= 0) {
		edi_record_procedure_failure(self, private, "jackknife_log_risk_ratio_null_unavailable", "se")
		edi_warn_jackknife_na(self, private, method, reason = "jackknife_log_risk_ratio_null_unavailable")
		return(NA_real_)
	}
	s = edi_rr_jackknife_log_summary(self, private, unit = unit)
	if (!is.null(s$reason)) {
		edi_rr_jackknife_warn(self, private, method, s)
		return(NA_real_)
	}
	edi_jackknife_wald_pval((s$log_est - log(delta)) / s$se_log, s$df)
}

edi_rr_jackknife_wald_confidence_interval = function(self, private, alpha = 0.05, unit = "auto"){
	ci = c(NA_real_, NA_real_)
	names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
	s = edi_rr_jackknife_log_summary(self, private, unit = unit)
	if (!is.null(s$reason)) {
		edi_rr_jackknife_warn(self, private, "compute_jackknife_wald_confidence_interval()", s)
		return(ci)
	}
	z = edi_jackknife_wald_quantile(alpha, s$df)
	ci[] = exp(s$log_est + c(-1, 1) * z * s$se_log)
	ci
}
