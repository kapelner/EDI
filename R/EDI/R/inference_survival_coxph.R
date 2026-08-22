# Internal survival::coxph.fit adapters used by Cox inference classes.
.fit_survival_coxph_kernel = function(X, y, dead, strata = NULL, offset = NULL, estimate_only = FALSE){
	X = as.matrix(X)
	y = as.numeric(y)
	dead = as.numeric(dead)
	if (is.null(colnames(X))) colnames(X) = paste0("x", seq_len(ncol(X)))
	strata_arg = if (is.null(strata)) NULL else as.integer(strata)
	offset_arg = if (is.null(offset)) NULL else as.numeric(offset)
	fit = tryCatch(
		suppressWarnings(survival::coxph.fit(
			x = X,
			y = survival::Surv(y, dead),
			strata = strata_arg,
			offset = offset_arg,
			init = NULL,
			control = survival::coxph.control(),
			weights = NULL,
			method = "breslow",
			rownames = as.character(seq_along(y)),
			resid = FALSE
		)),
		error = function(e) NULL
	)
	if (is.null(fit)) return(NULL)
	b = as.numeric(fit$coefficients %||% numeric(0))
	if (ncol(X) > 0L) {
		if (length(b) != ncol(X) || !all(is.finite(b))) return(NULL)
		names(b) = colnames(X)
	}
	if (estimate_only) {
		return(list(b = b, coefficients = b, vcov = NULL, var = NULL,
			neg_ll = NA_real_, neg_loglik = NA_real_, neg_log_lik = NA_real_,
			fisher_information = NULL, converged = TRUE))
	}
	vcov = if (ncol(X) > 0L) {
		v = as.matrix(fit$var)
		dimnames(v) = list(colnames(X), colnames(X))
		v
	} else {
		matrix(numeric(0), 0L, 0L)
	}
	neg_ll = -as.numeric(utils::tail(fit$loglik, 1L))
	if (!is.finite(neg_ll)) return(NULL)
	fisher = if (ncol(vcov) > 0L) {
		tryCatch(solve(vcov), error = function(e) NULL)
	} else {
		matrix(numeric(0), 0L, 0L)
	}
	list(
		b = b,
		coefficients = b,
		vcov = vcov,
		var = vcov,
		neg_ll = neg_ll,
		neg_loglik = neg_ll,
		neg_log_lik = neg_ll,
		fisher_information = fisher,
		converged = TRUE
	)
}

.fit_survival_coxph_fixed_kernel = function(X, y, dead, strata = NULL, fixed_idx = 1L, fixed_value = 0){
	X = as.matrix(X)
	p = ncol(X)
	if (p < 1L || fixed_idx < 1L || fixed_idx > p) return(NULL)
	if (is.null(colnames(X))) colnames(X) = paste0("x", seq_len(p))
	fixed_idx = as.integer(fixed_idx)
	X_fixed = X[, fixed_idx, drop = TRUE]
	free_idx = setdiff(seq_len(p), fixed_idx)
	X_free = X[, free_idx, drop = FALSE]
	offset = as.numeric(fixed_value) * as.numeric(X_fixed)
	fit = .fit_survival_coxph_kernel(X_free, y, dead, strata = strata, offset = offset)
	if (is.null(fit)) return(NULL)
	b = numeric(p)
	b[fixed_idx] = as.numeric(fixed_value)
	if (length(free_idx) > 0L) b[free_idx] = as.numeric(fit$b)
	names(b) = colnames(X)
	fisher = if (!is.null(fit$fisher_information) && length(free_idx) > 0L) {
		full = matrix(0, p, p, dimnames = list(colnames(X), colnames(X)))
		full[free_idx, free_idx] = fit$fisher_information
		full
	} else {
		NULL
	}
	list(
		b = b,
		coefficients = b,
		vcov = NULL,
		var = NULL,
		neg_ll = fit$neg_ll,
		neg_loglik = fit$neg_loglik,
		neg_log_lik = fit$neg_log_lik,
		fisher_information = fisher,
		converged = TRUE
	)
}

.cox_neg_loglik_breslow_r = function(X, y, dead, beta, strata = NULL){
	X = as.matrix(X)
	y = as.numeric(y)
	dead = as.numeric(dead)
	beta = as.numeric(beta)
	if (length(beta) != ncol(X)) return(NA_real_)
	strata_id = if (is.null(strata)) rep.int(1L, length(y)) else as.integer(strata)
	eta = as.numeric(X %*% beta)
	if (!all(is.finite(eta))) return(NA_real_)
	ll = 0
	for (s in unique(strata_id)) {
		idx = which(strata_id == s)
		if (length(idx) == 0L) next
		event_times = sort(unique(y[idx][dead[idx] == 1L]))
		for (tt in event_times) {
			event_idx = idx[dead[idx] == 1L & y[idx] == tt]
			risk_idx = idx[y[idx] >= tt]
			d = length(event_idx)
			if (d == 0L || length(risk_idx) == 0L) next
			den = sum(exp(eta[risk_idx]))
			if (!is.finite(den) || den <= 0) return(NA_real_)
			ll = ll + sum(eta[event_idx]) - d * log(den)
		}
	}
	-as.numeric(ll)
}

