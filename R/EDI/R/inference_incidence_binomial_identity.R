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
					res = tryCatch(
						fast_identity_binomial_regression_weighted_cpp(
							X = X_fit,
							y = as.numeric(private$y),
							weights = as.numeric(row_weights),
							warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
							warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit))
						),
						error = function(e) NULL
					)
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
		#'   inversion contract. Falls back to a nonestimable result (\code{NA}
		#'   bounds) if the underlying root-finding fails.
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
					private$cache_nonestimable_se("lik_ratio_confidence_interval_unavailable")
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
			res = tryCatch(
				fast_identity_binomial_regression_cpp(
					X = X, y = as.numeric(private$y),
					warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X)),
					warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X))
				),
				error = function(e) NULL
			)
			if (is.null(res) || !is.finite(res$b[2])){
				return(NA_real_)
			}
			private$set_fit_warm_start(res$b, "beta", fisher = res$fisher_information)
			as.numeric(res$b[2])
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
					res = tryCatch(
						fast_identity_binomial_regression_cpp(
							X = X_fit, y = y,
							warm_start_beta = start %||% private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
							warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit)),
							fixed_idx = j_treat, fixed_values = delta
						),
						error = function(e) NULL
					)
					if (is.null(res) || !isTRUE(res$converged)) return(NULL)
					res
				},
				extract_start = function(fit){
					as.numeric(fit$b)
				},
				observed_information = function(fit){
					-get_identity_binomial_regression_hessian_cpp(X_fit, y, as.numeric(fit$b))
				},
				fisher_information = function(fit){
					-get_identity_binomial_regression_hessian_cpp(X_fit, y, as.numeric(fit$b))
				},
				information = function(fit){
					-get_identity_binomial_regression_hessian_cpp(X_fit, y, as.numeric(fit$b))
				},
				score = function(fit){
					as.numeric(get_identity_binomial_regression_score_cpp(X_fit, y, as.numeric(fit$b)))
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
					if (estimate_only) {
						res = tryCatch(
							fast_identity_binomial_regression_cpp(
								X = X_fit, y = private$y,
								warm_start_beta = warm_start_beta,
								warm_start_fisher_info = warm_fisher
							),
							error = function(e) NULL
						)
						if (is.null(res)) return(NULL)
						list(b = res$b, beta_hat_T = as.numeric(res$b[j_treat]), ssq_b_j = NA_real_, j_treat = j_treat, fisher_information = res$fisher_information)
					} else {
						res = tryCatch(
							fast_identity_binomial_regression_with_var_cpp(
								X = X_fit, y = private$y, j = j_treat,
								warm_start_beta = warm_start_beta,
								warm_start_fisher_info = warm_fisher
							),
							error = function(e) NULL
						)
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
#' logit/probit, not a bug. Validity requires the additive risk-difference
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
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidBinomialIdentityRiskDiff$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceIncidBinomialIdentityRiskDiff = define_inference_class(
	classname = "InferenceIncidBinomialIdentityRiskDiff",
	inherit = Inference,
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "IncidenceBinomialIdentityLikelihood", "MarginalEstimand"),
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio"),
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
			private$shared(estimate_only = estimate_only)
			if (identical(self$get_estimand(), "marginal_mean_diff")) {
				return(private$compute_marginal_estimand_estimate("marginal_mean_diff", estimate_only = estimate_only))
			}
			# 2026-08-24 (marginal_estimand_report.md TODO-9): re-derive the
			# conditional beta_hat_T/s_beta_hat_T/df from the estimand-invariant
			# private$cached_mod every call -- same fix TODO-4/5 needed for the
			# same reason.
			mod = private$cached_mod
			if (!is.null(mod)) {
				j_treat = mod$j_treat %||% 2L
				private$cached_values$beta_hat_T = as.numeric(mod$beta_hat_T %||% mod$b[j_treat])[1L]
				if (!estimate_only) {
					ssq = mod$ssq_b_j
					ssq = if (length(ssq) >= 1L) as.numeric(ssq)[1L] else NA_real_
					private$cached_values$df = mod$df %||% Inf
					if (is.finite(ssq) && ssq > 0) {
						private$cached_values$s_beta_hat_T = sqrt(ssq)
						private$clear_nonestimable_state()
					} else {
						private$cache_nonestimable_se("model_standard_error_unavailable")
					}
				}
			}
			private$cached_values$beta_hat_T
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
			self$compute_estimate(estimate_only = FALSE)
			if (private$testing_type == "wald") {
				if (is.finite(private$cached_values$s_beta_hat_T %||% NA_real_)) {
					return(private$compute_z_or_t_ci_from_s_and_df(alpha))
				}
			}
			switch(
				private$testing_type,
				wald = private$compute_wald_confidence_interval_impl(alpha),
				score = private$compute_score_confidence_interval_impl(alpha),
				gradient = private$compute_gradient_confidence_interval_impl(alpha),
				lik_ratio = self$compute_lik_ratio_confidence_interval(alpha),
				lik_ratio_bartlett_approx = private$compute_lik_ratio_bartlett_approx_confidence_interval_impl(alpha),
				lik_ratio_bartlett_exact = private$compute_lik_ratio_bartlett_exact_confidence_interval_impl(alpha)
			)
		},
		#' @description Wald two-sided p-value, dispatched by
		#'   \code{testing_type} exactly as
		#'   \code{compute_asymp_confidence_interval()}; see that method's
		#'   description for the marginal-estimand always-Wald note.
		#' @param delta Null treatment-effect value under the current estimand
		#'   (both scales coincide for this family — see the class-level
		#'   \code{@details}).
		compute_asymp_two_sided_pval = function(delta = 0){
			self$compute_estimate(estimate_only = FALSE)
			if (private$testing_type == "wald") {
				if (is.finite(private$cached_values$s_beta_hat_T %||% NA_real_)) {
					return(private$compute_z_or_t_two_sided_pval_from_s_and_df(delta))
				}
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
		get_standard_error = function(){
			self$compute_estimate(estimate_only = FALSE)
			if (!identical(self$get_estimand(), "conditional")) {
				return(private$cached_values$s_beta_hat_T)
			}
			private$shared(estimate_only = FALSE)
			if (isTRUE(private$supports_information_preference())) {
				se = tryCatch(private$compute_standard_error_from_information_matrix(), error = function(e) NA_real_)
				if (is.finite(se)) return(se)
			}
			private$cached_values$s_beta_hat_T
		},
		# Degrees of freedom under the current estimand. Calls
		# self$compute_estimate() first so the estimand-aware cache is always
		# current regardless of call order.
		get_degrees_of_freedom = function(){
			self$compute_estimate(estimate_only = FALSE)
			private$cached_values$df %||% Inf
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
			X1 = X; X1[, 2L] = 1
			X0 = X; X0[, 2L] = 0
			mean(private$identity_binomial_mean_from_coefs(beta, X1)) -
				mean(private$identity_binomial_mean_from_coefs(beta, X0))
		},
		# Full-fit marginal path for compute_estimate(): reuses the single
		# cached ML fit (private$cached_mod, populated by private$shared() via
		# generate_mod()) -- a pure post-fit transform, no refit. SE via
		# marginal_estimand_delta_se() against the fitted vcov generate_mod()
		# now retains. Degrees of freedom: Inf, same convention as every other
		# delta-method/sandwich Wald path in this package.
		compute_marginal_estimand_estimate = function(estimand, estimate_only = FALSE){
			mod = private$cached_mod
			if (is.null(mod) || is.null(mod$b) || is.null(mod$X)) {
				private$cache_nonestimable_estimate("identity_binomial_marginal_fit_unavailable")
				return(NA_real_)
			}
			functional = function(theta) private$identity_binomial_marginal_functional(theta, mod$X)
			point = tryCatch(functional(mod$b), error = function(e) NA_real_)
			if (!is.finite(point)) {
				private$cache_nonestimable_estimate("identity_binomial_marginal_point_unavailable")
				return(NA_real_)
			}
			private$cached_values$beta_hat_T = point
			if (estimate_only) return(point)
			if (is.null(mod$vcov)) {
				private$cache_nonestimable_se("identity_binomial_marginal_vcov_unavailable")
				return(point)
			}
			dm = marginal_estimand_delta_se(mod$b, mod$vcov, functional)
			private$cached_values$df = Inf
			if (is.finite(dm$se) && dm$se >= 0) {
				private$cached_values$s_beta_hat_T = dm$se
				private$clear_nonestimable_state()
			} else {
				private$cache_nonestimable_se("identity_binomial_marginal_se_unavailable")
			}
			point
		}
	)
)
