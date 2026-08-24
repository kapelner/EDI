conditional_logit_prepare_combined_design = function(private_env, KKstats) {
	m = KKstats$m
	nRT = KKstats$nRT
	nRC = KKstats$nRC
	p = ncol(as.matrix(private_env$X))
	has_reservoir = nRT > 0 && nRC > 0
	X_comb = NULL
	y_comb = NULL
	j_beta_T = 2L
	split = split_kk_matched_reservoir_idx(private_env$m, private_env$n)
	m_vec = split$m_vec
	if (m > 0) {
		i_matched = split$matched_idx
		y_m = private_env$y[i_matched]
		w_m = private_env$w[i_matched]
		strata_m = m_vec[i_matched]
		X_mat = if (p > 0L) as.matrix(private_env$get_X()[i_matched, , drop = FALSE]) else matrix(numeric(0), nrow = length(y_m), ncol = 0L)
		if (has_reservoir) {
			y_r = KKstats$y_reservoir
			w_r = KKstats$w_reservoir
			X_r = if (p > 0L) as.matrix(KKstats$X_reservoir) else matrix(numeric(0), nrow = length(y_r), ncol = 0L)
			design = build_matching_combined_clogit_design_cpp(
				as.double(y_m), as.double(w_m), X_mat, as.integer(strata_m),
				as.double(y_r), as.double(w_r), X_r
			)
			X_comb = design$X_comb
			y_comb = design$y_comb
			j_beta_T = 2L
		} else {
			res = collect_discordant_pairs_cpp(
				as.double(y_m), as.double(w_m), X_mat, as.integer(strata_m)
			)
			if (res$nd > 0) {
				X_comb = if (p > 0L) cbind(res$t_diffs, res$X_diffs) else matrix(res$t_diffs, ncol = 1L)
				y_comb = res$y_01
				j_beta_T = 1L
			}
		}
	} else if (has_reservoir) {
		y_r = KKstats$y_reservoir
		w_r = KKstats$w_reservoir
		X_comb = if (p > 0L) cbind(1, w_r, as.matrix(KKstats$X_reservoir)) else cbind(1, w_r)
		y_comb = y_r
	}
	if (!is.null(X_comb)) {
		colnames(X_comb) = paste0("x", seq_len(ncol(X_comb)))
		colnames(X_comb)[j_beta_T] = "beta_T"
	}
	list(X = X_comb, y = y_comb, j_beta_T = j_beta_T, has_reservoir = has_reservoir)
}

conditional_logit_weighted_combined_estimate = function(private_env, KKstats, row_weights, estimate_only = TRUE) {
	design = conditional_logit_prepare_combined_design(private_env, KKstats)
	if (is.null(design$X)) {
		private_env$cache_nonestimable_estimate("kk_clogit_combined_weighted_no_informative_data")
		return(NA_real_)
	}
	kk_w = kk_pair_and_reservoir_bootstrap_weights(private_env, row_weights)
	w_comb = if (isTRUE(design$has_reservoir) && KKstats$m > 0) {
		c(kk_w$pair_weights, kk_w$reservoir_weights)
	} else if (KKstats$m > 0) {
		kk_w$pair_weights[seq_len(nrow(design$X))]
	} else {
		kk_w$reservoir_weights
	}
	ok = is.finite(w_comb) & w_comb > 0 & is.finite(design$y)
	if (!any(ok)) {
		private_env$cache_nonestimable_estimate("kk_clogit_combined_weighted_no_positive_weights")
		return(NA_real_)
	}
	X_comb = design$X[ok, , drop = FALSE]
	y_comb = design$y[ok]
	w_comb = w_comb[ok]
	mod = tryCatch(
		fast_logistic_regression_weighted_cpp(
			X = X_comb,
			y = y_comb,
			weights = w_comb,
			warm_start_beta = private_env$get_fit_warm_start_for_length("beta", ncol(X_comb)),
			warm_start_fisher_info = private_env$get_fit_warm_start_fisher(ncol(X_comb)),
			optimization_alg = private_env$optimization_alg
		),
		error = function(e) NULL
	)
	j_beta_fit = match("beta_T", colnames(X_comb))
	assessment = private_env$assess_combined_fit(
		mod,
		j_beta_fit,
		require_variance = !estimate_only
	)
	if (!isTRUE(assessment$usable)) {
		private_env$cache_nonestimable_estimate(paste0("kk_clogit_combined_weighted_", assessment$reason))
		return(NA_real_)
	}
	private_env$set_fit_warm_start(
		as.numeric(mod$b), "beta",
		fisher = mod$fisher_information %||% mod$XtWX
	)
	private_env$cached_values$s_beta_hat_T = if (estimate_only) NA_real_ else sqrt(assessment$variance)
	private_env$clear_nonestimable_state()
	as.numeric(mod$b[j_beta_fit])
}

