inference_survival_weibull_public = list(
		#' @description Initialize inference for the Weibull AFT model
		#'   \eqn{\log T_i = \beta_0 + \beta_T W_i + X_i^\top \gamma + \sigma
		#'   \epsilon_i}, \eqn{\epsilon_i \sim} standard extreme-value (so \eqn{T_i}
		#'   is marginally Weibull); see
		#'   \code{\link[EDI:InferenceSurvivalWeibullRegr]{InferenceSurvivalWeibullRegr}}
		#'   for the model form. Does not fit the model; the fit is deferred to the
		#'   first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with a survival response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart optimizer start values by default.
		#' @param optimization_alg Character scalar specifying the optimization algorithm. 
		#'   Default is dispatched via policy.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL, optimization_alg = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "survival")
				assertFormula(model_formula, null.ok = TRUE)
			}
			self$set_optimization_alg(optimization_alg, allow_irls = FALSE)
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
		},
		#' @description Fits the Weibull AFT model by maximum likelihood and returns
		#'   the log-time-ratio estimate \eqn{\hat\beta_T}. Handles right-, left-,
		#'   and interval-censored observations via their appropriate
		#'   survival/density likelihood contributions.
		#' @param estimate_only If TRUE, skip standard-error computation and cache
		#'   only the point estimate; used by randomization and bootstrap resampling
		#'   paths.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the treatment estimate under subject/block-level
		#'   Bayesian-bootstrap weights via
		#'   \code{weighted_weibull_bootstrap_surrogate_fit()}, a fast weighted
		#'   Weibull surrogate fit, as an approximation to the weighted AFT
		#'   likelihood. \strong{Only supported for ordinary right-censored data}:
		#'   throws an error for left-/interval-censored designs, since the
		#'   surrogate fit assumes ordinary right-censoring semantics.
		#' @param subject_or_block_weights Subject-, block-, cluster-, or matched-set
		#'   bootstrap weights.
		#' @param estimate_only If \code{TRUE}, compute only the weighted point
		#'   estimate.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			if (weights_are_effectively_constant(row_weights)) {
				beta_hat_T = as.numeric(self$compute_estimate(estimate_only = TRUE))[1L]
				if (is.finite(beta_hat_T)) return(beta_hat_T)
			}
			if (isTRUE(private$has_general_censoring)) {
				stop(
					"Bayesian-bootstrap weighted re-estimation is not yet supported for left-/",
					"interval-censored survival data (weighted_weibull_bootstrap_surrogate_fit() ",
					"assumes ordinary right-censoring semantics, which does not apply here)."
				)
			}
			X_fit = private$build_design_matrix()[, -1, drop = FALSE]
			colnames(X_fit)[1L] = "treatment"
			fit = weighted_weibull_bootstrap_surrogate_fit(private$y, private$dead, X_fit, row_weights)
			private$cached_values$beta_hat_T = if (is.null(fit)) NA_real_ else as.numeric(fit$beta_hat)
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$beta_hat_T
		},
		#' @description Wald confidence interval for the log-time-ratio \eqn{\beta_T}
		#'   using the fitted model's standard error; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared Wald
		#'   contract. Fits the model first if not already cached.
		#' @param alpha Two-sided miscoverage rate; the returned interval targets
		#'   \code{1 - alpha} coverage.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Two-sided Wald test of \eqn{H_0: \beta_T = \code{delta}}
		#'   using the fitted model's standard error; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared Wald
		#'   contract. Fits the model first if not already cached.
		#' @param delta Log-time-ratio value under the null hypothesis.
		compute_asymp_two_sided_pval = function(delta = 0){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		},
		#' @description Bayesian-bootstrap two-sided p-value; see
		#'   \code{\link[EDI:Inference]{Inference}}. Blocked outright (rather than
		#'   letting the underlying weighted re-estimate fail once per replicate,
		#'   inside a per-iteration \code{tryCatch} that silently converts the
		#'   \code{stop()} in \code{compute_estimate_with_bootstrap_weights()} into an
		#'   all-\code{NA} bootstrap distribution) under left-/interval-censored data.
		#' @param delta Null treatment effect value.
		#' @param B Number of Bayesian-bootstrap replicates.
		#' @param type Bootstrap p-value type.
		#' @param na.rm Whether to drop non-finite replicate estimates.
		#' @param show_progress Whether to print a progress bar.
		#' @param min_number_usable_samples Minimum number of finite replicates required.
		#' @param weighting_unit_type Resampling unit type for the bootstrap weights.
		compute_bayesian_bootstrap_two_sided_pval = function(delta = 0, B = 501, type = NULL, na.rm = FALSE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL){
			if (isTRUE(private$has_general_censoring)) {
				stop(
					"Bayesian bootstrap is not yet supported for left-/interval-censored survival data ",
					"(weighted_weibull_bootstrap_surrogate_fit() assumes ordinary right-censoring semantics, ",
					"which does not apply here)."
				)
			}
			# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
			# migration ladders): was `super$compute_bayesian_bootstrap_two_sided_
			# pval(...)`. BayesianBootstrap's own version is a full self-contained
			# implementation (not a thin private-impl wrapper), so it's pinned
			# into a private helper below (bayesian_boot_compute_bayesian_
			# bootstrap_two_sided_pval) -- same "pin from named source generator"
			# shape as compute_bootstrap_confidence_interval's fix in
			# inference_survival_dep_cens_transform.R.
			private$bayesian_boot_compute_bayesian_bootstrap_two_sided_pval(
				delta = delta, B = B, type = type, na.rm = na.rm, show_progress = show_progress,
				min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type
			)
		},
		#' @description Bartlett-corrected likelihood-ratio two-sided p-value; see
		#'   \code{\link[EDI:Inference]{Inference}}. Blocked outright under left-/
		#'   interval-censored data for the same reason as
		#'   \code{compute_bayesian_bootstrap_two_sided_pval()}: the underlying
		#'   \code{simulate_under_lik_null()} guard would otherwise only surface as a
		#'   silently all-\code{NA} calibration distribution.
		#' @param delta Null treatment effect value.
		#' @param B Number of parametric-bootstrap replicates used for the correction.
		compute_lik_ratio_bartlett_approx_two_sided_pval = function(delta = 0, B = 99){
			if (isTRUE(private$has_general_censoring)) {
				stop(
					"Parametric-bootstrap likelihood-ratio calibration (Bartlett correction) is not yet ",
					"supported for left-/interval-censored survival data: simulate_param_boot_weibull_observed() ",
					"only knows how to re-censor a simulated exact time against a single right-censoring ",
					"threshold, not against an arbitrary observation window."
				)
			}
			# Same super$ fix as compute_asymp_confidence_interval elsewhere in
			# this effort -- calls the real private impl directly.
			private$compute_lik_ratio_bartlett_approx_two_sided_pval_impl(delta, B = B)
		},
		#' @description Randomization-test two-sided p-value; see
		#'   \code{\link[EDI:Inference]{Inference}}. A nonzero null shift
		#'   (\code{delta != 0}) is blocked outright under left-/interval-censored
		#'   data for the same reason as the other bootstrap guards in this class:
		#'   the underlying shift-template guard in
		#'   \code{setup_randomization_template_and_shifts()} would otherwise only
		#'   surface as a silently all-\code{NA} randomization distribution.
		#' @param r Number of randomization replicates.
		#' @param delta Null treatment effect shift.
		#' @param transform_responses Response transform used for the randomization statistic.
		#' @param na.rm Whether to drop non-finite replicate statistics.
		#' @param show_progress Whether to print a progress bar.
		#' @param permutations Optional pre-generated permutation matrix.
		#' @param zero_one_logit_clamp Clamp used for logit-transformed responses.
		compute_rand_two_sided_pval = function(r = 501, delta = 0, transform_responses = "none", na.rm = TRUE, show_progress = TRUE, permutations = NULL, zero_one_logit_clamp = .Machine$double.eps){
			if (isTRUE(private$has_general_censoring) && delta != 0) {
				stop(
					"Randomization tests with a nonzero null shift (delta != 0) are not yet supported for ",
					"left-/interval-censored survival data."
				)
			}
			# Pinned like compute_bayesian_bootstrap_two_sided_pval above --
			# RandomizationTest's compute_rand_two_sided_pval is also a full
			# self-contained implementation. Pinned from plain InferenceRand
			# (not InferenceRandCI): matches the established survival-class
			# precedent (e.g. the plain Cox survival classes), not the
			# incidence-only Zhang-dispatch case.
			private$rand_compute_rand_two_sided_pval(
				r = r, delta = delta, transform_responses = transform_responses, na.rm = na.rm,
				show_progress = show_progress, permutations = permutations, zero_one_logit_clamp = zero_one_logit_clamp
			)
		}
	)

