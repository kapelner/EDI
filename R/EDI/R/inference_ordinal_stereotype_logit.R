OrdinalStereotypeLikelihoodSource = list(
	public = list(
		#' @description Initialize inference for the stereotype logit model; see
		#'   \code{\link[EDI:InferenceOrdinalStereotypeLogitRegr]{InferenceOrdinalStereotypeLogitRegr}}
		#'   for the model form. Does not fit the model; the fit is deferred to the
		#'   first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with an ordinal response.
		#' @param model_formula   Optional formula for covariate adjustment.
		#' @param verbose Whether to print progress messages.
		#' @param harden Whether to apply robustness measures.
		#' @param smart_cold_start_default Whether to use smart cold starts.
		initialize = function(des_obj, verbose = FALSE, harden = TRUE, model_formula = NULL, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "ordinal")
			}
			super$initialize(des_obj, verbose = verbose, harden = harden, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Recomputes the treatment estimate under subject/block-level
		#'   bootstrap weights (Bayesian-bootstrap or nonparametric-bootstrap draw
		#'   weights). Rather than refitting the full reduced-rank stereotype model
		#'   under weights, calls \code{weighted_ordinal_bootstrap_surrogate_fit()}
		#'   — a fast weighted ordinal-logistic surrogate fit on the raw design
		#'   matrix — as an approximation to the weighted stereotype likelihood; the
		#'   surrogate does not re-estimate the \eqn{\phi_k} category scores. No
		#'   standard error is computed (\code{s_beta_hat_T} is always \code{NA});
		#'   the surrogate returns \code{NA} if the fit fails.
		#' @param subject_or_block_weights Subject-, block-, cluster-, or matched-set
		#'   bootstrap weights.
		#' @param estimate_only If \code{TRUE}, compute only the weighted point
		#'   estimate.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			X_fit = private$build_design_matrix()
			if (!is.null(private$best_Xmm_colnames)) {
				keep = c("treatment", intersect(private$best_Xmm_colnames, colnames(X_fit)))
				X_fit = X_fit[, keep, drop = FALSE]
			}
			fit = weighted_ordinal_bootstrap_surrogate_fit(X_fit, private$y, row_weights, method = "logistic")
			if (is.null(fit) || !private$stereotype_treatment_estimate_is_usable(fit$beta_hat)) {
				private$cache_nonestimable_estimate("stereotype_logit_weighted_fit_unusable")
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			private$cached_values$beta_hat_T = as.numeric(fit$beta_hat)
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = NA_real_
			private$cached_values$full_coefficients = fit$coefficients
			private$cached_values$summary_table = NULL
			private$clear_nonestimable_state()
			private$cached_values$beta_hat_T
		}
	),
	private = list(
		supports_likelihood_tests = function(){ TRUE },
		# The weighted hook above is not estimator-preserving. Keep every public
		# Bayesian-bootstrap entry point disabled until the native weighted
		# stereotype-logit backend plan is complete.
		supports_bayesian_bootstrap = function() FALSE,
		best_Xmm_colnames = NULL,
		get_complexity_tier = function() "heavy",
		# Temporary class-local guard. Remove this when the centralized fit
		# diagnostics/acceptance policy in public_diagnostics_api_spec.md lands.
		stereotype_treatment_estimate_is_usable = function(beta){
			beta = suppressWarnings(as.numeric(beta)[1L])
			is.finite(beta) && abs(beta) <= 10
		},
		stereotype_fit_is_usable = function(fit, require_standard_error = FALSE, check_treatment = TRUE, fixed_idx = NULL, require_information_pd = TRUE){
			if (is.null(fit) || !isTRUE(fit$converged)) return(FALSE)
			if (check_treatment) {
				beta = suppressWarnings(as.numeric(fit$b)[1L])
				if (!is.finite(beta) || abs(beta) > 10) return(FALSE)
			}

			information = fit$fisher_information
			if (!is.null(information)) {
				information = suppressWarnings(as.matrix(information))
				if (nrow(information) < 1L || nrow(information) != ncol(information) || any(!is.finite(information))) {
					return(FALSE)
				}
				information = (information + t(information)) / 2

				# require_information_pd = FALSE: this fit is only ever going to
				# supply a neg_loglik value (a parametric-bootstrap LR replicate's
				# full/unconstrained refit -- see simulate_under_lik_null() below),
				# never a variance/SE. The stereotype model's gamma (loading)
				# parameters are a textbook Davies-type non-regular case: they are
				# NOT identified when the treatment coefficient beta is at/near
				# zero -- exactly the neighborhood every null-simulated bootstrap
				# replicate's true DGP sits in, so the Fisher information is
				# expected to be near-singular in the gamma directions on this
				# refit, not a sign of a broken fit. neg_loglik itself doesn't
				# depend on the information matrix being invertible, so skip the
				# PD/conditioning gate entirely for this use; convergence,
				# coefficient-finiteness, and information-finiteness (checked
				# above) remain the real usability signals here.
				if (require_information_pd) {
					# A delta-constrained null fit (fixed_idx = the held-fixed
					# treatment coefficient) can leave other parameters structurally
					# unidentified too -- e.g. a stereotype loading whose only
					# nonzero information entries are cross-terms with the now-fixed
					# treatment column, so its row collapses to all-zero once that
					# column is excluded. Cascade the exclusion until no further
					# all-zero rows remain, then check PD/conditioning only over the
					# parameters genuinely identified at this fit (see
					# InferenceIncidKKCondLogitOneLik's assess_combined_fit() for the
					# same pattern).
					free_idx = seq_len(nrow(information))
					if (!is.null(fixed_idx)) {
						fixed_idx_int = suppressWarnings(as.integer(fixed_idx))
						fixed_idx_int = fixed_idx_int[is.finite(fixed_idx_int) & fixed_idx_int >= 1L & fixed_idx_int <= nrow(information)]
						free_idx = setdiff(free_idx, fixed_idx_int)
						repeat {
							if (length(free_idx) < 1L) break
							sub = information[free_idx, free_idx, drop = FALSE]
							row_max = apply(abs(sub), 1L, max)
							zero_local = which(row_max <= 1e-8)
							if (length(zero_local) == 0L) break
							free_idx = free_idx[-zero_local]
						}
					}
					if (length(free_idx) < 1L) return(FALSE)
					information_free = information[free_idx, free_idx, drop = FALSE]
					is_positive_definite = !is.null(tryCatch(chol(information_free), error = function(e) NULL))
					reciprocal_condition = tryCatch(rcond(information_free), error = function(e) NA_real_)
					if (!is_positive_definite || !is.finite(reciprocal_condition) || reciprocal_condition <= sqrt(.Machine$double.eps)) {
						return(FALSE)
					}
				}
			}

			if (require_standard_error) {
				ssq = suppressWarnings(as.numeric(fit$ssq_b_j %||% fit$ssq_b_1)[1L])
				if (!is.finite(ssq) || ssq <= 0) return(FALSE)
			}
			TRUE
		},
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

			n_params = (length(sort(unique(private$y))) - 1L) + ncol(X)
			if (length(sort(unique(private$y))) >= 3) n_params = n_params + (length(sort(unique(private$y))) - 2L)
			
			ws_args = private$get_backend_warm_start_args(n_params)
			ws_fisher = ws_args$warm_start_fisher_info
			res = tryCatch(
				fast_stereotype_logit_cpp(
					X = X, y = as.numeric(private$y),
					warm_start_params = ws_args$start_params,
					warm_start_fisher_info = ws_fisher,
					estimate_only = TRUE
				),
				error = function(e) NULL
			)
			if (!private$stereotype_fit_is_usable(res)){
				return(NA_real_)
			}
			private$set_fit_warm_start(as.numeric(res$params), "params", fisher = ws_fisher)
			as.numeric(res$b[1])
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
					K = length(sort(unique(private$y)))
					n_params = (K - 1L) + ncol(X_fit)
					if (K >= 3) n_params = n_params + (K - 2L)
					ws_args = private$get_backend_warm_start_args(n_params)
					res = fast_stereotype_logit_cpp(
						X_fit, private$y,
						warm_start_params = ws_args$start_params,
						warm_start_fisher_info = ws_args$warm_start_fisher_info
					)
					res$ssq_b_j = NA_real_
					if (!private$stereotype_fit_is_usable(res)) return(NULL)
					res
				}
			)
		},
		generate_mod = function(estimate_only = FALSE){
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 1L,
				fit_fun = function(X_fit){
					K = length(sort(unique(private$y)))
					n_params = (K - 1L) + ncol(X_fit)
					if (K >= 3) n_params = n_params + (K - 2L)
					ws_args = private$get_backend_warm_start_args(n_params)
					if (estimate_only) {
						res = fast_stereotype_logit_cpp(
							X_fit, private$y,
							warm_start_params = ws_args$start_params,
							warm_start_fisher_info = ws_args$warm_start_fisher_info
						)
						res$ssq_b_j = NA_real_
						res
					} else {
						res = fast_stereotype_logit_with_var_cpp(
							X_fit, private$y,
							warm_start_params = ws_args$start_params,
							warm_start_fisher_info = ws_args$warm_start_fisher_info
						)
						neg_loglik = res$neg_loglik
						if (is.null(neg_loglik) || length(neg_loglik) != 1L || !is.finite(neg_loglik)) {
							lik_fit = fast_stereotype_logit_cpp(
								X_fit, private$y,
								warm_start_params = res$params,
								warm_start_fisher_info = res$fisher_information,
								estimate_only = TRUE
							)
							neg_loglik = lik_fit$neg_loglik
						}
						res$ssq_b_j = res$ssq_b_1
						res$neg_loglik = neg_loglik
						res
					}
				},
				fit_ok = function(mod, X_fit, keep){
					private$stereotype_fit_is_usable(mod, require_standard_error = !estimate_only)
				}
			)
			# fit_with_hardened_qr_column_dropping() falls back to its best/last
			# attempt even when NO candidate ever satisfied fit_ok (e.g. every
			# column-dropped refit still diverges under quasi-separation) --
			# see its own comment. Re-check usability here so a fit the
			# stereotype_fit_is_usable() guard has already flagged as unusable
			# (the |beta| <= 10 divergence ceiling, an unfinished info matrix,
			# etc.) is never silently accepted as the point estimate.
			if (!is.null(attempt$fit) && !private$stereotype_fit_is_usable(attempt$fit, require_standard_error = !estimate_only)) {
				attempt$fit = NULL
			}
			if (!is.null(attempt$fit)){
				private$set_fit_warm_start(attempt$fit$params, "params", fisher = attempt$fit$fisher_information)
				private$best_Xmm_colnames = setdiff(colnames(attempt$X), "treatment")
				if (!estimate_only) {
					n_alpha = length(sort(unique(private$y))) - 1L
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
						fast_stereotype_logit_cpp(
							X_fit, y,
							fixed_idx = j_treat, fixed_values = delta,
							warm_start_params = start %||% private$get_fit_warm_start_for_length("params", n_params),
							warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
							smart_cold_start = private$smart_cold_start_default
						),
						error = function(e) NULL
					)
					if (!private$stereotype_fit_is_usable(res, check_treatment = FALSE, fixed_idx = j_treat)) return(NULL)
					list(params = as.numeric(res$params), neg_loglik = as.numeric(res$neg_loglik))
				},
				extract_start = function(fit){ as.numeric(fit$params) },
				score = function(fit){
					get_stereotype_logit_score_cpp(X_fit, y, as.numeric(fit$params))
				},
				observed_information = function(fit){
					-get_stereotype_logit_hessian_cpp(X_fit, y, as.numeric(fit$params))
				},
				fisher_information = function(fit){
					fit$fisher_information %||% (-get_stereotype_logit_hessian_cpp(X_fit, y, as.numeric(fit$params)))
				},
				information = function(fit){
					fit$information %||% fit$fisher_information %||% (-get_stereotype_logit_hessian_cpp(X_fit, y, as.numeric(fit$params)))
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
			n_gamma     = K - 2L
			p           = n_params - n_alpha - n_gamma
			X_fit       = spec$X
			j           = spec$j
			n           = nrow(X_fit)
			if (p < 1L) return(NULL)

			alphas = params_null[seq_len(n_alpha)]
			betas  = params_null[(n_alpha + 1L):(n_alpha + p)]
			gammas = params_null[(n_alpha + p + 1L):n_params]

			eg   = exp(gammas)
			seg  = sum(eg)
			phi  = c(0, cumsum(eg) / (1 + seg), 1)

			eta  = as.numeric(X_fit %*% betas)
			y_sim = integer(n)
			for (i in seq_len(n)){
				logits = c(0, alphas + phi[seq(2L, K)] * eta[i])
				logits = logits - max(logits)
				cat_p = exp(logits)
				s = sum(cat_p)
				y_sim[i] = if (is.finite(s) && s > 0) sample.int(K, 1L, prob = cat_p / s) else 1L
			}
			if (length(unique(y_sim)) < K) return(NULL)

			ws   = private$get_fit_warm_start_for_length("params", n_params) %||% params_null
			full = tryCatch(
				fast_stereotype_logit_cpp(
					X = X_fit, y = y_sim,
					estimate_only = FALSE,
					warm_start_params = ws,
					warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params)
				),
				error = function(e) NULL
			)
			# require_information_pd = FALSE: this refit (and its fit_null below)
			# feed only into neg_loglik() for the LR statistic, never a
			# variance/SE -- see stereotype_fit_is_usable()'s own comment on
			# this flag for why the gamma-direction near-singularity expected
			# here (data simulated under H0: beta = 0) doesn't invalidate the
			# refit.
			if (!private$stereotype_fit_is_usable(full, require_information_pd = FALSE)) return(NULL)
			list(
				full_fit = full,
				fit_null = function(d, start = NULL){
					ws2 = start %||% private$get_fit_warm_start_for_length("params", n_params) %||% params_null
					f2  = tryCatch(
						fast_stereotype_logit_cpp(
							X = X_fit, y = y_sim,
							estimate_only = FALSE,
							warm_start_params = ws2,
							warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
							fixed_idx = j, fixed_values = d
						),
						error = function(e) NULL
					)
					if (!private$stereotype_fit_is_usable(f2, check_treatment = FALSE, fixed_idx = j, require_information_pd = FALSE)) return(NULL)
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

#' Stereotype Logit Regression Inference for Ordinal Responses
#'
#' Fits Anderson's (1984) stereotype logit model for ordinal responses (see
#' \code{\link{fast_stereotype_logit_cpp}} for the full reduced-rank
#' multinomial-softmax formula and reparameterization): a single linear
#' predictor \eqn{\eta_i = \beta_T W_i + X_i^\top \gamma} is scaled by a
#' category-specific \strong{score} \eqn{\phi_k \in [0,1]} (jointly estimated,
#' monotone in \eqn{k}) in a softmax over all \eqn{K} categories, rather than
#' assuming a single proportional/parallel effect across cuts as
#' \code{\link[EDI:InferenceOrdinalContRatioRegr]{InferenceOrdinalContRatioRegr}}/
#' \code{\link[EDI:InferenceOrdinalKKCondAdjCatLogitRegr]{InferenceOrdinalKKCondAdjCatLogitRegr}}
#' do. This makes the stereotype model a genuinely more flexible
#' (multinomial-logit-like, reduced-rank) alternative to the standard
#' proportional-odds/adjacent-category/continuation-ratio ordinal families,
#' at the cost of a less directly interpretable treatment coefficient
#' (\eqn{\beta_T} enters multiplicatively through the \eqn{\phi_k} scores
#' rather than as a single additive log-odds-ratio). \code{likelihood_tier =
#' "full"}: likelihood-ratio, score, gradient, and Wald tests are all
#' available when the model converges, plus parametric-likelihood-bootstrap
#' calibration of the likelihood-ratio test.
#' Bayesian-bootstrap inference is temporarily unavailable because the current
#' non-uniform weighted hook fits a cumulative-logit surrogate rather than the
#' stereotype likelihood. It will remain disabled until the native weighted
#' stereotype-logit backend described in the package implementation plan lands.
#'
#' @references Anderson, J. A. (1984). "Regression and Ordered Categorical
#'   Variables." \emph{Journal of the Royal Statistical Society, Series B},
#'   46(1), 1-30, \doi{10.1111/j.2517-6161.1984.tb01276.x}, for the
#'   stereotype logit model.
#'
#' @seealso \code{\link[EDI:InferenceOrdinalContRatioRegr]{InferenceOrdinalContRatioRegr}}
#'   for a proportional (non-reduced-rank) ordinal alternative. See also:
#'   \href{https://en.wikipedia.org/wiki/Ordinal_regression}{Ordinal
#'   regression} (Wikipedia).
#'
#' @name InferenceOrdinalStereotypeLogitRegr
#' @export
InferenceOrdinalStereotypeLogitRegr = define_inference_class(
	classname = "InferenceOrdinalStereotypeLogitRegr",
	inherit = Inference,
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "OrdinalStereotypeLikelihood"),
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio", response_types = "ordinal"),
	overrides = list(
		public = c(
			"compute_estimate", "compute_rand_two_sided_pval",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"get_supported_testing_types", "set_testing_type", "compute_estimate_with_bootstrap_weights"
		),
		private = c(
			"supports_bayesian_bootstrap",
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
			"get_complexity_tier", "get_bootstrap_worker_spec"
		)
	),
	public = list(
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	)
)

OrdinalContinuationRatioLikelihoodSource = list(
	public = list(
		#' @description Initialize inference for the continuation-ratio ordinal
		#'   regression model; see
		#'   \code{\link[EDI:InferenceOrdinalContRatioRegr]{InferenceOrdinalContRatioRegr}}
		#'   for the model form. Does not fit the model; the fit is deferred to the
		#'   first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with an ordinal response.
		#' @param model_formula   Optional formula for covariate adjustment.
		#' @param verbose Whether to print progress messages.
		#' @param harden Whether to apply robustness measures.
		#' @param smart_cold_start_default Whether to use smart cold starts.
		initialize = function(des_obj, verbose = FALSE, harden = TRUE, model_formula = NULL, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "ordinal")
			}
			super$initialize(des_obj, verbose = verbose, harden = harden, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Recomputes the treatment estimate under subject/block-level
		#'   bootstrap weights (Bayesian-bootstrap or nonparametric-bootstrap draw
		#'   weights). Refits the same continuation-ratio likelihood used by the
		#'   unweighted estimator, copying each subject's weight onto all of that
		#'   subject's augmented binary rows. No standard error is computed
		#'   (\code{s_beta_hat_T} is always \code{NA}); returns \code{NA} if the
		#'   weighted fit fails.
		#' @param subject_or_block_weights Subject-, block-, cluster-, or matched-set
		#'   bootstrap weights.
		#' @param estimate_only If \code{TRUE}, compute only the weighted point
		#'   estimate.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			X_fit = private$build_design_matrix()
			if (!is.null(private$best_Xmm_colnames)) {
				keep = c("treatment", intersect(private$best_Xmm_colnames, colnames(X_fit)))
				X_fit = X_fit[, keep, drop = FALSE]
			}
			n_params = (length(sort(unique(private$y))) - 1L) + ncol(X_fit)
			ws_args = private$get_backend_warm_start_args(n_params)
			res = tryCatch(
				fast_continuation_ratio_regression_weighted_cpp(
					X = X_fit,
					y = as.numeric(private$y),
					weights = row_weights,
					warm_start_beta = ws_args$warm_start_beta,
					warm_start_fisher_info = ws_args$warm_start_fisher_info
				),
				error = function(e) NULL
			)
			if (is.null(res) || length(res$b) < 1L || !is.finite(res$b[1L])) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			private$set_fit_warm_start(res$params, "beta", fisher = res$fisher_information)
			private$cached_values$beta_hat_T = as.numeric(res$b[1L])
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = NA_real_
			private$cached_values$full_coefficients = as.numeric(res$params)
			private$cached_values$summary_table = NULL
			private$cached_values$beta_hat_T
		}
	),
	private = list(
		supports_likelihood_tests = function(){ TRUE },
		best_Xmm_colnames = NULL,
		get_complexity_tier = function() "heavy",
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

			n_params = (length(sort(unique(private$y))) - 1L) + ncol(X)
			ws_args = private$get_backend_warm_start_args(n_params)
			res = tryCatch(
				fast_continuation_ratio_regression_cpp(
					X = X, y = as.numeric(private$y),
					warm_start_beta = ws_args$warm_start_beta,
					warm_start_fisher_info = ws_args$warm_start_fisher_info
				),
				error = function(e) NULL
			)
			if (is.null(res) || length(res$b) < 1L || !is.finite(res$b[length(res$b)])){
				return(NA_real_)
			}
			private$set_fit_warm_start(res$b, "beta", fisher = res$fisher_information)
			as.numeric(res$b[length(res$b)])
		},
		generate_mod = function(estimate_only = FALSE){
			X_full = private$build_design_matrix()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 1L,
				fit_fun = function(X_fit){
					n_params = ncol(X_fit) + length(sort(unique(private$y))) - 1L
					ws_args = private$get_backend_warm_start_args(n_params)
					if (estimate_only) {
						res = fast_continuation_ratio_regression_cpp(
							X_fit, private$y,
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_fisher_info = ws_args$warm_start_fisher_info
						)
						list(b = res$b, ssq_b_j = NA_real_, fisher_information = res$fisher_information)
					} else {
						res = fast_continuation_ratio_regression_with_var_cpp(
							X_fit, private$y,
							warm_start_beta = ws_args$warm_start_beta,
							warm_start_fisher_info = ws_args$warm_start_fisher_info
						)
						list(
							b = res$b,
							ssq_b_j = res$ssq_b_j %||% res$ssq_b_1,
							ssq_b_2 = res$ssq_b_2 %||% res$ssq_b_j %||% res$ssq_b_1,
							params = res$params,
							neg_loglik = res$neg_loglik,
							fisher_information = res$fisher_information
						)
					}
				},
				fit_ok = function(mod, X_fit, keep){
					if (is.null(mod) || length(mod$b) < 1L || !is.finite(mod$b[1])) return(FALSE)
					if (estimate_only) return(TRUE)
					is.finite(mod$ssq_b_j) && mod$ssq_b_j > 0
				}
			)
			if (!is.null(attempt$fit)){
				private$set_fit_warm_start(attempt$fit$b, "beta", fisher = attempt$fit$fisher_information)
				private$best_Xmm_colnames = setdiff(colnames(attempt$X), "treatment")
				if (!estimate_only) {
					n_alpha = length(sort(unique(private$y))) - 1L
					private$cached_values$likelihood_test_context = list(
						X = attempt$X,
						j_treat = as.integer(n_alpha + 1L),
						full_params = attempt$fit$params,
						full_neg_loglik = attempt$fit$neg_loglik
					)
				} else {
					private$cached_values$likelihood_test_context = NULL
				}
				list(
					b = c(0, attempt$fit$b[1]),
					ssq_b_2 = attempt$fit$ssq_b_2 %||% attempt$fit$ssq_b_j
				)
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
			full_fit = list(b = ctx$full_params, params = ctx$full_params, neg_loglik = ctx$full_neg_loglik)
			list(
				X = X_fit, y = y, K = length(sort(unique(private$y))), j = j_treat,
				full_fit = full_fit,
				fit_null = function(delta, start = NULL){
					n_params = length(ctx$full_params)
					res = tryCatch(
						fast_continuation_ratio_regression_cpp(
							X_fit, y,
							fixed_idx = j_treat, fixed_values = delta,
							warm_start_beta = start %||% private$get_fit_warm_start_for_length("beta", n_params),
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
					get_continuation_ratio_regression_score_cpp(X_fit, y, as.numeric(fit$params))
				},
				observed_information = function(fit){
					-get_continuation_ratio_regression_hessian_cpp(X_fit, y, as.numeric(fit$params))
				},
				fisher_information = function(fit){
					fit$fisher_information %||% (-get_continuation_ratio_regression_hessian_cpp(X_fit, y, as.numeric(fit$params)))
				},
				information = function(fit){
					fit$information %||% fit$fisher_information %||% (-get_continuation_ratio_regression_hessian_cpp(X_fit, y, as.numeric(fit$params)))
				},
				neg_loglik = function(fit){ as.numeric(fit$neg_loglik) }
			)
		},
		supports_lik_ratio_param_bootstrap = function() TRUE,
		simulate_under_lik_null = function(spec, delta, null_fit){
			params_null = as.numeric(null_fit$b %||% null_fit$params)
			n_params    = length(params_null)
			K           = as.integer(spec$K)
			n_alpha     = K - 1L
			X_fit       = spec$X
			j           = spec$j
			n           = nrow(X_fit)
			p           = n_params - n_alpha
			if (!is.finite(K) || K < 2L || p < 1L || length(params_null) < n_alpha + p) return(NULL)

			alphas = params_null[seq_len(n_alpha)]
			betas  = params_null[(n_alpha + 1L):n_params]
			eta    = as.numeric(X_fit %*% betas)

			y_sim = integer(n)
			for (i in seq_len(n)){
				k = 1L
				assigned = FALSE
				while (k <= n_alpha){
					# plogis(alphas[k] + eta[i]) = Pr(continue past k | reached k);
					# stop at k (y = k) on the complementary event.
					if (runif(1) >= plogis(alphas[k] + eta[i])){
						y_sim[i] = k
						assigned  = TRUE
						break
					}
					k = k + 1L
				}
				if (!assigned) y_sim[i] = K
			}
			if (length(unique(y_sim)) < K) return(NULL)

			ws   = private$get_fit_warm_start_for_length("beta", n_params) %||% params_null
			full = tryCatch(
				fast_continuation_ratio_regression_cpp(
					X = X_fit, y = y_sim,
					warm_start_beta = ws,
					warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params)
				),
				error = function(e) NULL
			)
			if (is.null(full) || !isTRUE(full$converged)) return(NULL)
			full_fit_boot = list(b = as.numeric(full$params), params = as.numeric(full$params), neg_loglik = as.numeric(full$neg_loglik))
			list(
				worker_data = list(y = y_sim),
				full_fit = full_fit_boot,
				fit_null = function(d, start = NULL){
					ws2 = start %||% private$get_fit_warm_start_for_length("beta", n_params) %||% params_null
					f2  = tryCatch(
						fast_continuation_ratio_regression_cpp(
							X = X_fit, y = y_sim,
							warm_start_beta = ws2,
							warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
							fixed_idx = j, fixed_values = d
						),
						error = function(e) NULL
					)
					if (is.null(f2) || !isTRUE(f2$converged)) return(NULL)
					list(b = as.numeric(f2$params), params = as.numeric(f2$params), neg_loglik = as.numeric(f2$neg_loglik))
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

#' Continuation Ratio Regression Inference for Ordinal Responses
#'
#' Fits a conditional (stratified) continuation-ratio logit model for ordinal
#' responses: for cut \eqn{j = 1, \dots, K-1}, among subjects who have
#' reached at least category \eqn{j}, \deqn{\log\frac{\Pr(Y_i > j \mid Y_i
#' \ge j)}{\Pr(Y_i = j \mid Y_i \ge j)} = \alpha_j + \beta_T W_i + X_i^\top
#' \gamma,} a discrete-time-hazard-model analog for ordinal data, with a
#' treatment coefficient \eqn{\beta_T} constrained equal across all cuts.
#' \eqn{\exp(\hat\beta_T)} is the common "continue vs. stop here" odds ratio:
#' a positive \eqn{\beta_T} means treatment pushes subjects toward higher
#' categories of \eqn{Y}, matching the sign convention of every other ordinal
#' estimator in the package.
#' Fitting proceeds by \code{\link{expand_continuation_ratio_data_cpp}}'s
#' stacked-binary expansion followed by conditional logistic regression on
#' the expanded data. \code{likelihood_tier = "full"}: likelihood-ratio,
#' score, gradient, and Wald tests are all available when the model
#' converges, plus parametric-likelihood-bootstrap calibration of the
#' likelihood-ratio test. Validity requires the continuation-ratio
#' proportionality assumption (a common \eqn{\beta_T} across all \eqn{K-1}
#' cuts).
#'
#' @references Agresti, A. (2010). \emph{Analysis of Ordinal Categorical
#'   Data} (2nd ed.). Wiley, for the continuation-ratio model family.
#'
#' @seealso \code{\link[EDI:InferenceOrdinalStereotypeLogitRegr]{InferenceOrdinalStereotypeLogitRegr}}
#'   and
#'   \code{\link[EDI:InferenceOrdinalKKCondAdjCatLogitRegr]{InferenceOrdinalKKCondAdjCatLogitRegr}}
#'   for related ordinal-logit expansions. See also:
#'   \href{https://en.wikipedia.org/wiki/Ordinal_regression}{Ordinal
#'   regression} (Wikipedia).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'ordinal')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(sample(1:4, 10, replace = TRUE))
#' inf = InferenceOrdinalContRatioRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceOrdinalContRatioRegr = define_inference_class(
	classname = "InferenceOrdinalContRatioRegr",
	inherit = Inference,
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "OrdinalContinuationRatioLikelihood"),
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio", response_types = "ordinal"),
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
			"get_complexity_tier"
		)
	),
	public = list(
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	)
)