conditional_logit_neg_loglik = function(X, y, b) {
	eta = as.numeric(X %*% as.numeric(b))
	log_denom = ifelse(eta > 0, eta + log1p(exp(-eta)), log1p(exp(eta)))
	-sum(y * eta - log_denom)
}

conditional_logit_fit_matched_pairs = function(KKstats) {
	y_m_all = KKstats$yTs_matched - KKstats$yCs_matched
	i_m_disc = which(abs(y_m_all) == 1)
	if (length(i_m_disc) == 0L) return(NULL)
	X_m = cbind(treatment = 1, KKstats$X_matched_diffs[i_m_disc, , drop = FALSE])
	y_m = (y_m_all[i_m_disc] + 1) / 2
	tryCatch(fast_logistic_regression_with_var_cpp(X_m, y_m, j = 1L), error = function(e) NULL)
}

conditional_logit_fit_reservoir = function(KKstats, X_covars) {
	y_r = KKstats$y_reservoir
	w_r = KKstats$w_reservoir
	X_r = if (is.null(X_covars) || ncol(X_covars) == 0) {
		cbind(`(Intercept)` = 1, treatment = w_r)
	} else {
		cbind(`(Intercept)` = 1, treatment = w_r, KKstats$X_reservoir)
	}
	tryCatch(fast_logistic_regression_with_var_cpp(X_r, y_r, j = 2L), error = function(e) NULL)
}

ConditionalLogitPartialLikelihoodSource = list(
	public = list(),
	private = list(
		conditional_logit_prepare_combined_design = function(KKstats) {
			conditional_logit_prepare_combined_design(private, KKstats)
		},
		conditional_logit_weighted_combined_estimate = function(KKstats, row_weights) {
			conditional_logit_weighted_combined_estimate(private, KKstats, row_weights)
		},
		conditional_logit_neg_loglik = function(X, y, b) {
			conditional_logit_neg_loglik(X, y, b)
		},
		conditional_logit_fit_matched_pairs = function(KKstats) {
			conditional_logit_fit_matched_pairs(KKstats)
		},
		conditional_logit_fit_reservoir = function(KKstats, X_covars) {
			conditional_logit_fit_reservoir(KKstats, X_covars)
		}
	)
)

