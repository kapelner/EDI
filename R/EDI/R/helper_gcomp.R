#' Internal G-Computation Design-Matrix Helpers
#'
#' Normalizes a g-computation treatment design matrix without accessing an
#' inference object. G-computation families use the same two leading columns:
#' an intercept followed by treatment. Existing column names are preserved.
#'
#' @keywords internal
#' @noRd
gcomp_normalize_treatment_design_matrix = function(X, covariate_names = NULL){
	if (is.null(dim(X))) {
		X = matrix(X, ncol = 2L)
	}
	if (is.null(colnames(X))) {
		if (ncol(X) > 2L && is.function(covariate_names)) {
			covariate_names = covariate_names()
		}
		colnames(X) = c(
			"(Intercept)",
			"treatment",
			if (ncol(X) > 2L) covariate_names else NULL
		)
	}
	X
}

#' Selects the covariate column to drop from a g-computation fit retry.
#'
#' The intercept and treatment columns are always retained in positions one and
#' two. Among covariates, the largest finite coefficient magnitude is dropped;
#' if no coefficient is usable, the last covariate is dropped deterministically.
#'
#' @keywords internal
#' @noRd
gcomp_select_covariate_to_drop = function(X_curr, coef_hat){
	if (ncol(X_curr) <= 2L) return(NA_integer_)
	covariate_cols = seq.int(3L, ncol(X_curr))
	coef_mags = abs(coef_hat[covariate_cols])
	if (length(coef_mags) == 0L || all(!is.finite(coef_mags))){
		return(tail(covariate_cols, 1L))
	}
	covariate_cols[which.max(replace(coef_mags, !is.finite(coef_mags), -Inf))]
}

#' Computes logistic potential outcomes for a treatment design matrix.
#'
#' Returns treated and control counterfactual design matrices, subject-level
#' risks, and their empirical means. Variance and estimand-specific logic stay
#' with the calling inference family.
#'
#' @keywords internal
#' @noRd
gcomp_logistic_potential_outcomes = function(X_fit, coef_hat, j_treat){
	X1 = X_fit
	X0 = X_fit
	X1[, j_treat] = 1
	X0[, j_treat] = 0
	risk1_i = stats::plogis(as.numeric(X1 %*% coef_hat))
	risk0_i = stats::plogis(as.numeric(X0 %*% coef_hat))
	list(
		X1 = X1,
		X0 = X0,
		risk1_i = risk1_i,
		risk0_i = risk0_i,
		risk1 = mean(risk1_i),
		risk0 = mean(risk0_i)
	)
}

#' Checks whether standardized g-computation effects are cache-ready.
#'
#' Estimate-only readiness requires a cached point estimate. Full-inference
#' readiness is tracked explicitly because estimate-only paths intentionally
#' cache \code{NA} standard errors.
#'
#' @keywords internal
#' @noRd
gcomp_standardized_effect_cache_is_ready = function(cached_values, estimate_only = FALSE){
	if (isTRUE(estimate_only)){
		return(!is.null(cached_values$rd) || !is.null(cached_values$rr))
	}
	isTRUE(cached_values$gcomp_standardized_effects_inference_ready)
}

#' Maps standardized g-computation effects into the inference cache.
#'
#' This helper is deliberately scoped to incidence g-computation classes, which
#' share the same standardized risk, RD, RR, and delta-method cache fields.
#'
#' @keywords internal
#' @noRd
gcomp_cache_standardized_effects = function(cached_values, effects, inference_ready = FALSE){
	for (field in c(
		"summary_table",
		"full_coefficients",
		"full_vcov",
		"risk1",
		"risk0",
		"rd",
		"se_rd",
		"log_rr",
		"rr",
		"se_log_rr"
	)){
		cached_values[[field]] = effects[[field]]
	}
	cached_values$gcomp_standardized_effects_inference_ready = isTRUE(inference_ready)
	cached_values
}

