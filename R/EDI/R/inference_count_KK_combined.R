#' GLMM Inference for KK Designs with Count Response
#'
#' Fits a Poisson GLMM for count responses under a KK matching-on-the-fly design.
#' The random intercept per matched pair is integrated out via Gauss-Hermite quadrature.
#'
#' When \code{use_rcpp = TRUE} (default) the likelihood is maximised by an internal
#' Rcpp routine. Set \code{use_rcpp = FALSE} to fall back to \pkg{glmmTMB}.
#'
#' @details
#' \strong{Model.} \eqn{Y_{ij} \mid b_i \sim \mathrm{Poisson}(\mu_{ij})} with
#' \eqn{\log \mu_{ij} = X_{ij}'\beta + \beta_T \cdot W_{ij} + b_i}, where
#' \eqn{i} indexes matched pairs, \eqn{j \in \{1, 2\}} the two subjects within
#' a pair, \eqn{W_{ij}} is the treatment indicator, and \eqn{b_i \sim
#' \mathcal{N}(0, \sigma_b^2)} is a pair-level random intercept absorbing
#' within-pair correlation induced by matching. \eqn{\beta_T} is a log-rate
#' (log relative risk) treatment effect: \eqn{\exp(\hat\beta_T)} is the
#' estimated rate ratio. The random effect is integrated out of the marginal
#' likelihood by adaptive Gauss-Hermite quadrature rather than a Laplace
#' approximation.
#'
#' \strong{Likelihood tier.} \code{likelihood_tier = "full"}: both Wald
#' (model-based standard error) and likelihood-ratio testing types are
#' available. Because the GLMM likelihood alone does not encode the KK design's
#' matched-pair randomization structure, the likelihood-ratio CI/p-value are
#' conservatively widened/calibrated against the design-aware Wald result (see
#' \code{compute_lik_ratio_confidence_interval()}/
#' \code{compute_lik_ratio_two_sided_pval()}) so the model-based test is never
#' anti-conservative relative to the design.
#'
#' \strong{Assumptions.} Count response modeled as conditionally Poisson given
#' the random intercept (equidispersion conditional on \eqn{b_i}); pair-level
#' random effects independent across pairs; a KK matching-on-the-fly design.
#'
#' @references
#' Kapelner, A. and Krieger, A. M. (2014). Matching on-the-fly: Sequential
#' allocation with higher power and efficiency. \emph{Biometrics}, 70(2),
#' 378-388. \doi{10.1111/biom.12148}. (KK14 in \code{REFERENCES.md}.)
#'
#' @seealso Analogous Python API for Poisson/count GLMs:
#'   \href{https://www.statsmodels.org/stable/discretemod.html}{statsmodels discrete models}.
#'   \href{https://en.wikipedia.org/wiki/Generalized_linear_model}{Generalized linear model} and
#'   \href{https://en.wikipedia.org/wiki/Gauss–Hermite_quadrature}{Gauss-Hermite quadrature} (orientation).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'count')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rpois(10, 2))
#' inf = InferenceCountKKGLMM$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceCountKKGLMM = define_inference_class("InferenceCountKKGLMM",
	inherit = Inference,
	# 2026-08-19 (fix_inference_hierarchy.md "KK And IVWC Estimators", "Migrate
	# KK GEE and GLMM classes"): flipped from the hybrid `inherit =
	# InferenceParamBootstrap` state, same fix as InferenceContinKKGLMM above.
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "KKGLMM"),
	# capabilities = "likelihood_ratio" is required explicitly -- same
	# rationale as every class composing ParametricLikelihoodBootstrap
	# directly (bypassing StandardModelCache) this stretch.
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio"),
	public = list(
		# Pinned from InferenceRand -- same flattened-super$ rationale as
		# every other count KK migration this stretch.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
		# Generic-`self$`-aliased overrides for the two compute_lik_ratio_*
		# methods below, whose bodies call `super$...()` under the old R6
		# ladder (reaching InferenceAsympLik's generic dispatch, now the
		# LikelihoodTests component) -- same pattern as
		# CountKKHurdlePoissonOneLikLikelihoodSource/
		# CountKKCondPoissonOneLikLikelihoodSource earlier this stretch.
		compute_lik_ratio_confidence_interval_generic = InferenceAsympLik$public_methods$compute_lik_ratio_confidence_interval,
		compute_lik_ratio_two_sided_pval_generic = InferenceAsympLik$public_methods$compute_lik_ratio_two_sided_pval,
		#' @description Initialize a KK Poisson-GLMM inference object for a matched-pair KK
		#'   design with a count response and prepare the matched-pair random-intercept
		#'   likelihood machinery; see the class topic for the model.
		#' @param des_obj A completed KK matching-on-the-fly \code{Design} object
		#'   (\code{\link[EDI:DesignSeqOneByOneKK14]{DesignSeqOneByOneKK14}} or subclass) with a
		#'   count response.
		#' @param model_formula Optional formula for covariate adjustment. If \code{NULL}
		#'   (default), the formula from the design object is used.
		#' @param use_rcpp Logical. If \code{TRUE} (default), maximize the Gauss-Hermite-quadrature
		#'   marginal likelihood with the internal Rcpp Poisson-GLMM routine; if \code{FALSE},
		#'   fall back to \pkg{glmmTMB}.
		#' @param optimization_alg Optimization algorithm passed to the likelihood maximizer. If
		#'   \code{NULL} (default), an algorithm is dispatched via the package's optimizer policy.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart starting values for the optimizer.
		initialize = function(des_obj, model_formula = NULL, use_rcpp = TRUE, optimization_alg = NULL, verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertFormula(model_formula, null.ok = TRUE)
				assertFlag(use_rcpp)
			}
			if (use_rcpp) private$skip_glmm_pkg_check = TRUE
			self$set_optimization_alg(optimization_alg, allow_irls = TRUE)
			super$initialize(des_obj, model_formula = model_formula, verbose = verbose, smart_cold_start_default = smart_cold_start_default)
			private$init_kk_glmm_shared(des_obj)
			private$use_rcpp = use_rcpp
		},
		#' @description Point estimate of the treatment log-rate coefficient \eqn{\beta_T} from a
		#'   Poisson GLMM with a matched-pair random intercept, fit by maximizing the
		#'   Gauss-Hermite-quadrature-integrated marginal likelihood (internal Rcpp routine when
		#'   \code{use_rcpp = TRUE}, else \pkg{glmmTMB}). See the class topic for the model form.
		#' @param estimate_only If \code{TRUE}, skip variance-component calculations.
		#' @return Numeric scalar: the treatment coefficient on the log-rate (link) scale, i.e.
		#'   \eqn{\exp(\hat\beta_T)} is a rate ratio.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the KK Poisson-GLMM treatment estimate under nonparametric/
		#'   Bayesian-bootstrap subject-or-block weights, refitting the weighted GLMM
		#'   (\code{compute_weighted_glmm_bootstrap_estimate()}). Standard error, degrees of
		#'   freedom, and the cached summary table are cleared/set to \code{NA}/\code{Inf}/
		#'   \code{NULL} since only the point estimate is meaningful under resampling weights.
		#'   Falls back to the unweighted point estimate when the weights are effectively
		#'   constant.
		#' @param subject_or_block_weights Numeric vector of nonnegative bootstrap replicate
		#'   weights, one per subject or per matched block (KK match structure).
		#' @param estimate_only If \code{TRUE}, compute only the weighted point estimate (this
		#'   method never computes a weighted standard error regardless of this argument).
		#' @return Numeric scalar treatment-effect estimate (log-rate scale) under the given
		#'   weights.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			if (weights_are_effectively_constant(row_weights)) {
				beta_hat_T = as.numeric(self$compute_estimate(estimate_only = TRUE))[1L]
				if (is.finite(beta_hat_T)) {
					private$cached_values$beta_hat_T = beta_hat_T
					private$cached_values$s_beta_hat_T = NA_real_
					private$cached_values$df = Inf
					private$cached_values$summary_table = NULL
					return(private$cached_values$beta_hat_T)
				}
			}
			beta_hat_T = private$compute_weighted_glmm_bootstrap_estimate(row_weights)
			private$cached_values$beta_hat_T = as.numeric(beta_hat_T)[1L]
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = Inf
			private$cached_values$summary_table = NULL
			private$cached_values$beta_hat_T
		},
		#' @description Wald confidence interval for the treatment log-rate coefficient:
		#'   \eqn{\hat\beta_T \pm t_{1-\alpha/2,\,df}\cdot \hat{se}(\hat\beta_T)}, using the
		#'   model-based GLMM standard error. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared contract.
		#' @param alpha The confidence level in the computed confidence interval is 1 -
		#'   \code{alpha}. The default is 0.05.
		#' @return A length-2 numeric vector \code{c(lower, upper)} on the log-rate scale.
		compute_wald_confidence_interval = function(alpha = 0.05){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Two-sided Wald p-value for \eqn{H_0: \beta_T = \code{delta}} vs.
		#'   \eqn{H_1: \beta_T \neq \code{delta}}, using the model-based GLMM standard error.
		#' @param delta The null value of \eqn{\beta_T} to test against; 0 (the default) tests for
		#'   any treatment effect at all.
		#' @return Numeric scalar p-value in \eqn{[0, 1]}.
		compute_wald_two_sided_pval = function(delta = 0){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		},
		#' @description Likelihood-ratio confidence interval for the treatment log-rate
		#'   coefficient, inverting the GLMM's profile likelihood-ratio test against
		#'   \eqn{\chi^2_1}. Because the GLMM likelihood does not itself account for the KK
		#'   matched-pair design's randomization structure, this interval is conservatively
		#'   widened to be at least as wide as the design-aware Wald interval
		#'   (\code{compute_wald_confidence_interval()}) via \code{.conservative_kk_onelik_ci()} --
		#'   guarding against the model-based interval being anti-conservative relative to the
		#'   design.
		#' @param alpha The confidence level in the computed confidence interval is 1 -
		#'   \code{alpha}. The default is 0.05.
		#' @return A length-2 numeric vector \code{c(lower, upper)} on the log-rate scale.
		compute_lik_ratio_confidence_interval = function(alpha = 0.05){
			ci_model = self$compute_lik_ratio_confidence_interval_generic(alpha = alpha)
			ci_design = self$compute_wald_confidence_interval(alpha = alpha)
			.conservative_kk_onelik_ci(ci_model, ci_design, alpha = alpha)
		},
		#' @description Two-sided likelihood-ratio p-value for \eqn{H_0: \beta_T = \code{delta}},
		#'   from the GLMM's profile likelihood-ratio test referred to \eqn{\chi^2_1}. As with
		#'   \code{compute_lik_ratio_confidence_interval()}, this is conservatively calibrated
		#'   (via \code{.conservative_kk_onelik_pval()}) against the design-aware Wald p-value so
		#'   the model-based test cannot be anti-conservative relative to the KK matched-pair
		#'   design.
		#' @param delta The null value of \eqn{\beta_T} to test against; 0 (the default) tests for
		#'   any treatment effect at all.
		#' @return Numeric scalar p-value in \eqn{[0, 1]}.
		compute_lik_ratio_two_sided_pval = function(delta = 0){
			p_model = self$compute_lik_ratio_two_sided_pval_generic(delta = delta)
			p_design = self$compute_wald_two_sided_pval(delta = delta)
			.conservative_kk_onelik_pval(p_model, p_design)
		},
		#' @description Asymptotic confidence interval, dispatching to
		#'   \code{compute_wald_confidence_interval()} or \code{compute_lik_ratio_confidence_interval()}
		#'   depending on \code{self$get_testing_type()} (defaults to Wald if the testing type is
		#'   neither). See \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
		#'   testing-type dispatch contract.
		#' @param alpha The confidence level in the computed confidence interval is 1 -
		#'   \code{alpha}. The default is 0.05.
		#' @return A length-2 numeric vector \code{c(lower, upper)} on the log-rate scale.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			switch(
				self$get_testing_type(),
				wald = self$compute_wald_confidence_interval(alpha = alpha),
				lik_ratio = self$compute_lik_ratio_confidence_interval(alpha = alpha),
				self$compute_wald_confidence_interval(alpha = alpha)
			)
		},
		#' @description Asymptotic two-sided p-value, dispatching to
		#'   \code{compute_wald_two_sided_pval()} or \code{compute_lik_ratio_two_sided_pval()}
		#'   depending on \code{self$get_testing_type()} (defaults to Wald if the testing type is
		#'   neither). See \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
		#'   testing-type dispatch contract.
		#' @param delta The null value of \eqn{\beta_T} to test against; 0 (the default) tests for
		#'   any treatment effect at all.
		#' @return Numeric scalar p-value in \eqn{[0, 1]}.
		compute_asymp_two_sided_pval = function(delta = 0){
			switch(
				self$get_testing_type(),
				wald = self$compute_wald_two_sided_pval(delta = delta),
				lik_ratio = self$compute_lik_ratio_two_sided_pval(delta = delta),
				self$compute_wald_two_sided_pval(delta = delta)
			)
		}
	),
	private = list(
		use_rcpp = TRUE,
		cached_vc_params = NULL,
		glmm_response_type = function() "count",
		compute_weighted_glmm_bootstrap_estimate = function(row_weights){
			if (!isTRUE(private$use_rcpp)) {
				return(callSuper())
			}
			m_vec = private$m
			if (is.null(m_vec)) m_vec = rep(NA_integer_, private$n)
			m_vec[is.na(m_vec)] = 0L
			group_id = m_vec
			reservoir_idx = which(group_id == 0L)
			if (length(reservoir_idx) > 0L)
				group_id[reservoir_idx] = max(group_id) + seq_along(reservoir_idx)
			# drop rows with zero or non-finite weight
			ok = is.finite(row_weights) & row_weights > 0 & is.finite(as.numeric(private$y))
			if (!any(ok)) return(NA_real_)
			if (ncol(as.matrix(private$X)) > 0) {
				X_fit = private$create_design_matrix()
			} else {
				X_fit = cbind(`(Intercept)` = 1, w = private$w)
			}
			X_fit = as.matrix(X_fit)[ok, , drop = FALSE]
			y_ok = as.numeric(private$y)[ok]
			gid_ok = as.integer(group_id)[ok]
			rw_ok = as.numeric(row_weights)[ok]
			j_T = 1L
			n_params = ncol(X_fit) + 1L
			fit = tryCatch(
				fast_poisson_glmm_cpp(
					X        = X_fit,
					y        = y_ok,
					group_id = gid_ok,
					j_T      = j_T,
					row_weights = rw_ok,
					warm_start_params = private$get_fit_warm_start_for_length("params", n_params),
					smart_cold_start  = private$smart_cold_start_default,
					estimate_only     = TRUE,
					optimization_alg  = private$optimization_alg
				),
				error = function(e) NULL
			)
			if (!is.null(fit) && isTRUE(fit$converged)) {
				beta_hat_T = as.numeric(fit$b[j_T + 1L])
				if (is.finite(beta_hat_T) && abs(beta_hat_T) <= private$max_abs_reasonable_coef)
					return(beta_hat_T)
			}
			# fall back to glmmTMB weighted path
			for (predictors_df in private$glmm_predictors_df_candidates()) {
				mod = private$fit_weighted_glmm_on_data(predictors_df, row_weights = row_weights, se = FALSE)
				if (!private$.is_usable_glmm_fit(mod, se = FALSE)) next
				beta = tryCatch(glmmTMB::fixef(mod)$cond, error = function(e) NULL)
				if (!is.null(beta) && "w" %in% names(beta) && is.finite(beta["w"]))
					return(as.numeric(beta["w"]))
			}
			NA_real_
		},
		glmm_family        = function() stats::poisson(link = "log"),
		supports_likelihood_tests = function(){
			isTRUE(private$use_rcpp)
		},
		get_supported_testing_types_impl = function(){
			if (isTRUE(private$use_rcpp)) c("wald", "score", "lik_ratio", "gradient") else "wald"
		},
		shared = function(estimate_only = FALSE){
			if (private$use_rcpp) {
				private$shared_rcpp(estimate_only)
			} else {
				private$shared_glmm_tmb(estimate_only)
			}
			if (!estimate_only) .inflate_kk_onelik_standard_error_with_jackknife(private, self)
		},
		shared_rcpp = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			private$clear_nonestimable_state()
			private$cached_mod = NULL
			private$cached_values$likelihood_test_context = NULL
			m_vec = private$m
			if (is.null(m_vec)) m_vec = rep(NA_integer_, private$n)
			m_vec[is.na(m_vec)] = 0L
			group_id = m_vec
			reservoir_idx = which(group_id == 0L)
			if (length(reservoir_idx) > 0L)
				group_id[reservoir_idx] = max(group_id) + seq_along(reservoir_idx)
			if (ncol(as.matrix(private$X)) > 0){
				X_fit = private$create_design_matrix()
			} else {
				X_fit = cbind(`(Intercept)` = 1, w = private$w)
			}
			if ("treatment" %in% colnames(X_fit))
				colnames(X_fit)[colnames(X_fit) == "treatment"] = "w"
			X_fit = as.matrix(X_fit)
			j_T_r = which(colnames(X_fit) == "w")
			if (length(j_T_r) == 0L) j_T_r = 2L
			j_T = as.integer(j_T_r - 1L)
			
			n_params = ncol(X_fit) + 1L
			fit = tryCatch(
				fast_poisson_glmm_cpp(
					X        = X_fit,
					y        = as.numeric(private$y),
					group_id = as.integer(group_id),
					j_T      = j_T,
					warm_start_params = private$get_fit_warm_start_for_length("params", n_params),
					warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
					smart_cold_start = private$smart_cold_start_default,
					estimate_only    = estimate_only,
					optimization_alg = private$optimization_alg
				),
				error = function(e) NULL
			)

			if (is.null(fit) || !isTRUE(fit$converged)) {
				# Rcpp failed; fall back to glmmTMB
				return(private$shared_glmm_tmb(estimate_only = estimate_only))
			}
			beta_hat_T = as.numeric(fit$b[j_T_r])
			if (!is.finite(beta_hat_T) || abs(beta_hat_T) > private$max_abs_reasonable_coef) {
				return(private$shared_glmm_tmb(estimate_only = estimate_only))
			}
			private$cached_mod = fit
			private$cached_vc_params = as.numeric(fit$log_sigma)
			private$set_fit_warm_start(as.numeric(c(fit$b, fit$log_sigma)), "params", fisher = fit$fisher_information)
			private$cached_values$likelihood_test_context = list(
				X = X_fit,
				y = as.numeric(private$y),
				group_id = as.integer(group_id),
				j_treat = as.integer(j_T_r),
				start = as.numeric(c(fit$b, fit$log_sigma))
			)
			private$cached_values$beta_hat_T = beta_hat_T
			private$cached_values$df   = Inf
			if (estimate_only) return(invisible(NULL))
			ssq = fit$ssq_b_T
			private$cached_values$s_beta_hat_T = if (!is.null(ssq) && is.finite(ssq) && ssq > 0) sqrt(ssq) else NA_real_
		},
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			if (!isTRUE(private$use_rcpp) || is.null(private$cached_vc_params)) {
				return(self$compute_estimate(estimate_only = estimate_only))
			}
			m_vec = private$m
			if (is.null(m_vec)) m_vec = rep(NA_integer_, private$n)
			m_vec[is.na(m_vec)] = 0L
			group_id = m_vec
			reservoir_idx = which(group_id == 0L)
			if (length(reservoir_idx) > 0L)
				group_id[reservoir_idx] = max(group_id) + seq_along(reservoir_idx)
			if (ncol(as.matrix(private$X)) > 0) {
				X_fit = private$create_design_matrix()
			} else {
				X_fit = cbind(`(Intercept)` = 1, w = private$w)
			}
			if ("treatment" %in% colnames(X_fit))
				colnames(X_fit)[colnames(X_fit) == "treatment"] = "w"
			X_fit = as.matrix(X_fit)
			j_T_r = which(colnames(X_fit) == "w")
			if (length(j_T_r) == 0L) j_T_r = 2L
			j_T = as.integer(j_T_r - 1L)
			p_ncol = ncol(X_fit)
			fit = tryCatch(
				fast_poisson_glmm_cpp(
					X        = X_fit,
					y        = as.numeric(private$y),
					group_id = as.integer(group_id),
					j_T      = j_T,
					warm_start_params = private$get_fit_warm_start_for_length("params", p_ncol + 1L),
					smart_cold_start  = private$smart_cold_start_default,
					estimate_only     = TRUE,
					optimization_alg  = private$optimization_alg,
					fixed_idx         = as.integer(p_ncol + 1L),
					fixed_values      = private$cached_vc_params[1L]
				),
				error = function(e) NULL
			)
			if (!is.null(fit) && isTRUE(fit$converged)) {
				beta_hat_T = as.numeric(fit$b[j_T_r])
				if (is.finite(beta_hat_T) && abs(beta_hat_T) <= private$max_abs_reasonable_coef)
					return(beta_hat_T)
			}
			self$compute_estimate(estimate_only = estimate_only)
		},
		get_likelihood_test_spec = function(){
			if (!isTRUE(private$use_rcpp)) return(NULL)
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			X_fit = ctx$X
			y = as.numeric(ctx$y)
			group_id = as.integer(ctx$group_id)
			j_treat = as.integer(ctx$j_treat)
			list(
				X = X_fit,
				y = y,
				group_id = group_id,
				j = j_treat,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					fast_poisson_glmm_cpp(
						X = X_fit,
						y = y,
						group_id = group_id,
						warm_start_params = start %||% private$get_fit_warm_start_for_length("params", length(ctx$start)) %||% ctx$start,
						warm_start_fisher_info = private$get_fit_warm_start_fisher(length(ctx$start)),
						smart_cold_start = private$smart_cold_start_default,
						j_T = j_treat - 1L,
						estimate_only = FALSE,
						n_gh = 20L,
						maxit = 300L,
						eps_g = 1e-6,
						fixed_idx = j_treat,
						fixed_values = delta,
						optimization_alg = private$optimization_alg
					)
				},
				extract_start = function(fit){
					as.numeric(c(fit$b, fit$log_sigma))
				},
				score = function(fit){
					params = as.numeric(c(fit$b, fit$log_sigma))
					as.numeric(get_poisson_glmm_score_cpp(X_fit, y, group_id, params))
				},
				observed_information = function(fit){
					params = as.numeric(c(fit$b, fit$log_sigma))
					as.matrix(get_poisson_glmm_hessian_cpp(X_fit, y, group_id, params))
				},
				fisher_information = function(fit){
					params = as.numeric(c(fit$b, fit$log_sigma))
					as.matrix(get_poisson_glmm_hessian_cpp(X_fit, y, group_id, params))
				},
				information = function(fit){
					params = as.numeric(c(fit$b, fit$log_sigma))
					as.matrix(get_poisson_glmm_hessian_cpp(X_fit, y, group_id, params))
				},
				neg_loglik = function(fit){
					as.numeric(fit$neg_loglik %||% fit$neg_ll)
				}
			)
		},
		supports_lik_ratio_param_bootstrap = function() isTRUE(private$use_rcpp),
		simulate_under_lik_null = function(spec, delta, null_fit){
			b_null = as.numeric(null_fit$b)
			sigma_u = exp(as.numeric(null_fit$log_sigma))
			X = spec$X
			group_id = spec$group_id
			n = nrow(X)
			K = max(group_id)
			u = rnorm(K, 0, sigma_u)
			eta = as.numeric(X %*% b_null) + u[group_id]
			y_sim = as.integer(rpois(n, exp(pmin(eta, 20))))
			j = spec$j
			full_res = tryCatch(
				fast_poisson_glmm_cpp(
					X = X, y = as.numeric(y_sim), group_id = group_id,
					j_T = j - 1L,
					smart_cold_start = private$smart_cold_start_default,
					optimization_alg = private$optimization_alg
				),
				error = function(e) NULL
			)
			if (is.null(full_res) || !isTRUE(full_res$converged) || !is.finite(full_res$b[j])) return(NULL)
			list(
				full_fit = full_res,
				fit_null = function(d, start = NULL){
					tryCatch(
						fast_poisson_glmm_cpp(
							X = X, y = as.numeric(y_sim), group_id = group_id,
							j_T = j - 1L,
							warm_start_params = start %||% as.numeric(c(full_res$b, full_res$log_sigma)),
							estimate_only = FALSE,
							fixed_idx = j, fixed_values = d,
							smart_cold_start = private$smart_cold_start_default,
							optimization_alg = private$optimization_alg
						),
						error = function(e) NULL
					)
				},
				neg_loglik = function(fit){ as.numeric(fit$neg_loglik %||% fit$neg_ll) }
			)
		}
	),
	overrides = list(
		public = c(
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_rand_two_sided_pval",
			"get_supported_testing_types", "set_testing_type",
			"compute_wald_two_sided_pval",
			"compute_wald_confidence_interval",
			"compute_lik_ratio_two_sided_pval",
			"compute_lik_ratio_confidence_interval"
		),
		private = c(
			"compute_weighted_glmm_bootstrap_estimate",
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl",
			"compute_treatment_estimate_during_randomization_inference",
			"get_standard_error",
			"get_degrees_of_freedom",
			"assert_finite_se",
			"supports_likelihood_tests",
			"supports_lik_ratio_param_bootstrap",
			"supports_information_preference",
			"supports_observed_information",
			"get_supported_information_preferences_impl",
			"supports_bartlett_likelihood_ratio_approx",
			"get_bartlett_factor_approx",
			"get_likelihood_test_spec",
			"simulate_under_lik_null",
			"shared",
			"get_complexity_tier"
		)
	)
)