#' Conditional Logistic Combined-Likelihood Inference for KK Designs with Binary Responses
#'
#' Fits a single joint likelihood over all KK design data for incidence responses.
#' The matched-pair component uses the conditional logistic likelihood, and the
#' reservoir component uses the standard Bernoulli log-likelihood.
#'
#' @keywords internal
# Static leaf source (2026-08-19 migration, fix_inference_hierarchy.md
# "Full-Likelihood Estimators" / "KK And IVWC Estimators"): formerly a
# single-layer R6 leaf raw-splicing InferenceMixinKKPassThrough$public/
# private onto InferenceParamBootstrap. This class's own
# compute_asymp_confidence_interval/compute_asymp_two_sided_pval fast-path
# the "wald" testing type directly and fall back to `super$...()` for
# score/gradient/lik_ratio (reaching InferenceAsympLik's generic switch
# dispatch, harvested verbatim as the LikelihoodTests component) -- unlike
# the count OneLik classes' six-method "design-conservative" pattern, only
# these two methods need the generic-`self$`-aliased-override fix (same
# pattern as CountKKHurdlePoissonOneLikLikelihoodSource/
# CountKKCondPoissonOneLikLikelihoodSource; see either's header comment for
# the full rationale). This class's own compute_basic_match_data = function()
# private$compute_basic_kk_match_data_impl() is a verified no-op restatement
# of InferenceMixinKKPassThrough's own default body -- dropped. This class
# already defined get_standard_error itself, so no Lesson-5 fix is needed
# here (unlike the count OneLik classes). Registered as
# `IncidKKCondLogitOneLikLikelihood` (`dependencies = c("KKPassThrough",
# "ParametricLikelihoodBootstrap")` -- fits one joint combined logistic
# likelihood directly, no KKCompound-style variance-weighted combination).
IncidKKCondLogitOneLikLikelihoodSource = list(
	public = list(
		#' @description Initialize conditional-logistic combined-likelihood inference
		#'   for KK binary responses and prepare matched-pair conditional-logit plus
		#'   reservoir Bernoulli likelihood components. See
		#'   \code{\link[EDI:InferenceAsympLik]{InferenceAsympLik}} for shared
		#'   likelihood-test methods.
		#' @param des_obj A completed \code{Design} object.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose  		Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart optimizer start values.
		initialize = function(des_obj, model_formula = NULL,  verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
			}
			super$initialize(des_obj = des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
			private$init_kk_passthrough(des_obj)
		},
		# Generic-`self$`-aliased overrides -- see this Source's header
		# comment (same pattern as the count OneLik Sources).
		compute_asymp_confidence_interval_generic = InferenceAsympLik$public_methods$compute_asymp_confidence_interval,
		compute_asymp_two_sided_pval_generic = InferenceAsympLik$public_methods$compute_asymp_two_sided_pval,
		#' @description Computes the class-specific treatment-effect estimate; see
		#'   \code{\link[EDI:Inference]{Inference}}.
		#' @param estimate_only Logical. If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared_combined_likelihood(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the combined conditional-logistic estimate under
		#'   Bayesian-bootstrap weights.
		#' @param subject_or_block_weights Numeric vector. Row weights for bootstrap.
		#' @param estimate_only Logical. If TRUE, skip variance component calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			if (weights_are_effectively_constant(row_weights)) {
				beta_hat_T = as.numeric(self$compute_estimate(estimate_only = estimate_only))[1L]
				if (is.finite(beta_hat_T)) {
					private$cached_values$beta_hat_T = beta_hat_T
					return(private$cached_values$beta_hat_T)
				}
				return(NA_real_)
			}
			private$cached_values$beta_hat_T = private$compute_weighted_combined_estimate(
				row_weights,
				estimate_only = estimate_only
			)
			private$cached_values$beta_hat_T
		},
		#' @description Uses the shared asymptotic confidence-interval contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param alpha Numeric. Significance level (default 0.05).
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (!identical(self$get_testing_type(), "wald")) {
				return(self$compute_asymp_confidence_interval_generic(alpha = alpha))
			}
			private$shared_combined_likelihood(estimate_only = FALSE)
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Uses the shared asymptotic two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param delta Numeric. Null treatment effect value (default 0).
		compute_asymp_two_sided_pval = function(delta = 0){
			if (!identical(self$get_testing_type(), "wald")) {
				return(self$compute_asymp_two_sided_pval_generic(delta = delta))
			}
			private$shared_combined_likelihood(estimate_only = FALSE)
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		}
		# approximate_bootstrap_distribution_beta_hat_T's old eval(body(...))
		# restatement dropped as a verified no-op (same argument as the count
		# OneLik Sources).
	),
	private = list(
		# compute_basic_match_data's old restatement (`function()
		# private$compute_basic_kk_match_data_impl()`) dropped as a verified
		# no-op -- InferenceMixinKKPassThrough's own default body is
		# identical.
		cached_mod = NULL,
		# Temporary class-local separation ceiling. Replace with the centralized
		# diagnostics policy when public_diagnostics_api_spec.md is implemented.
		max_abs_reasonable_coef = 10,
		assess_combined_fit = function(mod, j_treat, require_variance = FALSE, check_treatment = TRUE){
			fail = function(reason) list(usable = FALSE, reason = reason, variance = NA_real_)
			if (is.null(mod)) return(fail("fit_unavailable"))
			if (!isTRUE(mod$converged)) return(fail("not_converged"))
			if (!identical(mod$hit_iteration_cap, FALSE)) return(fail("iteration_cap_reached"))
			gradient_norm = suppressWarnings(as.numeric(mod$gradient_norm)[1L])
			if (!is.finite(gradient_norm)) return(fail("gradient_norm_nonfinite"))

			b = suppressWarnings(as.numeric(mod$b))
			j_treat = suppressWarnings(as.integer(j_treat)[1L])
			if (!is.finite(j_treat) || j_treat < 1L || j_treat > length(b) || any(!is.finite(b))) {
				return(fail("coefficients_nonfinite"))
			}
			if (check_treatment && abs(b[j_treat]) > private$max_abs_reasonable_coef) {
				return(fail("extreme_treatment_coefficient"))
			}

			information = mod$fisher_information %||% mod$XtWX %||% mod$information
			information = tryCatch(as.matrix(information), error = function(e) NULL)
			if (is.null(information) || nrow(information) < 1L ||
					nrow(information) != ncol(information) || nrow(information) != length(b) ||
					any(!is.finite(information))) {
				return(fail("information_unavailable"))
			}
			information = (information + t(information)) / 2
			chol_information = tryCatch(chol(information), error = function(e) NULL)
			if (is.null(chol_information)) return(fail("information_not_positive_definite"))
			reciprocal_condition = tryCatch(rcond(information), error = function(e) NA_real_)
			if (!is.finite(reciprocal_condition) || reciprocal_condition <= sqrt(.Machine$double.eps)) {
				return(fail("information_ill_conditioned"))
			}

			variance = suppressWarnings(as.numeric(mod$ssq_b_j)[1L])
			if (!is.finite(variance) || variance <= 0) {
				variance = tryCatch(chol2inv(chol_information)[j_treat, j_treat], error = function(e) NA_real_)
			}
			if (require_variance && (!is.finite(variance) || variance <= 0)) {
				return(fail("treatment_variance_unavailable"))
			}
			list(usable = TRUE, reason = NA_character_, variance = variance)
		},
		shared_combined_likelihood = function(estimate_only = FALSE){
			# A rejected primary fit is terminal for this inference object. Do not
			# let a later variance, likelihood-test, or resampling request refit the
			# same model and replace the typed nonestimable result.
			if (isTRUE(self$is_nonestimable("estimate"))) return(invisible(NULL))
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			private$cached_values$likelihood_test_context = NULL
			if (is.null(private$cached_values$KKstats)){
				private$compute_basic_match_data()
			}
			KKstats = private$cached_values$KKstats
			if (is.null(KKstats)) {
				private$cache_nonestimable_estimate("kk_clogit_combined_match_data_unavailable")
				return(invisible(NULL))
			}

			design = conditional_logit_prepare_combined_design(private, KKstats)
			X_comb = design$X
			y_comb = design$y
			j_beta_T = design$j_beta_T

			if (is.null(X_comb)){
				private$cache_nonestimable_estimate("kk_clogit_combined_no_informative_data")
				return(invisible(NULL))
			}

			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_comb,
				required_cols = j_beta_T,
				fit_fun = function(X_fit){
					j_beta_fit = match("beta_T", colnames(X_fit))
					tryCatch({
						res = if (estimate_only) {
							fast_logistic_regression_cpp(
								X = X_fit,
								y = as.numeric(y_comb),
								optimization_alg = private$optimization_alg,
								warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
								warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit)),
								estimate_only = FALSE
							)
						} else {
							fast_logistic_regression_with_var_cpp(
								X = X_fit,
								y = as.numeric(y_comb),
								j = j_beta_fit,
								optimization_alg = private$optimization_alg,
								warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
								warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit))
							)
						}
						res$params = as.numeric(res$b)
						res$neg_loglik = res$neg_loglik %||% res$neg_ll
						res
					}, error = function(e) NULL)
				},
				fit_ok = function(mod, X_fit, keep){
					j_beta_fit = match("beta_T", colnames(X_fit))
					isTRUE(private$assess_combined_fit(
						mod,
						j_beta_fit,
						require_variance = !estimate_only
					)$usable)
				}
			)
			mod = attempt$fit
			j_beta_T = if (!is.null(attempt$X)) match("beta_T", colnames(attempt$X)) else NA_integer_
			assessment = private$assess_combined_fit(
				mod,
				j_beta_T,
				require_variance = !estimate_only
			)
			if (!isTRUE(assessment$usable)){
				private$cached_mod = NULL
				private$cached_values$likelihood_test_context = NULL
				private$cache_nonestimable_estimate(paste0("kk_clogit_combined_", assessment$reason))
				return(invisible(NULL))
			}

			private$cached_values$beta_hat_T   = as.numeric(mod$b[j_beta_T])
			private$cached_mod = mod
			private$set_fit_warm_start(
				as.numeric(mod$b), "beta",
				fisher = mod$fisher_information %||% mod$XtWX
			)
			private$cached_values$likelihood_test_context = list(
				X = attempt$X,
				y = y_comb,
				j_treat = j_beta_T
			)
			if (!estimate_only) {
				private$cached_values$s_beta_hat_T = sqrt(assessment$variance)
			}
			private$clear_nonestimable_state()
			private$cached_values$df = NA_real_
			invisible(NULL)
		},
		get_standard_error = function(){
			private$shared_combined_likelihood(estimate_only = FALSE)
			se = private$cached_values$s_beta_hat_T
			if (is.null(se) || length(se) == 0L) {
				return(NA_real_)
			}
			as.numeric(se)[1L]
		},
		supports_likelihood_tests = function() TRUE,
		compute_likelihood_test_two_sided_pval = function(delta, testing_type, bartlett_B = NULL){
			spec = private$get_likelihood_test_spec()
			if (is.null(spec)) {
				if (!isTRUE(self$is_nonestimable())) {
					private$cache_nonestimable_estimate("kk_clogit_combined_likelihood_test_spec_unavailable")
				}
				return(NA_real_)
			}
			p_value = private$get_memoized_likelihood_test_pval(
				delta = delta,
				testing_type = testing_type,
				spec = spec,
				warm_cache_key = paste0("likelihood_test:", testing_type),
				bartlett_B = bartlett_B
			)
			if (!is.finite(p_value) && !isTRUE(self$is_nonestimable("estimate"))) {
				private$cache_nonestimable_se(paste0(testing_type, "_test_unavailable"))
			}
			p_value
		},
		get_likelihood_test_spec = function(){
			private$shared_combined_likelihood(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			X_fit = ctx$X
			y = as.numeric(ctx$y)
			j_treat = as.integer(ctx$j_treat)
			list(
				X = X_fit,
				y = y,
				j = j_treat,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					fit = tryCatch(
						fast_logistic_regression_with_var_cpp(
							X = X_fit,
							y = y,
							j = j_treat,
							warm_start_beta = start,
							fixed_idx = j_treat,
							fixed_values = delta,
							optimization_alg = private$optimization_alg
						),
						error = function(e) NULL
					)
					assessment = private$assess_combined_fit(
						fit,
						j_treat,
						require_variance = FALSE,
						check_treatment = FALSE
					)
					if (!isTRUE(assessment$usable)) return(NULL)
					fit
				},
				extract_start = function(fit) as.numeric(fit$b),
				score = function(fit){
					get_logistic_regression_score_cpp(X_fit, y, as.numeric(fit$b))
				},
				observed_information = function(fit){
					-get_logistic_regression_hessian_cpp(X_fit, as.numeric(fit$b))
				},
				fisher_information = function(fit){
					-get_logistic_regression_hessian_cpp(X_fit, as.numeric(fit$b))
				},
				information = function(fit){
					-get_logistic_regression_hessian_cpp(X_fit, as.numeric(fit$b))
				},
				neg_loglik = function(fit){
					conditional_logit_neg_loglik(X_fit, y, fit$b)
				}
			)
		},
		supports_lik_ratio_param_bootstrap = function() TRUE,
		compute_weighted_combined_estimate = function(row_weights, estimate_only = TRUE){
			if (is.null(private$cached_values$KKstats)){
				private$compute_basic_match_data()
			}
			KKstats = private$cached_values$KKstats
			if (is.null(KKstats)) {
				private$cache_nonestimable_estimate("kk_clogit_combined_weighted_match_data_unavailable")
				return(NA_real_)
			}
			conditional_logit_weighted_combined_estimate(
				private,
				KKstats,
				row_weights,
				estimate_only = estimate_only
			)
		},
		simulate_under_lik_null = function(spec, delta, null_fit){
			X = spec$X
			j = spec$j
			n = nrow(X)
			b_null = as.numeric(null_fit$b)
			pi = plogis(as.numeric(X %*% b_null))
			y_sim = as.integer(rbinom(n, 1L, pi))
			full_res = tryCatch(
				fast_logistic_regression_cpp(
					X = X, y = y_sim,
					optimization_alg = private$optimization_alg %||% "lbfgs",
					estimate_only = FALSE
				),
				error = function(e) NULL
			)
			full_assessment = private$assess_combined_fit(
				full_res,
				j,
				require_variance = FALSE
			)
			if (!isTRUE(full_assessment$usable)) return(NULL)
			list(
				full_fit = full_res,
				fit_null = function(d, start = NULL){
					fit = tryCatch(
						fast_logistic_regression_with_var_cpp(
							X = X, y = y_sim, j = j,
							warm_start_beta = start %||% as.numeric(full_res$b),
							fixed_idx = j, fixed_values = d,
							optimization_alg = private$optimization_alg %||% "lbfgs"
						),
						error = function(e) NULL
					)
					assessment = private$assess_combined_fit(
						fit,
						j,
						require_variance = FALSE,
						check_treatment = FALSE
					)
					if (!isTRUE(assessment$usable)) return(NULL)
					fit
				},
				neg_loglik = function(fit){
					conditional_logit_neg_loglik(X, y_sim, fit$b)
				}
			)
		}
	)
)