#' Maps a failed standardized g-computation fit into the inference cache.
#'
#' @keywords internal
#' @noRd
gcomp_cache_failed_standardized_effects = function(cached_values, inference_ready = TRUE){
	gcomp_cache_standardized_effects(
		cached_values = cached_values,
		effects = list(
			summary_table = NULL,
			full_coefficients = NULL,
			full_vcov = NULL,
			risk1 = NULL,
			risk0 = NULL,
			rd = NA_real_,
			se_rd = NA_real_,
			log_rr = NA_real_,
			rr = NA_real_,
			se_log_rr = NA_real_
		),
		inference_ready = inference_ready
	)
}

#' Weighted Huber-White (HC0) sandwich covariance of a logistic / fractional-logit
#' working model fitted with bootstrap row weights.
#'
#' Treats the weights as frequency weights, as a nonparametric bootstrap resample's
#' multiplicities would be: bread \eqn{\sum_i w_i \mu_i(1-\mu_i) x_i x_i^\top}, meat
#' \eqn{\sum_i w_i (y_i - \mu_i)^2 x_i x_i^\top}. The weights are first rescaled to
#' mean one over all rows, so the result does not depend on their overall scale and
#' unit weights reproduce the unweighted HC0 sandwich that
#' \code{gcomp_logistic_post_fit_cpp()} / \code{gcomp_fractional_logit_post_fit_cpp()}
#' compute (v1.0.6-TODO-134: the Bayesian-bootstrap studentized path needs a per-draw
#' standard error).
#'
#' @return The \eqn{p \times p} covariance matrix (named like \code{coef_hat}), or
#'   \code{NULL} when it cannot be formed.
#' @keywords internal
#' @noRd
gcomp_weighted_logistic_sandwich_vcov = function(X_fit, y, coef_hat, row_weights, clip_eps = .Machine$double.eps){
	w = as.numeric(row_weights)
	y = as.numeric(y)
	if (length(w) != nrow(X_fit) || length(y) != nrow(X_fit) || length(coef_hat) != ncol(X_fit)) return(NULL)
	w[!is.finite(w) | w < 0] = 0
	w_mean = mean(w)
	if (!is.finite(w_mean) || w_mean <= 0) return(NULL)
	w = w / w_mean
	ok = w > 0 & is.finite(y)
	if (sum(ok) <= ncol(X_fit)) return(NULL)
	X = X_fit[ok, , drop = FALSE]
	w = w[ok]
	y = y[ok]
	mu = stats::plogis(as.numeric(X %*% as.numeric(coef_hat)))
	mu = pmin(pmax(mu, clip_eps), 1 - clip_eps)
	info = crossprod(X, X * (w * mu * (1 - mu)))
	meat = crossprod(X, X * (w * (y - mu)^2))
	bread = tryCatch(solve(info), error = function(e) NULL)
	if (is.null(bread) || any(!is.finite(bread))) return(NULL)
	vcov_mat = bread %*% meat %*% bread
	vcov_mat = (vcov_mat + t(vcov_mat)) / 2
	if (any(!is.finite(vcov_mat))) return(NULL)
	dimnames(vcov_mat) = list(names(coef_hat), names(coef_hat))
	vcov_mat
}

