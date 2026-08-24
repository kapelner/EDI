SimpleMeanDifferenceSource = list(
	public = list(
		#' @description Initialize a simple mean-difference inference object.
		#' @param des_obj A DesignSeqOneByOne object whose entire n subjects are assigned
		#'   and response y is recorded within.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages. Default \code{FALSE}.
		#' @param max_resample_attempts Maximum number of times a single bootstrap replicate
		#'   may be redrawn when the drawn sample fails validity screening. If all attempts
		#'   fail the replicate is recorded as \code{NA}, silently reducing the effective \code{B}.
		#'   Must be a positive integer. Default \code{50L}.
		#' @param smart_cold_start_default Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, max_resample_attempts = 50L, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertCount(max_resample_attempts, positive = TRUE)
			}
			super$initialize(des_obj = des_obj, verbose = verbose, harden = TRUE, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			private$fit_warm_start_enabled = FALSE
			private$max_resample_attempts = max_resample_attempts
		},
		#' @description Computes a \eqn{1-\alpha} level confidence interval for the
		#'   simple (unadjusted) mean-difference treatment effect
		#'   \eqn{\hat\beta_T = \bar y_T - \bar y_C}, using \strong{Welch's
		#'   unequal-variance} formula: standard error
		#'   \eqn{\widehat{\mathrm{SE}}(\hat\beta_T) = \sqrt{s_T^2/n_T + s_C^2/n_C}}
		#'   (sample variances \eqn{s_T^2}, \eqn{s_C^2} computed separately per arm,
		#'   not pooled) with Satterthwaite-Welch degrees of freedom
		#'   \eqn{\mathrm{df} = (s_T^2/n_T + s_C^2/n_C)^2 \big/ \left(\frac{(s_T^2/n_T)^2}{n_T-1}
		#'   + \frac{(s_C^2/n_C)^2}{n_C-1}\right)}; the interval is
		#'   \eqn{\hat\beta_T \pm t_{\mathrm{df}, 1-\alpha/2}\,\widehat{\mathrm{SE}}(\hat\beta_T)}.
		#'   Requires at least 2 observations per arm; otherwise the standard error
		#'   and interval are \code{NA}. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
		#'   asymptotic confidence-interval contract this delegates to.
		#' @param alpha Confidence level.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			private$shared()
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Computes a two-sided Welch's t-test p-value testing
		#'   \eqn{H_0: \beta_T = \code{delta}}, from the same Welch
		#'   unequal-variance standard error and Satterthwaite-Welch degrees of
		#'   freedom used by \code{$compute_asymp_confidence_interval()} — see that
		#'   method's documentation for the full formula. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
		#'   asymptotic two-sided p-value contract this delegates to.
		#' @param delta Null treatment effect value.
		compute_asymp_two_sided_pval = function(delta = 0){
			private$shared()
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		},
		#' @description Computes the simple (unadjusted) mean-difference point
		#'   estimate \eqn{\hat\beta_T = \bar y_T - \bar y_C}, the difference in
		#'   sample means between the treated and control arms. \code{NA} if
		#'   either arm has zero observations. See
		#'   \code{\link[EDI:InferenceMLEorKMSummaryTable]{InferenceMLEorKMSummaryTable}}
		#'   for the shared estimate-contract this participates in.
		#'
		#' @return    The setting-appropriate (see description) numeric estimate of the treatment effect
		#'
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			if (is.null(private$cached_values$beta_hat_T)){
				private$cached_values$yTs = private$y[private$w == 1]
				private$cached_values$yCs = private$y[private$w == 0]
				if (length(private$cached_values$yTs) == 0 || length(private$cached_values$yCs) == 0) {
					return(NA_real_)
				}
				private$cached_values$beta_hat_T = mean(private$cached_values$yTs) - mean(private$cached_values$yCs)
			}
			if (!estimate_only && is.null(private$cached_values$s_beta_hat_T)) {
				private$shared(estimate_only = FALSE)
			}
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the simple mean-difference estimate under
		#'   subject/block bootstrap weights (used by the Bayesian bootstrap and
		#'   related weighted-resampling machinery — see
		#'   \code{\link[EDI:InferenceNonParamBootstrap]{InferenceNonParamBootstrap}}).
		#'   The weighted point estimate is \eqn{\hat\beta_T = \bar y_T^w - \bar
		#'   y_C^w}, weighted arm means \eqn{\bar y_T^w = \sum_i r_i y_i \mathbb{1}[w_i=1]
		#'   / \sum_i r_i \mathbb{1}[w_i=1]} (and analogously for control), where
		#'   \eqn{r_i} are the expanded row weights. Unless \code{estimate_only =
		#'   TRUE}, the standard error uses a \strong{weighted, effective-sample-size}
		#'   Welch formula: \eqn{n_{\mathrm{eff}} = (\sum r_i)^2 / \sum r_i^2}
		#'   (the usual Kish effective-sample-size correction for unequal weights)
		#'   in place of the raw \eqn{n} in both the per-arm weighted variance
		#'   denominator and the Satterthwaite-Welch degrees-of-freedom formula (see
		#'   \code{$compute_asymp_confidence_interval()} for the unweighted version
		#'   of the same formula). Rows with non-finite or non-positive weight, or a
		#'   non-finite response, are dropped before computing; if no rows survive,
		#'   returns \code{NA} with all cached variance components set to \code{NA}.
		#' @param subject_or_block_weights Row weights for the bootstrap sample.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			keep = is.finite(row_weights) & row_weights > 0 & is.finite(private$y)
			if (!any(keep)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			y_w  = private$y[keep]
			w_w  = private$w[keep]
			rw_w = row_weights[keep]
			rw_T = rw_w[w_w == 1]; y_T = y_w[w_w == 1]
			rw_C = rw_w[w_w == 0]; y_C = y_w[w_w == 0]
			mean_t = sum(y_T * rw_T) / sum(rw_T)
			mean_c = sum(y_C * rw_C) / sum(rw_C)
			private$cached_values$beta_hat_T = mean_t - mean_c
			if (!estimate_only) {
				if (length(y_T) >= 2L && length(y_C) >= 2L) {
					n_eff_T = sum(rw_T)^2 / sum(rw_T^2)
					n_eff_C = sum(rw_C)^2 / sum(rw_C^2)
					s_T_sq  = sum(rw_T * (y_T - mean_t)^2) / sum(rw_T) / (n_eff_T - 1)
					s_C_sq  = sum(rw_C * (y_C - mean_c)^2) / sum(rw_C) / (n_eff_C - 1)
					se = sqrt(s_T_sq + s_C_sq)
					df = (s_T_sq + s_C_sq)^2 / (s_T_sq^2 / (n_eff_T - 1) + s_C_sq^2 / (n_eff_C - 1))
					private$cached_values$s_beta_hat_T = if (is.finite(se) && se > 0) se else NA_real_
					private$cached_values$df = if (is.finite(df) && df > 0) df else NA_real_
				} else {
					private$cached_values$s_beta_hat_T = NA_real_
					private$cached_values$df = NA_real_
				}
			} else {
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
			}
			private$cached_values$beta_hat_T
		}
	),
	private = list(
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			if (is.null(private$cached_values$beta_hat_T)){
				yTs = private$y[private$w == 1]
				yCs = private$y[private$w == 0]
				if (length(yTs) == 0 || length(yCs) == 0) return(NA_real_)
				private$cached_values$beta_hat_T = mean(yTs) - mean(yCs)
			}
			private$cached_values$beta_hat_T
		},
		max_resample_attempts = 50L,
		get_standard_error = function(){
			if (is.null(private$cached_values$s_beta_hat_T)) private$shared()
			private$cached_values$s_beta_hat_T
		},
		get_degrees_of_freedom = function(){
			if (is.null(private$cached_values$df)) private$shared()
			private$cached_values$df
		},
		compute_fast_bootstrap_distr = function(B, ...) {
			if (!is.null(private[["custom_randomization_statistic_function"]])) return(NULL)
			if (private$is_KK) return(NULL)
			args = list(...)
			n = args[[1]]
			y = args[[2]]
			dead = args[[3]]
			w = args[[4]]
			y_mat = matrix(NA_real_, nrow = n, ncol = B)
			w_mat = matrix(NA_integer_, nrow = n, ncol = B)
			for (b in 1:B) {
				attempt = 1
				repeat {
					i_b = sample(n, n, replace = TRUE)
					w_b = w[i_b]
					if (any(w_b == 1, na.rm = TRUE) && any(w_b == 0, na.rm = TRUE)) {
						if (!private$any_censoring) break
						dead_b_temp = dead[i_b]
						if (any(dead_b_temp[w_b == 1] == 1) && any(dead_b_temp[w_b == 0] == 1) && min(y[i_b]) > 0) break
					}
					attempt = attempt + 1
					if (attempt > private$max_resample_attempts) break
				}
				if (attempt <= private$max_resample_attempts) {
					y_mat[, b] = y[i_b]
					w_mat[, b] = w_b
				}
			}
			res = numeric(B)
			for (b in 1:B) {
				wb = w_mat[, b]
				yb = y_mat[, b]
				res[b] = mean(yb[wb == 1], na.rm = TRUE) - mean(yb[wb == 0], na.rm = TRUE)
			}
			return(res)
		},
		compute_fast_randomization_distr = function(y, permutations, delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps) {
			if (!is.null(private[["custom_randomization_statistic_function"]])) return(NULL)
			w_mat = permutations$w_mat
			res = compute_simple_mean_diff_parallel_cpp(as.numeric(y), w_mat, as.numeric(delta), private$n_cpp_threads(ncol(w_mat)))
			return(res)
		},
		compute_fast_rand_bootstrap_distr = function(y0_full, rand_bootstrap_draws, delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps) {
			if (!is.null(private[["custom_randomization_statistic_function"]]) || !is.null(private[["compiled_cpp_stat_fn"]])) return(NULL)
			transform_code = private$rand_bootstrap_transform_code(transform_responses)
			if (is.null(transform_code)) return(NULL)
			mats = private$rand_bootstrap_draw_matrices(rand_bootstrap_draws)
			if (is.null(mats)) return(NULL)
			compute_rand_bootstrap_mean_diff_parallel_cpp(
				as.numeric(y0_full), mats$i_mat, mats$w_mat, as.numeric(delta),
				transform_code, as.numeric(zero_one_logit_clamp), mats$noise_mat, private$n_cpp_threads(ncol(mats$w_mat))
			)
		},
		# Affine decomposition of the BRT null draws for the closed-form CI: with the additive
		# sharp-null shift, t0_b(delta) = A_b + delta * c_b where A_b is the raw mean difference
		# over the fresh split and c_b = 1 - mean(w_obs | fresh treated) + mean(w_obs | fresh
		# control) accounts for delta having been removed from the originally treated rows.
		compute_rand_bootstrap_ci_affine_coefs = function(rand_bootstrap_draws){
			if (!is.null(private[["custom_randomization_statistic_function"]]) || !is.null(private[["compiled_cpp_stat_fn"]])) return(NULL)
			n = as.integer(private$n)
			B = length(rand_bootstrap_draws)
			if (B == 0L) return(NULL)
			y_raw = as.numeric(private$y)
			w_obs = as.numeric(private$w)
			A = rep(NA_real_, B)
			cc = rep(NA_real_, B)
			for (b in seq_len(B)) {
				draw = rand_bootstrap_draws[[b]]
				if (is.null(draw$w_b) || length(draw$i_b) != n || length(draw$w_b) != n) return(NULL)
				w_f = as.numeric(draw$w_b)
				is_t = w_f == 1
				n_T = sum(is_t)
				if (n_T == 0L || n_T == n) next
				y_b = y_raw[draw$i_b]
				w_obs_b = w_obs[draw$i_b]
				A[b] = mean(y_b[is_t]) - mean(y_b[!is_t])
				cc[b] = 1 - mean(w_obs_b[is_t]) + mean(w_obs_b[!is_t])
			}
			list(A = A, c = cc)
		},
		shared = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			
			if (is.null(private$cached_values$beta_hat_T)){
				self$compute_estimate()
			}
			nT = length(private$cached_values$yTs)
			nC = length(private$cached_values$yCs)
			if (nT <= 1 || nC <= 1) { 
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return() 
			}
			s_1_sq = var(private$cached_values$yTs) / nT
			s_2_sq = var(private$cached_values$yCs) / nC
			private$cached_values$s_beta_hat_T = sqrt(s_1_sq + s_2_sq)
			private$cached_values$df = (s_1_sq + s_2_sq)^2 / (s_1_sq^2 / (nT - 1) + s_2_sq^2 / (nC - 1))
			
			private$cached_values$likelihood_test_context = list(
				X = cbind(1, private$w),
				j = 2L,
				full_fit = list(b = c(mean(private$cached_values$yCs), private$cached_values$beta_hat_T), 
								vt = var(private$cached_values$yTs), vc = var(private$cached_values$yCs))
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
			
			list(
				full_fit = list(b = c(mean(y_sim[w==0]), mean(y_sim[w==1]) - mean(y_sim[w==0])), vt = var(y_sim[w==1]), vc = var(y_sim[w==0])),
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
		# C++ fast path for studentized/symmetric-percentile-t BRT: computes (t0_b, se0_b) in
		# one pass per replicate, bypassing the R worker loop entirely.
		compute_brt_null_statistics_with_se = function(draws, delta, transform_arg, y0_full, zero_one_logit_clamp){
			B = length(draws)
			if (B == 0L) return(list(t0 = numeric(0), se0 = numeric(0)))
			if (is.null(private[["custom_randomization_statistic_function"]]) &&
					is.null(private[["compiled_cpp_stat_fn"]])) {
				transform_code = private$rand_bootstrap_transform_code(transform_arg)
				if (!is.null(transform_code)) {
					mats = private$rand_bootstrap_draw_matrices(draws)
					if (!is.null(mats)) {
						result = tryCatch({
							r = compute_rand_bootstrap_mean_diff_se_parallel_cpp(
								as.numeric(y0_full), mats$i_mat, mats$w_mat,
								as.numeric(delta), as.integer(transform_code),
								as.numeric(zero_one_logit_clamp),
								private$n_cpp_threads(B)
							)
							list(t0 = r[1L, ], se0 = r[2L, ])
						}, error = function(e) NULL)
						if (!is.null(result)) return(result)
					}
				}
			}
			if (isTRUE(private$use_reusable_bootstrap_worker()) &&
					is.null(private[["custom_randomization_statistic_function"]]) &&
					is.null(private[["compiled_cpp_stat_fn"]])) {
				result = tryCatch(
					private$compute_brt_null_statistics_with_reused_workers(draws, delta, transform_arg, y0_full, zero_one_logit_clamp),
					error = function(e) NULL
				)
				if (!is.null(result)) return(result)
			}
			results_mat = matrix(NA_real_, nrow = B, ncol = 2L)
			for (b in seq_len(B)) {
				results_mat[b, ] = tryCatch(
					suppressWarnings(private$run_rand_bootstrap_iteration_with_se(
						draws[[b]], delta, transform_arg, y0_full, zero_one_logit_clamp
					)),
					error = function(e) c(NA_real_, NA_real_)
				)
			}
			list(t0 = results_mat[, 1L], se0 = results_mat[, 2L])
		},
		get_likelihood_test_spec = function(){
			NULL
		}
	)
)

