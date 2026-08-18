#' Abstract class for Survival Rank-based Regression (AFT) Compound Inference
#'
#' This class implements a robust compound estimator for KK matching-on-the-fly
#' designs with survival responses using rank-based estimating equations via the
#' \pkg{aftgee} package. For matched pairs, it fits a rank-based AFT model with
#' clustering. For reservoir subjects, it fits a standard rank-based AFT model.
#' The two estimates (both log-time ratios) are combined via a variance-weighted
#' linear combination.
#'
#' @details
#' This class requires the \pkg{aftgee} package. Under \code{harden = TRUE},
#' multivariate component fits preserve the treatment column and retry reduced
#' covariate sets after QR-based rank reduction and correlation-based pruning.
#' Extreme finite coefficients / standard errors are rejected and treated as
#' non-estimable.
#'
#' @keywords internal
# Static leaf source (2026-08-18 migration, fix_inference_hierarchy.md "KK And
# IVWC Estimators"): this file previously defined the abstract base
# `InferenceAbstractKKSurvivalRankRegrIVWC` on
# `InferenceKKPassThroughCompoundNoParamBootstrap`, whose ONLY descendant was
# the thin concrete leaf `InferenceSurvivalKKRankRegrIVWC`
# (inference_survival_KK_rank_regr.R: a delegating initialize plus a
# build_design_matrix helper that nothing in this estimator chain ever calls).
# Abstract + leaf are merged into this single static source; the factory call
# lives in the concrete file (which Collates after this one). The abstract's
# `eval(body(InferenceMixinKKPassThrough$public$approximate_bootstrap_
# distribution_beta_hat_T))` override was dropped as a verified no-op: the
# compound ladder's inline public list only defines initialize and
# compute_estimate_with_bootstrap_weights, so the ladder inherited exactly
# that same KKPassThrough body anyway, with or without the override.
SurvivalKKRankRegrIVWCSource = list(
	public = list(
		#' @description Initialize KK survival rank-regression IVWC inference and
		#'   prepare matched/reservoir Gehan-Wilcoxon rank-regression components used
		#'   by \code{\link[EDI:InferenceSurvivalKKRankRegrIVWC]{InferenceSurvivalKKRankRegrIVWC}}.
		#' @param des_obj  	A DesignSeqOneByOne object (must be a KK design).
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose  		Whether to print progress messages.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE){
			# The old abstract's initialize took a smart_cold_start_default
			# parameter, but the concrete leaf's delegating initialize never
			# exposed it, so it was always NULL; the merged signature keeps the
			# leaf's (public API) shape and pins NULL explicitly below.
			smart_cold_start_default = NULL
			res_type = des_obj$get_response_type()
			if (should_run_asserts()) {
				if (res_type == "incidence"){
					stop("Rank-based regression is not recommended for incidence data; clogit and compound mean diff is recommended.")
				}
			}
			if (should_run_asserts()) {
				assertResponseType(res_type, "survival")
			}
			super$initialize(des_obj = des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				if (!check_package_installed("aftgee")) {
					stop("Package 'aftgee' is required for ", class(self)[1], ". Please install it.")
				}
			}
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
			if (should_run_asserts()) {
				private$assert_finite_se()
			}
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Compute the survival rank-regression asymptotic p-value for
		#'   the treatment effect using the fitted rank-regression estimate and
		#'   standard error. See \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param delta                                   The null difference to test against. For
		#'   any treatment effect at all this is set to zero (the default).
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta)
			}
			private$shared()
			if (should_run_asserts()) {
				private$assert_finite_se()
			}
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
		is_a_kk_survival_rank_regr_ivwc = function() TRUE,
		# Inherited verbatim from the old concrete leaf (inference_survival_KK_
		# rank_regr.R). Nothing in this estimator chain calls it -- the aftsrr
		# fits build their design matrices via aft_design_candidates() -- but it
		# is preserved for byte-identical surface with the legacy class.
		build_design_matrix = function(){
			X_cov = private$X
			if (is.null(X_cov) || ncol(X_cov) == 0) {
				X = cbind(`(Intercept)` = 1, treatment = private$w)
			} else {
				X = cbind(`(Intercept)` = 1, treatment = private$w, X_cov)
			}
			X
		},
		best_X_colnames_matched = NULL,
		best_X_colnames_reservoir = NULL,
		max_abs_reasonable_coef = 1e4,
		compute_basic_match_data = function() private$compute_basic_kk_match_data_impl(),
		# Ladder of design-matrix candidates for the aftsrr fits: the full hardened-QR
		# matrix first, then versions with increasingly aggressive correlated-column
		# dropping. (Reinstated: this helper was removed in the model_formula refactor
		# while its call sites in aftsrr_for_matched_pairs/_reservoir remained.)
		aft_design_candidates = function(w, X, cache_key = "default"){
			cache_name = paste0("rank_regr_design_candidates_", cache_key)
			if (!is.null(private$cached_values[[cache_name]])) {
				return(private$cached_values[[cache_name]])
			}
			X_full = cbind(w = w, X)

			# Standard candidate: all covariates
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
				X_try = cbind(w = w, X_cov)
				attempt_try = private$fit_with_hardened_qr_column_dropping(
					X_full = X_try,
					required_cols = 1L,
					fit_fun = function(X_fit) X_fit,
					fit_ok = function(mod, X_fit, keep) TRUE
				)
				key = paste(colnames(attempt_try$X), collapse = "|")
				if (!(key %in% keys)){
					candidates[[length(candidates) + 1L]] = attempt_try$X
					keys = c(keys, key)
				}
			}
			private$cached_values[[cache_name]] = candidates
			candidates
		},
		# Abstract: subclasses return TRUE (multivariate) or FALSE (univariate).
		extract_term_estimate = function(mod, term_name = "w"){
			coefs = tryCatch(stats::coef(mod), error = function(e) NULL)
			if (is.null(coefs) || is.null(names(coefs)) || !(term_name %in% names(coefs))){
				return(NA_real_)
			}
			as.numeric(coefs[[term_name]])
		},
		extract_term_se = function(mod, term_name = "w"){
			coef_table = tryCatch(summary(mod)$coefficients, error = function(e) NULL)
			if (is.null(coef_table)){
				return(NA_real_)
			}
			# aftsrr returns a list of matrices, aftgee returns a matrix
			tab = if (is.list(coef_table)) coef_table[[1]] else coef_table
			
			if (is.null(tab) || is.null(dim(tab))){
				return(NA_real_)
			}
			if (is.null(rownames(tab)) || !(term_name %in% rownames(tab))){
				return(NA_real_)
			}
			se_col = intersect(colnames(tab), c("StdErr", "Std.Err", "Std.err", "Std.Error"))[1]
			if (is.na(se_col) || length(se_col) == 0L){
				return(NA_real_)
			}
			as.numeric(tab[term_name, se_col])
		},
		shared = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			if (!is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			private$clear_nonestimable_state()
			KKstats = private$cached_values$KKstats
			if (is.null(KKstats)) {
				private$compute_basic_match_data()
				KKstats = private$cached_values$KKstats
			}
			m   = KKstats$m
			nRT = KKstats$nRT
			nRC = KKstats$nRC
			# --- Matched pairs: aftsrr with clustering ---
			if (m > 0){
				private$aftsrr_for_matched_pairs(estimate_only = estimate_only)
			}
			beta_m   = private$cached_values$beta_T_matched
			ssq_m    = private$cached_values$ssq_beta_T_matched
			m_ok     = !is.null(beta_m) && is.finite(beta_m) &&
			           !is.null(ssq_m)  && is.finite(ssq_m) && ssq_m > 0
			# --- Reservoir: aftsrr (independent) ---
			if (nRT > 0 && nRC > 0){
				private$aftsrr_for_reservoir(estimate_only = estimate_only)
			}
			beta_r   = private$cached_values$beta_T_reservoir
			ssq_r    = private$cached_values$ssq_beta_T_reservoir
			r_ok     = !is.null(beta_r) && is.finite(beta_r) &&
			           !is.null(ssq_r)  && is.finite(ssq_r) && ssq_r > 0
			# --- Variance-weighted combination ---
			if (m_ok && r_ok){
				w_star = ssq_r / (ssq_r + ssq_m)
				private$cached_values$beta_hat_T   = w_star * beta_m + (1 - w_star) * beta_r
			if (estimate_only) return(invisible(NULL))
				private$cached_values$s_beta_hat_T = sqrt(ssq_m * ssq_r / (ssq_m + ssq_r))
			} else if (m_ok){
				private$cached_values$beta_hat_T   = beta_m
				private$cached_values$s_beta_hat_T = sqrt(ssq_m)
			} else if (r_ok){
				private$cached_values$beta_hat_T   = beta_r
				private$cached_values$s_beta_hat_T = sqrt(ssq_r)
			} else {
				private$cache_nonestimable_estimate("kk_rank_regr_ivwc_no_usable_component")
				return(invisible(NULL))
			}
			if (is.finite(private$cached_values$beta_hat_T) &&
			    abs(private$cached_values$beta_hat_T) > private$max_abs_reasonable_coef){
				private$cache_nonestimable_estimate("kk_rank_regr_ivwc_extreme_estimate")
				return(invisible(NULL))
			}
			if (!estimate_only &&
			    (!is.finite(private$cached_values$s_beta_hat_T) || private$cached_values$s_beta_hat_T <= 0 ||
			     private$cached_values$s_beta_hat_T > private$max_abs_reasonable_coef)){
				private$cache_nonestimable_se("kk_rank_regr_ivwc_standard_error_unavailable")
				return(invisible(NULL))
			}
			private$clear_nonestimable_state()
		},
		assert_finite_se = function(){
			if (!is.finite(private$cached_values$s_beta_hat_T)){
				return(invisible(NULL))
			}
		},
		# Copied verbatim from InferenceMLEorKMSummaryTable (the old ladder's
		# ancestor). Needed because shared() above early-returns whenever
		# beta_hat_T is already cached -- even from an estimate_only pass that
		# never computed the SE -- and the Wald component's own
		# get_standard_error() fallback stop()s on a missing SE, whereas the old
		# ladder's version (this one) calls shared() and then degrades to
		# NA_real_, which Wald-impl methods turn into NA CIs/p-values.
		get_standard_error = function(){
			private$shared(estimate_only = FALSE)
			se = private$cached_values$s_beta_hat_T
			if (is.null(se) || length(se) != 1L) NA_real_ else se
		},
		aftsrr_for_matched_pairs = function(estimate_only = FALSE){
			split = split_kk_matched_reservoir_idx(private$m, private$n)
			m_vec = split$m_vec
			i_matched = split$matched_idx
			y_m       = private$y[i_matched]
			dead_m    = private$dead[i_matched]
			w_m       = private$w[i_matched]
			strata_m  = m_vec[i_matched]
			# Filter strata that have no events (aftsrr needs at least some events)
			if (sum(dead_m) < 2) return(invisible(NULL))
			dat = data.frame(y = y_m, dead = dead_m, w = w_m, id = strata_m)
			formula_str = "survival::Surv(y, dead) ~ w"
			mod = NULL
			if (ncol(as.matrix(private$X)) > 0){
				X_m = as.matrix(private$get_X()[i_matched, , drop = FALSE])
				for (X_candidate in private$aft_design_candidates(w_m, X_m, cache_key = "matched")){
					dat_try = dat
					formula_try = formula_str
					X_covs = X_candidate[, colnames(X_candidate) != "w", drop = FALSE]
					if (ncol(X_covs) > 0){
						colnames(X_covs) = paste0("x", seq_len(ncol(X_covs)))
						dat_try = cbind(dat_try[, c("y", "dead", "w", "id")], X_covs)
						formula_try = paste(formula_try, "+", paste(colnames(X_covs), collapse = " + "))
					}
					se_method = if (estimate_only) "NULL" else "ISMB"
					mod_try = tryCatch({
						suppressMessages(aftgee::aftsrr(as.formula(formula_try), id = id, data = dat_try, se = se_method, B = 0))
					}, error = function(e) NULL)
					beta_try = private$extract_term_estimate(mod_try, "w")
					se_try = if (estimate_only) 1 else private$extract_term_se(mod_try, "w")
					if (is.finite(beta_try) && abs(beta_try) <= private$max_abs_reasonable_coef &&
					    (estimate_only || (is.finite(se_try) && se_try > 0 && se_try <= private$max_abs_reasonable_coef))){
						mod = mod_try
						break
					}
				}
			} else {
				mod = tryCatch({
					se_method = if (estimate_only) "NULL" else "ISMB"
					suppressMessages(aftgee::aftsrr(as.formula(formula_str), id = id, data = dat, se = se_method, B = 0))
				}, error = function(e) NULL)
			}
			if (is.null(mod)) return(invisible(NULL))
			beta = private$extract_term_estimate(mod, "w")
			se   = if (estimate_only) NA_real_ else private$extract_term_se(mod, "w")
			private$cached_values$beta_T_matched     = if (is.finite(beta) && abs(beta) <= private$max_abs_reasonable_coef) beta else NA_real_
			private$cached_values$ssq_beta_T_matched = if (!estimate_only && is.finite(se) && se > 0 && se <= private$max_abs_reasonable_coef) se^2 else NA_real_
		},
		aftsrr_for_reservoir = function(estimate_only = FALSE){
			KKstats = private$cached_values$KKstats
			y_r    = KKstats$y_reservoir
			w_r    = KKstats$w_reservoir
			dead_r = private$dead[private$m == 0]
			X_r    = as.matrix(KKstats$X_reservoir)
			if (sum(dead_r) < 2) return(invisible(NULL))
			dat = data.frame(y = y_r, dead = dead_r, w = w_r)
			formula_str = "survival::Surv(y, dead) ~ w"
			mod = NULL
			if (ncol(as.matrix(private$X)) > 0){
				for (X_candidate in private$aft_design_candidates(w_r, X_r, cache_key = "reservoir")){
					dat_try = dat
					formula_try = formula_str
					X_covs = X_candidate[, colnames(X_candidate) != "w", drop = FALSE]
					if (ncol(X_covs) > 0){
						colnames(X_covs) = paste0("x", seq_len(ncol(X_covs)))
						dat_try = cbind(dat_try[, c("y", "dead", "w")], X_covs)
						formula_try = paste(formula_try, "+", paste(colnames(X_covs), collapse = " + "))
					}
					se_method = if (estimate_only) "NULL" else "ISMB"
					mod_try = tryCatch({
						suppressMessages(aftgee::aftsrr(as.formula(formula_try), data = dat_try, se = se_method, B = 0))
					}, error = function(e) NULL)
					beta_try = private$extract_term_estimate(mod_try, "w")
					se_try = if (estimate_only) 1 else private$extract_term_se(mod_try, "w")
					if (is.finite(beta_try) && abs(beta_try) <= private$max_abs_reasonable_coef &&
					    (estimate_only || (is.finite(se_try) && se_try > 0 && se_try <= private$max_abs_reasonable_coef))){
						mod = mod_try
						break
					}
				}
			} else {
				mod = tryCatch({
					se_method = if (estimate_only) "NULL" else "ISMB"
					suppressMessages(aftgee::aftsrr(as.formula(formula_str), data = dat, se = se_method, B = 0))
				}, error = function(e) NULL)
			}
			if (is.null(mod)) return(invisible(NULL))
			beta = private$extract_term_estimate(mod, "w")
			se   = if (estimate_only) NA_real_ else private$extract_term_se(mod, "w")
			private$cached_values$beta_T_reservoir     = if (is.finite(beta) && abs(beta) <= private$max_abs_reasonable_coef) beta else NA_real_
			private$cached_values$ssq_beta_T_reservoir = if (!estimate_only && is.finite(se) && se > 0 && se <= private$max_abs_reasonable_coef) se^2 else NA_real_
		}
	)
)

KKSurvivalRankRegressionSource = list(
	public = list(),
	private = list(
		kk_survival_rank_design_candidates = function(w, X, cache_key = "default") {
			private$aft_design_candidates(w, X, cache_key = cache_key)
		},
		kk_survival_rank_extract_term_estimate = function(mod, term_name = "w") {
			private$extract_term_estimate(mod, term_name = term_name)
		},
		kk_survival_rank_extract_term_se = function(mod, term_name = "w") {
			private$extract_term_se(mod, term_name = term_name)
		},
		kk_survival_rank_shared = function(estimate_only = FALSE) {
			private$shared(estimate_only = estimate_only)
		},
		kk_survival_rank_assert_finite_se = function() {
			private$assert_finite_se()
		},
		kk_survival_rank_aftsrr_for_matched_pairs = function(estimate_only = FALSE) {
			private$aftsrr_for_matched_pairs(estimate_only = estimate_only)
		},
		kk_survival_rank_aftsrr_for_reservoir = function(estimate_only = FALSE) {
			private$aftsrr_for_reservoir(estimate_only = estimate_only)
		}
	)
)
