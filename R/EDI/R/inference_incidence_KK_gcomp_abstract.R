#' Marginal Standardization / G-Computation for Binary Responses in KK Designs
#'
#' Internal base class for all-subject incidence-outcome g-computation estimators
#' under KK matching-on-the-fly designs. A logistic working model is fit on all
#' subjects, then potential-outcome risks under all-treated and all-control
#' assignments are standardized over the empirical covariate distribution.
#' Inference uses a cluster-robust covariance where matched pairs form clusters
#' and reservoir subjects are singletons.
#'
#' @details
#' The implementation is optimized for high-throughput resampling. It leverages a
#' fast C++ IRLS solver for the logistic regression. During resampling (bootstrap
#' or randomization), it skips the computation of the cluster-robust sandwich
#' covariance matrix and delta-method variance components, focusing only on the
#' standardized effect estimate.
#'
#' @keywords internal
#' @noRd
InferenceIncidKKGCompAbstract = R6::R6Class("InferenceIncidKKGCompAbstract",
	lock_objects = FALSE,
	inherit = InferenceAbstractKKMarginalIncid,
	public = list(
		# 2026-08-19 (fix_inference_hierarchy.md "Full-Likelihood Estimators",
		# "ModifiedPoisson full-likelihood migration"): this class's own
		# `super$compute_bootstrap_confidence_interval()`/`super$compute_
		# bootstrap_two_sided_pval()`/`super$compute_bayesian_bootstrap_*()`/
		# `super$compute_jackknife_wald_*()` calls below were valid under the
		# old deep R6 ladder (reaching InferenceNonParamBootstrap/
		# InferenceBayesianBootstrap/InferenceJackknife's real generic
		# dispatch through true multi-level inheritance) but silently became
		# infinite self-recursion once its parent
		# `InferenceAbstractKKMarginalIncid` was migrated to flat
		# composition, where `super$X()` on a class with no further real R6
		# ancestor layer above the composed one can loop back into `self`
		# rather than erroring outright. Same "generic self-aliased
		# overrides" pattern already used by this file's separately-
		# harvested `IncidenceKKGComputationSource`/
		# `incidence_kk_gcomp_generic_alias_overrides` (which `modifyList()`s
		# these exact same aliases on top of this class's harvested body for
		# the real migrated `InferenceIncidKKGCompRiskDiff`/`RiskRatio`
		# classes -- unaffected either way, since its override already wins)
		# -- applying it here too makes this class self-sufficient
		# regardless of its ancestor's composition state, which also fixes
		# the test-only legacy R6 reconstruction in
		# test-incid-kk-gcomp-migration-golden.R that inherits this class
		# directly.
		compute_bootstrap_confidence_interval_generic = InferenceNonParamBootstrap$public_methods$compute_bootstrap_confidence_interval,
		compute_bootstrap_two_sided_pval_generic = InferenceNonParamBootstrap$public_methods$compute_bootstrap_two_sided_pval,
		compute_bayesian_bootstrap_two_sided_pval_generic = InferenceBayesianBootstrap$public_methods$compute_bayesian_bootstrap_two_sided_pval,
		compute_bayesian_bootstrap_confidence_interval_generic = InferenceBayesianBootstrap$public_methods$compute_bayesian_bootstrap_confidence_interval,
		compute_jackknife_wald_two_sided_pval_generic = InferenceJackknife$public_methods$compute_jackknife_wald_two_sided_pval,
		compute_jackknife_wald_confidence_interval_generic = InferenceJackknife$public_methods$compute_jackknife_wald_confidence_interval,
		#' @description Compute the KK g-computation treatment estimate by fitting the
		#'   logistic working model and standardizing predicted all-treated and
		#'   all-control risks over the empirical covariate distribution.
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
			if (weights_are_effectively_constant(row_weights)) {
				beta_hat_T = as.numeric(self$compute_estimate(estimate_only = TRUE))[1L]
				if (is.finite(beta_hat_T)) {
					private$cached_values$beta_hat_T = beta_hat_T
					private$cached_values$s_beta_hat_T = NA_real_
					private$cached_values$gcomp_standardized_effects_inference_ready = FALSE
					return(private$cached_values$beta_hat_T)
				}
			}
			private$cached_values$beta_hat_T = private$compute_weighted_gcomp_estimate(row_weights)
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$gcomp_standardized_effects_inference_ready = FALSE
			private$cached_values$beta_hat_T
		},
		#' @description Compute the KK g-computation asymptotic confidence interval
		#'   for the standardized risk difference or risk ratio using the
		#'   cluster-robust delta-method standard error. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for shared interval
		#'   semantics.
		#' @param alpha The significance level (default 0.05).
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
			}
			private$shared(estimate_only = FALSE)
			private$compute_effect_confidence_interval(alpha)
		},
		#' @description Compute the KK g-computation asymptotic two-sided p-value for
		#'   the standardized risk difference or risk ratio using the cluster-robust
		#'   delta-method standard error. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param delta The null treatment effect (default 0).
		compute_asymp_two_sided_pval = function(delta = NULL){
			private$shared(estimate_only = FALSE)
			private$compute_effect_pvalue(delta)
		},
		#' @description Compute Wald two sided pval for treatment effect.
		#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
		compute_wald_two_sided_pval = function(delta = NULL){
			private$shared(estimate_only = FALSE)
			private$compute_effect_pvalue(delta)
		},
		#' @description Compute Wald confidence interval.
		#' @param alpha The significance level (default 0.05).
		compute_wald_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
			}
			private$shared(estimate_only = FALSE)
			private$compute_effect_confidence_interval(alpha)
		},
		#' @description Compute bootstrap confidence interval
		#' @param alpha The significance level (default 0.05).
		#' @param B The number of bootstrap samples (default 501).
		#' @param type Bootstrap CI type. See \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
		#' @param na.rm Whether to remove NA values. (default \code{TRUE}).
		#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
		compute_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L){
			type_resolved = tolower(type %||% "percentile")
			if (identical(private$get_estimand_type(), "RR") && identical(type_resolved, "basic")) {
				return(private$compute_rr_bootstrap_basic_confidence_interval(alpha = alpha, B = B, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples))
			}
			self$compute_bootstrap_confidence_interval_generic(alpha = alpha, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples)
		},
		#' @description Compute bootstrap two sided pval
		#' @param delta The null treatment effect (default 0).
		#' @param B The number of bootstrap samples (default 501).
		#' @param type Bootstrap p-value type. See \code{InferenceNonParamBootstrap$compute_bootstrap_two_sided_pval}.
		#' @param na.rm Whether to remove NA values. (default \code{FALSE}).
		#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
		compute_bootstrap_two_sided_pval = function(delta = NULL, B = 501, type = "symmetric", na.rm = FALSE, show_progress = TRUE, min_number_usable_samples = 5L){
			if (is.null(delta)){
				delta = private$default_null_value()
			}
			self$compute_bootstrap_two_sided_pval_generic(delta = delta, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples)
		},
		#' @description Compute Bayesian-bootstrap two sided pval
		#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
		#' @param B The number of Bayesian-bootstrap samples (default 501).
		#' @param type Bayesian-bootstrap p-value type. See \code{InferenceBayesianBootstrap$compute_bayesian_bootstrap_two_sided_pval}.
		#' @param na.rm Whether to remove NA values. (default \code{FALSE}).
		#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
		compute_bayesian_bootstrap_two_sided_pval = function(delta = NULL, B = 501, type = NULL, na.rm = FALSE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL){
			if (is.null(delta)){
				delta = private$default_null_value()
			}
			self$compute_bayesian_bootstrap_two_sided_pval_generic(delta = delta, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type)
		},
		#' @description Compute Bayesian-bootstrap confidence interval
		#' @param alpha The significance level (default 0.05).
		#' @param B The number of Bayesian-bootstrap samples (default 501).
		#' @param type Bayesian-bootstrap CI type. See \code{InferenceBayesianBootstrap$compute_bayesian_bootstrap_confidence_interval}.
		#' @param na.rm Whether to remove NA values. (default \code{TRUE}).
		#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
		compute_bayesian_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL){
			type_resolved = tolower(type %||% "percentile")
			if (identical(private$get_estimand_type(), "RR") && type_resolved %in% c("basic", "wald")) {
				return(private$compute_rr_bayesian_bootstrap_log_confidence_interval(alpha = alpha, B = B, type = type_resolved, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type))
			}
			self$compute_bayesian_bootstrap_confidence_interval_generic(alpha = alpha, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type)
		},
		#' @description Compute jackknife-Wald two sided pval
		#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
		#' @param unit Deletion unit. Default \code{"auto"}.
		compute_jackknife_wald_two_sided_pval = function(delta = NULL, unit = "auto"){
			if (is.null(delta)){
				delta = private$default_null_value()
			}
			if (identical(private$get_estimand_type(), "RR")) {
				return(private$compute_rr_jackknife_wald_two_sided_pval(delta = delta, unit = unit))
			}
			self$compute_jackknife_wald_two_sided_pval_generic(delta = delta, unit = unit)
		},
		#' @description Compute jackknife-Wald confidence interval
		#' @param alpha Significance level. Default \code{0.05}.
		#' @param unit Deletion unit. Default \code{"auto"}.
		compute_jackknife_wald_confidence_interval = function(alpha = 0.05, unit = "auto"){
			if (identical(private$get_estimand_type(), "RR")) {
				return(private$compute_rr_jackknife_wald_confidence_interval(alpha = alpha, unit = unit))
			}
			self$compute_jackknife_wald_confidence_interval_generic(alpha = alpha, unit = unit)
		}
	),
	private = list(
		is_a_incid_kk_gcomp = function() TRUE,
		max_abs_reasonable_coef = 25,
		best_X_colnames = NULL,
		gcomp_boot_beta = NULL,
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			# Ensure we have the best design from the original data
			if (is.null(private$best_X_colnames)){
				private$shared(estimate_only = TRUE)
			}
			# Fallback if initial fit failed
			if (is.null(private$best_X_colnames)){
				return(self$compute_estimate(estimate_only = estimate_only))
			}
			# Use the same design matrix structure as the original fit
			X_cols = private$best_X_colnames
			X_data = private$get_X()
			
			if (length(X_cols) == 0L){
				# Univariate case
				X = cbind("(Intercept)" = 1, treatment = private$w)
			} else {
				# Multivariate case
				X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
				X = cbind("(Intercept)" = 1, treatment = private$w, X_cov)
			}
			fit = tryCatch(
				fast_logistic_regression_cpp(
					X = X, 
					y = as.numeric(private$y),
					warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X)),
					warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X))
				),
				error = function(e) {
					if (is_edi_control_condition(e)) stop(e)
					NULL
				}
			)
			if (is.null(fit) || !private$coefficients_are_usable(as.numeric(fit$b))){
				return(NA_real_)
			}
			private$set_fit_warm_start(fit$b, "beta", fisher = fit$fisher_information)
			
			# Standardized effect
			coef_hat = as.numeric(fit$b)
			X1 = X
			X0 = X
			X1[, 2L] = 1
			X0[, 2L] = 0
			risk1 = mean(stats::plogis(as.numeric(X1 %*% coef_hat)))
			risk0 = mean(stats::plogis(as.numeric(X0 %*% coef_hat)))
			estimand = private$get_estimand_type()
			if (identical(estimand, "RD")) return(risk1 - risk0)
			if (risk1 > 0 && risk0 > 0) return(risk1 / risk0)
			NA_real_
		},
		build_design_matrix = function() stop(class(self)[1], " must implement build_design_matrix()."),
		get_estimand_type = function() stop(class(self)[1], " must implement get_estimand_type()."),
		default_null_value = function(){
			if (identical(private$get_estimand_type(), "RR")) 1 else 0
		},
		compute_rr_bootstrap_basic_confidence_interval = function(alpha = 0.05, B = 501, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L){
			ci = c(NA_real_, NA_real_)
			names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
			est = as.numeric(self$compute_estimate(estimate_only = FALSE))[1L]
			if (!is.finite(est) || est <= 0) {
				return(private$missing_bootstrap_ci(alpha, "bootstrap_original_estimate_unavailable", stage = "estimate"))
			}
			boot_distr = as.numeric(self$approximate_bootstrap_distribution_beta_hat_T(B = B, show_progress = show_progress))
			if (isTRUE(na.rm)) {
				boot_distr = boot_distr[is.finite(boot_distr) & boot_distr > 0]
			} else if (any(!is.finite(boot_distr) | boot_distr <= 0)) {
				return(ci)
			}
			if (length(boot_distr) < as.integer(min_number_usable_samples)) {
				return(private$missing_bootstrap_ci(alpha, "bootstrap_too_few_finite_estimates", stage = "estimate"))
			}
			q = stats::quantile(log(boot_distr), probs = c(1 - alpha / 2, alpha / 2), names = FALSE, type = 8)
			ci[] = exp(2 * log(est) - q)
			ci
		},
		compute_rr_bayesian_bootstrap_log_confidence_interval = function(alpha = 0.05, B = 501, type = "basic", na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL){
			ci = c(NA_real_, NA_real_)
			names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
			est = as.numeric(self$compute_estimate(estimate_only = FALSE))[1L]
			if (!is.finite(est) || est <= 0) {
				return(private$missing_bootstrap_ci(alpha, "bayesian_bootstrap_original_estimate_unavailable", stage = "estimate"))
			}
			boot_distr = as.numeric(self$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = B, show_progress = show_progress, weighting_unit_type = weighting_unit_type))
			if (isTRUE(na.rm)) {
				boot_distr = boot_distr[is.finite(boot_distr) & boot_distr > 0]
			} else if (any(!is.finite(boot_distr) | boot_distr <= 0)) {
				return(ci)
			}
			if (length(boot_distr) < as.integer(min_number_usable_samples)) {
				return(private$missing_bootstrap_ci(alpha, "bayesian_bootstrap_too_few_finite_estimates", stage = "estimate"))
			}
			log_boot = log(boot_distr)
			if (identical(type, "wald")) {
				se_log = stats::sd(log_boot)
				if (!is.finite(se_log) || se_log <= 0) return(ci)
				z = stats::qnorm(1 - alpha / 2)
				ci[] = exp(log(est) + c(-1, 1) * z * se_log)
			} else {
				q = stats::quantile(log_boot, probs = c(1 - alpha / 2, alpha / 2), names = FALSE, type = 8)
				ci[] = exp(2 * log(est) - q)
			}
			ci
		},
		compute_rr_jackknife_log_se = function(unit = "auto"){
			unit = private$normalize_jackknife_unit(unit)
			if (private$mark_jackknife_nonestimable_if_block_unsupported(unit = unit)) return(NA_real_)
			private$assert_jackknife_supported(unit = unit)
			jack = as.numeric(private$approximate_jackknife_distribution_beta_hat_T_private(unit = unit))
			jack = jack[is.finite(jack) & jack > 0]
			n_units = length(jack)
			if (n_units <= 1L) {
				private$cache_nonestimable_se("jackknife_too_few_positive_risk_ratio_estimates")
				return(NA_real_)
			}
			log_jack = log(jack)
			var_j = ((n_units - 1) / n_units) * sum((log_jack - mean(log_jack))^2)
			if (!is.finite(var_j) || var_j <= 0) {
				private$cache_nonestimable_se("jackknife_log_risk_ratio_standard_error_unavailable")
				return(NA_real_)
			}
			sqrt(var_j)
		},
		compute_rr_jackknife_wald_two_sided_pval = function(delta = 1, unit = "auto"){
			if (!is.finite(delta) || delta <= 0) {
				private$cache_nonestimable_se("jackknife_log_risk_ratio_null_unavailable")
				return(NA_real_)
			}
			est = as.numeric(self$compute_estimate(estimate_only = TRUE))[1L]
			if (!is.finite(est) || est <= 0) {
				private$cache_nonestimable_estimate("jackknife_original_risk_ratio_unavailable")
				return(NA_real_)
			}
			se_log = private$compute_rr_jackknife_log_se(unit = unit)
			if (!is.finite(se_log) || se_log <= 0) return(NA_real_)
			2 * stats::pnorm(-abs((log(est) - log(delta)) / se_log))
		},
		compute_rr_jackknife_wald_confidence_interval = function(alpha = 0.05, unit = "auto"){
			ci = c(NA_real_, NA_real_)
			names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
			est = as.numeric(self$compute_estimate(estimate_only = TRUE))[1L]
			if (!is.finite(est) || est <= 0) {
				private$cache_nonestimable_estimate("jackknife_original_risk_ratio_unavailable")
				return(ci)
			}
			se_log = private$compute_rr_jackknife_log_se(unit = unit)
			if (!is.finite(se_log) || se_log <= 0) return(ci)
			z = stats::qnorm(1 - alpha / 2)
			ci[] = exp(log(est) + c(-1, 1) * z * se_log)
			ci
		},
		compute_weighted_gcomp_estimate = function(row_weights){
			X = private$build_design_matrix()
			if (is.null(X)) return(NA_real_)
			X = as.matrix(X)
			ok = is.finite(row_weights) & row_weights > 0 & is.finite(as.numeric(private$y))
			if (!any(ok)) return(NA_real_)
			X_fit = X[ok, , drop = FALSE]
			y_fit = as.numeric(private$y[ok])
			w_fit = as.numeric(row_weights[ok])
			p_fit = ncol(X_fit)
			boot_ws = if (!is.null(private$gcomp_boot_beta) && length(private$gcomp_boot_beta) == p_fit) {
				private$gcomp_boot_beta
			} else {
				private$get_fit_warm_start_for_length("beta", p_fit)
			}
			mod = tryCatch(
				fast_logistic_regression_weighted_cpp(
					X = X_fit,
					y = y_fit,
					weights = w_fit,
					warm_start_beta = boot_ws,
					warm_start_fisher_info = private$get_fit_warm_start_fisher(p_fit)
				),
				error = function(e) {
					if (is_edi_control_condition(e)) stop(e)
					NULL
				}
			)
			if (is.null(mod) || is.null(mod$b)) {
				private$gcomp_boot_beta = NULL
				return(NA_real_)
			}
			coef_hat = as.numeric(mod$b)
			private$gcomp_boot_beta = coef_hat
			X1 = X_fit
			X0 = X_fit
			X1[, 2L] = 1
			X0[, 2L] = 0
			risk1 = stats::weighted.mean(stats::plogis(as.numeric(X1 %*% coef_hat)), w_fit)
			risk0 = stats::weighted.mean(stats::plogis(as.numeric(X0 %*% coef_hat)), w_fit)
			if (!is.finite(risk1) || !is.finite(risk0)) return(NA_real_)
			if (identical(private$get_estimand_type(), "RD")) return(risk1 - risk0)
			if (risk1 > 0 && risk0 > 0) return(risk1 / risk0)
			NA_real_
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
		coefficients_are_usable = function(coef_hat){
			length(coef_hat) > 0L &&
				all(is.finite(coef_hat)) &&
				max(abs(coef_hat), na.rm = TRUE) <= private$max_abs_reasonable_coef
		},
		fit_logistic_with_sandwich = function(X_full, estimate_only = FALSE){
			X_curr = X_full
			repeat {
				reduced = private$reduce_design_matrix_preserving_treatment(X_curr)
				X_fit = reduced$X
				j_treat = reduced$j_treat
				if (is.null(X_fit) || !is.finite(j_treat) || nrow(X_fit) <= ncol(X_fit)){
					return(NULL)
				}
				mod = tryCatch(
					fast_logistic_regression_cpp(
						X = X_fit, 
						y = as.numeric(private$y),
						warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
						warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit))
					),
					error = function(e) {
						if (is_edi_control_condition(e)) stop(e)
						NULL
					}
				)
				if (is.null(mod)){
					return(NULL)
				}
				coef_hat = as.numeric(mod$b)
				converged = private$coefficients_are_usable(coef_hat)
				if (!converged){
					if (ncol(X_curr) <= 2L) return(NULL)
					drop_col = gcomp_select_covariate_to_drop(X_curr, coef_hat)
					if (!is.finite(drop_col)) return(NULL)
					X_curr = X_curr[, -drop_col, drop = FALSE]
					next
				}
				private$set_fit_warm_start(coef_hat, "beta", fisher = mod$fisher_information)
				
				if (estimate_only){
					return(list(
						X = X_fit,
						j_treat = j_treat,
						coefficients = coef_hat,
						estimate_only = TRUE
					))
				}
				mu_hat = inv_logit(X_fit %*% coef_hat)
				mu_hat = pmin(pmax(as.numeric(mu_hat), .Machine$double.eps), 1 - .Machine$double.eps)
				W = mu_hat * (1 - mu_hat)
				if (any(!is.finite(W)) || any(W <= 0)){
					if (ncol(X_curr) <= 2L) return(NULL)
					drop_col = gcomp_select_covariate_to_drop(X_curr, coef_hat)
					if (!is.finite(drop_col)) return(NULL)
					X_curr = X_curr[, -drop_col, drop = FALSE]
					next
				}
					post_fit = tryCatch(
						gcomp_logistic_cluster_post_fit_cpp(
							X_fit = X_fit,
							y = as.numeric(private$y),
							coef_hat = coef_hat,
							mu_hat = mu_hat,
							cluster_id = private$get_cluster_ids(),
							j_treat = j_treat
						),
						error = function(e) {
							if (is_edi_control_condition(e)) stop(e)
							NULL
						}
					)
				if (is.null(post_fit)){
					if (ncol(X_curr) <= 2L) return(NULL)
					drop_col = gcomp_select_covariate_to_drop(X_curr, coef_hat)
					if (!is.finite(drop_col)) return(NULL)
					X_curr = X_curr[, -drop_col, drop = FALSE]
					next
				}
				coef_names = colnames(X_fit)
				names(coef_hat) = coef_names
				vcov_robust = post_fit$vcov
				colnames(vcov_robust) = rownames(vcov_robust) = coef_names
				return(list(
					X = X_fit,
					j_treat = j_treat,
					coefficients = coef_hat,
					vcov = vcov_robust,
					mu_hat = mu_hat,
					post_fit = post_fit,
					estimate_only = FALSE
				))
			}
		},
		compute_standardized_effects_r = function(fit){
			X_fit = fit$X
			coef_hat = fit$coefficients
			vcov_robust = fit$vcov
			j_treat = fit$j_treat
			estimate_only = isTRUE(fit$estimate_only)
			potential_outcomes = gcomp_logistic_potential_outcomes(X_fit, coef_hat, j_treat)
			X1 = potential_outcomes$X1
			X0 = potential_outcomes$X0
			risk1_i = potential_outcomes$risk1_i
			risk0_i = potential_outcomes$risk0_i
			risk1 = potential_outcomes$risk1
			risk0 = potential_outcomes$risk0
			rd = risk1 - risk0
			log_rr = if (risk1 > 0 && risk0 > 0) log(risk1) - log(risk0) else NA_real_
			rr = if (is.finite(log_rr)) exp(log_rr) else NA_real_
			if (estimate_only){
				return(list(
					risk1 = risk1,
					risk0 = risk0,
					rd = rd,
					se_rd = NA_real_,
					log_rr = log_rr,
					rr = rr,
					se_log_rr = NA_real_,
					full_coefficients = coef_hat,
					full_vcov = NULL,
					summary_table = NULL
				))
			}
			grad1 = as.numeric(crossprod(X1, risk1_i * (1 - risk1_i))) / nrow(X1)
			grad0 = as.numeric(crossprod(X0, risk0_i * (1 - risk0_i))) / nrow(X0)
			grad_rd = grad1 - grad0
			var_rd = as.numeric(t(grad_rd) %*% vcov_robust %*% grad_rd)
			grad_log_rr = if (risk1 > 0 && risk0 > 0) grad1 / risk1 - grad0 / risk0 else rep(NA_real_, length(grad1))
			var_log_rr = if (all(is.finite(grad_log_rr))) as.numeric(t(grad_log_rr) %*% vcov_robust %*% grad_log_rr) else NA_real_
			std_err = sqrt(pmax(diag(vcov_robust), 0))
			z_vals = coef_hat / std_err
			summary_table = cbind(
				Value = coef_hat,
				`Std. Error` = std_err,
				`z value` = z_vals,
				`Pr(>|z|)` = 2 * stats::pnorm(-abs(z_vals))
			)
			list(
				risk1 = risk1,
				risk0 = risk0,
				rd = rd,
				se_rd = if (is.finite(var_rd) && var_rd >= 0) sqrt(var_rd) else NA_real_,
				log_rr = log_rr,
				rr = rr,
				se_log_rr = if (is.finite(var_log_rr) && var_log_rr >= 0) sqrt(var_log_rr) else NA_real_,
				full_coefficients = coef_hat,
				full_vcov = vcov_robust,
				summary_table = summary_table
			)
		},
		compute_standardized_effects = function(fit){
			if (isTRUE(fit$estimate_only)){
				return(private$compute_standardized_effects_r(fit))
			}
			coef_hat = fit$coefficients
			fast = fit$post_fit
			if (is.null(fast)){
				return(private$compute_standardized_effects_r(fit))
			}
			vcov_robust = fast$vcov
			colnames(vcov_robust) = rownames(vcov_robust) = names(coef_hat)
			std_err = fast$std_err
			names(std_err) = names(coef_hat)
			z_vals = fast$z_vals
			names(z_vals) = names(coef_hat)
			summary_table = cbind(
				Value = coef_hat,
				`Std. Error` = std_err,
				`z value` = z_vals,
				`Pr(>|z|)` = 2 * stats::pnorm(-abs(z_vals))
			)
			list(
				risk1 = fast$risk1,
				risk0 = fast$risk0,
				rd = fast$rd,
				se_rd = fast$se_rd,
				log_rr = fast$log_rr,
				rr = fast$rr,
				se_log_rr = fast$se_log_rr,
				full_coefficients = coef_hat,
				full_vcov = vcov_robust,
				summary_table = summary_table
			)
		},
		get_effect_estimate = function(){
			estimand = private$get_estimand_type()
			if (identical(estimand, "RD")) return(private$cached_values$rd)
			private$cached_values$rr
		},
		compute_effect_confidence_interval = function(alpha){
			z = stats::qnorm(1 - alpha / 2)
			estimand = private$get_estimand_type()
			if (identical(estimand, "RD")){
				est = private$cached_values$rd
				se = private$cached_values$se_rd
				if (!is.finite(est) || !is.finite(se) || se <= 0){
					return(c(NA_real_, NA_real_))
				}
				ci = est + c(-1, 1) * z * se
			} else {
				log_rr = private$cached_values$log_rr
				se_log_rr = private$cached_values$se_log_rr
				if (!is.finite(log_rr) || !is.finite(se_log_rr) || se_log_rr <= 0){
					return(c(NA_real_, NA_real_))
				}
				ci_log = log_rr + c(-1, 1) * z * se_log_rr
				if (!all(is.finite(exp(ci_log)))){
					stop("KK g-computation RR: could not compute a finite delta-method confidence interval.")
				}
				ci = exp(ci_log)
			}
			names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
			ci
		},
		compute_effect_pvalue = function(delta){
			estimand = private$get_estimand_type()
			if (is.null(delta)){
				delta = private$default_null_value()
			}
			if (should_run_asserts()) {
				assertNumeric(delta, len = 1)
			}
			if (identical(estimand, "RD")){
				est = private$cached_values$rd
				se = private$cached_values$se_rd
				if (!is.finite(est) || !is.finite(se) || se <= 0){
					return(NA_real_)
				}
				z_stat = (est - delta) / se
			} else {
				log_rr = private$cached_values$log_rr
				se_log_rr = private$cached_values$se_log_rr
				if (should_run_asserts()) {
					if (delta <= 0){
						stop("For RR inference, delta must be strictly positive.")
					}
				}
				if (!is.finite(log_rr) || !is.finite(se_log_rr) || se_log_rr <= 0){
					return(NA_real_)
				}
				z_stat = (log_rr - log(delta)) / se_log_rr
			}
			2 * stats::pnorm(-abs(z_stat))
		},
		shared = function(estimate_only = FALSE){
			if (gcomp_standardized_effect_cache_is_ready(private$cached_values, estimate_only = estimate_only)) return(invisible(NULL))
			X_full = gcomp_normalize_treatment_design_matrix(
				private$build_design_matrix(),
				covariate_names = private$get_covariate_names
			)
			fit = private$fit_logistic_with_sandwich(X_full, estimate_only = estimate_only)
			if (!is.null(fit)) {
				private$best_X_colnames = setdiff(colnames(fit$X), c("(Intercept)", "treatment"))
			}
			effects = if (!is.null(fit)) private$compute_standardized_effects(fit) else NULL
			if (private$harden && (is.null(fit) || is.null(effects) || !private$effects_are_usable(effects, estimate_only)) && ncol(X_full) > 2L){
				fit = private$fit_logistic_with_sandwich(X_full[, 1:2, drop = FALSE], estimate_only = estimate_only)
				effects = if (!is.null(fit)) private$compute_standardized_effects(fit) else NULL
			}
			if (is.null(fit) || is.null(effects) || !private$effects_are_usable(effects, estimate_only)){
				private$set_failed_fit_cache(inference_ready = !estimate_only)
				return(invisible(NULL))
			}
			private$cached_values = gcomp_cache_standardized_effects(
				private$cached_values,
				effects,
				inference_ready = !estimate_only
			)
		}
	)
)

