#' Identity-link binomial regression component source
#'
#' Source list for the \code{IncidenceBinomialIdentityLikelihood} component composed by \code{InferenceIncidBinomialIdentityRiskDiff}.
#'
#' @keywords internal
IncidenceBinomialIdentityLikelihoodSource = list(
	public = list(

		#' @description Initialize inference for the identity-link binomial risk-
		#'   difference model \eqn{P(Y_i = 1) = \beta_0 + \beta_T W_i + X_i^\top
		#'   \gamma}; see \code{\link[EDI:InferenceIncidBinomialIdentityRiskDiff]{
		#'   InferenceIncidBinomialIdentityRiskDiff}} for the model form. Does not
		#'   fit the model; the fit is deferred to the first call to
		#'   \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with an incidence response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose  		Whether to print progress messages.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Refits the identity-link binomial model with subject/block-level
		#'   weights applied to the fitting log-likelihood (Bayesian-bootstrap or
		#'   nonparametric-bootstrap draw weights, expanded to row level via
		#'   \code{private$expand_subject_or_block_weights_to_row_weights()}) via
		#'   \code{\link{fast_identity_binomial_regression_weighted_cpp}}, and returns
		#'   the reweighted risk-difference estimate \eqn{\hat\beta_T^{(w)}}. Uses the
		#'   same QR column-dropping hardening and fit-reasonableness check as
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
					# v1.0.6-TODO-146: refit cold when the warm-started fit stalls.
					res = private$fit_identity_binomial_warm_then_cold(function(warm){
						fast_identity_binomial_regression_weighted_cpp(
							X = X_fit,
							y = as.numeric(private$y),
							weights = as.numeric(row_weights),
							warm_start_beta = if (warm) private$get_fit_warm_start_for_length("beta", ncol(X_fit)) else NULL,
							warm_start_fisher_info = if (warm) private$get_fit_warm_start_fisher(ncol(X_fit)) else NULL
						)
					})
					if (is.null(res)) return(NULL)
					res$j_treat = j_treat
					res$beta_hat_T = as.numeric(res$b[j_treat])
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
					if (!isTRUE(private$is_identity_binomial_fit_reasonable(mod, X_fit, j_treat))) return(FALSE)
					TRUE
				}
			)
			private$cached_mod = attempt$fit
			j_treat = match(2L, attempt$keep)
			if (!isTRUE(private$is_identity_binomial_fit_reasonable(attempt$fit, attempt$X, j_treat))){
				private$cached_mod = NULL
				private$cache_nonestimable_estimate("binomial_identity_weighted_fit_unavailable")
				return(NA_real_)
			}
			private$set_fit_warm_start(attempt$fit$b, "beta", fisher = attempt$fit$fisher_information, force_pd = TRUE)
			private$cached_values$beta_hat_T = as.numeric(attempt$fit$b[j_treat])
			ssq = attempt$fit$ssq_b_j %||% attempt$fit$ssq_b_2
			private$cached_values$s_beta_hat_T = if (!is.null(ssq) && is.finite(ssq) && ssq > 0) sqrt(ssq) else NA_real_
			private$cached_values$df = NA_real_
			private$cached_values$beta_hat_T
		},
		#' @description Likelihood-ratio confidence interval for \eqn{\beta_T} by test
		#'   inversion (find the set of \code{delta} not rejected at level
		#'   \code{alpha} by the likelihood-ratio test); see
		#'   \code{\link[EDI:InferenceAsympLik]{InferenceAsympLik}} for the shared
		#'   inversion contract. If the underlying root-finding fails, returns
		#'   \code{NA} bounds and records a likelihood-ratio procedure failure; the
		#'   Wald estimate, standard error and \code{is_nonestimable()} are kept
		#'   (unless the Wald fit itself is unusable).
		#' @param alpha Two-sided miscoverage rate; the returned interval targets
		#'   \code{1 - alpha} coverage.
		compute_lik_ratio_confidence_interval = function(alpha = 0.05){
			# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
			# migration ladders): was `super$compute_lik_ratio_confidence_interval(...)`
			# -- same super$-through-a-composed-class breakage as documented in
			# inference_all_abstract_asymp_lik_std_mod_cache.R; replaced with the
			# private impl InferenceAsympLik's own public method delegates to.
			tryCatch(
				private$compute_lik_ratio_confidence_interval_impl(alpha),
				error = function(e){
					edi_record_procedure_failure(self, private, "lik_ratio_confidence_interval_unavailable", stage = "se") # TODO-116 (2026-10-22)
					ci = c(NA_real_, NA_real_)
					names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
					ci
				}
			)
		}
	),
	private = list(
		# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
		# migration ladders): see inference_incid_log_regr_private's cached_mod
		# entry (inference_incidence_logit.R) for the full explanation.
		cached_mod = NULL,
		best_X_colnames = NULL,
		build_design_matrix = function(){
			X_data = private$get_X()
			if (is.null(X_data) || ncol(X_data) == 0) {
				cbind(`(Intercept)` = 1, treatment = private$w)
			} else {
				cbind(`(Intercept)` = 1, treatment = private$w, X_data)
			}
		},
		is_identity_binomial_fit_reasonable = function(mod, X_fit = NULL, j_treat = 2L){
			if (is.null(mod) || is.null(mod$b)) return(FALSE)
			j_treat = as.integer(j_treat %||% mod$j_treat %||% 2L)
			if (length(j_treat) != 1L || !is.finite(j_treat) || j_treat < 1L) return(FALSE)
			b = as.numeric(mod$b)
			if (length(b) < j_treat || any(!is.finite(b))) return(FALSE)
			if (!is.null(mod$converged) && !isTRUE(mod$converged)) return(FALSE)
			if (!is.null(X_fit)) {
				mu = tryCatch(as.numeric(as.matrix(X_fit) %*% b), error = function(e) NA_real_)
				if (any(!is.finite(mu))) return(FALSE)
				if (any(mu < -1e-8) || any(mu > 1 + 1e-8)) return(FALSE)
			}
			TRUE
		},
		# v1.0.6-TODO-146: the randomization statistic is the cached point estimate,
		# the same quantity the reusable worker computes per draw
		# (compute_bootstrap_worker_estimate -> compute_estimate). This used to refit
		# on every call with no convergence check, from the warm start the previous
		# call left behind: the observed statistic drifted by ~1e-7 between calls
		# (this MLE sits near the mu = 0 bound and converges slowly), and draws whose
		# warm-started fit stalled returned the warm start itself, i.e. exactly the
		# observed estimate. Two seeded rand p-values on one object gave 1 vs 0.555
		# and the slow and reusable-worker paths disagreed.
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			self$compute_estimate(estimate_only = estimate_only)
		},
		# v1.0.6-TODO-146: fit_call(TRUE) fits from the stored warm start, fit_call(FALSE)
		# from a cold start. The warm start (beta and Fisher information) comes from a
		# fit on other data: on a randomization or bootstrap draw the treatment column or
		# rows differ, so the warm Fisher information is the wrong curvature for the
		# first Newton step. The constrained line search then rejects every step and
		# the kernel returns the start unchanged with converged = FALSE (about 30% of
		# draws on a 20-subject Bernoulli design). Refit cold when that happens.
		# v1.0.6-TODO-150: the kernel now restarts cold itself in that case (same
		# result as this retry, needs the owner's build); the retry stays for warm
		# fits that fail later, e.g. at the iteration cap.
		fit_identity_binomial_warm_then_cold = function(fit_call){
			res = tryCatch(fit_call(TRUE), error = function(e) NULL)
			if (is.null(res) || !isTRUE(res$converged)) {
				cold = tryCatch(fit_call(FALSE), error = function(e) NULL)
				if (!is.null(cold) && (is.null(res) || isTRUE(cold$converged))) res = cold
			}
			res
		},
		supports_reusable_bootstrap_worker = function(){
			TRUE
		},
		supports_likelihood_tests = function(){
			TRUE
		},
		get_supported_testing_types_impl = function(){
			c("wald", "score", "lik_ratio", "gradient")
		},
		supports_lik_ratio_param_bootstrap = function(){
			TRUE
		},
		simulate_under_lik_null = function(spec, delta, null_fit){
			b_null     = as.numeric(null_fit$b)
			mu         = pmin(pmax(as.numeric(spec$X %*% b_null), 0), 1)
			y_sim      = as.numeric(rbinom(length(mu), 1L, mu))
			X_fit      = spec$X
			j          = spec$j
			full_fit_b = tryCatch(
				fast_identity_binomial_regression_cpp(X = X_fit, y = y_sim),
				error = function(e) NULL
			)
			if (is.null(full_fit_b) || !isTRUE(full_fit_b$converged)) return(NULL)
			if (length(full_fit_b$b) < j || !is.finite(full_fit_b$b[j])) return(NULL)
			list(
				full_fit = full_fit_b,
				fit_null = function(d, start = NULL){
					res = tryCatch(
						fast_identity_binomial_regression_cpp(
							X = X_fit, y = y_sim,
							warm_start_beta = start %||% full_fit_b$b,
							fixed_idx = j, fixed_values = d
						),
						error = function(e) NULL
					)
					if (is.null(res) || !isTRUE(res$converged)) return(NULL)
					res
				},
				neg_loglik = function(fit){
					mu_fit = as.numeric(X_fit %*% as.numeric(fit$b))
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
							fast_identity_binomial_regression_cpp(
								X = X_fit, y = y,
								warm_start_beta = beta0,
								warm_start_fisher_info = fisher0,
								fixed_idx = j_treat, fixed_values = delta
							),
							error = function(e) NULL
						)
						if (is.null(res) || !isTRUE(res$converged)) NULL else res
					}
					# The original call first: identical result whenever it converges.
					res = try_fit(start %||% private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
						private$get_fit_warm_start_fisher(ncol(X_fit)))
					if (!is.null(res)) {
						# TODO-181 leftover (as for InferenceIncidLogBinomial): a
						# warm-started fit that is not a Kuhn-Tucker point (a row
						# held at a bound that the optimum frees) is refitted from a
						# cold start; the lower negative log-likelihood is kept.
						kkt = edi_binomial_identity_kkt_terms(X_fit, y, as.numeric(res$b), j_treat)
						if (isTRUE(kkt$not_kkt)) {
							cold = try_fit(NULL, NULL)
							if (!is.null(cold) &&
							    edi_binomial_identity_neg_loglik(X_fit, y, cold$b) < edi_binomial_identity_neg_loglik(X_fit, y, res$b)) res = cold
						}
						return(res)
					}
					# TODO-177: the full fit's warm Fisher is used as X'WX on iteration
					# 0; for the identity link it can be stale enough that every
					# line-search step is rejected. Retry from the full fit with
					# beta_T = delta and no warm Fisher, then from a cold start.
					b_full = as.numeric(private$cached_mod$b)
					if (length(b_full) == ncol(X_fit) && all(is.finite(b_full))) {
						b_full[j_treat] = delta
						res = try_fit(b_full, NULL)
						if (!is.null(res)) return(res)
					}
					res = try_fit(NULL, NULL)
					if (!is.null(res)) return(res)
					# The kernel stops after one iteration when its start has a fitted
					# probability outside [0, 1], even when the null MLE is interior
					# (a calibration replicate at delta = 0.49: both starts above
					# had max mu 1.08-1.09, the MLE 0.993). Last start: covariates
					# at 0, beta_T = delta and the intercept inside the feasible
					# range, so every fitted probability is in [0, 1].
					b_safe = edi_binomial_identity_feasible_start(X_fit, y, j_treat, delta)
					if (is.null(b_safe)) NULL else try_fit(b_safe, NULL)
				},
				extract_start = function(fit){
					as.numeric(fit$b)
				},
				observed_information = function(fit){
					edi_binomial_identity_lik_test_information(X_fit, y, as.numeric(fit$b), j_treat)
				},
				fisher_information = function(fit){
					edi_binomial_identity_lik_test_information(X_fit, y, as.numeric(fit$b), j_treat)
				},
				information = function(fit){
					edi_binomial_identity_lik_test_information(X_fit, y, as.numeric(fit$b), j_treat)
				},
				score = function(fit){
					# TODO-181 (c), revised 2026-11-08 (owner): at a
					# null-restricted MLE with a fitted probability at 0 or 1 the
					# score and information come from the Kuhn-Tucker terms
					# (edi_binomial_identity_kkt_terms(), the profile score test,
					# as for InferenceIncidLogBinomial) instead of being NA. They
					# are NA with a recorded reason only where those terms are
					# undefined (a y = 1 subject at 0, a y = 0 subject at 1, or
					# not a Kuhn-Tucker point). Interior fits keep the
					# finite-difference values.
					edi_binomial_identity_lik_test_score(X_fit, y, as.numeric(fit$b), j_treat, private)
				},
				neg_loglik = function(fit){
					mu = as.numeric(X_fit %*% as.numeric(fit$b))
					-sum(y * log(pmax(mu, 1e-15)) + (1 - y) * log(pmax(1 - mu, 1e-15)))
				}
			)
		},
		generate_mod = function(estimate_only = FALSE){
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L,
				fit_fun = function(X_fit, keep){
					j_treat = which(keep == 2L)
					warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit))
					warm_fisher = private$get_fit_warm_start_fisher(ncol(X_fit))
					# v1.0.6-TODO-146: refit cold when the warm-started fit stalls (see
					# fit_identity_binomial_warm_then_cold), and keep `converged` on the
					# estimate-only fit so fit_ok rejects a stalled one: dropping it let
					# a draw's unmoved warm start (the observed estimate) through.
					if (estimate_only) {
						res = private$fit_identity_binomial_warm_then_cold(function(warm){
							fast_identity_binomial_regression_cpp(
								X = X_fit, y = private$y,
								warm_start_beta = if (warm) warm_start_beta else NULL,
								warm_start_fisher_info = if (warm) warm_fisher else NULL
							)
						})
						if (is.null(res)) return(NULL)
						list(b = res$b, beta_hat_T = as.numeric(res$b[j_treat]), ssq_b_j = NA_real_, j_treat = j_treat, fisher_information = res$fisher_information, converged = isTRUE(res$converged))
					} else {
						res = private$fit_identity_binomial_warm_then_cold(function(warm){
							fast_identity_binomial_regression_with_var_cpp(
								X = X_fit, y = private$y, j = j_treat,
								warm_start_beta = if (warm) warm_start_beta else NULL,
								warm_start_fisher_info = if (warm) warm_fisher else NULL
							)
						})
						if (is.null(res)) return(NULL)
						res$j_treat = j_treat
						res$beta_hat_T = as.numeric(res$b[j_treat])
						res
					}
				},
				fit_ok = function(mod, X_fit, keep){
					j_treat = mod$j_treat
					if (!isTRUE(private$is_identity_binomial_fit_reasonable(mod, X_fit, j_treat))) return(FALSE)
					if (estimate_only) return(TRUE)
					is.finite(mod$ssq_b_j) && mod$ssq_b_j > 0
				}
			)
			j_treat_attempt = if (!is.null(attempt$fit)) attempt$fit$j_treat else NA_integer_
			attempt_ok = isTRUE(private$is_identity_binomial_fit_reasonable(attempt$fit, attempt$X, j_treat_attempt)) &&
				(isTRUE(estimate_only) || (is.finite(attempt$fit$ssq_b_j) && attempt$fit$ssq_b_j > 0))
			if (!isTRUE(attempt_ok)){
				attempt$fit = NULL
			}
			if (!is.null(attempt$fit)){
				private$set_fit_warm_start(attempt$fit$b, "beta", fisher = attempt$fit$fisher_information)
				private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
				private$cached_values$likelihood_test_context = list(
					X = attempt$X,
					j_treat = attempt$fit$j_treat
				)
				# 2026-08-24 (marginal_estimand_report.md TODO-9): stash the
				# exact fitting design matrix and its coefficient covariance so
				# the marginal-estimand g-computation path (private$compute_
				# marginal_estimand_estimate()) is a pure post-fit transform, no
				# refit -- same convention as InferenceIncidLogRegr's mod$X/
				# mod$vcov. NOTE (see class-level @details): because this
				# family uses the identity link with no treatment-by-covariate
				# interaction, the g-computation marginal mean difference
				# collapses algebraically to exactly attempt$fit$b[j_treat] --
				# this stash exists for estimand-API consistency and a correct
				# SE, not because the point estimate differs from conditional.
				attempt$fit$X = attempt$X
				attempt$fit$vcov = if (!is.null(attempt$fit$fisher_information)) tryCatch(solve(attempt$fit$fisher_information), error = function(e) NULL) else NULL
				edi_warn_binomial_mle_boundary_once(self, private, attempt$X, attempt$fit$b, "identity") # TODO-128: warning only, no numeric change
			} else {
				private$cached_values$likelihood_test_context = NULL
			}
			attempt$fit
		}
	)
)

