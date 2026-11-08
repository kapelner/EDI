#' Log-binomial likelihood component source
#'
#' Source list for the \code{IncidenceLogBinomialLikelihood} component composed by \code{InferenceIncidLogBinomial}.
#'
#' @keywords internal
IncidenceLogBinomialLikelihoodSource = list(
	public = list(

		#' @description Initialize inference for the log-link binomial risk-ratio
		#'   model \eqn{\log P(Y_i = 1) = \beta_0 + \beta_T W_i + X_i^\top \gamma};
		#'   see \code{\link[EDI:InferenceIncidLogBinomial]{InferenceIncidLogBinomial}}
		#'   for the model form. Does not fit the model; the fit is deferred to the
		#'   first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with an incidence response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose               Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		#' @param harden                Whether to apply robustness measures.
		#' @param max_abs_reasonable_coef Cap for reasonable log-binomial coefficients.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL, harden = TRUE, max_abs_reasonable_coef = 25){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
			}
			super$initialize(des_obj, model_formula = model_formula, verbose = verbose, harden = harden, smart_cold_start_default = smart_cold_start_default)
			private$max_abs_reasonable_coef = max_abs_reasonable_coef
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Refits the log-binomial model with subject/block-level weights
		#'   applied to the fitting log-likelihood (Bayesian-bootstrap or
		#'   nonparametric-bootstrap draw weights, expanded to row level via
		#'   \code{private$expand_subject_or_block_weights_to_row_weights()}) via
		#'   \code{\link{fast_log_binomial_regression_weighted_cpp}}, and returns the
		#'   reweighted log-risk-ratio estimate \eqn{\hat\beta_T^{(w)}}. Uses the same
		#'   QR column-dropping hardening and fit-reasonableness check as
		#'   \code{compute_estimate()}; a hardened-but-still-unreasonable fit is
		#'   cached as nonestimable and returns \code{NA}.
		#' @param subject_or_block_weights Bootstrap weights at the subject or block level.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L,
				fit_fun = function(X_fit, keep){
					j_treat = match(2L, keep)
					ws_args = private$logbin_feasible_warm_start_args(X_fit, list(
						warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
						warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit))
					))
					res = tryCatch(
						fast_log_binomial_regression_weighted_cpp(
							X = X_fit,
							y = as.numeric(private$y),
							weights = as.numeric(row_weights),
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default
						),
						error = function(e) NULL
					)
					if (is.null(res)) return(NULL)
					res$j_treat = j_treat
					ssq_b_j = NA_real_
					if (!estimate_only && !is.null(res$fisher_information) &&
					    is.matrix(res$fisher_information) && nrow(res$fisher_information) >= j_treat) {
						inv_fi = tryCatch(solve(res$fisher_information), error = function(e) NULL)
						if (!is.null(inv_fi) && is.finite(inv_fi[j_treat, j_treat]) && inv_fi[j_treat, j_treat] > 0) {
							ssq_b_j = inv_fi[j_treat, j_treat]
						}
					}
					res$ssq_b_j = ssq_b_j
					res$ssq_b_2 = ssq_b_j
					res
				},
				fit_ok = function(mod, X_fit, keep){
					j_treat = match(2L, keep)
					if (!isTRUE(private$is_log_binomial_fit_reasonable(mod, X_fit, j_treat, check_probability_boundary = FALSE))) return(FALSE)
					TRUE
				}
			)
			private$cached_mod = attempt$fit
			j_treat = match(2L, attempt$keep)
			if (!isTRUE(private$is_log_binomial_fit_reasonable(attempt$fit, attempt$X, j_treat, check_probability_boundary = FALSE))){
				private$cache_nonestimable_estimate("log_binomial_weighted_fit_unavailable")
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			private$set_fit_warm_start(attempt$fit$b, "beta", fisher = attempt$fit$fisher_information, force_pd = TRUE)
			private$cached_values$beta_hat_T = as.numeric(attempt$fit$b[j_treat])
			ssq = attempt$fit$ssq_b_j %||% attempt$fit$ssq_b_2
			private$cached_values$s_beta_hat_T = if (!is.null(ssq) && is.finite(ssq) && ssq > 0) sqrt(ssq) else NA_real_
			private$cached_values$df = NA_real_
			private$cached_values$beta_hat_T
		},
		#' @description Score confidence interval for \eqn{\beta_T} by test inversion
		#'   of the score test (find the set of \code{delta} not rejected at level
		#'   \code{alpha}); see \code{\link[EDI:InferenceAsympLik]{InferenceAsympLik}}
		#'   for the shared inversion contract. If the underlying root-finding
		#'   fails or degenerates, returns \code{NA} bounds and records a score
		#'   procedure failure; the Wald estimate, standard error and
		#'   \code{is_nonestimable()} are kept (unless the Wald fit itself is
		#'   unusable).
		#' @param alpha Two-sided miscoverage rate; the returned interval targets
		#'   \code{1 - alpha} coverage.
		compute_score_confidence_interval = function(alpha = 0.05){
			# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
			# migration ladders): was `super$compute_score_confidence_interval(...)`,
			# relying on classic R6 inheritance reaching InferenceAsympLik's real
			# implementation. Composed classes have no such `super$` chain --
			# calling the same private impl InferenceAsympLik's own public method
			# delegates to directly (see that file's compute_score_confidence_
			# interval) is the behavior-preserving replacement; same fix shape as
			# the identical StandardModelCacheSource super$ breakage documented in
			# inference_all_abstract_asymp_lik_std_mod_cache.R.
			ci = tryCatch(
				private$compute_score_confidence_interval_impl(alpha),
				error = function(e){
					msg = if (length(e$message) == 0L) "" else e$message
					if (grepl("'names' attribute", msg, fixed = TRUE) ||
					    grepl("must be the same length as the vector", msg, fixed = TRUE)) {
						edi_record_procedure_failure(self, private, "score_confidence_interval_unavailable", stage = "se") # TODO-116 (2026-10-22)
						return(c(NA_real_, NA_real_))
					}
					stop(e)
				}
			)
			if (length(ci) < 2L || !all(is.finite(ci[1:2]))) {
				edi_record_procedure_failure(self, private, "score_confidence_interval_unavailable", stage = "se") # TODO-116 (2026-10-22)
				return(c(NA_real_, NA_real_))
			}
			ci
		},
		#' @description Gradient confidence interval for \eqn{\beta_T} by test
		#'   inversion of the gradient test; see
		#'   \code{\link[EDI:InferenceAsympLik]{InferenceAsympLik}} for the shared
		#'   inversion contract. If gradient inversion gives no usable interval
		#'   (e.g. the gradient test is undefined at a null fit on the
		#'   \eqn{\exp(X\beta) \le 1} boundary), the likelihood-ratio interval is
		#'   returned instead, with a warning of class
		#'   \code{edi_lik_ci_lik_ratio_fallback}. If that also fails or
		#'   degenerates, returns \code{NA} bounds and records a gradient procedure
		#'   failure; the Wald estimate, standard error and \code{is_nonestimable()}
		#'   are kept (unless the Wald fit itself is unusable).
		#' @param alpha Two-sided miscoverage rate; the returned interval targets
		#'   \code{1 - alpha} coverage.
		compute_gradient_confidence_interval = function(alpha = 0.05){
			# See compute_score_confidence_interval()'s comment above -- same
			# super$ fix, same reason.
			ci = tryCatch(
				private$compute_gradient_confidence_interval_impl(alpha),
				error = function(e){
					msg = if (length(e$message) == 0L) "" else e$message
					if (grepl("'names' attribute", msg, fixed = TRUE) ||
					    grepl("must be the same length as the vector", msg, fixed = TRUE)) {
						edi_record_procedure_failure(self, private, "gradient_confidence_interval_unavailable", stage = "se") # TODO-116 (2026-10-22)
						return(c(NA_real_, NA_real_))
					}
					stop(e)
				}
			)
			if (length(ci) < 2L || !all(is.finite(ci[1:2]))) {
				edi_record_procedure_failure(self, private, "gradient_confidence_interval_unavailable", stage = "se") # TODO-116 (2026-10-22)
				return(c(NA_real_, NA_real_))
			}
			ci
		}
	),
	private = list(
		# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
		# migration ladders): see inference_incid_log_regr_private's cached_mod
		# entry (inference_incidence_logit.R) for the full explanation.
		cached_mod = NULL,
		best_X_colnames = NULL,
		logbin_X_full_cache = NULL,
		logbin_w_cache = NULL,
		logbin_X_cov_cache = NULL,
		max_abs_reasonable_coef = 25,
		is_log_binomial_fit_reasonable = function(mod, X_fit = NULL, j_treat = 2L, check_probability_boundary = TRUE){
			if (is.null(mod) || is.null(mod$b)) return(FALSE)
			j_treat = as.integer(j_treat %||% mod$j_treat %||% 2L)
			if (length(j_treat) != 1L || !is.finite(j_treat) || j_treat < 1L) return(FALSE)
			b = as.numeric(mod$b)
			if (length(b) < j_treat || any(!is.finite(b))) return(FALSE)
			if (any(abs(b) > private$max_abs_reasonable_coef)) return(FALSE)
			if (!is.null(mod$converged) && !isTRUE(mod$converged)) return(FALSE)
			# check_probability_boundary = FALSE: skip the fitted-probability-
			# exceeds-1 boundary check. Used only for the Dirichlet-weighted
			# Bayesian-bootstrap refit (compute_estimate_with_bootstrap_
			# weights() below), never for the primary fit. Under Dirichlet
			# reweighting, replicates that push a high-p0 subject's fitted
			# probability over 1 are disproportionately the EXTREME TAIL of
			# the resampling distribution -- exactly the replicates needed to
			# represent true sampling variability. Discarding them (as this
			# function used to do unconditionally) shrinks the empirical
			# bootstrap spread, producing simultaneously too-narrow CIs and
			# too-small p-values (found 2026-09-06: Bayesian-bootstrap size
			# 25-36% vs. nominal 5%, coverage 56-70% vs. nominal 95%, while
			# the ordinary nonparametric bootstrap for the same class stayed
			# near nominal). The coefficient estimate itself from a boundary-
			# hitting weighted fit is still a valid (if large) draw from the
			# resampling distribution of beta_hat_T; only fitted probabilities
			# derived from it are out of range, not the coefficient.
			if (isTRUE(check_probability_boundary)) {
				if (!is.null(X_fit)) {
					eta = tryCatch(as.numeric(as.matrix(X_fit) %*% b), error = function(e) NA_real_)
					if (any(!is.finite(eta))) return(FALSE)
					if (any(eta > 1e-6)) return(FALSE)
				} else if (!is.null(mod$mu_hat)) {
					mu = as.numeric(mod$mu_hat)
					if (any(!is.finite(mu)) || any(mu < -1e-10) || any(mu > 1 + 1e-10)) return(FALSE)
				}
			}
			TRUE
		},
		get_complexity_tier = function() "heavy",
		# TODO-128 (2026-10-22): jackknife and nonparametric-bootstrap workers
		# warm-start from the full-data fit (cached_mod), not from whatever
		# fit_warm_start the object holds when the worker is built. The Fisher-
		# scoring fit stops at a relative step of 1e-6 and converges only
		# linearly, so leave-one-out refits from different starts disagree by
		# ~1e-7 per fold, which the jackknife amplifies (n - 1)-fold. A
		# randomization call refits the observed statistic on this object and
		# overwrites fit_warm_start (compute_treatment_estimate_during_
		# randomization_inference() below), which made a later jackknife differ
		# by ~1e-11 from a fresh one. In a fresh call cached_mod is exactly what
		# shared() stored as fit_warm_start, so fresh results are unchanged.
		# Workers whose dispatch policy is cold ignore the base warm start.
		create_bootstrap_worker_state = function(){
			worker_state = private$create_design_backed_bootstrap_worker_state()
			op = private$active_resampling_operation
			full_fit = private$cached_mod
			if ((identical(op, "jackknife") || identical(op, "non_param_boot")) &&
			    !is.null(full_fit) && length(full_fit$b) && all(is.finite(full_fit$b))) {
				worker_state$base_fit_warm_start = as.numeric(full_fit$b)
				worker_state$base_fit_warm_start_type = "beta"
				worker_state$base_fit_warm_start_fisher = full_fit$fisher_information %||% full_fit$XtWX
			}
			worker_state
		},
		# TODO-128 (2026-10-22): drop a warm start that sits on (or beyond) the
		# exp(X b) < 1 boundary of the problem being fit. The C++ Fisher-scoring
		# loop has no active-set step: from such a start the Newton step leaves
		# the feasible region, step halving shrinks it to almost nothing, and the
		# tiny accepted step passes the relative-change test, so the fit reports
		# converged = TRUE at its starting point. When the full-data fit has a
		# subject on the boundary, every warm-started leave-one-out, bootstrap
		# or Dirichlet-weighted refit therefore returned the full-data estimate
		# unchanged (jackknife SE ~9x too small, a third of Bayesian-bootstrap
		# draws exactly at beta_hat_T). An interior start is passed through
		# untouched, so fits that never reach the boundary are bit-identical.
		logbin_feasible_warm_start_args = function(X_fit, ws_args, boundary_eta = -1e-6){
			start = ws_args$warm_start_beta
			if (is.null(start) || is.null(X_fit) || length(start) != ncol(X_fit)) return(ws_args)
			eta_max = suppressWarnings(max(as.numeric(as.matrix(X_fit) %*% as.numeric(start))))
			if (is.finite(eta_max) && eta_max <= boundary_eta) return(ws_args)
			ws_args$warm_start_beta = NULL
			ws_args$warm_start_fisher_info = NULL
			ws_args
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
				X = cbind(1, private$w)
			} else {
				X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
				X = cbind(1, treatment = private$w, X_cov)
			}
			ws_args = private$logbin_feasible_warm_start_args(X, private$get_backend_warm_start_args(ncol(X)))
			res = tryCatch(
				fast_log_binomial_regression_cpp(
					X = X, y = as.numeric(private$y),
					warm_start_beta = ws_args$warm_start_beta,
					warm_start_fisher_info = ws_args$warm_start_fisher_info,
					smart_cold_start = private$smart_cold_start_default
				),
				error = function(e) NULL
			)

			if (!isTRUE(private$is_log_binomial_fit_reasonable(res, X, 2L))){
				return(NA_real_)
			}
			private$set_fit_warm_start(res$b, "beta", fisher = res$fisher_information, force_pd = TRUE)
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
		compute_gradient_confidence_interval_impl = function(alpha){
			# TODO-190 (v1.0.5): hold the inner "gradient test unavailable (NA is
			# returned)" warning until we know whether an interval is substituted;
			# if one is, that warning would be wrong and the substitution warning
			# below (which carries the same reason) replaces it.
			held = list()
			ci = withCallingHandlers(
				private$invert_gradient_ci_uniroot(alpha),
				edi_lik_test_unavailable_warning = function(w){
					held[[length(held) + 1L]] <<- w
					invokeRestart("muffleWarning")
				}
			)
			release_held = function() for (w in held) warning(w)
			if (length(ci) >= 2L && all(is.finite(ci[1:2]))) { release_held(); return(ci) }

			# Log-binomial fixed-effect profiles can be infeasible on one side of
			# the treatment coefficient, and the score at a boundary null fit can be
			# undefined (edi_log_binomial_kkt_terms()).  Use the finite
			# likelihood-ratio profile interval rather than returning an NA gradient
			# CI -- visibly (TODO-190): classed warning + recorded reason.
			ci_fallback = tryCatch(private$invert_lik_ratio_ci_newton(alpha), error = function(e) c(NA_real_, NA_real_))
			if (length(ci_fallback) >= 2L && all(is.finite(ci_fallback[1:2]))) {
				names(ci_fallback) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
				if (length(held)) {
					# the NA warning was never shown: let a later NA gradient p-value warn
					private$cached_values$lik_test_unavailable_warned = setdiff(private$cached_values$lik_test_unavailable_warned %||% character(), "gradient")
				}
				edi_warn_log_binomial_gradient_ci_lik_ratio_substitution_once(self, private)
				return(ci_fallback)
			}
			release_held()
			ci
		},
		simulate_under_lik_null = function(spec, delta, null_fit){
			b_null     = as.numeric(null_fit$b)
			mu         = pmin(pmax(exp(as.numeric(spec$X %*% b_null)), 0), 1)
			y_sim      = as.numeric(rbinom(length(mu), 1L, mu))
			X_fit      = spec$X
			j          = spec$j

			# Parametric bootstrap: use observed fit as anchor
			ws_args = private$get_backend_warm_start_args(ncol(X_fit))
			full_fit_b = tryCatch(
				fast_log_binomial_regression_cpp(
					X = X_fit, y = y_sim,
					warm_start_beta = ws_args$warm_start_beta,
					warm_start_fisher_info = ws_args$warm_start_fisher_info,
					smart_cold_start = private$smart_cold_start_default
				),
				error = function(e) NULL
			)
			if (!isTRUE(private$is_log_binomial_fit_reasonable(full_fit_b, X_fit, j))) return(NULL)
			list(
				full_fit = full_fit_b,
				fit_null = function(d, start = NULL){
					ws_args_null = private$get_backend_warm_start_args(ncol(X_fit))
					res = tryCatch(
						fast_log_binomial_regression_cpp(
							X = X_fit, y = y_sim,
							warm_start_beta = start %||% full_fit_b$b,
							warm_start_fisher_info = ws_args_null$warm_start_fisher_info,
							fixed_idx = j, fixed_values = d,
							smart_cold_start = TRUE
						),
						error = function(e) NULL
					)
					if (!isTRUE(private$is_log_binomial_fit_reasonable(res, X_fit, j))) return(NULL)
					res
				},
				neg_loglik = function(fit){
					eta_f  = as.numeric(X_fit %*% as.numeric(fit$b))
					mu_fit = exp(eta_f)
					-sum(y_sim * log(pmax(mu_fit, 1e-15)) + (1 - y_sim) * log(pmax(1 - mu_fit, 1e-15)))
				}
			)
		},
		get_likelihood_test_spec = function(){
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			X_fit = ctx$X
			y = as.numeric(private$y)
			j_treat = as.integer(ctx$j_treat)
			list(
				X = X_fit, y = y, j = j_treat,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					# TODO-177 (2026-11-07): a start of the wrong length is dropped.
					if (!is.null(start) && (length(start) != ncol(X_fit) || !all(is.finite(start)))) start = NULL
					try_fit = function(beta0, fisher0) {
						res = tryCatch(
							fast_log_binomial_regression_cpp(
								X_fit, y,
								warm_start_beta = beta0,
								warm_start_fisher_info = fisher0,
								fixed_idx = j_treat, fixed_values = delta,
								smart_cold_start = private$smart_cold_start_default
							),
							error = function(e) NULL
						)
						if (!isTRUE(private$is_log_binomial_fit_reasonable(res, X_fit, j_treat))) NULL else res
					}
					# The original call first: identical result whenever it succeeds.
					ws_args = private$get_backend_warm_start_args(ncol(X_fit))
					res = try_fit(start %||% ws_args$warm_start_beta, ws_args$warm_start_fisher_info)
					if (!is.null(res)) {
						# TODO-181 LogBinomial leftover: where the set of rows at
						# exp(X b) = 1 changes with delta, a warm-started fit can stop
						# with a row held at the bound that the optimum frees (KKT
						# multiplier < 0; one calibration replicate: 1.6e-4 above the
						# constrained minimum). Such a fit is refitted from a cold
						# start and the lower negative log-likelihood is kept.
						kkt = edi_log_binomial_kkt_terms(X_fit, y, as.numeric(res$b), j_treat)
						if (isTRUE(kkt$not_kkt)) {
							cold = try_fit(NULL, NULL)
							if (!is.null(cold) &&
							    edi_log_binomial_neg_loglik(X_fit, y, cold$b) < edi_log_binomial_neg_loglik(X_fit, y, res$b)) res = cold
						}
						return(res)
					}
					# TODO-177: retry from the full fit with beta_T = delta and no
					# warm Fisher (a stale one can stall iteration 0), then cold.
					b_full = as.numeric(private$cached_mod$b)
					if (length(b_full) == ncol(X_fit) && all(is.finite(b_full))) {
						b_full[j_treat] = delta
						res = try_fit(b_full, NULL)
						if (!is.null(res)) return(res)
					}
					try_fit(NULL, NULL)
				},
				extract_start = function(fit){
					as.numeric(fit$b)
				},
				# TODO-181 LogBinomial leftover: at a null fit on (or within the
				# finite-difference stencil's reach of) the exp(X b) <= 1 boundary,
				# the score and information come from edi_log_binomial_kkt_terms();
				# every other fit keeps the finite-difference values unchanged.
				score = function(fit){
					edi_log_binomial_lik_test_score(X_fit, y, as.numeric(fit$b), j_treat, private)
				},
				observed_information = function(fit){
					edi_log_binomial_lik_test_information(X_fit, y, as.numeric(fit$b), j_treat)
				},
				fisher_information = function(fit){
					edi_log_binomial_lik_test_information(X_fit, y, as.numeric(fit$b), j_treat)
				},
				information = function(fit){
					edi_log_binomial_lik_test_information(X_fit, y, as.numeric(fit$b), j_treat)
				},
				neg_loglik = function(fit){
					eta = as.numeric(X_fit %*% as.numeric(fit$b))
					mu = exp(eta)
					-sum(y * log(pmax(mu, 1e-15)) + (1 - y) * log(pmax(1 - mu, 1e-15)))
				}
			)
		},
		generate_mod = function(estimate_only = FALSE){
			X_data = private$get_X()
			if (is.null(private$logbin_X_full_cache) ||
					!identical(private$w, private$logbin_w_cache) ||
					!identical(X_data, private$logbin_X_cov_cache)) {
				private$logbin_X_full_cache = if (is.null(X_data) || ncol(X_data) == 0) {
					cbind(`(Intercept)` = 1, treatment = private$w)
				} else {
					cbind(`(Intercept)` = 1, treatment = private$w, X_data)
				}
				private$logbin_w_cache = private$w
				private$logbin_X_cov_cache = X_data
			}
			X_full = private$logbin_X_full_cache
			
			if (!private$harden) {
				ws_args = private$logbin_feasible_warm_start_args(X_full, private$get_backend_warm_start_args(ncol(X_full)))
				if (estimate_only) {
					res = tryCatch(
						fast_log_binomial_regression_cpp(
							X_full, private$y,
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default,
							estimate_only = TRUE
						),
						error = function(e) NULL
					)
					if (is.null(res)) return(NULL)
					res$beta_hat_T = as.numeric(res$b[2L])
					res$ssq_b_j = NA_real_
					res$ssq_b_2 = NA_real_
				} else {
					res = tryCatch(
						fast_log_binomial_regression_with_var_cpp(
							X_full, private$y, j = 2L,
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default
						),
						error = function(e) NULL
					)
					if (is.null(res)) return(NULL)
					res$j_treat = 2L
					res$beta_hat_T = as.numeric(res$b[2L])
					res$ssq_b_2 = res$ssq_b_j
				}
				if (!isTRUE(private$is_log_binomial_fit_reasonable(res, X_full, 2L))) {
					private$cache_nonestimable_estimate("log_binomial_fit_unavailable")
					private$cached_values$likelihood_test_context = NULL
					return(NULL)
				}
				private$best_X_colnames = setdiff(colnames(X_full), c("(Intercept)", "treatment"))
				private$cached_values$likelihood_test_context = list(
					X = X_full,
					j_treat = 2L,
					full_neg_loglik = res$neg_ll
				)
				edi_warn_binomial_mle_boundary_once(self, private, X_full, res$b, "log") # TODO-128: warning only, no numeric change
				return(res)
			}

			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L, # intercept and treatment
				fit_fun = function(X_fit, keep){
					j_treat = which(keep == 2L)
					ws_args = private$logbin_feasible_warm_start_args(X_fit, private$get_backend_warm_start_args(ncol(X_fit)))
					if (estimate_only) {
						res = tryCatch(
							fast_log_binomial_regression_cpp(
								X = X_fit, y = private$y,
								warm_start_beta = ws_args$warm_start_beta,
								warm_start_fisher_info = ws_args$warm_start_fisher_info,
								smart_cold_start = private$smart_cold_start_default
							),
							error = function(e) NULL
						)
						if (is.null(res)) return(NULL)
						list(b = res$b, beta_hat_T = as.numeric(res$b[j_treat]), ssq_b_j = NA_real_, j_treat = j_treat, fisher_information = res$fisher_information, neg_ll = res$neg_ll, converged = res$converged, mu_hat = res$mu_hat)
					} else {
						res = tryCatch(
							fast_log_binomial_regression_with_var_cpp(
								X = X_fit, y = private$y, j = j_treat,
								warm_start_beta = ws_args$warm_start_beta,
								warm_start_fisher_info = ws_args$warm_start_fisher_info,
								smart_cold_start = private$smart_cold_start_default
							),
							error = function(e) NULL
						)
						if (is.null(res)) return(NULL)
						res$j_treat = j_treat
						res$beta_hat_T = as.numeric(res$b[j_treat])
						res$ssq_b_2 = res$ssq_b_j
						res
					}
				},

				fit_ok = function(mod, X_fit, keep){
					j_treat = mod$j_treat
					if (!isTRUE(private$is_log_binomial_fit_reasonable(mod, X_fit, j_treat))) return(FALSE)
					if (estimate_only) return(TRUE)
					is.finite(mod$ssq_b_j %||% mod$ssq_b_2)
				}
			)
			if (!isTRUE(private$is_log_binomial_fit_reasonable(attempt$fit, attempt$X, attempt$fit$j_treat %||% match(2L, attempt$keep)))) {
				private$cache_nonestimable_estimate("log_binomial_fit_unavailable")
				private$cached_values$likelihood_test_context = NULL
				return(NULL)
			}
			if (!is.null(attempt$fit)){
				private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
				private$cached_values$likelihood_test_context = list(
					X = attempt$X,
					j_treat = attempt$fit$j_treat,
					full_neg_loglik = attempt$fit$neg_ll
				)
				edi_warn_binomial_mle_boundary_once(self, private, attempt$X, attempt$fit$b, "log") # TODO-128: warning only, no numeric change
			} else {
				private$cached_values$likelihood_test_context = NULL
			}
			attempt$fit
		},
		build_design_matrix = function(){
			X_data = private$get_X()
			if (is.null(X_data) || ncol(X_data) == 0) {
				cbind(`(Intercept)` = 1, treatment = private$w)
			} else {
				cbind(`(Intercept)` = 1, treatment = private$w, X_data)
			}
		}
	)
)