#' Weighted cluster-robust sandwich covariance of a logistic working model fitted
#' with bootstrap row weights.
#'
#' The KK-pair analogue of \code{gcomp_weighted_logistic_sandwich_vcov()}: bread
#' \eqn{(\sum_i w_i \mu_i(1-\mu_i) x_i x_i^\top)^{-1}}, meat
#' \eqn{\sum_g s_g s_g^\top} with cluster score
#' \eqn{s_g = \sum_{i \in g} \sqrt{w_i} (y_i - \mu_i) x_i}, no small-sample factor.
#' The square root makes the meat linear in the weight when it is constant within a
#' cluster (\eqn{w_g s_g s_g^\top}, as for the pair-level Bayesian/nonparametric
#' bootstrap weights): a cluster drawn k times adds k copies of its outer product,
#' the frequency-weight convention of \code{gcomp_weighted_logistic_sandwich_vcov()}.
#' The weights are rescaled to mean one over all rows, so unit weights reproduce
#' \code{gcomp_logistic_cluster_post_fit_cpp()}'s covariance (v1.0.6-TODO-149: the
#' Bayesian-bootstrap studentized path needs a per-draw standard error).
#'
#' @return The \eqn{p \times p} covariance matrix (named like \code{coef_hat}), or
#'   \code{NULL} when it cannot be formed.
#' @keywords internal
#' @noRd
gcomp_weighted_logistic_cluster_sandwich_vcov = function(X_fit, y, coef_hat, row_weights, cluster_id, clip_eps = .Machine$double.eps){
	w = as.numeric(row_weights)
	y = as.numeric(y)
	if (length(w) != nrow(X_fit) || length(y) != nrow(X_fit) || length(cluster_id) != nrow(X_fit) ||
		length(coef_hat) != ncol(X_fit)) return(NULL)
	w[!is.finite(w) | w < 0] = 0
	w_mean = mean(w)
	if (!is.finite(w_mean) || w_mean <= 0) return(NULL)
	w = w / w_mean
	ok = w > 0 & is.finite(y) & !is.na(cluster_id)
	if (sum(ok) <= ncol(X_fit)) return(NULL)
	X = X_fit[ok, , drop = FALSE]
	w = w[ok]
	y = y[ok]
	cl = cluster_id[ok]
	mu = stats::plogis(as.numeric(X %*% as.numeric(coef_hat)))
	mu = pmin(pmax(mu, clip_eps), 1 - clip_eps)
	info = crossprod(X, X * (w * mu * (1 - mu)))
	scores = rowsum(X * (sqrt(w) * (y - mu)), group = cl, reorder = FALSE)
	meat = crossprod(scores)
	bread = tryCatch(solve(info), error = function(e) NULL)
	if (is.null(bread) || any(!is.finite(bread))) return(NULL)
	vcov_mat = bread %*% meat %*% bread
	vcov_mat = (vcov_mat + t(vcov_mat)) / 2
	if (any(!is.finite(vcov_mat))) return(NULL)
	dimnames(vcov_mat) = list(names(coef_hat), names(coef_hat))
	vcov_mat
}

#' Weighted logistic refit for a g-computation resampling replicate, with retries.
#'
#' v1.0.6-TODO-192: a replicate's fit is accepted only when IRLS reports convergence
#' and \code{private$coefficients_are_usable()} accepts the coefficients. The attempts
#' run in order: the chained warm start of the previous accepted replicate
#' (\code{chain_beta}, when its length matches), the full-data fit's warm start, then a
#' cold start; an attempt identical to an earlier one is skipped. Before this, the KK
#' class cached a diverged fit (\eqn{|b| \approx 10^9} after 100 IRLS steps) as the next
#' replicate's warm start, and every later replicate of the chain diverged too.
#'
#' @param private The calling inference object's private environment.
#' @param X_fit,y_fit,w_fit Design rows, responses and positive weights to fit.
#' @param chain_beta The previous accepted replicate's coefficients, or \code{NULL}.
#' @return \code{list(fit, last)}: \code{fit} is the accepted fit or \code{NULL};
#'   \code{last} is the last attempt that returned a coefficient vector (the caller's
#'   covariate-drop rule reads its coefficients), or \code{NULL} when every attempt
#'   errored.
#' @keywords internal
#' @noRd
gcomp_weighted_logistic_fit_with_retries = function(private, X_fit, y_fit, w_fit, chain_beta = NULL){
	p_fit = ncol(X_fit)
	full_beta = private$get_fit_warm_start_for_length("beta", p_fit)
	full_fisher = private$get_fit_warm_start_fisher(p_fit)
	starts = list()
	if (!is.null(chain_beta) && length(chain_beta) == p_fit) {
		starts[[length(starts) + 1L]] = list(beta = chain_beta, fisher = full_fisher)
	}
	starts[[length(starts) + 1L]] = list(beta = full_beta, fisher = full_fisher)
	starts[[length(starts) + 1L]] = list(beta = NULL, fisher = NULL)
	last = NULL
	tried = list()
	for (start in starts) {
		if (any(vapply(tried, identical, logical(1L), start))) next
		tried[[length(tried) + 1L]] = start
		mod = tryCatch(
			fast_logistic_regression_weighted_cpp(
				X = X_fit,
				y = y_fit,
				weights = w_fit,
				warm_start_beta = start$beta,
				warm_start_fisher_info = start$fisher
			),
			error = function(e) {
				if (is_edi_control_condition(e)) stop(e)
				NULL
			}
		)
		if (is.null(mod) || is.null(mod$b)) next
		last = mod
		if (!isFALSE(mod$converged) && private$coefficients_are_usable(as.numeric(mod$b))) {
			return(list(fit = mod, last = mod))
		}
	}
	list(fit = NULL, last = last)
}