#' Binomial Identity Risk Difference Inference for Incidence Responses
#'
#' Fits a binomial regression with the \strong{identity} link for binary
#' (incidence) responses: \eqn{P(Y_i = 1) = \beta_0 + \beta_T W_i + X_i^\top
#' \gamma}, where \eqn{W_i} is the treatment indicator and \eqn{X_i} are
#' optional recorded covariates, by maximum likelihood
#' (\code{\link{fast_identity_binomial_regression_cpp}}/
#' \code{\link{fast_identity_binomial_regression_weighted_cpp}}). Because the
#' link is the identity rather than the logit, \eqn{\hat\beta_T} is directly a
#' \strong{risk difference} on the probability scale, not a log-odds-ratio —
#' the class name and estimand differ from
#' \code{\link[EDI:InferenceIncidLogRegr]{InferenceIncidLogRegr}} for exactly
#' this reason. \code{likelihood_tier = "full"}: likelihood-ratio, score,
#' gradient, and Wald tests are all available when the model converges, plus
#' parametric-likelihood-bootstrap calibration of the likelihood-ratio test.
#' Because the identity link does not constrain fitted probabilities to
#' \eqn{[0,1]}, fits are hardened by QR column-dropping and rejected as
#' nonestimable when the fitted linear predictor produces implausible
#' coefficients (see \code{private$is_identity_binomial_fit_reasonable()});
#' this is a real practical limitation of the identity link relative to
#' logit/probit, not a bug. When the full-data MLE is on the boundary (some
#' fitted probability equal to 0 or 1), the object warns once
#' (\code{edi_binomial_mle_boundary_warning}) that Wald and score standard
#' errors and intervals may be unreliable. The Wald standard error is the
#' inverse of the expected (Fisher) information \eqn{X^\top W X},
#' \eqn{W = \mathrm{diag}\{1 / (\hat\mu_i (1 - \hat\mu_i))\}}, of the
#' Fisher-scoring fit, as \code{glm()} reports for a non-canonical link; it is
#' not the observed information, which the score test uses (a documented
#' exception to the package's observed-information rule for Wald standard
#' errors). The same standard error is used by every Wald interval and
#' p-value (\code{compute_asymp_*()} and \code{compute_wald_*()}) and by
#' \code{InferenceSuite}'s \code{se} column. Validity requires the additive risk-difference
#' model to be correctly specified over the covariate range actually observed
#' (an identity-link fit can be well-behaved in-sample yet imply
#' out-of-range probabilities for other covariate values).
#'
#' \strong{Estimand.} Composes
#' \code{\link[EDI:InferenceMarginalEstimand]{MarginalEstimand}}
#' (\code{set_estimand()}/\code{get_estimand()}/\code{get_supported_estimands()}).
#' \code{estimand = "marginal_mean_diff"} is supported for API consistency
#' with the other GLM families, but \strong{it is algebraically identical to
#' the default \code{estimand = "conditional"} for this class}: the
#' g-computation marginal risk difference is \eqn{\frac{1}{n}\sum_i
#' \{(\hat\beta_0 + \hat\beta_T + X_i^\top \hat\gamma) - (\hat\beta_0 +
#' X_i^\top \hat\gamma)\}}, which simplifies to exactly \eqn{\hat\beta_T} for
#' every subject (not merely on average) because the identity link is linear
#' in \eqn{W_i} with no treatment-by-covariate interaction term — the
#' per-subject treated-minus-control difference \eqn{\hat\beta_T} does not
#' depend on \eqn{X_i} at all, so standardizing over the covariate
#' distribution changes nothing. Contrast with
#' \code{\link[EDI:InferenceCountPoisson]{InferenceCountPoisson}}'s
#' \code{"marginal_ratio"} (also a collapsing case, for the same
#' no-interaction reason) and \code{"marginal_mean_diff"} (which does not
#' collapse, since a difference does not distribute through the nonlinear
#' log-link mean). This collapsing is a genuine property of the identity-link
#' model, not a wiring bug — it is documented here so a user comparing
#' \code{estimand}s for this class is not surprised the two never differ.
#' Standard errors are computed independently for each estimand (the
#' marginal path uses the delta method against the model's coefficient
#' covariance; the conditional path uses the model information matrix), so
#' while the two point estimates coincide exactly, their standard errors may
#' differ slightly by construction even though both are asymptotically valid.
#'
#' \strong{Small samples.} With unequal allocation (\code{prob_T = 0.2}, about
#' 10 treated subjects at n = 50), the Wald test rejected a true null 14.4\% of
#' the time at a nominal 5\% level with covariate adjustment (intervals covered
#' 85.6\%) and 9.4\% treatment-only. The score, gradient and likelihood-ratio
#' tests rejected 4.7\% to 5.9\% of the time in the same cells with covariate
#' adjustment, so prefer them at this sample size. The excess is expected to
#' shrink as n grows. With so few subjects in one arm, use a larger or more
#' balanced sample, or a randomization or bootstrap test. Source: the first
#' calibration campaign (2026-11-09-8c32d060; provisional, 1000 screening
#' replicates per cell, Monte Carlo standard error about 0.007; measured at n =
#' 50 only), \url{https://github.com/kapelner/EDI/tree/calibration-results}.
#'
#' \strong{Dropped covariates.} When the fit with all covariates fails or does not
#' pass the fit checks and the hardened refit drops covariates to get a usable
#' fit, the class raises one warning of class
#' \code{edi_covariate_dropped_warning} per object (silent inside resampling)
#' naming the dropped columns and the reason; the reported results are for the
#' reduced model. Columns dropped only for linear dependence are not warned
#' about.
#'
#' @references McCullagh, P., and Nelder, J. A. (1989). \emph{Generalized
#'   Linear Models} (2nd ed.). Chapman and Hall/CRC, for the binomial GLM
#'   family and identity-link risk-difference parameterization.
#'
#' @seealso \code{\link[EDI:InferenceIncidLogRegr]{InferenceIncidLogRegr}}
#'   (logit link, log-odds-ratio estimand),
#'   \code{\link[EDI:InferenceIncidLogBinomial]{InferenceIncidLogBinomial}}
#'   (log link, log-risk-ratio estimand) for alternative link/estimand
#'   choices on the same response type. Comparable Python API:
#'   \href{https://www.statsmodels.org/stable/glm.html}{statsmodels GLM}
#'   (\code{family=Binomial(link=identity())}). See also:
#'   \href{https://en.wikipedia.org/wiki/Generalized_linear_model}{Generalized
#'   linear model} (Wikipedia).
#'
#' @examples
#' \donttest{
#' set.seed(1)
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 100, response_type = 'incidence')
#' for (i in 1:100) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rbinom(1, 1, 0.5)))
#' }
#' # true risk 0.3 + 0.2 * w + 0.1 * x1 stays in [0.3, 0.6], well inside (0, 1),
#' # and a binary covariate keeps every fitted probability inside the four
#' # treatment-by-x1 cells, so the identity-link MLE stays off the boundary
#' w = seq_des$get_w()
#' x1 = seq_des$get_X()[, 1]
#' seq_des$add_all_subject_responses(rbinom(100, 1, 0.3 + 0.2 * w + 0.1 * x1))
#' inf = InferenceIncidBinomialIdentityRiskDiff$new(seq_des)
#' inf$compute_estimate()   # true risk difference 0.2
#' inf$compute_asymp_confidence_interval()
#' }
#' @inheritSection InferenceContinOLS Blocking designs
#' @eval rd_small_sample_section("InferenceIncidBinomialIdentityRiskDiff")
#' @export
InferenceIncidBinomialIdentityRiskDiff = define_inference_class(
	classname = "InferenceIncidBinomialIdentityRiskDiff",
	inherit = Inference,
	components = c(
		"RandomizationCI",
		"RandomizationBootstrapCI",
		"BayesianBootstrap",
		"Jackknife",
		"ParametricLikelihoodBootstrap",
		"IncidenceBinomialIdentityLikelihood",
		"MarginalEstimand"
	),
	metadata = list(likelihood_tier = "full"),
	overrides = list(
		public = c(
			"compute_estimate", "compute_rand_two_sided_pval",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"get_supported_testing_types", "set_testing_type", "compute_estimate_with_bootstrap_weights",
			"compute_lik_ratio_confidence_interval"
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
			"get_complexity_tier", "supports_fisher_information", "get_supported_estimands_impl"
		)
	),
	public = list(
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval,
		#' @description Fits the identity-link binomial regression model by
		#'   maximum likelihood. Under the default \code{estimand =
		#'   "conditional"}, returns \eqn{\hat\beta_T}, the risk difference
		#'   coefficient. Under \code{estimand = "marginal_mean_diff"} (set via
		#'   \code{set_estimand()}), returns the g-computation marginal risk
		#'   difference — see the class-level \code{@details} for why this is
		#'   algebraically identical to the conditional estimate for this
		#'   family. The underlying model fit is identical either way (a pure
		#'   post-fit transform of the same cached fit, no refit).
		#' @param estimate_only If TRUE, skip standard-error computation and
		#'   cache only the point estimate; used by randomization and
		#'   bootstrap resampling paths.
		compute_estimate = function(estimate_only = FALSE){
			compute_cached_mean_difference_estimate(self, private, estimate_only,
				function(mod) mod$j_treat %||% 2L, function(mod) mod$ssq_b_j)
		},
		#' @description Wald confidence interval, dispatched by
		#'   \code{testing_type} for the conditional estimand; under a
		#'   marginal estimand \code{testing_type} is always \code{"wald"} (the
		#'   only value \code{set_estimand()} permits there). Calls
		#'   \code{self$compute_estimate()} first (not \code{private$shared()}
		#'   directly) so the estimand-aware cache is always current
		#'   regardless of call order.
		#' @param alpha Two-sided miscoverage rate; the returned interval
		#'   targets \code{1 - alpha} coverage.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			compute_mean_difference_estimand_ci(self, private, alpha,
				lik_ratio = self$compute_lik_ratio_confidence_interval(alpha))
		},
		#' @description Wald two-sided p-value, dispatched by
		#'   \code{testing_type} exactly as
		#'   \code{compute_asymp_confidence_interval()}; see that method's
		#'   description for the marginal-estimand always-Wald note.
		#' @param delta Null treatment-effect value under the current estimand
		#'   (both scales coincide for this family — see the class-level
		#'   \code{@details}).
		compute_asymp_two_sided_pval = function(delta = 0){
			compute_mean_difference_estimand_pval(self, private, delta)
		}
	),
	private = list(
		# 2026-08-24 (marginal_estimand_report.md TODO-9): every class
		# composing MarginalEstimand supports only "conditional" by default;
		# overridden here for estimand-API consistency with the other GLM
		# families. See the class-level @details for why "marginal_mean_diff"
		# is numerically identical to "conditional" for this family
		# specifically (identity link, no treatment-by-covariate interaction).
		get_supported_estimands_impl = function(){
			c("conditional", "marginal_mean_diff")
		},
		# Standard error of beta_hat_T under the current estimand. Calls
		# self$compute_estimate() first so the estimand-aware cache is always
		# current regardless of call order.
		# v1.0.6-TODO-161 (2): this is the same SE as the Wald CI / p-value of
		# compute_asymp_*() (one source of truth): the conditional SE is the
		# inverse expected information X'WX of the IRLS fit (glm()'s convention,
		# owner decision 2026-11-19), not the observed information of the
		# likelihood-test spec, which it used to return (0.5% to 13% apart).
		get_standard_error = function(){
			self$compute_estimate(estimate_only = FALSE)
			private$cached_values$s_beta_hat_T
		},
		# Degrees of freedom under the current estimand. Calls
		# self$compute_estimate() first so the estimand-aware cache is always
		# current regardless of call order.
		get_degrees_of_freedom = function(){
			edi_estimand_degrees_of_freedom(self, private)
		},
		# Model-implied mean E[Y | w, x] = X %*% beta (identity link).
		identity_binomial_mean_from_coefs = function(beta, X){
			as.numeric(X %*% beta)
		},
		# G-computation average over the empirical covariate distribution,
		# with every subject plugged in at treatment column (column 2, per
		# build_design_matrix()'s fixed convention) = 1 and = 0. For an
		# identity-link model with no treatment-by-covariate interaction this
		# is algebraically exact and equal to beta[2] for every subject, not
		# just on average -- see the class-level @details.
		identity_binomial_marginal_functional = function(beta, X){
			edi_estimand_mean_difference(beta, X, private$identity_binomial_mean_from_coefs)
		},
		# Full-fit marginal path for compute_estimate(): reuses the single
		# cached ML fit (private$cached_mod, populated by private$shared() via
		# generate_mod()) -- a pure post-fit transform, no refit. SE via
		# marginal_estimand_delta_se() against the fitted vcov generate_mod()
		# now retains. Degrees of freedom: Inf, same convention as every other
		# delta-method/sandwich Wald path in this package.
		compute_marginal_estimand_estimate = function(estimand, estimate_only = FALSE){
			cache_delta_method_marginal_estimate(private, private$cached_mod,
				private$identity_binomial_marginal_functional, estimate_only, reason_prefix = "identity_binomial")
		}
	)
)