#' Log-Binomial Regression Inference for Incidence Responses
#'
#' Fits a binomial regression with the \strong{log} link for binary
#' (incidence) responses: \eqn{\log P(Y_i = 1) = \beta_0 + \beta_T W_i +
#' X_i^\top \gamma}, where \eqn{W_i} is the treatment indicator and \eqn{X_i}
#' are optional recorded covariates, by maximum likelihood
#' (\code{\link{fast_log_binomial_regression_cpp}}/
#' \code{\link{fast_log_binomial_regression_weighted_cpp}}). \eqn{\hat\beta_T}
#' is a \strong{log risk ratio}: \eqn{\exp(\hat\beta_T)} is the estimated
#' treatment risk ratio (relative risk) directly, unlike the log-odds-ratio
#' from \code{\link[EDI:InferenceIncidLogRegr]{InferenceIncidLogRegr}}'s logit
#' link. \code{likelihood_tier = "full"}: Wald, score, gradient, and
#' likelihood-ratio tests are all available when the model converges, plus
#' parametric-likelihood-bootstrap calibration of the likelihood-ratio test.
#' Because the log link does not constrain fitted probabilities to
#' \eqn{[0,1]} (only to \eqn{[0,\infty)}), fits are hardened by QR
#' column-dropping and a coefficient-magnitude cap
#' (\code{max_abs_reasonable_coef}) and rejected as nonestimable when the fit
#' is implausible — the same practical limitation as the identity-link
#' sibling \code{\link[EDI:InferenceIncidBinomialIdentityRiskDiff]{
#' InferenceIncidBinomialIdentityRiskDiff}}, here applying to the upper rather
#' than both tails of the probability scale. When the full-data MLE is on
#' that boundary (some fitted probability equal to 1), the object warns once
#' (\code{edi_binomial_mle_boundary_warning}) that Wald and score standard
#' errors and intervals may be unreliable. Validity requires the
#' multiplicative log-linear risk model to be correctly specified over the
#' covariate range observed.
#'
#' @references McCullagh, P., and Nelder, J. A. (1989). \emph{Generalized
#'   Linear Models} (2nd ed.). Chapman and Hall/CRC, for the binomial GLM
#'   family and log-link relative-risk parameterization.
#'
#' @seealso \code{\link[EDI:InferenceIncidLogRegr]{InferenceIncidLogRegr}}
#'   (logit link, log-odds-ratio estimand),
#'   \code{\link[EDI:InferenceIncidBinomialIdentityRiskDiff]{
#'   InferenceIncidBinomialIdentityRiskDiff}} (identity link, risk-difference
#'   estimand) for alternative link/estimand choices on the same response
#'   type. Comparable Python API:
#'   \href{https://www.statsmodels.org/stable/glm.html}{statsmodels GLM}
#'   (\code{family=Binomial(link=log())}). See also:
#'   \href{https://en.wikipedia.org/wiki/Generalized_linear_model}{Generalized
#'   linear model} (Wikipedia).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidLogBinomial$new(seq_des)
#' inf$compute_estimate()
#' }
#' @inheritSection InferenceContinOLS Blocking designs
#' @export
InferenceIncidLogBinomial = define_inference_class(
	classname = "InferenceIncidLogBinomial",
	inherit = Inference,
	components = c(
		"RandomizationCI",
		"RandomizationBootstrapCI",
		"BayesianBootstrap",
		"Jackknife",
		"ParametricLikelihoodBootstrap",
		"IncidenceLogBinomialLikelihood"
	),
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio"),
	overrides = list(
		public = c(
			"compute_estimate", "compute_rand_two_sided_pval",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"get_supported_testing_types", "set_testing_type", "compute_estimate_with_bootstrap_weights",
			"compute_score_confidence_interval", "compute_gradient_confidence_interval"
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
			"get_complexity_tier", "compute_gradient_confidence_interval_impl"
		)
	),
	public = list(
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval
	)
)