# Static leaf-shared source (2026-08-18 migration, fix_inference_hierarchy.md
# "KK And IVWC Estimators"): `InferenceIncidKKGCompAbstract` and
# `InferenceAbstractKKMarginalIncid` (inference_incidence_KK_marginal_abstract.R)
# are left completely untouched -- both remain real R6 generators, because
# `InferenceAbstractKKMarginalIncid` is also the parent of
# `InferenceAbstractKKModifiedPoisson`/`InferenceIncidKKModifiedPoisson`
# (inference_incidence_KK_marginal.R), a separate estimator family not being
# migrated in this change. Only the two concrete leaves
# (`InferenceIncidKKGCompRiskDiff`/`RiskRatio`, both previously empty
# `public = list()` R6 leaves relying entirely on the abstract chain) are
# migrated; this component supplies everything they need. Self-harvests
# `InferenceIncidKKGCompAbstract`'s own body (which has no `initialize` of
# its own -- it inherited straight through) via
# `inference_component_source_parts()`, same as the non-KK sibling component
# `IncidenceGComputationSource` at the bottom of inference_incidence_gcomp_
# abstract.R, then layers in: (1) a hand-written `initialize` replicating
# `InferenceAbstractKKMarginalIncid$initialize` (incidence-response assert +
# no-censoring assert + Lesson 1's explicit `private$init_kk_passthrough()`,
# since post-migration `super$initialize()` resolves straight to root
# `Inference`); (2) `InferenceAbstractKKMarginalIncid`'s own KK-cluster
# helpers (`get_cluster_ids`, `get_covariate_names`, `compute_basic_match_
# data`, `supports_likelihood_tests`), copied verbatim since that class isn't
# itself a registered component; (3) the same generic-self-aliased-override
# pattern as `incidence_gcomp_generic_alias_overrides`
# (inference_incidence_gcomp.R) for every method whose harvested body calls
# `super$...` -- valid under the old R6 ladder, not under flat composition.
incidence_kk_gcomp_generic_alias_overrides = list(
	# Pinned from InferenceRandCI, NOT InferenceRand: unlike the non-KK
	# sibling (incidence_gcomp_generic_alias_overrides, which resolves to
	# InferenceRand via InferenceAsymp's ladder), this KK class's legacy
	# ladder (InferenceParamBootstrap -> ... -> InferenceRandCI) actually
	# resolves compute_rand_two_sided_pval to InferenceRandCI's version
	# (verified via R6 ancestor walk) -- InferenceRand's version refuses
	# incidence data outright ("Randomization tests are not supported for
	# incidence. Use Zhang method"), which is NOT what the legacy class does.
	# Lesson 3 applies here after all; the non-KK sibling's different choice
	# doesn't generalize because that class's OWN ladder resolves differently.
	compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval,
	get_supported_testing_types = InferenceAsymp$public_methods$get_supported_testing_types,
	compute_bootstrap_confidence_interval_generic = InferenceNonParamBootstrap$public_methods$compute_bootstrap_confidence_interval,
	compute_bootstrap_two_sided_pval_generic = InferenceNonParamBootstrap$public_methods$compute_bootstrap_two_sided_pval,
	approximate_bootstrap_distribution_beta_hat_T_generic = InferenceNonParamBootstrap$public_methods$approximate_bootstrap_distribution_beta_hat_T,
	compute_bayesian_bootstrap_two_sided_pval_generic = InferenceBayesianBootstrap$public_methods$compute_bayesian_bootstrap_two_sided_pval,
	compute_bayesian_bootstrap_confidence_interval_generic = InferenceBayesianBootstrap$public_methods$compute_bayesian_bootstrap_confidence_interval,
	compute_jackknife_wald_two_sided_pval_generic = InferenceJackknife$public_methods$compute_jackknife_wald_two_sided_pval,
	compute_jackknife_wald_confidence_interval_generic = InferenceJackknife$public_methods$compute_jackknife_wald_confidence_interval,
	approximate_bootstrap_distribution_beta_hat_T = function(B = 501, show_progress = TRUE, debug = FALSE, bootstrap_type = NULL){
		self$approximate_bootstrap_distribution_beta_hat_T_generic(B, show_progress, debug, bootstrap_type)
	},
	compute_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L){
		type_resolved = tolower(type %||% "percentile")
		if (identical(private$get_estimand_type(), "RR") && identical(type_resolved, "basic")) {
			return(private$compute_rr_bootstrap_basic_confidence_interval(alpha = alpha, B = B, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples))
		}
		self$compute_bootstrap_confidence_interval_generic(alpha = alpha, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples)
	},
	compute_bootstrap_two_sided_pval = function(delta = NULL, B = 501, type = "symmetric", na.rm = FALSE, show_progress = TRUE, min_number_usable_samples = 5L){
		if (is.null(delta)){
			delta = private$default_null_value()
		}
		self$compute_bootstrap_two_sided_pval_generic(delta = delta, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples)
	},
	compute_bayesian_bootstrap_two_sided_pval = function(delta = NULL, B = 501, type = NULL, na.rm = FALSE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL){
		if (is.null(delta)){
			delta = private$default_null_value()
		}
		self$compute_bayesian_bootstrap_two_sided_pval_generic(delta = delta, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type)
	},
	compute_bayesian_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL){
		type_resolved = tolower(type %||% "percentile")
		if (identical(private$get_estimand_type(), "RR") && type_resolved %in% c("basic", "wald")) {
			return(private$compute_rr_bayesian_bootstrap_log_confidence_interval(alpha = alpha, B = B, type = type_resolved, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type))
		}
		self$compute_bayesian_bootstrap_confidence_interval_generic(alpha = alpha, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type)
	},
	compute_jackknife_wald_two_sided_pval = function(delta = NULL, unit = "auto"){
		if (is.null(delta)){
			delta = private$default_null_value()
		}
		if (identical(private$get_estimand_type(), "RR")) {
			return(private$compute_rr_jackknife_wald_two_sided_pval(delta = delta, unit = unit))
		}
		self$compute_jackknife_wald_two_sided_pval_generic(delta = delta, unit = unit)
	},
	compute_jackknife_wald_confidence_interval = function(alpha = 0.05, unit = "auto"){
		if (identical(private$get_estimand_type(), "RR")) {
			return(private$compute_rr_jackknife_wald_confidence_interval(alpha = alpha, unit = unit))
		}
		self$compute_jackknife_wald_confidence_interval_generic(alpha = alpha, unit = unit)
	}
)

