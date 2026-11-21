OrdinalOrderedProbitLikelihoodSource = list(
	public = list(
		# @description Initialize inference for the ordered probit model; see
		#   \code{\link[EDI:InferenceOrdinalOrderedProbitRegr]{InferenceOrdinalOrderedProbitRegr}}
		#   for the model form. Does not fit the model; the fit is deferred to the
		#   first call to \code{compute_estimate()} or a method that requires it.
		# @param des_obj A completed \code{Design} object with an ordinal response.
		# @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#   the formula from the design object is used and its pre-computed design matrix is
		#   reused. If a formula is provided, a new design matrix is constructed from the
		#   design's imputed covariates.
		# @param verbose Whether to print progress messages.
		# @param smart_cold_start_default Whether to use smart cold start values by default.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL){
			ordinal_cumlink_initialize(super, private, des_obj, model_formula, verbose, smart_cold_start_default)
		},
		# @description Recomputes the treatment estimate under subject/block-level
		#   bootstrap weights (Bayesian-bootstrap or nonparametric-bootstrap draw
		#   weights) via \code{weighted_ordinal_bootstrap_surrogate_fit()}, a fast
		#   weighted ordinal-probit surrogate fit on the raw design matrix, as an
		#   approximation to the weighted ordered-probit likelihood. No standard
		#   error is computed (\code{s_beta_hat_T} is always \code{NA}); the
		#   surrogate returns \code{NA} if the fit fails.
		# @param subject_or_block_weights Subject-, block-, cluster-, or matched-set
		#   bootstrap weights.
		# @param estimate_only If \code{TRUE}, compute only the weighted point
		#   estimate.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			ordinal_surrogate_estimate_with_bootstrap_weights(private, subject_or_block_weights, method = "probit")
		}
	),
	private = list(
		best_X_colnames = NULL,
		get_complexity_tier = function() "heavy",
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			ordinal_cumlink_rand_estimate(self, private, estimate_only, fast_ordinal_probit_regression_cpp,
				warm_start_args = private$get_backend_warm_start_args)
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
		supports_fisher_information = function(){
			TRUE
		},
		simulate_under_lik_null = function(spec, delta, null_fit){
			ordinal_cumlink_simulate_under_lik_null(private, spec, null_fit, fast_ordinal_probit_regression_cpp, stats::pnorm)
		},
		get_likelihood_test_spec = function(){
			ordinal_cumlink_likelihood_test_spec(private, fast_ordinal_probit_regression_cpp,
				score_fn = get_ordinal_probit_regression_score_cpp,
				hessian_fn = get_ordinal_probit_regression_hessian_cpp, link = "probit")
		},
		generate_mod = function(estimate_only = FALSE){
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(implicit_intercept = TRUE, 
				X_full = X_full,
				required_cols = 1L,
				fit_fun = function(X_fit){
					n_params = ncol(X_fit) + length(sort(unique(private$y))) - 1L
					ws_args = private$get_backend_warm_start_args(n_params)
					if (estimate_only) {
						ws_fisher = ws_args$warm_start_fisher_info
						res = ordinal_fit_scaled(fast_ordinal_probit_regression_cpp,
							X_fit, private$y,
							warm_start_params = ws_args$start_params,
							warm_start_fisher_info = ws_fisher,
							smart_cold_start = private$smart_cold_start_default,
							estimate_only = TRUE
						)
						if (is.null(res) || length(res) == 0) return(NULL)
						list(b = res$b, ssq_b_j = NA_real_, params = res$params, observed_information = ws_fisher)
					} else {
						res = ordinal_fit_scaled(fast_ordinal_probit_regression_with_var_cpp,
							X_fit, private$y,
							warm_start_params = ws_args$start_params,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default
						)
						if (is.null(res) || length(res$b) == 0 || is.na(res$b[1])) return(NULL)
						list(b = res$b, ssq_b_j = res$ssq_b_j, params = res$params, neg_loglik = res$neg_loglik, observed_information = res$observed_information)
					}
				},
				fit_ok = function(mod, X_fit, keep){
					# treatment is b[1] (X's first column); see the comment on
					# compute_treatment_estimate_during_randomization_inference()
					# above -- this used to gate on b[length(mod$b)], the last
					# covariate's coefficient, not treatment's.
					if (is.null(mod) || length(mod$b) < 1L || !is.finite(mod$b[1])) return(FALSE)
					if (estimate_only) return(TRUE)
					ssq = mod$ssq_b_j
					!is.null(ssq) && is.finite(ssq) && ssq > 0
				}
			)
			if (!is.null(attempt$fit)){
				private$set_fit_warm_start(attempt$fit$params, "params", fisher = attempt$fit$observed_information)
				private$best_X_colnames = setdiff(colnames(attempt$X), "treatment")
				if (!estimate_only) {
					n_alpha = length(attempt$fit$params) - ncol(attempt$X)
					private$cached_values$likelihood_test_context = list(
						X = attempt$X,
						j_treat = as.integer(n_alpha + 1L),
						full_params = attempt$fit$params,
						full_neg_loglik = attempt$fit$neg_loglik
					)
				}
				list(b = c(0, attempt$fit$b[1]), ssq_b_2 = attempt$fit$ssq_b_j)
			} else {
				private$cached_values$likelihood_test_context = NULL
				NULL
			}
		},
		build_design_matrix = function(){
			X_cov = private$get_X()
			if (is.null(X_cov) || ncol(X_cov) == 0) {
				X = matrix(private$w, ncol = 1L)
				colnames(X) = "treatment"
			} else {
				X = cbind(treatment = private$w, X_cov)
			}
			X
		}
	)
)