#' @R6method InferenceIncidLogBinomial$approximate_randomization_distribution_beta_hat_T
#' @template rand-approx-distribution-beta-hat-t
NULL

#' @R6method InferenceIncidLogBinomial$supports_rand_pval_for_incidence
#' @template rand-supports-pval-incidence
NULL


# TODO-181 LogBinomial leftover (v1.0.5): score and information for the score /
# gradient tests at a null-restricted fit on the exp(X b) <= 1 boundary.
#
# Only y = 1 rows can sit at mu = 1 (a y = 0 row there has log-likelihood
# -Inf). Their contribution y * eta is linear, so the analytic score
# X'(y - (1 - y) mu / (1 - mu)) and observed information
# X' diag((1 - y) mu / (1 - mu)^2) X are finite; the finite-difference ones
# (h = 1e-6 / 1e-4) step past the kernel's -1e-8 barrier for any row with
# eta >= -1e-4 and return -Inf / NaN.
#
# At a boundary point the nuisance score is not zero: it is the Kuhn-Tucker
# multiplier, s_n = X_{A,n}' lambda, lambda >= 0, over the binding rows A.
# lambda is fitted by nonnegative least squares over the rows within 1e-4 of
# the bound; rows with lambda > 0 are A. With A empty the point is interior
# and the analytic values are used as they are. Otherwise the score is the
# Lagrangian score g = s - X_A' lambda (nuisance part 0; tested part = the
# derivative of the profile log-likelihood, by the envelope theorem), and the
# information carries the face-restricted efficient information
# f = 1 / (c' (B' I B)^{-1} c) (B a basis of {d : X_A d = 0}, c = B' e_j) in
# the tested position with no cross terms. The generic
# score_j^2 / (I_jj - I_jn I_nn^{-1} I_nj) is then the Rao score test of the
# model with the binding constraints held as equalities, which equals the
# profile score test l_p'(delta)^2 / (-l_p''(delta)) (the interior statistic's
# continuous extension), and the gradient statistic g_j (beta_hat_j - delta)
# equals g' (beta_hat - beta_tilde). Returns NULL for a fit with no row within
# 1e-4 of the bound: the caller keeps the finite-difference values.
edi_log_binomial_kkt_terms = function(X, y, b, j){
	eta = as.numeric(X %*% b)
	if (any(!is.finite(eta))) return(NULL)
	C = which(eta >= -1e-4)
	if (!length(C)) return(NULL)
	undefined = function(why) list(reason = paste0(
		"the null-restricted MLE is on the boundary of the parameter space (fitted probability exp(X b) = 1) and ",
		why, "; the score and gradient tests are not computed there (the likelihood-ratio test is)"))
	eta0 = pmin(eta, 0)
	mu = exp(eta0)
	one_minus = -expm1(eta0)
	y0 = y < 0.5
	if (any(y0 & one_minus <= 0)) return(undefined("a subject with y = 0 is on it (log-likelihood -Inf)"))
	s = as.numeric(crossprod(X, ifelse(y0, -mu / one_minus, 1)))
	I = unname(crossprod(X, X * ifelse(y0, mu / one_minus^2, 0)))
	# constraint eta_i <= 0: outward normal +x_i
	edi_binomial_bound_kkt_core(X, b, j, s, I, C, rep(1, length(C)), undefined)
}

