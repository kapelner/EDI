#' Quasi-Poisson Regression Inference for Count Responses
#'
#' Fits a Poisson log-link mean model, \eqn{\log E[Y_i \mid x_i] =
#' x_i^\top\beta}, for count responses using the treatment indicator and,
#' optionally, all recorded covariates as predictors, via
#' \code{\link{fast_quasipoisson_regression_with_var_cpp}} — see that page for
#' the full model and the Pearson-dispersion-scaled ("quasi-Poisson") variance
#' formula, \eqn{\widehat{\mathrm{Var}}(\hat\beta_k) = \hat\phi\,[(X^\top
#' \hat{W}X)^{-1}]_{kk}}, which corrects standard errors for overdispersion
#' (\eqn{\mathrm{Var}(Y_i) > E[Y_i]}) relative to the strict Poisson assumption
#' without changing the point estimate \eqn{\hat\beta}. This class has no
#' likelihood-ratio/score/gradient testing capability
#' (\code{likelihood_tier = "quasi"}): the dispersion-scaled quasi-likelihood is
#' not a normalized model likelihood, so only Wald inference is available.
#' Rank-deficient covariate columns are dropped automatically before fitting
#' (via \code{private$fit_with_hardened_qr_column_dropping()}).
#'
#' \strong{Estimand.} Composes
#' \code{\link[EDI:InferenceMarginalEstimand]{MarginalEstimand}}
#' (\code{set_estimand()}/\code{get_estimand()}/\code{get_supported_estimands()}).
#' Under the default \code{estimand = "conditional"}, \eqn{\hat\beta_T} is the
#' treatment log-rate-ratio. Under \code{"marginal_mean_diff"} it is the
#' g-computed difference in the average fitted count under treatment vs. control,
#' \eqn{\frac{1}{n}\sum_i \{\exp(x_{i1}^\top\hat\beta) -
#' \exp(x_{i0}^\top\hat\beta)\}}, with every subject plugged in at treatment 1
#' and 0. \code{"marginal_ratio"} is the log of the corresponding ratio, which for
#' this log-link family equals the conditional \eqn{\hat\beta_T} exactly (there is
#' no treatment-by-covariate term), so it is offered for estimand-API consistency;
#' its delta-method SE equals the conditional SE. Under a marginal estimand the
#' standard error is the delta-method SE against the dispersion-scaled coefficient
#' covariance \eqn{\hat\phi (X^\top \hat W X)^{-1}}, i.e. the plain-Poisson
#' marginal SE inflated by \eqn{\sqrt{\hat\phi}}, with a normal reference
#' (degrees of freedom \code{Inf}). Switching the estimand is a pure post-fit
#' transform of the cached fit, never a refit. The Bayesian-bootstrap weighted
#' refit is not estimand-aware: it always targets the conditional coefficient.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'count')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rpois(10, 2))
#' inf = InferenceCountQuasiPoisson$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceCountQuasiPoisson = define_inference_class(
	classname = "InferenceCountQuasiPoisson",
	inherit = Inference,
	components = c("CountCompositeLikelihood", "BayesianBootstrap", "Wald", "MarginalEstimand"),
	public = list(
		#' @description Uses the shared randomization two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceRand]{InferenceRand}}.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
				
		#' @description Initialize a quasi-Poisson regression inference object for a
		#'   completed design with a count, uncensored response.
		#' @param des_obj A completed \code{Design} object with a count response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose  		Whether to print progress messages.
		#' @param harden  		Whether to apply robustness measures.
		#' @param smart_cold_start_default Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL, harden = TRUE){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "count")
			}
			super$initialize(des_obj, verbose = verbose, harden = harden, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Computes the quasi-Poisson point estimate via
		#'   \code{\link{fast_quasipoisson_regression_with_var_cpp}} (see class
		#'   documentation for the full model). Under the default
		#'   \code{estimand = "conditional"} this is the treatment coefficient
		#'   \eqn{\hat\beta_T}; under \code{"marginal_mean_diff"} or
		#'   \code{"marginal_ratio"} (set via \code{set_estimand()}) it is the
		#'   g-computed marginal mean difference / log ratio, a pure post-fit
		#'   transform of the same cached fit (no refit). Rank-deficient covariate
		#'   columns are dropped before fitting.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			estimand = self$get_estimand()
			if (estimand %in% c("marginal_mean_diff", "marginal_ratio")) {
				return(private$compute_marginal_estimand_estimate(estimand, estimate_only = estimate_only))
			}
			# Re-derive the conditional beta/SE from the estimand-invariant cached fit on every call, so switching back from a
			# marginal estimand never returns stale marginal numbers (same pattern as InferenceCountPoisson).
			mod = private$cached_mod
			if (!is.null(mod) && !is.null(mod$b)) {
				j_treat = mod$j_treat %||% 2L
				private$cached_values$beta_hat_T = as.numeric(mod$b[j_treat])
				if (!estimate_only) {
					ssq = mod$ssq_b_j %||% mod$ssq_b_2
					if (!is.null(ssq) && is.finite(ssq) && ssq > 0) {
						private$cached_values$s_beta_hat_T = sqrt(ssq)
						private$cached_values$df = mod$df %||% Inf
						private$clear_nonestimable_state()
					} else {
						private$cache_nonestimable_se("model_standard_error_unavailable")
					}
				}
			}
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the Poisson-mean-model treatment estimate under
		#'   subject/block bootstrap weights (via
		#'   \code{\link{fast_poisson_regression_weighted_cpp}}), used by the
		#'   Bayesian bootstrap and related weighted-resampling machinery; see
		#'   \code{\link[EDI:InferenceBayesianBootstrap]{InferenceBayesianBootstrap}}.
		#'   When \code{estimate_only = FALSE}, also computes a weighted
		#'   Pearson-dispersion-scaled standard error (fixed 2026-09-07 --
		#'   previously always \code{NA} regardless of \code{estimate_only},
		#'   which starved the Bayesian-bootstrap studentized/BCa variants of a
		#'   per-replicate SE and left them NA on the large majority of calls).
		#'   The weighted refit always targets the conditional treatment
		#'   coefficient, whatever the active estimand (it is not estimand-aware).
		#' @param subject_or_block_weights Bootstrap weights at the subject or block level.
		#' @param estimate_only If TRUE, skip the dispersion-correction computation.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = private$build_design_matrix(),
				required_cols = 2L,
				fit_fun = function(X_fit, keep){
					res = tryCatch(
						fast_poisson_regression_weighted_cpp(
							X = X_fit,
							y = as.numeric(private$y),
							weights = row_weights,
							warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
							smart_cold_start = private$smart_cold_start_default,
							warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit))
						),
						error = function(e) NULL
					)
					if (is.null(res)) return(NULL)
					j_treat = which(keep == 2L)
					ssq_b_j = NA_real_
					if (!estimate_only && length(j_treat) == 1L && !is.null(res$mu) && !is.null(res$XtWX)) {
						# Same weighted Pearson-dispersion-scaled variance as
						# fast_quasipoisson_regression_with_var_cpp's own unweighted
						# formula (fast_poisson_regression.cpp:569-585): dispersion =
						# sum(w_i*(y_i-mu_i)^2/mu_i) / df_resid, ssq_b_j = dispersion *
						# solve(XtWX)[j,j], just with row_weights folded into the
						# Pearson sum and XtWX already the weighted Fisher info this
						# fit returned.
						mu_hat = as.numeric(res$mu)
						df_resid = nrow(X_fit) - ncol(X_fit)
						if (df_resid > 0 && all(mu_hat > 0)) {
							dispersion = sum(row_weights * (as.numeric(private$y) - mu_hat)^2 / mu_hat) / df_resid
							if (is.finite(dispersion) && dispersion > .Machine$double.eps) {
								inv_jj = tryCatch(solve(res$XtWX)[j_treat, j_treat], error = function(e) NA_real_)
								if (is.finite(inv_jj) && inv_jj > 0) ssq_b_j = dispersion * inv_jj
							}
						}
					}
					list(b = res$b, XtWX = res$XtWX %||% res$fisher_information, ssq_b_j = ssq_b_j, j_treat = j_treat)
				},
				fit_ok = function(mod, X_fit, keep){
					j_treat = mod$j_treat
					!is.null(mod) && length(mod$b) >= j_treat && is.finite(mod$b[j_treat])
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
			ssq = attempt$fit$ssq_b_j
			private$cached_values$s_beta_hat_T = if (!is.null(ssq) && is.finite(ssq) && ssq > .Machine$double.eps) sqrt(ssq) else NA_real_
			private$cached_values$df = NA_real_
			private$set_fit_warm_start(as.numeric(attempt$fit$b), "beta", fisher = attempt$fit$XtWX)
			private$cached_values$beta_hat_T
		},
		#' @description Computes a \eqn{1-\alpha} level Wald confidence interval for the
		#'   active estimand. Under the default conditional estimand this is the
		#'   quasi-Poisson treatment coefficient \eqn{\hat\beta_T} with the
		#'   Pearson-dispersion-scaled standard error from
		#'   \code{\link{fast_quasipoisson_regression_with_var_cpp}} (see class
		#'   documentation); under a marginal estimand it is the g-computed functional
		#'   with its delta-method standard error. Both use a normal reference. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
		#'   asymptotic confidence-interval contract this delegates to.
		#' @param alpha Confidence level.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			self$compute_estimate(estimate_only = FALSE)
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Computes a two-sided Wald p-value testing \eqn{H_0:
		#'   \beta_T = \code{delta}} under the conditional estimand, or that the
		#'   active marginal functional equals \code{delta} under a marginal
		#'   estimand, from the same standard error used by
		#'   \code{$compute_asymp_confidence_interval()} (normal reference). See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
		#'   asymptotic two-sided p-value contract this delegates to.
		#' @param delta Null treatment effect value.
		compute_asymp_two_sided_pval = function(delta = 0){
			self$compute_estimate(estimate_only = FALSE)
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		}
	),
	private = list(
		best_X_colnames = NULL,
		# Conditional plus the g-computed marginal mean difference / log-ratio of the average fitted count.
		get_supported_estimands_impl = function(){
			c("conditional", "marginal_mean_diff", "marginal_ratio")
		},
		# Estimand-aware SE / df: under a marginal estimand the dispersion-scaled coefficient SE is NOT the functional's SE, so
		# return the delta-method SE cached by compute_estimate() (calling it first keeps the cache current regardless of call order).
		get_standard_error = function(){
			self$compute_estimate(estimate_only = FALSE)
			private$cached_values$s_beta_hat_T
		},
		get_degrees_of_freedom = function(){
			self$compute_estimate(estimate_only = FALSE)
			private$cached_values$df %||% Inf
		},
		# Shared with InferenceCountPoisson (helper_marginal_estimand.R); thin wrappers keep the private API.
		quasipoisson_mean_from_coefs = function(beta, X){
			poisson_family_mean_from_coefs(beta, X)
		},
		quasipoisson_marginal_functional = function(beta, X, estimand){
			poisson_family_marginal_functional(beta, X, estimand)
		},
		# Pure post-fit transform of the cached quasi-Poisson fit (no refit): delta-method SE against the dispersion-scaled
		# covariance phi * (X'WX)^-1 that generate_mod() stores as mod$vcov. df = Inf, as for every other delta-method Wald path.
		compute_marginal_estimand_estimate = function(estimand, estimate_only = FALSE){
			if (!estimate_only && !is.null(private$cached_mod) && is.null(private$cached_mod$vcov)) {
				# the cached fit came from an estimate-only pass (no dispersion / covariance): refit with variance
				private$cached_values$s_beta_hat_T = NULL
				private$shared(estimate_only = FALSE)
			}
			poisson_family_marginal_estimand_estimate(private, private$cached_mod, estimand, estimate_only, reason_prefix = "quasipoisson")
		},
		build_design_matrix = function(){
			X_cov = private$X
			if (is.null(X_cov) || ncol(X_cov) == 0) {
				X = cbind(`(Intercept)` = 1, treatment = private$w)
			} else {
				X = cbind(`(Intercept)` = 1, treatment = private$w, X_cov)
			}
			X
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
			res = tryCatch(fast_poisson_regression_cpp(X = X, y = as.numeric(private$y), estimate_only = TRUE), error = function(e) NULL)
			if (is.null(res) || !is.finite(res$b[2])){
				return(NA_real_)
			}
			as.numeric(res$b[2])
		},
		supports_reusable_bootstrap_worker = function(){
			TRUE
		},
		generate_mod = function(estimate_only = FALSE){
			# Use the common GLM fitting pattern
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = private$build_design_matrix(),
				fit_fun = function(X_fit, keep){
					j_treat = which(keep == 2L)
					ws_args = private$get_backend_warm_start_args(ncol(X_fit))
					if (estimate_only) {
						res = fast_poisson_regression_cpp(
							X = X_fit, y = private$y,
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_weights = ws_args$warm_start_weights,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default,
							estimate_only = TRUE
						)
						list(b = res$b, XtWX = res$XtWX, w = res$w, ssq_b_j = NA_real_, j_treat = j_treat)
					} else {
						res = fast_quasipoisson_regression_with_var_cpp(
							X = X_fit, y = private$y, j = j_treat,
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_weights = ws_args$warm_start_weights,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default
						)
						res$j_treat = j_treat
						res
					}
				},
				fit_ok = function(mod, X_fit, keep){
					j_treat = mod$j_treat
					if (is.null(mod) || length(mod$b) < j_treat || !is.finite(mod$b[j_treat])) return(FALSE)
					if (estimate_only) return(TRUE)
					is.finite(mod$ssq_b_j) && mod$ssq_b_j > .Machine$double.eps
				}
			)
			if (!is.null(attempt$fit)){
				# Stash the fitting design and the dispersion-scaled coefficient covariance so the marginal-estimand path is a
				# post-fit transform (the with_var kernel returns dispersion and mu but no information matrix).
				attempt$fit$X = attempt$X
				if (!is.null(attempt$fit$dispersion) && !is.null(attempt$fit$mu)) {
					info = crossprod(attempt$X * sqrt(as.numeric(attempt$fit$mu)))
					attempt$fit$vcov = tryCatch(as.numeric(attempt$fit$dispersion) * solve(info), error = function(e) NULL)
				}
				private$cached_values$likelihood_test_context = list(
					X = attempt$X,
					j_treat = which(attempt$keep == 2L)
				)
				private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
			} else {
				private$cached_values$likelihood_test_context = NULL
			}
			attempt$fit
		}
		),
		metadata = list(likelihood_tier = "quasi"),
		overrides = list(
			public = c(
				"compute_estimate", "compute_estimate_with_bootstrap_weights",
				"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
				"compute_rand_two_sided_pval"
			),
			private = c(
				"best_X_colnames", "build_design_matrix",
				"compute_treatment_estimate_during_randomization_inference",
				"supports_reusable_bootstrap_worker", "generate_mod",
				"get_standard_error", "get_degrees_of_freedom",
				"get_supported_testing_types_impl", "get_supported_estimands_impl",
				"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
				"mark_jackknife_nonestimable_if_block_unsupported",
				"create_bootstrap_worker_state", "load_bootstrap_sample_into_worker",
				"compute_bootstrap_worker_estimate"
			)
		)
	)
