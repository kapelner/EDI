# Static leaf source (2026-08-17 migration, same shape as
# SurvivalKKWeibullMarginalSource / CountKKHurdlePoissonIVWCSource): the KK
# compound layer arrives through the registered KKCompound component (this
# component's declared dependency); this source holds only the class's own
# estimator overrides.
SurvivalGLMMWeibullFrailtyLoggammaIVWCSource = list(
	public = list(
		#' @description Initialize KK Clayton-copula survival inference and prepare
		#'   the matched/reservoir likelihood components used by
		#'   \code{\link[EDI:InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC]{InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC}}.
		#' @param des_obj  	A DesignSeqOneByOne object (must be a KK design).
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose  		Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "survival")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			private$init_kk_passthrough(des_obj)
		},
		#' @description Returns the model-specific log-time-ratio treatment estimate; see
		#'   \code{\link[EDI:Inference]{Inference}}.
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the IVWC Clayton-copula treatment estimate under
		#'   Bayesian-bootstrap weights.
		#' @param subject_or_block_weights Subject-, block-, cluster-, or matched-set
		#'   bootstrap weights.
		#' @param estimate_only If \code{TRUE}, compute only the weighted point
		#'   estimate.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			if (weights_are_effectively_constant(row_weights)) {
				beta_hat_T = as.numeric(self$compute_estimate(estimate_only = TRUE))[1L]
				if (is.finite(beta_hat_T)) {
					private$cached_values$beta_hat_T = beta_hat_T
					private$cached_values$s_beta_hat_T = NA_real_
					return(private$cached_values$beta_hat_T)
				}
			}
			X_cov = private$get_X()
			X_fit = if (ncol(as.matrix(X_cov)) > 0) cbind(treatment = private$w, X_cov) else matrix(private$w, ncol = 1, dimnames = list(NULL, "treatment"))
			fit = weighted_weibull_bootstrap_surrogate_fit(private$y, private$dead, X_fit, row_weights)
			private$cached_values$beta_hat_T = if (is.null(fit)) NA_real_ else as.numeric(fit$beta_hat)
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$beta_hat_T
		},
		#' @description Uses the shared asymptotic confidence-interval contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param alpha                                   The confidence level in the computed
		#'   confidence interval is 1 - \code{alpha}. The default is 0.05.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
			}
			private$shared()
			if (should_run_asserts()) {
				private$assert_finite_se()
			}
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Compute the Clayton-copula survival asymptotic p-value for
		#'   the treatment effect using the fitted frailty/dependence model. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for shared p-value
		#'   semantics.
		#' @param delta                                   The null difference to test against. Default is 0.
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta)
			}
			private$shared()
			if (should_run_asserts()) {
				private$assert_finite_se()
			}
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		}
		# The old evaluated-body override of the mixin's
		# approximate_bootstrap_distribution_beta_hat_T and the pure-passthrough
		# duplicate() override are deliberately GONE -- the KK component chain
		# supplies the real functions directly (Static Cleanup).
	),
	private = list(
		best_par = NULL,
		best_X_colnames = NULL,
		cached_mod = NULL,
		best_X_colnames_matched = NULL,
		best_X_colnames_reservoir = NULL,
		cached_vc_params_matched = NULL,
		cached_vc_params_reservoir = NULL,
		compute_basic_match_data = function() private$compute_basic_kk_match_data_impl(),
		max_abs_reasonable_coef = 1e4,
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			# Re-read w, y, dead because they might have been transformed for
			# randomization. `dead` is NOT read from `private$des_obj_priv_int$dead`
			# here: post y/y_L/y_R migration, Design no longer stores a raw `dead`
			# field, so that read is always NULL and clobbers the correctly-set
			# `private$dead` -- see fix_inference_hierarchy.md Follow-Ups (found
			# 2026-08-19, same root cause as the InferenceSurvivalKKLWACoxPHOneLik
			# segfault fixed the same day). Re-derive `dead` the same way
			# Design$get_effective_dead() does instead.
			private$w = private$des_obj_priv_int$w
			private$y = private$des_obj_priv_int$y
			private$dead = as.numeric(!is.na(private$y))
			private$compute_basic_match_data()
			if (is.null(private$best_X_colnames_matched) && is.null(private$best_X_colnames_reservoir)){
				private$shared()
			}
			if (is.null(private$best_X_colnames_matched) && is.null(private$best_X_colnames_reservoir)){
				return(NA_real_)
			}
			KKstats = private$cached_values$KKstats
			if (is.null(KKstats)) return(NA_real_)
			m = KKstats$m
			nRT = KKstats$nRT
			nRC = KKstats$nRC
			X_data = private$get_X()
			split = split_kk_matched_reservoir_idx(private$m, private$n)
			m_vec = split$m_vec
			# Matched component
			beta_m = NA_real_
			if (m > 0 && !is.null(private$best_X_colnames_matched)) {
				i_matched = split$matched_idx
				cov_cols_m = setdiff(private$best_X_colnames_matched, "w")
				X_cand_m = cbind(w = private$w[i_matched], X_data[i_matched, intersect(cov_cols_m, colnames(X_data)), drop = FALSE])
				if (!is.null(private$cached_vc_params_matched) && all(is.finite(private$cached_vc_params_matched))) {
					X_m_int = cbind("(Intercept)" = 1, X_cand_m)
					p_m = ncol(X_m_int)
					pair_idx_m_r = .complete_pair_index_matrix(m_vec[i_matched])
					pair_idx_m_0 = if (nrow(pair_idx_m_r) > 0L) pair_idx_m_r - 1L else matrix(0L, 0L, 2L)
					warm_m = private$get_fit_warm_start_for_length("params", p_m + 2L)
					if (is.null(warm_m) || length(warm_m) != p_m + 2L)
						warm_m = c(rep(0, p_m), private$cached_vc_params_matched)
					fit_fast_m = tryCatch(
						fast_clayton_weibull_aft_optim_cpp(
							X = as.matrix(X_m_int),
							y = as.numeric(private$y[i_matched]),
							dead = as.numeric(private$dead[i_matched]),
							pair_idx = pair_idx_m_0,
							singleton_rows = integer(0),
							warm_start_params = warm_m,
							estimate_only = TRUE,
							optimization_alg = private$optimization_alg,
							fixed_idx = as.integer(c(p_m + 1L, p_m + 2L)),
							fixed_values = as.numeric(private$cached_vc_params_matched)
						), error = function(e) NULL
					)
					if (!is.null(fit_fast_m) && isTRUE(fit_fast_m$converged) && length(fit_fast_m$params) >= 2L)
						beta_m = as.numeric(fit_fast_m$params[2L])
				}
				if (!is.finite(beta_m)) {
					fit_m = .fit_clayton_weibull_aft(
						y = private$y[i_matched], dead = private$dead[i_matched],
						X = X_cand_m, pair_id = m_vec[i_matched], estimate_only = TRUE,
						optimization_alg = private$optimization_alg
					)
					if (!is.null(fit_m) && is.finite(fit_m$beta)) beta_m = fit_m$beta
				}
			}
			# Reservoir component
			beta_r = NA_real_
			if (nRT > 0 && nRC > 0 && !is.null(private$best_X_colnames_reservoir)) {
				i_reservoir = split$reservoir_idx
				y_r = private$y[i_reservoir]
				w_r = private$w[i_reservoir]
				dead_r = private$dead[i_reservoir]
				cov_cols_r = setdiff(private$best_X_colnames_reservoir, "w")
				X_cov_r = X_data[i_reservoir, intersect(cov_cols_r, colnames(X_data)), drop = FALSE]
				X_r = cbind(w = w_r, X_cov_r)
				if (!is.null(private$cached_vc_params_reservoir) && is.finite(private$cached_vc_params_reservoir[1L])) {
					X_r_int = cbind("(Intercept)" = 1, as.matrix(X_r))
					p_r = ncol(X_r_int)
					fit_fast_r = tryCatch(
						fast_weibull_regression_cpp(
							y = y_r, dead = dead_r, X = X_r_int,
							estimate_only = TRUE,
							fixed_idx = as.integer(p_r),
							fixed_values = as.numeric(private$cached_vc_params_reservoir[1L])
						), error = function(e) NULL
					)
					if (!is.null(fit_fast_r) && isTRUE(fit_fast_r$converged) && length(fit_fast_r$b) >= 2L)
						beta_r = as.numeric(fit_fast_r$b[2L])
				}
				if (!is.finite(beta_r)) {
					fit_r = .fit_standard_weibull_aft_from_matrix(
						y = y_r, dead = dead_r, X = X_r, estimate_only = TRUE
					)
					if (!is.null(fit_r) && is.finite(fit_r$beta)) beta_r = fit_r$beta
				}
			}
			# Pooling
			m_ok = is.finite(beta_m)
			r_ok = is.finite(beta_r)
			if (m_ok && r_ok) {
				ssq_m_orig = private$cached_values$ssq_beta_T_matched
				ssq_r_orig = private$cached_values$ssq_beta_T_reservoir
				if (!is.null(ssq_m_orig) && !is.null(ssq_r_orig) && is.finite(ssq_m_orig) && is.finite(ssq_r_orig)) {
					w_star = ssq_r_orig / (ssq_r_orig + ssq_m_orig)
					return(w_star * beta_m + (1 - w_star) * beta_r)
				}
				return(0.5 * beta_m + 0.5 * beta_r)
			} else if (m_ok) {
				return(beta_m)
			} else if (r_ok) {
				return(beta_r)
			}
			NA_real_
		},
		assert_finite_se = function(){
			if (!is.finite(private$cached_values$s_beta_hat_T)){
				return(invisible(NULL))
			}
		},
		filtered_covariate_candidates = function(X = as.matrix(private$X)){
			if (ncol(X) == 0L) return(list(matrix(nrow = nrow(X), ncol = 0L)))
			
			# Ensure no linearly dependent columns first
			res = drop_linearly_dependent_cols(X)
			X_reduced = res$M
			if (ncol(X_reduced) == 0L) return(list(matrix(nrow = nrow(X), ncol = 0L)))
			
			# Generate candidates by dropping highly correlated columns at various thresholds
			thresholds = c(0.99, 0.9, 0.7)
			candidates = list(X_reduced)
			for (thresh in thresholds) {
				X_try = drop_highly_correlated_cols(X_reduced, threshold = thresh)$M
				# Simple way to avoid duplicates in the list
				is_new = TRUE
				for (c in candidates) {
					if (ncol(c) == ncol(X_try) && all(colnames(c) == colnames(X_try))) {
						is_new = FALSE
						break
					}
				}
				if (is_new) candidates[[length(candidates) + 1L]] = X_try
			}
			candidates
		},
		design_matrix_candidates = function(){
			if (!is.null(private$cached_values$clayton_design_candidates)){
				return(private$cached_values$clayton_design_candidates)
			}
			candidates = list()
			# Case 1: no covariates
			if (ncol(as.matrix(private$X)) == 0L){
				Xcand = matrix(private$w, ncol = 1)
				colnames(Xcand) = "w"
				candidates = list(Xcand)
			} else {
				cov_candidates = private$filtered_covariate_candidates()
				for (X in cov_candidates){
					M = matrix(private$w, ncol = 1)
					colnames(M) = "w"
					if (ncol(X) > 0){
						M = cbind(M, X)
					}
					# Ensure we drop any additional linear dependencies
					qr_res = qr(M)
					if (qr_res$rank < ncol(M)){
						keep = qr_res$pivot[seq_len(qr_res$rank)]
						if (!(1L %in% keep)) keep = c(1L, keep) # Keep treatment
						keep = sort(unique(keep))
						M = M[, keep, drop = FALSE]
					}
					candidates[[length(candidates) + 1L]] = M
				}
			}
			private$cached_values$clayton_design_candidates = candidates
			candidates
		},
		shared = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			if (!is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (is.null(private$cached_values$KKstats)){
				private$compute_basic_match_data()
			}
			KKstats = private$cached_values$KKstats
			m   = KKstats$m
			nRT = KKstats$nRT
			nRC = KKstats$nRC
			if (m > 0){
				private$clayton_copula_for_matched_pairs(estimate_only = estimate_only)
			}
			beta_m = private$cached_values$beta_T_matched
			ssq_m = private$cached_values$ssq_beta_T_matched
			m_ok = !is.null(beta_m) && is.finite(beta_m) && 
			       (!estimate_only && !is.null(ssq_m) && is.finite(ssq_m) && ssq_m > 0 || estimate_only)
			if (nRT > 0 && nRC > 0){
				private$weibull_for_reservoir(estimate_only = estimate_only)
			}
			beta_r = private$cached_values$beta_T_reservoir
			ssq_r = private$cached_values$ssq_beta_T_reservoir
			r_ok = !is.null(beta_r) && is.finite(beta_r) &&
			       (!estimate_only && !is.null(ssq_r) && is.finite(ssq_r) && ssq_r > 0 || estimate_only)
			if (m_ok && r_ok){
				w_star = ssq_r / (ssq_r + ssq_m)
				private$cached_values$beta_hat_T = w_star * beta_m + (1 - w_star) * beta_r
			if (estimate_only) return(invisible(NULL))
				private$cached_values$s_beta_hat_T = sqrt(ssq_m * ssq_r / (ssq_m + ssq_r))
			} else if (m_ok){
				private$cached_values$beta_hat_T = beta_m
				private$cached_values$s_beta_hat_T = if (estimate_only) NA_real_ else sqrt(ssq_m)
			} else if (r_ok){
				private$cached_values$beta_hat_T = beta_r
				private$cached_values$s_beta_hat_T = if (estimate_only) NA_real_ else sqrt(ssq_r)
			} else {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
			}
		},
		clayton_copula_for_matched_pairs = function(estimate_only = FALSE){
			split = split_kk_matched_reservoir_idx(private$m, private$n)
			m_vec = split$m_vec
			i_matched = split$matched_idx
			if (length(i_matched) == 0L) return(invisible(NULL))
			X_data = private$get_X()
			X_matched = X_data[i_matched, , drop = FALSE]
			X_fit = cbind(w = private$w[i_matched], X_matched)
			n_params = ncol(X_fit) + 2L
			# Fit using optimized helper
			fit = .fit_clayton_weibull_aft(
				y = private$y[i_matched],
				dead = private$dead[i_matched],
				X = X_fit,
				pair_id = m_vec[i_matched],
				estimate_only = estimate_only,
				optimization_alg = private$optimization_alg,
				starts = if (!is.null(private$get_fit_warm_start_for_length("params", n_params))) 
				             list(private$get_fit_warm_start_for_length("params", n_params)) else NULL,
				warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params)
			)
			
			if (!is.null(fit) && is.finite(fit$beta)){
				private$cached_values$beta_T_matched = fit$beta
				private$cached_values$ssq_beta_T_matched = if (estimate_only) NA_real_ else fit$ssq
				private$best_X_colnames_matched = colnames(X_fit)
				if (!is.null(fit$best_par) && length(fit$best_par) >= 3L)
					private$cached_vc_params_matched = as.numeric(tail(fit$best_par, 2L))
			}
		},
		weibull_for_reservoir = function(estimate_only = FALSE){
			KKstats = private$cached_values$KKstats
			y_r    = KKstats$y_reservoir
			w_r    = KKstats$w_reservoir
			m_vec_safe = private$m
			if (is.null(m_vec_safe)) m_vec_safe = rep(0L, private$n)
			m_vec_safe[is.na(m_vec_safe)] = 0L
			dead_r = private$dead[m_vec_safe == 0]
			X_r    = as.matrix(KKstats$X_reservoir)
			# Candidate reduced design matrices for the reservoir
			candidates = list()
			if (ncol(X_r) == 0L){
				Xcand = matrix(w_r, ncol = 1)
				colnames(Xcand) = "w"
				candidates = list(Xcand)
			} else {
				cov_candidates = private$filtered_covariate_candidates(X_r)
				for (X in cov_candidates){
					M = matrix(w_r, ncol = 1)
					colnames(M) = "w"
					if (ncol(X) > 0){
						M = cbind(M, X)
					}
					qr_res = qr(M)
					if (qr_res$rank < ncol(M)){
						keep = qr_res$pivot[seq_len(qr_res$rank)]
						if (!(1L %in% keep)) keep = c(1L, keep)
						keep = sort(unique(keep))
						M = M[, keep, drop = FALSE]
					}
					candidates[[length(candidates) + 1L]] = M
				}
			}
			for (Xcand in candidates){
				n_params = ncol(Xcand) + 1L
				fit = .fit_standard_weibull_aft_from_matrix(
					y = y_r,
					dead = dead_r,
					X = Xcand,
					estimate_only = estimate_only,
					starts = if (!is.null(private$get_fit_warm_start_for_length("params", n_params)))
					             list(private$get_fit_warm_start_for_length("params", n_params)) else NULL,
					warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params)
				)
				if (!is.null(fit) && is.finite(fit$beta) && (estimate_only || (is.finite(fit$ssq) && fit$ssq > 0))){
					private$cached_values$beta_T_reservoir = fit$beta
					private$cached_values$ssq_beta_T_reservoir = fit$ssq
					private$best_X_colnames_reservoir = colnames(Xcand)
					X_r_int = cbind("(Intercept)" = 1, as.matrix(Xcand))
					res_log_s = tryCatch(
							fast_weibull_regression_cpp(
								y = y_r, dead = dead_r,
							X    = X_r_int,
							estimate_only = TRUE
						),
						error = function(e) NULL
					)
					if (!is.null(res_log_s) && isTRUE(res_log_s$converged))
						private$cached_vc_params_reservoir = as.numeric(res_log_s$log_sigma)
					return(invisible(NULL))
				}
			}
		}
		)
	)

