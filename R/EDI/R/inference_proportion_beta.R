#' Beta Regression Inference for Proportion Responses
#'
#' Fits Ferrari and Cribari-Neto's (2004) beta regression for proportion
#' responses \eqn{Y_i \in (0, 1)}: \eqn{\mathrm{logit}(E[Y_i \mid w_i, x_i]) =
#' \beta_0 + \beta_T w_i + x_i^\top \gamma}, \eqn{Y_i \mid w_i, x_i \sim
#' \mathrm{Beta}(\mu_i \phi, (1-\mu_i)\phi)} for fitted mean \eqn{\mu_i} and a
#' single (constant, not covariate-dependent) precision parameter \eqn{\phi},
#' by maximum likelihood (\code{\link{fast_beta_regression_cpp}}/
#' \code{\link{fast_beta_regression_weighted_cpp}}). \eqn{\hat\beta_T} is a
#' log-odds-ratio on the conditional-mean scale: \eqn{\exp(\hat\beta_T)} is
#' the odds ratio for the expected proportion. Unlike
#' \code{\link[EDI:InferencePropFractionalLogit]{InferencePropFractionalLogit}}'s
#' quasi-likelihood (which specifies only the conditional mean), beta
#' regression also specifies the conditional variance/shape via \eqn{\phi} —
#' a correctly specified beta model yields a fully efficient likelihood-based
#' fit and genuine likelihood-ratio/score/gradient tests, at the cost of
#' requiring the beta-distribution shape assumption to actually hold.
#' \code{likelihood_tier = "full"}: likelihood-ratio, score, gradient, and
#' Wald tests are all available when the model converges, plus
#' parametric-likelihood-bootstrap calibration of the likelihood-ratio test.
#' \eqn{Y_i} values of exactly 0 or 1 are not supported by the beta density
#' and are handled by \code{sanitize_beta_response()}'s boundary adjustment
#' before fitting.
#'
#' \strong{Estimand.} Composes
#' \code{\link[EDI:InferenceMarginalEstimand]{MarginalEstimand}}
#' (\code{set_estimand()}/\code{get_estimand()}/\code{get_supported_estimands()}).
#' Under the default \code{estimand = "conditional"}, \eqn{\hat\beta_T} is the
#' log-odds-ratio above. Under \code{estimand = "marginal_mean_diff"}, the
#' reported quantity is instead the g-computation marginal mean difference
#' \eqn{\frac{1}{n}\sum_i \{\mathrm{plogis}(\hat\beta_0 + \hat\beta_T +
#' X_i^\top \hat\gamma) - \mathrm{plogis}(\hat\beta_0 + X_i^\top
#' \hat\gamma)\}} (the precision parameter \eqn{\phi} does not enter the
#' mean, so it plays no role in this functional). Only
#' \code{"marginal_mean_diff"} is supported — a ratio of two mean
#' proportions, both bounded in \eqn{[0,1]}, is not the standard estimand
#' for a beta-regression treatment effect the way a rate ratio is for count
#' data. Because there is no latent submodel for this family (unlike e.g.
#' \code{\link[EDI:InferencePropZeroOneInflatedBetaRegr]{InferencePropZeroOneInflatedBetaRegr}}'s
#' zero/one-inflation mixture), the marginal mean function is exactly the
#' model's own fitted mean; no separate standardization step beyond the
#' g-computation average is needed. Standard errors under the marginal
#' estimand use the delta method against the mean-submodel coefficient
#' covariance (degrees of freedom \code{Inf}); \code{testing_type} is
#' restricted to \code{"wald"} whenever the estimand is non-conditional. The
#' underlying model fit is identical regardless of estimand — switching
#' \code{estimand} is a pure post-fit transform, never a refit.
#'
#' @references Ferrari, S., and Cribari-Neto, F. (2004). "Beta regression for
#'   modelling rates and proportions." \emph{Journal of Applied Statistics},
#'   31(7), 799-815, \doi{10.1080/0266476042000214501}.
#'
#' @seealso \code{\link[EDI:InferencePropFractionalLogit]{InferencePropFractionalLogit}}
#'   for a quasi-likelihood proportion model that specifies only the
#'   conditional mean. Comparable Python API: no direct beta-regression
#'   equivalent in \pkg{statsmodels}; see
#'   \href{https://www.statsmodels.org/stable/glm.html}{statsmodels GLM} for
#'   the general exponential-family GLM framework. See also:
#'   \href{https://en.wikipedia.org/wiki/Beta_distribution}{Beta
#'   distribution} (Wikipedia).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'proportion')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(runif(10))
#' inf = InferencePropBetaRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferencePropBetaRegr = define_inference_class(
	classname = "InferencePropBetaRegr",
	inherit = Inference,
	# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
	# migration ladders): unlike its 10 AsympLikStdModCache siblings, this
	# class has no pre-registered per-class component (no `*Source`
	# extraction line existed in this file before this migration), so its
	# public=/private= content is declared inline directly rather than
	# hoisted into a separate registered component.
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "StandardModelCache", "MarginalEstimand"),
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio"),
	overrides = list(
		public = c(
			"compute_estimate", "compute_rand_two_sided_pval",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"get_supported_testing_types", "set_testing_type", "compute_estimate_with_bootstrap_weights"
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
			"get_complexity_tier", "get_supported_estimands_impl"
		)
	),
	public = list(
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize inference for the beta regression model
		#'   \eqn{\mathrm{logit}(E[Y_i \mid w_i, x_i]) = \beta_0 + \beta_T w_i +
		#'   x_i^\top \gamma}, \eqn{Y_i \sim \mathrm{Beta}(\mu_i \phi, (1-\mu_i)
		#'   \phi)}; see
		#'   \code{\link[EDI:InferencePropBetaRegr]{InferencePropBetaRegr}} for the
		#'   model form. Does not fit the model; the fit is deferred to the first
		#'   call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with a proportion response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values by default.
		#' @param optimization_alg Character scalar specifying the optimization algorithm. 
		#'   Default is dispatched via policy.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL, optimization_alg = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "proportion")
				assertFormula(model_formula, null.ok = TRUE)
			}
			self$set_optimization_alg(optimization_alg, allow_irls = FALSE)
			super$initialize(des_obj, model_formula = model_formula, verbose = verbose, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Fits the beta regression model by maximum likelihood
		#'   (jointly estimating the mean coefficients and the precision parameter
		#'   \eqn{\phi}). Under the default \code{estimand = "conditional"},
		#'   returns the log-odds-ratio estimate \eqn{\hat\beta_T} on the
		#'   conditional-mean scale. Under \code{estimand = "marginal_mean_diff"}
		#'   (set via \code{set_estimand()}), returns the g-computation
		#'   marginal mean difference instead — see the class-level
		#'   \code{@details} for the formula. The underlying model fit is
		#'   identical either way (a pure post-fit transform of the same
		#'   cached fit, no refit).
		#' @param estimate_only If TRUE, skip standard-error computation and cache
		#'   only the point estimate; used by randomization and bootstrap resampling
		#'   paths.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			if (identical(self$get_estimand(), "marginal_mean_diff")) {
				return(private$compute_marginal_estimand_estimate("marginal_mean_diff", estimate_only = estimate_only))
			}
			# 2026-08-24 (marginal_estimand_report.md TODO-9): re-derive the
			# conditional beta_hat_T/s_beta_hat_T/df from the estimand-invariant
			# private$cached_mod every call, rather than trusting
			# private$cached_values$beta_hat_T/s_beta_hat_T to already hold the
			# conditional values -- same fix TODO-4/5 needed for the same reason.
			mod = private$cached_mod
			if (!is.null(mod)) {
				private$cached_values$beta_hat_T = as.numeric(mod$beta_hat_T %||% mod$b[2L])[1L]
				if (!estimate_only) {
					ssq = mod$ssq_b_2 %||% mod$ssq_b_j
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
		#'   \code{testing_type} for the conditional estimand (score/gradient/
		#'   likelihood-ratio/Bartlett available; see
		#'   \code{\link[EDI:InferenceAsympLik]{InferenceAsympLik}}); under a
		#'   marginal estimand \code{testing_type} is always \code{"wald"} (the
		#'   only value \code{set_estimand()} permits there), so this always
		#'   resolves to the delta-method interval. Calls
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
				lik_ratio = private$compute_lik_ratio_confidence_interval_impl(alpha),
				lik_ratio_bartlett_approx = private$compute_lik_ratio_bartlett_approx_confidence_interval_impl(alpha),
				lik_ratio_bartlett_exact = private$compute_lik_ratio_bartlett_exact_confidence_interval_impl(alpha)
			)
		},
		#' @description Wald two-sided p-value, dispatched by
		#'   \code{testing_type} exactly as
		#'   \code{compute_asymp_confidence_interval()}; see that method's
		#'   description for the marginal-estimand always-Wald note.
		#' @param delta Null treatment-effect value under the current estimand
		#'   (conditional log-odds-ratio, or marginal mean difference).
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
		},
		#' @description Refits the beta model with subject/block-level weights
		#'   applied to the fitting log-likelihood (Bayesian-bootstrap or
		#'   nonparametric-bootstrap draw weights, expanded to row level via
		#'   \code{private$expand_subject_or_block_weights_to_row_weights()}) via
		#'   \code{\link{fast_beta_regression_weighted_cpp}}, and returns the
		#'   reweighted estimate \eqn{\hat\beta_T^{(w)}}. Uses the same QR
		#'   column-dropping hardening as \code{compute_estimate()}; a
		#'   hardened-but-still-unreasonable fit is cached as nonestimable.
		#' @param subject_or_block_weights Bootstrap weights at the subject or block level.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L,
				fit_fun = function(X_fit, keep){
					y_fit = sanitize_beta_response(as.numeric(private$y))
					res = tryCatch({
						n_params = ncol(X_fit) + 1L
						ws_args = private$get_backend_warm_start_args(n_params)
						start_params = ws_args$start_params
						start_beta = if (!is.null(start_params) && length(start_params) >= ncol(X_fit)) {
							start_params[seq_len(ncol(X_fit))]
						} else {
							ws_args$start_beta
						}
						start_phi = if (!is.null(start_params) && length(start_params) >= n_params) {
							exp(start_params[n_params])
						} else {
							10
						}
						fast_beta_regression_weighted_cpp(
							X = X_fit,
							y = y_fit,
							weights = row_weights,
							warm_start_beta = start_beta,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default,
							start_phi = start_phi,
							estimate_only = estimate_only,
							optimization_alg = private$optimization_alg
						)
					}, error = function(e) NULL)
					if (!is.null(res)) {
						coef_vec = as.numeric(res$coefficients)
						if (all(is.finite(coef_vec))) {
							ssq_b_2 = NA_real_
							if (!estimate_only && !is.null(res$fisher_information) &&
							    is.matrix(res$fisher_information) && nrow(res$fisher_information) >= 2L) {
								inv_fi = tryCatch(solve(res$fisher_information), error = function(e) NULL)
								if (!is.null(inv_fi) && is.finite(inv_fi[2L, 2L]) && inv_fi[2L, 2L] > 0) {
									ssq_b_2 = inv_fi[2L, 2L]
								}
							}
							return(list(
								b = coef_vec,
								phi = as.numeric(res$phi),
								fisher_information = res$fisher_information,
								ssq_b_2 = ssq_b_2
							))
						}
					}
					lm_fit = tryCatch(
						stats::lm.wfit(x = X_fit, y = logit(y_fit), w = row_weights),
						error = function(e) NULL
					)
					if (is.null(lm_fit) || length(lm_fit$coefficients) < 2L) return(NULL)
					list(
						b = as.numeric(lm_fit$coefficients),
						phi = NA_real_,
						fisher_information = NULL,
						ssq_b_2 = NA_real_
					)
				},
				fit_ok = function(mod, X_fit, keep){
					!is.null(mod) && length(mod$b) >= 2L && is.finite(mod$b[2L])
				}
			)
			private$cached_mod = attempt$fit
			if (is.null(attempt$fit) || is.null(attempt$fit$b) || length(attempt$fit$b) < 2L || !is.finite(attempt$fit$b[2L])) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			private$cached_values$beta_hat_T = as.numeric(attempt$fit$b[2L])
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = NA_real_
			private$set_fit_warm_start(
				c(as.numeric(attempt$fit$b), if (is.finite(attempt$fit$phi)) log(as.numeric(attempt$fit$phi)) else 0),
				"params",
				fisher = attempt$fit$fisher_information
			)
			private$cached_values$beta_hat_T
		}
	),
	private = list(
		# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
		# migration ladders): see inference_incid_log_regr_private's
		# cached_mod entry (inference_incidence_logit.R) for the eager-NULL-
		# dropping explanation this applies to as well. cached_vc_params was
		# previously undeclared entirely (created dynamically on first
		# assignment, harmless only because lock_objects=FALSE let it spring
		# into existence) -- declared explicitly for the same reason.
		cached_mod = NULL,
		cached_vc_params = NULL,
		# 2026-08-24 (marginal_estimand_report.md TODO-9): every class
		# composing MarginalEstimand supports only "conditional" by default;
		# overridden here to add the g-computation marginal mean difference on
		# the response's natural (proportion) scale. Only "marginal_mean_diff"
		# is wired (not "marginal_ratio") -- a ratio of two mean proportions,
		# both bounded in [0,1], is not the standard estimand for a beta-
		# regression treatment effect the way a rate ratio is for count data.
		# There is no latent submodel to standardize over for a plain beta
		# GLM, so the "marginal" mean function is exactly the model's own
		# fitted mean plogis(X %*% beta) (the precision parameter phi does not
		# enter the mean), unlike the ZOIB mixture family (TODO-4) where the
		# marginal mean also has to fold in separate zero/one-inflation
		# submodels.
		get_supported_estimands_impl = function(){
			c("conditional", "marginal_mean_diff")
		},
		# Standard error of beta_hat_T under the current estimand. Under
		# "conditional", prefers the information-matrix-based SE when
		# available; under a marginal estimand, always the delta-method SE
		# cached by compute_estimate(). Calls self$compute_estimate() first so
		# the estimand-aware cache is always current regardless of call order.
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
		# Degrees of freedom under the current estimand (Inf for a
		# delta-method marginal SE). Calls self$compute_estimate() first so
		# the estimand-aware cache is always current regardless of call order.
		get_degrees_of_freedom = function(){
			self$compute_estimate(estimate_only = FALSE)
			private$cached_values$df %||% Inf
		},
		# Model-implied mean E[Y | w, x] = plogis(X %*% beta) (the beta
		# regression mean submodel; phi does not enter the mean).
		beta_regr_mean_from_coefs = function(beta, X){
			plogis(as.numeric(X %*% beta))
		},
		# G-computation average over the empirical covariate distribution,
		# with every subject plugged in at treatment column (column 2, per
		# build_design_matrix()'s fixed convention) = 1 and = 0.
		beta_regr_marginal_functional = function(beta, X){
			X1 = X; X1[, 2L] = 1
			X0 = X; X0[, 2L] = 0
			mean(private$beta_regr_mean_from_coefs(beta, X1)) - mean(private$beta_regr_mean_from_coefs(beta, X0))
		},
		# Full-fit marginal path for compute_estimate(): reuses the single
		# cached ML fit (private$cached_mod, populated by private$shared() via
		# generate_mod()) -- a pure post-fit transform, no refit. SE via
		# marginal_estimand_delta_se() against the fitted (mean-submodel-only)
		# vcov generate_mod() now retains. Degrees of freedom: Inf, same
		# convention as every other delta-method/sandwich Wald path in this
		# package.
		compute_marginal_estimand_estimate = function(estimand, estimate_only = FALSE){
			mod = private$cached_mod
			if (is.null(mod) || is.null(mod$b) || is.null(mod$X)) {
				private$cache_nonestimable_estimate("beta_regr_marginal_fit_unavailable")
				return(NA_real_)
			}
			functional = function(theta) private$beta_regr_marginal_functional(theta, mod$X)
			point = tryCatch(functional(mod$b), error = function(e) NA_real_)
			if (!is.finite(point)) {
				private$cache_nonestimable_estimate("beta_regr_marginal_point_unavailable")
				return(NA_real_)
			}
			private$cached_values$beta_hat_T = point
			if (estimate_only) return(point)
			if (is.null(mod$vcov)) {
				private$cache_nonestimable_se("beta_regr_marginal_vcov_unavailable")
				return(point)
			}
			dm = marginal_estimand_delta_se(mod$b, mod$vcov, functional)
			private$cached_values$df = Inf
			if (is.finite(dm$se) && dm$se >= 0) {
				private$cached_values$s_beta_hat_T = dm$se
				private$clear_nonestimable_state()
			} else {
				private$cache_nonestimable_se("beta_regr_marginal_se_unavailable")
			}
			point
		},
		best_X_colnames = NULL,
		get_complexity_tier = function() "heavy",
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
			has_vc = isTRUE(is.finite(private$cached_vc_params))
			res = fast_beta_regression_cpp(
				X = X, y = sanitize_beta_response(as.numeric(private$y)),
				warm_start_beta = ws_args$start_beta,
				warm_start_fisher_info = ws_args$warm_start_fisher_info,
				compute_std_errs = FALSE,
				smart_cold_start = private$smart_cold_start_default,
				optimization_alg = private$optimization_alg,
				fixed_idx    = if (has_vc) as.integer(ncol(X) + 1L) else NULL,
				fixed_values = if (has_vc) as.numeric(private$cached_vc_params) else NULL
			)

			if (is.null(res) || !is.finite(res$coefficients[2])){
				return(NA_real_)
			}
			private$set_fit_warm_start(c(as.numeric(res$coefficients), log(as.numeric(res$phi))), "params", fisher = res$fisher_information)
			as.numeric(res$coefficients[2])
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
			b_null = as.numeric(null_fit$b)
			phi    = as.numeric(null_fit$phi)
			if (!is.finite(phi) || phi <= 0) return(NULL)
			mu     = pmin(pmax(plogis(as.numeric(spec$X %*% b_null)), 1e-8), 1 - 1e-8)
			y_sim  = rbeta(length(mu), shape1 = mu * phi, shape2 = (1 - mu) * phi)
			y_sim  = pmin(pmax(y_sim, 1e-8), 1 - 1e-8)
			X_fit  = spec$X
			j      = spec$j
			
			# Parametric bootstrap: use observed fit as anchor for the full fit
			ws_args = private$get_backend_warm_start_args(ncol(X_fit) + 1L)
			full_res = tryCatch(
				fast_beta_regression_cpp(
					X = X_fit, y = y_sim,
					warm_start_beta = ws_args$start_beta,
					warm_start_fisher_info = ws_args$warm_start_fisher_info,
					smart_cold_start = private$smart_cold_start_default,
					optimization_alg = private$optimization_alg
				),
				error = function(e) NULL
			)
			if (is.null(full_res) || length(full_res$coefficients) < j || !is.finite(full_res$coefficients[j])) return(NULL)
			full_fit_boot = list(
				b          = as.numeric(full_res$coefficients),
				phi        = as.numeric(full_res$phi),
				neg_loglik = as.numeric(full_res$neg_loglik)
			)
			list(
				full_fit = full_fit_boot,
				fit_null = function(d, start = NULL){
					ws_args_null = private$get_backend_warm_start_args(ncol(X_fit) + 1L)
					res = tryCatch(
						fast_beta_regression_cpp(
							X = X_fit, y = y_sim,
							warm_start_beta = (if (!is.null(start)) start[seq_len(ncol(X_fit))] else full_fit_boot$b),
							warm_start_fisher_info = ws_args_null$warm_start_fisher_info,
							fixed_idx = j, fixed_values = d,
							smart_cold_start = TRUE,
							optimization_alg = private$optimization_alg
						),
						error = function(e) NULL
					)
					if (is.null(res)) return(NULL)
					list(b = as.numeric(res$coefficients), phi = as.numeric(res$phi), neg_loglik = as.numeric(res$neg_loglik))
				},
				neg_loglik = function(fit) as.numeric(fit$neg_loglik)
			)
		},
		get_likelihood_test_spec = function(){
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			X_fit = ctx$X
			y = sanitize_beta_response(as.numeric(private$y))
			j_treat = as.integer(ctx$j_treat)
			list(
				X = X_fit, y = y, j = j_treat,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					ws_args = private$get_backend_warm_start_args(ncol(X_fit) + 1L)
					res = fast_beta_regression_cpp(
						X_fit, y,
						fixed_idx = j_treat, fixed_values = delta,
						warm_start_beta = if (!is.null(start)) start[1:ncol(X_fit)] else ws_args$start_beta,
						warm_start_fisher_info = ws_args$warm_start_fisher_info,
						smart_cold_start = private$smart_cold_start_default,
						optimization_alg = private$optimization_alg
					)
					if (is.null(res)) return(NULL)
					list(b = as.numeric(res$coefficients), phi = res$phi, neg_loglik = res$neg_loglik, fisher_information = res$fisher_information)
				},
				extract_start = function(fit){
					c(as.numeric(fit$b), log(as.numeric(fit$phi)))
				},
				score = function(fit){
					params = c(as.numeric(fit$b), log(as.numeric(fit$phi)))
					get_beta_regression_score_cpp(X_fit, y, params)
				},
				observed_information = function(fit){
					params = c(as.numeric(fit$b), log(as.numeric(fit$phi)))
					-get_beta_regression_hessian_cpp(X_fit, y, params)
				},
				fisher_information = function(fit){
					fit$fisher_information %||% {
						params = c(as.numeric(fit$b), log(as.numeric(fit$phi)))
						-get_beta_regression_hessian_cpp(X_fit, y, params)
					}
				},
				information = function(fit){
					fit$information %||% fit$fisher_information %||% {
						params = c(as.numeric(fit$b), log(as.numeric(fit$phi)))
						-get_beta_regression_hessian_cpp(X_fit, y, params)
					}
				},
				neg_loglik = function(fit){ as.numeric(fit$neg_loglik) }
			)
		},
		generate_mod = function(estimate_only = FALSE){
			X_full = private$build_design_matrix()
			y_san = sanitize_beta_response(as.numeric(private$y))
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L,
				fit_fun = function(X_fit){
					n_params = ncol(X_fit) + 1L
					ws_args = private$get_backend_warm_start_args(n_params)
					if (estimate_only) {
						res = fast_beta_regression_cpp(
							X_fit, y_san,
							warm_start_beta = ws_args$start_beta,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							compute_std_errs = FALSE,
							smart_cold_start = private$smart_cold_start_default,
							optimization_alg = private$optimization_alg
						)
						if (is.null(res)) return(NULL)
						list(b = res$coefficients, ssq_b_2 = NA_real_, phi = res$phi, neg_loglik = res$neg_loglik, fisher_information = res$fisher_information)
					} else {
						res = fast_beta_regression_with_var_cpp(
							X_fit, y_san,
							warm_start_beta = ws_args$start_beta,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default,
							optimization_alg = private$optimization_alg
						)
						if (is.null(res)) return(NULL)
						list(b = res$coefficients,
						     ssq_b_2 = if (!is.null(res$vcov) && nrow(res$vcov) >= 2L) res$vcov[2L, 2L] else NA_real_,
						     phi = res$phi, neg_loglik = res$neg_loglik, fisher_information = res$fisher_information)
					}
				},

				fit_ok = function(mod, X_fit, keep){
					!is.null(mod) && length(mod$b) >= 2L && is.finite(mod$b[2L]) && max(abs(mod$b), na.rm = TRUE) <= 100
				}
			)
			if (!is.null(attempt$fit)){
				private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
				log_phi = log(as.numeric(attempt$fit$phi))
				if (isTRUE(is.finite(log_phi))) private$cached_vc_params = log_phi
				private$set_fit_warm_start(c(as.numeric(attempt$fit$b), log_phi), "params", fisher = attempt$fit$fisher_information)
				private$cached_values$likelihood_test_context = list(
					X = attempt$X,
					j_treat = which(attempt$keep == 2L)
				)
				# 2026-08-24 (marginal_estimand_report.md TODO-9): stash the
				# exact fitting design matrix and the mean-submodel coefficient
				# covariance (attempt$fit$fisher_information is sized to the
				# mean coefficients only -- see the ssq_b_2 = vcov[2,2] use
				# above, not the joint [b, log_phi] vector) so the
				# marginal-estimand g-computation path (private$compute_
				# marginal_estimand_estimate()) is a pure post-fit transform,
				# no refit -- same convention as InferenceIncidLogRegr/
				# InferenceCountPoisson's mod$X/mod$vcov.
				attempt$fit$X = attempt$X
				attempt$fit$vcov = if (!is.null(attempt$fit$fisher_information)) {
					tryCatch({
						# fisher_information is sized to the JOINT [b, log_phi]
						# parameter vector (verified: ncol/nrow == length(b) + 1),
						# but mod$b is the mean-submodel coefficients alone --
						# invert the full joint information matrix (correct;
						# inverting the mean-only submatrix directly would ignore
						# b/log_phi correlation) and then take only the
						# length(b) x length(b) leading block, matching mod$b's
						# order/length exactly.
						p_b = length(attempt$fit$b)
						solve(attempt$fit$fisher_information)[seq_len(p_b), seq_len(p_b), drop = FALSE]
					}, error = function(e) NULL)
				} else NULL
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
)
