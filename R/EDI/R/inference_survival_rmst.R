#' Restricted Mean Survival Time (RMST) Difference Inference for Survival Responses
#'
#' Fits a non-parametric treatment-effect estimator for censored survival
#' responses: the difference in \strong{restricted mean survival time} (RMST)
#' between the treated and control arms, \eqn{\hat\mu_T(\tau) - \hat\mu_C(\tau)},
#' where each arm's RMST is the area under its Kaplan-Meier survival curve up to
#' a truncation horizon \eqn{\tau} (\eqn{\hat\mu(\tau) = \int_0^\tau \hat S(t)\,dt}),
#' computed by trapezoidal integration of the step-function KM curve. The
#' standard error of the difference comes from the Greenwood-type variance of
#' each arm's RMST, combined across the two (independent) arms via
#' \code{get_restricted_mean_se_diff()}. When that standard error is
#' unavailable or non-finite, \code{$compute_asymp_confidence_interval()} falls
#' back to a nonparametric bootstrap interval rather than returning \code{NA}.
#' Randomization confidence intervals are not supported (the RMST-difference
#' units are not commensurate with the randomization CI bisection algorithm's
#' transformed-scale null search).
#'
#' @references Royston, P., and Parmar, M. K. B. (2013). "Restricted mean
#'   survival time: an alternative to the hazard ratio for the design and
#'   analysis of randomized trials with a time-to-event outcome." \emph{BMC
#'   Medical Research Methodology}, 13, 152, \doi{10.1186/1471-2288-13-152},
#'   for RMST as a treatment-effect summary. Kaplan, E. L., and Meier, P.
#'   (1958). "Nonparametric Estimation from Incomplete Observations."
#'   \emph{Journal of the American Statistical Association}, 53(282),
#'   457-481, \doi{10.2307/2281868}, for the underlying survival curve
#'   estimator each arm's RMST is integrated from.
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'survival')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(runif(10))
#' inf = InferenceSurvivalRestrictedMeanDiff$new(seq_des)
#' inf$compute_estimate()
#' }
#' @concept restricted mean survival time
#' @concept RMST
#' @export
InferenceSurvivalRestrictedMeanDiff = define_inference_class(
	classname = "InferenceSurvivalRestrictedMeanDiff",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald"),
	public = list(
		#' @description Uses the shared randomization two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceRand]{InferenceRand}}.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize restricted-mean-survival-time difference
		#'   inference and prepare treatment-group survival summaries used by
		#'   \code{\link[EDI:InferenceSurvivalRestrictedMeanDiff]{InferenceSurvivalRestrictedMeanDiff}}.
		#'
		#' @param des_obj The design object.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose If TRUE, print additional information.
		#' @param smart_cold_start_default Whether to use smart cold start values by default.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL) {
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "survival")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
		},
		#' @description Computes the class-specific mean or survival contrast; see
		#'   \code{\link[EDI:InferenceMLEorKMSummaryTable]{InferenceMLEorKMSummaryTable}}.
		#'
		#' @return  The setting-appropriate (see description) numeric estimate of the treatment effect
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			if (is.null(private$cached_values$beta_hat_T)){
				if (isTRUE(private$has_general_censoring)) {
					# Turnbull-NPMLE restricted-mean contrast (TODO-8,
					# interval_censored_survival_response.md) via
					# interval::icfit() -- see
					# inference_survival_turnbull_helpers.R for the
					# interval-identifiability convention.
					assert_interval_installed(class(self)[1L])
					private$cached_values$beta_hat_T = turnbull_npmle_stat_diff(
						private$y_L, private$y_R, private$w, "restricted_mean"
					)
				} else {
					private$cached_values$beta_hat_T = get_survival_stat_diff(
						private$y,
						private$dead,
						private$w,
						"restricted_mean"
					)
				}
			}
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the class-specific treatment estimate for a bootstrap sample; see
		#'   \code{\link[EDI:InferenceNonParamBootstrap]{InferenceNonParamBootstrap}}.
		#' @param subject_or_block_weights Row weights for the bootstrap sample.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			if (isTRUE(private$has_general_censoring)) {
				stop(
					"Bayesian bootstrap is not yet supported for left-/interval-censored survival data ",
					"(interval::icfit() has no weights argument, so weighted_survival_stat_diff() cannot ",
					"be generalized to this case)."
				)
			}
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			private$cached_values$beta_hat_T = private$weighted_survival_stat_diff(
				row_weights,
				requested_stat = "restricted_mean"
			)
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$beta_hat_T
		},
		#' @description Computes a \eqn{1-\alpha} level Wald confidence interval for
		#'   the RMST-difference treatment effect \eqn{\hat\mu_T(\tau) -
		#'   \hat\mu_C(\tau)}, using its Greenwood-based standard error (see class
		#'   documentation). Falls back to a nonparametric bootstrap interval if
		#'   that standard error is unavailable or non-finite.
		#'
		#' @param alpha The confidence level in the computed confidence
		#'   interval is 1 - \code{alpha}. The default is 0.05.
		#'
		#' @return  A (1 - alpha)-sized frequentist confidence interval for the treatment effect
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
			}
			if (is.null(private$cached_values$beta_hat_T)){
				self$compute_estimate()
			}
			if (is.null(private$cached_values$s_beta_hat_T)){
				private$compute_s_beta_hat_T()
			}
			if (is.na(private$cached_values$s_beta_hat_T) || private$cached_values$s_beta_hat_T <= 0) {
				return(self$compute_bootstrap_confidence_interval(alpha = alpha))
			}
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Computes a two-sided Wald p-value testing \eqn{H_0:
		#'   \mu_T(\tau) - \mu_C(\tau) = 0} (only \code{delta = 0} is currently
		#'   supported; a non-zero null raises an error), using the RMST-difference
		#'   estimate and its Greenwood-based standard error — see class
		#'   documentation. Falls back to a nonparametric bootstrap p-value if that
		#'   standard error is unavailable.
		#'
		#' @param delta The null difference to test against. For any
		#'   treatment effect at all this is set to zero (the default).
		#'
		#' @return  The approximate frequentist p-value
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta)
			}
			if (delta == 0){
				if (is.null(private$cached_values$s_beta_hat_T)){
					private$compute_s_beta_hat_T()
				}
				if (is.na(private$cached_values$s_beta_hat_T) || private$cached_values$s_beta_hat_T <= 0) {
					return(self$compute_bootstrap_two_sided_pval(delta = delta, na.rm = TRUE))
				}
				z_beta_hat_T = private$cached_values$beta_hat_T / private$cached_values$s_beta_hat_T
				2 * min(stats::pnorm(z_beta_hat_T), 1 - stats::pnorm(z_beta_hat_T))
			} else {
				if (should_run_asserts()) {
					stop("TO-DO")
				}
				NA_real_
			}
		},
		#' @description Uses the shared randomization confidence-interval contract; see
		#'   \code{\link[EDI:InferenceRandCI]{InferenceRandCI}}.
		#'
		#' @param alpha The confidence level in the computed confidence
		#'   interval is 1 - \code{alpha}. The default is 0.05.
		#' @param  r  	The number of randomization vectors. The default is 501.
		#' @param  pval_epsilon  		The bisection algorithm tolerance. The default is 0.005.
		#' @param  show_progress  	Show a text progress indicator.
		#' @param ci_search_control Unused.
		#' @return  A 1 - alpha sized frequentist confidence interval
		compute_rand_confidence_interval = function(alpha = 0.05, r = 501, pval_epsilon = 0.005, show_progress = TRUE, ci_search_control = NULL){
			stop("Randomization confidence intervals are not supported for InferenceSurvivalRestrictedMeanDiff due to inconsistent estimator units on the transformed scale (estimates time difference, but randomization test searches for log-time ratio).")
		}
	),
	private = list(
		supports_interval_or_left_censored_data = function() TRUE,
		compute_fast_rand_bootstrap_distr = function(y0_full, rand_bootstrap_draws, delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps){
			# compute_survival_stat_diff_rand_bootstrap_parallel_cpp() assumes
			# ordinary right-censoring; under general censoring there is no
			# fast path -- NULL is this codebase's established "no fast path"
			# signal, falling back to the generic randomization loop that
			# re-dispatches through compute_estimate() per replicate.
			if (isTRUE(private$has_general_censoring)) return(NULL)
			if (!is.null(private[["custom_randomization_statistic_function"]]) || !is.null(private[["compiled_cpp_stat_fn"]])) return(NULL)
			if (delta != 0 && !identical(transform_responses, "log")) return(NULL)
			mats = private$rand_bootstrap_draw_matrices(rand_bootstrap_draws)
			if (is.null(mats)) return(NULL)
			compute_survival_stat_diff_rand_bootstrap_parallel_cpp(
				as.numeric(y0_full), as.integer(private$dead), mats$i_mat, mats$w_mat,
				as.numeric(delta), TRUE, mats$noise_mat, private$n_cpp_threads(ncol(mats$w_mat))
			)
		},
		weighted_survival_stat_for_group = function(y, dead, row_weights, requested_stat = c("median", "restricted_mean")){
			requested_stat = match.arg(requested_stat)
			keep = is.finite(y) & is.finite(dead) & is.finite(row_weights) & row_weights > 0
			if (!any(keep)) return(NA_real_)
			y = y[keep]
			dead = dead[keep]
			row_weights = as.numeric(row_weights[keep])
			fit = tryCatch(
				survival::survfit(
					survival::Surv(y, dead) ~ 1,
					weights = row_weights
				),
				error = function(e) NULL
			)
			if (is.null(fit)) return(NA_real_)
			if (requested_stat == "median") {
				q = tryCatch(stats::quantile(fit, probs = 0.5), error = function(e) NULL)
				med = if (!is.null(q)) as.numeric(q$quantile) else NA_real_
				return(if (length(med)) med[1L] else NA_real_)
			}
			tau = max(y)
			times = c(0, fit$time)
			surv_vals = c(1, fit$surv)
			if (!length(times) || !length(surv_vals)) return(NA_real_)
			area = 0
			for (i in seq_len(length(times) - 1L)) {
				area = area + surv_vals[i] * (times[i + 1L] - times[i])
			}
			if (length(times) >= 1L) {
				area = area + surv_vals[length(surv_vals)] * (tau - times[length(times)])
			}
			as.numeric(area)
		},
		weighted_survival_stat_diff = function(row_weights, requested_stat = c("median", "restricted_mean")){
			requested_stat = match.arg(requested_stat)
			idx_t = private$w == 1
			idx_c = private$w == 0
			if (!any(idx_t) || !any(idx_c)) return(NA_real_)
			stat_t = private$weighted_survival_stat_for_group(
				private$y[idx_t], private$dead[idx_t], row_weights[idx_t], requested_stat = requested_stat
			)
			stat_c = private$weighted_survival_stat_for_group(
				private$y[idx_c], private$dead[idx_c], row_weights[idx_c], requested_stat = requested_stat
			)
			if (!is.finite(stat_t) || !is.finite(stat_c)) return(NA_real_)
			as.numeric(stat_t - stat_c)
		},
		compute_s_beta_hat_T = function(){
			if (isTRUE(private$has_general_censoring)) {
				# No closed-form SE for a Turnbull-NPMLE restricted-mean contrast
				# is available from interval::icfit() -- leaving s_beta_hat_T NA
				# here makes compute_asymp_confidence_interval()/
				# compute_asymp_two_sided_pval() (unchanged above) fall back to
				# the nonparametric bootstrap automatically, which is the
				# "bootstrap fallback" variance strategy TODO-8 asks for.
				private$cached_values$s_beta_hat_T = NA_real_
				return(invisible(NULL))
			}
			se_val = get_restricted_mean_se_diff(
				private$y,
				private$dead,
				private$w
			)
			if (is.na(se_val) || se_val <= 0) {
				warning("Restricted mean SE is non-positive or NA; MLE p-value/CI unavailable.")
				private$cached_values$s_beta_hat_T = NA_real_
				return(invisible(NULL))
			}
			private$cached_values$s_beta_hat_T = se_val
		}
	),
	overrides = list(
		public = c(
			"compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"compute_rand_confidence_interval", "compute_rand_two_sided_pval"
		),
		private = c(
			"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker", "create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker", "compute_bootstrap_worker_estimate"
		)
	),
	metadata = list(likelihood_tier = "none")
)