#' Clayton Copula / Standard Weibull Compound Inference for KK Designs
#'
#' This class implements a compound estimator for KK matching-on-the-fly designs with
#' survival responses using a Clayton copula with Weibull AFT margins for matched
#' pairs and a standard Weibull AFT model for the reservoir. The two treatment-effect
#' estimates (on the log-time ratio scale) are combined by inverse-variance weighting.
#'
#' @details
#' \strong{Frailty distribution.} The Clayton copula for a matched pair,
#' \code{S(t1,t2) = (S1(t1)^-theta + S2(t2)^-theta - 1)^(-1/theta)} with Weibull
#' margins \code{S_i}, is exactly the closed-form bivariate survival function
#' obtained by multiplying two conditionally-independent Weibull hazards by a
#' shared \strong{gamma} frailty term \code{Z ~ Gamma(1/theta, 1/theta)} and
#' integrating \code{Z} out analytically (Clayton 1978; Oakes 1989); \code{theta}
#' is the frailty variance / dependence parameter (see \code{ClaytonWeibullLikelihood}
#' in \code{fast_survival_models_optim.cpp}, which builds the likelihood from the
#' per-subject Weibull cumulative hazards \code{H1, H2}). This is the classic
#' textbook Weibull-gamma shared-frailty model, fit here in its closed form (no
#' numerical integration required) rather than as an AFT Gaussian-random-intercept
#' model.
#'
#' This is a different (and equally standard) frailty assumption from the
#' \strong{log-normal}-frailty Weibull AFT GLMM implemented by
#' \code{\link[EDI:InferenceSurvivalGLMMWeibullFrailtyNormalIVWC]{InferenceSurvivalGLMMWeibullFrailtyNormalIVWC}} /
#' \code{\link[EDI:InferenceSurvivalGLMMWeibullFrailtyNormalOneLik]{InferenceSurvivalGLMMWeibullFrailtyNormalOneLik}},
#' which instead places a Gaussian random intercept on the log-time (AFT) scale and
#' integrates it out by Gauss-Hermite quadrature. Prefer this Clayton-copula class
#' for the classic gamma-frailty / proportional-hazards dependence structure;
#' prefer the Weibull-frailty class for a Gaussian-random-intercept / GLMM-style
#' dependence structure.
#'
#' @references
#' Clayton DG (1978). "A Model for Association in Bivariate Life Tables and
#' Its Application in Epidemiological Studies of Familial Tendency in Chronic
#' Disease Incidence." Biometrika, 65(1), 141-151. \doi{10.2307/2335289}
#'
#' Oakes D (1989). "Bivariate Survival Models Induced by Frailties." Journal
#' of the American Statistical Association, 84(406), 487-493.
#' \doi{10.2307/2289934}
#'
#' \strong{Legacy class.} Not fully tested in \code{comprehensive_tests.R}.
#' @seealso \code{\link[EDI:InferenceSurvivalGLMMWeibullFrailtyNormalIVWC]{InferenceSurvivalGLMMWeibullFrailtyNormalIVWC}}
#'   for the corresponding log-normal-frailty IVWC estimator.
#' @export
InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC = define_inference_class(
	classname = "InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald", "SurvivalGLMMWeibullFrailtyLoggammaIVWC"),
	public = list(
		# Pinned from InferenceRand -- same flattened-super$ rationale as the
		# other survival KK migrations (RandCI's Zhang dispatch never applies).
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	),
	metadata = list(likelihood_tier = "full"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"initialize",
			"compute_estimate",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_estimate_with_bootstrap_weights",
			"approximate_bootstrap_distribution_beta_hat_T"
		),
		private = c(
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl",
			"compute_treatment_estimate_during_randomization_inference",
			"compute_basic_match_data",
			"shared",
			"assert_finite_se",
			"supports_likelihood_tests",
			"max_abs_reasonable_coef",
			"optimization_alg",
			"best_par",
			"best_X_colnames",
			"cached_mod"
		)
	)
)

