# Interim class (documentation demoted to plain comments): only consumed via
# inference_component_source_parts() below; the composed class is documented on the
# final define_inference_class() assignment.
#' @inheritSection InferenceContinOLS Blocking designs
InferenceOrdinalPropOddsRegr = R6::R6Class("InferenceOrdinalPropOddsRegr",
	lock_objects = FALSE,
	inherit = InferenceAsympLikStdModCache,
	public = list(
		# @description Initialize a proportional-odds inference object for a
		#   completed design with an ordinal, uncensored response.
		# @param des_obj A completed \code{Design} object with an ordinal response.
		# @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#   the formula from the design object is used and its pre-computed design matrix is
		#   reused. If a formula is provided, a new design matrix is constructed from the
		#   design's imputed covariates.
		# @param verbose Whether to print progress messages.
		# @param smart_cold_start_default Whether to use smart cold start values by default.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL){
			ordinal_cumlink_initialize(super, private, des_obj, model_formula, verbose, smart_cold_start_default)
		}
		,
		# @description Recomputes the proportional-odds treatment estimate under
		#   subject/block bootstrap weights (via
		#   \code{\link{fast_ordinal_regression_weighted_cpp}}), used by the
		#   Bayesian bootstrap and related weighted-resampling machinery; see
		#   \code{\link[EDI:InferenceBayesianBootstrap]{InferenceBayesianBootstrap}}.
		#   When \code{estimate_only = FALSE}, also wires through the already-
		#   computed weighted variance (fixed 2026-09-07 -- see below).
		# @param subject_or_block_weights Bootstrap weights at the subject or block level.
		# @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			X_fit = private$build_design_matrix()
			n_params = ncol(X_fit) + length(sort(unique(private$y))) - 1L
			ws_args = private$get_backend_warm_start_args(n_params)
			res = tryCatch(
				ordinal_fit_scaled(fast_ordinal_regression_weighted_cpp,
					X = X_fit,
					y = as.numeric(private$y),
					weights = as.numeric(row_weights),
					warm_start_params = ws_args$start_params,
					warm_start_fisher_info = ws_args$warm_start_fisher_info,
					smart_cold_start = private$smart_cold_start_default
				),
				error = function(e) NULL
			)
			# Two bugs fixed 2026-09-07:
			# (1) build_design_matrix() puts `treatment` in column 1, so `res$b`
			#     (length == ncol(X_fit), the K-1 alpha cutpoints are returned
			#     separately -- see fast_ordinal_regression.cpp's
			#     .set("b", params.tail(p))) has the treatment coefficient at
			#     b[1], NOT b[length(b)]; the two only coincide when there are
			#     no extra covariates (p == 1). With covariates present, this
			#     silently returned a DIFFERENT covariate's coefficient as
			#     beta_hat_T.
			# (2) The weighted fit's `ssq_b_j` (already the variance of that
			#     same b[1] treatment coefficient -- see
			#     fast_ordinal_regression.cpp's ssq_b_j = vcov_full(n_alpha,
			#     n_alpha), the first beta block entry) was discarded and
			#     always replaced with NA, starving the Bayesian-bootstrap
			#     studentized/BCa variants of a per-replicate SE.
			if (is.null(res) || length(res$b) < 1L || !is.finite(res$b[1L])){
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			if (!is.null(res$converged) && !isTRUE(res$converged)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			private$set_fit_warm_start(res$params, "params", fisher = res$observed_information)
			private$cached_values$beta_hat_T = as.numeric(res$b[1L])
			ssq = res$ssq_b_j
			private$cached_values$s_beta_hat_T = if (!estimate_only && !is.null(ssq) && is.finite(ssq) && ssq > 0) sqrt(ssq) else NA_real_
			private$cached_values$df = NA_real_
			private$cached_values$beta_hat_T
		}
	),
	private = list(
		best_X_colnames = NULL,
		get_complexity_tier = function() "heavy",
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			ordinal_cumlink_rand_estimate(self, private, estimate_only, fast_ordinal_regression_cpp,
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
		# Expected (Fisher) information from ordinal_cumlink_expected_information(),
		# as in the probit / cauchit / cloglog siblings (v1.0.6-TODO-142).
		supports_fisher_information = function(){
			TRUE
		},
		simulate_under_lik_null = function(spec, delta, null_fit){
			ordinal_cumlink_simulate_under_lik_null(private, spec, null_fit, fast_ordinal_regression_cpp, stats::plogis)
		},
		get_likelihood_test_spec = function(){
			ordinal_cumlink_likelihood_test_spec(private, fast_ordinal_regression_cpp,
				score_fn = get_ordinal_regression_score_cpp,
				hessian_fn = get_ordinal_regression_hessian_cpp, link = "logit")
		},
		generate_mod = function(estimate_only = FALSE){
			ordinal_cumlink_generate_mod(private, estimate_only, function(X_fit){
				n_params = ncol(X_fit) + length(sort(unique(private$y))) - 1L
				ws_args = private$get_backend_warm_start_args(n_params)
				if (estimate_only) {
					ws_fisher = ws_args$warm_start_fisher_info
					res = tryCatch(
						ordinal_fit_scaled(fast_ordinal_regression_cpp,
							X_fit, private$y,
							warm_start_params = ws_args$start_params,
							warm_start_fisher_info = ws_fisher,
							smart_cold_start = private$smart_cold_start_default,
							estimate_only = TRUE
						),
						error = function(e) NULL
					)
					list(b = res$b, ssq_b_j = NA_real_, params = res$params, observed_information = ws_fisher)
				} else {
					res = tryCatch(
						ordinal_fit_scaled(fast_ordinal_regression_with_var_cpp,
							X_fit, private$y,
							warm_start_params = ws_args$start_params,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default
						),
						error = function(e) NULL
					)
					# TODO-107: an explicitly unconverged fit is not reported as the
					# MLE; retry cold on centered/scaled covariates (maps back exactly).
					if (!is.null(res) && !is.null(res$converged) && !isTRUE(res$converged)) {
						res = ordinal_po_refit_centered_scaled(X_fit, private$y, private$smart_cold_start_default)
					}
					list(converged = res$converged, b = res$b, ssq_b_j = res$ssq_b_j, params = res$params, neg_loglik = res$neg_loglik, observed_information = res$observed_information)
				}
			}, require_convergence = TRUE, cast_context = TRUE)
		},
		build_design_matrix = function(){
			ordinal_cumlink_design_matrix(private)
		}
	)
)

OrdinalProportionalOddsLikelihoodSource = inference_component_source_parts(InferenceOrdinalPropOddsRegr)

#' Proportional Odds Regression Inference for Ordinal Responses
#'
#' Fits a proportional-odds (cumulative-logit) regression, via
#' \code{\link{fast_ordinal_regression_with_var_cpp}} (see that page for the
#' full model), for ordinal responses using the treatment indicator and,
#' optionally, all recorded covariates as predictors. This is a full-likelihood
#' class (\code{likelihood_tier = "full"}) supporting score, gradient, and
#' likelihood-ratio tests, plus parametric likelihood-ratio bootstrap
#' calibration, in addition to Wald and resampling-based inference.
#'
#' @references McCullagh, P. (1980). "Regression Models for Ordinal Data."
#'   \emph{Journal of the Royal Statistical Society, Series B}, 42(2),
#'   109-127, \doi{10.1111/j.2517-6161.1980.tb01109.x}, for the
#'   proportional-odds cumulative-logit model fit here.
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'ordinal')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(sample(1:4, 10, replace = TRUE))
#' inf = InferenceOrdinalPropOddsRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' \donttest{
#' inf$set_seed(1)
#' inf$compute_lik_ratio_bootstrap_two_sided_pval(delta = 0, B = 9, show_progress = FALSE)
#' }
#' @concept proportional odds
#' @concept ordinal logistic regression
#' @concept cumulative logit model
#' @eval rd_small_sample_section("InferenceOrdinalPropOddsRegr")
#' @section Constructor:
#' \code{InferenceOrdinalPropOddsRegr$new(des_obj, model_formula = NULL, verbose = FALSE,
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
InferenceOrdinalPropOddsRegr = define_ordinal_cumulative_likelihood_class(
	"InferenceOrdinalPropOddsRegr", "OrdinalProportionalOddsLikelihood", "get_complexity_tier"
)