# Reusable-bootstrap-worker wiring, mirroring `incidence_gcomp_worker_
# overrides` in inference_incidence_gcomp.R exactly (same rationale:
# `best_X_colnames`/`gcomp_boot_beta`, the warm-start caches
# `compute_weighted_gcomp_estimate()` chains across resampling replicates,
# only do anything useful when the SAME worker object is reused across an
# entire resampling run rather than being freshly re-cloned per replicate).
# Missing this block on the first pass of this migration left
# `supports_reusable_bootstrap_worker()` silently falling back to the
# generic default (FALSE) instead of the legacy ladder's TRUE, which
# produced a *wrong-but-plausible-looking* divergence: the migrated class's
# `approximate_randomization_distribution_beta_hat_T`/
# `approximate_rand_bootstrap_distribution_beta_hat_T` varied properly
# across replicates while the legacy class returned the same constant value
# every time (a symptom of the worker-reuse path, not a red flag on its
# own) -- caught by the golden, not by inspection.
incidence_kk_gcomp_worker_overrides = list(
	supports_reusable_bootstrap_worker = function(){
		TRUE
	},
	create_bootstrap_worker_state = function(){
		private$create_design_backed_bootstrap_worker_state()
	},
	load_bootstrap_sample_into_worker = function(worker_state, indices){
		private$load_bootstrap_sample_into_design_backed_worker(worker_state, indices)
	},
	compute_bootstrap_worker_estimate = function(worker_state){
		private$compute_bootstrap_worker_estimate_via_compute_treatment_estimate(worker_state)
	}
)