#' Ordered Probit Regression Inference for Ordinal Responses
#'
#' Fits a cumulative-probit ("ordered probit") model for ordinal responses:
#' \eqn{\Phi^{-1}(P(Y_i \le k)) = \alpha_k - (\beta_T W_i + X_i^\top \gamma)},
#' for cutpoints \eqn{\alpha_1 < \cdots < \alpha_{K-1}}, where \eqn{\Phi} is
#' the standard normal CDF, \eqn{W_i} is the treatment indicator, and
#' \eqn{X_i} are optional recorded covariates, by maximum likelihood
#' (\code{\link{fast_ordinal_probit_regression_cpp}}/
#' \code{\link{fast_ordinal_probit_regression_with_var_cpp}}). As with binary
#' probit regression, \eqn{\hat\beta_T} is not an odds-ratio-scale parameter:
#' it is the treatment's effect on the latent standard-normal index
#' underlying the ordinal categories. \code{likelihood_tier = "full"}:
#' likelihood-ratio, score, gradient, and Wald tests are all available when
#' the model converges, plus parametric-likelihood-bootstrap calibration of
#' the likelihood-ratio test. Validity requires the proportional/parallel
#' cutpoints assumption (a single \eqn{\beta_T} shared across all cutpoints)
#' in addition to the usual latent-normal-index assumption.
#'
#' A response with fewer than two observed levels has no cutpoints to fit, so
#' the estimate (and every test and interval built on it) is \code{NA}.
#' Bootstrap and other resampling draws whose response has a single level are
#' unusable and are dropped from the resampling distribution, as for
#' \code{\link[EDI:InferenceOrdinalCauchitRegr]{InferenceOrdinalCauchitRegr}}
#' and \code{\link[EDI:InferenceOrdinalCloglogRegr]{InferenceOrdinalCloglogRegr}}.
#' (Before v1.0.6 this class returned an estimate of 0 in that case, and such
#' draws entered the bootstrap distribution as exact zeros.)
#'
#' @references McCullagh, P. (1980). "Regression Models for Ordinal Data."
#'   \emph{Journal of the Royal Statistical Society, Series B}, 42(2),
#'   109-127, \doi{10.1111/j.2517-6161.1980.tb01109.x}, for the cumulative-link
#'   ordinal model family this class's probit link instantiates.
#'
#' @seealso \code{\link[EDI:InferenceOrdinalCauchitRegr]{InferenceOrdinalCauchitRegr}},
#'   \code{\link[EDI:InferenceOrdinalCloglogRegr]{InferenceOrdinalCloglogRegr}}
#'   for other cumulative-link function choices on the same ordinal model
#'   family. See also:
#'   \href{https://en.wikipedia.org/wiki/Ordinal_regression}{Ordinal
#'   regression} and \href{https://en.wikipedia.org/wiki/Probit_model}{Probit
#'   model} (Wikipedia).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'ordinal')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(sample(1:4, 10, replace = TRUE))
#' inf = InferenceOrdinalOrderedProbitRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' @inheritSection InferenceContinOLS Blocking designs
#' @eval rd_small_sample_section("InferenceOrdinalOrderedProbitRegr")
#' @section Constructor:
#' \code{InferenceOrdinalOrderedProbitRegr$new(des_obj, model_formula = NULL, verbose = FALSE,
#' smart_cold_start_default = NULL)}
#' \describe{
#'   \item{\code{des_obj}}{A completed \code{Design} object with an ordinal,
#'     uncensored response.}
#'   \item{\code{model_formula}}{Optional formula for covariate adjustment. If
#'     \code{NULL} (default), the formula from the design object is used and its
#'     pre-computed design matrix is reused. If a formula is provided, a new design
#'     matrix is constructed from the design's imputed covariates.}
#'   \item{\code{verbose}}{Whether to print progress messages. Default \code{FALSE}.}
#'   \item{\code{smart_cold_start_default}}{Whether to use smart cold start values by
#'     default for the likelihood fit. Explicit starts always override this
#'     object-level policy. \code{NULL} (default) consults the global cold-start
#'     dispatch policy.}
#' }
#' These are the only arguments. The inherited \code{Inference$new()} entry below
#' also lists \code{harden} and \code{seed}, but this constructor does not take
#' them (passing either is an "unused argument" error): the base class's default
#' \code{harden = TRUE} always applies, and the seed for the resampling methods is
#' set after construction with \code{$set_seed()}.
#' @export
InferenceOrdinalOrderedProbitRegr = define_inference_class(
	classname = "InferenceOrdinalOrderedProbitRegr",
	inherit = Inference,
	components = c(
		"RandomizationCI",
		"RandomizationBootstrapCI",
		"BayesianBootstrap",
		"Jackknife",
		"ParametricLikelihoodBootstrap",
		"OrdinalOrderedProbitLikelihood"
	),
	metadata = list(likelihood_tier = "full", response_types = "ordinal"),
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
			"get_complexity_tier", "supports_fisher_information"
		)
	),
	public = list(
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	)
)


