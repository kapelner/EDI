# Null fit when beta_T is the only Cox parameter (TODO-121, as TODO-115 for the
# clogit sibling): no optimization, b = delta. The partial likelihood uses the
# Breslow rule, the same as the C++ fitter that produced the full fit.
kk_cox_fully_fixed_null_fit = function(X, y, dead, strata, delta){
	delta = as.numeric(delta)[1L]
	if (!is.finite(delta)) return(NULL)
	nll = .cox_neg_loglik_breslow_r(X, y, dead, delta, strata = strata)
	if (!is.finite(nll)) return(NULL)
	list(b = delta, coefficients = delta, params = delta, neg_ll = nll, neg_loglik = nll,
		converged = TRUE, fixed_all = TRUE)
}

# v1.0.6-TODO-128: columns of a stratified Cox design that are aliased once each
# stratum's mean is removed (constant within every stratum, or a within-stratum
# linear combination of earlier columns) are not identified by the partial
# likelihood. Returns X unchanged when it has full within-strata rank; otherwise
# keeps column 1 (treatment) and the identified columns, in their original order.
# If treatment itself is aliased, X is returned unchanged and the fit fails.
kk_strat_cox_drop_within_strata_aliased_cols = function(X, strata){
	X = as.matrix(X)
	if (ncol(X) <= 1L || nrow(X) == 0L) return(X)
	strata = as.integer(strata)
	Xc = X - apply(X, 2L, function(col) stats::ave(col, strata))
	qr_c = qr(Xc, tol = 1e-7)
	if (qr_c$rank == ncol(X)) return(X)
	keep = sort(qr_c$pivot[seq_len(qr_c$rank)])
	if (!(1L %in% keep)) return(X)
	X[, keep, drop = FALSE]
}