# Shared by InferenceIncidLogBinomial and InferenceIncidBinomialIdentityRiskDiff
# (TODO-181 leftover, v1.0.5). Given the analytic score s and information I at
# b, the candidate rows C near a bound and the sign of each row's outward
# constraint normal (g_i(b) = sgn_i x_i' b - const <= 0), returns the
# Lagrangian score and face-restricted information described above, the
# plain analytic s / I when no candidate row binds, or list(reason = ...)
# (with not_kkt = TRUE when b is not a Kuhn-Tucker point).
edi_binomial_bound_kkt_core = function(X, b, j, s, I, C, sgn, undefined){
	nj = setdiff(seq_along(b), j)
	S = X[C, , drop = FALSE] * sgn
	# nonnegative least squares s_n ~ S_{C,n}' lambda (small active-set loop)
	keep = seq_along(C)
	lambda = numeric(0)
	for (it in seq_len(length(C) + 1L)) {
		if (!length(keep)) break
		lam = tryCatch(qr.solve(t(S[keep, nj, drop = FALSE]), s[nj]), error = function(e) NULL)
		if (is.null(lam) || any(!is.finite(lam))) return(undefined("its Kuhn-Tucker multipliers are not identified"))
		tol = 1e-8 * max(1, abs(s))
		if (all(lam > tol)) { lambda = lam; break }
		keep = keep[lam > tol]
	}
	A = if (length(lambda)) keep else integer(0)
	if (!length(A)) return(list(score = s, info = I, boundary = FALSE))
	SA = S[A, , drop = FALSE]
	resid = s[nj] - as.numeric(crossprod(SA[, nj, drop = FALSE], lambda))
	if (sqrt(sum(resid^2)) > 1e-3 * (1 + sqrt(sum(s[nj]^2)))) return(c(undefined("it is not a Kuhn-Tucker point"), list(not_kkt = TRUE)))
	g = s - as.numeric(crossprod(SA, lambda))
	g[nj] = 0
	B = tryCatch(MASS::Null(t(SA)), error = function(e) NULL)
	if (is.null(B) || !ncol(B)) return(undefined("the binding constraints fix every coefficient"))
	cc = B[j, ]
	v = tryCatch(solve(crossprod(B, I %*% B), cc), error = function(e) NULL)
	f = if (is.null(v)) NA_real_ else 1 / sum(cc * v)
	if (!is.finite(f) || f <= 0) return(undefined("the information on the binding face is singular"))
	J = I
	J[j, ] = 0
	J[, j] = 0
	J[j, j] = f
	list(score = g, info = J, boundary = TRUE, n_binding = length(A))
}