# TODO-181 (c) revised 2026-11-08 (owner): score and information for the
# score / gradient tests of InferenceIncidBinomialIdentityRiskDiff at a
# null-restricted fit with a fitted probability mu = X b at 0 or 1 (the
# kernel keeps mu in [1e-8, 1 - 1e-8]). A y = 1 row can only bind at mu = 1
# (constraint x' b <= 1, outward normal +x) and a y = 0 row only at mu = 0
# (x' b >= 0, normal -x); a y = 1 row at 0 or a y = 0 row at 1 has
# log-likelihood -Inf. With the analytic score X'(y / mu - (1 - y) / (1 - mu))
# and information X' diag(y / mu^2 + (1 - y) / (1 - mu)^2) X, evaluated at the
# bound itself for the bound rows, the Kuhn-Tucker terms are those of
# edi_binomial_bound_kkt_core() (see edi_log_binomial_kkt_terms()): the
# profile score test. Returns NULL when no row is within 1e-4 of a bound (the
# caller keeps the finite-difference values).
edi_binomial_identity_kkt_terms = function(X, y, b, j){
	mu = as.numeric(X %*% b)
	if (any(!is.finite(mu))) return(NULL)
	up = mu >= 1 - 1e-4
	lo = mu <= 1e-4
	C = which(up | lo)
	if (!length(C)) return(NULL)
	undefined = function(why) list(reason = paste0(
		"the null-restricted MLE is on the boundary of the parameter space (fitted probability 0 or 1) and ",
		why, "; the score and gradient tests are not computed there (the likelihood-ratio test is)"))
	y1 = y > 0.5
	edge = 1e-8 + 1e-6
	if (any(y1 & mu <= edge)) return(undefined("a subject with y = 1 has fitted probability 0 (log-likelihood -Inf)"))
	if (any(!y1 & mu >= 1 - edge)) return(undefined("a subject with y = 0 has fitted probability 1 (log-likelihood -Inf)"))
	mu0 = mu
	mu0[y1 & up] = 1
	mu0[!y1 & lo] = 0
	if (any(y1 & mu0 <= 0) || any(!y1 & mu0 >= 1)) return(undefined("a fitted probability is outside [0, 1]"))
	r = ifelse(y1, 1 / mu0, -1 / (1 - mu0))
	w = ifelse(y1, 1 / mu0^2, 1 / (1 - mu0)^2)
	s = as.numeric(crossprod(X, r))
	I = unname(crossprod(X, X * w))
	sgn = ifelse(up[C], 1, -1)
	edi_binomial_bound_kkt_core(X, b, j, s, I, C, sgn, undefined)
}