# Static leaf source (2026-08-18 migration, fix_inference_hierarchy.md "KK And
# IVWC Estimators"): formerly a plain leaf on
# `InferenceKKPassThroughCompoundNoParamBootstrap`; the KK compound layer now
# arrives via the registered KKCompound component (this component's declared
# dependency). The `eval(body(InferenceMixinKKPassThrough$public$approximate_
# bootstrap_distribution_beta_hat_T))` override was dropped as a verified
# no-op (same argument as SurvivalKKRankRegrIVWCSource: the compound ladder's
# inline public list never overrode that method, so the ladder inherited
# exactly that body anyway). The factory call is below the source. The OneLik
# sibling later in this file is untouched (one-likelihood phase).
#' KK stratified Cox IVWC component source
#'
#' Source list for the KK stratified Cox inverse-variance-weighted-combination (IVWC) survival component.
#'
#' @keywords internal
SurvivalKKStratCoxIVWCSource = list(
	public = list(
		#' @description Initialize KK stratified Cox IVWC inference and prepare the
		#'   matched/reservoir partial-likelihood components used by
		#'   \code{\link[EDI:InferenceSurvivalKKStratCoxPHIVWC]{InferenceSurvivalKKStratCoxPHIVWC}}.
		#' @param des_obj  	A DesignSeqOneByOne object (must be a KK design).
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose  		Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL,  verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "survival")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			private$init_kk_passthrough(des_obj)
		},
		#' @description Returns the estimated treatment effect (log-hazard ratio).
		#' @param estimate_only If TRUE, return a cached estimate when one exists. The
		#'   estimate is always the inverse-variance-weighted combination, which needs
		#'   both halves' variances, so a fresh call costs the same as a full fit.
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
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
			}
			private$shared()
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Compute the stratified-Cox asymptotic p-value for the
		#'   treatment log-hazard ratio using the fitted partial-likelihood standard
		#'   error. See \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param delta                                   The null difference to test against.
		#'   Only zero (the default, testing for any treatment effect at all) is currently
		#'   supported; a non-zero value raises an error, or returns \code{NA} when
		#'   assertions are disabled.
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta, len = 1, finite = TRUE, any.missing = FALSE)
			}
			private$shared()
			if (delta == 0){
				private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
			} else {
				if (should_run_asserts()) {
					stop("Testing non-zero delta is not yet implemented for this class.")
				}
				NA_real_
			}
		}
	),
	private = list(
		# Copied verbatim from InferenceMLEorKMSummaryTable (the old ladder's
		# ancestor) -- Lesson 5 (see SurvivalKKRankRegrIVWCSource): the Wald
		# component's own get_standard_error() fallback stop()s when the SE is
		# missing (e.g. the nonestimable paths in shared() below), whereas the
		# old ladder's version (this one) calls shared() and then degrades to
		# NA_real_, which Wald-impl methods turn into NA CIs/p-values.
		get_standard_error = function(){
			private$shared(estimate_only = FALSE)
			se = private$cached_values$s_beta_hat_T
			if (is.null(se) || length(se) != 1L) NA_real_ else se
		},
		# Overrides the generic KK pass-through delegation to
		# private$compute_basic_kk_match_data_impl(): that shared helper delegates
		# to compute_zhang_match_data_cpp(), which only ever produces
		# paired-difference match data for binary/incidence outcomes (X_matched_diffs,
		# yTs_matched/yCs_matched, X_reservoir/y_reservoir/w_reservoir, nRT/nRC, ...)
		# and has no notion of censoring. shared() below needs per-subject long-format
		# data (one row per matched subject, grouped by pair id as a stratum, plus a
		# censoring indicator) to feed fast_stratified_coxph_regression_cpp() /
		# fast_coxph_regression_cpp(); the shared kernel never produced those fields,
		# so KKstats$*_matched_long silently came back empty for every caller of this
		# class (interval_censored_survival_response.md TODO-16). Built directly from
		# this object's own private fields instead of the shared Zhang-style kernel.
		compute_basic_match_data = function(){
			if (!isTRUE(private$has_match_structure)) {
				private$cache_nonestimable_estimate("kk_design_required")
				return(invisible(NULL))
			}
			split = split_kk_matched_reservoir_idx(private$m, private$n)
			m_vec = split$m_vec
			matched_idx = split$matched_idx
			reservoir_idx = split$reservoir_idx
			X_full = private$get_X()
			if (is.null(X_full)) X_full = matrix(numeric(0), nrow = private$n, ncol = 0L)
			X_full = as.matrix(X_full)

			private$cached_values$KKstats = list(
				m = length(unique(m_vec[matched_idx])),
				nRT = sum(private$w[reservoir_idx] == 1L),
				nRC = sum(private$w[reservoir_idx] == 0L),
				y_matched_long = private$y[matched_idx],
				dead_matched_long = private$dead[matched_idx],
				w_matched_long = private$w[matched_idx],
				m_matched_long = m_vec[matched_idx],
				X_matched_long = X_full[matched_idx, , drop = FALSE],
				y_reservoir = private$y[reservoir_idx],
				dead_reservoir = private$dead[reservoir_idx],
				w_reservoir = private$w[reservoir_idx],
				X_reservoir = X_full[reservoir_idx, , drop = FALSE]
			)
			private$cached_values$KKstats
		},
		max_abs_reasonable_coef = 1e4,
		# Ladder of design-matrix candidates (w first): the full matrix alone when not
		# hardening, else the hardened-QR matrix, then increasingly aggressive
		# correlated-column dropping.
		cox_design_candidates = function(w, X){
			X_full = matrix(w, ncol = 1)
			colnames(X_full) = "w"
			X_covs = as.matrix(X)
			if (ncol(X_covs) > 0L){
				X_full = cbind(X_full, X_covs)
			}
			if (!private$harden || ncol(X_full) <= 1L){
				return(list(X_full))
			}
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 1L,
				fit_fun = function(X_fit) X_fit,
				fit_ok = function(mod, X_fit, keep) TRUE
			)
			candidates = list(attempt$X)
			keys = paste(colnames(candidates[[1L]]), collapse = "|")
			thresholds = c(0.99, 0.95, 0.90, 0.85, 0.80, 0.70, 0.60, 0.50, 0.40, 0.30, 0.20, 0.10)
			X_cov_orig = X_full[, -1, drop = FALSE]
			for (thresh in thresholds){
				X_cov = drop_highly_correlated_cols(X_cov_orig, threshold = thresh)$M
				X_try = matrix(w, ncol = 1)
				colnames(X_try) = "w"
				if (ncol(X_cov) > 0){
					X_try = cbind(X_try, X_cov)
				}
				X_try_df = as.data.frame(X_try)
				key = paste(colnames(X_try_df), collapse = "|")
				if (key %in% keys) next
				keys = c(keys, key)
				attempt_try = private$fit_with_hardened_qr_column_dropping(
					X_full = X_try,
					required_cols = 1L,
					fit_fun = function(X_fit) X_fit,
					fit_ok = function(mod, X_fit, keep) TRUE
				)
				candidates[[length(candidates) + 1L]] = attempt_try$X
			}
			candidates
		},
		# v1.0.6-TODO-217: the Bayesian-bootstrap replicate. It used to fall through to
		# the KK compound's generic mean-difference fallback, which reads
		# KKstats$y_matched_diffs; this class never builds that field, so every
		# replicate was sum(NULL) / ... = 0 and the interval was [0, 0]. Now it is the
		# same estimator as shared(): a weighted stratified Cox fit of the matched
		# pairs (pair strata) and a weighted Cox fit of the reservoir, each with the
		# variance of its own weighted fit, pooled by inverse variance.
		compute_weighted_estimate_ivwc = function(w_info, estimate_only = FALSE){
			row_weights = kk_ivwc_row_weights(w_info, private$n)
			if (weights_are_effectively_constant(row_weights)) {
				return(as.numeric(self$compute_estimate(estimate_only = TRUE))[1L])
			}
			private$clear_nonestimable_state()
			KKstats = private$cached_values$KKstats
			if (is.null(KKstats)) KKstats = private$compute_basic_match_data()
			if (is.null(KKstats) || sum(private$dead) == 0L) {
				private$cache_nonestimable_estimate("kk_strat_cox_ivwc_weighted_no_events")
				return(NA_real_)
			}
			split = split_kk_matched_reservoir_idx(private$m, private$n)
			beta_m = NA_real_; ssq_m = NA_real_
			if (KKstats$m > 0) {
				strata_m = KKstats$m_matched_long
				X_m = cbind(w = KKstats$w_matched_long, KKstats$X_matched_long)
				if (isTRUE(private$harden)) X_m = kk_strat_cox_drop_within_strata_aliased_cols(X_m, strata_m)
				fit_m = kk_ivwc_weighted_cox_half(
					KKstats$y_matched_long, KKstats$dead_matched_long, list(X_m),
					row_weights[split$matched_idx], strata = strata_m,
					max_abs = private$max_abs_reasonable_coef
				)
				if (!is.null(fit_m)) { beta_m = fit_m$beta; ssq_m = fit_m$ssq }
			}
			beta_r = NA_real_; ssq_r = NA_real_
			if (KKstats$nRT > 0 && KKstats$nRC > 0) {
				w_r = KKstats$w_reservoir
				X_treat_only = matrix(w_r, ncol = 1L, dimnames = list(NULL, "w"))
				fit_r = kk_ivwc_weighted_cox_half(
					KKstats$y_reservoir, KKstats$dead_reservoir,
					c(private$cox_design_candidates(w_r, as.matrix(KKstats$X_reservoir)), list(X_treat_only)),
					row_weights[split$reservoir_idx],
					max_abs = private$max_abs_reasonable_coef
				)
				if (!is.null(fit_r)) { beta_r = fit_r$beta; ssq_r = fit_r$ssq }
			}
			pooled = kk_ivwc_pool_halves(beta_m, ssq_m, beta_r, ssq_r)
			if (!is.finite(pooled$beta)) {
				private$cache_nonestimable_estimate("kk_strat_cox_ivwc_weighted_both_failed")
				return(NA_real_)
			}
			private$cached_values$beta_hat_T = pooled$beta
			private$cached_values$s_beta_hat_T = if (estimate_only) NA_real_ else sqrt(pooled$ssq)
			pooled$beta
		},
		rcpp_cox_fit_is_usable = function(fit, estimate_only = FALSE){
			if (is.null(fit) || !isTRUE(fit$converged)) return(FALSE)
			coef1 = fit$coefficients[1L]
			if (!is.finite(coef1) || abs(coef1) > private$max_abs_reasonable_coef) return(FALSE)
			if (estimate_only) return(TRUE)
			# A negative variance is unusable; test it before sqrt() so it does not
			# warn "NaNs produced" (every resampling replicate now takes this path,
			# v1.0.6-TODO-132).
			v = fit$vcov[1L, 1L]
			is.finite(v) && v > 0 && sqrt(v) <= private$max_abs_reasonable_coef
		},
		shared = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			# v1.0.6-TODO-132 (owner decision 2026-11-19): estimate_only = TRUE used
			# to combine the two halves by sample size (and to accept halves whose
			# variance was not finite), a different estimator from the reported
			# inverse-variance-weighted one. The reusable worker, the jackknife and
			# the slow subset refit all call compute_estimate(estimate_only = TRUE),
			# so their replicates were not of the reported quantity, and the result
			# depended on call order (after a full fit, the cached IVW value was
			# returned). The IVW weights need both halves' variances, so every call
			# now runs the full fit; estimate_only only selects the cache check above.
			private$clear_nonestimable_state()
			if (is.null(private$cached_values$KKstats)){
				private$compute_basic_match_data()
			}
			KKstats = private$cached_values$KKstats
			if (is.null(KKstats)) return(invisible(NULL))
			m = KKstats$m
			nRT = KKstats$nRT
			nRC = KKstats$nRC
			if (sum(private$dead) == 0L){
				private$cache_nonestimable_estimate("kk_strat_cox_ivwc_no_events")
				return(invisible(NULL))
			}
			# ── Matched pairs ───────────────────────────────────────────────
			beta_m = NA_real_; ssq_m = NA_real_
			if (m > 0){
				y_m = KKstats$y_matched_long
				dead_m = KKstats$dead_matched_long
				w_m = KKstats$w_matched_long
				strata_m = KKstats$m_matched_long
				X_cov_m = KKstats$X_matched_long
				X_m = cbind(w = w_m, X_cov_m)
				# v1.0.6-TODO-128: a covariate constant within every pair (e.g. a rare
				# binary whose carriers all sit in the reservoir, or a bootstrap draw
				# that omits them) is aliased with the pair strata. The C++ fitter then
				# returns a finite treatment coefficient but a NaN vcov, so the matched
				# half was dropped whenever an SE was requested (compute_estimate())
				# and kept when it was not (the reusable bootstrap worker). Drop the
				# aliased columns, as survival::coxph(strata = ) does; full-rank
				# matrices are returned unchanged.
				if (isTRUE(private$harden)) X_m = kk_strat_cox_drop_within_strata_aliased_cols(X_m, strata_m)

				res = tryCatch(
					fast_stratified_coxph_regression_cpp(X_m, y_m, dead_m, as.integer(strata_m), estimate_only = FALSE),
					error = function(e) NULL
				)
				if (private$rcpp_cox_fit_is_usable(res)){
					beta_m = res$coefficients[1L]
					ssq_m = res$vcov[1L, 1L]
				}
			}
			# ── Reservoir ───────────────────────────────────────────────────
			beta_r = NA_real_; ssq_r = NA_real_
			res = NULL
			if (nRT > 0 && nRC > 0){
				y_r = KKstats$y_reservoir
				dead_r = KKstats$dead_reservoir
				w_r = KKstats$w_reservoir
				X_cov_r = as.matrix(KKstats$X_reservoir)
				candidates = private$cox_design_candidates(w_r, X_cov_r)
				for (X_candidate in candidates){
					res_try = tryCatch(
						fast_coxph_regression_cpp(X_candidate, y_r, dead_r, estimate_only = FALSE),
						error = function(e) NULL
					)
					if (private$rcpp_cox_fit_is_usable(res_try)){
						res = res_try
						break
					}
				}
				# v1.0.6-TODO-133: the treatment-only fallback used to be accepted
				# unchecked, so a separated reservoir (e.g. one treated subject)
				# passed an infinite-coefficient fit (|beta| ~ 22, huge SE) into the
				# combination. It also ran when an arm was empty, where y_r/dead_r
				# were undefined (the error was swallowed by tryCatch). Now it runs
				# only with both arms present and must pass the same usability check.
				if (is.null(res)){
					X_mat = matrix(w_r, ncol = 1L)
					colnames(X_mat) = "w"
					res_try = tryCatch(
						fast_coxph_regression_cpp(X_mat, y_r, dead_r, estimate_only = FALSE),
						error = function(e) NULL
					)
					if (private$rcpp_cox_fit_is_usable(res_try)) res = res_try
				}
			}
			if (!is.null(res)){
				beta_r = res$coefficients[1L]
				ssq_r = res$vcov[1L, 1L]
			}
			# ── Combine ─────────────────────────────────────────────────────
			m_ok = is.finite(beta_m) && is.finite(ssq_m) && ssq_m > 0
			r_ok = is.finite(beta_r) && is.finite(ssq_r) && ssq_r > 0
			if (m_ok && r_ok){
				w_star = ssq_r / (ssq_r + ssq_m)
				private$cached_values$beta_hat_T = w_star * beta_m + (1 - w_star) * beta_r
				private$cached_values$s_beta_hat_T = sqrt(ssq_m * ssq_r / (ssq_m + ssq_r))
			} else if (m_ok){
				private$cached_values$beta_hat_T = beta_m
				private$cached_values$s_beta_hat_T = sqrt(ssq_m)
				# v1.0.6-TODO-133: say so whenever a non-empty reservoir is dropped
				# (warn on direct calls only, never inside resampling). Owner decision
				# 2026-11-18: an empty reservoir arm warns too; it carries no treatment
				# contrast, so the reservoir subjects do not contribute to the estimate.
				if (nRT + nRC > 0L && is.null(private$active_resampling_operation)) {
					why = if (nRT == 0L || nRC == 0L) {
						paste0(" has an empty ", if (nRT == 0L) "treated" else "control",
							" arm, so it carries no treatment contrast")
					} else {
						" has no usable Cox fit with a finite standard error"
					}
					warning(structure(
						class = c("edi_kk_strat_cox_ivwc_reservoir_dropped_warning", "warning", "condition"),
						list(
							message = paste0(class(self)[1L], ": the reservoir (treated/control: ", nRT, "/", nRC,
								")", why, "; using the matched-pair stratified Cox estimate alone."),
							call = NULL
						)
					))
				}
			} else if (r_ok){
				private$cached_values$beta_hat_T = beta_r
				private$cached_values$s_beta_hat_T = sqrt(ssq_r)
			} else {
				private$cache_nonestimable_estimate("kk_strat_cox_ivwc_both_failed")
				# v1.0.6-TODO-128: do not hand back NA silently. Resampling replicates
				# are summarised by the resampling layer, so warn only on direct calls.
				if (is.null(private$active_resampling_operation)) {
					warning(structure(
						class = c("edi_kk_strat_cox_ivwc_nonestimable_warning", "warning", "condition"),
						list(
							message = paste0(class(self)[1L], ": neither the matched-pair stratified Cox fit nor ",
								"the reservoir Cox fit is usable with a finite standard error",
								" (matched pairs: ", m, ", reservoir treated/control: ", nRT, "/", nRC,
								"); returning NA."),
							call = NULL
						)
					))
				}
			}
		}
	)
)