#' Logistic g-computation fit with a covariate-drop retry loop and a sandwich covariance.
#'
#' Shared by the KK and non-KK incidence g-computation classes (v1.0.6-TODO-193,
#' code-duplication audit decision \code{code-duplication-da35f9c8f}); they differ only in
#' the fitted-probability clamp and the post-fit covariance (HC0 for the non-KK class,
#' KK-pair cluster-robust for the KK class), passed in as \code{clip_eps} and
#' \code{post_fit}. Each fit warm-starts from the object's warm-start cache. A fit whose
#' coefficients are unusable, whose IRLS weights degenerate, or whose post-fit step fails
#' is retried without the covariate \code{gcomp_select_covariate_to_drop()} picks, until
#' only intercept and treatment remain.
#'
#' @param private The calling inference object's private environment.
#' @param X_full The normalized full design (intercept, treatment, covariates).
#' @param estimate_only When \code{TRUE}, return after the fit, with no covariance.
#' @param clip_eps Fitted-probability clamp applied before the IRLS weights are checked.
#' @param post_fit \code{function(X_fit, coef_hat, mu_hat, j_treat)} returning the post-fit
#'   list (with \code{$vcov}); an error in it counts as a failed post-fit step.
#' @return The fit list the classes' \code{compute_standardized_effects()} reads, or
#'   \code{NULL}.
#' @keywords internal
#' @noRd
gcomp_fit_logistic_with_sandwich = function(private, X_full, estimate_only, clip_eps, post_fit){
	X_curr = X_full
	# v1.0.6-TODO-138: remember the QR-rank design and its first fit so the caller can name
	# covariates the drop loop removed beyond collinearity.
	rank_colnames = NULL
	rank_coefs = NULL
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
		if (is.null(rank_colnames)) {
			rank_colnames = colnames(X_fit)
			rank_coefs = coef_hat
		}
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
				estimate_only = TRUE,
				qr_rank_colnames = rank_colnames,
				qr_rank_coefficients = rank_coefs
			))
		}
		mu_hat = inv_logit(X_fit %*% coef_hat)
		mu_hat = pmin(pmax(as.numeric(mu_hat), clip_eps), 1 - clip_eps)
		W = mu_hat * (1 - mu_hat)
		if (any(!is.finite(W)) || any(W <= 0)){
			if (ncol(X_curr) <= 2L) return(NULL)
			drop_col = gcomp_select_covariate_to_drop(X_curr, coef_hat)
			if (!is.finite(drop_col)) return(NULL)
			X_curr = X_curr[, -drop_col, drop = FALSE]
			next
		}
		post = tryCatch(
			post_fit(X_fit, coef_hat, mu_hat, j_treat),
			error = function(e) {
				if (is_edi_control_condition(e)) stop(e)
				NULL
			}
		)
		if (is.null(post)){
			if (ncol(X_curr) <= 2L) return(NULL)
			drop_col = gcomp_select_covariate_to_drop(X_curr, coef_hat)
			if (!is.finite(drop_col)) return(NULL)
			X_curr = X_curr[, -drop_col, drop = FALSE]
			next
		}
		coef_names = colnames(X_fit)
		names(coef_hat) = coef_names
		vcov_robust = post$vcov
		colnames(vcov_robust) = rownames(vcov_robust) = coef_names
		return(list(
			X = X_fit,
			j_treat = j_treat,
			coefficients = coef_hat,
			vcov = vcov_robust,
			mu_hat = mu_hat,
			post_fit = post,
			estimate_only = FALSE,
			qr_rank_colnames = rank_colnames,
			qr_rank_coefficients = rank_coefs
		))
	}
}

