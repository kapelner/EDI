#' Zero/One-Inflated Beta Inference for Proportion Responses
#'
#' Internal class for non-KK zero/one-inflated beta regression models. The
#' response is modeled as a three-component mixture with point masses at 0 and 1
#' plus a beta-distributed interior component on \eqn{(0, 1)}. The reported
#' treatment effect is the treatment coefficient from the beta mean submodel, on
#' the logit scale, \strong{conditional on the response falling strictly inside
#' \eqn{(0, 1)}}: it is not, and should not be read as, the effect on the
#' unconditional mean \eqn{E[Y]}, which also depends on how treatment shifts the
#' zero/one inflation probabilities. A design where treatment moves mass between
#' the point masses and the interior, with no shift in the interior beta mean,
#' will report a null treatment coefficient here even though \eqn{E[Y]} changed.
#'
#' @details
#' The beta mean submodel uses treatment alone in the univariate class and
#' treatment plus covariates in the multivariate class. The zero/one inflation
#' submodels use \code{model_formula_zero_one}, which defaults to \code{~ .}
#' so that treatment plus all available covariates enter those auxiliary pieces.
#' See the class-level description above for what the reported coefficient does
#' and does not represent; a marginal (unconditional-mean) estimand is not yet
#' implemented for this class (see \code{marginal_estimand_report.md}).
#'
#' @references Ospina, R., and Ferrari, S. L. P. (2010). "Inflated beta
#'   distributions." \emph{Statistical Papers}, 51(1), 111-126,
#'   \doi{10.1007/s00362-008-0125-4}, for the zero/one-inflated beta
#'   mixture density; Ferrari, S., and Cribari-Neto, F. (2004). "Beta
#'   regression for modelling rates and proportions." \emph{Journal of
#'   Applied Statistics}, 31(7), 799-815,
#'   \doi{10.1080/0266476042000214501}, for the interior beta-regression
#'   submodel.
#'
#' @seealso \code{\link[EDI:InferencePropBetaRegr]{InferencePropBetaRegr}}
#'   for the plain (non-inflated) beta regression model.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'proportion')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(runif(10))
#' inf = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferencePropZeroOneInflatedBetaRegr = define_inference_class(
	classname = "InferencePropZeroOneInflatedBetaRegr",
	inherit = Inference,
	# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
	# migration ladders): like InferencePropBetaRegr, no pre-registered
	# per-class component existed for this class -- declared inline.
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "StandardModelCache"),
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio"),
	overrides = list(
		public = c(
			"compute_estimate", "compute_rand_two_sided_pval",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"get_supported_testing_types", "compute_estimate_with_bootstrap_weights"
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
			"get_complexity_tier"
		)
	),
	public = list(
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize inference for the three-component zero/one-inflated
		#'   beta mixture model; see
		#'   \code{\link[EDI:InferencePropZeroOneInflatedBetaRegr]{InferencePropZeroOneInflatedBetaRegr}}
		#'   for the model form and the important caveat that the reported treatment
		#'   coefficient is conditional on the interior \eqn{(0,1)} component, not an
		#'   unconditional-mean effect. Does not fit the model; the fit is deferred to
		#'   the first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with a proportion response.
		#' @param model_formula Optional formula for covariate adjustment. If \code{NULL}
		#'   (default), the formula from the design object is used and its pre-computed
		#'   design matrix is reused. If a formula is provided, a new design matrix is
		#'   constructed from the design's imputed covariates.
		#' @param model_formula_zero_one Formula for the zero/one inflation submodels.
		#'   Defaults to \code{~ .}, meaning treatment plus all available covariates.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, model_formula_zero_one = NULL, verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "proportion")
				assertFormula(model_formula_zero_one, null.ok = TRUE)
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
			if (is.null(model_formula_zero_one)) {
				model_formula_zero_one = if (is.null(model_formula)) ~ . else model_formula
			}
			private$model_formula_zero_one = model_formula_zero_one
		},
		#' @description Fits the zero/one-inflated beta mixture model by maximum
		#'   likelihood (jointly the beta mean submodel, the zero/one inflation
		#'   submodels, and the beta precision) and returns \eqn{\hat\beta_T}, the
		#'   treatment log-odds-ratio from the beta mean submodel \strong{conditional
		#'   on the interior \eqn{(0,1)} component} — see
		#'   \code{\link[EDI:InferencePropZeroOneInflatedBetaRegr]{InferencePropZeroOneInflatedBetaRegr}}'s
		#'   estimand caveat.
		#' @param estimate_only If TRUE, skip standard-error computation and cache
		#'   only the point estimate; used by randomization and bootstrap resampling
		#'   paths.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Refits the zero/one-inflated beta model with subject/block-level
		#'   weights applied to the fitting log-likelihood (Bayesian-bootstrap or
		#'   nonparametric-bootstrap draw weights, expanded to row level via
		#'   \code{private$expand_subject_or_block_weights_to_row_weights()}), and
		#'   returns the reweighted conditional log-odds-ratio estimate
		#'   \eqn{\hat\beta_T^{(w)}}.
		#' @param subject_or_block_weights Bootstrap weights at the subject or block level.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			X = private$build_component_matrix(private$model_formula, private$best_X_colnames)
			X_zero_one = private$build_component_matrix(private$model_formula_zero_one, private$best_X_zero_one_colnames)
			y = as.numeric(private$y)
			is_zero = as.numeric(y == 0)
			is_one = as.numeric(y == 1)
			is_mid = y > 0 & y < 1
			zero_fit = tryCatch(
				fast_logistic_regression_weighted_cpp(
					X = X_zero_one,
					y = is_zero,
					weights = row_weights
				),
				error = function(e) NULL
			)
			one_fit = tryCatch(
				fast_logistic_regression_weighted_cpp(
					X = X_zero_one,
					y = is_one,
					weights = row_weights
				),
				error = function(e) NULL
			)
			if (!any(is_mid)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			X_mid = X[is_mid, , drop = FALSE]
			y_mid = sanitize_beta_response(y[is_mid])
			w_mid = row_weights[is_mid]
			beta_fit = tryCatch({
				if (check_package_installed("betareg")) {
					df_mid = as.data.frame(X_mid[, -1, drop = FALSE])
					df_mid$y = y_mid
					suppressWarnings(
						betareg::betareg(
							y ~ .,
							data = df_mid,
							weights = w_mid,
							control = betareg::betareg.control(start = list(phi = 10))
						)
					)
				} else {
					NULL
				}
			}, error = function(e) NULL)
			if (!is.null(beta_fit)) {
				coef_vec = stats::coef(beta_fit)[colnames(X_mid)]
				beta_hat = coef_vec[2L]
			}
			if (is.null(beta_fit) || !is.finite(beta_hat)) {
				lm_fit = tryCatch(
					stats::lm.wfit(x = X_mid, y = logit(y_mid), w = w_mid),
					error = function(e) NULL
				)
				if (is.null(lm_fit) || length(lm_fit$coefficients) < 2L) {
					private$cached_values$beta_hat_T = NA_real_
					private$cached_values$s_beta_hat_T = NA_real_
					private$cached_values$df = NA_real_
					return(NA_real_)
				}
				coef_vec = as.numeric(lm_fit$coefficients)
				beta_hat = coef_vec[2L]
			}
			if (!is.finite(beta_hat)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			private$cached_values$beta_hat_T = as.numeric(beta_hat)
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = NA_real_
			private$cached_values$full_coefficients = coef_vec
			private$cached_values$summary_table = NULL
			private$cached_values$zero_coefficients = if (!is.null(zero_fit)) zero_fit$b else NULL
			private$cached_values$one_coefficients = if (!is.null(one_fit)) one_fit$b else NULL
			private$cached_values$beta_hat_T
		}
		# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
		# migration ladders): dropped the pure-passthrough
		# approximate_bootstrap_distribution_beta_hat_T override (was just
		# `super$approximate_bootstrap_distribution_beta_hat_T(...)`, no added
		# logic) -- composed classes have no `super$` chain, and since it
		# added no behavior, the composed NonparametricBootstrap component's
		# own version is used directly with no change in behavior.
	),
	private = list(
		# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
		# migration ladders): see inference_incid_log_regr_private's
		# cached_mod entry (inference_incidence_logit.R) for the eager-NULL-
		# dropping explanation. cached_vc_params was previously undeclared
		# entirely (created dynamically on first assignment).
		cached_mod = NULL,
		cached_vc_params = NULL,
		best_X_colnames = NULL,
		best_X_zero_one_colnames = NULL,
		model_formula_zero_one = NULL,
		build_component_matrix = function(model_formula, selected_colnames = NULL, treatment_name = "treatment"){
			if (is.null(selected_colnames)) {
				if (identical(model_formula, ~ .)) {
					X_cov = private$get_X()
				} else {
					X_imp = private$des_obj$get_X_imp()
					X_cov = if (is.null(X_imp)) matrix(NA_real_, nrow = private$n, ncol = 0) else create_model_matrix_from_features(model_formula, X_imp)
				}
			} else {
				if (identical(model_formula, ~ .)) {
					X_cov_all = private$get_X()
				} else {
					X_imp = private$des_obj$get_X_imp()
					X_cov_all = if (is.null(X_imp)) matrix(NA_real_, nrow = private$n, ncol = 0) else create_model_matrix_from_features(model_formula, X_imp)
				}
				X_cov = if (is.null(X_cov_all) || !length(selected_colnames)) matrix(NA_real_, nrow = private$n, ncol = 0) else as.matrix(X_cov_all[, intersect(selected_colnames, colnames(X_cov_all)), drop = FALSE])
			}
			if (is.null(X_cov) || ncol(as.matrix(X_cov)) == 0L) {
				X_fit = cbind(`(Intercept)` = 1, treatment = private$w)
				colnames(X_fit)[2] = treatment_name
				return(X_fit)
			}
			X_fit = cbind(`(Intercept)` = 1, treatment = private$w, as.matrix(X_cov))
			colnames(X_fit)[2] = treatment_name
			X_fit
		},
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			if (is.null(private$best_X_colnames)){
				private$shared(estimate_only = TRUE)
			}
			if (is.null(private$best_X_colnames)){
				return(self$compute_estimate(estimate_only = estimate_only))
			}
			X = private$build_component_matrix(private$model_formula, private$best_X_colnames)
			X_zero_one = private$build_component_matrix(private$model_formula_zero_one, private$best_X_zero_one_colnames)

			start_len = ncol(X) + 1L + 2L * ncol(X_zero_one)
			vc_start = ncol(X) + 1L
			n_vc = 1L + 2L * ncol(X_zero_one)
			has_vc = !is.null(private$cached_vc_params) && length(private$cached_vc_params) == n_vc && all(is.finite(private$cached_vc_params))
			res = tryCatch(
				fast_zero_one_inflated_beta_cpp(
					X, X_zero_one, private$y,
					warm_start_params = private$get_fit_warm_start_for_length("params", start_len) %||% rep(0, start_len),
					smart_cold_start = private$smart_cold_start_default,
					warm_start_fisher_info = private$get_fit_warm_start_fisher(start_len),
					fixed_idx    = if (has_vc) as.integer(vc_start:(vc_start + n_vc - 1L)) else NULL,
					fixed_values = if (has_vc) as.numeric(private$cached_vc_params) else NULL
				),
				error = function(e) NULL
			)
			if (is.null(res) || length(res$b) < 2 || !is.finite(res$b[2])) return(NA_real_)
			private$set_fit_warm_start(as.numeric(res$params), "params", fisher = res$fisher_information)
			as.numeric(res$b[2])
		},
		supports_reusable_bootstrap_worker = function(){
			FALSE
		},
		supports_likelihood_tests = function(){
			TRUE
		},
		get_likelihood_test_spec = function(){
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			X_fit = ctx$X
			X_zero_one = ctx$X_zero_one
			y = as.numeric(private$y)
			j_treat = as.integer(ctx$j_treat)
			full_params = ctx$full_params
			start_len = ncol(X_fit) + 1L + 2L * ncol(X_zero_one)
			list(
				X = X_fit, X_zero_one = X_zero_one, y = y, j = j_treat,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					warm_start_params = start %||% private$get_fit_warm_start_for_length("params", start_len) %||% (if (!is.null(full_params)) as.numeric(full_params) else rep(0, start_len))
					warm_fisher = private$get_fit_warm_start_fisher(start_len)
					res = tryCatch(
						fast_zero_one_inflated_beta_cpp(
							X_fit,
							X_zero_one,
							y,
							warm_start_params = warm_start_params,
							smart_cold_start = private$smart_cold_start_default,
							warm_start_fisher_info = warm_fisher,
							fixed_idx = j_treat,
							fixed_values = delta
						),
						error = function(e) NULL
					)
					if (is.null(res)) return(NULL)
					res
				},
				extract_start = function(fit){
					as.numeric(fit$params)
				},
				score = function(fit){
					get_zero_one_inflated_beta_score_cpp(X_fit, X_zero_one, y, as.numeric(fit$params))
				},
				observed_information = function(fit){
					as.matrix(fit$observed_information %||% -get_zero_one_inflated_beta_hessian_cpp(X_fit, X_zero_one, y, as.numeric(fit$params)))
				},
				fisher_information = function(fit){
					as.matrix(fit$fisher_information %||% fit$information %||% fit$observed_information %||% -get_zero_one_inflated_beta_hessian_cpp(X_fit, X_zero_one, y, as.numeric(fit$params)))
				},
				information = function(fit){
					as.matrix(fit$information %||% fit$fisher_information %||% fit$observed_information %||% -get_zero_one_inflated_beta_hessian_cpp(X_fit, X_zero_one, y, as.numeric(fit$params)))
				},
				neg_loglik = function(fit){ as.numeric(fit$neg_loglik) }
			)
		},
		generate_mod = function(estimate_only = FALSE){
			X_full = private$build_component_matrix(private$model_formula)
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 2L,
				fit_fun = function(X_fit, keep){
					j_treat = which(keep == 2L)
					if (is.null(private$best_X_zero_one_colnames)) {
						X_zero_one_full = private$build_component_matrix(private$model_formula_zero_one)
						red_zo = private$reduce_design_matrix_preserving_treatment(X_zero_one_full)
						X_zero_one = red_zo$X
						if (is.null(X_zero_one)) return(NULL)
						colnames(X_zero_one) = colnames(X_zero_one_full)[red_zo$keep]
					} else {
						X_zero_one = private$build_component_matrix(private$model_formula_zero_one, private$best_X_zero_one_colnames)
					}
					
					start_len = ncol(X_fit) + 1L + 2L * ncol(X_zero_one)
					warm_start_params = private$get_fit_warm_start_for_length("params", start_len) %||% rep(0, start_len)
					res = tryCatch(
						fast_zero_one_inflated_beta_cpp(
							X_fit, X_zero_one, private$y, 
							warm_start_params = warm_start_params,
							smart_cold_start = private$smart_cold_start_default,
							warm_start_fisher_info = private$get_fit_warm_start_fisher(start_len)
						),
						error = function(e) NULL
					)
					if (is.null(res)) return(NULL)
					private$set_fit_warm_start(as.numeric(res$params), "params", fisher = res$fisher_information)
					
					ssq_b_j = if (!is.null(res$vcov) && nrow(res$vcov) >= j_treat) {
						as.numeric(res$vcov[j_treat, j_treat])
					} else {
						NA_real_
					}
						list(
							b = as.numeric(res$b),
							beta_hat_T = as.numeric(res$b[j_treat]),
							ssq_b_2 = ssq_b_j,
							ssq_b_j = ssq_b_j,
							j_treat = j_treat,
							params = as.numeric(res$params),
						neg_loglik = as.numeric(res$neg_loglik),
						X_zero_one = X_zero_one
					)
				},
				fit_ok = function(mod, X_fit, keep){
					j_treat = mod$j_treat
					!is.null(mod) && length(mod$b) >= j_treat && is.finite(mod$b[j_treat])
				}
			)
			if (!is.null(attempt$fit)){
				private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
				private$best_X_zero_one_colnames = setdiff(colnames(attempt$fit$X_zero_one), c("(Intercept)", "treatment"))
				if (!is.null(attempt$fit$params)) {
					vc_start = ncol(attempt$X) + 1L
					vc_vals = as.numeric(attempt$fit$params[vc_start:length(attempt$fit$params)])
					if (all(is.finite(vc_vals))) private$cached_vc_params = vc_vals
				}
				private$cached_values$likelihood_test_context = list(
					X = attempt$X,
					X_zero_one = attempt$fit$X_zero_one,
					j_treat = attempt$fit$j_treat,
					full_params = attempt$fit$params
				)
			} else {
				private$cached_values$likelihood_test_context = NULL
			}
			attempt$fit
		},
		supports_lik_ratio_param_bootstrap = function() TRUE,
		simulate_under_lik_null = function(spec, delta, null_fit){
			X        = spec$X
			X_zo     = spec$X_zero_one
			j        = spec$j
			n        = nrow(X)
			p        = ncol(X)
			q        = ncol(X_zo)
			params   = as.numeric(null_fit$params)
			if (length(params) < p + 1L + 2L * q) return(NULL)
			b_beta   = params[seq_len(p)]
			log_phi  = params[p + 1L]
			b_zero   = params[(p + 2L):(p + 1L + q)]
			b_one    = params[(p + 1L + q + 1L):(p + 1L + 2L * q)]
			phi_val  = exp(min(log_phi, 15))
			if (!is.finite(phi_val) || phi_val <= 0) return(NULL)
			mu_i  = plogis(as.numeric(X %*% b_beta))
			p0_i  = plogis(as.numeric(X_zo %*% b_zero))
			p1_i  = plogis(as.numeric(X_zo %*% b_one))
			p_b_i = pmax(1 - p0_i - p1_i, 0)
			tot   = p0_i + p1_i + p_b_i
			p0_i  = p0_i / tot; p1_i = p1_i / tot; p_b_i = p_b_i / tot
			u = runif(n)
			y_sim = numeric(n)
			for (i in seq_len(n)){
				if (u[i] < p0_i[i]){
					y_sim[i] = 0
				} else if (u[i] < p0_i[i] + p1_i[i]){
					y_sim[i] = 1
				} else {
					a = mu_i[i] * phi_val
					b = (1 - mu_i[i]) * phi_val
					y_sim[i] = rbeta(1L, max(a, 1e-4), max(b, 1e-4))
				}
			}
			y_sim = pmin(pmax(y_sim, 0), 1)
			start_len = p + 1L + 2L * q
			ws = as.numeric(params)
			full_res = tryCatch(
				fast_zero_one_inflated_beta_cpp(
					X, X_zo, y_sim,
					warm_start_params = ws,
					smart_cold_start = private$smart_cold_start_default
				),
				error = function(e) NULL
			)
			if (is.null(full_res) || length(full_res$b) < j || !is.finite(full_res$b[j])) return(NULL)
			list(
				full_fit = full_res,
				fit_null = function(d, start = NULL){
					ws_null = start %||% as.numeric(full_res$params %||% ws)
					tryCatch(
						fast_zero_one_inflated_beta_cpp(
							X, X_zo, y_sim,
							warm_start_params = ws_null,
							smart_cold_start = private$smart_cold_start_default,
							fixed_idx = j, fixed_values = d
						),
						error = function(e) NULL
					)
				},
				neg_loglik = function(fit){ as.numeric(fit$neg_loglik) }
			)
		}
	)
)