#' @R6method InferenceOrdinalPropOddsRegr$approximate_randomization_distribution_beta_hat_T
#' @template rand-approx-distribution-beta-hat-t
NULL

#' @R6method InferenceOrdinalPropOddsRegr$supports_rand_pval_for_incidence
#' @template rand-supports-pval-incidence
NULL

#' @R6method InferenceOrdinalPropOddsRegr$compute_rand_two_sided_pval
#' @template rand-compute-rand-two-sided-pval-params
NULL

# TODO-107: the C++ ordinal solver's convergence test is not scale-aware, so on
# uncentred covariates (e.g. mean 100) it stops early while still reporting
# converged = TRUE, with a treatment coefficient off by up to ~0.7. These
# helpers centre and scale every non-treatment column (all but column 1) before
# calling any of fast_ordinal_regression_{,with_var_,weighted_}cpp and map the
# fit back to the ORIGINAL parameterization exactly. Parameters are
# theta = (alpha, beta) under eta_k = alpha_k - x'beta; with X_s = (X - m) / sc the scaled parameters are
# alpha_s = alpha - sum(beta m), beta_s = beta * sc, i.e. theta_s = M theta.
# The treatment column is untouched (m = 0, sc = 1) so its coefficient, SE and
# neg_loglik are identical. Warm starts given in the original parameterization
# are mapped forward (theta_s = M theta, I_s = M^-T I M^-1). When every column
# is already well scaled (|mean| <= sd and sd in [0.25, 4]) the data are passed
# through untouched, so well-scaled inputs keep bit-identical behaviour.
ordinal_center_scale_plan = function(X, force = FALSE){
	p = ncol(X)
	if (p < 2L) return(NULL)
	Xc = X[, -1L, drop = FALSE]
	m = colMeans(Xc)
	sc = apply(Xc, 2L, stats::sd)
	bad = !is.finite(sc) | sc < 1e-12
	if (!force && all(is.finite(m)) && all(bad | (abs(m) <= sc & sc >= 0.25 & sc <= 4))) return(NULL)
	m[!is.finite(m)] = 0
	sc[bad] = 1
	list(m = c(0, m), sc = c(1, sc), sgn = -1)
}

