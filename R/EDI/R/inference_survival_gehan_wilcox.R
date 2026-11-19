#' Gehan-Wilcoxon (Peto-Prentice) Inference for Survival Data with Censoring
#'
#' Non-parametric inference for survival outcomes supporting censored data, using
#' the Peto-Prentice modification of the Gehan-Wilcoxon test. The treatment effect
#' estimate is the mean difference in Peto-Prentice weighted martingale residuals
#' between the treatment and control groups. Specifically, for each subject the
#' weighted residual is \eqn{M_i^w = \hat{S}(t_i^-) \cdot M_i}, where
#' \eqn{M_i = \delta_i - \hat\Lambda_0(t_i)} is the martingale residual and
#' \eqn{\hat{S}(t_i^-)} is the overall Kaplan-Meier survival estimate just before
#' time \eqn{t_i}. These weights downweight late events, analogously to the
#' Wilcoxon rank-sum test for uncensored data (which also weights early observations
#' more heavily via their larger rank denominator).
#'
#' The p-value uses \code{survival::survdiff(rho = 1)} (Peto-Prentice / Fleming-Harrington
#' p=1, q=0), which is distinct from the log-rank test (\code{rho = 0}) used in
#' \code{InferenceSurvivalKMDiff}.
#'
#' The Bayesian bootstrap
#' (\code{$compute_bayesian_bootstrap_confidence_interval()},
#' \code{$compute_bayesian_bootstrap_two_sided_pval()} and
#' \code{$approximate_bayesian_bootstrap_distribution_beta_hat_T()}) stops
#' with an error on left- or interval-censored data, because the weighted Peto-Prentice re-estimate assumes
#' right-censoring (\code{coxph()}/\code{survfit()}) and the interval-censored
#' fit takes no case weights; use the
#' nonparametric bootstrap there instead. On right-censored data it is
#' unaffected.
#'
#' @references Gehan, E. A. (1965). "A generalized Wilcoxon test for
#'   comparing arbitrarily singly-censored samples." \emph{Biometrika},
#'   52(1-2), 203-223, \doi{10.1093/biomet/52.1-2.203}, for the original
#'   generalized (Gehan) Wilcoxon test for censored data. Peto, R., and Peto,
#'   J. (1972). "Asymptotically Efficient Rank Invariant Test Procedures."
#'   \emph{Journal of the Royal Statistical Society, Series A}, 135(2),
#'   185-207, \doi{10.2307/2344317}, for the survival-weighted (Peto-Prentice)
#'   modification this class implements via \eqn{\rho=1}.
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'survival')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(runif(10))
#' inf = InferenceSurvivalGehanWilcox$new(seq_des)
#' inf$compute_estimate()
#' }
#' @concept Gehan-Wilcoxon test
#' @concept Peto-Prentice test
#' @eval rd_small_sample_section("InferenceSurvivalGehanWilcox")
#' @export
InferenceSurvivalGehanWilcox = define_inference_class(
	classname = "InferenceSurvivalGehanWilcox",
	inherit = Inference,
	components = c(
		"RandomizationCI",
		"RandomizationBootstrapCI",
		"BayesianBootstrap",
		"Jackknife",
		"Wald"
	),
	public = list(
		#' @description Uses the shared randomization two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceRand]{InferenceRand}}.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize Gehan-Wilcoxon survival inference and prepare the
		#'   rank-based treatment statistic used by
		#'   \code{\link[EDI:InferenceSurvivalGehanWilcox]{InferenceSurvivalGehanWilcox}}.
		#'
		#' @param des_obj The design object.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose If TRUE, print additional information.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE) {
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "survival")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula)
		},
		#' @description Returns the mean difference in Peto-Prentice weighted martingale residuals
		#' between the treatment and control groups. Positive values indicate that treatment
		#' subjects experienced more early events than expected (worse early survival).
		#' For left- or interval-censored data, dispatches instead to \code{interval::ictest(...,
		#' scores = "wmw")} (the Wilcoxon-Mann-Whitney interval-censored
		#' generalization of the Peto-Prentice test) and returns its estimate.
		#'
		#' @return  A numeric scalar (the Peto-Prentice weighted score treatment effect estimate).
		#'
		#' @examples
		#' seq_des = DesignSeqOneByOneBernoulli$new(n = 6, response_type = "survival")
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[1, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[2, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[3, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[4, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[5, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[6, 2:10])
		#' seq_des$add_all_subject_responses(
		#'   ys = c(4.71, NA, 4.78, 6.11, NA, 8.43),
		#'   y_Ls = c(NA, 1.23, NA, NA, 5.95, NA),
		#'   y_Rs = c(NA, Inf, NA, NA, Inf, NA)
		#' )
		#'
		#' seq_des_inf = InferenceSurvivalGehanWilcox$new(seq_des)
		#' seq_des_inf$compute_estimate()
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$compute_shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the class-specific treatment estimate under bootstrap weights; see
		#'   \code{\link[EDI:InferenceBayesianBootstrap]{InferenceBayesianBootstrap}}.
		#' @param subject_or_block_weights Bootstrap weights at the subject or block level.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			if (isTRUE(private$has_general_censoring)) {
				stop(
					"Bayesian bootstrap is not yet supported for left-/interval-censored survival data ",
					"(weighted_peto_prentice_mean_difference() assumes ordinary right-censoring semantics ",
					"via coxph()/survfit()/Surv(), which does not apply here)."
				)
			}
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			private$cached_values$beta_hat_T = private$weighted_peto_prentice_mean_difference(row_weights)
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$beta_hat_T
		},
		#' @description Computes a (1 - alpha)-level confidence interval based on the asymptotic normality
		#' of the Peto-Prentice weighted martingale residual mean difference. Falls back to
		#' bootstrap if the SE is unavailable.
		#'
		#' @param  alpha  Significance level. Default is 0.05.
		#'
		#' @return  A numeric vector of length 2: (lower, upper) confidence bounds.
		#'
		#' @examples
		#' seq_des = DesignSeqOneByOneBernoulli$new(n = 6, response_type = "survival")
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[1, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[2, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[3, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[4, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[5, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[6, 2:10])
		#' seq_des$add_all_subject_responses(
		#'   ys = c(4.71, NA, 4.78, 6.11, NA, 8.43),
		#'   y_Ls = c(NA, 1.23, NA, NA, 5.95, NA),
		#'   y_Rs = c(NA, Inf, NA, NA, Inf, NA)
		#' )
		#'
		#' seq_des_inf = InferenceSurvivalGehanWilcox$new(seq_des)
		#' seq_des_inf$compute_asymp_confidence_interval()
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
			}
			private$compute_shared()
			if (is.na(private$cached_values$s_beta_hat_T) || private$cached_values$s_beta_hat_T <= 0){
				return(self$compute_bootstrap_confidence_interval(alpha = alpha))
			}
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Computes the Peto-Prentice (Gehan-Wilcoxon) two-sided p-value via
		#' \code{survival::survdiff(rho = 1)}, which puts greater weight on early events
		#' relative to the standard log-rank test (\code{rho = 0}).
		#' For delta != 0, not yet implemented.
		#'
		#' @param  delta  Null treatment effect to test against. Default is 0.
		#'
		#' @return  A p-value in [0, 1].
		#'
		#' @examples
		#' seq_des = DesignSeqOneByOneBernoulli$new(n = 6, response_type = "survival")
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[1, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[2, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[3, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[4, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[5, 2:10])
		#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[6, 2:10])
		#' seq_des$add_all_subject_responses(
		#'   ys = c(4.71, NA, 4.78, 6.11, NA, 8.43),
		#'   y_Ls = c(NA, 1.23, NA, NA, 5.95, NA),
		#'   y_Rs = c(NA, Inf, NA, NA, Inf, NA)
		#' )
		#'
		#' seq_des_inf = InferenceSurvivalGehanWilcox$new(seq_des)
		#' seq_des_inf$compute_asymp_two_sided_pval()
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta, len = 1, finite = TRUE, any.missing = FALSE)
				if (delta != 0){
					stop("Testing non-zero delta is not yet implemented for InferenceSurvivalGehanWilcox.")
				}
			}
			private$compute_shared()
			if (isTRUE(private$has_general_censoring)) {
				pv = private$cached_values$icen_pval
				if (!is.finite(pv)) return(self$compute_bootstrap_two_sided_pval(delta = delta, na.rm = TRUE))
				return(pv)
			}
			if (!is.finite(private$cached_values$gw_var) || private$cached_values$gw_var <= 0){
				surv_obj  = survival::Surv(private$y, private$dead)
				surv_diff = survival::survdiff(surv_obj ~ private$w, rho = 1)
				return(surv_diff$pvalue)
			}
			chisq_stat = private$cached_values$gw_score ^ 2 / private$cached_values$gw_var
			stats::pchisq(chisq_stat, df = 1, lower.tail = FALSE)
		},
		#' @description Randomization confidence intervals are not supported for this class because
		#' the Peto-Prentice weighted score scale is not commensurate with the time-ratio
		#' null used by the randomization CI bisection algorithm.
		#'
		#' @param  alpha  		Unused.
		#' @param  r  Unused.
		#' @param  pval_epsilon  Unused.
		#' @param  show_progress  Unused.
		#' @param ci_search_control Unused.
		compute_rand_confidence_interval = function(alpha = 0.05, r = 501, pval_epsilon = 0.005, show_progress = TRUE, ci_search_control = NULL){
			stop("Randomization confidence intervals are not supported for InferenceSurvivalGehanWilcox due to inconsistent estimator units on the Peto-Prentice score scale.")
		}
	),
	private = list(
		supports_interval_or_left_censored_data = function() TRUE,
		weighted_peto_prentice_mean_difference = function(row_weights){
			# Shared with InferenceSurvivalLogRank (v1.0.6-TODO-193); the Peto-Prentice
			# KM weights are the only difference.
			survival_null_martingale_mean_difference(private$y, private$dead, private$w, row_weights, peto_prentice = TRUE)
		},
		# interval::ictest() dispatch for left-/interval-censored data (TODO-7,
		# interval_censored_survival_response.md). Wilcoxon-Mann-Whitney scores
		# (scores = "wmw"), the interval-censored generalization of the
		# right-censored Peto-Prentice (Gehan-Wilcoxon) test above. Same
		# (L, R)/y_L/y_R encoding as InferenceSurvivalLogRank's
		# compute_shared_icen() -- see its comment for the empirical check.
		compute_shared_icen = function(estimate_only = FALSE){
			survival_ictest_compute_shared(private, class(self)[1L], estimate_only,
				scores = "wmw", score_key = "gw_score", var_key = "gw_var")
		},
		# Computes the Peto-Prentice weighted martingale residual estimate, its SE, and
		# the survdiff(rho=1) score/variance, via a single fused C++ sweep equivalent to
		# coxph(~1) martingale residuals + survfit(~1) KM weights + survdiff(rho=1).
		# Results are cached in private$cached_values.
		compute_shared = function(estimate_only = FALSE){
			if (isTRUE(private$has_general_censoring)) {
				return(private$compute_shared_icen(estimate_only = estimate_only))
			}
			survival_fast_stats_compute_shared(private, estimate_only,
				stats_fn = function() fast_gehan_wilcox_stats_cpp(
					w = as.integer(private$w),
					y_r = as.numeric(private$y),
					dead = as.integer(private$dead)
				),
				score_key = "gw_score", var_key = "gw_var")
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
