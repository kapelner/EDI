#' Partial Proportional-Odds Regression Inference for Ordinal Responses
#'
#' @name InferenceOrdinalPartialProportionalOddsRegr
#' @description Fits a \strong{partial} proportional-odds cumulative-logit model
#' for an ordinal response: a subset of covariates named in \code{nonparallel}
#' are allowed a separate coefficient at each cumulative threshold (relaxing the
#' proportional-odds/parallel-lines assumption for exactly those covariates),
#' while every other covariate — including the \strong{treatment} indicator,
#' which is \emph{always} fit as a parallel (proportional) term regardless of
#' \code{nonparallel} — keeps one shared coefficient across all thresholds. The
#' reported treatment effect is therefore always a single proportional
#' (threshold-invariant) log-odds shift, even when other covariates' effects
#' are allowed to vary by threshold. When \code{nonparallel} is empty, fitting
#' uses this package's fast Rcpp full-proportional-odds solver
#' (\code{\link{fast_ordinal_regression_with_var_cpp}}); otherwise it falls back,
#' in order, to \code{VGAM::vglm(family = VGAM::cumulative(parallel = ...))},
#' \code{ordinal::clm(nominal = ...)}, and (only when \code{nonparallel} is
#' empty and the earlier fast/VGAM/clm attempts failed) \code{MASS::polr}. Each
#' fallback requires its corresponding package to be installed; unavailable
#' packages are silently skipped in favor of the next fallback.
#'
#' @references Peterson, B., and Harrell, F. E. (1990). "Partial Proportional
#'   Odds Models for Ordinal Response Variables." \emph{Journal of the Royal
#'   Statistical Society, Series C (Applied Statistics)}, 39(2), 205-217,
#'   \doi{10.2307/2347760}, for the partial (non-parallel-covariate)
#'   proportional-odds model fit here. McCullagh, P. (1980). "Regression
#'   Models for Ordinal Data." \emph{Journal of the Royal Statistical
#'   Society, Series B}, 42(2), 109-142,
#'   \doi{10.1111/j.2517-6161.1980.tb01109.x}, for the full proportional-odds
#'   model this generalizes (see
#'   \code{\link[EDI:InferenceOrdinalPropOddsRegr]{InferenceOrdinalPropOddsRegr}}).
#' @export
InferenceOrdinalPartialProportionalOddsRegr = define_inference_class(
	classname = "InferenceOrdinalPartialProportionalOddsRegr",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald"),
	public = list(
		#' @description Uses the shared randomization two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceRand]{InferenceRand}}.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize partial proportional-odds ordinal regression
		#'   inference for a completed design with an ordinal, uncensored response.
		#' @param des_obj A completed \code{DesignSeqOneByOne} object with an ordinal
		#'   response.
		#' @param nonparallel Names of covariates (not including \code{"treatment"},
		#'   which is always fit as a parallel/proportional term) allowed a separate
		#'   coefficient at each cumulative threshold, relaxing the proportional-odds
		#'   assumption for those covariates specifically.
		#' @param model_formula Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values by default.
		#' @param harden Whether to apply robustness measures.
		initialize = function(des_obj, verbose = FALSE, harden = TRUE, model_formula = NULL, nonparallel = character(0), smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "ordinal")
			}
			super$initialize(des_obj, verbose = verbose, harden = harden, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
				assertCharacter(nonparallel, null.ok = TRUE)
			}
			private$nonparallel = unique(nonparallel)
		},

		#' @description Retrieves the estimated (always-parallel) treatment
		#'   log-odds shift from the partial proportional-odds fit (see class
		#'   documentation for the fitting backend cascade).
		#'
		#' @return The estimated treatment effect.
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the partial-proportional-odds treatment estimate
		#'   under subject/block bootstrap weights, used by the Bayesian bootstrap
		#'   and related weighted-resampling machinery. If the weights are
		#'   effectively constant, short-circuits to the unweighted
		#'   \code{$compute_estimate(estimate_only = TRUE)}. Otherwise refits with
		#'   weights via the same backend cascade as the unweighted fit
		#'   (\code{VGAM}/\code{ordinal}/\code{MASS::polr}, each weighted), and if
		#'   \strong{all} of those fail, falls back further to a plain weighted
		#'   binary-logistic surrogate fit
		#'   (\code{weighted_ordinal_bootstrap_surrogate_fit(..., method =
		#'   "logistic")}) that does not model the ordinal structure at all. Never
		#'   computes a standard error on any weighted path (\code{s_beta_hat_T} is
		#'   always \code{NA}), regardless of \code{estimate_only}.
		#' @param subject_or_block_weights Subject-, block-, cluster-, or matched-set
		#'   bootstrap weights.
		#' @param estimate_only Present for interface parity; this method never
		#'   computes variance components regardless of its value.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			if (weights_are_effectively_constant(row_weights)) {
				beta_hat_T = as.numeric(self$compute_estimate(estimate_only = TRUE))[1L]
				if (is.finite(beta_hat_T)) {
					private$cached_values$beta_hat_T = beta_hat_T
					private$cached_values$s_beta_hat_T = NA_real_
					return(private$cached_values$beta_hat_T)
				}
			}
			X_cov = private$ppo_covariate_matrix()
			fit = private$fit_partial_proportional_odds_from_covariates_weighted(X_cov, row_weights)
			private$cached_values$beta_hat_T = if (is.null(fit)) NA_real_ else as.numeric(fit$beta)
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$beta_hat_T
		},

			#' @description Computes a Wald-style confidence interval for the
			#'   treatment log-odds shift, using the model-based standard error
			#'   from whichever backend (fast Rcpp solver, \code{VGAM},
			#'   \code{ordinal}, or \code{MASS::polr}) successfully fit the
			#'   unweighted model (see class documentation). If that standard
			#'   error is unavailable (\code{NA}, non-finite, or 0) — e.g. because
			#'   the fit succeeded via a fallback path that doesn't report one —
			#'   the interval is explicitly marked non-estimable
			#'   (\code{c(NA, NA)}) when \code{private$harden} is \code{TRUE}, or
			#'   raises an error otherwise, rather than silently returning a
			#'   misleading result. Identical to \code{$compute_wald_confidence_interval()}.
			#' @param alpha Significance level for the interval.
			#'
			#' @return A confidence interval for the treatment effect.
			compute_asymp_confidence_interval = function(alpha = 0.05){
				if (should_run_asserts()) {
					assertNumeric(
						alpha,
						lower = .Machine$double.xmin,
						upper = 1 - .Machine$double.xmin
					)
				}
				private$shared()
				if (!private$has_finite_se()){
					return(private$missing_asymp_ci(alpha))
				}
				private$compute_z_or_t_ci_from_s_and_df(alpha)
			},

			#' @description Computes a Wald-style two-sided p-value testing
			#'   \eqn{H_0: \beta_T = \code{delta}}, using the same model-based
			#'   standard error as \code{$compute_asymp_confidence_interval()}; if
			#'   unavailable, marked non-estimable (\code{NA}) or an error is
			#'   raised, per \code{private$harden} — see that method's
			#'   documentation. Identical to \code{$compute_wald_two_sided_pval()}.
			#' @param delta Null treatment effect to test.
			#'
			#' @return A two-sided p-value.
			compute_asymp_two_sided_pval = function(delta = 0){
				if (should_run_asserts()) {
					assertNumeric(delta)
				}
				private$shared()
				if (!private$has_finite_se()){
					return(private$missing_asymp_pval())
				}
				private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
			},
			#' @description Identical to \code{$compute_asymp_confidence_interval()};
			#'   provided as an explicit alias for callers that want to name the
			#'   Wald method directly rather than via the generic "asymptotic"
			#'   dispatch.
			#' @param alpha Significance level for the interval.
			#'
			#' @return A confidence interval for the treatment effect.
			compute_wald_confidence_interval = function(alpha = 0.05){
				if (should_run_asserts()) {
					assertNumeric(
						alpha,
						lower = .Machine$double.xmin,
						upper = 1 - .Machine$double.xmin
					)
				}
				private$shared()
				if (!private$has_finite_se()){
					return(private$missing_asymp_ci(alpha))
				}
				private$compute_z_or_t_ci_from_s_and_df(alpha)
			},

			#' @description Identical to \code{$compute_asymp_two_sided_pval()};
			#'   provided as an explicit alias for callers that want to name the
			#'   Wald method directly rather than via the generic "asymptotic"
			#'   dispatch.
			#' @param delta Null treatment effect to test.
			#'
			#' @return A two-sided p-value.
			compute_wald_two_sided_pval = function(delta = 0){
				if (should_run_asserts()) {
					assertNumeric(delta)
				}
				private$shared()
				if (!private$has_finite_se()){
					return(private$missing_asymp_pval())
				}
				private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
			},

		#' @description Diagnostic helper for performance investigation: runs the
		#'   same computation as \code{$compute_asymp_two_sided_pval()} (fit the
		#'   partial proportional-odds model requiring a standard error, cache the
		#'   estimate/SE/df, compute the two-sided Wald p-value) but separately
		#'   times each of the three stages — model fit, cache materialization, and
		#'   final p-value arithmetic — via \code{proc.time()}. If the fit fails or
		#'   has no usable standard error, returns immediately with only
		#'   \code{fit_time} populated and every other timing/result field
		#'   \code{NA}.
		#'
		#' @param delta Null treatment effect to test.
		#'
		#' @return A named list: \code{fit_time}, \code{cache_time},
		#'   \code{pval_math_time}, \code{total_time} (all in seconds), \code{pval},
		#'   \code{beta_hat_T}, and \code{s_beta_hat_T}.
		benchmark_asymp_two_sided_pval_breakdown = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta)
				}

				t0 = proc.time()[["elapsed"]]
				fit = private$fit_partial_proportional_odds(require_se = TRUE)
				fit_time = round(proc.time()[["elapsed"]] - t0, 6)

				if (is.null(fit) || !private$ppo_fit_is_usable(fit, require_se = TRUE)){
					return(list(
						fit_time = fit_time,
						cache_time = NA_real_,
						pval_math_time = NA_real_,
						total_time = fit_time,
						pval = NA_real_,
						beta_hat_T = NA_real_,
						s_beta_hat_T = NA_real_
					))
				}

			t1 = proc.time()[["elapsed"]]
			private$cached_values$beta_hat_T = fit$beta
			private$cached_values$s_beta_hat_T = fit$se
			private$cached_values$df = private$n - 1
			cache_time = round(proc.time()[["elapsed"]] - t1, 6)

			t2 = proc.time()[["elapsed"]]
			pval = private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
			pval_math_time = round(proc.time()[["elapsed"]] - t2, 6)

			list(
				fit_time = fit_time,
				cache_time = cache_time,
				pval_math_time = pval_math_time,
				total_time = round(fit_time + cache_time + pval_math_time, 6),
				pval = pval,
				beta_hat_T = private$cached_values$beta_hat_T,
				s_beta_hat_T = private$cached_values$s_beta_hat_T
			)
		}
	),
	private = list(
		nonparallel = character(0),

		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			if (is.null(private$best_X_colnames)){
				private$shared(estimate_only = TRUE)
			}
			if (is.null(private$best_X_colnames)){
				return(self$compute_estimate(estimate_only = estimate_only))
			}

			X_cols = private$best_X_colnames
			X_data = private$get_X()

			X_cov = if (length(X_cols) == 0L){
				matrix(0, nrow = private$n, ncol = 0)
			} else {
				X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
			}

			fit = private$fit_partial_proportional_odds_from_covariates(X_cov)
			if (is.null(fit) || !is.finite(fit$beta)){
				return(NA_real_)
			}
			as.numeric(fit$beta)
		},

		ppo_covariate_matrix = function(){
			X_cov = private$get_X()
			if (is.null(X_cov) || length(X_cov) == 0L) {
				return(matrix(0, nrow = private$n, ncol = 0))
			}
			as.matrix(X_cov)
		},

			shared = function(estimate_only = FALSE){
				if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
				if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))

				fit = private$fit_partial_proportional_odds(require_se = !estimate_only)
				if (is.null(fit) || !is.finite(fit$beta)){
					if (!estimate_only) {
						estimate_fit = private$fit_partial_proportional_odds(require_se = FALSE)
						if (!is.null(estimate_fit) && is.finite(estimate_fit$beta)) {
							private$cached_values$beta_hat_T = estimate_fit$beta
							private$cached_values$df = private$n - 1
							private$cache_nonestimable_se("ppor_standard_error_unavailable")
						} else {
							private$cache_nonestimable_estimate("ppor_fit_unavailable")
							private$cached_values$df = private$n - 1
						}
					} else {
						private$cache_nonestimable_estimate("ppor_fit_unavailable")
					}
					return(invisible(NULL))
				}

				private$cached_values$beta_hat_T = fit$beta
				private$cached_values$s_beta_hat_T = fit$se
				private$cached_values$df = private$n - 1
				if (!estimate_only && !private$has_finite_se()) {
					private$cache_nonestimable_se("ppor_standard_error_unavailable")
				} else {
					private$clear_nonestimable_state()
				}
			},

		has_finite_se = function(){
			is.finite(private$cached_values$s_beta_hat_T) &&
				private$cached_values$s_beta_hat_T > 0
		},
		get_standard_error = function(){
			private$shared(estimate_only = FALSE)
			private$cached_values$s_beta_hat_T %||% NA_real_
		},
		get_degrees_of_freedom = function(){
			private$shared(estimate_only = FALSE)
			private$cached_values$df %||% NA_real_
		},

			missing_asymp_pval = function(reason = "ppor_standard_error_unavailable"){
				if (isTRUE(private$harden)) {
					private$cache_nonestimable_se(reason)
					return(NA_real_)
				}
				stop("Partial proportional-odds regression could not compute a finite model-based standard error.", call. = FALSE)
			},

			missing_asymp_ci = function(alpha = 0.05, reason = "ppor_standard_error_unavailable"){
				if (isTRUE(private$harden)) {
					private$cache_nonestimable_se(reason)
					ci = c(NA_real_, NA_real_)
					names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
					return(ci)
				}
				stop("Partial proportional-odds regression could not compute a finite model-based standard error.", call. = FALSE)
			},

			fit_partial_proportional_odds = function(require_se = FALSE){
				X_cov = private$ppo_covariate_matrix()
				X_full = cbind(treatment = private$w, X_cov)
				attempt = private$fit_with_hardened_qr_column_dropping(
					X_full = X_full,
					required_cols = 1L,
					fit_fun = function(X_fit){
						X_cov_fit = X_fit[, -1, drop = FALSE]
						private$fit_partial_proportional_odds_from_covariates(X_cov_fit, require_se = require_se)
					},
					fit_ok = function(fit, X_fit, keep){
						private$ppo_fit_is_usable(fit, require_se = require_se)
					}
				)
				if (!private$ppo_fit_is_usable(attempt$fit, require_se = require_se)) return(NULL)
				if (!is.null(attempt$fit)){
					private$best_X_colnames = setdiff(colnames(attempt$X_fit), "treatment")
				}
				attempt$fit
			},

			ppo_fit_is_usable = function(fit, require_se = FALSE){
				!is.null(fit) &&
					is.finite(fit$beta) &&
					(!isTRUE(require_se) || (is.finite(fit$se) && fit$se > 0))
			},

			fit_partial_proportional_odds_from_covariates = function(X_cov, require_se = FALSE){
				covar_names = colnames(X_cov)
				if (is.null(covar_names)) covar_names = character(0)
				nonparallel_covars = intersect(private$nonparallel, covar_names)
				parallel_covars = setdiff(covar_names, nonparallel_covars)

				if (length(nonparallel_covars) == 0){
					fit = private$fit_fast_proportional_odds(X_cov)
					if (private$ppo_fit_is_usable(fit, require_se = require_se)) return(fit)
				}

			dat = data.frame(
				y = ordered(private$y, levels = sort(unique(private$y))),
				treatment = private$w,
				as.data.frame(X_cov, check.names = FALSE),
				check.names = FALSE
			)
			if (nlevels(dat$y) < 2) return(NULL)

				fit = private$fit_vgam(dat, parallel_covars, nonparallel_covars)
				if (private$ppo_fit_is_usable(fit, require_se = require_se)) return(fit)

				fit = private$fit_clm(dat, parallel_covars, nonparallel_covars)
				if (private$ppo_fit_is_usable(fit, require_se = require_se)) return(fit)

				fit = private$fit_polr(dat, parallel_covars, nonparallel_covars)
				if (private$ppo_fit_is_usable(fit, require_se = require_se)) return(fit)

				NULL
			},
		fit_partial_proportional_odds_from_covariates_weighted = function(X_cov, row_weights){
			covar_names = colnames(X_cov)
			if (is.null(covar_names)) covar_names = character(0)
			nonparallel_covars = intersect(private$nonparallel, covar_names)
			parallel_covars = setdiff(covar_names, nonparallel_covars)
			if (length(nonparallel_covars) == 0){
				fit = private$fit_fast_proportional_odds_weighted(X_cov, row_weights)
				if (!is.null(fit)) return(fit)
			}
			dat = data.frame(
				y = ordered(private$y, levels = sort(unique(private$y))),
				treatment = private$w,
				as.data.frame(X_cov, check.names = FALSE),
				.bootstrap_weight__ = as.numeric(row_weights),
				check.names = FALSE
			)
			ok = is.finite(dat$.bootstrap_weight__) & dat$.bootstrap_weight__ > 0
			dat = dat[ok, , drop = FALSE]
			if (nrow(dat) == 0L || nlevels(dat$y) < 2) return(NULL)
			fit = private$fit_vgam_weighted(dat, parallel_covars, nonparallel_covars)
			if (!is.null(fit)) return(fit)
			fit = private$fit_clm_weighted(dat, parallel_covars, nonparallel_covars)
			if (!is.null(fit)) return(fit)
			fit = private$fit_polr_weighted(dat, parallel_covars, nonparallel_covars)
			if (!is.null(fit)) return(fit)
			sur = weighted_ordinal_bootstrap_surrogate_fit(
				X = cbind(treatment = dat$treatment, as.matrix(dat[, setdiff(colnames(dat), c("y", "treatment", ".bootstrap_weight__")), drop = FALSE])),
				y = as.integer(dat$y),
				row_weights = dat$.bootstrap_weight__,
				method = "logistic"
			)
			if (is.null(sur)) return(NULL)
			list(beta = as.numeric(sur$beta_hat), se = NA_real_)
		},

		fit_fast_proportional_odds = function(X_cov){
			X_fit = cbind(treatment = private$w, X_cov)
			if (is.null(dim(X_fit))){
				X_fit = matrix(X_fit, ncol = 1)
				colnames(X_fit) = "treatment"
			}
			
			start_len = ncol(X_fit) + nlevels(ordered(private$y)) - 1L
			res = tryCatch(
				fast_ordinal_regression_with_var_cpp(
					X = X_fit,
					y = as.numeric(private$y),
					warm_start_params = private$get_fit_warm_start_for_length("params", start_len),
					warm_start_fisher_info = private$get_fit_warm_start_fisher(start_len)
				),
				error = function(e) NULL
			)
			if (is.null(res) || length(res$b) < 1 || !is.finite(res$b[1]) || (isTRUE(private$harden) && !is.null(res$converged) && !res$converged)){
				return(NULL)
			}
			private$set_fit_warm_start(as.numeric(res$params), "params", fisher = res$fisher_information)

			se_beta = if (is.finite(res$ssq_b_j) && res$ssq_b_j > 0) {
				sqrt(res$ssq_b_j)
			} else {
				NA_real_
			}

			list(beta = as.numeric(res$b[1]), se = se_beta)
		},
		fit_fast_proportional_odds_weighted = function(X_cov, row_weights){
			X_fit = cbind(treatment = private$w, X_cov)
			if (is.null(dim(X_fit))){
				X_fit = matrix(X_fit, ncol = 1)
				colnames(X_fit) = "treatment"
			}
			ok = is.finite(row_weights) & row_weights > 0 & is.finite(as.numeric(private$y))
			if (!any(ok)) return(NULL)
			X_fit = X_fit[ok, , drop = FALSE]
			y_fit = as.numeric(private$y[ok])
			w_fit = as.numeric(row_weights[ok])
			start_len = ncol(X_fit) + length(sort(unique(y_fit))) - 1L
			res = tryCatch(
				fast_ordinal_regression_weighted_cpp(
					X = X_fit,
					y = y_fit,
					weights = w_fit,
					warm_start_params = private$get_fit_warm_start_for_length("params", start_len),
					warm_start_fisher_info = private$get_fit_warm_start_fisher(start_len)
				),
				error = function(e) NULL
			)
			if (is.null(res) || length(res$b) < 1 || !is.finite(res$b[1])) return(NULL)
			list(beta = as.numeric(res$b[1]), se = NA_real_)
		},

		main_formula = function(term_names){
			stats::reformulate(termlabels = term_names, response = "y")
		},

		parallel_formula = function(term_names){
			stats::reformulate(termlabels = term_names)
		},

		extract_common_treatment_fit = function(mod, coef_getter, vcov_getter){
			coefs = tryCatch(coef_getter(mod), error = function(e) NULL)
			if (is.null(coefs) || !"treatment" %in% names(coefs)) return(NULL)

			beta_hat = as.numeric(coefs[["treatment"]])
			var_beta = tryCatch(
				vcov_getter(mod)["treatment", "treatment"],
				error = function(e) NA_real_
			)
			se_beta = if (is.finite(var_beta) && var_beta > 0) sqrt(var_beta) else NA_real_

			list(beta = beta_hat, se = se_beta)
		},

		fit_vgam = function(dat, parallel_covars, nonparallel_covars){
			if (!check_package_installed("VGAM")) return(NULL)

			all_terms = unique(c("treatment", parallel_covars, nonparallel_covars))
			par_terms = unique(c("treatment", parallel_covars))

			mod = tryCatch(
				suppressWarnings(
					VGAM::vglm(
						formula = private$main_formula(all_terms),
						family = VGAM::cumulative(
							link = "logitlink",
							parallel = private$parallel_formula(par_terms)
						),
						data = dat,
						trace = FALSE,
						model = FALSE
					)
				),
				error = function(e) NULL
			)
			if (is.null(mod)) return(NULL)

			private$extract_common_treatment_fit(
				mod,
				coef_getter = VGAM::Coef,
				vcov_getter = VGAM::vcov
			)
		},
		fit_vgam_weighted = function(dat, parallel_covars, nonparallel_covars){
			if (!check_package_installed("VGAM")) return(NULL)
			all_terms = unique(c("treatment", parallel_covars, nonparallel_covars))
			par_terms = unique(c("treatment", parallel_covars))
			mod = tryCatch(
				suppressWarnings(
					VGAM::vglm(
						formula = private$main_formula(all_terms),
						family = VGAM::cumulative(link = "logitlink", parallel = private$parallel_formula(par_terms)),
						data = dat,
						weights = .bootstrap_weight__,
						trace = FALSE,
						model = FALSE
					)
				),
				error = function(e) NULL
			)
			if (is.null(mod)) return(NULL)
			out = private$extract_common_treatment_fit(mod, coef_getter = VGAM::Coef, vcov_getter = VGAM::vcov)
			if (is.null(out)) return(NULL)
			out$se = NA_real_
			out
		},

		fit_clm = function(dat, parallel_covars, nonparallel_covars){
			if (!check_package_installed("ordinal")) return(NULL)

			main_terms = unique(c("treatment", parallel_covars))
			nominal_form = if (length(nonparallel_covars) == 0) {
				NULL
			} else {
				stats::reformulate(termlabels = nonparallel_covars)
			}

			mod = tryCatch(
				suppressWarnings(
					ordinal::clm(
						formula = private$main_formula(main_terms),
						nominal = nominal_form,
						data = dat,
						link = "logit",
						Hess = TRUE
					)
				),
				error = function(e) NULL
			)
			if (is.null(mod)) return(NULL)

			private$extract_common_treatment_fit(
				mod,
				coef_getter = stats::coef,
				vcov_getter = stats::vcov
			)
		},
		fit_clm_weighted = function(dat, parallel_covars, nonparallel_covars){
			if (!check_package_installed("ordinal")) return(NULL)
			main_terms = unique(c("treatment", parallel_covars))
			nominal_form = if (length(nonparallel_covars) == 0) NULL else stats::reformulate(termlabels = nonparallel_covars)
			mod = tryCatch(
				suppressWarnings(
					ordinal::clm(
						formula = private$main_formula(main_terms),
						nominal = nominal_form,
						data = dat,
						link = "logit",
						weights = dat$.bootstrap_weight__,
						Hess = FALSE
					)
				),
				error = function(e) NULL
			)
			if (is.null(mod)) return(NULL)
			out = private$extract_common_treatment_fit(mod, coef_getter = stats::coef, vcov_getter = stats::vcov)
			if (is.null(out)) return(NULL)
			out$se = NA_real_
			out
		},

		fit_polr = function(dat, parallel_covars, nonparallel_covars){
			if (length(nonparallel_covars) > 0) return(NULL)
			main_terms = unique(c("treatment", parallel_covars))
			mod = tryCatch(
				suppressWarnings(
					MASS::polr(
						formula = private$main_formula(main_terms),
						data = dat,
						method = "logistic",
						Hess = TRUE
					)
				),
				error = function(e) NULL
			)
			if (is.null(mod)) return(NULL)

			private$extract_common_treatment_fit(
				mod,
				coef_getter = stats::coef,
				vcov_getter = stats::vcov
			)
		},
		fit_polr_weighted = function(dat, parallel_covars, nonparallel_covars){
			if (length(nonparallel_covars) > 0) return(NULL)
			main_terms = unique(c("treatment", parallel_covars))
			mod = tryCatch(
				suppressWarnings(
					MASS::polr(
						formula = private$main_formula(main_terms),
						data = dat,
						method = "logistic",
						weights = dat$.bootstrap_weight__,
						Hess = FALSE
					)
				),
				error = function(e) NULL
			)
			if (is.null(mod)) return(NULL)
			out = private$extract_common_treatment_fit(mod, coef_getter = stats::coef, vcov_getter = stats::vcov)
			if (is.null(out)) return(NULL)
			out$se = NA_real_
			out
		}
	),
	overrides = list(
		public = c(
			"compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"compute_wald_confidence_interval", "compute_wald_two_sided_pval",
			"compute_rand_two_sided_pval"
		),
		private = c(
			"get_standard_error", "get_degrees_of_freedom",
			"compute_treatment_estimate_during_randomization_inference",
			"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker", "create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker", "compute_bootstrap_worker_estimate"
		)
	),
	metadata = list(likelihood_tier = "none")
)