#' Stratified Cox / Standard Cox Compound Inference for KK Designs
#'
#' This class implements a compound estimator for KK matching-on-the-fly designs with
#' survival responses. For matched pairs, it uses stratified Cox proportional hazards
#' regression (each pair is a stratum). For reservoir subjects, it uses standard Cox
#' regression. The two estimates (both log-hazard ratios) are combined via a
#' variance-weighted linear combination.
#'
#' Under \code{harden = TRUE}, multivariate fits preserve the treatment column and
#' progressively retry reduced covariate sets after QR-based rank reduction and
#' correlation-based pruning. Extreme finite coefficients / standard errors are
#' rejected and treated as non-estimable.
#'
#' The matched-pair sub-estimate treats each pair as its own stratum (a
#' pair-specific baseline hazard, exactly canceling shared-frailty effects
#' within the pair via Cox's partial likelihood) and is a special case of the
#' Lee-Wei-Amato (1992) large-numbers-of-small-groups stratified Cox approach;
#' the reservoir sub-estimate is a standard unstratified Cox partial-likelihood
#' fit (Cox 1972). The two log-hazard-ratio estimates are combined by
#' inverse-variance weighting, the same rule used throughout the KK IVWC family.
#'
#' \strong{Legacy class.} Not fully tested in \code{comprehensive_tests.R}.
#' @references
#' Cox, D. R. (1972). "Regression Models and Life-Tables." Journal of the
#' Royal Statistical Society, Series B, 34(2), 187-220.
#'
#' Lee, E. W., Wei, L. J., Amato, D. A., and Leurgans, S. (1992). "Cox-Type Regression
#' Analysis for Large Numbers of Small Groups of Correlated Failure Time
#' Observations." In Survival Analysis: State of the Art, 237-247. Springer.
#' \doi{10.1007/978-94-015-7983-4_14}
#' @export
InferenceSurvivalKKStratCoxPHIVWC = define_inference_class(
	classname = "InferenceSurvivalKKStratCoxPHIVWC",
	inherit = Inference,
	components = c(
		"RandomizationCI",
		"RandomizationBootstrapCI",
		"BayesianBootstrap",
		"Jackknife",
		"Wald",
		"SurvivalKKStratCoxIVWC"
	),
	public = list(
		# Pinned from InferenceRand -- same flattened-super$ rationale as every
		# other survival/count KK migration this stretch.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	),
	metadata = list(likelihood_tier = "partial"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"initialize",
			"compute_estimate",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			# KKCompound chain vs bootstrap/Wald chain: the KK-aware versions win
			# via component order (KKCompound resolves after BayesianBootstrap/
			# Wald), matching the old ladder's inherited behavior -- the source
			# dropped the class's no-op eval(body(...)) restatement of
			# approximate_bootstrap_distribution_beta_hat_T.
			"approximate_bootstrap_distribution_beta_hat_T",
			"compute_estimate_with_bootstrap_weights"
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
			# MLEorKM's graceful-NA version wins over the Wald component's
			# stop()-on-missing-SE fallback (Lesson 5, see the Source comment).
			"get_standard_error"
		)
	)
)