.cox_score_breslow_fd_r = function(X, y, dead, beta, strata = NULL){
	beta = as.numeric(beta)
	p = length(beta)
	score = numeric(p)
	for (j in seq_len(p)) {
		h = 1e-5 * max(1, abs(beta[j]))
		b_hi = beta; b_lo = beta
		b_hi[j] = b_hi[j] + h
		b_lo[j] = b_lo[j] - h
		nll_hi = .cox_neg_loglik_breslow_r(X, y, dead, b_hi, strata = strata)
		nll_lo = .cox_neg_loglik_breslow_r(X, y, dead, b_lo, strata = strata)
		if (!is.finite(nll_hi) || !is.finite(nll_lo)) return(rep(NA_real_, p))
		score[j] = -(nll_hi - nll_lo) / (2 * h)
	}
	score
}

.cox_information_breslow_fd_r = function(X, y, dead, beta, strata = NULL){
	beta = as.numeric(beta)
	p = length(beta)
	info = matrix(NA_real_, p, p)
	nll0 = .cox_neg_loglik_breslow_r(X, y, dead, beta, strata = strata)
	if (!is.finite(nll0)) return(info)
	h = 1e-4 * pmax(1, abs(beta))
	for (i in seq_len(p)) {
		for (j in i:p) {
			if (i == j) {
				b_hi = beta; b_lo = beta
				b_hi[i] = b_hi[i] + h[i]
				b_lo[i] = b_lo[i] - h[i]
				f_hi = .cox_neg_loglik_breslow_r(X, y, dead, b_hi, strata = strata)
				f_lo = .cox_neg_loglik_breslow_r(X, y, dead, b_lo, strata = strata)
				val = (f_hi - 2 * nll0 + f_lo) / (h[i]^2)
			} else {
				b_pp = beta; b_pm = beta; b_mp = beta; b_mm = beta
				b_pp[i] = b_pp[i] + h[i]; b_pp[j] = b_pp[j] + h[j]
				b_pm[i] = b_pm[i] + h[i]; b_pm[j] = b_pm[j] - h[j]
				b_mp[i] = b_mp[i] - h[i]; b_mp[j] = b_mp[j] + h[j]
				b_mm[i] = b_mm[i] - h[i]; b_mm[j] = b_mm[j] - h[j]
				f_pp = .cox_neg_loglik_breslow_r(X, y, dead, b_pp, strata = strata)
				f_pm = .cox_neg_loglik_breslow_r(X, y, dead, b_pm, strata = strata)
				f_mp = .cox_neg_loglik_breslow_r(X, y, dead, b_mp, strata = strata)
				f_mm = .cox_neg_loglik_breslow_r(X, y, dead, b_mm, strata = strata)
				val = (f_pp - f_pm - f_mp + f_mm) / (4 * h[i] * h[j])
			}
			info[i, j] = val
			info[j, i] = val
		}
	}
	info
}

cox_partial_likelihood_coefficients_extreme = function(coefs, threshold = 20) {
	coefs = as.numeric(coefs)
	any(!is.finite(coefs)) || any(abs(coefs) > threshold)
}

CoxPartialLikelihoodSource = list(
	public = list(),
	private = list(
		fit_survival_coxph_kernel = function(X, y, dead, strata = NULL, offset = NULL, estimate_only = FALSE) {
			.fit_survival_coxph_kernel(X, y, dead, strata = strata, offset = offset, estimate_only = estimate_only)
		},
		fit_survival_coxph_fixed_kernel = function(X, y, dead, strata = NULL, fixed_idx = 1L, fixed_value = 0) {
			.fit_survival_coxph_fixed_kernel(X, y, dead, strata = strata, fixed_idx = fixed_idx, fixed_value = fixed_value)
		},
		cox_neg_loglik_breslow_r = function(X, y, dead, beta, strata = NULL) {
			.cox_neg_loglik_breslow_r(X, y, dead, beta, strata = strata)
		},
		cox_score_breslow_fd_r = function(X, y, dead, beta, strata = NULL) {
			.cox_score_breslow_fd_r(X, y, dead, beta, strata = strata)
		},
		cox_information_breslow_fd_r = function(X, y, dead, beta, strata = NULL) {
			.cox_information_breslow_fd_r(X, y, dead, beta, strata = strata)
		},
		cox_partial_likelihood_coefficients_extreme = function(coefs, threshold = 20) {
			cox_partial_likelihood_coefficients_extreme(coefs, threshold = threshold)
		}
	)
)