#' Log-scale PRW subsampling / m-out-of-n p-value and confidence interval for a risk ratio.
#'
#' One body for the subsampling and m-out-of-n families (v1.0.6-TODO-193, code-duplication
#' audit decision \code{code-duplication-d593b90a9}); \code{family} picks the draw method,
#' the size argument (\code{b} or \code{m}), the failure-reason prefix and the procedure
#' tag. The pivot itself is \code{private$compute_rr_resampling_pivot()}.
#'
#' @keywords internal
#' @noRd
gcomp_rr_resampling_family = function(self, family){
	if (identical(family, "subsampling")) {
		list(distribution_fn = self$approximate_subsampling_distribution_beta_hat_T, size_arg_name = "b")
	} else {
		list(distribution_fn = self$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T, size_arg_name = "m")
	}
}

#' @keywords internal
#' @noRd
gcomp_rr_resampling_two_sided_pval = function(self, private, family, delta, B, size, show_progress, min_number_usable_samples, resampling_type){
	if (!is.finite(delta) || delta <= 0) {
		edi_record_procedure_failure(self, private, paste0(family, "_log_risk_ratio_null_unavailable"), "estimate")
		return(NA_real_)
	}
	fam = gcomp_rr_resampling_family(self, family)
	pivot = private$compute_rr_resampling_pivot(fam$distribution_fn, fam$size_arg_name, size, B, resampling_type, show_progress)
	if (!isTRUE(pivot$ok)) {
		if (isTRUE(private$harden)) edi_record_procedure_failure(self, private, pivot$reason, "estimate", procedure = family)
		return(NA_real_)
	}
	if (length(pivot$finite) < as.integer(min_number_usable_samples)) {
		if (isTRUE(private$harden)) edi_record_procedure_failure(self, private, paste0(family, "_too_few_finite_estimates"), "estimate")
		return(NA_real_)
	}
	private$resampling_centered_pval(pivot$centered_scaled, est = pivot$log_est, delta = log(delta), n_units = pivot$n_units, scaling = "sqrt_n")
}

#' @keywords internal
#' @noRd
gcomp_rr_resampling_confidence_interval = function(self, private, family, alpha, B, size, show_progress, min_number_usable_samples, resampling_type){
	ci = c(NA_real_, NA_real_)
	names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
	fam = gcomp_rr_resampling_family(self, family)
	pivot = private$compute_rr_resampling_pivot(fam$distribution_fn, fam$size_arg_name, size, B, resampling_type, show_progress, alpha = alpha)
	if (!isTRUE(pivot$ok)) {
		if (isTRUE(private$harden)) return(private$missing_bootstrap_ci(alpha, pivot$reason, stage = "estimate", procedure = family))
		return(ci)
	}
	if (length(pivot$finite) < as.integer(min_number_usable_samples)) {
		if (isTRUE(private$harden)) return(private$missing_bootstrap_ci(alpha, paste0(family, "_too_few_finite_estimates"), stage = "estimate"))
		return(ci)
	}
	log_ci = private$resampling_ci_from_centered_distribution(pivot$centered_scaled, alpha = alpha, est = pivot$log_est, n_units = pivot$n_units, scaling = "sqrt_n")
	ci[] = exp(log_ci)
	if (!all(is.finite(ci)) || private$bootstrap_confidence_interval_extreme(ci, est = pivot$est)) {
		if (isTRUE(private$harden)) return(private$missing_bootstrap_ci(alpha, paste0(family, "_extreme_confidence_interval"), stage = "estimate"))
	}
	ci
}

