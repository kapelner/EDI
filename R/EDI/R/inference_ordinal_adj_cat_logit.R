#' Adjacent Category Logit Regression Inference for Ordinal Responses
#'
#' Fits an adjacent-category logit regression for ordinal responses (via
#' \code{\link{fast_adjacent_category_logit_cpp}} — see that page for the full
#' model, an alternative ordinal parameterization to the cumulative-logit
#' proportional-odds model) using the treatment indicator and, optionally, all
#' recorded covariates as predictors. This is a full-likelihood class
#' (\code{likelihood_tier = "full"}) supporting score, gradient, and
#' likelihood-ratio tests, plus parametric likelihood-ratio bootstrap
#' calibration, in addition to Wald and resampling-based inference.
#' Bayesian-bootstrap inference is temporarily unavailable because the current
#' non-uniform weighted hook fits a cumulative-logit surrogate rather than the
#' adjacent-category likelihood. It will remain disabled until the native
#' weighted adjacent-category backend described in the package implementation
#' plan lands.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'ordinal')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(sample(1:4, 10, replace = TRUE))
#' inf = InferenceOrdinalAdjCatLogitRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceOrdinalAdjCatLogitRegr = R6::R6Class("InferenceOrdinalAdjCatLogitRegr",
	lock_objects = FALSE,
	inherit = InferenceAsympLikStdModCache,
	public = list(
		#' @description Initialize an adjacent-category-logit inference object for a
		#'   completed design with an ordinal, uncensored response.
		#' @param des_obj A completed \code{Design} object with an ordinal response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param harden Whether to apply robustness measures.
		#' @param smart_cold_start_default Whether to use smart cold starts.
		initialize = function(des_obj, verbose = FALSE, harden = TRUE, model_formula = NULL, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "ordinal")
				assertFormula(model_formula, null.ok = TRUE)
			}
			super$initialize(des_obj, verbose = verbose, harden = harden, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Recomputes the ordinal treatment estimate under
		#'   subject/block bootstrap weights, used by the Bayesian bootstrap and
		#'   related weighted-resampling machinery; see
		#'   \code{\link[EDI:InferenceBayesianBootstrap]{InferenceBayesianBootstrap}}.
		#'   Rather than refitting the full adjacent-category logit model with
		#'   weights, this uses a cheaper \strong{surrogate} fit
		#'   (\code{weighted_ordinal_bootstrap_surrogate_fit(..., method =
		#'   "logistic")}) on the (possibly rank-reduced, reusing
		#'   \code{private$best_Xmm_colnames} from a prior full fit if available)
		#'   design matrix. Always leaves the standard error and degrees of freedom
		#'   unavailable (\code{NA}) regardless of \code{estimate_only} — this
		#'   surrogate path never computes a variance.
		#' @param subject_or_block_weights Numeric vector. Row weights for bootstrap.
		#' @param estimate_only Present for interface parity; this method never
		#'   computes variance components regardless of its value.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			X_fit = private$build_design_matrix()
			if (!is.null(private$best_Xmm_colnames)) {
				keep = c("treatment", intersect(private$best_Xmm_colnames, colnames(X_fit)))
				X_fit = X_fit[, keep, drop = FALSE]
			}
			fit = weighted_ordinal_bootstrap_surrogate_fit(X_fit, private$y, row_weights, method = "logistic")
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
	),
	private = list(
		supports_likelihood_tests = function(){ TRUE },
		# The weighted hook below is not estimator-preserving. Keep every public
		# Bayesian-bootstrap entry point disabled until the native weighted
		# adjacent-category backend plan is complete.
		supports_bayesian_bootstrap = function() FALSE,
		best_Xmm_colnames = NULL,
		# Declared explicitly (2026-08-21 fix) so the harvested
		# OrdinalAdjacentCategoryLikelihood component's owns_state can
		# re-declare it too, surviving the eager-component NULL-dropping bug
		# (Wald's own `cached_mod = NULL` never survives composition; see the
		# component spec's comment in contracts_mixins.R). Previously created
		# dynamically on first assignment in generate_mod() -- harmless for
		# unlocked package instances but breaks any locked test/user subclass.
		cached_mod = NULL,
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			if (is.null(private$best_Xmm_colnames)){
				private$shared(estimate_only = TRUE)
			}
			if (is.null(private$best_Xmm_colnames)){
				return(self$compute_estimate(estimate_only = estimate_only))
			}
			X_cols = private$best_Xmm_colnames
			X_data = private$get_X()
			if (length(X_cols) == 0L){
				X = as.matrix(private$w)
				colnames(X) = "treatment"
			} else {
				X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
				X = cbind(treatment = private$w, X_cov)
			}

			n_params = ncol(X) + length(sort(unique(private$y))) - 1L
			res = fast_adjacent_category_logit_cpp(
				X = X, y = as.numeric(private$y),
				warm_start_params = private$get_fit_warm_start_for_length("params", n_params),
				warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params)
			)
			if (is.null(res) || length(res$b) < 1L || !is.finite(res$b[length(res$b)])){
				return(NA_real_)
			}
			private$set_fit_warm_start(res$params, "params")
			as.numeric(res$b[length(res$b)])
		},
		supports_reusable_bootstrap_worker = function(){
			TRUE
		},
		get_bootstrap_worker_spec = function(){
			private$shared(estimate_only = FALSE)
			list(
				X_full = private$build_design_matrix(),
				best_X_cols = private$best_Xmm_colnames,
				fit_fun = function(X_fit, keep){
					n_params = ncol(X_fit) + length(sort(unique(private$y))) - 1L
					res = fast_adjacent_category_logit_cpp(
						X_fit, private$y,
						warm_start_params = private$get_fit_warm_start_for_length("params", n_params),
						warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params)
					)
					list(b = res$b, ssq_b_j = NA_real_, params = res$params)
				}
			)
		},
		generate_mod = function(estimate_only = FALSE){
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 1L,
				fit_fun = function(X_fit){
					n_params = ncol(X_fit) + length(sort(unique(private$y))) - 1L
					warm_start_params = private$get_fit_warm_start_for_length("params", n_params)
					warm_fisher = private$get_fit_warm_start_fisher(n_params)
					if (estimate_only) {
						res = fast_adjacent_category_logit_cpp(
							X_fit, private$y,
							warm_start_params = warm_start_params,
							warm_start_fisher_info = warm_fisher
						)
						list(b = res$b, ssq_b_j = NA_real_, params = res$params)
					} else {
						res = fast_adjacent_category_logit_with_var_cpp(
							X_fit, private$y,
							warm_start_params = warm_start_params,
							warm_start_fisher_info = warm_fisher
						)
						list(b = res$b, ssq_b_j = res$ssq_b_1, params = res$params, neg_loglik = res$neg_loglik, fisher_information = res$fisher_information)
					}
				},
				fit_ok = function(mod, X_fit, keep){
					if (is.null(mod) || length(mod$b) < 1L || !is.finite(mod$b[1])) return(FALSE)
					if (estimate_only) return(TRUE)
					is.finite(mod$ssq_b_j) && mod$ssq_b_j > 0
				}
			)
			if (!is.null(attempt$fit)){
				private$set_fit_warm_start(attempt$fit$params, "params", fisher = attempt$fit$fisher_information)
				private$best_Xmm_colnames = setdiff(colnames(attempt$X), "treatment")
				if (!estimate_only) {
					n_alpha = length(attempt$fit$params) - ncol(attempt$X)
					private$cached_values$likelihood_test_context = list(
						X = attempt$X,
						j_treat = as.integer(n_alpha + 1L),
						full_params = attempt$fit$params,
						full_neg_loglik = attempt$fit$neg_loglik
					)
				} else {
					private$cached_values$likelihood_test_context = NULL
				}
				list(b = c(0, attempt$fit$b[1]), ssq_b_2 = attempt$fit$ssq_b_j)
			} else {
				private$cached_values$likelihood_test_context = NULL
				NULL
			}
		},
		get_likelihood_test_spec = function(){
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx)) return(NULL)
			X_fit = ctx$X
			y = as.numeric(private$y)
			j_treat = as.integer(ctx$j_treat)
			full_fit = list(params = ctx$full_params, neg_loglik = ctx$full_neg_loglik)
			list(
				X = X_fit, y = y, j = j_treat,
				K = length(sort(unique(y))),
				full_fit = full_fit,
				fit_null = function(delta, start = NULL){
					n_params = length(ctx$full_params)
					res = tryCatch(
						fast_adjacent_category_logit_cpp(
							X_fit, y,
							fixed_idx = j_treat, fixed_values = delta,
							warm_start_params = start %||% private$get_fit_warm_start_for_length("params", n_params),
							warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
							smart_cold_start = private$smart_cold_start_default
						),
						error = function(e) NULL
					)
					if (is.null(res) || length(res) == 0L) return(NULL)
					list(params = as.numeric(res$params), neg_loglik = as.numeric(res$neg_loglik))
				},
				extract_start = function(fit){ as.numeric(fit$params) },
				score = function(fit){
					get_adjacent_category_logit_score_cpp(X_fit, y, as.numeric(fit$params))
				},
				observed_information = function(fit){
					-get_adjacent_category_logit_hessian_cpp(X_fit, y, as.numeric(fit$params))
				},
				fisher_information = function(fit){
					fit$fisher_information %||% (-get_adjacent_category_logit_hessian_cpp(X_fit, y, as.numeric(fit$params)))
				},
				information = function(fit){
					fit$information %||% fit$fisher_information %||% (-get_adjacent_category_logit_hessian_cpp(X_fit, y, as.numeric(fit$params)))
				},
				neg_loglik = function(fit){ as.numeric(fit$neg_loglik) }
			)
		},
		supports_lik_ratio_param_bootstrap = function() TRUE,
		simulate_under_lik_null = function(spec, delta, null_fit){
			params_null = as.numeric(null_fit$params)
			n_params    = length(params_null)
			K           = as.integer(spec$K)
			n_alpha     = K - 1L
			X_fit       = spec$X
			j           = spec$j
			n           = nrow(X_fit)

			alphas = params_null[seq_len(n_alpha)]
			betas  = params_null[(n_alpha + 1L):n_params]
			cum_alpha_right = rev(cumsum(rev(alphas)))

			eta = as.numeric(X_fit %*% betas)
			y_sim = integer(n)
			for (i in seq_len(n)){
				e     = eta[i]
				log_u = c(cum_alpha_right - (K - seq_len(n_alpha)) * e, 0)
				log_u = log_u - max(log_u)
				p     = exp(log_u)
				p     = pmax(p, 0)
				s     = sum(p)
				y_sim[i] = if (is.finite(s) && s > 0) sample.int(K, 1L, prob = p / s) else 1L
			}
			if (length(unique(y_sim)) < K) return(NULL)

			ws   = private$get_fit_warm_start_for_length("params", n_params) %||% params_null
			full = tryCatch(
				fast_adjacent_category_logit_cpp(
					X = X_fit, y = y_sim,
					warm_start_params = ws,
					warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params)
				),
				error = function(e) NULL
			)
			if (is.null(full) || !isTRUE(full$converged)) return(NULL)
			list(
				full_fit = full,
				fit_null = function(d, start = NULL){
					ws2 = start %||% private$get_fit_warm_start_for_length("params", n_params) %||% params_null
					f2  = tryCatch(
						fast_adjacent_category_logit_cpp(
							X = X_fit, y = y_sim,
							warm_start_params = ws2,
							warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
							fixed_idx = j, fixed_values = d
						),
						error = function(e) NULL
					)
					if (is.null(f2) || !isTRUE(f2$converged)) return(NULL)
					f2
				},
				neg_loglik = function(fit) as.numeric(fit$neg_loglik %||% fit$neg_ll)
			)
		},
				build_design_matrix = function(){
			X_cov = private$X
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

	OrdinalAdjacentCategoryLikelihoodSource = inference_component_source_parts(InferenceOrdinalAdjCatLogitRegr)

	InferenceOrdinalAdjCatLogitRegr = define_inference_class(
		classname = "InferenceOrdinalAdjCatLogitRegr",
		inherit = Inference,
		components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "OrdinalAdjacentCategoryLikelihood"),
		public = list(
			compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
		),
		metadata = list(
			response_types = "ordinal",
			likelihood_tier = "full",
			capabilities = "likelihood_ratio"
		),
		overrides = list(
			public = c(
				"compute_rand_two_sided_pval",
				"compute_asymp_confidence_interval",
				"compute_asymp_two_sided_pval",
				"compute_estimate",
				"compute_estimate_with_bootstrap_weights",
				"get_supported_testing_types", "set_testing_type"
			),
			private = c(
				"supports_bayesian_bootstrap",
				"resolve_jackknife_unit",
				"jackknife_block_size_gt_one_unsupported",
				"mark_jackknife_nonestimable_if_block_unsupported",
				"supports_reusable_bootstrap_worker",
				"get_bootstrap_worker_spec",
				"create_bootstrap_worker_state",
				"load_bootstrap_sample_into_worker",
				"compute_bootstrap_worker_estimate",
				"get_supported_testing_types_impl",
				"supports_bartlett_likelihood_ratio_approx",
				"get_bartlett_factor_approx",
				"compute_treatment_estimate_during_randomization_inference",
				"get_standard_error",
				"get_degrees_of_freedom",
				"make_warm_fit_null_wrapper",
				"compute_likelihood_test_two_sided_pval",
				"compute_score_two_sided_pval_impl",
				"compute_gradient_two_sided_pval_impl",
				"compute_lik_ratio_two_sided_pval_impl",
				"get_likelihood_test_spec",
				"supports_likelihood_tests",
				"get_complexity_tier",
				"supports_lik_ratio_param_bootstrap",
				"simulate_under_lik_null",
				"generate_mod"
			)
		)
	)
