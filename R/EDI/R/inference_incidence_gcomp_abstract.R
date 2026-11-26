#' Marginal Standardization / G-Computation for Binary Responses
#'
#' Internal base class for incidence-outcome g-computation estimators. A
#' logistic regression working model is fit, then potential-outcome risks under
#' all-treated and all-control assignments are standardized over the empirical
#' covariate distribution. Inference uses a sandwich-robust covariance for the
#' regression coefficients and the delta method for the marginal estimand.
#'
#' @details
#' The implementation is optimized for resampling-based inference (bootstrap and
#' randomization). It utilizes a fast C++ IRLS solver for the underlying logistic
#' regression. During resampling draws, it bypasses the expensive calculation of
#' the sandwich covariance matrix and delta-method standard errors, as only the
#' point estimate is required for the distribution.
#'
#' @keywords internal
#' @noRd
InferenceIncidGCompAbstract = R6::R6Class("InferenceIncidGCompAbstract",
	lock_objects = FALSE,
	inherit = InferenceAsymp,
	public = list(
				
		#' @description Initialize the g-computation inference object.
		#' @param des_obj A completed \code{DesignSeqOneByOne} object with an incidence response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param prob_clip_eps Probability clamp applied to fitted values before computing
		#'   the sandwich covariance. Predicted probabilities (mu) are clipped to
		#'   \code{[prob_clip_eps, 1 - prob_clip_eps]} so that the IWLS weight
		#'   \eqn{mu(1-mu)} is bounded away from zero. Must be in \code{[0, 0.5)}.
		#'   Default \code{.Machine$double.eps} (essentially no clamping).
		#' @param smart_cold_start_default Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, prob_clip_eps = .Machine$double.eps, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
				assertFormula(model_formula, null.ok = TRUE)
				if (!checkmate::testNumber(prob_clip_eps, lower = 0) || prob_clip_eps >= 0.5) {
					stop("prob_clip_eps must be in [0, 0.5): at 0.5 every fitted probability is clipped to 0.5.", call. = FALSE)
				}
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
			private$prob_clip_eps = prob_clip_eps
		},
		#' @description Uses the shared nonparametric bootstrap distribution contract; see
		#'   \code{\link[EDI:InferenceNonParamBootstrap]{InferenceNonParamBootstrap}}.
		#' @param B  					Number of bootstrap samples.
		#' @param show_progress Whether to show a progress bar.
		#' @param debug         Whether to return diagnostics.
		#' @param bootstrap_type Optional resampling scheme.
		#' @param reimpute_missing_vals_each_resample Missing covariate values in the resamples: \code{FALSE}
		#'   (default) keeps the design's original imputation in every resample, \code{TRUE} re-runs it per
		#'   resample. See \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
		#' @return A numeric vector of bootstrap estimates.
		approximate_bootstrap_distribution_beta_hat_T = function(B = 501, show_progress = TRUE, debug = FALSE, bootstrap_type = NULL, reimpute_missing_vals_each_resample = FALSE){
			super$approximate_bootstrap_distribution_beta_hat_T(B, show_progress, debug, bootstrap_type,
				reimpute_missing_vals_each_resample = edi_bootstrap_reimpute_forward(reimpute_missing_vals_each_resample, missing(reimpute_missing_vals_each_resample)))
		},
		#' @description Computes the g-computation treatment-effect estimate.
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$get_effect_estimate()
		},
		get_standard_error = function(){
			private$shared(estimate_only = FALSE)
			estimand = private$get_estimand_type()
			se = if (identical(estimand, "RD")) {
				private$cached_values$se_rd
			} else {
				private$cached_values$rr * private$cached_values$se_log_rr
			}
			if (is.null(se) || length(se) == 0L) {
				return(NA_real_)
			}
			as.numeric(se)[1L]
		},
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			effects = private$weighted_gcomp_effects_from_row_weights(row_weights)
			if (is.null(effects) || !private$effects_are_usable(effects, estimate_only = TRUE)) {
				private$set_failed_fit_cache(inference_ready = FALSE)
				private$cached_values$beta_hat_T = NA_real_
				return(NA_real_)
			}
			private$cached_values = gcomp_cache_standardized_effects(
				private$cached_values,
				effects,
				inference_ready = FALSE
			)
			private$cached_values$beta_hat_T = if (identical(private$get_estimand_type(), "RD")) effects$rd else effects$rr
			# v1.0.6-TODO-88: the Bayesian-bootstrap studentized path reads this draw's
			# SE (last_weighted_refit$s_beta_hat_T), which was never set. Delta-method SE
			# through the weighted HC0 sandwich; at unit weights it equals the unweighted SE.
			private$cached_values$s_beta_hat_T = NA_real_
			if (!isTRUE(estimate_only) && !is.null(effects$fit)) {
				fit_w = effects$fit
				fit_w$vcov = gcomp_weighted_logistic_sandwich_vcov(fit_w$X, private$y, fit_w$coefficients, row_weights,
					clip_eps = private$prob_clip_eps)
				if (!is.null(fit_w$vcov)) {
					fit_w$estimate_only = FALSE
					eff_w = tryCatch(private$compute_standardized_effects_r(fit_w), error = function(e) NULL)
					se_w = if (is.null(eff_w)) NA_real_ else if (identical(private$get_estimand_type(), "RD")) eff_w$se_rd else effects$rr * eff_w$se_log_rr
					se_w = suppressWarnings(as.numeric(se_w)[1L])
					if (length(se_w) == 1L && is.finite(se_w) && se_w > 0) private$cached_values$s_beta_hat_T = se_w
				}
			}
			private$cached_values$beta_hat_T
		},
		#' @description Computes a 1 - \code{alpha} confidence interval.
		#' @param alpha The confidence level in the computed confidence interval is 1 - \code{alpha}.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			edi_warn_cluster_independence_once(self, private, "wald")
			if (should_run_asserts()) {
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
			}
			private$shared(estimate_only = FALSE)
			private$compute_effect_confidence_interval(alpha)
		},
		#' @description Uses the shared asymptotic two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
		compute_asymp_two_sided_pval = function(delta = NULL){
			edi_warn_cluster_independence_once(self, private, "wald")
			private$shared(estimate_only = FALSE)
			private$compute_effect_pvalue(delta)
		},
		#' @description Computes a Wald two-sided p-value for the treatment effect.
		#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
		compute_wald_two_sided_pval = function(delta = NULL){
			edi_warn_cluster_independence_once(self, private, "wald")
			private$shared(estimate_only = FALSE)
			private$compute_effect_pvalue(delta)
		},
		#' @description Uses the shared Wald confidence-interval contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param alpha The confidence level in the computed confidence interval is 1 - \code{alpha}.
		compute_wald_confidence_interval = function(alpha = 0.05){
			edi_warn_cluster_independence_once(self, private, "wald")
			if (should_run_asserts()) {
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
			}
			private$shared(estimate_only = FALSE)
			private$compute_effect_confidence_interval(alpha)
		},
		#' @description Computes a bootstrap confidence interval for the treatment effect.
		#' @param alpha Significance level. Default 0.05.
		#' @param B Number of bootstrap samples.
		#' @param type Bootstrap CI type. See \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
		#' @param na.rm Whether to remove non-finite bootstrap replicates.
		#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
		#' @param reimpute_missing_vals_each_resample Missing covariate values in the resamples: \code{FALSE}
		#'   (default) keeps the design's original imputation in every resample, \code{TRUE} re-runs it per
		#'   resample. See \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
		compute_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L, reimpute_missing_vals_each_resample = FALSE){
			gcomp_incid_bootstrap_confidence_interval(private, super$compute_bootstrap_confidence_interval,
				alpha, B, type, na.rm, show_progress, min_number_usable_samples,
				reimpute_missing_vals_each_resample = edi_bootstrap_reimpute_forward(reimpute_missing_vals_each_resample, missing(reimpute_missing_vals_each_resample)))
		},
		#' @description Computes a bootstrap two-sided p-value for the treatment effect.
		#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
		#' @param B Number of bootstrap samples.
		#' @param type Bootstrap p-value type. See \code{InferenceNonParamBootstrap$compute_bootstrap_two_sided_pval}.
		#' @param na.rm Whether to remove non-finite bootstrap replicates. Default
		#'   \code{FALSE}: any non-finite replicate makes the p-value \code{NA}, with a
		#'   once-per-object warning of class \code{edi_bootstrap_nonfinite_na_warning}.
		#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
		#' @param min_fraction_usable_samples Minimum fraction of the \code{B} replicates that must be
		#'   finite when \code{na.rm = TRUE}. Default 0.95. See
		#'   \code{InferenceNonParamBootstrap$compute_bootstrap_two_sided_pval}.
		#' @param reimpute_missing_vals_each_resample Missing covariate values in the resamples: \code{FALSE}
		#'   (default) keeps the design's original imputation in every resample, \code{TRUE} re-runs it per
		#'   resample. See \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
		compute_bootstrap_two_sided_pval = function(delta = NULL, B = 501, type = "symmetric", na.rm = FALSE, show_progress = TRUE, min_number_usable_samples = 5L, min_fraction_usable_samples = 0.95, reimpute_missing_vals_each_resample = FALSE){
			gcomp_incid_bootstrap_two_sided_pval(private, super$compute_bootstrap_two_sided_pval,
				delta, B, type, na.rm, show_progress, min_number_usable_samples, min_fraction_usable_samples,
				reimpute_missing_vals_each_resample = edi_bootstrap_reimpute_forward(reimpute_missing_vals_each_resample, missing(reimpute_missing_vals_each_resample)))
		},
		#' @description Computes a Bayesian-bootstrap two-sided p-value for the treatment effect.
		#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
		#' @param B Number of Bayesian-bootstrap samples.
		#' @param type Bayesian-bootstrap p-value type. See \code{InferenceBayesianBootstrap$compute_bayesian_bootstrap_two_sided_pval}.
		#' @param na.rm Whether to remove non-finite bootstrap replicates. Default
		#'   \code{FALSE}: any non-finite replicate makes the p-value \code{NA}, with a
		#'   once-per-object warning of class \code{edi_bootstrap_nonfinite_na_warning}.
		#' @param show_progress Whether to show a progress bar.
		#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
		#' @param weighting_unit_type Optional Bayesian-bootstrap weighting-unit scheme. See
		#'   \code{InferenceBayesianBootstrap$approximate_bayesian_bootstrap_distribution_beta_hat_T}.
		#' @param min_fraction_usable_samples Minimum fraction of the \code{B} replicates that must be
		#'   finite when \code{na.rm = TRUE}. Default 0.95. See
		#'   \code{InferenceBayesianBootstrap$compute_bayesian_bootstrap_two_sided_pval}.
		compute_bayesian_bootstrap_two_sided_pval = function(delta = NULL, B = 501, type = NULL, na.rm = FALSE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL, min_fraction_usable_samples = 0.95){
			gcomp_incid_bayesian_bootstrap_two_sided_pval(private, super$compute_bayesian_bootstrap_two_sided_pval,
				delta, B, type, na.rm, show_progress, min_number_usable_samples, weighting_unit_type, min_fraction_usable_samples)
		},
		#' @description Computes a Bayesian-bootstrap confidence interval for the treatment effect.
		#' @param alpha Significance level. Default 0.05.
		#' @param B Number of Bayesian-bootstrap samples.
		#' @param type Bayesian-bootstrap CI type. See \code{InferenceBayesianBootstrap$compute_bayesian_bootstrap_confidence_interval}.
		#' @param na.rm Whether to remove non-finite bootstrap replicates.
		#' @param show_progress Whether to show a progress bar.
		#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
		#' @param weighting_unit_type Optional Bayesian-bootstrap weighting-unit scheme. See
		#'   \code{InferenceBayesianBootstrap$approximate_bayesian_bootstrap_distribution_beta_hat_T}.
		compute_bayesian_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL){
			gcomp_incid_bayesian_bootstrap_confidence_interval(private, super$compute_bayesian_bootstrap_confidence_interval,
				alpha, B, type, na.rm, show_progress, min_number_usable_samples, weighting_unit_type)
		},
		#' @description Computes a jackknife-Wald two-sided p-value for the treatment effect.
		#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
		#' @param unit Deletion unit. Default \code{"auto"}.
		compute_jackknife_wald_two_sided_pval = function(delta = NULL, unit = "auto"){
			gcomp_incid_jackknife_wald_two_sided_pval(private, super$compute_jackknife_wald_two_sided_pval,
				delta, unit)
		},
		#' @description Computes a jackknife-Wald confidence interval for the treatment effect.
		#' @param alpha Significance level. Default \code{0.05}.
		#' @param unit Deletion unit. Default \code{"auto"}.
		compute_jackknife_wald_confidence_interval = function(alpha = 0.05, unit = "auto"){
			gcomp_incid_jackknife_wald_confidence_interval(private, super$compute_jackknife_wald_confidence_interval,
				alpha, unit)
		}
	),
	# default_null_value() and the compute_rr_*() risk-ratio methods: gcomp_incid_rr_private_methods
	# (helper_gcomp.R), shared by the KK and non-KK classes (v1.0.7-TODO-54).
	private = c(gcomp_incid_rr_private_methods, list(
		is_a_incid_gcomp = function() TRUE,
		best_X_colnames = NULL,
		gcomp_boot_beta = NULL,
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			# Ensure we have the best design from the original data
			if (is.null(private$best_X_colnames)){
				private$shared(estimate_only = TRUE)
			}
			# Fallback if initial fit failed
			gcomp_incid_rand_estimate(self, private, estimate_only)
		},
		prob_clip_eps = .Machine$double.eps,
		max_abs_reasonable_coef = 25,
		build_design_matrix = function(){
			X_cov = private$get_X()
			if (is.null(X_cov) || ncol(X_cov) == 0) {
				X = cbind(`(Intercept)` = 1, treatment = private$w)
			} else {
				X = cbind(`(Intercept)` = 1, treatment = private$w, X_cov)
			}
			X
		},
		get_estimand_type = function() stop(class(self)[1], " must implement get_estimand_type()."),
		get_covariate_names = function(){
			X = private$get_X()
			p = ncol(X)
			x_names = colnames(X)
			if (is.null(x_names)){
				x_names = paste0("x", seq_len(p))
			}
			x_names
		},
		set_failed_fit_cache = function(inference_ready = TRUE){
			private$cached_values = gcomp_cache_failed_standardized_effects(
				private$cached_values,
				inference_ready = inference_ready
			)
		},
		effects_are_usable = function(effects, estimate_only = FALSE){
			estimand = private$get_estimand_type()
			if (estimate_only) {
				if (identical(estimand, "RD")){
					return(is.finite(effects$rd))
				} else {
					return(is.finite(effects$rr) && effects$rr > 0)
				}
			}
			if (identical(estimand, "RD")){
				is.finite(effects$rd) && is.finite(effects$se_rd) && effects$se_rd > 0
			} else {
				is.finite(effects$rr) && effects$rr > 0 &&
					is.finite(effects$log_rr) &&
					is.finite(effects$se_log_rr) && effects$se_log_rr > 0
			}
		},
		weighted_gcomp_fit = function(X_full, row_weights){
			X_curr = X_full
			repeat {
				reduced = private$reduce_design_matrix_preserving_treatment(X_curr)
				X_fit = reduced$X
				j_treat = reduced$j_treat
				if (is.null(X_fit) || !is.finite(j_treat) || nrow(X_fit) <= ncol(X_fit)){
					return(NULL)
				}
				ok = is.finite(row_weights) & row_weights > 0 & is.finite(private$y)
				if (sum(ok) <= ncol(X_fit)) return(NULL)
				# These bootstrap fits estimate coefficients only. Keep their
				# optimization independent of the arbitrary overall weight scale.
				fit_weights = as.numeric(row_weights[ok])
				fit_weights = fit_weights / max(fit_weights)
				# v1.0.6-TODO-138: a non-converged or unusable fit is retried from the
				# full-data warm start and then cold before the covariate-drop rule runs.
				attempt = gcomp_weighted_logistic_fit_with_retries(private, X_fit[ok, , drop = FALSE],
					as.numeric(private$y[ok]), fit_weights, chain_beta = private$gcomp_boot_beta)
				mod = attempt$fit %||% attempt$last
				if (is.null(mod)) {
					private$gcomp_boot_beta = NULL
					return(NULL)
				}
				coef_hat = as.numeric(mod$b)
				if (!is.null(attempt$fit)) {
					# Only cache this fit as the next replicate's warm start when it
					# used the FULL (undropped) design -- a column-dropped fit's
					# shorter coefficient vector is a legitimate answer for THIS
					# replicate's ill-conditioned weights, but caching it here would
					# silently bias the next (differently-weighted, generally
					# full-rank-again) replicate's starting point toward the same
					# reduced model rather than letting it warm-start from the last
					# genuinely full-model fit. The length-mismatch guards in
					# get_fit_warm_start_for_length()/get_fit_warm_start_fisher()
					# already fall back to a cold start on a length mismatch, but
					# skipping the cache write here keeps that fallback from ever
					# being needed for this reason in the first place.
					if (ncol(X_curr) == ncol(X_full)) {
						private$set_fit_warm_start(coef_hat, "beta", fisher = mod$fisher_information)
						private$gcomp_boot_beta = coef_hat
					}
					names(coef_hat) = colnames(X_fit)
					return(list(X = X_fit, j_treat = j_treat, coefficients = coef_hat, estimate_only = TRUE))
				}
				if (ncol(X_curr) <= 2L) return(NULL)
				drop_col = gcomp_select_covariate_to_drop(X_curr, coef_hat)
				if (!is.finite(drop_col)) return(NULL)
				X_curr = X_curr[, -drop_col, drop = FALSE]
			}
		},
		weighted_gcomp_effects_from_row_weights = function(row_weights){
			# A replicate-specific reduced-model fallback must not determine
			# which covariates are retained by the next weighted draw.
			original_keep = private$reduced_design_keep_cache
			on.exit(private$reduced_design_keep_cache <- original_keep, add = TRUE)
			X_full = gcomp_normalize_treatment_design_matrix(
				private$build_design_matrix(),
				covariate_names = private$get_covariate_names
			)
			fit = private$weighted_gcomp_fit(X_full, row_weights)
			if (is.null(fit) && private$harden && ncol(X_full) > 2L) {
				fit = private$weighted_gcomp_fit(X_full[, 1:2, drop = FALSE], row_weights)
			}
			if (is.null(fit)) return(NULL)
			effects = private$compute_standardized_effects_r(fit)
			if (!private$effects_are_usable(effects, estimate_only = TRUE)) return(NULL)
			effects$fit = fit
			effects
		},
		coefficients_are_usable = function(coef_hat){
			gcomp_incid_coefficients_are_usable(private, coef_hat)
		},
		# One body with the KK class (v1.0.7-TODO-54, code-duplication audit decision
		# code-duplication-da35f9c8f): this class clamps at prob_clip_eps and uses the HC0 sandwich.
		fit_logistic_with_sandwich = function(X_full, estimate_only = FALSE){
			gcomp_fit_logistic_with_sandwich(private, X_full, estimate_only, clip_eps = private$prob_clip_eps,
				post_fit = function(X_fit, coef_hat, mu_hat, j_treat){
					gcomp_logistic_post_fit_cpp(
						X_fit = X_fit,
						y = as.numeric(private$y),
						coef_hat = coef_hat,
						mu_hat = mu_hat,
						j_treat = j_treat
					)
				})
		},
		compute_standardized_effects_r = function(fit){
			gcomp_incid_compute_standardized_effects_r(private, fit)
		},
		compute_standardized_effects = function(fit){
			gcomp_incid_compute_standardized_effects(private, fit)
		},
		get_effect_estimate = function(){
			gcomp_incid_get_effect_estimate(private)
		},
		compute_effect_confidence_interval = function(alpha){
			gcomp_incid_compute_effect_confidence_interval(self, private, alpha, "G-computation")
		},
		compute_effect_pvalue = function(delta){
			gcomp_incid_compute_effect_pvalue(self, private, delta)
		},
		shared = function(estimate_only = FALSE){
			if (gcomp_standardized_effect_cache_is_ready(private$cached_values, estimate_only = estimate_only)) return(invisible(NULL))
			if (estimate_only && isFALSE(private$harden)) {
				X = private$build_design_matrix()
				if (!is.null(dim(X)) && is.null(colnames(X))) {
					colnames(X) = c("(Intercept)", "treatment", if (ncol(X) > 2L) private$get_covariate_names() else NULL)
				}
				glm_fit = glm.fit(x = X, y = as.numeric(private$y), family = binomial())
				b = glm_fit$coefficients
				if (length(b) >= 2L && all(is.finite(b))) {
					gcomp_record_fit_diagnostics(private, X, b, converged = glm_fit$converged)
					eta_base = drop(X %*% b) - X[, 2L] * b[2L]
					risk1 = mean(plogis(eta_base + b[2L]))
					risk0 = mean(plogis(eta_base))
					private$best_X_colnames = setdiff(colnames(X), c("(Intercept)", "treatment"))
					private$cached_values$risk1 = risk1
					private$cached_values$risk0 = risk0
					private$cached_values$rd = as.numeric(risk1 - risk0)
					private$cached_values$rr = as.numeric(risk1 / risk0)
					private$cached_values$log_rr = log(private$cached_values$rr)
					private$cached_values$beta_hat_T = if (identical(private$get_estimand_type(), "RD")) private$cached_values$rd else private$cached_values$rr
					private$cached_values$gcomp_standardized_effects_inference_ready = FALSE
					return(invisible(NULL))
				}
			}
			gcomp_incid_fit_and_cache_effects(self, private, estimate_only)
		}
	))
)

