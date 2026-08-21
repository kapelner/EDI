#' Fractional Logit Inference for Proportion Responses
#'
#' Fits Papke and Wooldridge's (1996) fractional logistic (quasi-binomial)
#' regression for proportion responses \eqn{Y_i \in [0, 1]} (not restricted to
#' \eqn{\{0, 1\}}):
#' \eqn{E[Y_i \mid W_i, X_i] = \mathrm{logit}^{-1}(\beta_0 + \beta_T W_i +
#' X_i^\top \gamma)}, fit by maximizing the Bernoulli quasi-log-likelihood
#' \eqn{\sum_i \{Y_i \log \mu_i + (1 - Y_i) \log(1 - \mu_i)\}} treating
#' \eqn{Y_i} as if it were binary (a valid estimating equation for the
#' conditional mean even though \eqn{Y_i} is fractional — the Bernoulli
#' log-likelihood's score is unbiased for the true mean regardless of the
#' actual distribution of \eqn{Y_i} on \eqn{[0,1]}). \eqn{\hat\beta_T} is a
#' log-odds-ratio on the conditional-mean scale: \eqn{\exp(\hat\beta_T)} is
#' the odds ratio for the expected proportion. Standard errors use the
#' model-based (non-robust/non-sandwich) Fisher information from this
#' quasi-likelihood, matching pre-migration behavior; only Wald inference is
#' exposed (\code{private$supports_likelihood_tests()} is hard \code{FALSE}
#' here even though \code{likelihood_tier = "full"} metadata is set for
#' component-composition purposes — this class deliberately does not compose
#' \code{ParametricLikelihoodBootstrap}, so no likelihood-ratio/score/gradient
#' test surface is exposed). Validity requires that the conditional mean is
#' correctly specified on the logit scale; unlike beta regression, no
#' assumption is made about the conditional variance or shape of \eqn{Y_i}'s
#' distribution.
#'
#' @references Papke, L. E., and Wooldridge, J. M. (1996). "Econometric
#'   Methods for Fractional Response Variables with an Application to 401(K)
#'   Plan Participation Rates." \emph{Journal of Applied Econometrics}, 11(6),
#'   619-632, \doi{10.1002/(SICI)1099-1255(199611)11:6<619::AID-JAE418>3.0.CO;2-1}.
#'
#' @seealso \code{\link[EDI:InferencePropBetaRegr]{InferencePropBetaRegr}} for
#'   a proportion model that also specifies the conditional variance/shape.
#'   Comparable Python API:
#'   \href{https://www.statsmodels.org/stable/glm.html}{statsmodels GLM}
#'   (\code{family=Binomial()} on fractional response data). See also:
#'   \href{https://en.wikipedia.org/wiki/Logistic_regression}{Logistic
#'   regression} (Wikipedia).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'proportion')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(runif(10))
#' inf = InferencePropFractionalLogit$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferencePropFractionalLogit = define_inference_class(
	classname = "InferencePropFractionalLogit",
	inherit = Inference,
	# 2026-08-20 (fix_inference_hierarchy.md "KK And IVWC Estimators" /
	# per-class migration ladders): flipped from `inherit =
	# InferenceAsympLikStdModCacheNoParamBootstrap` (a deep algorithmic-
	# compatibility base) to composing the already-registered
	# `StandardModelCache` component (source `StandardModelCacheSource` in
	# inference_all_abstract_asymp_lik_std_mod_cache.R, previously registered
	# but not yet composed by any concrete class) directly, matching the
	# manifest's own target_components for this class. `StandardModelCache`
	# depends on `LikelihoodTests` -> `Wald` -> `Jackknife`; `BayesianBootstrap`
	# depends on `RandomizationBootstrapCI` -> ... -> `RandomizationTest` --
	# together these transitively resolve to the full 10-component manifest
	# target without listing every name directly (same shape as every other
	# migrated class composing BayesianBootstrap + Wald).
	components = c("BayesianBootstrap", "Wald", "StandardModelCache"),
	# No explicit `capabilities` needed: this class does not compose
	# ParametricLikelihoodBootstrap (the only consumer requiring
	# "likelihood_ratio" pre-declared), and its own
	# supports_likelihood_tests() override (below) is FALSE, matching
	# pre-migration behavior exactly (verified: get_supported_testing_types()
	# stays c("wald") for both legacy and migrated).
	metadata = list(likelihood_tier = "full"),
	overrides = list(
		public = c(
			"compute_estimate", "compute_rand_two_sided_pval",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"get_supported_testing_types", "compute_estimate_with_bootstrap_weights"
		),
		private = c(
			"compute_treatment_estimate_during_randomization_inference",
			"supports_likelihood_tests", "supports_reusable_bootstrap_worker",
			"generate_mod",
			"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"create_bootstrap_worker_state", "load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate", "get_supported_testing_types_impl",
			"get_standard_error", "get_degrees_of_freedom", "make_warm_fit_null_wrapper",
			"compute_likelihood_test_two_sided_pval", "compute_score_two_sided_pval_impl",
			"compute_gradient_two_sided_pval_impl", "compute_lik_ratio_two_sided_pval_impl",
			"get_likelihood_test_spec"
		)
	),
	public = list(
		# Uses the randomization-CI layer's two-sided p-value contract
		# (InferenceRandCI's version, not InferenceRand's): same reasoning as
		# InferenceAllSimpleMeanDiff's identical pin (inference_all_mean_diff.R)
		# -- RandCI's version is documented safe to splice in outside the old
		# inheritance chain and is now the default choice across migrated
		# classes composing this bootstrap chain, not an incidence-only special
		# case.
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize inference for the fractional logit model
		#'   \eqn{E[Y_i \mid W_i, X_i] = \mathrm{logit}^{-1}(\beta_0 + \beta_T W_i +
		#'   X_i^\top \gamma)}; see
		#'   \code{\link[EDI:InferencePropFractionalLogit]{InferencePropFractionalLogit}}
		#'   for the model form. Does not fit the model; the fit is deferred to the
		#'   first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with a proportion response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param harden  		Whether to apply robustness measures.
		#' @param smart_cold_start_default Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, harden = TRUE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "proportion")
				assertFormula(model_formula, null.ok = TRUE)
			}
			super$initialize(des_obj, verbose = verbose, harden = harden, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Fits the fractional logit model by maximizing the Bernoulli
		#'   quasi-log-likelihood on the fractional response and returns the
		#'   log-odds-ratio estimate \eqn{\hat\beta_T}. When \code{estimate_only =
		#'   TRUE} and hardening is disabled (\code{harden = FALSE}), uses a fast
		#'   path via base R's \code{glm.fit(family = quasibinomial())} instead of
		#'   the package's own fitting routine; otherwise dispatches through the
		#'   shared hardened-fit path.
		#' @param estimate_only If TRUE, skip variance component calculations; when
		#'   combined with \code{harden = FALSE}, also switches to the
		#'   \code{quasibinomial()} fast path.
		compute_estimate = function(estimate_only = FALSE){
			if (estimate_only) {
				if (!is.null(private$cached_values$beta_hat_T)) return(private$cached_values$beta_hat_T)
				if (isFALSE(private$harden)) {
					X = private$build_design_matrix()
					fit = glm.fit(x = X, y = as.numeric(private$y), family = quasibinomial())
					b = fit$coefficients
					private$cached_values$beta_hat_T = if (length(b) >= 2L && is.finite(b[2L])) {
						private$best_X_colnames = setdiff(colnames(X), c("(Intercept)", "treatment"))
						as.numeric(b[2L])
					} else NA_real_
					return(private$cached_values$beta_hat_T)
				}
			}
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Refits the fractional logit model with subject/block-level
		#'   weights applied to the fitting quasi-log-likelihood (Bayesian-bootstrap
		#'   or nonparametric-bootstrap draw weights, expanded to row level via
		#'   \code{private$expand_subject_or_block_weights_to_row_weights()}), and
		#'   returns the reweighted estimate \eqn{\hat\beta_T^{(w)}}. Uses the same
		#'   QR column-dropping hardening as \code{compute_estimate()}'s hardened
		#'   path; a hardened-but-still-unreasonable fit is cached as nonestimable.
		#' @param subject_or_block_weights Bootstrap weights at the subject or block level.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L,
				fit_fun = function(X_fit, keep){
					res = tryCatch(
						fast_logistic_regression_weighted_cpp(
							X = X_fit,
							y = as.numeric(private$y),
							weights = as.numeric(row_weights),
							warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
							warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit))
						),
						error = function(e) NULL
					)
					if (is.null(res)) return(NULL)
					list(b = res$b, fisher_information = res$fisher_information, ssq_b_2 = NA_real_)
				},
				fit_ok = function(mod, X_fit, keep){
					!is.null(mod) && length(mod$b) >= 2L && is.finite(mod$b[2L])
				}
			)
			private$cached_mod = attempt$fit
			if (is.null(attempt$fit) || is.null(attempt$fit$b) || length(attempt$fit$b) < 2L || !is.finite(attempt$fit$b[2L])) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				return(NA_real_)
			}
			private$cached_values$beta_hat_T = as.numeric(attempt$fit$b[2L])
			private$cached_values$s_beta_hat_T = NA_real_
			private$set_fit_warm_start(
				as.numeric(attempt$fit$b),
				"beta",
				fisher = attempt$fit$fisher_information
			)
			private$cached_values$beta_hat_T
		}
	),
	private = list(
		best_X_colnames = NULL,
		supports_likelihood_tests = function(){
			FALSE
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
				X = cbind(`(Intercept)` = 1, treatment = private$w)
			} else {
				X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
				X = cbind(`(Intercept)` = 1, treatment = private$w, X_cov)
			}
			res = fast_logistic_regression_cpp(X = X, y = as.numeric(private$y), estimate_only = TRUE)
			if (is.null(res) || !is.finite(res$b[2])){
				return(NA_real_)
			}
			as.numeric(res$b[2])
		},
		supports_reusable_bootstrap_worker = function(){
			TRUE
		},
		generate_mod = function(estimate_only = FALSE){
			X_full = private$build_design_matrix()
			
			attempt = if (private$harden) {
				private$fit_with_hardened_qr_column_dropping(
					X_full = X_full,
					required_cols = 2L,
					fit_fun = function(X_fit){
						ws_args = private$get_backend_warm_start_args(ncol(X_fit))
						if (estimate_only) {
							res = fast_logistic_regression_cpp(
								X = X_fit, 
								y = private$y, 
								warm_start_beta = ws_args$warm_start_beta,
								warm_start_weights = ws_args$warm_start_weights,
								warm_start_fisher_info = ws_args$warm_start_fisher_info,
								smart_cold_start = private$smart_cold_start_default,
								estimate_only = TRUE
							)
							list(b = res$b, ssq_b_2 = NA_real_)
						} else {
							fast_logistic_regression_with_var_cpp(
								X = X_fit, 
								y = private$y,
								warm_start_beta = ws_args$warm_start_beta,
								warm_start_weights = ws_args$warm_start_weights,
								warm_start_fisher_info = ws_args$warm_start_fisher_info,
								smart_cold_start = private$smart_cold_start_default
							)
						}
					},
					fit_ok = function(mod, X_fit, keep){
						if (is.null(mod) || length(mod$b) < 2L || !is.finite(mod$b[2])) return(FALSE)
						if (max(abs(mod$b), na.rm = TRUE) > 100) return(FALSE)
						if (estimate_only) return(TRUE)
						is.finite(mod$ssq_b_2) && mod$ssq_b_2 > 0
					}
				)
			} else {
				list(
					X = X_full,
					keep = seq_len(ncol(X_full)),
					fit = {
						ws_args = private$get_backend_warm_start_args(ncol(X_full))
						if (estimate_only) {
							res = fast_logistic_regression_cpp(
								X = X_full, 
								y = private$y, 
								warm_start_beta = ws_args$warm_start_beta,
								warm_start_weights = ws_args$warm_start_weights,
								warm_start_fisher_info = ws_args$warm_start_fisher_info,
								smart_cold_start = private$smart_cold_start_default,
								estimate_only = TRUE
							)
							list(b = res$b, ssq_b_2 = NA_real_)
						} else {
							fast_logistic_regression_with_var_cpp(
								X = X_full, 
								y = private$y,
								warm_start_beta = ws_args$warm_start_beta,
								warm_start_weights = ws_args$warm_start_weights,
								warm_start_fisher_info = ws_args$warm_start_fisher_info,
								smart_cold_start = private$smart_cold_start_default
							)
						}
					}
				)
			}
			if (!is.null(attempt$fit)){
				private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
			}
			attempt$fit
		},
		build_design_matrix = function(){
			private$create_design_matrix()
		}
	)
)