#' @R6method InferenceOrdinalOrderedProbitRegr$approximate_randomization_distribution_beta_hat_T
#' @template rand-approx-distribution-beta-hat-t
NULL

#' @R6method InferenceOrdinalOrderedProbitRegr$supports_rand_pval_for_incidence
#' @template rand-supports-pval-incidence
NULL

#' @R6method InferenceOrdinalOrderedProbitRegr$compute_rand_two_sided_pval
#' @template rand-compute-rand-two-sided-pval-params
NULL

# Shared cumulative-link ordinal helpers (v1.0.6-TODO-193; code-duplication
# audit dup-4ca7ca9c9237 and dup-86f70c0a1fbe). The ordered-probit,
# proportional-odds and cauchit classes repeated these bodies, differing only in
# the C++ fitter / score / Hessian, the link CDF and (cauchit) how the warm start
# is read. Each class keeps its private/public method as a one-line wrapper.

#' @keywords internal
#' @noRd
ordinal_cumlink_initialize = function(super, private, des_obj, model_formula, verbose, smart_cold_start_default) {
	if (should_run_asserts()) {
		assertResponseType(des_obj$get_response_type(), "ordinal")
		assertFormula(model_formula, null.ok = TRUE)
	}
	super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
	if (should_run_asserts()) {
		assertNoCensoring(private$any_censoring)
	}
}

