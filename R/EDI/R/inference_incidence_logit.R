inference_incid_log_regr_public = list(

		#' @description Initialize inference for the logistic regression model
		#'   \eqn{\mathrm{logit}(P(Y_i = 1)) = \beta_0 + \beta_T W_i + X_i^\top
		#'   \gamma}; see
		#'   \code{\link[EDI:InferenceIncidLogRegr]{InferenceIncidLogRegr}} for the
		#'   model form. Does not fit the model; the fit is deferred to the first
		#'   call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with an incidence response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values by default.
		#' @param harden                Whether to apply robustness measures.
		#' @param optimization_alg  Optimization algorithm to use. Default is dispatched via policy.
		#' @param max_abs_reasonable_coef Cap for reasonable logistic coefficients.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL, harden = TRUE, optimization_alg = NULL, max_abs_reasonable_coef = 50){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
				assertFormula(model_formula, null.ok = TRUE)
			}
			self$set_optimization_alg(optimization_alg, allow_irls = TRUE)
			super$initialize(des_obj, model_formula = model_formula, verbose = verbose, harden = harden, smart_cold_start_default = smart_cold_start_default)
			private$max_abs_reasonable_coef = max_abs_reasonable_coef
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},

		#' @description Refits the logistic model with subject/block-level weights
		#'   applied to the fitting log-likelihood (Bayesian-bootstrap or
		#'   nonparametric-bootstrap draw weights, expanded to row level via
		#'   \code{private$expand_subject_or_block_weights_to_row_weights()}) via
		#'   \code{\link{fast_logistic_regression_weighted_cpp}}, and returns the
		#'   reweighted log-odds-ratio estimate \eqn{\hat\beta_T^{(w)}}. Uses the
		#'   same QR column-dropping hardening and fit-reasonableness check as
		#'   \code{compute_estimate()}; a hardened-but-still-unreasonable fit
		#'   (e.g. near-perfect separation under the resampled weights) is cached
		#'   as nonestimable and returns \code{NA}.
		#' @param subject_or_block_weights Row weights for the bootstrap sample.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L,
				fit_fun = function(X_fit){
					res = fast_logistic_regression_weighted_cpp(
						X = X_fit,
						y = private$y,
						weights = row_weights,
						warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X_fit)),
						smart_cold_start = private$smart_cold_start_default,
						warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X_fit)),
						optimization_alg = private$optimization_alg
					)
					ssq_b_2 = NA_real_
					if (!estimate_only && !is.null(res$fisher_information) && is.matrix(res$fisher_information) && nrow(res$fisher_information) >= 2L) {
						inv_fi = tryCatch(solve(res$fisher_information), error = function(e) NULL)
						if (!is.null(inv_fi) && is.finite(inv_fi[2L, 2L]) && inv_fi[2L, 2L] > 0) ssq_b_2 = inv_fi[2L, 2L]
					}
					list(b = res$b, fisher_information = res$fisher_information, ssq_b_2 = ssq_b_2)
				},
				fit_ok = function(mod, X_fit, keep){
					isTRUE(private$is_logistic_fit_reasonable(mod))
				}
			)
			private$cached_mod = attempt$fit
			if (!isTRUE(private$is_logistic_fit_reasonable(attempt$fit))) {
				private$cache_nonestimable_estimate("logistic_regression_weighted_extreme_coefficients")
				return(NA_real_)
			}
			private$cached_values$beta_hat_T = as.numeric(attempt$fit$b[2])
			ssq = attempt$fit$ssq_b_2
			private$cached_values$s_beta_hat_T = if (!is.null(ssq) && is.finite(ssq) && ssq > 0) sqrt(ssq) else NA_real_
			private$set_fit_warm_start(
				as.numeric(attempt$fit$b),
				"beta",
				fisher = attempt$fit$fisher_information
			)
			private$cached_values$beta_hat_T
		}
	)