ordinal_center_scale_M = function(plan, n_par, p){
	n_alpha = n_par - p
	M = diag(n_par)
	M[seq_len(n_alpha), n_alpha + seq_len(p)] = plan$sgn * matrix(plan$m, n_alpha, p, byrow = TRUE)
	M[cbind(n_alpha + seq_len(p), n_alpha + seq_len(p))] = plan$sc
	M
}

# `linpred_sign` is the sign of x'beta in the solver's linear predictor
# (-1: eta_k = alpha_k - x'beta, the logit/cauchit/probit solvers; +1: the
# cloglog solver, eta_k = alpha_k + x'beta).
# `warm_arg` is the NAME of the solver's full-parameter warm-start argument
# ("warm_start_params" for the cumulative/adjacent-category solvers,
# "warm_start_beta" for the continuation-ratio solvers, where it also holds the
# FULL c(alpha, beta) vector). The adjacent-category logit solver uses
# linpred_sign = -1 (log p~_k = sum_{j>=k}(alpha_j - x'beta)); the
# continuation-ratio solvers use linpred_sign = +1 (logit P(continue past j) =
# alpha_j + x'beta).
# Calls `fit_fun` (one of the fast ordinal C++ solvers) on centred/scaled
# covariates and returns its result in the original parameterization.
ordinal_fit_scaled = function(fit_fun, X, y, warm_start_params = NULL, warm_start_fisher_info = NULL,
		fixed_idx = NULL, fixed_values = NULL, force = FALSE, linpred_sign = -1,
		warm_arg = "warm_start_params", ...){
	p = ncol(X)
	plan = ordinal_center_scale_plan(X, force = force)
	if (!is.null(plan)) plan$sgn = linpred_sign
	# a fixed non-treatment parameter would need its own value mapped; only the
	# treatment coefficient (index n_alpha + 1) is ever fixed, which is unchanged
	if (!is.null(plan) && length(fixed_idx) > 0L) {
		n_alpha_guess = length(unique(y)) - 1L
		if (any(fixed_idx != n_alpha_guess + 1L)) plan = NULL
	}
	if (is.null(plan)) {
		args = list(X, y, warm_start_fisher_info = warm_start_fisher_info,
			fixed_idx = fixed_idx, fixed_values = fixed_values, ...)
		args[warm_arg] = list(warm_start_params)
		return(do.call(fit_fun, args))
	}
	X_s = sweep(sweep(X, 2L, plan$m, "-"), 2L, plan$sc, "/")
	ws = NULL
	wf = NULL
	if (!is.null(warm_start_params) && length(warm_start_params) >= p + 1L) {
		n_par = length(warm_start_params)
		M0 = ordinal_center_scale_M(plan, n_par, p)
		ws = as.numeric(M0 %*% as.numeric(warm_start_params))
		if (!is.null(warm_start_fisher_info) && all(dim(warm_start_fisher_info) == n_par)) {
			Mi = solve(M0)
			wf = crossprod(Mi, warm_start_fisher_info %*% Mi)
		}
	}
	args = list(X_s, y, warm_start_fisher_info = wf,
		fixed_idx = fixed_idx, fixed_values = fixed_values, ...)
	args[warm_arg] = list(ws)
	res = do.call(fit_fun, args)
	if (is.null(res) || is.null(res$params)) return(res)
	n_par = length(res$params)
	n_alpha = n_par - p
	M = ordinal_center_scale_M(plan, n_par, p)
	res$params = as.numeric(solve(M, as.numeric(res$params)))
	res$b = res$params[n_alpha + seq_len(p)]
	if (n_alpha > 0L) res$alpha = res$params[seq_len(n_alpha)]
	# continuation-ratio solvers also return the full vector as beta_full and
	# the augmented design (whose covariate columns were the scaled ones)
	if (!is.null(res$beta_full)) res$beta_full = res$params
	if (is.matrix(res$X_aug) && ncol(res$X_aug) == n_par) {
		jj = n_alpha + seq_len(p)
		res$X_aug[, jj] = sweep(sweep(res$X_aug[, jj, drop = FALSE], 2L, plan$sc, "*"), 2L, plan$m, "+")
	}
	Mi = NULL
	for (nm in c("fisher_information", "observed_information", "information")) {
		A = res[[nm]]
		if (is.matrix(A) && all(dim(A) == n_par)) res[[nm]] = crossprod(M, A %*% M)
	}
	V = res$vcov
	if (is.matrix(V) && all(dim(V) == n_par)) {
		Mi = solve(M)
		res$vcov = Mi %*% V %*% t(Mi)
	}
	res
}

# Cold refit of the unweighted proportional-odds model on centered and
# scaled covariate columns (all but column 1 = treatment), with the fit
# mapped back to the original parameterization. The treatment coefficient and
# SE are unaffected by rescaling the other columns.
ordinal_po_refit_centered_scaled = function(X_fit, y, smart_cold_start){
	if (ncol(X_fit) < 2L) return(NULL)
	tryCatch(
		ordinal_fit_scaled(fast_ordinal_regression_with_var_cpp, X_fit, y, force = TRUE, smart_cold_start = smart_cold_start),
		error = function(e) NULL
	)
}