#' Cox Proportional Hazards Regression Inference for Survival Responses
#'
#' Fits a Cox proportional hazards model, \eqn{\lambda(t \mid x_i) = \lambda_0(t)
#' \exp(x_i^\top\beta)}, for survival responses using the treatment indicator
#' and, optionally, all recorded covariates as predictors, by maximizing the
#' \strong{Breslow-tie-corrected partial likelihood}. For exact/right-censored
#' data, fitting uses this package's internal Newton-Raphson C++ solver
#' (\code{fast_coxph_regression_prebuilt_cpp}) by default (\code{use_rcpp =
#' TRUE}), falling back to \code{survival::coxph.fit()}/\code{survival::coxph()}
#' if that fails to converge or \code{use_rcpp = FALSE}. For \strong{left- or
#' interval-censored} data (a genuinely different likelihood, with no
#' closed-form partial-likelihood score/information), fitting instead dispatches
#' to \code{icenReg::ic_sp(model = "ph")}, a semiparametric NPMLE Cox fit whose
#' standard errors come from \pkg{icenReg}'s own internal bootstrap (not a
#' closed-form covariance) — only Wald inference (\code{testing_type = "wald"})
#' is supported on that path; score/gradient/likelihood-ratio/Bartlett testing
#' types raise an informative error for such data. This is a partial-likelihood
#' class (\code{likelihood_tier = "partial"}) supporting score, gradient, and
#' likelihood-ratio tests, plus parametric likelihood-ratio bootstrap
#' calibration (both only for the exact/right-censored path), in addition to
#' Wald and resampling-based inference. Fitted coefficients exceeding a fixed
#' magnitude threshold (20, on the log-hazard-ratio scale) are treated as
#' non-estimable (a numerical-divergence guard) rather than returned.
#'
#' @references Cox, D. R. (1972). "Regression Models and Life-Tables."
#'   \emph{Journal of the Royal Statistical Society, Series B}, 34(2), 187-220,
#'   for the proportional hazards model and partial likelihood; Breslow, N. E.
#'   (1974). "Covariance Analysis of Censored Survival Data." \emph{Biometrics},
#'   30(1), 89-99, \doi{10.2307/2529620}, for the tied-event partial-likelihood
#'   approximation used for exact/right-censored data.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'survival')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(runif(10))
#' inf = InferenceSurvivalCoxPHRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' @concept Cox regression
#' @concept Cox proportional hazards
#' @concept proportional hazards regression
#' @export
InferenceSurvivalCoxPHRegr = define_inference_class(
	classname = "InferenceSurvivalCoxPHRegr",
	inherit = Inference,
	# BayesianBootstrap listed BEFORE CoxPartialLikelihood so CoxPartialLikelihood's
	# dependency subtree (-> StandardModelCache -> LikelihoodTests -> Wald ->
	# Jackknife) resolves and merges LAST (see resolve_component_dependencies()'s
	# post-order DFS in contracts_mixins.R): combine_component_slot() merges
	# resolved components in order via utils::modifyList(), so a later-resolved
	# component's method body wins any name collision. This ordering is load-
	# bearing, not cosmetic -- getting it backwards (as an earlier attempt at
	# this did, see TODO-13 in interval_censored_survival_response.md) silently
	# lets InferenceRand's generic compute_treatment_estimate_during_randomization_inference()
	# win over StandardModelCache's Cox-aware version (which correctly threads
	# through private$shared()/generate_mod()), breaking every resampling-based
	# method without erroring anywhere.
	components = c("BayesianBootstrap", "CoxPartialLikelihood"),
	public = list(
		#' @description Uses the shared randomization two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceRand]{InferenceRand}}. Deliberately pulled from
		#'   \code{InferenceRand}, not \code{InferenceRandCI} -- despite
		#'   \code{InferenceRandCI}'s override having a richer signature
		#'   (\code{type}/\code{args_for_type}), its body calls \code{super$...()},
		#'   which resolves against this class's *actual* R6 superclass
		#'   (\code{Inference}, which has no such method) once the method body is
		#'   extracted and merged flatly by the component system -- not against
		#'   \code{InferenceRand} the way it would inside \code{InferenceRandCI}'s
		#'   own real inheritance chain. \code{InferenceRandCI}'s only other content
		#'   is an incidence-response special case (Zhang exact test) that never
		#'   applies to survival data anyway, so the two are behaviorally identical
		#'   for this class -- confirmed by tracing the body, not assumed. Matches
		#'   the pattern already used by the sibling migrated classes (LogRank/
		#'   GehanWilcox/KMDiff/RestrictedMeanDiff).
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,

		#' @description Initialize a Cox PH inference object for a completed design
		#'   with a survival response. Unlike most survival inference classes in
		#'   this package, this one accepts left- and interval-censored data (via
		#'   an \pkg{icenReg}-backed fallback fit; see class documentation), not
		#'   only exact/right-censored.
		#' @param des_obj A completed \code{Design} object with a survival response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param use_rcpp Logical. If \code{TRUE} (default), enable internal Rcpp score/information helpers for likelihood inference.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values by default.
		initialize = function(des_obj, model_formula = NULL, use_rcpp = TRUE, verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "survival")
				assertFormula(model_formula, null.ok = TRUE)
				assertFlag(use_rcpp)
			}
			super$initialize(des_obj, model_formula = model_formula, verbose = verbose, smart_cold_start_default = smart_cold_start_default)
			
			
			private$use_rcpp = use_rcpp
		},
		#' @description Computes the Cox PH treatment coefficient \eqn{\hat\beta_T}
		#'   (log hazard ratio) — see class documentation for the fitting backend
		#'   used (partial-likelihood C++/\code{survival} solver for exact/
		#'   right-censored data; \pkg{icenReg} NPMLE for left-/interval-censored
		#'   data). \code{NA} if the fit fails or the fitted coefficients are
		#'   numerically extreme.
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Computes an asymptotic confidence interval using the configured likelihood-backed test.
		#' @param alpha Significance level 1 - \code{alpha}. Default 0.05.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (isTRUE(private$has_general_censoring) && private$testing_type != "wald") {
				stop(
					"testing_type = '", private$testing_type, "' is not supported for left-/",
					"interval-censored survival data (dispatched via icenReg::ic_sp(), which has ",
					"no partial-likelihood score/gradient/likelihood-ratio machinery to reuse). ",
					"Use testing_type = 'wald', which is supported."
				)
			}
			if (private$testing_type == "wald") {
				private$shared(estimate_only = FALSE)
				if (is.finite(private$cached_values$s_beta_hat_T %||% NA_real_)) {
					return(private$compute_z_or_t_ci_from_s_and_df(alpha))
				}
			}
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
			}
			switch(
				private$testing_type,
				wald = private$compute_wald_confidence_interval_impl(alpha),
				score = private$compute_score_confidence_interval_impl(alpha),
				gradient = private$compute_gradient_confidence_interval_impl(alpha),
				lik_ratio = private$compute_lik_ratio_confidence_interval_impl(alpha),
				lik_ratio_bartlett_approx = private$compute_lik_ratio_bartlett_approx_confidence_interval_impl(alpha),
				lik_ratio_bartlett_exact = private$compute_lik_ratio_bartlett_exact_confidence_interval_impl(alpha)
			)
		},
		#' @description Computes an asymptotic two-sided p-value using the configured likelihood-backed test.
		#' @param delta Null treatment effect to test against. Default 0.
		compute_asymp_two_sided_pval = function(delta = 0){
			if (isTRUE(private$has_general_censoring) && private$testing_type != "wald") {
				stop(
					"testing_type = '", private$testing_type, "' is not supported for left-/",
					"interval-censored survival data (dispatched via icenReg::ic_sp(), which has ",
					"no partial-likelihood score/gradient/likelihood-ratio machinery to reuse). ",
					"Use testing_type = 'wald', which is supported."
				)
			}
			if (private$testing_type == "wald") {
				private$shared(estimate_only = FALSE)
				if (is.finite(private$cached_values$s_beta_hat_T %||% NA_real_)) {
					return(private$compute_z_or_t_two_sided_pval_from_s_and_df(delta))
				}
			}
			if (should_run_asserts()) {
				assertNumeric(delta)
			}
			switch(
				private$testing_type,
				wald = private$compute_wald_two_sided_pval_impl(delta),
				score = private$compute_score_two_sided_pval_impl(delta),
				gradient = private$compute_gradient_two_sided_pval_impl(delta),
				lik_ratio = private$compute_lik_ratio_two_sided_pval_impl(delta),
				lik_ratio_bartlett_approx = private$compute_lik_ratio_bartlett_approx_two_sided_pval_impl(delta),
				lik_ratio_bartlett_exact = private$compute_lik_ratio_bartlett_exact_two_sided_pval_impl(delta)
			)
		},
		#' @description Recomputes the Cox PH treatment estimate under subject/block
		#'   bootstrap weights (via \code{weighted_cox_bootstrap_surrogate_fit()},
		#'   which assumes ordinary right-censoring semantics), used by the
		#'   Bayesian bootstrap and related weighted-resampling machinery. If the
		#'   weights are effectively constant, short-circuits to the unweighted
		#'   \code{$compute_estimate(estimate_only = TRUE)}. \strong{Not supported}
		#'   for left- or interval-censored data — raises an error immediately,
		#'   since the surrogate weighted fit has no extension for that likelihood.
		#'   Always leaves the standard error unavailable (\code{NA}) regardless of
		#'   \code{estimate_only} — this weighted path never computes a variance.
		#' @param subject_or_block_weights Subject-, block-, cluster-, or matched-set
		#'   bootstrap weights.
		#' @param estimate_only Present for interface parity; this method never
		#'   computes variance components regardless of its value.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			if (isTRUE(private$has_general_censoring)) {
				stop(
					"Bayesian-bootstrap weighted re-estimation is not yet supported for left-/",
					"interval-censored survival data (weighted_cox_bootstrap_surrogate_fit() assumes ",
					"ordinary right-censoring semantics, which does not apply here)."
				)
			}
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			if (weights_are_effectively_constant(row_weights)) {
				beta_hat_T = as.numeric(self$compute_estimate(estimate_only = TRUE))[1L]
				if (is.finite(beta_hat_T)) return(beta_hat_T)
			}
			X_cov = private$get_X()
			X_fit = if (!is.null(X_cov) && ncol(X_cov) > 0) cbind(treatment = private$w, X_cov) else matrix(private$w, ncol = 1, dimnames = list(NULL, "treatment"))
			fit = weighted_cox_bootstrap_surrogate_fit(
				private$y, private$dead, X_fit, row_weights,
				warm_start_beta = private$get_fit_warm_start_for_length("params", ncol(X_fit)) %||% private$get_fit_warm_start_for_length("beta", ncol(X_fit))
			)
			beta_hat_T = if (is.null(fit)) NA_real_ else as.numeric(fit$beta_hat)
			if (!is.finite(beta_hat_T) || private$cox_coefficients_extreme(beta_hat_T)) {
				private$cache_nonestimable_estimate("coxph_weighted_extreme_coefficients")
				beta_hat_T = NA_real_
			}
			private$cached_values$beta_hat_T = beta_hat_T
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$beta_hat_T
		}
	),
	private = list(
		use_rcpp = TRUE,
		cox_extreme_coef_threshold = 20,
		cox_X_fit_cache = NULL,
		cox_data_cache = NULL,
		cox_w_cache = NULL,
		# Bootstrap replicates icenReg::ic_sp() uses for its covariance
		# matrix when dispatching on left-/interval-censored data (see
		# generate_mod_icen below); the semi-parametric NPMLE fit has no
		# closed-form SE, so icenReg estimates it this way itself.
		icen_bs_samples = 200L,
		supports_interval_or_left_censored_data = function(){
			TRUE
		},
		cox_coefficients_extreme = function(coefs){
			cox_partial_likelihood_coefficients_extreme(coefs, private$cox_extreme_coef_threshold)
		},
		supports_likelihood_tests = function(){
			isTRUE(private$use_rcpp)
		},
		supports_lik_ratio_param_bootstrap = function() isTRUE(private$use_rcpp),
		simulate_under_lik_null = function(spec, delta, null_fit){
			b_null = as.numeric(null_fit$b)
			if (!all(is.finite(b_null))) return(NULL)
			X_fit = spec$X
			y_obs = as.numeric(private$y)
			dead_obs = as.numeric(private$dead)
			breslow = .breslow_hazard(y_obs, dead_obs, X_fit, b_null)
			if (length(breslow$times) == 0L) return(NULL)
			sim = .cox_simulate_from_breslow(breslow, y_obs, dead_obs, X_fit, b_null)
			y_sim = sim$y_sim; dead_sim = sim$dead_sim
			if (!all(is.finite(y_sim)) || any(y_sim <= 0)) return(NULL)
			j = spec$j
			full_res = .fit_survival_coxph_kernel(X_fit, y_sim, dead_sim)
			if (is.null(full_res) || !isTRUE(full_res$converged) || !is.finite(full_res$coefficients[j])) return(NULL)
			full_fit_boot = list(b = as.numeric(full_res$coefficients), neg_loglik = as.numeric(full_res$neg_ll))
			list(
				full_fit = full_fit_boot,
				fit_null = function(d, start = NULL){
					res = .fit_survival_coxph_fixed_kernel(X_fit, y_sim, dead_sim, fixed_idx = j, fixed_value = d)
					if (is.null(res) || !isTRUE(res$converged)) return(NULL)
					list(b = as.numeric(res$coefficients), neg_loglik = as.numeric(res$neg_ll))
				},
				neg_loglik = function(fit) as.numeric(fit$neg_loglik)
			)
		},
		get_likelihood_test_spec = function(){
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			X = ctx$X
			y = as.numeric(private$y)
			dead = as.numeric(private$dead)
			full_b_cox = as.numeric(private$cached_mod$b[-1])  # strip Cox no-intercept prefix
			full_fit = list(b = full_b_cox, neg_loglik = ctx$full_neg_loglik)
			list(
				X = X, y = y, j = 1L,
				full_fit = full_fit,
				fit_null = function(delta, start = NULL){
					res = .fit_survival_coxph_fixed_kernel(X, y, dead, fixed_idx = 1L, fixed_value = delta)
					if (is.null(res) || !isTRUE(res$converged)) return(NULL)
					list(b = as.numeric(res$coefficients), neg_loglik = as.numeric(res$neg_ll), fisher_information = res$fisher_information)
				},
				extract_start = function(fit){
					as.numeric(fit$b)
				},
				score = function(fit){
					get_coxph_score_cpp(X, y, dead, as.numeric(fit$b))
				},
				observed_information = function(fit){
					-get_coxph_hessian_cpp(X, y, dead, as.numeric(fit$b))
				},
				fisher_information = function(fit){
					fit$fisher_information %||% -get_coxph_hessian_cpp(X, y, dead, as.numeric(fit$b))
				},
				information = function(fit){
					fit$information %||% fit$fisher_information %||% -get_coxph_hessian_cpp(X, y, dead, as.numeric(fit$b))
				},
				neg_loglik = function(fit){ as.numeric(fit$neg_loglik) }
			)
		},
		generate_mod = function(estimate_only = FALSE){
			# Top-level dispatch, not a hot-path edit (see the plan's
			# "Zero-Regression Design Principle"): left-/interval-censored
			# data never reaches the Breslow partial-likelihood machinery
			# below at all -- survival::coxph()/the Rcpp kernel have no
			# extension for it. Guaranteed disjoint from the exact/
			# right-censored path by Inference$initialize()'s censoring
			# guard (only classes with supports_interval_or_left_censored_data()
			# == TRUE, i.e. this class, can even construct with such data).
			if (isTRUE(private$has_general_censoring)) {
				return(private$generate_mod_icen(estimate_only))
			}
			if (is.null(private$cox_X_fit_cache) || is.null(private$cox_data_cache) || !identical(private$w, private$cox_w_cache)) {
				X_cov = private$get_X()
				private$cox_X_fit_cache = if (!is.null(X_cov) && ncol(X_cov) > 0){
					cbind(treatment = private$w, X_cov)
				} else {
					matrix(private$w, ncol = 1, dimnames = list(NULL, "treatment"))
				}
				if (private$harden && ncol(private$cox_X_fit_cache) > 1L) {
					orig_names = colnames(private$cox_X_fit_cache)
					reduced = qr_reduce_preserve_cols_cpp(as.matrix(private$cox_X_fit_cache), 1L)
					private$cox_X_fit_cache = as.matrix(reduced$X_reduced)
					colnames(private$cox_X_fit_cache) = orig_names[as.integer(reduced$keep)]
				}
				private$cox_data_cache = build_cox_data_cache_cpp(private$cox_X_fit_cache, private$y, private$dead)
				private$cox_w_cache = private$w
			}
			X_fit = private$cox_X_fit_cache

			if (private$use_rcpp) {
				fit = tryCatch(
					fast_coxph_regression_prebuilt_cpp(
						private$cox_data_cache,
						estimate_only = estimate_only,
						warm_start_beta = private$get_fit_warm_start_for_length("params", ncol(X_fit)),
						warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit)),
						smart_cold_start = private$smart_cold_start_default %||% TRUE,
						optimization_alg = "newton_raphson"
					),
					error = function(e) NULL
				)
				
				if (is.null(fit) || !isTRUE(fit$converged)) {
					# Fallback to R if C++ fails
					fit = .fit_survival_coxph_kernel(X_fit, private$y, private$dead, estimate_only = estimate_only)
				}
				
				if (is.null(fit)) {
					private$cached_values$likelihood_test_context = NULL
					return(list(b = rep(NA_real_, ncol(X_fit) + 1L), vcov = matrix(NA_real_, ncol(X_fit) + 1L, ncol(X_fit) + 1L)))
				}
				
				private$cached_mod = fit
				private$cached_values$likelihood_test_context = list(
					X = X_fit,
					full_neg_loglik = fit$neg_ll %||% fit$neg_log_lik
				)
				
				coefs = as.numeric(fit$coefficients %||% fit$b)
				if (private$cox_coefficients_extreme(coefs)) {
					private$cache_nonestimable_estimate("coxph_extreme_coefficients")
					private$cached_values$likelihood_test_context = NULL
					return(list(
						beta_hat_T = NA_real_,
						ssq_b_2 = NA_real_,
						b = rep(NA_real_, ncol(X_fit) + 1L),
						params = rep(NA_real_, ncol(X_fit)),
						neg_log_lik = NA_real_,
						fisher_information = NULL,
						vcov = if (estimate_only) NULL else matrix(NA_real_, ncol(X_fit) + 1L, ncol(X_fit) + 1L)
					))
				}
				return(list(
					beta_hat_T = coefs[1L],
					ssq_b_2 = if (estimate_only) NA_real_ else fit$vcov[1, 1],
					b = c(0, coefs),
					params = coefs,
					neg_log_lik = as.numeric(fit$neg_ll %||% fit$neg_log_lik),
					fisher_information = fit$fisher_information,
					vcov = if (estimate_only) NULL else {
						v = matrix(0, ncol(X_fit) + 1, ncol(X_fit) + 1)
						v[2:(ncol(X_fit) + 1), 2:(ncol(X_fit) + 1)] = fit$vcov
						v
					}
				))
			}
			surv_obj = survival::Surv(private$y, private$dead)
			tryCatch({
				coxph_mod = suppressWarnings(survival::coxph(surv_obj ~ X_fit))
				if (estimate_only) {
					coefs = stats::coef(coxph_mod)
					if (private$cox_coefficients_extreme(coefs)) {
						private$cache_nonestimable_estimate("coxph_extreme_coefficients")
						return(list(beta_hat_T = NA_real_, b = rep(NA_real_, ncol(X_fit) + 1L), ssq_b_2 = NA_real_, vcov = NULL))
					}
					list(
						beta_hat_T = as.numeric(coefs[1]),
						b = c(0, coefs),
						ssq_b_2 = NA_real_,
						vcov = NULL
					)
				} else {
					coefs = stats::coef(coxph_mod)
					if (private$cox_coefficients_extreme(coefs)) {
						private$cache_nonestimable_estimate("coxph_extreme_coefficients")
						return(list(
							beta_hat_T = NA_real_,
							ssq_b_2 = NA_real_,
							b = rep(NA_real_, ncol(X_fit) + 1L),
							vcov = matrix(NA_real_, ncol(X_fit) + 1L, ncol(X_fit) + 1L),
							neg_log_lik = NA_real_
						))
					}
					vcov_mat = stats::vcov(coxph_mod)
					v = matrix(0, ncol(X_fit) + 1, ncol(X_fit) + 1)
					v[2:(ncol(X_fit) + 1), 2:(ncol(X_fit) + 1)] = vcov_mat
					list(
						beta_hat_T = as.numeric(coefs[1]),
						ssq_b_2 = as.numeric(vcov_mat[1, 1]),
						b = c(0, coefs),
						vcov = v,
						neg_log_lik = as.numeric(-stats::logLik(coxph_mod))
					)
				}
			}, error = function(e){
				list(
					b = rep(NA_real_, ncol(X_fit) + 1),
					vcov = matrix(NA_real_, ncol(X_fit) + 1, ncol(X_fit) + 1)
				)
			})
		},
		# icenReg::ic_sp() dispatch for left-/interval-censored data (TODO-6,
		# interval_censored_survival_response.md). Reshapes the fit into the
		# same list(beta_hat_T=, ssq_b_2=, b=, vcov=, neg_log_lik=) shape
		# generate_mod()'s existing branches return, so compute_estimate()
		# and the "wald" testing_type path (compute_asymp_confidence_interval()/
		# compute_asymp_two_sided_pval()) work unchanged. Deliberately does
		# NOT populate cached_values$likelihood_test_context: the
		# score/gradient/lik_ratio/bartlett testing types and the
		# bootstrap-weights/randomization-inference paths are Cox
		# partial-likelihood-specific and don't generalize to this NPMLE fit
		# -- those are explicitly blocked elsewhere rather than silently
		# misapplied to it.
		generate_mod_icen = function(estimate_only = FALSE){
			assert_icenreg_installed(class(self)[1L])
			X_cov = private$get_X()
			X_fit = if (!is.null(X_cov) && ncol(X_cov) > 0){
				cbind(treatment = private$w, X_cov)
			} else {
				matrix(private$w, ncol = 1, dimnames = list(NULL, "treatment"))
			}
			if (private$harden && ncol(X_fit) > 1L) {
				orig_names = colnames(X_fit)
				reduced = qr_reduce_preserve_cols_cpp(as.matrix(X_fit), 1L)
				X_fit = as.matrix(reduced$X_reduced)
				colnames(X_fit) = orig_names[as.integer(reduced$keep)]
			}
			covariate_names = colnames(X_fit)
			p1 = ncol(X_fit) + 1L
			na_result = list(b = rep(NA_real_, p1), vcov = matrix(NA_real_, p1, p1))
			# Exact rows (private$y non-NA) become a zero-width interval
			# [y, y]; censored rows use their stored y_L/y_R directly --
			# right-censored (y_R = Inf) and left-censored (y_L = 0) both
			# fall out of the same cbind(L, R) shape icenReg expects.
			L = ifelse(is.na(private$y), private$y_L, private$y)
			R = ifelse(is.na(private$y), private$y_R, private$y)
			dat = as.data.frame(X_fit)
			dat$.icen_L = L
			dat$.icen_R = R
			fmla = stats::as.formula(paste0(
				"cbind(.icen_L, .icen_R) ~ ", paste(covariate_names, collapse = " + ")
			))
			bs_samples = if (isTRUE(estimate_only)) 0L else private$icen_bs_samples
			fit = tryCatch(
				suppressWarnings(icenReg::ic_sp(fmla, data = dat, model = "ph", bs_samples = bs_samples)),
				error = function(e) NULL
			)
			if (is.null(fit)) {
				private$cached_values$likelihood_test_context = NULL
				return(na_result)
			}
			coefs = as.numeric(fit$coefficients[covariate_names])
			if (length(coefs) != ncol(X_fit) || !all(is.finite(coefs)) || private$cox_coefficients_extreme(coefs)) {
				private$cache_nonestimable_estimate("coxph_icenreg_extreme_coefficients")
				private$cached_values$likelihood_test_context = NULL
				return(list(
					beta_hat_T = NA_real_,
					ssq_b_2 = NA_real_,
					b = rep(NA_real_, p1),
					vcov = if (estimate_only) NULL else matrix(NA_real_, p1, p1),
					neg_log_lik = NA_real_
				))
			}
			private$cached_values$likelihood_test_context = NULL
			if (isTRUE(estimate_only)) {
				return(list(
					beta_hat_T = coefs[1L],
					ssq_b_2 = NA_real_,
					b = c(0, coefs),
					vcov = NULL,
					neg_log_lik = NA_real_
				))
			}
			var_mat = tryCatch(as.matrix(fit$var)[covariate_names, covariate_names, drop = FALSE], error = function(e) NULL)
			if (is.null(var_mat) || !all(is.finite(var_mat))) {
				return(list(
					beta_hat_T = coefs[1L],
					ssq_b_2 = NA_real_,
					b = c(0, coefs),
					vcov = matrix(NA_real_, p1, p1),
					neg_log_lik = -as.numeric(fit$llk %||% NA_real_)
				))
			}
			v = matrix(0, p1, p1)
			v[2:p1, 2:p1] = var_mat
			list(
				beta_hat_T = coefs[1L],
				ssq_b_2 = v[2, 2],
				b = c(0, coefs),
				vcov = v,
				neg_log_lik = -as.numeric(fit$llk %||% NA_real_)
			)
		},
		compute_fast_rand_bootstrap_distr = function(y0_full, rand_bootstrap_draws, delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps){
			# The Rcpp fast path assumes ordinary right-censoring (dead in
			# {0,1} against a single y); under general censoring there is no
			# fast path -- returning NULL here (the framework's established
			# "no fast path available" signal) falls back to the generic,
			# slower randomization loop, which re-dispatches through
			# generate_mod() per replicate and so correctly reuses
			# generate_mod_icen() above.
			if (isTRUE(private$has_general_censoring)) return(NULL)
			if (!is.null(private[["custom_randomization_statistic_function"]]) || !is.null(private[["compiled_cpp_stat_fn"]])) return(NULL)
			if (delta != 0 && !identical(transform_responses, "log")) return(NULL)
			mats = private$rand_bootstrap_draw_matrices(rand_bootstrap_draws)
			if (is.null(mats)) return(NULL)
			Xc = if (!is.null(private$cox_X_fit_cache) && ncol(private$cox_X_fit_cache) > 1L) {
				as.matrix(private$cox_X_fit_cache[, -1L, drop = FALSE])
			} else {
				X_cov = private$get_X()
				if (!is.null(X_cov) && ncol(as.matrix(X_cov)) > 0L) as.matrix(X_cov) else matrix(numeric(0), nrow = private$n, ncol = 0L)
			}
			compute_coxph_rand_bootstrap_parallel_cpp(
				as.numeric(y0_full), as.integer(private$dead), Xc, mats$i_mat, mats$w_mat,
				as.numeric(delta), mats$noise_mat, private$n_cpp_threads(ncol(mats$w_mat))
			)
		}
	),
	metadata = list(likelihood_tier = "partial"),
	overrides = list(
		public = c(
			"compute_estimate",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"get_supported_testing_types", "set_testing_type",
			# Cox's own weighted_cox_bootstrap_surrogate_fit()-backed
			# implementation (already correctly guards general censoring, see
			# TODO-6) must win over BayesianBootstrap's generic default.
			"compute_estimate_with_bootstrap_weights",
			# RandomizationCI (in BayesianBootstrap's dependency chain) legitimately
			# overrides RandomizationTest's plain version of this method with a
			# richer signature -- a normal subclass override in the old R6 chain,
			# but still a name collision the flat component merge must be told is
			# intentional. RandomizationCI is resolved after RandomizationTest (it
			# depends on it), so its version wins the merge automatically; no host
			# entry needed.
			"compute_rand_two_sided_pval"
		),
		private = c(
			"supports_likelihood_tests",
			"supports_lik_ratio_param_bootstrap",
			"simulate_under_lik_null",
			"get_likelihood_test_spec",
			"generate_mod",
			"get_standard_error",
			"get_degrees_of_freedom",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"make_warm_fit_null_wrapper",
			"compute_likelihood_test_two_sided_pval",
			"compute_score_two_sided_pval_impl",
			"compute_gradient_two_sided_pval_impl",
			"compute_lik_ratio_two_sided_pval_impl",
			"get_supported_testing_types_impl",
			"compute_fast_rand_bootstrap_distr",
			# StandardModelCache (via CoxPartialLikelihood's dependency chain)
			# vs. RandomizationTest (via BayesianBootstrap's chain): both define
			# this name. StandardModelCache's version -- which calls
			# private$shared()/generate_mod(), i.e. Cox's own partial-likelihood
			# fit -- is correct here and wins via the components= ordering above,
			# not via this declaration (which only permits the collision).
			"compute_treatment_estimate_during_randomization_inference",
			# Jackknife (via CoxPartialLikelihood's chain) vs. NonparametricBootstrap
			# (via BayesianBootstrap's chain): both define these with byte-identical
			# bodies (confirmed by direct comparison), so the winner is immaterial.
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			# Wald (via CoxPartialLikelihood's chain) vs. NonparametricBootstrap
			# (via BayesianBootstrap's chain): both return TRUE, so the winner is
			# immaterial.
			"supports_reusable_bootstrap_worker"
		)
	)
)