#' One-Likelihood Conditional-Logistic Inference for KK Binary Designs
#'
#' Estimates a treatment log-odds-ratio \eqn{\beta_T} for binary
#' (incidence) outcomes collected under a KK matching-on-the-fly design
#' (\code{\link[EDI:DesignSeqOneByOneKK14]{DesignSeqOneByOneKK14}} or
#' subclass) by maximizing one combined likelihood that couples a
#' conditional-logistic (intercept-free, within-matched-pair) likelihood
#' for matched subjects with an ordinary logistic likelihood for reservoir
#' subjects, sharing a single treatment coefficient across both pieces.
#' This is the "one-likelihood" counterpart to
#' \code{\link[EDI:InferenceIncidKKCondLogitIVWC]{InferenceIncidKKCondLogitIVWC}},
#' which instead fits the matched and reservoir pieces separately and
#' pools them by inverse-variance weighting; here the treatment coefficient
#' is a single joint MLE, and \code{likelihood_tier = "full"} exposes
#' likelihood-ratio, score, and gradient inference plus a parametric
#' likelihood bootstrap in addition to Wald.
#'
#' \strong{Estimand.} \eqn{\beta_T}, the treatment coefficient of a
#' logistic mean model \eqn{\mathrm{logit}(P(Y=1 \mid w,x)) = \beta_0 +
#' \beta_T w + x\beta}; \eqn{\exp(\hat\beta_T)} is the treatment-vs-control
#' odds ratio.
#'
#' \strong{Model.} Matched pairs contribute McFadden-style conditional
#' logistic likelihood terms that condition away the pair-specific nuisance
#' intercept (see \code{build_matching_combined_clogit_design_cpp}/
#' \code{collect_discordant_pairs_cpp}); reservoir subjects contribute an
#' ordinary logistic likelihood with one shared intercept. The combined
#' negative log-likelihood is minimized jointly in
#' \eqn{(\beta_0, \beta_T, \beta)} via \code{fast_logistic_regression_cpp}/
#' \code{fast_logistic_regression_with_var_cpp}. When
#' \code{get_testing_type() != "wald"}, asymptotic CI/p-value calls are
#' routed through \code{\link[EDI:InferenceAsympLik]{InferenceAsympLik}}'s
#' generic score/likelihood-ratio/gradient dispatch instead of the
#' design's own Wald machinery.
#'
#' \strong{Assumptions.} Independence across matched pairs and reservoir
#' subjects given covariates; correct logistic mean specification; a KK
#' matching-on-the-fly design supplying the matched/reservoir partition.
#' No response censoring is supported (checked at construction via
#' \code{assertNoCensoring()}).
#'
#' @references
#' Kapelner, A., and Krieger, A. M. (2014). "Matching on-the-fly: Sequential
#' allocation with higher power and efficiency." \emph{Biometrics}, 70(2),
#' 378-388. \doi{10.1111/biom.12148}. (KK14 in \code{REFERENCES.md}.)
#'
#' @seealso Analogous Python API for conditional logistic regression:
#'   \href{https://www.statsmodels.org/stable/discretemod.html}{statsmodels
#'   discrete models} (\code{ConditionalLogit}).
#'   \href{https://en.wikipedia.org/wiki/Logistic_regression}{Logistic
#'   regression} (orientation).
#' @export
# Migrated 2026-08-19 (fix_inference_hierarchy.md "Full-Likelihood
# Estimators" / "KK And IVWC Estimators"): see
# IncidKKCondLogitOneLikLikelihoodSource above.
InferenceIncidKKCondLogitOneLik = define_inference_class(
	classname = "InferenceIncidKKCondLogitOneLik",
	inherit = Inference,
	components = c("BayesianBootstrap", "IncidKKCondLogitOneLikLikelihood"),
	public = list(
		# Pinned from InferenceRandCI (incidence class -- Lesson 3): the
		# non-KK sibling InferenceIncidRiskDiff and every other incidence KK
		# migration this stretch pin RandCI for the Zhang randomization
		# dispatch, not InferenceRand. Preflight the observed model statistic
		# before RandCI can take its incidence-specific Zhang shortcut: an exact
		# p-value must not be reported for a class whose declared primary
		# treatment statistic is nonestimable.
		compute_rand_two_sided_pval = function(
				r = 501, delta = 0, transform_responses = "none", na.rm = TRUE,
				show_progress = TRUE, permutations = NULL, type = NULL,
				args_for_type = NULL, zero_one_logit_clamp = .Machine$double.eps){
			private$shared_combined_likelihood(estimate_only = TRUE)
			observed = suppressWarnings(as.numeric(private$cached_values$beta_hat_T)[1L])
			if (isTRUE(self$is_nonestimable("estimate")) || !is.finite(observed)) {
				if (!isTRUE(self$is_nonestimable("estimate"))) {
					private$cache_nonestimable_estimate("kk_clogit_combined_randomization_observed_statistic_unavailable")
				}
				return(NA_real_)
			}
			rand_fn = InferenceRandCI$public_methods$compute_rand_two_sided_pval
			environment(rand_fn) = environment()
			rand_fn(
				r = r, delta = delta, transform_responses = transform_responses,
				na.rm = na.rm, show_progress = show_progress,
				permutations = permutations, type = type,
				args_for_type = args_for_type,
				zero_one_logit_clamp = zero_one_logit_clamp
			)
		}
	),
	# capabilities = "likelihood_ratio" is required explicitly -- same
	# rationale as every class composing ParametricLikelihoodBootstrap
	# directly (bypassing StandardModelCache).
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"initialize",
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_asymp_confidence_interval_generic",
			"compute_asymp_two_sided_pval_generic",
			"get_supported_testing_types", "set_testing_type",
			"approximate_bootstrap_distribution_beta_hat_T"
		),
		private = c(
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl",
			"compute_treatment_estimate_during_randomization_inference",
			"get_standard_error",
			"supports_likelihood_tests",
			"compute_likelihood_test_two_sided_pval",
			"supports_lik_ratio_param_bootstrap",
			"supports_information_preference",
			"supports_observed_information",
			"get_supported_information_preferences_impl",
			"supports_bartlett_likelihood_ratio_approx",
			"get_bartlett_factor_approx",
			"get_likelihood_test_spec",
			"simulate_under_lik_null"
		)
	)
)