incidence_kk_gcomp_marginal_incid_overrides = list(
	is_a_kk_marginal_incid = function() TRUE,
	supports_likelihood_tests = function() FALSE,
	compute_basic_match_data = function() private$compute_basic_kk_match_data_impl(),
	get_covariate_names = function(){
		X = private$get_X()
		p = ncol(X)
		x_names = colnames(X)
		if (is.null(x_names)){
			x_names = paste0("x", seq_len(p))
		}
		x_names
	},
	get_cluster_ids = function(){
		des_priv = private$des_obj_priv_int
		m_vec = private$m
		if (is.null(m_vec)) m_vec = rep(NA_integer_, private$n)
		m_vec_int = as.integer(m_vec)
		m_vec_int[is.na(m_vec_int)] = 0L
		des_m = des_priv$m
		if (is.null(des_m)) des_m = rep(NA_integer_, private$n)
		des_m_int = as.integer(des_m)
		des_m_int[is.na(des_m_int)] = 0L
		if (!is.null(des_priv$cluster_id) && identical(m_vec_int, des_m_int)){
			return(des_priv$cluster_id)
		}
		if (!is.null(private$cached_values$cluster_id) &&
			identical(m_vec_int, private$cached_values$cluster_id_m_vec)){
			return(private$cached_values$cluster_id)
		}
		cluster_id = des_priv$compute_matching_cluster_ids(m_vec_int)
		if (identical(m_vec_int, des_m_int)){
			des_priv$cluster_id = cluster_id
			des_priv$cluster_id_m_vec = m_vec_int
		} else {
			private$cached_values$cluster_id = cluster_id
			private$cached_values$cluster_id_m_vec = m_vec_int
		}
		cluster_id
	}
)