#' @R6method InferenceSurvivalKKStratCoxPHIVWC$approximate_randomization_distribution_beta_hat_T
#' @template rand-approx-distribution-beta-hat-t
NULL

#' @R6method InferenceSurvivalKKStratCoxPHIVWC$supports_rand_pval_for_incidence
#' @template rand-supports-pval-incidence
NULL

#' @R6method InferenceSurvivalKKStratCoxPHIVWC$compute_rand_two_sided_pval
#' @template rand-compute-rand-two-sided-pval-params
NULL

#' Stratified Cox Combined-Likelihood Compound Inference for KK Designs
#'
#' @keywords internal
# Static leaf-shared source (2026-08-18 migration, fix_inference_hierarchy.md
# "Partial-Likelihood Estimators" / "KK And IVWC Estimators"): formerly a
# single-layer R6 leaf `InferenceSurvivalKKStratCoxPHOneLik` inheriting
# `InferenceParamBootstrap` and raw-splicing `InferenceMixinKKPassThrough$
# public/private`. Merged into the registered component source
# `SurvivalKKStratCoxOneLikPartialLikelihoodSource` (see the
# SurvivalKKStratCoxOneLikPartialLikelihood entry in contracts_mixins.R,
# analogous reshaping to KKLWACoxOneLikPartialLikelihoodSource). The
# `eval(body(InferenceMixinKKPassThrough$public$approximate_bootstrap_
# distribution_beta_hat_T))` override was dropped as a verified no-op (same
# argument as every other KK leaf this stretch): the old ladder's inline
# public list only overrode initialize/compute_estimate/compute_estimate_
# with_bootstrap_weights/compute_asymp_*, so it inherited exactly that
# KKPassThrough body anyway; the class declares the collision in its
# factory's overrides so the KKPassThrough-supplied version wins. This class
# never overrode compute_treatment_estimate_during_randomization_inference
# (unlike the LWA Cox OneLik sibling), so it also flows through unchanged
# from the KKPassThrough dependency -- declared as a collision override on
# the factory, not duplicated in this source.
SurvivalKKStratCoxOneLikPartialLikelihoodSource = list(
	public = list(
		#' @description Initialize KK stratified Cox one-likelihood inference and
		#'   prepare the combined partial-likelihood fit used by
		#'   \code{\link[EDI:InferenceSurvivalKKStratCoxPHOneLik]{InferenceSurvivalKKStratCoxPHOneLik}}.
		#' @param des_obj A completed KK survival design object.
		#' @param model_formula Optional formula for covariate adjustment.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL,  verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "survival")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			# Lesson 1 (see KKNewcombeRiskDiffIVWCSource): post-migration
			# super$initialize() resolves to the root Inference, not
			# InferenceParamBootstrap, so the KK match-structure setup that
			# ancestor's initialize() performed must be invoked explicitly here.
			private$init_kk_passthrough(des_obj)
		},
		#' @description Returns the model-specific combined-likelihood treatment estimate; see
		#'   \code{\link[EDI:InferenceAsympLik]{InferenceAsympLik}}.
		#' @param estimate_only If \code{TRUE}, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared_combined_likelihood(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the one-likelihood stratified Cox treatment
		#'   estimate under Bayesian-bootstrap weights.
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
			m_vec = private$m
			if (is.null(m_vec)) m_vec = rep(NA_integer_, private$n)
			m_vec[is.na(m_vec)] = 0L
			strata = m_vec
			res_idx = which(strata == 0L)
			if (length(res_idx) > 0L) {
				# One shared reservoir stratum, identical to the point estimate in
				# shared_combined_likelihood() (singleton strata contribute nothing).
				max_m = if (any(strata > 0L)) max(strata) else 0L
				strata[res_idx] = max_m + 1L
			}
			X_cov = private$get_X()
			X_fit = if (ncol(as.matrix(X_cov)) > 0) cbind(treatment = private$w, X_cov) else matrix(private$w, ncol = 1, dimnames = list(NULL, "treatment"))
			fit = weighted_cox_bootstrap_surrogate_fit(
				private$y, private$dead, X_fit, row_weights,
				strata = strata,
				warm_start_beta = private$get_fit_warm_start_for_length("params", ncol(X_fit)) %||% private$get_fit_warm_start_for_length("beta", ncol(X_fit))
			)
			private$cached_values$beta_hat_T = if (is.null(fit)) NA_real_ else as.numeric(fit$beta_hat)
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$beta_hat_T
		},
		#' @description Computes an asymptotic confidence interval for the treatment effect.
		#' @param alpha Significance level; the interval has confidence level 1 - \code{alpha}. Default 0.05.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
			}
			# TODO-121: honor the configured testing type. This override used to
			# return the Wald interval for every type, so score / lik_ratio /
			# gradient requests were silently served Wald under another label.
			tt = self$get_testing_type()
			if (!identical(tt, "wald")) {
				return(switch(
					tt,
					score = private$compute_score_confidence_interval_impl(alpha),
					gradient = private$compute_gradient_confidence_interval_impl(alpha),
					lik_ratio = private$compute_lik_ratio_confidence_interval_impl(alpha),
					lik_ratio_bartlett_approx = private$compute_lik_ratio_bartlett_approx_confidence_interval_impl(alpha),
					lik_ratio_bartlett_exact = private$compute_lik_ratio_bartlett_exact_confidence_interval_impl(alpha),
					stop(class(self)[1], ": unsupported testing_type \"", tt, "\".", call. = FALSE)
				))
			}
			private$shared_combined_likelihood(estimate_only = FALSE)
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Returns a 2-sided p-value for H0: beta_T = delta.
		#' @param delta Null treatment effect value.
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta, len = 1, finite = TRUE, any.missing = FALSE)
			}
			# TODO-121: honor the configured testing type (see the CI above).
			tt = self$get_testing_type()
			if (!identical(tt, "wald")) {
				return(switch(
					tt,
					score = private$compute_score_two_sided_pval_impl(delta),
					gradient = private$compute_gradient_two_sided_pval_impl(delta),
					lik_ratio = private$compute_lik_ratio_two_sided_pval_impl(delta),
					lik_ratio_bartlett_approx = private$compute_lik_ratio_bartlett_approx_two_sided_pval_impl(delta),
					lik_ratio_bartlett_exact = private$compute_lik_ratio_bartlett_exact_two_sided_pval_impl(delta),
					stop(class(self)[1], ": unsupported testing_type \"", tt, "\".", call. = FALSE)
				))
			}
			private$shared_combined_likelihood(estimate_only = FALSE)
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		}
	),
	private = list(
		compute_basic_match_data = function() private$compute_basic_kk_match_data_impl(),
		max_abs_reasonable_coef = 1e4,
		best_X_colnames = NULL,
		design_matrix_candidates = function(){
			X_full = matrix(private$w, ncol = 1)
			colnames(X_full) = "w"
			X_covs = private$get_X()
			if (ncol(as.matrix(X_covs)) > 0L){
				X_full = cbind(X_full, as.matrix(X_covs))
			}
			X_full
		},
		shared_combined_likelihood = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			private$clear_nonestimable_state()
			if (is.null(private$cached_values$KKstats)){
				private$compute_basic_match_data()
			}
			m_vec = private$m
			if (is.null(m_vec)) m_vec = rep(NA_integer_, private$n)
			m_vec[is.na(m_vec)] = 0L
			strata_ids = m_vec
			res_idx = which(strata_ids == 0L)
			if (length(res_idx) > 0L){
				max_m = if (any(strata_ids > 0L)) max(strata_ids) else 0L
				strata_ids[res_idx] = max_m + 1L
			}
			X_full = private$design_matrix_candidates()
			attempt = private$fit_with_hardened_qr_column_dropping(
				X_full = X_full,
				required_cols = 1L,
				fit_fun = function(X_fit){
					fast_stratified_coxph_regression_cpp(
						X = as.matrix(X_fit),
						y = private$y,
						dead = private$dead,
						strata = as.integer(strata_ids),
						estimate_only = estimate_only,
						optimization_alg = private$optimization_alg
					)
				},
				fit_ok = function(res, X_fit, keep){
					if (is.null(res) || !isTRUE(res$converged)) return(FALSE)
					beta = res$coefficients[1L]
					if (!is.finite(beta) || abs(beta) > private$max_abs_reasonable_coef) return(FALSE)
					if (estimate_only) return(TRUE)
					se = tryCatch(sqrt(res$vcov[1L, 1L]), error = function(e) NA_real_)
					is.finite(se) && se > 0 && se <= private$max_abs_reasonable_coef
				}
			)
			res = attempt$fit
			if (!is.null(res)){
				private$best_X_colnames = setdiff(colnames(attempt$X), "w")
				private$cached_mod = res
				private$cached_values$likelihood_test_context = list(
					X = attempt$X,
					y = private$y,
					dead = private$dead,
					strata = strata_ids,
					j_treat = 1L
				)
				private$cached_values$beta_hat_T = as.numeric(res$coefficients[1L])
				if (!estimate_only){
					se = sqrt(res$vcov[1L, 1L])
					private$cached_values$s_beta_hat_T = if (is.finite(se) && se > 0) se else NA_real_
				}
				return(invisible(NULL))
			}
			private$cache_nonestimable_estimate("kk_strat_cox_combined_fit_failed")
			invisible(NULL)
		},
		supports_likelihood_tests = function() TRUE,
		get_likelihood_test_spec = function(){
			private$shared_combined_likelihood(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			X_fit = ctx$X
			y = as.numeric(ctx$y)
			dead = as.numeric(ctx$dead)
			strata = as.integer(ctx$strata)
			j_treat = as.integer(ctx$j_treat %||% 1L)
			list(
				X = X_fit, y = y, dead = dead, strata = strata, j = j_treat,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					# TODO-121 (same as TODO-115): beta_T is the only parameter, so
					# nothing is free and the solver rejects the empty free set;
					# the null fit is the fixed point b = delta.
					if (ncol(X_fit) == 1L) return(kk_cox_fully_fixed_null_fit(X_fit, y, dead, strata, delta))
					warm = start %||% private$get_fit_warm_start_for_length("params", ncol(X_fit))
					fast_stratified_coxph_regression_cpp(
						X = X_fit, y = y, dead = dead, strata = strata,
						warm_start_beta = warm,
						estimate_only = FALSE,
						optimization_alg = private$optimization_alg,
						fixed_idx = j_treat, fixed_values = delta
					)
				},
				extract_start = function(fit) as.numeric(fit$coefficients %||% fit$b),
				score = function(fit){
					beta = as.numeric(fit$coefficients %||% fit$b)
					get_stratified_coxph_score_cpp(X_fit, y, dead, strata, beta)
				},
				observed_information = function(fit){
					beta = as.numeric(fit$coefficients %||% fit$b)
					-get_stratified_coxph_hessian_cpp(X_fit, y, dead, strata, beta)
				},
				fisher_information = function(fit){
					beta = as.numeric(fit$coefficients %||% fit$b)
					-get_stratified_coxph_hessian_cpp(X_fit, y, dead, strata, beta)
				},
				information = function(fit){
					beta = as.numeric(fit$coefficients %||% fit$b)
					-get_stratified_coxph_hessian_cpp(X_fit, y, dead, strata, beta)
				},
				neg_loglik = function(fit) as.numeric(fit$neg_ll %||% fit$neg_loglik)
			)
		},
		get_standard_error = function(){
			private$shared_combined_likelihood()
			as.numeric(private$cached_values$s_beta_hat_T)
		},
		get_degrees_of_freedom = function() Inf,
		supports_lik_ratio_param_bootstrap = function() TRUE,
		simulate_under_lik_null = function(spec, delta, null_fit){
			b_null = as.numeric(null_fit$coefficients %||% null_fit$b)
			if (!all(is.finite(b_null))) return(NULL)
			X_fit = spec$X
			y_obs = as.numeric(spec$y)
			dead_obs = as.numeric(spec$dead)
			strata = as.integer(spec$strata)
			j = spec$j
			sim = .cox_simulate_stratified(y_obs, dead_obs, X_fit, b_null, strata)
			y_sim = sim$y_sim; dead_sim = sim$dead_sim
			if (!all(is.finite(y_sim)) || any(y_sim <= 0)) return(NULL)
			full_res = tryCatch(
				fast_stratified_coxph_regression_cpp(
					X = X_fit, y = y_sim, dead = dead_sim, strata = strata,
					estimate_only = FALSE,
					optimization_alg = private$optimization_alg
				),
				error = function(e) NULL
			)
			if (is.null(full_res) || !isTRUE(full_res$converged) || !is.finite(full_res$coefficients[j])) return(NULL)
			full_fit_boot = list(b = as.numeric(full_res$coefficients), neg_loglik = as.numeric(full_res$neg_ll))
			list(
				full_fit = full_fit_boot,
				fit_null = function(d, start = NULL){
					if (ncol(X_fit) == 1L) return(kk_cox_fully_fixed_null_fit(X_fit, y_sim, dead_sim, strata, d))
					res = tryCatch(
						fast_stratified_coxph_regression_cpp(
							X = X_fit, y = y_sim, dead = dead_sim, strata = strata,
							warm_start_beta = start %||% as.numeric(full_res$coefficients),
							fixed_idx = j, fixed_values = d,
							estimate_only = FALSE,
							optimization_alg = private$optimization_alg
						),
						error = function(e) NULL
					)
					if (is.null(res) || !isTRUE(res$converged)) return(NULL)
					list(b = as.numeric(res$coefficients), neg_loglik = as.numeric(res$neg_ll))
				},
				neg_loglik = function(fit) as.numeric(fit$neg_loglik %||% fit$neg_ll)
			)
		}
	)
)