# Static leaf source (2026-08-18 migration, fix_inference_hierarchy.md "KK And
# IVWC Estimators"): formerly a plain leaf on
# `InferenceKKPassThroughCompoundNoParamBootstrap`; the KK compound layer now
# arrives via the registered KKCompound component (this component's declared
# dependency). The estimator privates call the free functions
# conditional_logit_fit_matched_pairs()/conditional_logit_fit_reservoir()
# directly, so no ConditionalLogitPartialLikelihood component methods are
# needed here (the discovery-era target composition named that component; the
# factory reality below supersedes it, mirroring the LWA Cox IVWC target
# update). The `eval(body(...))` bootstrap override was dropped as a verified
# no-op (same argument as SurvivalKKRankRegrIVWCSource). The factory call is
# below the source. The OneLik sibling earlier in this file is untouched
# (one-likelihood phase).
IncidKKCondLogitIVWCSource = list(
	public = list(
		#' @description Initialize conditional-logistic IVWC inference for KK binary
		#'   responses and prepare separate matched-pair and reservoir likelihood
		#'   components used by \code{\link[EDI:InferenceIncidKKCondLogitIVWC]{InferenceIncidKKCondLogitIVWC}}.
		#' @param des_obj A completed \code{Design} object.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose  		Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
			}
			super$initialize(des_obj = des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
			private$init_kk_passthrough(des_obj)
		},
			#' @description Computes the class-specific treatment-effect estimate; see
			#'   \code{\link[EDI:Inference]{Inference}}.
			#' @param estimate_only Logical. If TRUE, skip variance component calculations.
			compute_estimate = function(estimate_only = FALSE){
				private$shared(estimate_only = estimate_only)
				private$cached_values$beta_hat_T
			},
			#' @description Uses the shared asymptotic confidence-interval contract; see
			#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
			#' @param alpha Numeric. Significance level (default 0.05).
			compute_asymp_confidence_interval = function(alpha = 0.05){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Uses the shared asymptotic two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param delta Numeric. Null treatment effect value (default 0).
		compute_asymp_two_sided_pval = function(delta = 0){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		}
	),
	private = list(
		compute_basic_match_data = function() private$compute_basic_kk_match_data_impl(),
		# Copied verbatim from InferenceMLEorKMSummaryTable (the old ladder's
		# ancestor) -- Lesson 5 (see SurvivalKKRankRegrIVWCSource): the Wald
		# component's own get_standard_error() fallback stop()s when the SE is
		# missing (shared() below has an extra early-return on cached
		# beta_hat_T and NA-out failure paths), whereas the old ladder's
		# version (this one) calls shared() and then degrades to NA_real_.
		get_standard_error = function(){
			private$shared(estimate_only = FALSE)
			se = private$cached_values$s_beta_hat_T
			if (is.null(se) || length(se) != 1L) NA_real_ else se
		},
		shared = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			if (!is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			private$compute_basic_match_data()
			KKstats = private$cached_values$KKstats
			if (is.null(KKstats)) return(invisible(NULL))
			X_covars = private$X
			
			# --- Matched pairs: Conditional Logistic ---
			if (KKstats$m > 0){
				private$clogit_for_matched_pairs(KKstats, X_covars)
			}
			beta_m   = private$cached_values$beta_T_matched
			ssq_m    = private$cached_values$ssq_beta_T_matched
			m_ok     = !is.null(beta_m) && is.finite(beta_m) &&
			           !is.null(ssq_m)  && is.finite(ssq_m) && ssq_m > 0
			# --- Reservoir: Logistic Regression ---
			if (KKstats$nRT > 0 && KKstats$nRC > 0){
				private$logistic_for_reservoir(KKstats, X_covars)
			}
			beta_r   = private$cached_values$beta_T_reservoir
			ssq_r    = private$cached_values$ssq_beta_T_reservoir
			r_ok     = !is.null(beta_r) && is.finite(beta_r) &&
			           !is.null(ssq_r)  && is.finite(ssq_r) && ssq_r > 0
			# --- Variance-weighted combination ---
			if (m_ok && r_ok){
				w_star = ssq_r / (ssq_r + ssq_m)
				private$cached_values$beta_hat_T   = w_star * beta_m + (1 - w_star) * beta_r
				if (estimate_only) return(invisible(NULL))
				private$cached_values$s_beta_hat_T = sqrt(ssq_m * ssq_r / (ssq_m + ssq_r))
			} else if (m_ok){
				private$cached_values$beta_hat_T   = beta_m
				private$cached_values$s_beta_hat_T = sqrt(ssq_m)
			} else if (r_ok){
				private$cached_values$beta_hat_T   = beta_r
				private$cached_values$s_beta_hat_T = sqrt(ssq_r)
			} else {
				private$cached_values$beta_hat_T   = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
			}
			private$cached_values$df = Inf
		},
		clogit_for_matched_pairs = function(KKstats, X_covars){
			fit = conditional_logit_fit_matched_pairs(KKstats)
			if (is.null(fit) || !isTRUE(fit$converged)){
				private$cached_values$beta_T_matched = NA_real_
				private$cached_values$ssq_beta_T_matched = NA_real_
				return(invisible(NULL))
			}
			private$cached_values$beta_T_matched = as.numeric(fit$b[1])
			private$cached_values$ssq_beta_T_matched = as.numeric(fit$ssq_b_j)
		},
		logistic_for_reservoir = function(KKstats, X_covars){
			fit = conditional_logit_fit_reservoir(KKstats, X_covars)
			if (is.null(fit) || !isTRUE(fit$converged)){
				private$cached_values$beta_T_reservoir = NA_real_
				private$cached_values$ssq_beta_T_reservoir = NA_real_
				return(invisible(NULL))
			}
			private$cached_values$beta_T_reservoir = as.numeric(fit$b[2])
			private$cached_values$ssq_beta_T_reservoir = as.numeric(fit$ssq_b_j)
		}
	)
)