inference_survival_weibull_private = list(
		bayesian_boot_compute_bayesian_bootstrap_two_sided_pval = InferenceBayesianBootstrap$public_methods$compute_bayesian_bootstrap_two_sided_pval,
		rand_compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
		# See inference_incid_log_regr_private's cached_mod entry
		# (inference_incidence_logit.R) for the eager-NULL-dropping
		# explanation.
		cached_mod = NULL,
		best_X_colnames = NULL,
		get_complexity_tier = function() "light",
		# private$y_L/private$y_R are always
		# row-aligned with whatever y/dead this file passes in (no row
		# reordering happens anywhere in this class), so they're safe to
		# reference directly regardless of which local snapshot of y/dead a
		# given call site is using.
		# Dispatches to the fast exact/right-censored-only kernel when possible,
		# the general left-/interval-censoring kernel only when actually needed
		# (TODO-28: the fast kernel is ~3-4x cheaper per call, a real and
		# unavoidable cost of general-censoring support, not worth paying on
		# ordinary right-censored/exact data).
		weibull_kernel_fit = function(X, y, dead, warm_start_params = NULL, warm_start_fisher_info = NULL,
		                               fixed_idx = NULL, fixed_values = NULL, estimate_only = FALSE,
		                               smart_cold_start = TRUE, optimization_alg = "lbfgs") {
			if (isTRUE(private$has_general_censoring)) {
				fast_weibull_regression_general_cpp(
					X = X, y = y, y_L = private$y_L, y_R = private$y_R,
					warm_start_params = warm_start_params, warm_start_fisher_info = warm_start_fisher_info,
					fixed_idx = fixed_idx, fixed_values = fixed_values,
					smart_cold_start = smart_cold_start, estimate_only = estimate_only,
					optimization_alg = optimization_alg
				)
			} else {
				fast_weibull_regression_cpp(
					X = X, y = y, dead = dead,
					warm_start_params = warm_start_params, warm_start_fisher_info = warm_start_fisher_info,
					fixed_idx = fixed_idx, fixed_values = fixed_values,
					smart_cold_start = smart_cold_start, estimate_only = estimate_only,
					optimization_alg = optimization_alg
				)
			}
		},
		weibull_kernel_score = function(X, y, dead, params) {
			if (isTRUE(private$has_general_censoring)) {
				get_weibull_regression_general_score_cpp(X, y, private$y_L, private$y_R, params)
			} else {
				get_weibull_regression_score_cpp(X, y, dead, params)
			}
		},
		weibull_kernel_hessian = function(X, y, dead, params) {
			if (isTRUE(private$has_general_censoring)) {
				get_weibull_regression_general_hessian_cpp(X, y, private$y_L, private$y_R, params)
			} else {
				get_weibull_regression_hessian_cpp(X, y, dead, params)
			}
		},
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			if (is.null(private$best_X_colnames)){
				private$shared(estimate_only = TRUE)
			}
			if (is.null(private$best_X_colnames)){
				return(self$compute_estimate(estimate_only = estimate_only))
			}
			X_cols = private$best_X_colnames
			X_data = private$get_X()
			if (length(X_cols) == 0L){
				X = cbind(`(Intercept)` = 1, treatment = private$w)
			} else {
				X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
				X = cbind(`(Intercept)` = 1, treatment = private$w, X_cov)
			}
			n_params = ncol(X) + 1L
			ws_args = private$get_backend_warm_start_args(n_params)
			
			res = private$weibull_kernel_fit(
				X = X, y = private$y, dead = private$dead,
				warm_start_params = ws_args$start_params,
				warm_start_fisher_info = ws_args$warm_start_fisher_info,
				smart_cold_start = private$smart_cold_start_default,
				estimate_only = TRUE, optimization_alg = private$optimization_alg
			)
			if (is.null(res) || !isTRUE(res$converged) || !is.finite(res$b[2])){
				return(NA_real_)
			}
			private$set_fit_warm_start(c(as.numeric(res$b), as.numeric(res$log_sigma)), "params", fisher = res$fisher_information)
			as.numeric(res$b[2])
		},
		supports_reusable_bootstrap_worker = function(){
			TRUE
		},
		supports_lik_ratio_param_bootstrap = function(){
			TRUE
		},
		supports_likelihood_tests = function(){
			TRUE
		},
		simulate_under_lik_null = function(spec, delta, null_fit){
			if (isTRUE(private$has_general_censoring)) {
				stop(
					"Parametric-bootstrap likelihood-ratio calibration (Bartlett correction) is not ",
					"yet supported for left-/interval-censored survival data: simulate_param_boot_weibull_observed() ",
					"only knows how to re-censor a simulated exact time against a single right-censoring ",
					"threshold, not against an arbitrary observation window -- extending it is a modeling ",
					"decision (how to re-derive a simulated interval), not a mechanical one."
				)
			}
			b_null    = as.numeric(null_fit$b)
			log_sigma = as.numeric(null_fit$log_sigma)
			X_fit    = spec$X
			j        = spec$j
			sim_data = private$simulate_param_boot_weibull_observed(
				X = X_fit,
				b_null = b_null,
				log_sigma = log_sigma,
				y_obs = private$y,
				dead_obs = private$dead
			)
			if (is.null(sim_data)) return(NULL)
			y_sim = sim_data$y
			dead_sim = sim_data$dead
			# has_general_censoring is FALSE here (guarded above), so route
			# through the fast exact/right-censored-only kernel directly --
			# no y_exact/y_L/y_R conversion needed (TODO-28).
			full_res = tryCatch(
				fast_weibull_regression_cpp(
					y = y_sim, dead = dead_sim, X = X_fit,
					smart_cold_start = private$smart_cold_start_default,
					estimate_only = FALSE, optimization_alg = private$optimization_alg
				),
				error = function(e) NULL
			)
			p_fit = ncol(X_fit)
			if (is.null(full_res) || !isTRUE(full_res$converged) || length(full_res$params) < j || !is.finite(full_res$params[j])) return(NULL)
			full_fit_boot = list(
				b          = as.numeric(full_res$params[seq_len(p_fit)]),
				log_sigma  = as.numeric(full_res$params[p_fit + 1L]),
				neg_loglik = as.numeric(full_res$neg_ll)
			)
			list(
				worker_data = list(y = y_sim, dead = dead_sim),
				full_fit = full_fit_boot,
				fit_null = function(d, start = NULL){
					res = tryCatch(
						fast_weibull_regression_cpp(
							y = y_sim, dead = dead_sim, X = X_fit,
							warm_start_params = start %||% as.numeric(full_res$params),
							fixed_idx = j, fixed_values = d,
							smart_cold_start = TRUE,
							estimate_only = FALSE, optimization_alg = private$optimization_alg
						),
						error = function(e) NULL
					)
					if (is.null(res) || !isTRUE(res$converged)) return(NULL)
					list(b = as.numeric(res$params[seq_len(p_fit)]), log_sigma = as.numeric(res$params[p_fit + 1L]), neg_loglik = as.numeric(res$neg_ll))
				},
				neg_loglik = function(fit) as.numeric(fit$neg_loglik)
			)
		},
		get_likelihood_test_spec = function(){
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			X_fit = ctx$X
			y = as.numeric(private$y)
			dead = as.numeric(private$dead)
			j_treat = as.integer(ctx$j_treat)
			list(
				X = X_fit, y = y, j = j_treat,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					ws_args = private$get_backend_warm_start_args(ncol(X_fit) + 1L)
					res = tryCatch(
						private$weibull_kernel_fit(
							X = X_fit, y = y, dead = dead,
							warm_start_params = start %||% ws_args$start_params,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							fixed_idx = j_treat, fixed_values = delta,
							smart_cold_start = private$smart_cold_start_default,
							optimization_alg = private$optimization_alg
						),
						error = function(e) NULL
					)
					if (is.null(res) || !isTRUE(res$converged)) return(NULL)
					list(b = as.numeric(res$params[seq_len(ncol(X_fit))]), log_sigma = as.numeric(res$params[ncol(X_fit) + 1L]), neg_loglik = as.numeric(res$neg_ll), fisher_information = res$information)
				},
				extract_start = function(fit){
					c(as.numeric(fit$b), as.numeric(fit$log_sigma))
				},
				score = function(fit){
					params = c(as.numeric(fit$b), as.numeric(fit$log_sigma))
					private$weibull_kernel_score(X_fit, y, dead, params)
				},
				observed_information = function(fit){
					params = c(as.numeric(fit$b), as.numeric(fit$log_sigma))
					-private$weibull_kernel_hessian(X_fit, y, dead, params)
				},
				fisher_information = function(fit){
					params = c(as.numeric(fit$b), as.numeric(fit$log_sigma))
					-private$weibull_kernel_hessian(X_fit, y, dead, params)
				},
				information = function(fit){
					params = c(as.numeric(fit$b), as.numeric(fit$log_sigma))
					-private$weibull_kernel_hessian(X_fit, y, dead, params)
				},
				neg_loglik = function(fit){ as.numeric(fit$neg_loglik) }
			)
		},
		generate_mod = function(estimate_only = FALSE){
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L,
				fit_fun = function(X_fit){
					n_params = ncol(X_fit) + 1L
					ws_args = private$get_backend_warm_start_args(n_params)
					res = private$weibull_kernel_fit(
						X = X_fit, y = private$y, dead = private$dead,
						warm_start_params = ws_args$start_params,
						warm_start_fisher_info = ws_args$warm_start_fisher_info,
						smart_cold_start = private$smart_cold_start_default,
						estimate_only = estimate_only, optimization_alg = private$optimization_alg
					)
					if (is.null(res) || !isTRUE(res$converged)) return(NULL)
					p = ncol(X_fit)
					b_vals = as.numeric(if (estimate_only) res$b[seq_len(p)] else res$params[seq_len(p)])
					ls_val = as.numeric(if (estimate_only) res$log_sigma else res$params[p + 1L])
					list(
						b                  = b_vals,
						params             = c(b_vals, ls_val),
						log_sigma          = ls_val,
						fisher_information = if (estimate_only) NULL else res$information,
						neg_loglik         = as.numeric(res$neg_ll),
						ssq_b_2            = if (estimate_only || is.null(res$vcov)) NA_real_ else {
							if (nrow(res$vcov) >= 2L) res$vcov[2L, 2L] else NA_real_
						}
					)
				},
				fit_ok = function(mod, X_fit, keep){
					if (is.null(mod) || length(mod$b) < 2L || !is.finite(mod$b[2]) || abs(mod$b[2]) > 5) return(FALSE)
					if (estimate_only) return(TRUE)
					is.finite(mod$ssq_b_2) && mod$ssq_b_2 > 0
				}
			)
			if (!is.null(attempt$fit)){
				private$set_fit_warm_start(attempt$fit$params, "params", fisher = attempt$fit$fisher_information)
				private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
				private$cached_values$likelihood_test_context = list(
					X = attempt$X,
					j_treat = which(attempt$keep == 2L)
				)
			} else {
				private$cached_values$likelihood_test_context = NULL
			}
			attempt$fit
		},
		build_design_matrix = function(){
			X_cov = private$X
			if (is.null(X_cov) || ncol(X_cov) == 0) {
				X = cbind(`(Intercept)` = 1, treatment = private$w)
			} else {
				X = cbind(`(Intercept)` = 1, treatment = private$w, X_cov)
			}
			X
		}
	)