# compute_estimate_with_bootstrap_weights(): the weighted surrogate fit
# (weighted_ordinal_bootstrap_surrogate_fit()) on the columns the full fit kept.
# No standard error is computed.
#' @keywords internal
#' @noRd
ordinal_surrogate_estimate_with_bootstrap_weights = function(private, subject_or_block_weights, method) {
	row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
	X_fit = private$build_design_matrix()
	if (!is.null(private$best_X_colnames)) {
		keep = c("treatment", intersect(private$best_X_colnames, colnames(X_fit)))
		X_fit = X_fit[, keep, drop = FALSE]
	}
	fit = weighted_ordinal_bootstrap_surrogate_fit(X_fit, private$y, row_weights, method = method)
	if (is.null(fit) || !is.finite(fit$beta_hat)) {
		private$cached_values$beta_hat_T = NA_real_
		private$cached_values$s_beta_hat_T = NA_real_
		private$cached_values$df = NA_real_
		return(NA_real_)
	}
	private$cached_values$beta_hat_T = as.numeric(fit$beta_hat)
	private$cached_values$s_beta_hat_T = NA_real_
	private$cached_values$df = NA_real_
	private$cached_values$full_coefficients = fit$coefficients
	private$cached_values$summary_table = NULL
	private$cached_values$beta_hat_T
}

# compute_treatment_estimate_during_randomization_inference(): refit on the
# columns the full fit kept, estimate only. warm_start_args(n_params) returns
# list(start_params, warm_start_fisher_info).
#' @keywords internal
#' @noRd
ordinal_cumlink_rand_estimate = function(self, private, estimate_only, fit_fn, warm_start_args) {
	if (is.null(private$best_X_colnames)){
		private$shared(estimate_only = TRUE)
	}
	if (is.null(private$best_X_colnames)){
		return(self$compute_estimate(estimate_only = estimate_only))
	}
	X_cols = private$best_X_colnames
	X_data = private$get_X()
	if (length(X_cols) == 0L){
		X = matrix(private$w, ncol = 1L)
		colnames(X) = "treatment"
	} else {
		X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
		X = cbind(treatment = private$w, X_cov)
	}
	n_params = ncol(X) + length(sort(unique(private$y))) - 1L
	ws_args = warm_start_args(n_params)
	ws_fisher = ws_args$warm_start_fisher_info
	res = ordinal_fit_scaled(fit_fn,
		X = X, y = as.numeric(private$y),
		warm_start_params = ws_args$start_params,
		warm_start_fisher_info = ws_fisher,
		smart_cold_start = private$smart_cold_start_default,
		estimate_only = TRUE
	)
	# treatment is X's first column (cbind(treatment = ..., X_cov) above), and
	# res$b follows X's column order: b[1] is the treatment slope, matching
	# generate_mod()'s own extraction. res$b[length(res$b)] (the last
	# covariate's slope whenever design_formula includes covariates) fed the
	# randomization test a covariate's coefficient instead of treatment's.
	if (is.null(res) || length(res$b) < 1L || !is.finite(res$b[1])){
		return(NA_real_)
	}
	private$set_fit_warm_start(as.numeric(res$params), "params", fisher = ws_fisher)
	as.numeric(res$b[1])
}