#' Clayton Copula Combined-Likelihood Inference for KK Designs
#'
#' Gamma-frailty (Clayton copula) Weibull estimator; see
#' \code{\link[EDI:InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC]{InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC}}
#' for the frailty-distribution details and contrast with the log-normal-frailty
#' \code{\link[EDI:InferenceSurvivalGLMMWeibullFrailtyNormalOneLik]{InferenceSurvivalGLMMWeibullFrailtyNormalOneLik}}
#' alternative.
#'
#' @keywords internal
# Leaf-only component source (2026-08-23, fix_inference_hierarchy.md "Static
# Cleanup" / "Ban raw component splicing"). Until 2026-08-23 this was an
# internal `...LegacyRaw` R6 generator built by a raw
# `modifyList(InferenceMixinKKPassThrough$public/private, list(...))` splice
# and self-harvested via `inference_component_source_parts()`, which forced
# the registered `SurvivalGLMMWeibullFrailtyLoggammaOneLik` component to carry the whole
# flattened KK pass-through surface (and to redeclare root-owned state). It
# is now the same plain public/private list every other OneLik component
# uses; the KK pass-through behavior arrives through the component's
# `dependencies = "KKPassThrough"`, and the historical `optimization_alg =
# "lbfgs"` default is established by `init_kk_passthrough()` through the
# root setter. The migration golden test rebuilds the legacy generator from
# this source plus the mixin, exactly as the hurdle/cond-logit OneLik goldens
# do.
SurvivalGLMMWeibullFrailtyLoggammaOneLikSource = list(
	public = list(
		#' @description Initialize KK Clayton-copula one-likelihood survival
		#'   inference and prepare the combined likelihood used by
		#'   \code{\link[EDI:InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik]{InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik}}.
		#' @param des_obj  	A DesignSeqOneByOne object (must be a KK design).
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose  		Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "survival")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			private$init_kk_passthrough(des_obj)
		},
		#' @description Returns the model-specific log-time-ratio treatment estimate; see
		#'   \code{\link[EDI:Inference]{Inference}}.
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Uses the shared asymptotic confidence-interval contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param alpha                                   The confidence level in the computed
		#'   confidence interval is 1 - \code{alpha}. The default is 0.05.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
			}
			private$shared()
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Compute the one-likelihood Clayton-copula survival
		#'   asymptotic p-value for the treatment effect using the fitted dependence
		#'   model. See \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param delta                                   The null difference to test against. Default is 0.
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta)
			}
			private$shared()
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		},
		# 2026-08-19 (fix_inference_hierarchy.md "Static Cleanup", "Ban
		# eval(body(Inference...))"): removed the redundant
		# `approximate_bootstrap_distribution_beta_hat_T = function(...) {
		# eval(body(InferenceMixinKKPassThrough$public$approximate_bootstrap_
		# distribution_beta_hat_T)) }` restatement -- verified no-op, same as
		# every other KK leaf this stretch: this class already splices
		# `InferenceMixinKKPassThrough$public` via
		# `as.list(modifyList(as.list(InferenceMixinKKPassThrough$public), list(...)))`
		# below, so the raw source's own
		# `approximate_bootstrap_distribution_beta_hat_T` (same body, same
		# R6-construction-time environment rebinding) is already present
		# without this explicit re-evaluated copy.
		#' @description Duplicates this subclass while preserving fit caches; see
		#'   \code{\link[EDI:Inference]{Inference}}.
		#' @param verbose Whether the duplicate should be verbose.
		#' @param make_fork_cluster Whether the duplicate should be allowed to create a fork cluster.
		duplicate = function(verbose = FALSE, make_fork_cluster = FALSE){
			inf_obj = super$duplicate(verbose = verbose, make_fork_cluster = make_fork_cluster)
			inf_obj
		}
	),
	private = list(
		max_abs_reasonable_coef = 1e4,
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			# Re-read w, y, dead because they might have been transformed for
			# randomization. `dead` is NOT read from `private$des_obj_priv_int$dead`
			# here: post y/y_L/y_R migration, Design no longer stores a raw `dead`
			# field, so that read is always NULL and clobbers the correctly-set
			# `private$dead` -- see fix_inference_hierarchy.md Follow-Ups (found
			# 2026-08-19, same root cause as the InferenceSurvivalKKLWACoxPHOneLik
			# segfault fixed the same day). Re-derive `dead` the same way
			# Design$get_effective_dead() does instead.
			private$w = private$des_obj_priv_int$w
			private$y = private$des_obj_priv_int$y
			private$dead = as.numeric(!is.na(private$y))
			private$compute_basic_match_data()
			# Fixed-VC fast path: private$best_par and private$best_X_colnames survive duplicate()
			if (!is.null(private$best_par) && length(private$best_par) >= 3L &&
			    !is.null(private$best_X_colnames) && all(is.finite(tail(private$best_par, 2L)))) {
				m_vec = private$m
				if (is.null(m_vec)) m_vec = rep(NA_integer_, private$n)
				m_vec[is.na(m_vec)] = 0L
				X_data = private$get_X()
				cov_cols = setdiff(private$best_X_colnames, "w")
				X_cand = matrix(private$w, ncol = 1L, dimnames = list(NULL, "w"))
				if (length(cov_cols) > 0L)
					X_cand = cbind(X_cand, X_data[, intersect(cov_cols, colnames(X_data)), drop = FALSE])
				X_full = cbind("(Intercept)" = 1, X_cand)
				p_full = ncol(X_full)
				vc_vals = as.numeric(tail(private$best_par, 2L))
				pair_idx_r = .complete_pair_index_matrix(m_vec)
				singleton_rows_r = setdiff(seq_len(private$n), sort(unique(as.vector(pair_idx_r)))) - 1L
				pair_idx_0 = if (nrow(pair_idx_r) > 0L) pair_idx_r - 1L else matrix(0L, 0L, 2L)
				warm = private$get_fit_warm_start_for_length("params", p_full + 2L)
				if (is.null(warm) || length(warm) != p_full + 2L)
					warm = c(rep(0, p_full), vc_vals)
				fit_fast = tryCatch(
					fast_clayton_weibull_aft_optim_cpp(
						X               = as.matrix(X_full),
						y               = as.numeric(private$y),
						dead            = as.numeric(private$dead),
						pair_idx        = pair_idx_0,
						singleton_rows  = as.integer(singleton_rows_r),
						warm_start_params = warm,
						estimate_only   = TRUE,
						optimization_alg = private$optimization_alg,
						fixed_idx       = as.integer(c(p_full + 1L, p_full + 2L)),
						fixed_values    = vc_vals
					),
					error = function(e) NULL
				)
				if (!is.null(fit_fast) && isTRUE(fit_fast$converged)) {
					b_w = as.numeric(fit_fast$params[2L])
					if (is.finite(b_w) && abs(b_w) <= private$max_abs_reasonable_coef)
						return(b_w)
				}
			}
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		get_standard_error = function(){
			private$shared()
			as.numeric(private$cached_values$s_beta_hat_T)
		},
		get_degrees_of_freedom = function() Inf,
		assert_finite_se = function(){
			if (!is.finite(private$cached_values$s_beta_hat_T)){
				return(invisible(NULL))
			}
		},
		supports_likelihood_tests = function(){
			TRUE
		},
		get_likelihood_test_spec = function(){
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			X = ctx$X
			y = as.numeric(ctx$y)
			dead = as.numeric(ctx$dead)
			pair_idx = ctx$pair_idx
			singleton_rows = ctx$singleton_rows
			j_treat = as.integer(ctx$j_treat %||% 1L)
			start_len = length(ctx$start %||% numeric(0))
			list(
				X = X,
				y = y,
				dead = dead,
				pair_idx = pair_idx,
				singleton_rows = singleton_rows,
				j = j_treat,
				full_fit = private$cached_mod$best_fit %||% private$cached_mod,
				fit_null = function(delta, start = NULL){
					warm_start_params = start %||% private$get_fit_warm_start_for_length("params", start_len)
					if (length(warm_start_params) == 0L) warm_start_params = ctx$start
					warm_fisher = private$get_fit_warm_start_fisher(start_len)
					fast_clayton_weibull_aft_optim_cpp(
						X = X,
						y = y,
						dead = dead,
						pair_idx = pair_idx,
						singleton_rows = singleton_rows,
						warm_start_params = warm_start_params,
						warm_start_fisher_info = warm_fisher,
						estimate_only = FALSE,
						optimization_alg = private$optimization_alg,
						fixed_idx = j_treat,
						fixed_values = delta
					)
				},
				extract_start = function(fit){
					as.numeric(fit$params %||% fit$par %||% fit$best_par)
				},
				score = function(fit){
					params = as.numeric(fit$params %||% fit$par %||% fit$best_par)
					as.numeric(fit$score %||% get_clayton_weibull_aft_score_cpp(X, y, dead, pair_idx, singleton_rows, params))
				},
				observed_information = function(fit){
					params = as.numeric(fit$params %||% fit$par %||% fit$best_par)
					as.matrix(fit$observed_information %||% fit$information %||% -get_clayton_weibull_aft_hessian_cpp(X, y, dead, pair_idx, singleton_rows, params))
				},
				fisher_information = function(fit){
					params = as.numeric(fit$params %||% fit$par %||% fit$best_par)
					as.matrix(fit$information %||% fit$observed_information %||% -get_clayton_weibull_aft_hessian_cpp(X, y, dead, pair_idx, singleton_rows, params))
				},
				information = function(fit){
					params = as.numeric(fit$params %||% fit$par %||% fit$best_par)
					as.matrix(fit$information %||% fit$observed_information %||% -get_clayton_weibull_aft_hessian_cpp(X, y, dead, pair_idx, singleton_rows, params))
				},
				neg_loglik = function(fit){
					as.numeric(fit$neg_loglik %||% fit$neg_ll %||% fit$value)
				}
			)
		},
		filtered_covariate_candidates = function(){
			X = as.matrix(private$X)
			if (ncol(X) == 0L) return(list(matrix(nrow = private$n, ncol = 0L)))
			
			# Ensure no linearly dependent columns first
			res = drop_linearly_dependent_cols(X)
			X_reduced = res$M
			if (ncol(X_reduced) == 0L) return(list(matrix(nrow = private$n, ncol = 0L)))
			
			# Generate candidates by dropping highly correlated columns at various thresholds
			thresholds = c(0.99, 0.9, 0.7)
			candidates = list(X_reduced)
			for (thresh in thresholds) {
				X_try = drop_highly_correlated_cols(X_reduced, threshold = thresh)$M
				# Simple way to avoid duplicates in the list
				is_new = TRUE
				for (c in candidates) {
					if (ncol(c) == ncol(X_try) && all(colnames(c) == colnames(X_try))) {
						is_new = FALSE
						break
					}
				}
				if (is_new) candidates[[length(candidates) + 1L]] = X_try
			}
			candidates
		},
		shared = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			if (!is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (is.null(private$cached_values$KKstats)){
				private$compute_basic_match_data()
			}
			KKstats = private$cached_values$KKstats
			m   = KKstats$m
			nRT = KKstats$nRT
			nRC = KKstats$nRC
			m_vec = private$m
			if (is.null(m_vec)) m_vec = rep(NA_integer_, private$n)
			m_vec[is.na(m_vec)] = 0L
			# Optimization candidates
			w_only = matrix(private$w, ncol = 1); colnames(w_only) = "w"
			if (ncol(as.matrix(private$X)) == 0L){
				candidates = list(w_only)
			} else {
				cov_candidates = private$filtered_covariate_candidates()
				candidates = list()
				for (X_cov in cov_candidates){
					if (ncol(X_cov) == 0L){
						M = w_only
					} else {
						M = matrix(private$w, ncol = 1)
						colnames(M) = "w"
						M = cbind(M, X_cov)
						qr_M = qr(M)
						if (qr_M$rank < ncol(M)){
							keep = qr_M$pivot[seq_len(qr_M$rank)]
							if (!(1L %in% keep)) keep = c(1L, keep)
							keep = sort(unique(keep))
							M = M[, keep, drop = FALSE]
						}
						colnames(M)[1] = "w"
					}
					candidates[[length(candidates) + 1L]] = M
				}
				candidates[[length(candidates) + 1L]] = w_only
			}
			for (X in candidates){
				n_params = ncol(X) + 2L
				fit = .fit_clayton_weibull_aft(
					y = private$y,
					dead = private$dead,
					X = X,
					pair_id = m_vec,
					include_singletons = TRUE,
					estimate_only = estimate_only,
					starts = if (!is.null(private$get_fit_warm_start_for_length("params", n_params))) 
					             list(private$get_fit_warm_start_for_length("params", n_params)) else NULL,
					warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params)
				)
				if (!is.null(fit) && is.finite(fit$beta) && (isTRUE(estimate_only) || (is.finite(fit$ssq) && fit$ssq > 0))){
					private$cached_values$beta_hat_T = fit$beta
					private$cached_values$s_beta_hat_T = if (is.finite(fit$ssq) && fit$ssq > 0) sqrt(fit$ssq) else NA_real_
					private$cached_values$theta = fit$theta
					private$best_par = fit$best_par
					private$best_X_colnames = colnames(X)
					private$cached_mod = fit
					private$set_fit_warm_start(fit$best_par, "params", fisher = fit$fisher_information)
					pair_idx = .complete_pair_index_matrix(m_vec) - 1L
					singleton_rows = if (length(pair_idx) > 0L) setdiff(seq_len(length(private$y)), sort(unique(as.vector(pair_idx + 1L)))) - 1L else seq_len(length(private$y)) - 1L
					# .fit_clayton_weibull_aft() prepends "(Intercept)" to X before
					# fitting (helper_survival_fits.R), so fit$best_par is parameterized
					# on the intercept-augmented matrix. The likelihood-test context must
					# store that same matrix (and point j_treat at "w"'s column within it,
					# now 2 instead of 1) or fit_null()'s refits run on a different,
					# non-nested model than the full fit -- see inference_continuous_ols.R
					# for the same X_full/j_treat=2L pattern used elsewhere.
					X_ctx = cbind("(Intercept)" = 1, X)
					private$cached_values$likelihood_test_context = list(
						X = X_ctx,
						y = as.numeric(private$y),
						dead = as.numeric(private$dead),
						pair_idx = pair_idx,
						singleton_rows = singleton_rows,
						start = fit$best_par,
						j_treat = 2L
					)
					return(invisible(NULL))
				}
			}
			private$cached_values$beta_hat_T = NA_real_
			private$cached_values$s_beta_hat_T = NA_real_
		},
		supports_lik_ratio_param_bootstrap = function() TRUE,
		simulate_under_lik_null = function(spec, delta, null_fit){
			par = as.numeric(null_fit$par %||% null_fit$params %||% null_fit$b)
			if (!all(is.finite(par))) return(NULL)
			p = ncol(spec$X)
			if (length(par) < p + 2L) return(NULL)
			b_null = par[seq_len(p)]
			log_sigma = par[p + 1L]
			log_theta = par[p + 2L]
			sigma = exp(log_sigma)
			theta = exp(log_theta)
			if (!is.finite(sigma) || sigma <= 0 || !is.finite(theta) || theta <= 0) return(NULL)
			X = spec$X
			y_obs = as.numeric(spec$y)
			dead_obs = as.numeric(spec$dead)
			pair_idx = spec$pair_idx      # 0-indexed pairs matrix (n_pairs x 2)
			singleton_rows = spec$singleton_rows  # 0-indexed singleton row indices
			n = nrow(X)
			mu = as.numeric(X %*% b_null)
			T_sim = rep(NA_real_, n)
			# Simulate paired subjects via Clayton survival copula
			if (length(pair_idx) > 0L){
				pair_mat = as.matrix(pair_idx) + 1L  # convert to 1-indexed
				for (k in seq_len(nrow(pair_mat))){
					i1 = pair_mat[k, 1L]; i2 = pair_mat[k, 2L]
					U1 = runif(1L)
					W  = runif(1L)
					inner = (W * U1^(theta + 1L))^(-theta / (theta + 1L)) - U1^(-theta) + 1
					inner = max(inner, .Machine$double.xmin)
					U2 = inner^(-1 / theta)
					U2 = min(max(U2, .Machine$double.xmin), 1 - .Machine$double.xmin)
					T_sim[i1] = exp(mu[i1]) * (-log(max(U1, .Machine$double.xmin)))^sigma
					T_sim[i2] = exp(mu[i2]) * (-log(max(U2, .Machine$double.xmin)))^sigma
				}
			}
			# Simulate singleton subjects via marginal Weibull
			if (length(singleton_rows) > 0L){
				sg_idx = singleton_rows + 1L  # convert to 1-indexed
				for (i in sg_idx){
					U = runif(1L)
					T_sim[i] = exp(mu[i]) * (-log(max(U, .Machine$double.xmin)))^sigma
				}
			}
			if (!all(is.finite(T_sim)) || any(T_sim <= 0)) return(NULL)
			C_i = ifelse(dead_obs == 0, y_obs, Inf)
			y_sim = pmin(T_sim, C_i)
			dead_sim = as.numeric(T_sim <= C_i)
			if (!all(is.finite(y_sim)) || any(y_sim <= 0)) return(NULL)
			j = spec$j
			warm_full = c(as.numeric(par))
			full_res = tryCatch(
				fast_clayton_weibull_aft_optim_cpp(
					X = X, y = y_sim, dead = dead_sim,
					pair_idx = pair_idx, singleton_rows = singleton_rows,
					warm_start_params = warm_full,
					estimate_only = FALSE,
					optimization_alg = private$optimization_alg
				),
				error = function(e) NULL
			)
			if (is.null(full_res) || !isTRUE(full_res$converged)) return(NULL)
			full_par = as.numeric(full_res$par %||% full_res$params %||% full_res$b)
			if (length(full_par) < j || !is.finite(full_par[j])) return(NULL)
			list(
				full_fit = full_res,
				fit_null = function(d, start = NULL){
					warm = start %||% full_par
					tryCatch(
						fast_clayton_weibull_aft_optim_cpp(
							X = X, y = y_sim, dead = dead_sim,
							pair_idx = pair_idx, singleton_rows = singleton_rows,
							warm_start_params = warm,
							estimate_only = FALSE,
							optimization_alg = private$optimization_alg,
							fixed_idx = j, fixed_values = d
						),
						error = function(e) NULL
					)
				},
				neg_loglik = function(fit) as.numeric(fit$neg_loglik %||% fit$neg_ll %||% fit$value)
			)
		}
	)
)