#' Conditional Logistic IVWC Inference (KK Designs, Binary Response)
#'
#' Inverse-variance-weighted combination (IVWC) of two independently fit
#' conditional-likelihood pieces for KK matched-pair-plus-reservoir binary
#' designs: matched pairs are analyzed with exact conditional logistic
#' regression (\code{conditional_logit_fit_matched_pairs()}, which
#' conditions out the pair-specific nuisance intercept and estimates only the
#' treatment log-odds-ratio \eqn{\beta_T} from discordant pairs, or the joint
#' \code{clogit}-style likelihood when covariates are present), and reservoir
#' subjects are analyzed with ordinary logistic regression
#' (\code{conditional_logit_fit_reservoir()}). If \eqn{\hat\beta_m,
#' \hat\sigma^2_m} and \eqn{\hat\beta_r, \hat\sigma^2_r} are the matched-pair
#' and reservoir estimates and their variances, the combined estimate is the
#' variance-weighted average
#' \deqn{\hat\beta_T = w^\star \hat\beta_m + (1-w^\star) \hat\beta_r, \quad
#' w^\star = \frac{\hat\sigma^2_r}{\hat\sigma^2_r + \hat\sigma^2_m},}
#' with combined variance \eqn{\hat\sigma^2_m \hat\sigma^2_r / (\hat\sigma^2_m
#' + \hat\sigma^2_r)}. This is the classical fixed-effects inverse-variance
#' meta-analysis pooling formula (see Cochrane Handbook / DerSimonian-Laird),
#' applied here to combine the two conditionally-independent likelihood
#' contributions of a KK design rather than to pool separate studies. When
#' only one of the two components is estimable the combined estimate falls
#' back to that component alone. Contrast this with
#' \code{InferenceIncidKKCondLogitOneLik}, which instead fits a single joint
#' likelihood over both pieces (see that class's documentation) --
#' \code{likelihood_tier = "partial"} here reflects that the matched-pair
#' piece is a genuine conditional (partial) likelihood, but the two-piece
#' combination itself is a closed-form Wald/meta-analytic step, not a further
#' likelihood evaluation.
#'
#' \strong{Legacy class.} Not fully tested in \code{comprehensive_tests.R}.
#'
#' @seealso \code{\link[EDI:InferenceIncidKKCondLogitOneLik]{InferenceIncidKKCondLogitOneLik}}
#'   for the one-likelihood alternative combining strategy.
#' @references
#' Fleiss, J.L., Levin, B., Paik, M.C. (2003). \emph{Statistical Methods for
#' Rates and Proportions}, 3rd ed. Wiley. (conditional logistic regression for
#' matched pairs)
#' @export
InferenceIncidKKCondLogitIVWC = define_inference_class(
	classname = "InferenceIncidKKCondLogitIVWC",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald", "IncidKKCondLogitIVWC"),
	public = list(
		# Pinned from InferenceRandCI (NOT InferenceRand): incidence classes
		# keep RandCI's Zhang-dispatch-aware version -- Lesson 3, same as the
		# KK Newcombe migration.
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval
	),
	metadata = list(likelihood_tier = "partial"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"initialize",
			"compute_estimate",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			# KKCompound chain vs bootstrap/Wald chain: the KK-aware versions win
			# via component order, matching the old ladder's inherited behavior
			# -- the source dropped the class's no-op eval(body(...)) restatement
			# of approximate_bootstrap_distribution_beta_hat_T.
			"approximate_bootstrap_distribution_beta_hat_T",
			"compute_estimate_with_bootstrap_weights"
		),
		private = c(
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl",
			"compute_treatment_estimate_during_randomization_inference",
			"compute_basic_match_data",
			"shared",
			# MLEorKM's graceful-NA version wins over the Wald component's
			# stop()-on-missing-SE fallback (Lesson 5, see the Source comment).
			"get_standard_error"
		)
	)
)