inference_incid_log_regr_private = list(
		# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
		# migration ladders): re-declared here even though `Wald`'s own source
		# (InferenceAsymp) already declares `cached_mod = NULL` and lists it in
		# `owns_state` -- component composition merges via `modifyList()`,
		# which silently DROPS NULL-valued entries for eager components
		# (`keep.null` is TRUE only for lazy components), so `cached_mod` never
		# actually lands as a real private field via Wald alone. Harmless for
		# real package instances (`lock_objects = FALSE` lets it spring into
		# existence on first assignment), but `test-bartlett-lr-plumbing.R`
		# subclasses this class via plain `R6::R6Class(inherit = ...)` without
		# its own `lock_objects = FALSE`, so the first `private$cached_mod =`
		# write inside `shared()` hit "cannot add bindings to a locked
		# environment". Re-declaring it here (a lazy component, so `keep.null`
		# applies) makes it a real pre-existing binding again.
		cached_mod = NULL,
		best_X_colnames = NULL,
		logit_X_full_cache = NULL,
		logit_w_cache = NULL,
		max_abs_reasonable_coef = 50,
		is_logistic_fit_reasonable = function(mod){
			if (is.null(mod) || is.null(mod$b) || length(mod$b) < 2L) return(FALSE)
			b = as.numeric(mod$b)
			all(is.finite(b)) && all(abs(b) <= private$max_abs_reasonable_coef)
		},
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			# Ensure we have the best design from the original data
			if (is.null(private$best_X_colnames)){
				private$shared(estimate_only = TRUE)
			}
			# Fallback if initial fit failed
			if (is.null(private$best_X_colnames)){
				return(self$compute_estimate(estimate_only = estimate_only))
			}
			# Use the same design matrix structure as the original fit
			X_cols = private$best_X_colnames
			X_data = private$get_X()
			if (length(X_cols) == 0L){
				# Univariate case
				X = cbind(1, private$w)
			} else {
				# Multivariate case
				X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
				X = cbind(1, treatment = private$w, X_cov)
			}
			res = fast_logistic_regression_cpp(
				X = X, y = as.numeric(private$y),
				warm_start_beta = private$get_fit_warm_start_for_length("beta", ncol(X)),
				smart_cold_start = private$smart_cold_start_default,
				warm_start_fisher_info = private$get_fit_warm_start_fisher(ncol(X)),
				estimate_only = TRUE,
				optimization_alg = private$optimization_alg
			)
			if (!isTRUE(private$is_logistic_fit_reasonable(res))){
				return(NA_real_)
			}
			private$set_fit_warm_start(res$b, "beta", fisher = res$fisher_information)
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
		supports_fisher_information = function(){
			TRUE
		},
		simulate_under_lik_null = function(spec, delta, null_fit){
			b_null = as.numeric(null_fit$b)
			eta    = as.numeric(spec$X %*% b_null)
			mu     = pmin(pmax(1 / (1 + exp(-eta)), 0), 1)
			y_sim  = private$simulate_param_boot_bernoulli_y(mu)
			if (is.null(y_sim)) return(NULL)
			X_fit  = spec$X
			j      = spec$j

			# Parametric bootstrap: use observed fit as anchor
			ws_args = private$get_backend_warm_start_args(ncol(X_fit))
			full_fit_b = tryCatch(
				fast_logistic_regression_cpp(
					X = X_fit, y = y_sim,
					warm_start_beta = ws_args$warm_start_beta,
					warm_start_weights = ws_args$warm_start_weights,
					warm_start_fisher_info = ws_args$warm_start_fisher_info,
					smart_cold_start = private$smart_cold_start_default,
					optimization_alg = private$optimization_alg
				),
				error = function(e) NULL
			)
			if (is.null(full_fit_b) || length(full_fit_b$b) < j || !is.finite(full_fit_b$b[j])) return(NULL)
			list(
				worker_data = list(y = y_sim),
				full_fit = full_fit_b,
				fit_null = function(d, start = NULL){
					ws_args_null = private$get_backend_warm_start_args(ncol(X_fit))
					tryCatch(
						fast_logistic_regression_with_var_cpp(
							X = X_fit, y = y_sim, j = j,
							warm_start_beta = start %||% full_fit_b$b,
							warm_start_weights = ws_args_null$warm_start_weights,
							warm_start_fisher_info = ws_args_null$warm_start_fisher_info,
							fixed_idx = j, fixed_values = d,
							smart_cold_start = TRUE,
							optimization_alg = private$optimization_alg
						),
						error = function(e) NULL
					)
				},
				neg_loglik = function(fit){
					eta_f      = as.numeric(X_fit %*% as.numeric(fit$b))
					log_denom  = ifelse(eta_f > 0, eta_f + log1p(exp(-eta_f)), log1p(exp(eta_f)))
					-sum(y_sim * eta_f - log_denom)
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
				X = X_fit,
				y = y,
				j = j_treat,
				full_fit = list(
					b = as.numeric(private$cached_mod$b),
					neg_loglik = as.numeric(ctx$full_neg_loglik)
				),
				fit_null = function(delta, start = NULL){
					ws_args = private$get_backend_warm_start_args(ncol(X_fit))
					fast_logistic_regression_with_var_cpp(
						X = X_fit,
						y = y,
						j = j_treat,
						warm_start_beta = start %||% ws_args$warm_start_beta,
						smart_cold_start = private$smart_cold_start_default,
						warm_start_weights = ws_args$warm_start_weights,
						warm_start_fisher_info = ws_args$warm_start_fisher_info,
						fixed_idx = j_treat,
						fixed_values = delta,
						optimization_alg = private$optimization_alg
					)
				},
				extract_start = function(fit){
					as.numeric(fit$b)
				},
				score = function(fit){
					get_logistic_regression_score_cpp(X_fit, y, as.numeric(fit$b))
				},
				observed_information = function(fit){
					-get_logistic_regression_hessian_cpp(X_fit, as.numeric(fit$b))
				},
				fisher_information = function(fit){
					-get_logistic_regression_hessian_cpp(X_fit, as.numeric(fit$b))
				},
				information = function(fit){
					-get_logistic_regression_hessian_cpp(X_fit, as.numeric(fit$b))
				},
				neg_loglik = function(fit){
					eta = as.numeric(X_fit %*% as.numeric(fit$b))
					log_denom = ifelse(eta > 0, eta + log1p(exp(-eta)), log1p(exp(eta)))
					-sum(y * eta - log_denom)
				}
			)
		},
		generate_mod = function(estimate_only = FALSE){
			if (is.null(private$logit_X_full_cache) || !identical(private$w, private$logit_w_cache)) {
				private$logit_X_full_cache = private$build_design_matrix()
				private$logit_w_cache = private$w
			}
			X_full = private$logit_X_full_cache
			
			if (!private$harden) {
				ws_args = private$get_backend_warm_start_args(ncol(X_full))
				if (estimate_only) {
					res = fast_logistic_regression_cpp(
						X_full, private$y,
						warm_start_beta = ws_args$warm_start_beta,
						warm_start_weights = ws_args$warm_start_weights,
						warm_start_fisher_info = ws_args$warm_start_fisher_info,
						smart_cold_start = private$smart_cold_start_default,
						estimate_only = TRUE,
						optimization_alg = private$optimization_alg
					)
					res$beta_hat_T = as.numeric(res$b[2])
					res$ssq_b_2 = NA_real_
					res$neg_log_lik = as.numeric(res$neg_ll)
				} else {
					res = fast_logistic_regression_with_var_cpp(
						X_full, private$y, j = 2L,
						warm_start_beta = ws_args$warm_start_beta,
						warm_start_weights = ws_args$warm_start_weights,
						warm_start_fisher_info = ws_args$warm_start_fisher_info,
						smart_cold_start = private$smart_cold_start_default,
						optimization_alg = private$optimization_alg
					)
					res$beta_hat_T = as.numeric(res$b[2])
					res$ssq_b_2 = res$ssq_b_j
				}
				if (!isTRUE(private$is_logistic_fit_reasonable(res))) {
					private$cache_nonestimable_estimate("logistic_regression_extreme_coefficients")
					private$cached_values$likelihood_test_context = NULL
					return(NULL)
				}
				private$best_X_colnames = setdiff(colnames(X_full), c("(Intercept)", "treatment"))
				private$cached_values$likelihood_test_context = list(
					X = X_full,
					j_treat = 2L,
					full_neg_loglik = res$neg_log_lik %||% res$neg_ll
				)
				return(res)
			}

			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L, # intercept and treatment
				fit_fun = function(X_fit){
					ws_args = private$get_backend_warm_start_args(ncol(X_fit))
					if (estimate_only) {
						res = fast_logistic_regression_cpp(
							X_fit, private$y,
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_weights = ws_args$warm_start_weights,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default,
							estimate_only = TRUE,
							optimization_alg = private$optimization_alg
						)
						list(
							beta_hat_T = as.numeric(res$b[2]),
							b = res$b, 
							fisher_information = res$fisher_information, 
							ssq_b_2 = NA_real_,
							neg_log_lik = as.numeric(res$neg_ll)
						)
					} else {
						res = fast_logistic_regression_with_var_cpp(
							X_fit, private$y,
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_weights = ws_args$warm_start_weights,
							warm_start_fisher_info = ws_args$warm_start_fisher_info,
							smart_cold_start = private$smart_cold_start_default,
							optimization_alg = private$optimization_alg
						)
						res$beta_hat_T = as.numeric(res$b[2])
						res$ssq_b_2 = res$ssq_b_j
						res
					}
				},
				fit_ok = function(mod, X_fit, keep){
					if (!isTRUE(private$is_logistic_fit_reasonable(mod))) return(FALSE)
					if (estimate_only) return(TRUE)
					is.finite(mod$ssq_b_2 %||% mod$ssq_b_j)
				}
			)
			if (!isTRUE(private$is_logistic_fit_reasonable(attempt$fit))) {
				private$cache_nonestimable_estimate("logistic_regression_extreme_coefficients")
				private$cached_values$likelihood_test_context = NULL
				return(NULL)
			}
			if (!is.null(attempt$fit)){
				private$set_fit_warm_start(
					attempt$fit$b, "beta", 
					fisher = attempt$fit$fisher_information, 
					weights = attempt$fit$w
				)
				private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
				private$cached_values$likelihood_test_context = list(
					X = attempt$X,
					j_treat = match(2L, attempt$keep),
					full_neg_loglik = attempt$fit$neg_log_lik %||% attempt$fit$neg_ll
				)
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
		},
		get_complexity_tier = function() "medium"
	)

IncidenceLogisticLikelihoodSource = list(
	public = inference_incid_log_regr_public,
	private = inference_incid_log_regr_private
)

#' Logistic Regression Inference for Incidence Responses
#'
#' Fits a logistic regression model for binary (incidence) responses:
#' \eqn{\mathrm{logit}(P(Y_i = 1)) = \beta_0 + \beta_T W_i + X_i^\top \gamma},
#' where \eqn{W_i} is the treatment indicator and \eqn{X_i} are optional
#' recorded covariates, by maximum likelihood
#' (\code{\link{fast_logistic_regression_cpp}}/
#' \code{\link{fast_logistic_regression_weighted_cpp}}). \eqn{\hat\beta_T} is
#' a log-odds-ratio: \eqn{\exp(\hat\beta_T)} is the estimated treatment odds
#' ratio. \code{likelihood_tier = "full"}: Wald, score, gradient, and
#' likelihood-ratio tests are all available (via the shared
#' \code{StandardModelCache} model-caching contract), plus
#' parametric-likelihood-bootstrap calibration of the likelihood-ratio test.
#' A fit whose coefficients exceed
#' \code{max_abs_reasonable_coef} in magnitude (a proxy for near-perfect
#' separation) is cached as nonestimable rather than returned. Validity
#' requires the usual logistic-regression assumptions: correctly specified
#' linear predictor on the logit scale, independence across subjects
#' conditional on covariates, and no perfect/quasi-complete separation.
#'
#' @references McCullagh, P., and Nelder, J. A. (1989). \emph{Generalized
#'   Linear Models} (2nd ed.). Chapman and Hall/CRC, for the logistic
#'   regression model and its maximum-likelihood theory.
#'
#' @seealso Comparable Python API:
#'   \href{https://www.statsmodels.org/stable/glm.html}{statsmodels GLM}. See
#'   also: \href{https://en.wikipedia.org/wiki/Logistic_regression}{Logistic
#'   regression} (Wikipedia).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidLogRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' \donttest{
#' inf$set_seed(1)
#' inf$compute_lik_ratio_bootstrap_two_sided_pval(delta = 0, B = 9, show_progress = FALSE)
#' }
#' @export
InferenceIncidLogRegr = define_inference_class(
	classname = "InferenceIncidLogRegr",
	inherit = Inference,
	# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
	# migration ladders): flipped from `inherit = InferenceAsympLikStdModCache`
	# (a deep algorithmic-compatibility base) to composing the
	# already-registered `IncidenceLogisticLikelihood` component (source
	# extracted above as a static plain-list object -- previously harvested
	# post-hoc via `inference_component_source_parts(InferenceIncidLogRegr)`
	# from the raw R6 generator; that pattern breaks once the class itself is
	# rebuilt via `define_inference_class()`, since the merged generator's
	# `$public_methods`/`$private_methods` would then include every composed
	# component's own methods too, not just this class's own layer -- so the
	# public=/private= content was hoisted into named list objects above,
	# harvested from directly instead). `IncidenceLogisticLikelihood`
	# declares `dependencies = "StandardModelCache"`; `ParametricLikelihood
	# Bootstrap` pulls in `LikelihoodTests` -> `Wald` -> `Jackknife`
	# separately; `BayesianBootstrap` pulls the rand/bootstrap chain.
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "IncidenceLogisticLikelihood"),
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval", "compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval", "get_supported_testing_types",
			"compute_estimate", "compute_estimate_with_bootstrap_weights"
		),
		private = c(
			"compute_treatment_estimate_during_randomization_inference",
			"supports_reusable_bootstrap_worker", "supports_likelihood_tests",
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
	# Uses the randomization-CI layer's two-sided p-value contract
	# (InferenceRandCI's version, not InferenceRand's) for the same reason
	# as every other migrated class this stretch -- Zhang dispatch matters
	# doubly here since this is an incidence-response class.
	public = list(
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval
	)
)