#' Private risk-ratio / null-value methods shared by the incidence g-computation classes.
#'
#' One copy for \code{InferenceIncidGCompAbstract} and \code{InferenceIncidKKGCompAbstract}
#' (v1.0.6-TODO-193, code-duplication audit decision \code{code-duplication-db001874c}):
#' the default null value, the log-scale bootstrap / Bayesian-bootstrap risk-ratio
#' intervals, the risk-ratio jackknife-Wald methods and the log-scale subsampling /
#' m-out-of-n pivot. Both classes add this list to their R6 \code{private} list.
#'
#' @keywords internal
#' @noRd
gcomp_incid_rr_private_methods = list(
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
		# v1.0.6-TODO-175 (3): the same replicate and interval checks as the other bootstrap
		# CI types (both judge a risk ratio on log(RR)); before, a degenerate basic interval
		# such as [1.4e-8, 20] or [0.04, 7.6e7] was returned silently.
		if (private$bootstrap_ci_estimates_extreme(boot_distr, est = est)) {
			return(private$missing_bootstrap_ci(alpha, "bootstrap_extreme_finite_estimates", stage = "estimate"))
		}
		q = stats::quantile(log(boot_distr), probs = c(1 - alpha / 2, alpha / 2), names = FALSE, type = 8)
		ci[] = exp(2 * log(est) - q)
		if (private$bootstrap_confidence_interval_extreme(ci, est = est, theta = boot_distr)) {
			return(private$missing_bootstrap_ci(alpha, "bootstrap_extreme_confidence_interval", stage = "estimate"))
		}
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
		# v1.0.6-TODO-175 (3): same checks as the generic Bayesian-bootstrap CI types.
		if (private$bootstrap_ci_estimates_extreme(boot_distr, est = est)) {
			return(private$missing_bootstrap_ci(alpha, "bayesian_bootstrap_extreme_finite_estimates", stage = "estimate"))
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
		if (private$bootstrap_confidence_interval_extreme(ci, est = est, theta = boot_distr)) {
			return(private$missing_bootstrap_ci(alpha, "bayesian_bootstrap_extreme_confidence_interval",
				stage = if (identical(type, "wald")) "se" else "estimate"))
		}
		ci
	},
	# v1.0.6-TODO-137: shared with the KK/non-KK sibling; the helpers in
	# inference_all_abstract_jackknife.R apply the compute_jackknife_summary()
	# guards and warn on every NA.
	compute_rr_jackknife_log_se = function(unit = "auto"){
		edi_rr_jackknife_log_summary(self, private, unit = unit)$se_log
	},
	compute_rr_jackknife_wald_two_sided_pval = function(delta = 1, unit = "auto"){
		edi_rr_jackknife_wald_two_sided_pval(self, private, delta = delta, unit = unit)
	},
	compute_rr_jackknife_wald_confidence_interval = function(alpha = 0.05, unit = "auto"){
		edi_rr_jackknife_wald_confidence_interval(self, private, alpha = alpha, unit = unit)
	},
	# Log-scale PRW subsampling/m-out-of-n pivot for the risk-ratio estimand,
	# mirroring compute_rr_bootstrap_basic_confidence_interval()'s log-scale
	# convention above. The generic centered-pivot machinery in
	# inference_ext_exchangeable_resampling_units.R/inference_ext_prw_
	# subsampling.R/inference_ext_m_out_of_n_bootstrap.R centers and scales
	# on the RAW estimate scale (appropriate for an additive estimand like
	# risk difference, whose null is 0), which is not the right pivot for a
	# ratio estimand whose null is 1: a raw risk ratio is right-skewed in
	# finite samples, and that skew is severe at the reduced effective
	# sample sizes (b/m ~ n^0.7) subsampling and m-out-of-n draw at --
	# confirmed empirically via near-total null rejection specific to
	# InferenceIncidGCompRiskRatio's subsampling/m-out-of-n paths while the
	# identical generic code stays well-calibrated for the additive
	# InferenceIncidGCompRiskDiff sibling. Recentering on log(estimate) with
	# a log(delta) null, as already done for the bootstrap/BBT CIs and the
	# jackknife-Wald methods above, fixes this the same way.
	compute_rr_resampling_pivot = function(distribution_fn, size_arg_name, size, B, resampling_type, show_progress, alpha = NULL){
		# Control conditions (timeouts, interrupts) re-throw, as in the generic pivots (v1.0.6-TODO-196).
		est = tryCatch(as.numeric(self$compute_estimate(estimate_only = TRUE))[1L], error = private$resampling_error_to_na)
		if (!is.finite(est) || est <= 0) {
			return(list(ok = FALSE, reason = "resampling_original_estimate_unavailable"))
		}
		# A list-valued b / m goes through the same minimum-volatility selector as the
		# generic paths (v1.0.6-TODO-196); a failed selection is recorded even unhardened.
		if (is.list(size)) {
			family = if (identical(size_arg_name, "b")) "subsampling" else "m_out_of_n"
			size = private$select_resampling_size_from_spec(family, size, B = B, alpha = alpha,
				resampling_type = resampling_type, scaling = "sqrt_n", show_progress = show_progress)
			if (!is.numeric(size) || length(size) != 1L || !is.finite(size)) {
				reason = if (identical(family, "subsampling")) "subsampling_b_selection_failed" else "m_out_of_n_m_selection_failed"
				if (!isTRUE(private$harden)) {
					if (!is.null(alpha)) private$missing_bootstrap_ci(alpha, reason, stage = "estimate")
					else edi_record_procedure_failure(self, private, reason, "estimate")
				}
				return(list(ok = FALSE, reason = reason))
			}
		}
		unit_info = private$get_exchangeable_units(unit = "auto", resampling_type = resampling_type)
		size = private$resolve_resampling_size(size, unit_info$n_units, size_arg_name)
		draw_args = list(B = B, show_progress = show_progress)
		draw_args[[size_arg_name]] = size
		draw_args[[if (identical(size_arg_name, "b")) "subsampling_type" else "bootstrap_type"]] = resampling_type
		draws = as.numeric(do.call(distribution_fn, draw_args))
		finite = draws[is.finite(draws) & draws > 0]
		if (!length(finite)) {
			return(list(ok = FALSE, reason = "resampling_too_few_finite_estimates"))
		}
		list(
			ok = TRUE,
			reason = NA_character_,
			est = est,
			log_est = log(est),
			finite = finite,
			centered_scaled = private$resampling_scaling_factor(size, "sqrt_n") * (log(finite) - log(est)),
			n_units = unit_info$n_units
		)
	},
	# Subsampling and m-out-of-n share one body (v1.0.6-TODO-193, code-duplication audit
	# decision code-duplication-d593b90a9): gcomp_rr_resampling_two_sided_pval() /
	# gcomp_rr_resampling_confidence_interval() below.
	compute_rr_subsampling_two_sided_pval = function(delta = 1, B = 501, b = NULL, show_progress = TRUE, min_number_usable_samples = 5L, subsampling_type = NULL){
		gcomp_rr_resampling_two_sided_pval(self, private, "subsampling", delta, B, b, show_progress, min_number_usable_samples, subsampling_type)
	},
	compute_rr_subsampling_confidence_interval = function(alpha = 0.05, B = 501, b = NULL, show_progress = TRUE, min_number_usable_samples = 5L, subsampling_type = NULL){
		gcomp_rr_resampling_confidence_interval(self, private, "subsampling", alpha, B, b, show_progress, min_number_usable_samples, subsampling_type)
	},
	compute_rr_m_out_of_n_bootstrap_two_sided_pval = function(delta = 1, B = 501, m = NULL, show_progress = TRUE, min_number_usable_samples = 5L, bootstrap_type = NULL){
		gcomp_rr_resampling_two_sided_pval(self, private, "m_out_of_n", delta, B, m, show_progress, min_number_usable_samples, bootstrap_type)
	},
	compute_rr_m_out_of_n_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, m = NULL, show_progress = TRUE, min_number_usable_samples = 5L, bootstrap_type = NULL){
		gcomp_rr_resampling_confidence_interval(self, private, "m_out_of_n", alpha, B, m, show_progress, min_number_usable_samples, bootstrap_type)
	}
)