#' Stratified Cox Combined-Likelihood Compound Inference for KK Designs
#'
#' Fits a single combined partial likelihood for KK matching-on-the-fly designs
#' with survival responses: matched pairs contribute a stratified Cox term (one
#' stratum per pair, canceling shared-frailty effects within the pair) and
#' reservoir subjects contribute a standard unstratified Cox term, summed into
#' one joint partial log-likelihood and optimized jointly for a single shared
#' treatment coefficient. This differs from the two-stage IVWC sibling
#' \code{\link[EDI:InferenceSurvivalKKStratCoxPHIVWC]{InferenceSurvivalKKStratCoxPHIVWC}},
#' which fits the matched and reservoir sub-models separately and combines the
#' two log-hazard-ratio estimates by inverse-variance weighting; this class
#' instead estimates one coefficient from the combined likelihood directly,
#' which additionally supports likelihood-ratio tests and parametric
#' likelihood bootstrap (\code{likelihood_tier = "partial"}).
#' @references
#' Cox, D. R. (1972). "Regression Models and Life-Tables." Journal of the
#' Royal Statistical Society, Series B, 34(2), 187-220.
#'
#' Lee, E. W., Wei, L. J., Amato, D. A., and Leurgans, S. (1992). "Cox-Type Regression
#' Analysis for Large Numbers of Small Groups of Correlated Failure Time
#' Observations." In Survival Analysis: State of the Art, 237-247. Springer.
#' \doi{10.1007/978-94-015-7983-4_14}
#' @eval rd_small_sample_section("InferenceSurvivalKKStratCoxPHOneLik")
#' @export
# Migrated 2026-08-18 (fix_inference_hierarchy.md "Partial-Likelihood
# Estimators" / "KK And IVWC Estimators"): see
# SurvivalKKStratCoxOneLikPartialLikelihoodSource above.
InferenceSurvivalKKStratCoxPHOneLik = define_inference_class(
	classname = "InferenceSurvivalKKStratCoxPHOneLik",
	inherit = Inference,
	components = c(
		"RandomizationCI",
		"RandomizationBootstrapCI",
		"BayesianBootstrap",
		"Jackknife",
		"SurvivalKKStratCoxOneLikPartialLikelihood"
	),
	public = list(
		# Pinned from InferenceRand -- same flattened-super$ rationale as every
		# other survival/count KK migration this stretch.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	),
	metadata = list(likelihood_tier = "partial"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"initialize",
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"approximate_bootstrap_distribution_beta_hat_T",
			"get_supported_testing_types", "set_testing_type"
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
			"supports_likelihood_tests",
			"supports_lik_ratio_param_bootstrap",
			"simulate_under_lik_null",
			"get_likelihood_test_spec",
			"design_matrix_candidates",
			"shared_combined_likelihood",
			"max_abs_reasonable_coef",
			"optimization_alg",
			"supports_information_preference",
			"supports_observed_information",
			"get_supported_information_preferences_impl",
			"supports_bartlett_likelihood_ratio_approx",
			"get_bartlett_factor_approx"
		)
	)
)

#' @R6method InferenceSurvivalKKStratCoxPHOneLik$approximate_randomization_distribution_beta_hat_T
#' @template rand-approx-distribution-beta-hat-t
NULL

#' @R6method InferenceSurvivalKKStratCoxPHOneLik$supports_rand_pval_for_incidence
#' @template rand-supports-pval-incidence
NULL

#' @R6method InferenceSurvivalKKStratCoxPHOneLik$compute_rand_two_sided_pval
#' @template rand-compute-rand-two-sided-pval-params
NULL

