SimpleWilcoxSource = list(
	public = list(
		#' @description Initialize simple Wilcoxon inference and prepare the
		#'   rank-based treatment statistic used by
		#'   \code{\link[EDI:InferenceAllSimpleWilcox]{InferenceAllSimpleWilcox}}.
		#'   Rejects \code{response_type = "incidence"} (Hodges-Lehmann degenerates
		#'   on binary data) and rejects censored survival data at construction; see
		#'   the class-level documentation for recommended alternatives in both
		#'   cases. Legal \code{response_type} values are \code{"continuous"},
		#'   \code{"count"}, \code{"proportion"}, \code{"survival"} (uncensored
		#'   only), and \code{"ordinal"}.
		#' @param des_obj  A completed \code{DesignSeqOneByOne} object.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose      Whether to print progress messages. Default \code{FALSE}.
		#' @param max_resample_attempts Maximum number of times a single bootstrap replicate
		#'   may be redrawn when the drawn sample fails validity screening. If all attempts
		#'   fail the replicate is recorded as \code{NA}, silently reducing the effective \code{B}.
		#'   Must be a positive integer. Default \code{50L}.
		#' @param smart_cold_start_default Flag for consistent API.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, max_resample_attempts = 50L, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertCount(max_resample_attempts, positive = TRUE)
			}
			if (should_run_asserts()) {
				stop_if_design_incompatible(private$design_compatibility_reason, des_obj, list(
					wilcoxon_incidence_response_unsupported = paste0(
						"Wilcoxon rank-sum inference is not implemented for incidence (binary) ",
						"responses: the Hodges-Lehmann estimator is degenerate (almost always 0) ",
						"on 0/1 data. Use InferenceAllSimpleAverageDiff or a clogit estimator instead."
					),
					wilcoxon_censored_survival_unsupported = paste0(
						"Wilcoxon rank-sum inference does not support censored survival data. ",
						"Use InferenceSurvivalGehanWilcox for censored survival outcomes."
					)
				))
			}
			res_type = des_obj$get_response_type()
			if (should_run_asserts()) {
				assertResponseType(res_type, c("continuous", "count", "proportion", "survival", "ordinal"))
			}
			super$initialize(des_obj = des_obj, verbose = verbose, harden = TRUE, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			private$max_resample_attempts = max_resample_attempts
		},
		#' @description Returns the \strong{Hodges-Lehmann} estimate of location
		#'   shift: the median of all pairwise treatment-minus-control differences
		#'   \eqn{y_{T,i} - y_{C,j}} (via \code{wilcox_hl_point_estimate_cpp()}), the
		#'   standard point estimate associated with the Wilcoxon rank-sum test.
		#'   Robust to outliers and does not assume normality or equal variances.
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Wilcoxon rank-sum test two-sided p-value testing
		#'   \eqn{H_0: \beta_T = \code{delta}} (via \code{stats::wilcox.test(yT, yC -
		#'   delta, exact = FALSE)$p.value}, the normal approximation with
		#'   continuity correction) — a genuine rank-based test, \strong{not} a
		#'   Wald test built from the Hodges-Lehmann estimate and its standard
		#'   error, despite living alongside \code{$compute_asymp_confidence_interval()}
		#'   in this class's "asymptotic" method family. For \code{delta != 0}, the
		#'   control arm's values are shifted by \code{delta} before testing, so the
		#'   test checks whether \eqn{y_T} and \eqn{y_C + \code{delta}} come from
		#'   the same distribution.
		#' @param delta Null treatment effect. Default 0.
		compute_asymp_two_sided_pval = function(delta = 0){
			private$shared(estimate_only = FALSE)
			yT = as.numeric(private$y[private$w == 1])
			yC = as.numeric(private$y[private$w == 0])
			if (length(yT) == 0L || length(yC) == 0L) return(NA_real_)
			if (delta == 0 && !is.null(private$cached_values$wilcox_asymp_pval) && is.finite(private$cached_values$wilcox_asymp_pval)) {
				return(private$cached_values$wilcox_asymp_pval)
			}
				pv = tryCatch(
					stats::wilcox.test(yT, yC - delta, exact = FALSE)$p.value,
					error = function(e) {
						if (is_edi_control_condition(e)) stop(e)
						NA_real_
					}
				)
			as.numeric(pv)
		},
		#' @description Returns the Hodges-Lehmann confidence interval directly from
		#'   \code{stats::wilcox.test(yT, yC, conf.int = TRUE, exact = FALSE,
		#'   conf.level = 1 - alpha)} — the standard nonparametric interval
		#'   associated with the Wilcoxon rank-sum test, based on inverting the
		#'   rank-sum test statistic rather than a Wald normal-approximation
		#'   interval around \code{$compute_estimate()}'s point estimate (though the
		#'   two coincide asymptotically).
		#' @param alpha Significance level. Default 0.05.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			private$shared(estimate_only = FALSE)
			ci = private$cached_values$wilcox_conf_int
			if (!is.null(ci) && length(ci) == 2L && all(is.finite(ci))) return(as.numeric(ci))
			yT = as.numeric(private$y[private$w == 1])
			yC = as.numeric(private$y[private$w == 0])
			if (length(yT) == 0L || length(yC) == 0L) return(c(NA_real_, NA_real_))
			mod = tryCatch(
				stats::wilcox.test(yT, yC, conf.int = TRUE, exact = FALSE, conf.level = 1 - alpha),
				error = function(e) {
					if (is_edi_control_condition(e)) stop(e)
					NULL
				}
			)
			if (is.null(mod)) return(c(NA_real_, NA_real_))
			as.numeric(mod$conf.int)
		},
		#' @description Reports the jackknife point-estimate as explicitly
		#'   non-estimable for this Hodges-Lehmann estimator, rather than computing
		#'   a leave-one-out jackknife: the median-of-pairwise-differences
		#'   functional is not smooth enough for the delete-1 jackknife's
		#'   linear-approximation machinery to be reliable. This method exists
		#'   purely to record that unavailability (via
		#'   \code{private$cache_nonestimable_estimate()}) rather than silently
		#'   returning a misleading number; see
		#'   \code{\link[EDI:InferenceJackknife]{InferenceJackknife}} for the shared
		#'   jackknife contract this method participates in.
		#' @param unit Deletion unit. Default \code{"auto"}.
		compute_jackknife_estimate = function(unit = "auto"){
			private$cache_nonestimable_estimate("wilcox_hl_jackknife_not_supported")
			NA_real_
		},
		#' @description Reports the jackknife bias-correction estimate as
		#'   non-estimable for this simple Wilcoxon estimator, for the same reason
		#'   as \code{$compute_jackknife_estimate()} (the Hodges-Lehmann functional
		#'   is not smooth enough for the delete-1 jackknife); see
		#'   \code{\link[EDI:InferenceJackknife]{InferenceJackknife}} for the shared
		#'   jackknife contract.
		#' @param unit Deletion unit. Default \code{"auto"}.
		compute_jackknife_bias_estimate = function(unit = "auto"){
			private$cache_nonestimable_estimate("wilcox_hl_jackknife_not_supported")
			NA_real_
		},
		#' @description Reports the jackknife standard error as non-estimable for
		#'   this simple Wilcoxon estimator, for the same reason as
		#'   \code{$compute_jackknife_estimate()}; see
		#'   \code{\link[EDI:InferenceJackknife]{InferenceJackknife}} for the shared
		#'   jackknife contract.
		#' @param unit Deletion unit. Default \code{"auto"}.
		compute_jackknife_std_error = function(unit = "auto"){
			private$cache_nonestimable_se("wilcox_hl_jackknife_not_supported")
			NA_real_
		},
		#' @description Reports the jackknife-Wald p-value as non-estimable here,
		#'   for the same reason as \code{$compute_jackknife_estimate()}; see
		#'   \code{\link[EDI:InferenceJackknife]{InferenceJackknife}}.
		#' @param delta Null treatment-effect value. Default 0.
		#' @param unit Deletion unit. Default \code{"auto"}.
		compute_jackknife_wald_two_sided_pval = function(delta = 0, unit = "auto"){
			private$cache_nonestimable_se("wilcox_hl_jackknife_not_supported")
			NA_real_
		},
		#' @description Reports the jackknife-Wald confidence interval as
		#'   non-estimable here, for the same reason as
		#'   \code{$compute_jackknife_estimate()}; see
		#'   \code{\link[EDI:InferenceJackknife]{InferenceJackknife}}.
		#' @param alpha Significance level. Default 0.05.
		#' @param unit Deletion unit. Default \code{"auto"}.
		compute_jackknife_wald_confidence_interval = function(alpha = 0.05, unit = "auto"){
			private$cache_nonestimable_se("wilcox_hl_jackknife_not_supported")
			c(NA_real_, NA_real_)
		}
	),
	private = list(
		# Discovery-time counterpart of the two initialize()-time stop()s above
		# (incidence response, censored survival) -- self/private-free so it's
		# safe to call unbound against a candidate des_obj before construction,
		# same "safe invoke without construction" contract as
		# supports_interval_or_left_censored_data()/requires_blocking_design().
		# See infer_inference_design_compatibility_reason_fn() in
		# inference_class_registry.R.
		design_compatibility_reason = function(des_obj){
			if (isTRUE(des_obj$get_response_type() == "incidence")) {
				return("wilcoxon_incidence_response_unsupported")
			}
			if (isTRUE(des_obj$any_censoring())) {
				return("wilcoxon_censored_survival_unsupported")
			}
			NA_character_
		},
		supports_bayesian_bootstrap = function() FALSE,
		# Self/private-free literal, same "safe invoke without construction"
		# contract as `design_compatibility_reason()` just above -- see
		# `inference_all_abstract_jackknife.R`'s `jackknife_always_
		# nonestimable()` default (`FALSE`) for why this override exists:
		# every jackknife method on this class unconditionally reports
		# non-estimable regardless of data (the Hodges-Lehmann functional
		# isn't smooth enough for the delete-1 jackknife), so `run_all_
		# inference()` can skip generating that doomed task entirely.
		jackknife_always_nonestimable = function() TRUE,
		compute_fast_rand_bootstrap_distr = function(y0_full, rand_bootstrap_draws, delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps){
			if (!is.null(private[["custom_randomization_statistic_function"]]) || !is.null(private[["compiled_cpp_stat_fn"]])) return(NULL)
			transform_code = private$rand_bootstrap_transform_code(transform_responses)
			if (is.null(transform_code)) return(NULL)
			mats = private$rand_bootstrap_draw_matrices(rand_bootstrap_draws)
			if (is.null(mats)) return(NULL)
			compute_wilcox_hl_rand_bootstrap_parallel_cpp(
				as.numeric(y0_full), mats$i_mat, mats$w_mat, as.numeric(delta),
				transform_code, as.numeric(zero_one_logit_clamp), mats$noise_mat, private$n_cpp_threads(ncol(mats$w_mat))
			)
		},
		max_resample_attempts = 50L,
		hl_point_estimate = function(y_vals, w_vals, row_weights = NULL){
			if (is.null(row_weights)) {
				return(wilcox_hl_point_estimate_cpp(as.integer(w_vals), as.numeric(y_vals)))
			}
			private$check_bootstrap_replicate_deadline("Wilcox weighted HL setup")
			# Weighted implementation
			y_vals = as.numeric(y_vals)
			w_vals = as.integer(w_vals)
			row_weights = as.numeric(row_weights)
			i_t = which(w_vals == 1L & is.finite(y_vals) & is.finite(row_weights) & row_weights > 0)
			i_c = which(w_vals == 0L & is.finite(y_vals) & is.finite(row_weights) & row_weights > 0)
			if (length(i_t) == 0L || length(i_c) == 0L) return(NA_real_)
			diffs = as.numeric(outer(y_vals[i_t], y_vals[i_c], "-"))
			private$check_bootstrap_replicate_deadline("Wilcox weighted HL differences")
			wdiff = as.numeric(outer(row_weights[i_t], row_weights[i_c], "*"))
			private$check_bootstrap_replicate_deadline("Wilcox weighted HL weights")
			ok = is.finite(diffs) & is.finite(wdiff) & wdiff > 0
			if (!any(ok)) return(NA_real_)
			diffs = diffs[ok]
			wdiff = wdiff[ok]
			o = order(diffs)
			private$check_bootstrap_replicate_deadline("Wilcox weighted HL order")
			diffs = diffs[o]
			wdiff = wdiff[o]
			cw = cumsum(wdiff) / sum(wdiff)
			idx = which(cw >= 0.5)[1L]
			if (!is.finite(idx) || is.na(idx)) return(NA_real_)
			as.numeric(diffs[idx])
		},
		compute_fast_bootstrap_distr = function(B, ...) {
			if (!is.null(private[["custom_randomization_statistic_function"]])) return(NULL)
			if (private$is_KK) return(NULL)
			args = list(...)
			n = args[[1]]; y = args[[2]]; dead = args[[3]]; w = args[[4]]
			indices_mat = matrix(-1L, nrow = n, ncol = B)
			for (b in seq_len(B)) {
				attempt = 1L
				repeat {
					i_b = sample_int_replace_cpp(n, n)
					w_b = w[i_b]
					if (any(w_b == 1, na.rm = TRUE) && any(w_b == 0, na.rm = TRUE)) {
						indices_mat[, b] = i_b - 1L
						break
					}
					attempt = attempt + 1L
					if (attempt > private$max_resample_attempts) break
				}
			}
			compute_wilcox_hl_distr_parallel_cpp(as.numeric(y), as.integer(w), matrix(as.integer(indices_mat), nrow=n), private$n_cpp_threads(B))
		},
		get_standard_error = function(){
			if (is.null(private$cached_values$s_beta_hat_T)) private$shared()
			private$cached_values$s_beta_hat_T
		},
		get_degrees_of_freedom = function(){
			NA_real_
		},
		compute_fast_randomization_distr = function(y, permutations, delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps) {
			if (!is.null(private[["custom_randomization_statistic_function"]])) return(NULL)
			w_mat = permutations$w_mat
			res = compute_wilcox_hl_distr_parallel_cpp(
				w_mat = as.matrix(w_mat),
				y = as.numeric(y),
				delta = as.numeric(delta),
				transform_code = 0L,
				zero_one_logit_clamp = as.numeric(zero_one_logit_clamp),
				num_cores = private$n_cpp_threads(ncol(w_mat))
			)
			return(res)
		},
		shared = function(estimate_only = FALSE){
			# `estimate_only = TRUE` is the hot path for randomization/bootstrap
			# replicate workers (`compute_treatment_estimate_during_randomization_inference()`
			# calls this once per replicate, potentially thousands of times per
			# suite run): it must skip `stats::wilcox.test(conf.int = TRUE)`
			# entirely, since that call runs an internal `uniroot()` search over
			# the rank statistic and dominates runtime otherwise. The point
			# estimate alone is available cheaply via `hl_point_estimate()`
			# (a vectorized C++ call) independent of the CI/SE machinery below.
			if (estimate_only) {
				if (!is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
				yT = private$y[private$w == 1]
				yC = private$y[private$w == 0]
				if (length(yT) == 0L || length(yC) == 0L){
					private$cache_nonestimable_estimate("wilcox_empty_treatment_arm")
					return(invisible(NULL))
				}
				beta = private$hl_point_estimate(private$y, private$w)
				private$cached_values$beta_hat_T = if (length(beta) == 1L && is.finite(beta)) beta else NA_real_
				return(invisible(NULL))
			}
			if (!is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			yT = private$y[private$w == 1]
			yC = private$y[private$w == 0]
			if (length(yT) == 0L || length(yC) == 0L){
				private$cache_nonestimable_estimate("wilcox_empty_treatment_arm")
				return(invisible(NULL))
			}
			mod = tryCatch(
				stats::wilcox.test(yT, yC, conf.int = TRUE, exact = FALSE),
				error = function(e) {
					if (is_edi_control_condition(e)) stop(e)
					NULL
				}
			)
			if (is.null(mod)){
				private$cache_nonestimable_estimate("wilcox_fit_unavailable")
				return(invisible(NULL))
			}
			beta = private$hl_point_estimate(private$y, private$w)
			ci   = mod$conf.int
			se   = if (length(ci) == 2L) (ci[2] - ci[1]) / (2 * 1.96) else NA_real_
			private$cached_values$beta_hat_T       = if (length(beta) == 1L && is.finite(beta)) beta else NA_real_
			private$cached_values$s_beta_hat_T     = if (length(se)   == 1L && is.finite(se) && se > 0) se else NA_real_
			private$cached_values$wilcox_asymp_pval = as.numeric(mod$p.value)
			private$cached_values$wilcox_conf_int   = as.numeric(ci)

			beta_hl = private$cached_values$beta_hat_T
			private$cached_values$likelihood_test_context = list(
				X = cbind(1, private$w),
				j = 2L,
				full_fit = list(b = c(mean(private$y - beta_hl * private$w), beta_hl), vt = var(yT), vc = var(yC))
			)
		},
		supports_lik_ratio_param_bootstrap = function() FALSE,
		supports_likelihood_tests = function() FALSE,
		get_supported_testing_types_impl = function(){
			"wald"
		},
		simulate_under_lik_null = function(spec, delta, null_fit){
			b_null = as.numeric(null_fit$b)
			vt = spec$full_fit$vt; vc = spec$full_fit$vc
			w = spec$X[, 2]; n = length(w)
			y_sim = numeric(n)
			y_sim[w == 1] = b_null[1] + b_null[2] + rnorm(sum(w == 1), 0, sqrt(vt))
			y_sim[w == 0] = b_null[1] + rnorm(sum(w == 0), 0, sqrt(vc))
			
			hl_sim = private$hl_point_estimate(y_sim, w)
			list(
				full_fit = list(b = c(mean(y_sim - hl_sim * w), hl_sim), vt = var(y_sim[w==1]), vc = var(y_sim[w==0])),
				fit_null = function(d, start = NULL){
					m_joint = mean(y_sim - w * d)
					list(b = c(m_joint, d), vt = var(y_sim[w==1]), vc = var(y_sim[w==0]))
				},
				neg_loglik = function(fit){
					mu = fit$b[1] + fit$b[2]*w
					sum((y_sim - mu)^2)
				}
			)
		},
		get_likelihood_test_spec = function(){
			NULL
		}
	)
)

#' Simple Wilcoxon Rank-Sum (Hodges-Lehmann) Inference
#'
#' Fits a non-parametric treatment-effect estimator based on the two-sample
#' Wilcoxon rank-sum test: the point estimate is the \strong{Hodges-Lehmann}
#' location-shift estimate (the median of all pairwise treatment-minus-control
#' differences \eqn{y_{T,i} - y_{C,j}}), and both the confidence interval and
#' two-sided p-value are the standard rank-based Wilcoxon quantities from
#' \code{stats::wilcox.test()} (normal approximation with continuity correction),
#' not Wald intervals/tests built around the point estimate and a separately
#' estimated standard error. Robust to outliers and does not assume normality or
#' equal arm variances. Not supported for incidence (binary) responses (the
#' Hodges-Lehmann estimator degenerates on 0/1 data — use
#' \code{\link[EDI:InferenceAllSimpleAverageDiff]{InferenceAllSimpleAverageDiff}} or a
#' conditional-logistic estimator instead) or censored survival data (use
#' \code{\link[EDI:InferenceSurvivalGehanWilcox]{InferenceSurvivalGehanWilcox}}
#' instead). This class has no likelihood tier (\code{likelihood_tier = "none"})
#' and does not support the Bayesian bootstrap; its jackknife methods all report
#' explicit non-estimability rather than computing a (statistically unreliable)
#' delete-1 jackknife of the Hodges-Lehmann functional.
#'
#' @references Hodges, J. L., and Lehmann, E. L. (1963). "Estimates of Location
#'   Based on Rank Tests." \emph{The Annals of Mathematical Statistics}, 34(2),
#'   598-611, \doi{10.1214/aoms/1177704172}, for the Hodges-Lehmann estimator;
#'   Wilcoxon, F. (1945). "Individual Comparisons by Ranking Methods."
#'   \emph{Biometrics Bulletin}, 1(6), 80-83, \doi{10.2307/3001968}, for the
#'   underlying rank-sum test.
#'
#' @examples
#' \dontrun{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 6, response_type = "continuous")
#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[1, 2 : 10])
#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[2, 2 : 10])
#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[3, 2 : 10])
#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[4, 2 : 10])
#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[5, 2 : 10])
#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[6, 2 : 10])
#' seq_des$add_all_subject_responses(c(4.71, 1.23, 4.78, 6.11, 5.95, 8.43))
#'
#' seq_des_inf = InferenceAllSimpleWilcox$new(seq_des)
#' seq_des_inf$compute_estimate()
#' }
#' @name InferenceAllSimpleWilcox
#' @export
InferenceAllSimpleWilcox = define_inference_class(
	classname = "InferenceAllSimpleWilcox",
	inherit = Inference,
	components = c("RandomizationBootstrapCI", "Wald", "SimpleWilcox"),
	public = list(
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	),
	metadata = list(likelihood_tier = "none"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"initialize",
			"compute_estimate",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_jackknife_estimate",
			"compute_jackknife_bias_estimate",
			"compute_jackknife_std_error",
			"compute_jackknife_wald_two_sided_pval",
			"compute_jackknife_wald_confidence_interval"
		),
		private = c(
			"compute_fast_rand_bootstrap_distr",
			"jackknife_always_nonestimable",
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"compute_fast_bootstrap_distr",
			"get_standard_error",
			"get_degrees_of_freedom",
			"compute_fast_randomization_distr",
			"shared",
			"supports_lik_ratio_param_bootstrap",
			"supports_likelihood_tests",
			"get_supported_testing_types_impl",
			"simulate_under_lik_null",
			"get_likelihood_test_spec"
		)
	)
)