# simulate_under_lik_null(): parametric-bootstrap draw from the null fit through
# the link CDF, then the full refit (anchored at the policy warm start) and the
# null refit closure.
#' @keywords internal
#' @noRd
ordinal_cumlink_simulate_under_lik_null = function(private, spec, null_fit, fit_fn, cdf) {
	params_null = as.numeric(null_fit$params)
	y_sim       = private$simulate_param_boot_ordinal_y(spec$X, params_null, spec$y, cdf)
	if (is.null(y_sim)) return(NULL)
	X_fit    = spec$X
	j        = spec$j
	# Parametric bootstrap: use observed fit as anchor
	ws_args = private$get_backend_warm_start_args(length(params_null))
	full_res = tryCatch(
		ordinal_fit_scaled(fit_fn,
			X_fit, y_sim,
			warm_start_params = ws_args$start_params,
			warm_start_fisher_info = ws_args$warm_start_fisher_info,
			smart_cold_start = private$smart_cold_start_default
		),
		error = function(e) NULL
	)
	if (is.null(full_res) || length(full_res$params) == 0L) return(NULL)
	full_fit_boot = list(params = as.numeric(full_res$params), neg_loglik = as.numeric(full_res$neg_loglik))
	if (!is.finite(full_fit_boot$neg_loglik)) return(NULL)
	list(
		worker_data = list(y = y_sim),
		full_fit = full_fit_boot,
		fit_null = function(d, start = NULL){
			ws_args_null = private$get_backend_warm_start_args(length(params_null))
			res = tryCatch(
				ordinal_fit_scaled(fit_fn,
					X_fit, y_sim,
					warm_start_params = start %||% full_fit_boot$params,
					warm_start_fisher_info = ws_args_null$warm_start_fisher_info,
					fixed_idx = j, fixed_values = d,
					smart_cold_start = TRUE
				),
				error = function(e) NULL
			)
			if (is.null(res) || length(res) == 0L) return(NULL)
			list(params = as.numeric(res$params), neg_loglik = as.numeric(res$neg_loglik))
		},
		neg_loglik = function(fit) as.numeric(fit$neg_loglik)
	)
}

# CDF and density of each cumulative link, matching the C++ kernels in
# ordinal_fixed_link_helpers.h (cloglog: F(z) = 1 - exp(-exp(z))).
#' @keywords internal
#' @noRd
ordinal_cumlink_link_cdf_pdf = function(link) {
	switch(link,
		logit = list(cdf = stats::plogis, pdf = stats::dlogis),
		probit = list(cdf = stats::pnorm, pdf = stats::dnorm),
		cauchit = list(cdf = stats::pcauchy, pdf = stats::dcauchy),
		cloglog = list(cdf = function(z) -expm1(-exp(z)), pdf = function(z) exp(z - exp(z))),
		stop("unknown cumulative link: ", link, call. = FALSE)
	)
}

# Expected (Fisher) information of the cumulative-link ordinal model
# P(Y_i <= k | x_i) = F(z_ik), z_ik = alpha_k + eta_sign * x_i'beta, k = 1..K-1,
# in the solvers' native parameterization params = c(alpha, beta) (raw,
# increasing thresholds; eta_sign = -1 for logit/probit/cauchit, +1 for the
# cloglog solver). With pi_ik = F(z_ik) - F(z_i,k-1) (F(z_i0) = 0,
# F(z_iK) = 1) and f = F', the information is
#   I = sum_i sum_k (d pi_ik / d par)(d pi_ik / d par)' / pi_ik,
# which in blocks is
#   I[a_m, a_m]     = sum_i f_im^2 (1 / pi_im + 1 / pi_i,m+1)
#   I[a_m, a_m+1]   = -sum_i f_im f_i,m+1 / pi_i,m+1      (tridiagonal)
#   I[a_m, beta]    = eta_sign * sum_i f_im (d_im / pi_im - d_i,m+1 / pi_i,m+1) x_i'
#   I[beta, beta]   = sum_i x_i x_i' sum_k d_ik^2 / pi_ik
# with d_ik = f_ik - f_i,k-1 (f_i0 = f_iK = 0). It does not depend on y beyond
# its level set (the K categories), and it is the y-expectation of the
# observed information -hessian_fn(X, y, params). Verified against the exact
# expectation of the C++ score outer product and of the C++ negative Hessian
# (relative error < 1e-14) for all four links, v1.0.6-TODO-201; see
# R/package_metadata/audits/research_findings/2026-11-19-ordinal-cumulative-link-expected-information.md.
# Category probabilities are floored at 1e-12, as in the C++ likelihood.
# Returns NULL when params are not a valid (finite, increasing-threshold) point.
#' @keywords internal
#' @noRd
ordinal_cumlink_expected_information = function(X, y, params, link, eta_sign = -1) {
	X = as.matrix(X)
	params = as.numeric(params)
	K = length(unique(as.numeric(y)))
	n_alpha = K - 1L
	p = ncol(X)
	if (n_alpha < 1L || length(params) != n_alpha + p || any(!is.finite(params))) return(NULL)
	a = seq_len(n_alpha)
	b = n_alpha + seq_len(p)
	alpha = params[a]
	if (n_alpha > 1L && any(diff(alpha) <= 0)) return(NULL)
	cf = ordinal_cumlink_link_cdf_pdf(link)
	Z = outer(eta_sign * as.numeric(X %*% params[b]), alpha, "+")
	Fz = matrix(cf$cdf(Z), nrow(X))
	fz = matrix(cf$pdf(Z), nrow(X))
	Fext = cbind(0, Fz, 1)
	fext = cbind(0, fz, 0)
	pi_ik = pmax(Fext[, -1L, drop = FALSE] - Fext[, -(K + 1L), drop = FALSE], 1e-12)
	d_ik = fext[, -1L, drop = FALSE] - fext[, -(K + 1L), drop = FALSE]
	ratio = d_ik / pi_ik
	info = matrix(0, n_alpha + p, n_alpha + p)
	info[cbind(a, a)] = colSums(fz^2 * (1 / pi_ik[, a, drop = FALSE] + 1 / pi_ik[, a + 1L, drop = FALSE]))
	if (n_alpha > 1L) {
		off = -colSums(fz[, -n_alpha, drop = FALSE] * fz[, -1L, drop = FALSE] / pi_ik[, 2:n_alpha, drop = FALSE])
		info[cbind(1:(n_alpha - 1L), 2:n_alpha)] = off
		info[cbind(2:n_alpha, 1:(n_alpha - 1L))] = off
	}
	info_ab = eta_sign * crossprod(fz * (ratio[, a, drop = FALSE] - ratio[, a + 1L, drop = FALSE]), X)
	info[a, b] = info_ab
	info[b, a] = t(info_ab)
	info[b, b] = crossprod(X, X * rowSums(d_ik^2 / pi_ik))
	info
}