#' Simple Mean-Difference Inference for Continuous Responses
#'
#' Fits the simplest possible treatment-effect estimator for a continuous
#' response: the unadjusted difference in sample means between the treated and
#' control arms, \eqn{\hat\beta_T = \bar y_T - \bar y_C}, with no covariate
#' adjustment. Inference is by \strong{Welch's unequal-variance t-test}: standard
#' error \eqn{\sqrt{s_T^2/n_T + s_C^2/n_C}} (per-arm sample variances, not
#' pooled) with Satterthwaite-Welch degrees of freedom — see
#' \code{$compute_asymp_confidence_interval()} for the exact formula. This class
#' has no likelihood tier (\code{likelihood_tier = "none"}) and provides
#' asymptotic Wald, randomization, and bootstrap (including Bayesian bootstrap)
#' confidence intervals and p-values. Warm starts are disabled for this class,
#' since the simple mean difference is a closed-form estimator (no iterative fit
#' to warm-start).
#'
#' @references Welch, B. L. (1947). "The Generalization of 'Student's' Problem
#'   when Several Different Population Variances are Involved." \emph{Biometrika},
#'   34(1-2), 28-35, \doi{10.1093/biomet/34.1-2.28}, for the unequal-variance
#'   t-test and its Satterthwaite-Welch degrees-of-freedom approximation used
#'   here.
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
#' seq_des_inf = InferenceAllSimpleAverageDiff$new(seq_des)
#' seq_des_inf$compute_estimate()
#' seq_des_inf$compute_asymp_confidence_interval()
#' seq_des_inf$compute_asymp_two_sided_pval()
#' }
#' @name InferenceAllSimpleAverageDiff
#' @export
InferenceAllSimpleAverageDiff = define_inference_class(
	classname = "InferenceAllSimpleAverageDiff",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald", "SimpleMeanDifference"),
	public = list(
		#' @description Uses the randomization-CI layer's two-sided p-value contract
		#'   (\code{InferenceRandCI}'s version, not \code{InferenceRand}'s): for
		#'   incidence responses this dispatches to the Zhang exact randomization
		#'   test where applicable rather than refusing outright, matching this
		#'   class's pre-migration old-ladder behavior (see
		#'   \code{InferenceIncidRiskDiff}'s identical rationale). Previously bound
		#'   to \code{InferenceRand}'s version instead, which silently regressed
		#'   Zhang dispatch after migration -- see
		#'   \code{inference_all_abstract_rand_ci.R}'s
		#'   \code{compute_rand_two_sided_pval} for why it's now safe to splice
		#'   this in outside the old inheritance chain.
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval
	),
	metadata = list(likelihood_tier = "none"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights"
		),
		private = c(
			"compute_treatment_estimate_during_randomization_inference",
			"get_standard_error",
			"get_degrees_of_freedom",
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"compute_fast_bootstrap_distr",
			"compute_fast_randomization_distr",
			"compute_fast_rand_bootstrap_distr",
			"compute_rand_bootstrap_ci_affine_coefs",
			"shared",
			"supports_lik_ratio_param_bootstrap",
			"supports_likelihood_tests",
			"get_supported_testing_types_impl",
			"simulate_under_lik_null",
			"compute_brt_null_statistics_with_se",
			"get_likelihood_test_spec"
		)
	)
)