# TODO-190 (v1.0.5): InferenceIncidLogBinomial's gradient CI returns the
# likelihood-ratio interval when gradient inversion yields no usable interval
# (in calibration: n = 50 `~.` fits whose MLE has a y = 1 row at exp(X b) = 1,
# where the gradient test at delta = estimate is undefined). Records the reason
# in cached_values$ci_fallback_reason["gradient"] (first reason wins, as for the
# Wald fallback) and warns once per object with class
# edi_lik_ci_lik_ratio_fallback (fields testing_type = "gradient", substitute,
# reason); never inside a resampling worker. The interval is not changed.
edi_warn_log_binomial_gradient_ci_lik_ratio_substitution_once = function(self, private){
	cv = private$cached_values
	if (is.null(cv)) return(invisible(FALSE))
	fail = unname((cv$likelihood_test_failure_reason %||% character())["gradient"])
	proc = cv$procedure_failure_reason[["gradient"]] %||% NA_character_
	why = if (length(fail) == 1L && !is.na(fail) && nzchar(fail)) fail else if (!is.na(proc)) proc else "the root search returned no usable bounds"
	lr_wald = unname((cv$ci_fallback_reason %||% character())["lik_ratio"])
	substitute = if (length(lr_wald) == 1L && !is.na(lr_wald)) "wald" else "lik_ratio"
	reason = paste0("gradient test inversion gave no usable interval (", why, "), so the likelihood-ratio interval was returned",
		if (identical(substitute, "wald")) paste0(", which is itself the Wald interval (", lr_wald, ")") else "")
	rec = cv$ci_fallback_reason %||% character()
	if (!("gradient" %in% names(rec))) {
		rec["gradient"] = reason
		private$cached_values$ci_fallback_reason = rec
	}
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	if (isTRUE(cv$lik_ci_lik_ratio_fallback_warned)) return(invisible(FALSE))
	private$cached_values$lik_ci_lik_ratio_fallback_warned = TRUE
	warning(structure(
		class = c("edi_lik_ci_lik_ratio_fallback", "warning", "condition"),
		list(
			message = paste0(
				class(self)[1L], ": the gradient confidence interval could not be obtained by test inversion (", why, "), ",
				"so the returned interval is the ", if (identical(substitute, "wald")) "Wald interval (the likelihood-ratio inversion also fell back)" else "likelihood-ratio interval",
				", NOT a gradient interval. Use compute_lik_ratio_confidence_interval() explicitly if that is what you want. ",
				"Suppress with suppressWarnings(expr, classes = \"edi_lik_ci_lik_ratio_fallback\")."
			),
			call = NULL,
			testing_type = "gradient",
			substitute = substitute,
			reason = reason
		)
	))
	invisible(TRUE)
}