IncidenceGComputationSource = inference_component_source_parts(InferenceIncidGCompAbstract)

# v1.0.6-TODO-116 (a): symmetric studentized (percentile-t) Bayesian-bootstrap interval for the
# g-computation risk ratio, type = "symmetric-percentile-t" of
# compute_bayesian_bootstrap_confidence_interval() on InferenceIncidGCompRiskRatio and
# InferenceIncidKKGCompRiskRatio (the same type name and pivot as the nonparametric and
# randomization bootstrap). The pivot is built on log(RR): t_b = |log RR_b - log RR| / se_log_b with
# se_log_b = se_b / RR_b (exact, since each replicate's SE is RR_b * se_log_b from the weighted
# sandwich), and the interval is exp(log RR +/- q_{1 - alpha} * se / RR). The raw-scale "studentized"
# type undercovers at small n (0.89 at n = 60 in the TODO-168 study) because large replicate estimates
# come with large replicate SEs, compressing the pivot's upper tail; the symmetric log-scale pivot
# covered 0.93. Shared by the KK and non-KK RR helpers; runs the same replicate guard
# (bootstrap_ci_estimates_extreme) and interval check (bootstrap_confidence_interval_extreme, which
# judges a risk ratio on log(RR)) as the other Bayesian-bootstrap types.
edi_rr_bayesian_bootstrap_symmetric_studentized_ci = function(self, private, alpha = 0.05, B = 501, na.rm = TRUE,
		show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL){
	if (should_run_asserts()) {
		assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
		assertCount(B, positive = TRUE)
		assertFlag(na.rm)
		assertFlag(show_progress)
		assertCount(min_number_usable_samples, positive = TRUE)
	}
	est = as.numeric(self$compute_estimate())[1L]
	edi_clear_procedure_failure(private, "bayesian_bootstrap")
	private$cached_values$ci_call_failure_reason = NA_character_
	on.exit({private$cached_values$ci_call_failure_reason <- NULL; private$cached_values$ci_call_ctx <- NULL}, add = TRUE)
	ci = c(NA_real_, NA_real_)
	names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
	if (!is.finite(est) || est <= 0) {
		return(private$missing_bootstrap_ci(alpha, "bayesian_bootstrap_original_estimate_unavailable", stage = "estimate"))
	}
	se_hat = suppressWarnings(as.numeric(private$infer_original_se())[1L])
	if (length(se_hat) != 1L || !is.finite(se_hat) || se_hat <= 0) {
		return(private$missing_bootstrap_ci(alpha, "bayesian_bootstrap_standard_error_ci_unavailable", stage = "se"))
	}
	boot_stats = private$approximate_bayesian_bootstrap_statistics_beta_hat_T(
		B = B, show_progress = show_progress, na.rm = isTRUE(na.rm),
		require_se = TRUE, weighting_unit_type = weighting_unit_type
	)
	ok = is.finite(boot_stats$theta) & boot_stats$theta > 0 & is.finite(boot_stats$se) & boot_stats$se > 0
	if (sum(ok) < as.integer(min_number_usable_samples)) {
		return(private$missing_bootstrap_ci(alpha, "bayesian_bootstrap_too_few_finite_standard_errors", stage = "se"))
	}
	theta = boot_stats$theta[ok]
	if (private$bootstrap_ci_estimates_extreme(theta, est = est)) {
		return(private$missing_bootstrap_ci(alpha, "bayesian_bootstrap_extreme_finite_estimates", stage = "estimate"))
	}
	log_theta = log(theta)
	ci_log = tryCatch(
		bootstrap_ci_symmetric_studentized(list(theta = log_theta, se = boot_stats$se[ok] / theta), alpha, log(est),
			se_hat / est, min_number_usable_samples = min_number_usable_samples),
		error = function(e) c(NA_real_, NA_real_)
	)
	if (length(ci_log) < 2L || !all(is.finite(ci_log[1:2]))) {
		return(private$missing_bootstrap_ci(alpha, "bayesian_bootstrap_standard_error_ci_unavailable", stage = "se"))
	}
	if (bootstrap_studentized_interval_scale_unstable(theta = log_theta, ci = ci_log, est = log(est), alpha = alpha)) {
		return(private$missing_bootstrap_ci(alpha, "bayesian_bootstrap_unstable_studentized_interval", stage = "se"))
	}
	ci[] = exp(ci_log[1:2])
	if (private$bootstrap_confidence_interval_extreme(ci, est = est, theta = theta)) {
		return(private$missing_bootstrap_ci(alpha, "bayesian_bootstrap_extreme_confidence_interval", stage = "se"))
	}
	ci
}