IncidenceKKGComputationSource = local({
	parts = inference_component_source_parts(InferenceIncidKKGCompAbstract)
	list(
		public = utils::modifyList(parts$public, c(
			list(
				#' @description Initialize KK marginal g-computation inference for a
				#'   completed incidence design; prepares the KK match structure used by
				#'   the cluster-robust sandwich covariance.
				#' @param des_obj A completed \code{Design} object with an incidence response.
				#' @param model_formula   Optional formula for covariate adjustment.
				#' @param verbose Whether to print progress messages.
				#' @param smart_cold_start_default Whether to use smart cold start values.
				initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL){
					if (should_run_asserts()) {
						assertResponseType(des_obj$get_response_type(), "incidence")
					}
					super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
					if (should_run_asserts()) {
						assertNoCensoring(private$any_censoring)
					}
					# Lesson 1 (see KKNewcombeRiskDiffIVWCSource): post-migration
					# super$initialize() resolves to the root Inference, not
					# InferenceAbstractKKMarginalIncid, so the KK match-structure setup
					# that ancestor's initialize() performed must be invoked explicitly
					# here.
					private$init_kk_passthrough(des_obj)
				}
			),
			incidence_kk_gcomp_generic_alias_overrides
		)),
		private = utils::modifyList(parts$private, c(
			incidence_kk_gcomp_marginal_incid_overrides,
			incidence_kk_gcomp_worker_overrides
		))
	)
})