edi_log_binomial_neg_loglik = function(X, y, b){
	eta = as.numeric(X %*% as.numeric(b))
	if (any(!is.finite(eta)) || any(eta > 0)) return(Inf)
	-sum(y * eta + (1 - y) * log1p(-exp(eta)))
}

edi_log_binomial_lik_test_score = function(X, y, b, j, private){
	s = get_log_binomial_regression_score_cpp(X, y, b)
	kkt = edi_log_binomial_kkt_terms(X, y, b, j)
	if (is.null(kkt) || (!isTRUE(kkt$boundary) && is.null(kkt$reason) && all(is.finite(s)))) return(s)
	if (!is.null(kkt$reason)) {
		edi_note_lik_test_failure(private, "score", kkt$reason)
		edi_note_lik_test_failure(private, "gradient", kkt$reason)
		return(rep(NA_real_, length(b)))
	}
	kkt$score
}

edi_log_binomial_lik_test_information = function(X, y, b, j){
	info = -get_log_binomial_regression_hessian_cpp(X, y, b)
	kkt = edi_log_binomial_kkt_terms(X, y, b, j)
	if (is.null(kkt) || (!isTRUE(kkt$boundary) && is.null(kkt$reason) && all(is.finite(info)))) return(info)
	if (!is.null(kkt$reason)) return(matrix(NA_real_, length(b), length(b)))
	kkt$info
}