# get_likelihood_test_spec(): the score / gradient / LR spec on the columns the
# full fit kept, from the class's fitter, score and Hessian. `link` names the
# cumulative link for the expected (Fisher) information, which is computed in R
# (v1.0.6-TODO-201); the C++ fits return only the observed information
# (`observed_information` / `information`, information_type "observed";
# v1.0.6-TODO-215).
#' @keywords internal
#' @noRd
ordinal_cumlink_likelihood_test_spec = function(private, fit_fn, score_fn, hessian_fn, link) {
	private$shared(estimate_only = FALSE)
	ctx = private$cached_values$likelihood_test_context
	if (is.null(ctx)) return(NULL)
	X_fit = ctx$X
	y = as.numeric(private$y)
	j_treat = as.integer(ctx$j_treat)
	full_fit = list(params = ctx$full_params, neg_loglik = ctx$full_neg_loglik)
	list(
		X = X_fit, y = y, j = j_treat,
		full_fit = full_fit,
		fit_null = function(delta, start = NULL){
			ws_args = private$get_backend_warm_start_args(length(ctx$full_params))
			res = tryCatch(
				ordinal_fit_scaled(fit_fn,
					X_fit, y,
					warm_start_params = start %||% ws_args$start_params,
					warm_start_fisher_info = ws_args$warm_start_fisher_info,
					fixed_idx = j_treat, fixed_values = delta,
					smart_cold_start = private$smart_cold_start_default
				),
				error = function(e) NULL
			)
			if (is.null(res) || length(res) == 0) return(NULL)
			list(params = as.numeric(res$params), neg_loglik = as.numeric(res$neg_loglik), observed_information = res$observed_information)
		},
		extract_start = function(fit){
			as.numeric(fit$params)
		},
		score = function(fit){
			score_fn(X_fit, y, as.numeric(fit$params))
		},
		observed_information = function(fit){
			-hessian_fn(X_fit, y, as.numeric(fit$params))
		},
		fisher_information = function(fit){
			ordinal_cumlink_expected_information(X_fit, y, fit$params, link)
		},
		information = function(fit){
			fit$information %||% fit$observed_information %||% -hessian_fn(X_fit, y, as.numeric(fit$params))
		},
		neg_loglik = function(fit){ as.numeric(fit$neg_loglik) }
	)
}