edi_binomial_identity_neg_loglik = function(X, y, b){
	mu = as.numeric(X %*% as.numeric(b))
	if (any(!is.finite(mu)) || any(mu < 0 | mu > 1)) return(Inf)
	-sum(ifelse(y > 0.5, log(mu), log1p(-mu)))
}

edi_binomial_identity_lik_test_score = function(X, y, b, j, private){
	s = as.numeric(get_identity_binomial_regression_score_cpp(X, y, b))
	kkt = edi_binomial_identity_kkt_terms(X, y, b, j)
	if (is.null(kkt) || (!isTRUE(kkt$boundary) && is.null(kkt$reason) && all(is.finite(s)))) return(s)
	if (!is.null(kkt$reason)) {
		edi_note_lik_test_failure(private, "score", kkt$reason)
		edi_note_lik_test_failure(private, "gradient", kkt$reason)
		return(rep(NA_real_, length(b)))
	}
	kkt$score
}

edi_binomial_identity_lik_test_information = function(X, y, b, j){
	info = -get_identity_binomial_regression_hessian_cpp(X, y, b)
	kkt = edi_binomial_identity_kkt_terms(X, y, b, j)
	if (is.null(kkt) || (!isTRUE(kkt$boundary) && is.null(kkt$reason) && all(is.finite(info)))) return(info)
	if (!is.null(kkt$reason)) return(matrix(NA_real_, length(b), length(b)))
	kkt$info
}

# A start for the identity-link fit with beta_T = delta that keeps every fitted
# probability inside [eps, 1 - eps]: the other coefficients at 0 and the
# intercept at the empirical rate, clamped to the feasible range. NULL when
# the design has no intercept column or no feasible intercept exists.
edi_binomial_identity_feasible_start = function(X, y, j, delta, eps = 1e-3){
	int_col = which(apply(X, 2L, function(col) all(col == 1)))
	int_col = setdiff(int_col, j)
	if (!length(int_col)) return(NULL)
	int_col = int_col[1L]
	shift = range(delta * X[, j])
	lo = eps - shift[1L]
	hi = 1 - eps - shift[2L]
	if (!is.finite(lo) || !is.finite(hi) || lo > hi) return(NULL)
	b = numeric(ncol(X))
	b[j] = delta
	b[int_col] = min(max(mean(y) - delta * mean(X[, j]), lo), hi)
	b
}