#' One-Likelihood Clayton-Copula Weibull AFT Inference for KK Survival Designs
#'
#' Estimates a treatment log-time-ratio \eqn{\beta_T} for right-censored
#' survival outcomes collected under a KK matching-on-the-fly design
#' (\code{\link[EDI:DesignSeqOneByOneKK14]{DesignSeqOneByOneKK14}} or
#' subclass) by maximizing a single combined likelihood: matched-pair
#' survival times are modeled with a Weibull accelerated-failure-time (AFT)
#' margin joined by a Clayton copula (dependence parameter \eqn{\theta})
#' to account for within-pair correlation induced by shared matching
#' covariates, while unmatched reservoir subjects are modeled by the same
#' Weibull AFT margin marginally (no dependence term). All subjects share
#' one treatment coefficient, estimated jointly.
#'
#' \strong{Estimand.} \eqn{\beta_T}, the treatment coefficient of a Weibull
#' AFT model \eqn{\log T = \beta_0 + \beta_T W + X\beta + \sigma\epsilon}
#' with \eqn{\epsilon} extreme-value-distributed; \eqn{\exp(\hat\beta_T)}
#' is the treatment-vs-control survival-time ratio (an acceleration
#' factor). This is a distinct scale from the log hazard ratio reported by
#' Cox-based KK survival classes.
#'
#' \strong{Model.} \code{.fit_clayton_weibull_aft()} jointly optimizes the
#' AFT regression coefficients, the Weibull shape (\eqn{\log\sigma}), and
#' the Clayton copula dependence parameter (\eqn{\log\theta}) by direct
#' maximum likelihood over the combined matched-pair-copula /
#' reservoir-marginal log-likelihood; right-censoring enters as the usual
#' survival contribution (density for observed failures, survival function
#' for censored times). \code{likelihood_tier = "full"}, so a parametric
#' likelihood bootstrap (\code{simulate_under_lik_null}, which draws new
#' pair times from the fitted Clayton copula and new singleton times from
#' the marginal Weibull) is available alongside Wald inference.
#'
#' \strong{Assumptions.} Weibull AFT margin correctly specified; Clayton
#' copula correctly captures within-pair dependence (a positive-dependence,
#' single-parameter Archimedean copula); independent censoring given
#' covariates; a KK matching-on-the-fly design supplying the matched/
#' reservoir partition.
#'
#' @references
#' Clayton, D. G. (1978). "A model for association in bivariate life tables
#' and its application in epidemiological studies of familial tendency in
#' chronic disease incidence." \emph{Biometrika}, 65(1), 141-151.
#' \doi{10.1093/biomet/65.1.141}. (Clayton1978 in \code{REFERENCES.md}.)
#'
#' Oakes, D. (1989). "Bivariate survival models induced by frailties."
#' \emph{Journal of the American Statistical Association}, 84(406),
#' 487-493. \doi{10.1080/01621459.1989.10478795}. (Oakes1989 in
#' \code{REFERENCES.md}.)
#'
#' @seealso Analogous Python API for AFT/copula survival models:
#'   \href{https://lifelines.readthedocs.io/en/latest/fitters/regression/WeibullAFTFitter.html}{lifelines
#'   WeibullAFTFitter}, \href{https://sdv.dev/Copulas/}{copulas}.
#'   \href{https://en.wikipedia.org/wiki/Copula_(probability_theory)}{Copula
#'   (probability theory)} (orientation).
#' @export
# Migrated 2026-08-19 (fix_inference_hierarchy.md "Full-Likelihood
# Estimators" / "KK And IVWC Estimators"): see
# InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLikLegacyRaw's comment above.
InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik = define_inference_class(
	classname = "InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik",
	inherit = Inference,
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "SurvivalGLMMWeibullFrailtyLoggammaOneLik"),
	public = list(
		# Pinned from InferenceRand -- same flattened-super$ rationale as every
		# other survival KK migration this stretch.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	),
	# capabilities = "likelihood_ratio" is required explicitly -- same
	# rationale as every class composing ParametricLikelihoodBootstrap
	# directly (bypassing StandardModelCache).
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"initialize",
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"get_supported_testing_types", "set_testing_type",
			"approximate_bootstrap_distribution_beta_hat_T",
			"duplicate"
		),
		private = c(
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl",
			"compute_treatment_estimate_during_randomization_inference",
			"compute_basic_match_data",
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
			"simulate_under_lik_null"
		)
	)
)