SurvivalWeibullLikelihoodSource = list(
	public = inference_survival_weibull_public,
	private = inference_survival_weibull_private
)

#' Weibull AFT Inference for Survival Responses
#'
#' Fits a Weibull Accelerated Failure Time (AFT) model for survival responses:
#' \eqn{\log T_i = \beta_0 + \beta_T W_i + X_i^\top \gamma + \sigma \epsilon_i},
#' \eqn{\epsilon_i \sim} standard extreme-value (Gumbel-minimum), so that
#' \eqn{T_i} is marginally Weibull-distributed with shape \eqn{1/\sigma} and
#' treatment-dependent scale, by maximum likelihood
#' (\code{\link{fast_weibull_regression_cpp}}). \eqn{\hat\beta_T} is a
#' \strong{log-time-ratio} (log acceleration factor): \eqn{\exp(\hat\beta_T)}
#' is the estimated multiplicative effect of treatment on survival time (an
#' AFT model, not a proportional-hazards model — the Weibull distribution is
#' the one location where AFT and proportional-hazards parameterizations
#' coincide, since \eqn{\exp(-\beta_T/\sigma)} also equals the treatment
#' hazard ratio). \code{likelihood_tier = "full"}: likelihood-ratio, score,
#' gradient, and Wald tests are all available when the model converges, plus
#' parametric-likelihood-bootstrap calibration of the likelihood-ratio test.
#' Right-censored and interval-censored observations enter the likelihood via
#' their appropriate survival/density contributions. Validity requires the
#' Weibull shape assumption for the (log-)survival-time distribution and,
#' when interpreted causally, the usual design-based/model-based assumptions.
#'
#' @references Kalbfleisch, J. D., and Prentice, R. L. (2002). \emph{The
#'   Statistical Analysis of Failure Time Data} (2nd ed.). Wiley, for the
#'   Weibull AFT model and its equivalence to a proportional-hazards model.
#'
#' @seealso Comparable Python API:
#'   \href{https://lifelines.readthedocs.io/en/latest/fitters/regression/WeibullAFTFitter.html}{lifelines
#'   WeibullAFTFitter}. See also:
#'   \href{https://en.wikipedia.org/wiki/Proportional_hazards_model}{Proportional
#'   hazards model} (Wikipedia, for the AFT/PH equivalence note).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'survival')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(runif(10))
#' inf = InferenceSurvivalWeibullRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' \donttest{
#' inf$set_seed(1)
#' inf$compute_lik_ratio_bootstrap_two_sided_pval(delta = 0, B = 9, show_progress = FALSE)
#' }
#' @export
InferenceSurvivalWeibullRegr = define_inference_class(
	classname = "InferenceSurvivalWeibullRegr",
	inherit = Inference,
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "SurvivalWeibullLikelihood"),
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio", response_types = "survival"),
	overrides = list(
		public = c(
			"compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"compute_bayesian_bootstrap_two_sided_pval",
			"compute_lik_ratio_bartlett_approx_two_sided_pval",
			"compute_rand_two_sided_pval", "get_supported_testing_types"
		),
		private = c(
			"compute_treatment_estimate_during_randomization_inference",
			"supports_likelihood_tests", "supports_reusable_bootstrap_worker",
			"generate_mod", "get_likelihood_test_spec",
			"supports_lik_ratio_param_bootstrap", "simulate_under_lik_null",
			"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"create_bootstrap_worker_state", "load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate", "get_supported_testing_types_impl",
			"get_standard_error", "get_degrees_of_freedom", "make_warm_fit_null_wrapper",
			"compute_likelihood_test_two_sided_pval", "compute_score_two_sided_pval_impl",
			"compute_gradient_two_sided_pval_impl", "compute_lik_ratio_two_sided_pval_impl",
			"supports_bartlett_likelihood_ratio_approx", "get_bartlett_factor_approx",
			"get_complexity_tier"
		)
	),
	private = list(
		# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
		# migration ladders): declared at the HOST level (not inside the lazy
		# SurvivalWeibullLikelihood component source) even though it's a
		# trivial, argument-less literal like every other implementation of
		# this method. infer_inference_supports_general_censoring() (used by
		# populate_inference_class_registry()) calls this function directly
		# and unbound (`fn()`, no `self`/`private`), on the documented
		# assumption that every implementation is self/private-free -- true
		# for the literal body itself, but NOT true for how a LAZY
		# component's copy of it actually behaves before first use: a lazy
		# component's `provides_private_methods` entries are template-level
		# STUB functions (installed for real only on first access through a
		# live instance), and the stub's own body references `self`/
		# `private` to perform the install -- calling that stub raw and
		# unbound throws "object 'private' not found". Declaring it directly
		# in the class's own (always-eager) private= here avoids ever
		# stubbing it at all, restoring the "safe to call raw" assumption.
		# This is the first class in this migration effort whose composed
		# component overrides this specific method, so the gap was never
		# exercised until now.
		supports_interval_or_left_censored_data = function() TRUE
	)
)
