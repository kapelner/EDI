# Interim class (documentation demoted to plain comments): only consumed via
# inference_component_source_parts() below; the composed class is documented on the
# final define_inference_class() assignment.
#' @inheritSection InferenceContinOLS Blocking designs
InferenceOrdinalCauchitRegr = R6::R6Class("InferenceOrdinalCauchitRegr",
	lock_objects = FALSE,
	inherit = InferenceAsympLikStdModCache,
	public = list(
		# @description Initialize a cauchit ordinal inference object.
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
		# @description Refits the cauchit cumulative-link model under subject/block
		#   resampling weights via \code{weighted_ordinal_bootstrap_surrogate_fit()}
		#   (a weighted-likelihood surrogate fit, not full IRLS re-optimization from
		#   cold start) and returns the re-estimated treatment coefficient
		#   \eqn{\hat\beta_T} on the cauchit-link scale. Used to build the
		#   nonparametric- and Bayesian-bootstrap distributions of \eqn{\hat\beta_T}.
		#   If the surrogate fit fails or yields a non-finite estimate, the
		#   replicate's estimate, standard error, and degrees of freedom are all set
		#   to \code{NA}.
		# @param subject_or_block_weights Numeric vector of resampling weights, one
		#   per subject or resampling block.
		# @param estimate_only Accepted for interface compatibility; standard errors
		#   are never computed for a single bootstrap replicate regardless of this flag.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			ordinal_surrogate_estimate_with_bootstrap_weights(private, subject_or_block_weights, method = "cauchit")
		}
	),
	private = list(
		best_X_colnames = NULL,
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			ordinal_cumlink_rand_estimate(self, private, estimate_only, fast_ordinal_cauchit_regression_cpp,
				warm_start_args = function(n_params) list(
					start_params = private$get_fit_warm_start_for_length("params", n_params),
					warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params)
				))
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
			params_null = as.numeric(null_fit$params)
			y_sim       = private$simulate_param_boot_ordinal_y(spec$X, params_null, spec$y, stats::pcauchy)
			if (is.null(y_sim)) return(NULL)
			X_fit    = spec$X
			j        = spec$j
			full_res = tryCatch(
				ordinal_fit_scaled(fast_ordinal_cauchit_regression_cpp,
					X_fit, y_sim,
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
					res = tryCatch(
						ordinal_fit_scaled(fast_ordinal_cauchit_regression_cpp,
							X_fit, y_sim,
							warm_start_params = start %||% full_fit_boot$params,
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
		},
		get_likelihood_test_spec = function(){
			ordinal_cumlink_likelihood_test_spec(private, fast_ordinal_cauchit_regression_cpp,
				score_fn = get_ordinal_cauchit_regression_score_cpp,
				hessian_fn = get_ordinal_cauchit_regression_hessian_cpp, link = "cauchit", direct_warm_start = TRUE)
		},
		generate_mod = function(estimate_only = FALSE){
			ordinal_cumlink_generate_mod(private, estimate_only, function(X_fit){
				n_params = ncol(X_fit) + length(sort(unique(private$y))) - 1L
				warm_start_params = private$get_fit_warm_start_for_length("params", n_params)
				warm_fisher = private$get_fit_warm_start_fisher(n_params)
				if (estimate_only) {
					res = ordinal_fit_scaled(fast_ordinal_cauchit_regression_cpp,
						X_fit, private$y,
						warm_start_params = warm_start_params,
						warm_start_fisher_info = warm_fisher,
						smart_cold_start = private$smart_cold_start_default,
						estimate_only = TRUE
					)
					if (is.null(res) || length(res) == 0) return(NULL)
					list(b = res$b, ssq_b_j = NA_real_, params = res$params, observed_information = warm_fisher)
				} else {
					res = ordinal_fit_scaled(fast_ordinal_cauchit_regression_with_var_cpp,
						X_fit, private$y,
						warm_start_params = warm_start_params,
						warm_start_fisher_info = warm_fisher,
						smart_cold_start = private$smart_cold_start_default
					)
					if (is.null(res) || length(res$b) == 0 || is.na(res$b[1])) return(NULL)
					list(b = res$b, ssq_b_j = res$ssq_b_j, params = res$params, neg_loglik = res$neg_loglik, observed_information = res$observed_information)
				}
			})
		},
		build_design_matrix = function(){
			ordinal_cumlink_design_matrix(private)
		}
	)
)

OrdinalCauchitLikelihoodSource = inference_component_source_parts(InferenceOrdinalCauchitRegr)

#' Cauchit Regression Inference for Ordinal Responses
#'
#' Cauchit-link cumulative-odds ordinal regression: \eqn{P(Y \le k \mid w, x) =
#' F_{\mathrm{Cauchy}}(\alpha_k - \beta_T w - \beta_X^\top x)}, where
#' \eqn{F_{\mathrm{Cauchy}}} is the standard Cauchy CDF, \eqn{\alpha_k} are
#' category-specific cutpoints, and \eqn{\beta_T} is the treatment coefficient
#' on the cauchit (Cauchy-quantile) scale: a shift common to all categories, not
#' a log odds ratio. Fit by maximum likelihood. The heavy-tailed Cauchy link is
#' markedly less sensitive to outlying/extreme response categories than the
#' logit or probit link, at the cost of a less familiar effect-size
#' interpretation. \code{likelihood_tier = "full"}: exposes likelihood-ratio,
#' score, gradient, and parametric-likelihood-bootstrap inference in addition to
#' the Wald/asymptotic and Bayesian-bootstrap paths.
#'
#' \strong{Small samples.} With covariate adjustment at n = 50, the score test
#' rejected a true null up to 17\% of the time at a nominal 5\% level (intervals
#' covered as little as 84\%) and the gradient and likelihood-ratio tests up to
#' 13\%, while the Wald test stayed at 6\% to 7\%; treatment-only, the score
#' test rejected up to 8\%. The worst cells were with unequal allocation
#' (\code{prob_T = 0.2}, about 10 treated subjects). The excess is expected to
#' shrink as n grows. With samples this small, use the Wald test, a larger
#' sample, or a randomization or bootstrap test. Source: the first calibration
#' campaign (2026-11-09-8c32d060; provisional, 1000 screening replicates per
#' cell, Monte Carlo standard error about 0.007; measured at n = 50 only),
#' \url{https://github.com/kapelner/EDI/tree/calibration-results}.
#'
#' @references Agresti, A. (2010). \emph{Analysis of Ordinal Categorical Data}
#'   (2nd ed.). Wiley. Ch. 3-4 (cumulative link models).
#' @seealso \url{https://en.wikipedia.org/wiki/Ordinal_regression},
#'   \url{https://www.statsmodels.org/stable/discretemod.html} for an analogous
#'   Python cumulative-link API.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'ordinal')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(sample(1:4, 10, replace = TRUE))
#' inf = InferenceOrdinalCauchitRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' @eval rd_small_sample_section("InferenceOrdinalCauchitRegr")
#' @section Constructor:
#' \code{InferenceOrdinalCauchitRegr$new(des_obj, model_formula = NULL, verbose = FALSE,
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
InferenceOrdinalCauchitRegr = define_ordinal_cumulative_likelihood_class(
	"InferenceOrdinalCauchitRegr", "OrdinalCauchitLikelihood"
)


#' @R6method InferenceOrdinalCauchitRegr$approximate_randomization_distribution_beta_hat_T
#' @template rand-approx-distribution-beta-hat-t
NULL

#' @R6method InferenceOrdinalCauchitRegr$supports_rand_pval_for_incidence
#' @template rand-supports-pval-incidence
NULL

#' @R6method InferenceOrdinalCauchitRegr$compute_rand_two_sided_pval
#' @template rand-compute-rand-two-sided-pval-params
NULL
