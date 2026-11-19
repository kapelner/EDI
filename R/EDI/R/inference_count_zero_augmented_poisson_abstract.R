#' Zero-Augmented Poisson Inference for Count Responses
#'
#' Internal base class for non-KK zero-inflated and hurdle Poisson regression
#' models fit using the \pkg{glmmTMB} fitter. The reported treatment effect is the
#' treatment coefficient from the conditional count component, on the log-rate
#' scale, \strong{conditional on the response coming from the count process, not
#' the structural/excess-zero mechanism}: it is not, and should not be read as,
#' the effect on the unconditional mean \eqn{E[Y]}, which also depends on how
#' treatment shifts the zero-inflation/hurdle probability. A design where
#' treatment shifts only the excess-zero probability, with no change in the
#' conditional count rate, will report a null treatment coefficient here even
#' though \eqn{E[Y]} changed. A marginal (unconditional-mean) estimand is not
#' yet implemented for the negative-binomial variants (see \code{marginal_estimand_report.md}).
#'
#' Count-part covariates aliased on the subjects with a positive count are
#' dropped before every fit, the same as what \code{\link[stats]{glm}} does with
#' aliased columns (v1.0.6-TODO-195; see
#' \code{zero_augmented_drop_aliased_count_cols()} and the concrete classes'
#' "Aliased count-part covariates" paragraph). The treatment is never dropped.
#'
#' @keywords internal
#' @noRd
ZeroAugmentedCountLikelihoodSource = list(
	public = list(
				
		#' @description Initialize zero-augmented count-likelihood inference, prepare
		#'   the conditional count and zero/hurdle auxiliary model formulas, and set
		#'   up the shared \code{\link[EDI:InferenceCountLikelihood]{InferenceCountLikelihood}}
		#'   likelihood-test machinery.
		#' @param des_obj A completed \code{Design} object.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param model_formula_zero Formula for the zero/hurdle auxiliary component.
		#'   If \code{NULL} (default), the auxiliary component uses the same formula as
		#'   the conditional count component.
		#' @param use_rcpp Whether to use Rcpp speedup.
		#' @param verbose Whether to print progress messages.
		#' @param optimization_alg  Optimization algorithm to use. Default is dispatched via policy.
		initialize = function(des_obj, model_formula = NULL, model_formula_zero = NULL, use_rcpp = TRUE, verbose = FALSE, smart_cold_start_default = NULL, optimization_alg = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "count")
				assertFormula(model_formula, null.ok = TRUE)
				assertFormula(model_formula_zero, null.ok = TRUE)
				assertFlag(use_rcpp)
			}
			self$set_optimization_alg(optimization_alg, allow_irls = FALSE)
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (is.null(model_formula_zero)) {
				model_formula_zero = private$model_formula
			}
			if (should_run_asserts()) {
				assertFormula(model_formula_zero, null.ok = FALSE)
			}
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
			if (should_run_asserts() && !use_rcpp) {
				if (!check_package_installed("glmmTMB")){
					stop("Package 'glmmTMB' is required for ", class(self)[1], " when use_rcpp = FALSE. Please install it.")
				}
			}
			
			
			private$use_rcpp = use_rcpp
			private$model_formula_zero = model_formula_zero
			# 2026-11-04: a zero-inflated mixture needs zeros -- with none, the
			# structural-zero probability's MLE is pi = 0 (logits at -Inf) and the
			# zero-inflation submodel is not identified (pscl::zeroinfl() refuses the
			# same data). Refuse up front on the user's data; resampled data are
			# handled by zero_inflation_fixed_args() instead (non-inflated fit).
			if (private$zero_inflation_is_unidentified(private$y)) {
				stop(class(self)[1L], ": the response has no zeros, so the zero-inflation submodel is not identified ",
					"(its maximum-likelihood structural-zero probability is 0). Use ",
					if (grepl("Negative Binomial", private$za_description())) "InferenceCountNegBin" else "InferenceCountPoisson",
					" instead.", call. = FALSE)
			}
		},
		#' @description Compute the zero-augmented count-model asymptotic confidence
		#'   interval for the conditional treatment coefficient, with bootstrap
		#'   fallback when a stable model standard error is unavailable. See
		#'   \code{\link[EDI:InferenceCountLikelihood]{InferenceCountLikelihood}}.
		#' @param alpha The significance level (default 0.05).
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
			}
			if (private$mark_count_likelihood_block_asymp_nonestimable()) {
				return(private$count_likelihood_missing_ci(alpha))
			}
			private$shared()
			se = private$get_standard_error()
			if (is.finite(se) && se > 0) {
				private$cached_values$s_beta_hat_T = se
			}
			if (!is.finite(private$cached_values$s_beta_hat_T) || private$cached_values$s_beta_hat_T <= 0){
				# 2026-09-18: the bootstrap fallback below is itself unavailable on a
				# KK21stepwise/SPBR design (apply_inference_design_restrictions()
				# stubs compute_bootstrap_confidence_interval() to stop() on any
				# non-Bernoulli DesignSeqOneByOne design) -- checking first avoids
				# that unrelated design-restriction error leaking through and being
				# misread as "asymp itself is unsupported" (found via a
				# comprehensive_tests results audit).
				if (!("nonparametric_bootstrap" %in% self$capabilities())) {
					return(private$count_likelihood_missing_ci(alpha))
				}
				warning(private$za_description(), ": falling back to bootstrap because standard error is unavailable.")
				return(private$count_bootstrap_fallback_ci(alpha))
			}
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Compute the zero-augmented count-model asymptotic two-sided
		#'   p-value for the conditional treatment coefficient, with bootstrap
		#'   fallback when a stable model standard error is unavailable. See
		#'   \code{\link[EDI:InferenceCountLikelihood]{InferenceCountLikelihood}}.
		#' @param delta The null treatment effect (default 0).
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta, len = 1, finite = TRUE, any.missing = FALSE)
			}
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(NA_real_)
			private$shared()
			se = private$get_standard_error()
			if (is.finite(se) && se > 0) {
				private$cached_values$s_beta_hat_T = se
			}
			if (!is.finite(private$cached_values$s_beta_hat_T) || private$cached_values$s_beta_hat_T <= 0){
				# See compute_asymp_confidence_interval()'s matching comment: the
				# bootstrap fallback is itself unavailable on this design.
				if (!("nonparametric_bootstrap" %in% self$capabilities())) {
					return(NA_real_)
				}
				warning(private$za_description(), ": falling back to bootstrap because standard error is unavailable.")
				return(private$count_bootstrap_fallback_pval(delta))
			}
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		},
		#' @description Recomputes the class-specific treatment estimate under bootstrap weights; see
		#'   \code{\link[EDI:InferenceBayesianBootstrap]{InferenceBayesianBootstrap}}.
		#' @param subject_or_block_weights Bootstrap weights at the subject or block level.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			if (!check_package_installed("glmmTMB")) {
				stop(class(self)[1], " weighted bootstrap estimation requires package 'glmmTMB'.")
			}
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			X_fit = private$build_component_matrix(private$model_formula, private$best_X_colnames, treatment_name = "w")
			if (is.null(X_fit)) {
				private$cache_nonestimable_estimate("zero_augmented_poisson_design_unusable")
				return(NA_real_)
			}
			Xzi_fit = private$build_component_matrix(private$model_formula_zero, private$best_Xzi_colnames, treatment_name = "w")
			if (is.null(Xzi_fit)) {
				private$cache_nonestimable_estimate("zero_augmented_poisson_aux_design_unusable")
				return(NA_real_)
			}
			# v1.0.6-TODO-195 (2): same aliased-column drop as the full fit, on the
			# rows with positive weight.
			X_fit = edi_zero_augmented_drop_aliased_count_cols(self, private, X_fit, weights = row_weights)
			# v1.0.6-TODO-186: see zero_augmented_count_treatment_identified().
			if (!zero_augmented_count_treatment_identified(X_fit, private$y, j_treat = 2L, weights = row_weights)) {
				private$cache_nonestimable_estimate("zero_augmented_count_treatment_unidentified")
				return(NA_real_)
			}
			# v1.0.6-TODO-195 (3): no finite hurdle count-part treatment MLE on the
			# rows with positive weight.
			if (identical(private$za_description(), "Hurdle Poisson") &&
				zero_augmented_count_mle_infinite(X_fit, private$y, j_treat = 2L, weights = row_weights)) {
				private$cache_nonestimable_estimate("hurdle_count_mle_not_finite")
				return(NA_real_)
			}
			dat = private$build_component_frame(X_fit, Xzi_fit)
			mod = private$fit_zero_augmented_model(dat, X_fit, Xzi_fit, weights = row_weights)
			if (is.null(mod)) {
				private$cache_nonestimable_estimate("zero_augmented_poisson_weighted_fit_unavailable")
				return(NA_real_)
			}
			cond_coef = tryCatch(glmmTMB::fixef(mod)$cond, error = function(e) NULL)
			if (is.null(cond_coef) || !("w" %in% names(cond_coef)) || !is.finite(cond_coef["w"])) {
				private$cache_nonestimable_estimate("zero_augmented_poisson_weighted_treatment_missing")
				return(NA_real_)
			}
			private$clear_nonestimable_state()
			private$cached_mod = mod
			private$cached_values$likelihood_test_context = NULL
			private$cached_values$beta_hat_T = as.numeric(cond_coef["w"])
			# Fixed 2026-09-07: glmmTMB::glmmTMB() is called with no
			# se=FALSE/sdreport=FALSE override, so it already computes its
			# full sdreport (Hessian-based vcov) for this weighted fit -- the
			# unweighted sibling path further below (generate_mod(),
			# ~line 1353-1354) already extracts the SE this exact way from the
			# identical kind of fit; this weighted path just never did,
			# starving the Bayesian-bootstrap studentized/BCa variants of a
			# per-replicate SE.
			se = NA_real_
			if (!estimate_only) {
				coef_table = tryCatch(summary(mod)$coefficients$cond, error = function(e) NULL)
				se = if (!is.null(coef_table) && ("w" %in% rownames(coef_table))) as.numeric(coef_table["w", "Std. Error"]) else NA_real_
			}
			private$cached_values$s_beta_hat_T = if (is.finite(se) && se > 0) se else NA_real_
			private$cached_values$df = NA_real_
			private$cached_values$full_coefficients = cond_coef
			private$cached_values$beta_hat_T
		},
		#' @description Zero-augmented mixture fits are too unstable under delete-one
		#'   refits for jackknife inference; report explicit non-estimability.
		compute_jackknife_estimate = function(unit = "auto"){
			private$signal_unsupported_procedure("zero_augmented_poisson_jackknife_not_supported")
			NA_real_
		},
		compute_jackknife_bias_estimate = function(unit = "auto"){
			private$signal_unsupported_procedure("zero_augmented_poisson_jackknife_not_supported")
			NA_real_
		},
		compute_jackknife_std_error = function(unit = "auto"){
			private$signal_unsupported_procedure("zero_augmented_poisson_jackknife_not_supported")
			NA_real_
		},
		compute_jackknife_wald_two_sided_pval = function(delta = 0, unit = "auto"){
			private$signal_unsupported_procedure("zero_augmented_poisson_jackknife_not_supported")
			NA_real_
		},
		compute_jackknife_wald_confidence_interval = function(alpha = 0.05, unit = "auto"){
			private$signal_unsupported_procedure("zero_augmented_poisson_jackknife_not_supported")
			ci = c(NA_real_, NA_real_)
			names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
			ci
		},
		#' @description Nonparametric-bootstrap two-sided p-value; see
		#'   \code{\link[EDI:InferenceNonParamBootstrap]{InferenceNonParamBootstrap}}.
		#' @param delta Null treatment-effect value. Default 0.
		#' @param B Number of bootstrap replicates. Default 501.
		#' @param type Bootstrap p-value type; \code{"bca"} is not supported here
		#'   (it needs jackknife refits) and returns \code{NA}.
		#' @param na.rm Whether to drop non-finite replicates. Default \code{TRUE}.
		#' @param show_progress A flag indicating whether a progress bar should be displayed.
		#' @param min_number_usable_samples Minimum number of finite replicates. Default 5.
		#' @param min_fraction_usable_samples Minimum fraction of the \code{B} replicates that must
		#'   be finite when \code{na.rm = TRUE}. Default 0.95; below it the p-value is \code{NA} with reason
		#'   \code{"bootstrap_too_few_valid_replicates_fraction"}. \code{0} turns the check off.
		compute_bootstrap_two_sided_pval = function(delta = 0, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L, min_fraction_usable_samples = 0.95){
			if (!is.null(type) && identical(tolower(type), "bca")) {
				private$signal_unsupported_procedure("zero_augmented_poisson_jackknife_not_supported")
				return(NA_real_)
			}
			private$nonparam_boot_compute_bootstrap_two_sided_pval(delta = delta, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, min_fraction_usable_samples = min_fraction_usable_samples)
		},
		compute_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L){
			if (!is.null(type) && identical(tolower(type), "bca")) {
				private$signal_unsupported_procedure("zero_augmented_poisson_jackknife_not_supported")
				ci = c(NA_real_, NA_real_)
				names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
				return(ci)
			}
			private$nonparam_boot_compute_bootstrap_confidence_interval(alpha = alpha, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples)
		},
		#' @description Bayesian-bootstrap two-sided p-value; see
		#'   \code{\link[EDI:InferenceBayesianBootstrap]{InferenceBayesianBootstrap}}.
		#' @param delta Null treatment-effect value. Default 0.
		#' @param B Number of bootstrap replicates. Default 501.
		#' @param type Bootstrap p-value type; \code{"bca"} is not supported here
		#'   (it needs jackknife refits) and returns \code{NA}.
		#' @param na.rm Whether to drop non-finite replicates. Default \code{TRUE}.
		#' @param show_progress A flag indicating whether a progress bar should be displayed.
		#' @param min_number_usable_samples Minimum number of finite replicates. Default 5.
		#' @param min_fraction_usable_samples Minimum fraction of the \code{B} replicates that must
		#'   be finite when \code{na.rm = TRUE}. Default 0.95; below it the p-value is \code{NA} with reason
		#'   \code{"bootstrap_too_few_valid_replicates_fraction"}. \code{0} turns the check off.
		#' @param weighting_unit_type Weighting unit; see
		#'   \code{\link[EDI:InferenceBayesianBootstrap]{InferenceBayesianBootstrap}}.
		compute_bayesian_bootstrap_two_sided_pval = function(delta = 0, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL, min_fraction_usable_samples = 0.95){
			if (!is.null(type) && identical(tolower(type), "bca")) {
				private$signal_unsupported_procedure("zero_augmented_poisson_jackknife_not_supported")
				return(NA_real_)
			}
			private$bayesian_boot_compute_bayesian_bootstrap_two_sided_pval(delta = delta, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type, min_fraction_usable_samples = min_fraction_usable_samples)
		},
		compute_bayesian_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL){
			if (!is.null(type) && identical(tolower(type), "bca")) {
				private$signal_unsupported_procedure("zero_augmented_poisson_jackknife_not_supported")
				ci = c(NA_real_, NA_real_)
				names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
				return(ci)
			}
			private$bayesian_boot_compute_bayesian_bootstrap_confidence_interval(alpha = alpha, B = B, type = type, na.rm = na.rm, show_progress = show_progress, min_number_usable_samples = min_number_usable_samples, weighting_unit_type = weighting_unit_type)
		}
	),
	private = list(
		is_a_count_zero_augmented_poisson = function() TRUE,
		# Pinned from their real source generators: composed classes have no
		# real super$ chain, so the 4 super$compute_bootstrap_*/
		# compute_bayesian_bootstrap_* calls above are replaced with calls to
		# these -- the real, self-contained implementations, pinned under
		# non-colliding private names (same pattern used throughout this
		# migration, e.g. InferenceSurvivalDepCensTransformRegr's
		# nonparam_boot_compute_bootstrap_confidence_interval pin).
		nonparam_boot_compute_bootstrap_two_sided_pval = InferenceNonParamBootstrap$public_methods$compute_bootstrap_two_sided_pval,
		nonparam_boot_compute_bootstrap_confidence_interval = InferenceNonParamBootstrap$public_methods$compute_bootstrap_confidence_interval,
		bayesian_boot_compute_bayesian_bootstrap_two_sided_pval = InferenceBayesianBootstrap$public_methods$compute_bayesian_bootstrap_two_sided_pval,
		bayesian_boot_compute_bayesian_bootstrap_confidence_interval = InferenceBayesianBootstrap$public_methods$compute_bayesian_bootstrap_confidence_interval,
		supports_reusable_bootstrap_worker = function(){
			TRUE
		},
		# Override the generic design-backed worker to freeze best_X_colnames /
		# best_Xzi_colnames in the worker state.  load_bootstrap_sample_into_design_backed_worker
		# clears best_X_colnames (line 855) which would force a full design-reduction on every
		# BRT draw — saving and restoring it here skips that and goes straight to the C++ fit.
		create_bootstrap_worker_state = function(){
			ws = private$create_design_backed_bootstrap_worker_state()
			ws$base_best_X_colnames   = private$best_X_colnames
			ws$base_best_Xzi_colnames = private$best_Xzi_colnames
			ws
		},
		load_bootstrap_sample_into_worker = function(worker_state, indices){
			private$load_bootstrap_sample_into_design_backed_worker(worker_state, indices)
			worker_state$worker_priv$best_X_colnames   = worker_state$base_best_X_colnames
			worker_state$worker_priv$best_Xzi_colnames = worker_state$base_best_Xzi_colnames
		},
		compute_bootstrap_worker_estimate = function(worker_state){
			private$compute_bootstrap_worker_estimate_via_compute_treatment_estimate(worker_state)
		},
			cached_mod = NULL,
			za_X_cov_all = NULL,
			za_Xzi_cov_all = NULL,
			record_zero_augmented_fit_summary = function(fit, X_full, Xzi_full, X_fit, Xzi_fit, is_hurdle = FALSE){
				cond_full_names = colnames(X_full)
				aux_full_names = colnames(Xzi_full)
				cond_fit_names = colnames(X_fit)
				aux_fit_names = colnames(Xzi_fit)
				params = as.numeric(fit$params %||% c(as.numeric(fit$coefficients$cond), as.numeric(fit$coefficients$zi)))
				if (length(params) < length(cond_fit_names) + length(aux_fit_names)) return(invisible(NULL))
				cond_fit = params[seq_along(cond_fit_names)]
				aux_fit = params[length(cond_fit_names) + seq_along(aux_fit_names)]
				
				cond_full = rep(NA_real_, length(cond_full_names))
				names(cond_full) = cond_full_names
				aux_full = rep(NA_real_, length(aux_full_names))
				names(aux_full) = aux_full_names
				cond_full[match(cond_fit_names, cond_full_names)] = cond_fit
				aux_full[match(aux_fit_names, aux_full_names)] = aux_fit
				
				coef_all = c(cond_full, aux_full)
				row_names = c(
					paste0("conditional:", names(cond_full)),
					paste0(if (isTRUE(is_hurdle)) "hurdle:" else "zero:", names(aux_full))
				)
				se_all = rep(NA_real_, length(coef_all))
				vcov_fit = tryCatch({
					vc = fit$vcov %||% solve(as.matrix(fit$fisher_information))
					as.matrix(vc)
				}, error = function(e) NULL)
				if (!is.null(vcov_fit) && nrow(vcov_fit) >= length(cond_fit_names) + length(aux_fit_names)) {
					se_fit = sqrt(pmax(0, diag(vcov_fit)[seq_len(length(cond_fit_names) + length(aux_fit_names))]))
					se_cond = rep(NA_real_, length(cond_full_names))
					se_aux = rep(NA_real_, length(aux_full_names))
					se_cond[match(cond_fit_names, cond_full_names)] = se_fit[seq_along(cond_fit_names)]
					se_aux[match(aux_fit_names, aux_full_names)] = se_fit[length(cond_fit_names) + seq_along(aux_fit_names)]
					se_all = c(se_cond, se_aux)
				}
				
				summary_table = matrix(NA_real_, nrow = length(coef_all), ncol = 4L)
				rownames(summary_table) = row_names
				colnames(summary_table) = c("Value", "Std. Error", "z value", "Pr(>|z|)")
				summary_table[, 1L] = coef_all
				summary_table[, 2L] = se_all
				ok = is.finite(coef_all) & is.finite(se_all) & se_all > 0
				summary_table[ok, 3L] = coef_all[ok] / se_all[ok]
				summary_table[ok, 4L] = 2 * stats::pnorm(-abs(summary_table[ok, 3L]))
				
				private$cached_values$full_coefficients = cond_full
				private$cached_values$zero_coefficients = aux_full
				private$cached_values$summary_table = summary_table
				private$cached_values$model_fit_fallback = NULL
				invisible(NULL)
			},
			invalidate_likelihood_fit = function(reason){
			private$cached_mod = NULL
			private$cached_values$likelihood_test_context = NULL
			private$cache_nonestimable_estimate(reason)
			invisible(NULL)
		},
		get_standard_error = function(){
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(NA_real_)
			private$shared(estimate_only = FALSE)
			# Under a marginal estimand the information-matrix SE below is the
			# CONDITIONAL coefficient's, not the g-computation functional's:
			# report only the delta-method SE compute_estimate() cached (NA when
			# that is unavailable, e.g. a degenerate zero-inflation fit), so the
			# SE, CI and p-value agree on estimability.
			if (is.function(self$get_estimand) && self$get_estimand() %in% c("marginal_mean_diff", "marginal_ratio")) {
				self$compute_estimate(estimate_only = FALSE)
				se_marg = private$cached_values$s_beta_hat_T
				return(if (is.finite(se_marg) && se_marg > 0) se_marg else NA_real_)
			}
			se_cached = private$cached_values$s_beta_hat_T
			if (is.finite(se_cached) && se_cached > 0) return(se_cached)
			# 2026-09-24 (CI run 36047860251, R-CMD-check windows-latest release,
			# test-adversarial-and-fault-injection.R's "every y == 1" hurdle scenario):
			# zero_augmented_sandwich_se()/safe_zero_augmented_vcov_se() (already tried
			# via se_cached above, through compute_estimate()'s own SE computation) both
			# check zero_augmented_data_has_no_mle()/zero_augmented_fit_is_degenerate()
			# before accepting a SE, but compute_standard_error_from_information_matrix()
			# is a GENERIC fallback shared across unrelated inference classes with no
			# knowledge of that hurdle/ZIP-specific degeneracy -- it inverts the raw
			# information matrix directly, and whether that inversion happens to succeed
			# or fail (returning a spurious finite SE vs. correctly NA) is a
			# LAPACK/BLAS-backend detail confirmed to differ from this environment (this
			# fixture correctly returns NA/nonestimable on every local run) to CI's
			# Windows legs. zero_augmented_data_has_no_mle() is decided from the data
			# alone (every positive count under a hurdle equals 1), so this check itself
			# cannot vary by environment, unlike the generic fallback it now guards.
			if (zero_augmented_data_has_no_mle(private$y, identical(private$za_description(), "Hurdle Poisson"))) {
				return(NA_real_)
			}
			se = private$compute_standard_error_from_information_matrix()
			if (is.finite(se)) return(se)
			private$cached_values$s_beta_hat_T
		},
		get_degrees_of_freedom = function(){
			private$shared(estimate_only = FALSE)
			private$cached_values$df %||% NA_real_
		},
		safe_zero_augmented_vcov_se = function(fit, j_treat = 2L){
			v = tryCatch({
				vc = fit$vcov
				params_fit = as.numeric(fit$params %||% NA_real_)
				# 2026-10-22: a zero-INFLATED fit whose zero-inflation block alone
				# is unidentified (e.g. the zi treatment coefficient running to
				# -Inf because one arm has no excess zeros) used to have its whole
				# vcov rejected (rcond ~1e-12), discarding a perfectly estimable
				# count-model treatment SE (pscl/glmmTMB report it finite and equal
				# to the EDI inverse-information entry). Re-test degeneracy on the
				# count-coefficient (+ dispersion) sub-block only. Hurdle fits keep
				# the whole-matrix test (test-degenerate-fit-threshold-calibration).
				degenerate = is.null(vc) || length(dim(vc)) != 2L ||
					nrow(vc) < j_treat || ncol(vc) < j_treat ||
					zero_augmented_data_has_no_mle(private$y, identical(private$za_description(), "Hurdle Poisson")) ||
					zero_augmented_fit_is_degenerate(as.matrix(vc), params_fit)
				# cpp patch 07 (TODO-4 ZINB note): on a singular free information block the
				# kernel returns a pseudo-inverse covariance whose NON-identified
				# coordinates are NaN rows/columns. Then only the count(+theta) sub-block
				# must be finite (tested below by zero_augmented_fit_is_degenerate(), which
				# rejects non-finite input). Current kernels never emit the tag, so the
				# original all(is.finite(vc)) requirement is unchanged for them.
				covariance_type = if (is.list(fit)) fit$covariance_type else NULL
				pinv_identified = is.character(covariance_type) && length(covariance_type) == 1L &&
					covariance_type %in% c("pseudo_inverse_identified_coordinates", "pseudo_inverse_zero_inflation_unidentified",
						# TODO-169: boundary fits carry NaN rows for the pinned (zi / theta) block.
						"observed_conditional_on_poisson_boundary", "observed_conditional_on_zero_inflation_boundary")
				vc_finite_enough = !is.null(vc) && length(dim(vc)) == 2L && (all(is.finite(vc)) || pinv_identified)
				if (degenerate && vc_finite_enough &&
						!grepl("Hurdle", private$za_description(), fixed = TRUE)) {
					p_cond = length(fit$coefficients$cond)
					n_par = length(params_fit)
					if (p_cond >= j_treat && nrow(vc) == n_par && n_par > p_cond) {
						idx = seq_len(p_cond)
						# theta is pinned (NaN row) at the Poisson boundary, so leave it out.
						if (grepl("Negative Binomial", private$za_description(), fixed = TRUE) && !isTRUE(fit$dispersion_at_poisson_boundary)) idx = c(idx, n_par)
						degenerate = zero_augmented_fit_is_degenerate(as.matrix(vc)[idx, idx, drop = FALSE], params_fit)
					}
				}
				if (degenerate) {
					private$cached_values$fit_degenerate = TRUE
					NA_real_
				} else {
					as.numeric(vc[j_treat, j_treat])
				}
			}, error = function(e) NA_real_)
			if (is.finite(v) && v > .Machine$double.eps) sqrt(v) else NA_real_
		},
		best_X_colnames = NULL,
		best_Xzi_colnames = NULL,
		use_rcpp = TRUE,
		model_formula_zero = NULL,
		get_complexity_tier = function() "light",
		build_component_matrix = function(model_formula, selected_colnames = NULL, treatment_name = "treatment"){
			# Determine if this is the zero-inflation formula or conditional formula
			is_zero_formula = identical(model_formula, private$model_formula_zero)
			
			if (is_zero_formula) {
				if (is.null(private$za_Xzi_cov_all)) {
					if (identical(model_formula, ~ .)) {
						X_cov_all = private$get_X()
					} else {
						X_imp = private$des_obj$get_X_imp()
						X_cov_all = if (is.null(X_imp)) matrix(NA_real_, nrow = private$n, ncol = 0) else edi_drop_perfect_predictor_cols(private, create_model_matrix_from_features(model_formula, X_imp))  # v1.0.6-TODO-158
					}
					private$za_Xzi_cov_all = X_cov_all
				} else {
					X_cov_all = private$za_Xzi_cov_all
				}
			} else {
				if (is.null(private$za_X_cov_all)) {
					if (identical(model_formula, ~ .)) {
						X_cov_all = private$get_X()
					} else {
						X_imp = private$des_obj$get_X_imp()
						X_cov_all = if (is.null(X_imp)) matrix(NA_real_, nrow = private$n, ncol = 0) else edi_drop_perfect_predictor_cols(private, create_model_matrix_from_features(model_formula, X_imp))  # v1.0.6-TODO-158
					}
					private$za_X_cov_all = X_cov_all
				} else {
					X_cov_all = private$za_X_cov_all
				}
			}

			if (is.null(selected_colnames)) {
				X_cov = X_cov_all
				if (is.null(X_cov) || ncol(as.matrix(X_cov)) == 0L) {
					X_fit = cbind(1, private$w)
					colnames(X_fit) = c("(Intercept)", treatment_name)
					return(X_fit)
				}
				X_cov = as.matrix(X_cov)
				if (isTRUE(private$harden)) {
					X_cov = drop_highly_correlated_cols(X_cov, threshold = 0.999)$M
				}
				X_fit = cbind(1, private$w, X_cov)
				colnames(X_fit)[1:2] = c("(Intercept)", treatment_name)
				if (isTRUE(private$harden)) {
					res = drop_linearly_dependent_cols(X_fit)
					X_fit = res$M
					colnames(X_fit) = c("(Intercept)", treatment_name, colnames(X_cov))[res$js]
				}
				X_fit
			} else {
				if (is.null(X_cov_all) || length(selected_colnames) == 0L) {
					X_cov = matrix(NA_real_, nrow = private$n, ncol = 0)
				} else {
					X_cov = as.matrix(X_cov_all[, intersect(selected_colnames, colnames(X_cov_all)), drop = FALSE])
				}
				if (is.null(X_cov) || ncol(as.matrix(X_cov)) == 0L) {
					X_fit = cbind(1, private$w)
					colnames(X_fit) = c("(Intercept)", treatment_name)
					return(X_fit)
				}
				X_fit = cbind(1, private$w, as.matrix(X_cov))
				colnames(X_fit)[1:2] = c("(Intercept)", treatment_name)
				X_fit
			}
		},
		build_component_frame = function(X_cond, Xzi){
			dat = data.frame(y = private$y, w = private$w)
			if (ncol(X_cond) > 2L) {
				Xc = as.data.frame(X_cond[, -c(1, 2), drop = FALSE])
				names(Xc) = make.names(colnames(X_cond)[-c(1, 2)], unique = TRUE)
				dat = cbind(dat, Xc)
			}
			if (ncol(Xzi) > 2L) {
				Xz = as.data.frame(Xzi[, -c(1, 2), drop = FALSE])
				names(Xz) = make.names(colnames(Xzi)[-c(1, 2)], unique = TRUE)
				for (nm in names(Xz)) {
					if (!nm %in% names(dat)) dat[[nm]] = Xz[[nm]]
				}
			}
			dat
		},
		build_formula_from_matrix = function(X_fit, response = "y"){
			vars = colnames(X_fit)[-1]
			rhs = if (!length(vars)) "1" else paste(vars, collapse = " + ")
			if (is.null(response)) return(stats::as.formula(paste("~", rhs)))
			stats::as.formula(paste(response, "~", rhs))
		},
		# 2026-08-23 (marginal_estimand_report.md TODO-5): factored out of
		# zero_augmented_sandwich_se() (which used to compute the full
		# sandwich vcov and immediately throw away every entry but
		# [j_treat, j_treat]) so the marginal-estimand delta-method path can
		# reuse the exact same bread/meat construction against the FULL
		# matrix, rather than duplicating it. Poisson-family only (the score
		# formulas below assume a plain exp()-link Poisson/hurdle-Poisson
		# mean with no dispersion parameter) -- NOT valid for the NegBin
		# variants (ZINB/hurdle-NegBin), which is exactly why this plan's
		# TODO-5 wires the marginal estimand onto the two Poisson concretes
		# only and leaves NegBin for a follow-up pass with its own,
		# dispersion-aware score derivation.
		zero_augmented_poisson_sandwich_vcov_full = function(fit, X_fit, Xzi_fit, is_hurdle = FALSE){
			if (zero_augmented_data_has_no_mle(private$y, is_hurdle)) {
				private$cached_values$fit_degenerate = TRUE
				return(NULL)
			}
			params = as.numeric(fit$params %||% NA_real_)
			bread = tryCatch(as.matrix(fit$vcov), error = function(e) NULL)
			if (is.null(bread) || !length(params) || any(!is.finite(params))) return(NULL)
			total_p = ncol(X_fit) + ncol(Xzi_fit)
			if (length(params) != total_p || nrow(bread) != total_p || ncol(bread) != total_p ||
					any(!is.finite(bread))) {
				return(NULL)
			}
			if (zero_augmented_fit_is_degenerate(bread, params)) {
				private$cached_values$fit_degenerate = TRUE
				return(NULL)
			}
			X_fit = as.matrix(X_fit)
			Xzi_fit = as.matrix(Xzi_fit)
			y = as.numeric(private$y)
			lambda = exp(pmin(as.numeric(X_fit %*% params[seq_len(ncol(X_fit))]), 700))
			pi = stats::plogis(as.numeric(Xzi_fit %*% params[ncol(X_fit) + seq_len(ncol(Xzi_fit))]))
			score = matrix(0, nrow = nrow(X_fit), ncol = total_p)
			if (isTRUE(is_hurdle)) {
				is_zero = y == 0
				if (any(is_zero)) {
					score[is_zero, ncol(X_fit) + seq_len(ncol(Xzi_fit))] =
						(1 - pi[is_zero]) * Xzi_fit[is_zero, , drop = FALSE]
				}
				if (any(!is_zero)) {
					lambda_pos = lambda[!is_zero]
					denom = pmax(1 - exp(-lambda_pos), 1e-15)
					score[!is_zero, seq_len(ncol(X_fit))] =
						(y[!is_zero] - lambda_pos / denom) * X_fit[!is_zero, , drop = FALSE]
					score[!is_zero, ncol(X_fit) + seq_len(ncol(Xzi_fit))] =
						-pi[!is_zero] * Xzi_fit[!is_zero, , drop = FALSE]
				}
			} else {
				is_zero = y == 0
				if (any(is_zero)) {
					e0 = exp(-lambda[is_zero])
					A = pmax(pi[is_zero] + (1 - pi[is_zero]) * e0, 1e-15)
					score[is_zero, seq_len(ncol(X_fit))] =
						-((1 - pi[is_zero]) * e0 * lambda[is_zero] / A) * X_fit[is_zero, , drop = FALSE]
					score[is_zero, ncol(X_fit) + seq_len(ncol(Xzi_fit))] =
						(pi[is_zero] * (1 - pi[is_zero]) * (1 - e0) / A) * Xzi_fit[is_zero, , drop = FALSE]
				}
				if (any(!is_zero)) {
					score[!is_zero, seq_len(ncol(X_fit))] =
						(y[!is_zero] - lambda[!is_zero]) * X_fit[!is_zero, , drop = FALSE]
					score[!is_zero, ncol(X_fit) + seq_len(ncol(Xzi_fit))] =
						-pi[!is_zero] * Xzi_fit[!is_zero, , drop = FALSE]
				}
			}
			meat = crossprod(score)
			tryCatch(bread %*% meat %*% bread, error = function(e) NULL)
		},
		zero_augmented_sandwich_se = function(fit, X_fit, Xzi_fit, j_treat = 2L, is_hurdle = FALSE){
			j_treat = as.integer(j_treat)[1L]
			if (j_treat < 1L || j_treat > ncol(X_fit)) return(NA_real_)
			vcov_robust = private$zero_augmented_poisson_sandwich_vcov_full(fit, X_fit, Xzi_fit, is_hurdle = is_hurdle)
			if (is.null(vcov_robust) || nrow(vcov_robust) < j_treat) return(NA_real_)
			se = sqrt(as.numeric(vcov_robust[j_treat, j_treat]))
			# sqrt(eps) floor: a perfect fit collapses the sandwich to ~0 (see
			# robust_sandwich_variance()), which is non-estimability, not precision.
			if (is.finite(se) && se > sqrt(.Machine$double.eps)) se else NA_real_
		},
			# 2026-08-23 (marginal_estimand_report.md TODO-5): model-implied
			# unconditional mean E[Y | x, w] for the zero-augmented Poisson
			# family, Poisson variants only (ZIP / hurdle Poisson -- NOT
			# NegBin, see zero_augmented_poisson_sandwich_vcov_full()'s
			# comment for why NegBin is deliberately excluded from this
			# pass). theta = [b_cond (p), b_zi (q)], the exact stacked
			# layout fast_zero_augmented_poisson_cpp()'s params/vcov use
			# (matches zero_augmented_sandwich_se()'s own parameter
			# ordering). pi = plogis(Xzi %*% b_zi) is P(structural zero)
			# for ZIP and P(Y = 0) (the hurdle probability) for hurdle --
			# same convention zero_augmented_poisson_sandwich_vcov_full()
			# already uses for its score derivation.
			#
			# ZIP/ZINB-style zero-inflated mean: (1 - pi) * lambda (the
			# untruncated Poisson mean).
			#
			# Hurdle mean: (1 - pi) * E[Y | Y > 0], where the zero-truncated
			# Poisson mean is lambda / (1 - exp(-lambda)) -- verified
			# against the zero-truncated Poisson distribution's standard
			# moment formula (e.g. Cameron & Trivedi, Regression Analysis of
			# Count Data, ch. 4.2): for Y ~ Poisson(lambda) truncated to
			# exclude 0, E[Y | Y > 0] = lambda / P(Y > 0) = lambda / (1 -
			# exp(-lambda)) exactly, because truncating a Poisson does not
			# change its mean-parameter lambda, only the normalizing
			# constant. This Poisson-specific shortcut is NOT valid for
			# NegBin (that family's truncated mean has no such closed form
			# in terms of the untruncated mean alone) -- another reason
			# NegBin needs its own dedicated pass.
			zero_augmented_poisson_mean_from_theta = function(theta, X, Xzi, is_hurdle){
				p = ncol(X)
				b_cond = theta[seq_len(p)]
				b_zi = theta[(p + 1L):length(theta)]
				lambda = exp(pmin(as.numeric(X %*% b_cond), 700))
				pi = stats::plogis(as.numeric(Xzi %*% b_zi))
				if (isTRUE(is_hurdle)) {
					trunc_mean = lambda / pmax(-expm1(-lambda), 1e-15)
					(1 - pi) * trunc_mean
				} else {
					(1 - pi) * lambda
				}
			},
			# G-computation average over the empirical covariate
			# distribution, all subjects plugged in at w = 1 vs. w = 0
			# (column 2 of both design matrices, the fixed "treatment"
			# column convention used throughout this file, e.g.
			# zero_augmented_sandwich_se()'s j_treat = 2L default).
			zero_augmented_poisson_marginal_functional = function(theta, X, Xzi, is_hurdle, estimand){
				X1 = X; X1[, 2L] = 1
				X0 = X; X0[, 2L] = 0
				Xzi1 = Xzi; Xzi1[, 2L] = 1
				Xzi0 = Xzi; Xzi0[, 2L] = 0
				mean1 = mean(private$zero_augmented_poisson_mean_from_theta(theta, X1, Xzi1, is_hurdle))
				mean0 = mean(private$zero_augmented_poisson_mean_from_theta(theta, X0, Xzi0, is_hurdle))
				if (identical(estimand, "marginal_ratio")) log(mean1 / mean0) else mean1 - mean0
			},
			# Full-fit marginal path for compute_estimate(): reuses the
			# single cached ML fit (private$cached_mod, populated by
			# private$shared() via generate_mod()) -- a pure post-fit
			# transform, no refit. SE via marginal_estimand_delta_se()
			# against the sandwich vcov (NOT fit$vcov alone -- the
			# zero-augmented family's Wald SE is already sandwich-corrected
			# for the conditional coefficient, per
			# zero_augmented_sandwich_se(), so the marginal delta-method SE
			# uses the same robust covariance for consistency). Degrees of
			# freedom: Inf, same convention as every other delta-method/
			# sandwich Wald path in this package (ZOIB's marginal path,
			# InferenceIncidGCompAbstract's RD/RR paths).
			compute_marginal_estimand_estimate = function(estimand, estimate_only = FALSE){
				# 2026-08-23 (marginal_estimand_report.md TODO-5, wiring pass):
				# private$cached_mod is NOT the raw backend fit -- shared()
				# (CountLikelihoodPlumbingSource) overwrites private$cached_mod
				# with generate_mod()'s full return value ("out": beta_hat_T/
				# ssq_b_j/params/fisher_information/mod), clobbering the
				# `private$cached_mod = fit` assignment generate_mod() makes
				# internally. The X_fit/Xzi_fit/is_hurdle fields stashed for
				# this marginal path live on the raw fit at out$mod, one level
				# deeper than this function originally assumed (verified via a
				# real fitted instance: mod$X_fit was NULL, mod$mod$X_fit was
				# not). mod$params still resolves correctly at the top level
				# too (out$params is a copy of the raw fit's params), but read
				# it from the same raw object for consistency.
				mod = private$cached_mod
				raw = mod$mod
				if (is.null(raw) || is.null(raw$params) || is.null(raw$X_fit) || is.null(raw$Xzi_fit)) {
					private$cache_nonestimable_estimate("zero_augmented_poisson_marginal_fit_unavailable")
					return(NA_real_)
				}
				is_hurdle = isTRUE(raw$is_hurdle)
				functional = function(theta) private$zero_augmented_poisson_marginal_functional(theta, raw$X_fit, raw$Xzi_fit, is_hurdle, estimand)
				point = tryCatch(functional(raw$params), error = function(e) NA_real_)
				if (!is.finite(point)) {
					private$cache_nonestimable_estimate("zero_augmented_poisson_marginal_point_unavailable")
					return(NA_real_)
				}
				private$cached_values$beta_hat_T = point
				if (estimate_only) return(point)
				vcov_robust = private$zero_augmented_poisson_sandwich_vcov_full(raw, raw$X_fit, raw$Xzi_fit, is_hurdle = is_hurdle)
				if (is.null(vcov_robust)) {
					private$cache_nonestimable_se("zero_augmented_poisson_marginal_vcov_unavailable")
					return(point)
				}
				dm = marginal_estimand_delta_se(raw$params, vcov_robust, functional)
				private$cached_values$df = Inf
				if (is.finite(dm$se) && dm$se >= 0) {
					private$cached_values$s_beta_hat_T = dm$se
					private$clear_nonestimable_state()
				} else {
					private$cache_nonestimable_se("zero_augmented_poisson_marginal_se_unavailable")
				}
				point
			},
			hurdle_poisson_neg_loglik = function(params, X_fit, Xzi_fit){
				y = as.numeric(private$y)
				eta_c = as.numeric(X_fit %*% params[seq_len(ncol(X_fit))])
				eta_z = as.numeric(Xzi_fit %*% params[ncol(X_fit) + seq_len(ncol(Xzi_fit))])
				lambda = exp(pmin(eta_c, 700))
				pi0 = stats::plogis(eta_z)
				is_zero = y == 0
				nll = numeric(length(y))
				nll[is_zero] = -log(pmax(pi0[is_zero], 1e-15))
				if (any(!is_zero)) {
					log1m_pi = stats::plogis(eta_z[!is_zero], lower.tail = FALSE, log.p = TRUE)
					log1m_exp_minus_lambda = log(-expm1(-lambda[!is_zero]))
					nll[!is_zero] = -(log1m_pi + y[!is_zero] * eta_c[!is_zero] - lambda[!is_zero] - log1m_exp_minus_lambda)
				}
				sum(nll)
			},
			zero_augmented_failed_fit_diagnostics = function(fit, exception_message = NULL){
				info = fit$information %||% fit$fisher_information %||% fit$observed_information
				list(
					family = private$za_description(),
					converged = isTRUE(fit$converged),
					hit_iteration_cap = isTRUE(fit$hit_iteration_cap),
					num_iter = fit$num_iter %||% NA_integer_,
					gradient_norm = fit$gradient_norm %||% NA_real_,
					min_eigenvalue_information = fit$min_eigenvalue_information %||% NA_real_,
					params = fit$params %||% NULL,
					params_origin = fit$params_origin %||% "optimizer terminal state",
					information = info %||% NULL,
					exception_message = exception_message %||% fit$exception_message %||% NULL
				)
			},
			fit_hurdle_poisson_components_independently = function(X_fit, Xzi_fit, estimate_only = FALSE){
				# The hurdle-Poisson likelihood has disjoint conditional-count and
				# binary-hurdle parameter blocks. Recover a failed joint optimization
				# by optimizing each full-covariate block with the other held fixed.
				p_cond = ncol(X_fit)
				p_aux = ncol(Xzi_fit)
				total_p = p_cond + p_aux
				y = as.numeric(private$y)
				edi_check_count_kernel_inputs("fast_zero_augmented_poisson_cpp", X_fit, y, Xzi_fit)
				component_error = NULL
				fit_cond = tryCatch(
					fast_zero_augmented_poisson_cpp(
						X_fit, y, Xzi_fit, is_hurdle = TRUE,
						fixed_idx = seq.int(p_cond + 1L, total_p),
						fixed_values = rep(0, p_aux),
						smart_cold_start = private$smart_cold_start_default,
						estimate_only = TRUE,
						optimization_alg = private$optimization_alg
					),
					error = function(e){
						component_error <<- conditionMessage(e)
						NULL
					}
				)
				# Do NOT gate on fit_cond$converged/fit_aux$converged here: this
				# whole function exists to recover a fit the C++ optimizer's
				# own internal flag already called "failed" (see the joint
				# optimization this is a fallback for), so requiring its
				# sub-fits to individually pass that same internal flag can
				# throw away a perfectly good solution -- confirmed in
				# practice (2026-08-27, count-likelihood-families-focused
				# smoke test): a component fit reported converged = FALSE
				# (likely an iteration-cap or internal-tolerance mismatch,
				# not a bad optimum) while its recovered joint parameters
				# matched pscl::hurdle() to ~7 significant figures and its
				# combined gradient_norm was 2.4e-7, far inside the 1e-6
				# acceptance threshold already enforced a few lines below.
				# That gradient-norm check is the real, authoritative
				# quality gate for this function; only finiteness/shape need
				# checking on the raw sub-fits themselves.
				if (is.null(fit_cond) ||
						length(fit_cond$params) != total_p ||
						any(!is.finite(fit_cond$params[seq_len(p_cond)]))) return(NULL)

				beta_cond = as.numeric(fit_cond$params[seq_len(p_cond)])
				fit_aux = tryCatch(
					fast_zero_augmented_poisson_cpp(
						X_fit, y, Xzi_fit, is_hurdle = TRUE,
						fixed_idx = seq_len(p_cond),
						fixed_values = beta_cond,
						smart_cold_start = private$smart_cold_start_default,
						estimate_only = TRUE,
						optimization_alg = private$optimization_alg
					),
					error = function(e){
						component_error <<- conditionMessage(e)
						NULL
					}
				)
				if (is.null(fit_aux) ||
						length(fit_aux$params) != total_p ||
						any(!is.finite(fit_aux$params[p_cond + seq_len(p_aux)]))) return(NULL)

				params = c(beta_cond, as.numeric(fit_aux$params[p_cond + seq_len(p_aux)]))
				score = tryCatch(
					as.numeric(get_zero_augmented_poisson_score_cpp(X_fit, y, Xzi_fit, params, is_hurdle = TRUE)),
					error = function(e) NULL
				)
				gradient_norm = if (!is.null(score) && all(is.finite(score))) sqrt(sum(score^2)) else NA_real_
				if (!is.finite(gradient_norm) || gradient_norm > 1e-6) return(NULL)
				observed_information = tryCatch(
					-as.matrix(get_zero_augmented_poisson_hessian_cpp(X_fit, y, Xzi_fit, params, is_hurdle = TRUE)),
					error = function(e) NULL
				)
				if (is.null(observed_information) || any(!is.finite(observed_information))) return(NULL)
				vcov = tryCatch(solve(observed_information), error = function(e) NULL)
				if (is.null(vcov)) return(NULL)
				param_names = c(colnames(X_fit), colnames(Xzi_fit))
				names(params) = param_names
				colnames(vcov) = rownames(vcov) = param_names
				neg_loglik = private$hurdle_poisson_neg_loglik(params, X_fit, Xzi_fit)
				list(
					coefficients = list(
						cond = stats::setNames(beta_cond, colnames(X_fit)),
						zi = stats::setNames(params[p_cond + seq_len(p_aux)], colnames(Xzi_fit))
					),
					params = params,
					vcov = vcov,
					converged = TRUE,
					hit_iteration_cap = isTRUE(fit_cond$hit_iteration_cap) || isTRUE(fit_aux$hit_iteration_cap),
					num_iter = sum(as.integer(c(fit_cond$num_iter %||% 0L, fit_aux$num_iter %||% 0L))),
					gradient_norm = gradient_norm,
					neg_ll = neg_loglik,
					neg_loglik = neg_loglik,
					observed_information = observed_information,
					fisher_information = observed_information,
					information = observed_information,
					information_type = "observed",
					hessian = -observed_information,
					componentwise_recovery = TRUE,
					component_fits = list(conditional = fit_cond, auxiliary = fit_aux),
					exception_message = component_error
				)
			},
			compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			# Ensure we have the best design from the original data
			if (is.null(private$best_X_colnames)){
				private$shared(estimate_only = TRUE)
			}
			# If the initial fit was unavailable, preserve its typed result.
			if (is.null(private$best_X_colnames)){
				return(self$compute_estimate(estimate_only = estimate_only))
			}
			X_fit = private$build_component_matrix(private$model_formula, private$best_X_colnames, treatment_name = "treatment")
			Xzi_fit = private$build_component_matrix(private$model_formula_zero, private$best_Xzi_colnames, treatment_name = "treatment")
			# v1.0.6-TODO-195 (2): same aliased-column drop as the full fit.
			X_fit = edi_zero_augmented_drop_aliased_count_cols(self, private, X_fit)
			# v1.0.6-TODO-186: see zero_augmented_count_treatment_identified().
			if (!zero_augmented_count_treatment_identified(X_fit, private$y, j_treat = 2L)) return(NA_real_)
			# v1.0.6-TODO-195 (3): no finite hurdle count-part treatment MLE.
			if (identical(private$za_description(), "Hurdle Poisson") && zero_augmented_count_mle_infinite(X_fit, private$y, j_treat = 2L)) return(NA_real_)
			if (private$use_rcpp && identical(private$za_description(), "Zero-Inflated Negative Binomial")) {
				n_params = ncol(X_fit) + ncol(Xzi_fit) + 1L
				ws_args = private$get_backend_warm_start_args(n_params)
				vc_start = ncol(X_fit) + 1L
				n_vc = ncol(Xzi_fit) + 1L
				has_vc = !is.null(private$cached_vc_params) && length(private$cached_vc_params) == n_vc && all(is.finite(private$cached_vc_params))
				fit = tryCatch(
					fast_zinb_cpp_guarded(
						X = X_fit, y = as.numeric(private$y), Xzi = Xzi_fit,
						warm_start_params = ws_args$start_params,
						warm_start_fisher_info = ws_args$warm_start_fisher_info,
						smart_cold_start = private$smart_cold_start_default,
						estimate_only = estimate_only, optimization_alg = private$optimization_alg,
						fixed_idx    = if (has_vc) as.integer(vc_start:(vc_start + n_vc - 1L)) else NULL,
						fixed_values = if (has_vc) as.numeric(private$cached_vc_params) else NULL
					),
					error = function(e) NULL
				)
				if (is.null(fit) || !isTRUE(fit$converged)) return(NA_real_)
				private$set_fit_warm_start(as.numeric(fit$params), "params")
				return(as.numeric(fit$params[2]))
			} else if (private$use_rcpp && !grepl("Negative Binomial", private$za_description())) {
				is_hurdle = identical(private$za_description(), "Hurdle Poisson")
				n_params = ncol(X_fit) + ncol(Xzi_fit)
				ws_args = private$get_backend_warm_start_args(n_params)
					# v1.0.6-TODO-30: the guarded fitter cold-starts when the warm start
					# (the full-data fit) has its zero part on the ridge and adds the
					# pscl-start candidate (v1.0.6-TODO-152), as the full fit does.
					fit = tryCatch(
						fast_zero_augmented_poisson_cpp_guarded(
							X_fit, as.numeric(private$y), Xzi_fit,
						is_hurdle = is_hurdle,
						warm_start_params = ws_args$start_params,
						warm_start_fisher_info = ws_args$warm_start_fisher_info,
						smart_cold_start = private$smart_cold_start_default,
						estimate_only = estimate_only, optimization_alg = private$optimization_alg
						),
						error = function(e) NULL
					)
					# v1.0.6-TODO-30: the same plain cold retry the full fit makes
					# (release_v1_0_5.md TODO-4), so a replicate equals a fresh fit.
					if ((is.null(fit) || !isTRUE(fit$converged)) && !is_hurdle) {
						fit_retry = tryCatch(
							fast_zero_augmented_poisson_cpp_guarded(
								X_fit, as.numeric(private$y), Xzi_fit,
								is_hurdle = FALSE,
								smart_cold_start = FALSE,
								estimate_only = estimate_only, optimization_alg = private$optimization_alg
							),
							error = function(e) NULL
						)
						if (!is.null(fit_retry) && isTRUE(fit_retry$converged)) fit = fit_retry
					}
					if ((is.null(fit) || !isTRUE(fit$converged)) && is_hurdle) {
						fit_recovered = private$fit_hurdle_poisson_components_independently(
							X_fit, Xzi_fit, estimate_only = estimate_only
						)
						if (!is.null(fit_recovered) && isTRUE(fit_recovered$converged)) fit = fit_recovered
					}
					if (is.null(fit) || !isTRUE(fit$converged)) return(NA_real_)
					private$set_fit_warm_start(as.numeric(fit$params), "params")
					# v1.0.6-TODO-189: under a marginal estimand (ZIP / hurdle Poisson
					# only) return the g-computed functional, the scale
					# compute_estimate() and the reused worker use.
					estimand = if (is.function(self$get_estimand)) self$get_estimand() else "conditional"
					if (identical(estimand, "conditional")) return(as.numeric(fit$params[2]))
					return(edi_rand_statistic_marginal_point(function() private$zero_augmented_poisson_marginal_functional(
						as.numeric(fit$params), X_fit, Xzi_fit, is_hurdle, estimand
					)))
			} else {
				# v1.0.6-TODO-189: the glmmTMB path has no marginal functional (the
				# marginal estimate needs the Rcpp fit's stacked params), so it gives
				# no statistic rather than the conditional coefficient.
				if (is.function(self$get_estimand) && !identical(self$get_estimand(), "conditional")) return(NA_real_)
				dat = private$build_component_frame(X_fit, Xzi_fit)
				mod = private$fit_zero_augmented_model(dat, X_fit, Xzi_fit)
				if (is.null(mod)) return(NA_real_)
				
				cond_coef = tryCatch(glmmTMB::fixef(mod)$cond, error = function(e) NULL)
				if (is.null(cond_coef) || !("w" %in% names(cond_coef))) return(NA_real_)
				return(as.numeric(cond_coef["w"]))
			}
		},
		za_family = function() stop(class(self)[1], " must implement za_family()."),
		# TRUE for a zero-inflated MIXTURE (not a hurdle: there zeros come only from
		# the binary part, the likelihood factorizes and the count part keeps a finite
		# MLE) whose effective response -- rows with positive weight -- has no zeros.
		zero_inflation_is_unidentified = function(y, weights = NULL){
			desc = tryCatch(private$za_description(), error = function(e) "")
			if (!grepl("^Zero-Inflated", desc)) return(FALSE)
			y = as.numeric(y)
			keep = is.finite(y)
			if (!is.null(weights)) keep = keep & is.finite(weights) & weights > 0
			any(keep) && !any(y[keep] == 0)
		},
		# Inside resampling (bootstrap draws, parametric-bootstrap simulations) a
		# replicate with no zeros gets the non-inflated fit: the zero-inflation
		# intercept is fixed at -40 (pi ~ 4e-18) and its other coefficients at 0, which
		# is the boundary MLE and reproduces the Poisson / negative binomial fit of the
		# count part. Returns list(idx, values) for the C++ fitters' fixed_idx /
		# fixed_values (NULL when the data have zeros and nothing else is fixed);
		# `extra_idx` / `extra_values` are parameters the caller already fixes.
		zero_inflation_fixed_args = function(y, n_cond, n_zi, extra_idx = NULL, extra_values = NULL){
			if (!private$zero_inflation_is_unidentified(y)) {
				if (is.null(extra_idx)) return(NULL)
				return(list(idx = as.integer(extra_idx), values = as.numeric(extra_values)))
			}
			list(
				idx = as.integer(c(extra_idx, n_cond + seq_len(n_zi))),
				values = as.numeric(c(extra_values, -40, rep(0, n_zi - 1L)))
			)
		},
		za_description = function() stop(class(self)[1], " must implement za_description()."),
		supports_likelihood_tests = function(){
			isTRUE(private$use_rcpp) && private$za_description() %in% c(
				"Zero-Inflated Negative Binomial",
				"Zero-Inflated Poisson",
				"Hurdle Poisson"
			)
		},
		get_likelihood_test_spec = function(){
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			beta_hat_T = as.numeric(private$cached_values$beta_hat_T %||% NA_real_)[1L]
			if (!is.finite(beta_hat_T)) {
				private$invalidate_likelihood_fit("zero_augmented_poisson_treatment_missing")
				return(NULL)
			}
			X_fit = ctx$X
			Xzi_fit = ctx$Xzi
			y = as.numeric(private$y)
			j_treat = as.integer(ctx$j_treat)
			is_hurdle = isTRUE(ctx$is_hurdle)
			is_zinb = identical(private$za_description(), "Zero-Inflated Negative Binomial")
			start_len = if (is_zinb) ncol(X_fit) + ncol(Xzi_fit) + 1L else ncol(X_fit) + ncol(Xzi_fit)
			boundary_information = function(fit, information){
				information = as.matrix(information)
				if (is_zinb && isTRUE(fit$dispersion_at_poisson_boundary)) {
					k = nrow(information)
					information[k, ] = 0
					information[, k] = 0
					information[k, k] = 1
				}
				# 2026-09-07 fix (#18): the zero-inflation submodel is not
				# identified once its fitted probability has collapsed to
				# ~0 for every observation (fast_zinb.cpp's
				# zero_inflation_at_boundary reduced-fit path). Neuter the
				# entire zi coefficient block, mirroring the
				# dispersion-boundary handling above -- without this, the
				# information matrix carries near-zero rows/columns for
				# the zi block that destabilize the Wald/score tests and
				# (via the reduced fit's neg_loglik discontinuity when
				# only one of the full/null refits hits the boundary)
				# inflate the LR test's Type-I error.
				if (is_zinb && isTRUE(fit$zero_inflation_at_boundary)) {
					zi_idx = (ncol(X_fit) + 1L):(ncol(X_fit) + ncol(Xzi_fit))
					information[zi_idx, ] = 0
					information[, zi_idx] = 0
					diag(information)[zi_idx] = 1
				}
				information
			}
			list(
				X = X_fit,
				Xzi = Xzi_fit,
				y = y,
				j = j_treat,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					warm_fisher = private$get_fit_warm_start_fisher(start_len)
					fit_from = function(warm_start_params) if (is_zinb) {
						fast_zinb_cpp_guarded(
							X = X_fit,
							y = y,
							Xzi = Xzi_fit,
							warm_start_params = warm_start_params,
							warm_start_fisher_info = warm_fisher,
							smart_cold_start = private$smart_cold_start_default,
							estimate_only = FALSE,
							optimization_alg = private$optimization_alg,
							fixed_idx = j_treat,
							fixed_values = delta
						)
					} else {
						edi_check_count_kernel_inputs("fast_zero_augmented_poisson_cpp", X_fit, y, Xzi_fit)
						fast_zero_augmented_poisson_cpp(
							X_fit,
							y,
							Xzi_fit,
							is_hurdle = is_hurdle,
							warm_start_params = warm_start_params,
							warm_start_fisher_info = warm_fisher,
							smart_cold_start = private$smart_cold_start_default,
							estimate_only = FALSE,
							optimization_alg = private$optimization_alg,
							fixed_idx = j_treat,
							fixed_values = delta
						)
					}
					fit = fit_from(start %||% private$get_fit_warm_start_for_length("params", start_len))
					# TODO-169 (2026-10-28): a start chained from the previous CI-search
					# delta can sit where the zero-inflation logits have saturated
					# (pi ~ 0, zero gradient), and the refit then "converges" there at a
					# too-high nll -- the LR/score CI stops being the inversion of the
					# test. Also refit from the full fit with element j set to delta and
					# keep the lower nll.
					full_start = as.numeric(private$cached_mod$params %||% NULL)
					if (!is.null(start) && length(full_start) == start_len && all(is.finite(full_start))) {
						full_start[j_treat] = delta
						nll_of = function(f) {
							v = if (is.null(f)) NA_real_ else suppressWarnings(as.numeric(f$neg_loglik %||% f$neg_ll %||% NA_real_)[1L])
							if (is.finite(v)) v else Inf
						}
						alt = tryCatch(fit_from(full_start), error = function(e) NULL)
						if (nll_of(alt) < nll_of(fit)) fit = alt
					}
					if (!is.null(fit) && is.null(fit$b) && is.null(fit$params) && !is.null(fit$coefficients)) {
						fit$params = as.numeric(c(fit$coefficients$cond, fit$coefficients$zi))
					}
					fit
				},
				extract_start = function(fit){
					as.numeric(fit$params %||% c(as.numeric(fit$coefficients$cond), as.numeric(fit$coefficients$zi)))
				},
				score = function(fit){
					params = as.numeric(fit$params %||% c(as.numeric(fit$coefficients$cond), as.numeric(fit$coefficients$zi)))
					if (is_zinb) {
						as.numeric(fit$score %||% get_zinb_score_cpp(X = X_fit, y = y, Xzi = Xzi_fit, params))
					} else {
						as.numeric(fit$score %||% get_zero_augmented_poisson_score_cpp(X_fit, y, Xzi_fit, params, is_hurdle = is_hurdle))
					}
				},
				observed_information = function(fit){
					params = as.numeric(fit$params %||% c(as.numeric(fit$coefficients$cond), as.numeric(fit$coefficients$zi)))
					boundary_information(fit, fit$observed_information %||% (if (is_zinb) -get_zinb_hessian_cpp(X_fit, y, Xzi_fit, params) else -get_zero_augmented_poisson_hessian_cpp(X_fit, y, Xzi_fit, params, is_hurdle)))
				},
				information = function(fit){
					params = as.numeric(fit$params %||% c(as.numeric(fit$coefficients$cond), as.numeric(fit$coefficients$zi)))
					boundary_information(fit, fit$information %||% fit$fisher_information %||% fit$observed_information %||% (if (is_zinb) -get_zinb_hessian_cpp(X_fit, y, Xzi_fit, params) else -get_zero_augmented_poisson_hessian_cpp(X_fit, y, Xzi_fit, params, is_hurdle)))
				},
				neg_loglik = function(fit){
					params = as.numeric(fit$params %||% c(as.numeric(fit$coefficients$cond), as.numeric(fit$coefficients$zi)))
					if (is_zinb) {
						as.numeric(fit$neg_loglik %||% fit$neg_ll %||% get_zinb_neg_loglik_cpp(X = X_fit, y = y, Xzi = Xzi_fit, params))
					} else {
						as.numeric(fit$neg_loglik %||% fit$neg_ll %||% fit$mod$neg_ll %||% fit$mod$neg_loglik)
					}
				}
			)
		},
		predictors_df = function(){
			if (ncol(as.matrix(private$get_X())) > 0){
				full_X = private$create_design_matrix()
				X_model = full_X[, -1, drop = FALSE]
				colnames(X_model)[1] = "w"
				as.data.frame(X_model)
			} else {
				data.frame(w = private$w)
			}
		},
		fit_zero_augmented_model = function(dat, X_fit, Xzi_fit, weights = NULL){
			formula_cond = private$build_formula_from_matrix(X_fit)
			formula_zi = private$build_formula_from_matrix(Xzi_fit, response = NULL)
			# Resampled data with no zeros (positive weight): glmmTMB's own
			# non-inflated model (ziformula = ~0), i.e. the Poisson / NB fit -- see
			# zero_inflation_fixed_args().
			if (private$zero_inflation_is_unidentified(private$y, weights)) {
				formula_zi = ~0
				private$cached_values$zero_inflation_fallback = TRUE
			}
			# One TMB thread: a thread-split likelihood sum changes the fit with
			# set_num_cores() (v1.0.6-TODO-64); EDI parallelizes the replicates itself.
			glmm_control = glmmTMB::glmmTMBControl(parallel = 1L)
			tryCatch(
				suppressWarnings(suppressMessages(
					glmmTMB::glmmTMB(
						formula_cond,
						ziformula = formula_zi,
						family = private$za_family(),
						data = dat,
						weights = weights,
						control = glmm_control
					)
				)),
				error = function(e) NULL
			)
		},
			generate_mod = function(estimate_only = FALSE){
				private$cached_values$likelihood_test_context = NULL
				private$cached_values$model_fit_fallback = NULL
				private$cached_values$model_fit_failure = NULL
				private$cached_values$summary_table = NULL
				private$cached_values$zero_part_nonestimable_reason = NULL
				X_full = private$build_component_matrix(private$model_formula, treatment_name = "w")
				if (is.null(X_full)){
					private$cache_nonestimable_estimate("zero_augmented_poisson_design_unusable")
					return(NULL)
				}
				# v1.0.6-TODO-126: best_X_colnames is reduced once on the full data, and the
				# reusable bootstrap/jackknife worker restores it on every draw. On a draw
				# where a cached column is constant or collinear (e.g. a stratum dummy on a
				# leave-one-block-out draw), the hardened X_full above has already dropped
				# it, so the cached set no longer fits this sample: reduce afresh, as a
				# refit on the same rows does. X_full is full rank after hardening, so a
				# cached set it still contains is a valid reduction.
				if (!is.null(private$best_X_colnames) && !all(private$best_X_colnames %in% colnames(X_full))) {
					private$best_X_colnames = NULL
				}
				if (is.null(private$best_X_colnames)) {
					res_reduced = private$reduce_design_matrix_preserving_treatment(X_full)
					X_fit = res_reduced$X
					if (is.null(X_fit)){
						private$cache_nonestimable_estimate("zero_augmented_poisson_design_unusable")
					return(NULL)
				}
				colnames(X_fit) = colnames(X_full)[res_reduced$keep]
				private$best_X_colnames = setdiff(colnames(X_fit), c("(Intercept)", "w"))
				} else {
					X_fit = private$build_component_matrix(private$model_formula, private$best_X_colnames, treatment_name = "w")
				}
				Xzi_full = private$build_component_matrix(private$model_formula_zero, treatment_name = "w")
				if (is.null(Xzi_full)){
					private$cache_nonestimable_estimate("zero_augmented_poisson_aux_design_unusable")
					return(NULL)
				}
				if (!is.null(private$best_Xzi_colnames) && !all(private$best_Xzi_colnames %in% colnames(Xzi_full))) {
					private$best_Xzi_colnames = NULL
				}
				if (is.null(private$best_Xzi_colnames)) {
					res_zi = private$reduce_design_matrix_preserving_treatment(Xzi_full)
					Xzi_fit = res_zi$X
					if (is.null(Xzi_fit)){
						private$cache_nonestimable_estimate("zero_augmented_poisson_aux_design_unusable")
					return(NULL)
				}
				colnames(Xzi_fit) = colnames(Xzi_full)[res_zi$keep]
				private$best_Xzi_colnames = setdiff(colnames(Xzi_fit), c("(Intercept)", "w"))
				} else {
					Xzi_fit = private$build_component_matrix(private$model_formula_zero, private$best_Xzi_colnames, treatment_name = "w")
				}
				# v1.0.6-TODO-195 (2): drop count-part covariates aliased on the
				# positive rows, as glm does (warns once, never inside resampling).
				X_fit = edi_zero_augmented_drop_aliased_count_cols(self, private, X_fit, warn = TRUE)
				# v1.0.6-TODO-186: a count-part treatment coefficient the positive rows do
				# not identify is not estimable; fitting would just return the warm start.
				if (!zero_augmented_count_treatment_identified(X_fit, private$y, j_treat = 2L)) {
					private$invalidate_likelihood_fit("zero_augmented_count_treatment_unidentified")
					return(NULL)
				}
				# v1.0.6-TODO-195 (3): a hurdle count part whose positive counts all equal
				# 1 in an arm has no finite treatment MLE; NA with a recorded reason and
				# one edi_procedure_na_warning (silent inside resampling).
				if (identical(private$za_description(), "Hurdle Poisson")) {
					inf_arms = zero_augmented_count_mle_infinite_arms(X_fit, private$y, j_treat = 2L)
					if (length(inf_arms)) {
						private$invalidate_likelihood_fit("hurdle_count_mle_not_finite")
						edi_warn_hurdle_count_mle_not_finite(self, private, inf_arms)
						return(NULL)
					}
				}
				out = list()
				private$cached_values$zero_inflation_fallback = NULL
				zi_fix = private$zero_inflation_fixed_args(private$y, ncol(X_fit), ncol(Xzi_fit))
				if (!is.null(zi_fix)) private$cached_values$zero_inflation_fallback = TRUE
			if (private$use_rcpp && identical(private$za_description(), "Zero-Inflated Negative Binomial")) {
				n_params = ncol(X_fit) + ncol(Xzi_fit) + 1L
				ws_args = private$get_backend_warm_start_args(n_params)
				fit_error = NULL
				fit = tryCatch(
					fast_zinb_cpp_guarded(
						X = X_fit, y = as.numeric(private$y), Xzi = Xzi_fit,
						warm_start_params = ws_args$start_params,
						warm_start_fisher_info = ws_args$warm_start_fisher_info,
						smart_cold_start = private$smart_cold_start_default,
						estimate_only = estimate_only, optimization_alg = private$optimization_alg,
						fixed_idx = zi_fix$idx, fixed_values = zi_fix$values
					),
					error = function(e){
						fit_error <<- conditionMessage(e)
						NULL
					}
				)
				if (is.null(fit) || !isTRUE(fit$converged)) {
					private$cached_values$model_fit_failure = private$zero_augmented_failed_fit_diagnostics(
						fit %||% list(), exception_message = fit_error
					)
					private$invalidate_likelihood_fit("zinb_fit_unavailable")
					return(NULL)
				}
				beta_hat_T = as.numeric(fit$params[2])
				if (!is.finite(beta_hat_T)) {
					private$invalidate_likelihood_fit("zinb_treatment_missing")
					return(NULL)
				}
				
				private$clear_nonestimable_state()
				private$cached_mod = fit
				private$set_fit_warm_start(as.numeric(fit$params), "params")
				vc_vals = as.numeric(fit$params[(ncol(X_fit) + 1L):length(fit$params)])
				if (all(is.finite(vc_vals))) private$cached_vc_params = vc_vals

				private$cached_values$likelihood_test_context = list(
					X = X_fit,
					Xzi = Xzi_fit,
					j_treat = 2L,
					is_hurdle = FALSE
				)
				private$record_zero_augmented_fit_summary(
					fit = fit,
					X_full = X_full,
					Xzi_full = Xzi_full,
					X_fit = X_fit,
					Xzi_fit = Xzi_fit,
					is_hurdle = FALSE
				)
				# v1.0.6-TODO-152: separated zero part -> NA zero rows + one warning.
				edi_zero_augmented_flag_zero_part_separation(self, private, fit, X_fit, Xzi_fit, is_hurdle = FALSE, is_zinb = TRUE)
				out$beta_hat_T = beta_hat_T
				if (!estimate_only) {
					se = private$zero_augmented_sandwich_se(fit, X_fit, Xzi_fit, j_treat = 2L, is_hurdle = FALSE)
					if (!is.finite(se) || se <= 0) {
						se = private$safe_zero_augmented_vcov_se(fit, j_treat = 2L)
					}
					out$ssq_b_j = if (is.finite(se) && se > 0) se^2 else NA_real_
				}
				out$params = as.numeric(fit$params)
				out$neg_loglik = fit$neg_loglik %||% fit$neg_ll
				out$fisher_information = fit$fisher_information
				out$information_invertible = fit$information_invertible %||% NA
				out$mod = fit
			} else if (private$use_rcpp && !grepl("Negative Binomial", private$za_description())) {
				is_hurdle = identical(private$za_description(), "Hurdle Poisson")
				n_params = ncol(X_fit) + ncol(Xzi_fit)
				ws_args = private$get_backend_warm_start_args(n_params)
				fit_error = NULL
				# v1.0.6-TODO-30 / -152: see fast_zero_augmented_poisson_cpp_guarded().
				fit = tryCatch(
					fast_zero_augmented_poisson_cpp_guarded(
						X_fit, as.numeric(private$y), Xzi_fit,
						is_hurdle = is_hurdle,
						warm_start_params = ws_args$start_params,
						warm_start_fisher_info = ws_args$warm_start_fisher_info,
						smart_cold_start = private$smart_cold_start_default,
						estimate_only = estimate_only, optimization_alg = private$optimization_alg,
						fixed_idx = zi_fix$idx, fixed_values = zi_fix$values
					),
					error = function(e){
						fit_error <<- conditionMessage(e)
						NULL
					}
				)
				if (is.null(fit) || !isTRUE(fit$converged)) {
					private$cached_values$model_fit_failure = private$zero_augmented_failed_fit_diagnostics(
						fit %||% list(), exception_message = fit_error
					)
					if (!is_hurdle) {
						# 2026-10-22 (release_v1_0_5.md TODO-4): the default
						# Newton->LBFGS fit can stall just above the gradient
						# tolerance from the smart cold start (|grad| ~5e-8 vs
						# 1e-8, params already equal to pscl's to 6 digits) and
						# be flagged unconverged; one cold retry from the plain
						# start (no warm start, smart_cold_start = FALSE)
						# converges (|grad| ~1e-9..1e-12). Mirrors the hurdle
						# recovery below.
						fit_retry = tryCatch(
							fast_zero_augmented_poisson_cpp_guarded(
								X_fit, as.numeric(private$y), Xzi_fit,
								is_hurdle = FALSE,
								warm_start_params = NULL,
								warm_start_fisher_info = NULL,
								smart_cold_start = FALSE,
								estimate_only = estimate_only, optimization_alg = private$optimization_alg,
								fixed_idx = zi_fix$idx, fixed_values = zi_fix$values
							),
							error = function(e) NULL
						)
						if (!is.null(fit_retry) && isTRUE(fit_retry$converged)) {
							private$cached_values$model_fit_failure$recovered_by = "plain_cold_start_retry"
							fit = fit_retry
						}
					}
					if (is_hurdle) {
						fit_recovered = private$fit_hurdle_poisson_components_independently(
							X_fit, Xzi_fit, estimate_only = estimate_only
						)
						if (!is.null(fit_recovered) && isTRUE(fit_recovered$converged)) {
							private$cached_values$model_fit_failure$recovered_by = "independent_full_model_components"
							fit = fit_recovered
						}
					}
				}
					if (is.null(fit) || !isTRUE(fit$converged)) {
						private$invalidate_likelihood_fit("zero_augmented_poisson_fit_unavailable")
						return(NULL)
				}
				beta_hat_T = as.numeric(fit$params[2])
				if (!is.finite(beta_hat_T)) {
					private$invalidate_likelihood_fit("zero_augmented_poisson_treatment_missing")
					return(NULL)
				}
				
				private$clear_nonestimable_state()
				# 2026-08-23 (marginal_estimand_report.md TODO-5): stash the
				# design matrices and is_hurdle flag on the cached fit itself
				# (same pattern as ZOIB's mod$X/mod$X_zero_one, TODO-4) so the
				# marginal-estimand post-fit path can rebuild the mean
				# function and its delta-method gradient without a refit.
				fit$X_fit = X_fit
				fit$Xzi_fit = Xzi_fit
				fit$is_hurdle = is_hurdle
				private$cached_mod = fit
				full_params = as.numeric(fit$params)
				private$set_fit_warm_start(full_params, "params")

				private$cached_values$likelihood_test_context = list(
					X = X_fit,
					Xzi = Xzi_fit,
					j_treat = 2L,
					is_hurdle = is_hurdle
				)
				private$record_zero_augmented_fit_summary(
					fit = fit,
					X_full = X_full,
					Xzi_full = Xzi_full,
					X_fit = X_fit,
					Xzi_fit = Xzi_fit,
					is_hurdle = is_hurdle
				)
				# v1.0.6-TODO-152: separated zero part -> NA zero rows + one warning.
				edi_zero_augmented_flag_zero_part_separation(self, private, fit, X_fit, Xzi_fit, is_hurdle = is_hurdle)
				out$beta_hat_T = beta_hat_T
				# 2026-08-23 (marginal_estimand_report.md TODO-5, wiring pass):
				# also stash beta_hat_T/ssq_b_j directly onto fit (== private$
				# cached_mod), mirroring ZOIB's mod$beta_hat_T/mod$ssq_b_2
				# (TODO-4) -- lets compute_estimate() re-derive the conditional
				# point/SE from private$cached_mod alone (no refit) after a
				# marginal-estimand computation has overwritten private$
				# cached_values$beta_hat_T/s_beta_hat_T, fixing the same
				# shared()-short-circuit-guard staleness-on-toggle bug ZOIB's
				# own compute_estimate() comment documents.
				fit$beta_hat_T = beta_hat_T
				if (!estimate_only) {
					se = private$zero_augmented_sandwich_se(fit, X_fit, Xzi_fit, j_treat = 2L, is_hurdle = is_hurdle)
					if (!is.finite(se) || se <= 0) {
						se = private$safe_zero_augmented_vcov_se(fit, j_treat = 2L)
					}
					out$ssq_b_j = if (is.finite(se) && se > 0) se^2 else NA_real_
					fit$ssq_b_j = out$ssq_b_j
				}
				out$params = full_params
				out$fisher_information = fit$fisher_information
				out$information_invertible = fit$information_invertible %||% NA
				out$mod = fit
			} else {
				dat = private$build_component_frame(X_fit, Xzi_fit)
				mod = private$fit_zero_augmented_model(dat, X_fit, Xzi_fit)
				if (is.null(mod)){
					private$cache_nonestimable_estimate("zero_augmented_poisson_fit_unavailable")
					return(NULL)
				}
				
				private$clear_nonestimable_state()
				private$cached_values$likelihood_test_context = NULL
				cond_coef = tryCatch(glmmTMB::fixef(mod)$cond, error = function(e) NULL)
				if (is.null(cond_coef) || !("w" %in% names(cond_coef)) || !is.finite(cond_coef["w"])){
					private$cache_nonestimable_estimate("zero_augmented_poisson_treatment_missing")
					return(NULL)
				}
				out$beta_hat_T = as.numeric(cond_coef["w"])
				if (!estimate_only) {
					coef_table = tryCatch(summary(mod)$coefficients$cond, error = function(e) NULL)
					se = if (!is.null(coef_table) && ("w" %in% rownames(coef_table))) as.numeric(coef_table["w", "Std. Error"]) else NA_real_
					out$ssq_b_j = if (is.finite(se) && se > 0) se^2 else NA_real_
				}
				out$mod = mod
			}
			out
		},
		supports_lik_ratio_param_bootstrap = function(){
			isTRUE(private$use_rcpp) && private$za_description() %in% c(
				"Zero-Inflated Negative Binomial",
				"Zero-Inflated Poisson",
				"Hurdle Poisson"
			)
		},
		supports_lik_ratio_param_bootstrap_confidence_interval = function(){
			FALSE
		},
		simulate_under_lik_null = function(spec, delta, null_fit){
			is_zinb   = identical(private$za_description(), "Zero-Inflated Negative Binomial")
			is_hurdle = identical(private$za_description(), "Hurdle Poisson")
			X   = spec$X
			Xzi = spec$Xzi
			j   = spec$j
			n   = nrow(X)
			if (is_zinb) {
				p_null = as.numeric(null_fit$params)
				b_cond = p_null[seq_len(ncol(X))]
				b_zi   = p_null[ncol(X) + seq_len(ncol(Xzi))]
			} else {
				b_cond = as.numeric(null_fit$coefficients$cond)
				b_zi   = as.numeric(null_fit$coefficients$zi)
			}
			lambda = exp(pmin(as.numeric(X %*% b_cond), 20))
			pi     = plogis(as.numeric(Xzi %*% b_zi))
			if (is_zinb){
				full_params = as.numeric(null_fit$params)
				theta = exp(min(full_params[length(full_params)], 15))
				if (!is.finite(theta) || theta <= 0) return(NULL)
				u = rbinom(n, 1L, pi)
				counts = rnbinom(n, size = theta, mu = lambda)
				y_sim = as.integer(ifelse(u == 1L, 0L, counts))
			} else if (is_hurdle){
				p0 = ppois(0, lambda)
				u  = rbinom(n, 1L, pi)
				y_pos = as.integer(qpois(p0 + (1 - p0) * runif(n), lambda))
				y_pos = pmax(y_pos, 1L)
				y_sim = as.integer(ifelse(u == 1L, 0L, y_pos))
			} else {
				u = rbinom(n, 1L, pi)
				y_sim = as.integer(ifelse(u == 1L, 0L, rpois(n, lambda)))
			}
			n_params = if (is_zinb) ncol(X) + ncol(Xzi) + 1L else ncol(X) + ncol(Xzi)
			# A simulated response with no zeros gets the non-inflated fit (both the
			# full and the null refit), never a dropped replicate.
			sim_fix = private$zero_inflation_fixed_args(y_sim, ncol(X), ncol(Xzi))
			full_res = tryCatch(
				if (is_zinb) {
					fast_zinb_cpp_guarded(
						X = X, y = as.numeric(y_sim), Xzi = Xzi,
						smart_cold_start = private$smart_cold_start_default,
						estimate_only = FALSE,
						optimization_alg = private$optimization_alg,
						fixed_idx = sim_fix$idx, fixed_values = sim_fix$values
					)
				} else {
					fast_zero_augmented_poisson_cpp_guarded(
						X, as.numeric(y_sim), Xzi,
						is_hurdle = is_hurdle,
						smart_cold_start = private$smart_cold_start_default,
						estimate_only = FALSE,
						optimization_alg = private$optimization_alg,
						fixed_idx = sim_fix$idx, fixed_values = sim_fix$values
					)
				},
				error = function(e) NULL
			)
			if (is.null(full_res) || !isTRUE(full_res$converged)) return(NULL)
			beta_j = if (is_zinb) as.numeric(full_res$params[j]) else as.numeric(full_res$coefficients$cond[j])
			if (!is.finite(beta_j)) return(NULL)
			if (is.null(full_res$params) && !is.null(full_res$coefficients)){
				full_res$params = as.numeric(c(full_res$coefficients$cond, full_res$coefficients$zi))
			}
			# v1.0.6-TODO-186 / -195 (3): a simulated hurdle response whose positive rows
			# do not identify the count-part treatment coefficient, or put it at
			# infinity, has no usable estimate: the parametric-bootstrap ESTIMATE
			# replicate reads params[j] and counts it as a failed refit. The LR
			# replicate only uses the two neg-log-likelihoods, whose supremum stays
			# finite, so it is unchanged.
			if (is_hurdle && length(full_res$params) >= j &&
				(!zero_augmented_count_treatment_identified(X, y_sim, j_treat = j) ||
					zero_augmented_count_mle_infinite(X, y_sim, j_treat = j))) {
				full_res$params[j] = NA_real_
			}
			list(
				worker_data = list(y = as.numeric(y_sim)),
				full_fit = full_res,
				fit_null = function(d, start = NULL){
					ws = start %||% private$get_fit_warm_start_for_length("params", n_params)
					null_fix = private$zero_inflation_fixed_args(y_sim, ncol(X), ncol(Xzi), extra_idx = j, extra_values = d)
					fit = tryCatch(
						if (is_zinb) {
							fast_zinb_cpp_guarded(
								X = X, y = as.numeric(y_sim), Xzi = Xzi,
								warm_start_params = ws,
								smart_cold_start = private$smart_cold_start_default,
								estimate_only = FALSE,
								optimization_alg = private$optimization_alg,
								fixed_idx = null_fix$idx, fixed_values = null_fix$values
							)
						} else {
							fast_zero_augmented_poisson_cpp_guarded(
								X, as.numeric(y_sim), Xzi,
								is_hurdle = is_hurdle,
								warm_start_params = ws,
								smart_cold_start = private$smart_cold_start_default,
								estimate_only = FALSE,
								optimization_alg = private$optimization_alg,
								fixed_idx = null_fix$idx, fixed_values = null_fix$values
							)
						},
						error = function(e) NULL
					)
					if (!is.null(fit) && is.null(fit$params) && !is.null(fit$coefficients)){
						fit$params = as.numeric(c(fit$coefficients$cond, fit$coefficients$zi))
					}
					fit
				},
				neg_loglik = function(fit){
					params = as.numeric(fit$params %||% c(as.numeric(fit$coefficients$cond), as.numeric(fit$coefficients$zi)))
					if (is_zinb){
						as.numeric(fit$neg_loglik %||% fit$neg_ll %||% get_zinb_neg_loglik_cpp(X = X, y = as.numeric(y_sim), Xzi = Xzi, params))
					} else {
						as.numeric(fit$neg_loglik %||% fit$neg_ll)
					}
				}
			)
		}
	)
)

InferenceCountZeroAugmentedPoissonAbstract = define_inference_class(
	classname = "InferenceCountZeroAugmentedPoissonAbstract",
	inherit = Inference,
	# 2026-08-21 (fix_inference_hierarchy.md per-class migration ladder):
	# composes the already-registered ZeroAugmentedCountLikelihood component
	# (source built from inference_count_za_public/_private above as a
	# static plain-list object -- the pre-existing inference_component_
	# source_parts(InferenceCountZeroAugmentedPoissonAbstract) post-hoc
	# harvesting this file used to end with breaks once the class itself is
	# rebuilt via define_inference_class(), since the merged generator's
	# $public_methods/$private_methods would then include every composed
	# component's own methods too -- same fix as InferenceIncidLogRegr's
	# migration earlier in this push). ZeroAugmentedCountLikelihood already
	# declares dependencies = "CountLikelihoodPlumbing"; ParametricLikelihood
	# Bootstrap pulls in LikelihoodTests -> Wald -> NonparametricBootstrap.
	# Since v1.0.5 TODO-97 the randomization CI / rand-bootstrap CI and
	# Jackknife components are listed explicitly (they used to arrive through
	# packaging-only dependency edges).
	components = c(
		"RandomizationCI",
		"RandomizationBootstrapCI",
		"BayesianBootstrap",
		"Jackknife",
		"ParametricLikelihoodBootstrap",
		"ZeroAugmentedCountLikelihood"
	),
	metadata = list(abstract = TRUE, likelihood_tier = "full", response_types = "count"),
	overrides = list(
		public = c(
			"compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"compute_rand_two_sided_pval", "get_supported_testing_types", "set_testing_type",
			"compute_wald_two_sided_pval", "compute_wald_confidence_interval",
			"compute_score_two_sided_pval", "compute_score_confidence_interval",
			"compute_lik_ratio_two_sided_pval", "compute_lik_ratio_confidence_interval",
			"compute_gradient_two_sided_pval", "compute_gradient_confidence_interval",
			"compute_lik_ratio_bootstrap_two_sided_pval", "compute_lik_ratio_bootstrap_confidence_interval",
			"compute_jackknife_estimate", "compute_jackknife_bias_estimate",
			"compute_jackknife_std_error", "compute_jackknife_wald_two_sided_pval",
			"compute_jackknife_wald_confidence_interval",
			"compute_bootstrap_two_sided_pval", "compute_bootstrap_confidence_interval",
			"compute_bayesian_bootstrap_two_sided_pval", "compute_bayesian_bootstrap_confidence_interval"
		),
		private = c(
			"cached_mod", "cached_vc_params", "supports_lik_ratio_param_bootstrap", "supports_likelihood_tests",
			"supports_lik_ratio_param_bootstrap_confidence_interval",
			"simulate_under_lik_null", "get_likelihood_test_spec",
			"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker", "create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker", "compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl",
			"supports_bartlett_likelihood_ratio_approx", "get_bartlett_factor_approx",
			"get_standard_error", "get_degrees_of_freedom",
			"compute_score_two_sided_pval_impl", "compute_score_confidence_interval_impl",
			"compute_gradient_two_sided_pval_impl", "compute_gradient_confidence_interval_impl",
			"compute_lik_ratio_two_sided_pval_impl", "compute_lik_ratio_confidence_interval_impl",
			"compute_treatment_estimate_during_randomization_inference", "get_complexity_tier"
		)
	)
)

# TRUE when a zero-augmented Poisson fit is degenerate and no SE derived from it
# can be trusted: e.g. every y == 1 under a hurdle, where the zero-truncated
# Poisson likelihood only improves as lambda -> 0 (no MLE; the optimizer stops at
# an arbitrary boundary point with absurd coefficient SEs). Judged on the fit's
# own model-based covariance: it must have a strictly positive diagonal and be
# well conditioned, and the conditional intercept must not sit at the
# lambda ~ 0 boundary. Calibrated 2026-09-22
# (test-degenerate-fit-threshold-calibration.R): across a spectrum of
# increasing hurdle-side separation, legitimate fits' rcond clustered at
# 1e-3..1e-2 and degenerate fits' at 1e-11..1e-15 with no observed case in
# between (a 6-8 order-of-magnitude gap around the 1e-10 threshold); a
# rare-but-real fit (few positive counts, both treatment arms represented)
# stayed >= 6e-4/-1.2 respectively, far from either threshold.
zero_augmented_fit_is_degenerate = function(vcov, params) {
	vcov = as.matrix(vcov)
	if (!length(vcov) || any(!is.finite(vcov))) return(TRUE)
	if (any(diag(vcov) <= .Machine$double.eps)) return(TRUE)
	rc = tryCatch(rcond(vcov), error = function(e) NA_real_)
	if (!is.finite(rc) || rc < 1e-10) return(TRUE)
	length(params) >= 1L && is.finite(params[1L]) && params[1L] < -15
}

# TRUE when a HURDLE fit has no MLE by construction: every positive count equals 1,
# so the zero-truncated Poisson likelihood only improves as lambda -> 0. Decided from
# the data alone, so the outcome cannot depend on what an optimizer/TMB build returns.
# Since v1.0.6-TODO-195 (3) the full fit is NA on such data (and whenever one
# arm's positive counts are all 1, zero_augmented_count_mle_infinite_arms()), so
# this SE-side check is only a backstop.
zero_augmented_data_has_no_mle = function(y, is_hurdle) {
	if (!isTRUE(is_hurdle)) return(FALSE)
	pos = as.numeric(y)
	pos = pos[is.finite(pos) & pos > 0]
	length(pos) > 0L && all(pos == 1)
}

# v1.0.6-TODO-186: TRUE when the rows with a positive count identify the
# count-part treatment coefficient, i.e. dropping the treatment column from
# those rows of the count design lowers its rank. For a hurdle the likelihood
# factors into the binary part and a zero-truncated count part fit to the
# positive rows only; ZIP/ZINB factor the same way (P(y > 0) times the
# zero-truncated density), and since the zero part has its own treatment term,
# the count-part treatment coefficient is again learned from the positive rows
# only. When those rows do not identify it (e.g. one positive count, more count
# parameters than positive rows, or every positive row in one arm), the
# likelihood is flat along the treatment direction. The optimizer then returns
# its warm start, so every randomization replicate equalled the observed estimate
# instead of responding to the permuted assignment. Decided from the design and
# data alone, so the outcome does not depend on the optimizer.
zero_augmented_count_treatment_identified = function(X_fit, y, j_treat = 2L, weights = NULL) {
	X_fit = as.matrix(X_fit)
	y = as.numeric(y)
	if (!is.finite(j_treat) || j_treat < 1L || j_treat > ncol(X_fit) || nrow(X_fit) != length(y)) return(FALSE)
	keep = is.finite(y) & y > 0
	if (!is.null(weights)) keep = keep & is.finite(as.numeric(weights)) & as.numeric(weights) > 0
	if (!any(keep)) return(FALSE)
	X_pos = X_fit[keep, , drop = FALSE]
	if (any(!is.finite(X_pos))) return(FALSE)
	qr(X_pos)$rank > qr(X_pos[, -j_treat, drop = FALSE])$rank
}

# v1.0.6-TODO-195 (4), 2026-11-19: R-side argument check before the zero-augmented
# and hurdle count kernels (fast_zero_augmented_poisson_cpp(),
# fast_hurdle_negbin_cpp() / _with_var_cpp(), fast_truncated_negbin_count_cpp(),
# fast_hurdle_poisson_glmm_cpp()). Until the owner rebuilds with the C++ checks of
# the same item, a NULL / empty y, a y whose length differs from nrow(X), or a
# second design (Xzi / X_hurdle) or group_id of another length crashed R
# (y = numeric(0) segfaulted) or read past the end of y and returned a
# "converged" fit of garbage. The callers wrap the kernels in tryCatch(), so the
# error becomes a failed (NA) fit, never a crash.
edi_check_count_kernel_inputs = function(kernel, X, y, X2 = NULL, group_id = NULL, X2_name = "Xzi") {
	if (is.null(y)) stop(kernel, ": y must be a numeric vector with one entry per row of X (got NULL)", call. = FALSE)
	if (!is.numeric(y) && !is.logical(y)) stop(kernel, ": y must be a numeric vector", call. = FALSE)
	n = NROW(X)
	if (!length(y) || !n) {
		stop(kernel, ": y and X must have at least one row (y has ", length(y), " entries, X has ", n, " rows)", call. = FALSE)
	}
	if (length(y) != n) stop(kernel, ": y has ", length(y), " entries but X has ", n, " rows", call. = FALSE)
	if (!is.null(X2) && NROW(X2) != n) stop(kernel, ": ", X2_name, " has ", NROW(X2), " rows but X has ", n, " rows", call. = FALSE)
	if (!is.null(group_id) && length(group_id) != n) {
		stop(kernel, ": group_id has ", length(group_id), " entries but X has ", n, " rows", call. = FALSE)
	}
	invisible(TRUE)
}

# v1.0.6-TODO-195 (3), 2026-11-19: the arms (values of the treatment column) in
# which every positive count equals 1. A zero-truncated count density (Poisson or
# negative binomial) at y = 1 only increases as the rate goes to 0, so when every
# positive row of one arm has y = 1 the likelihood keeps increasing along the
# direction that lowers that arm's rate alone (-treatment for the treated arm;
# -intercept + treatment for the control arm), whatever the covariates, and the
# count-part treatment coefficient has no finite MLE. pscl::hurdle() then
# "converges" to a coefficient of -13 or +11 with a standard error in the
# hundreds; when every positive count equals 1 the intercept runs off instead and
# the treatment coefficient is arbitrary. Hurdle (and KK hurdle) count parts
# only: a zero-INFLATED count part also models the zeros, so its rate is not
# pushed to 0. Rows are those with y > 0 (and positive weight); an arm with no
# positive rows is the TODO-186 unidentified case, not this one. Decided from the
# data alone, so the outcome does not depend on where an optimizer stops.
zero_augmented_count_mle_infinite_arms = function(X_fit, y, j_treat = 2L, weights = NULL) {
	X_fit = as.matrix(X_fit)
	y = as.numeric(y)
	if (!is.finite(j_treat) || j_treat < 1L || j_treat > ncol(X_fit) || nrow(X_fit) != length(y)) return(numeric())
	rows = is.finite(y) & y > 0
	if (!is.null(weights)) rows = rows & is.finite(as.numeric(weights)) & as.numeric(weights) > 0
	if (!any(rows)) return(numeric())
	arm = as.numeric(X_fit[rows, j_treat])
	arms = sort(unique(arm))
	if (length(arms) != 2L) return(numeric())
	y_pos = y[rows]
	arms[vapply(arms, function(a) all(y_pos[arm == a] == 1), logical(1))]
}

zero_augmented_count_mle_infinite = function(X_fit, y, j_treat = 2L, weights = NULL) {
	length(zero_augmented_count_mle_infinite_arms(X_fit, y, j_treat, weights)) > 0L
}

# Full-data fit only (silent inside resampling): the hurdle count-part treatment
# estimate is NA because its MLE is not finite (see
# zero_augmented_count_mle_infinite_arms()). One edi_procedure_na_warning of
# class edi_hurdle_count_mle_not_finite_warning, procedure "estimate", once per
# object.
edi_warn_hurdle_count_mle_not_finite = function(self, private, arms, reason = "hurdle_count_mle_not_finite", kk_reservoir = FALSE) {
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	# once per object: the nonestimable fit is redone by later calls (CI, p-value)
	if (isTRUE(private$cached_values$hurdle_count_mle_not_finite_warned)) return(invisible(FALSE))
	private$cached_values$hurdle_count_mle_not_finite_warned = TRUE
	arms = as.numeric(arms)
	which_arms = if (length(arms) >= 2L) "both arms" else if (isTRUE(arms == 1)) "the treated arm (w = 1)" else "the control arm (w = 0)"
	edi_warn_procedure_na(self, private, procedure = "estimate", reason = reason,
		detail = paste0(
			if (isTRUE(kk_reservoir)) paste0("In ", which_arms, " every positive matched count equals 1 and every reservoir count is 0. ")
			else paste0("Every positive count in ", which_arms, " equals 1. "),
			"The count part's likelihood then keeps increasing as the rate in ",
			if (length(arms) >= 2L) "either arm" else "that arm", " goes to 0, so the count-part treatment coefficient ",
			"has no finite maximum likelihood estimate (pscl::hurdle() reports a very large coefficient with a ",
			"standard error in the hundreds). Inference built on this estimate is NA as well",
			if (isTRUE(kk_reservoir) || grepl("^kk_", reason)) "." else "; the hurdle (zero vs. positive) part is unaffected."
		),
		warning_class = "edi_hurdle_count_mle_not_finite_warning")
}

# v1.0.6-TODO-195 item (2), owner decision 2026-11-19: the count-part coefficients
# are learned from the rows with a positive count (see
# zero_augmented_count_treatment_identified()), so a count-part covariate that is
# aliased on those rows (constant there, or a linear combination of the intercept,
# the treatment and the covariates before it) is not identified even when it varies
# over the full sample. Drop such columns before fitting, as stats::glm does with
# its pivoted QR (glm keeps them and reports NA coefficients): the order is the
# intercept, then the treatment, then the covariates in design order, and a column
# is dropped when it adds no rank given the columns kept before it. The treatment
# is never dropped: when it is itself aliased (with the intercept alone, e.g. every
# positive row in one arm), X_fit is returned unchanged and the TODO-186 guard
# makes the fit non-estimable. The QR is the one kk_strat_cox_drop_within_strata_
# aliased_cols() (v1.0.6-TODO-128) uses, with a single stratum: removing the
# column means is the same as putting the intercept first. Rows are those with
# y > 0 (and positive weight). Returns list(X, keep, dropped); with nothing to
# drop, X is X_fit itself.
zero_augmented_drop_aliased_count_cols = function(X_fit, y, j_treat = 2L, weights = NULL) {
	X_fit = as.matrix(X_fit)
	p = ncol(X_fit)
	unchanged = list(X = X_fit, keep = seq_len(p), dropped = character())
	if (p <= 2L || !identical(as.integer(j_treat), 2L) || nrow(X_fit) != length(y)) return(unchanged)
	y = as.numeric(y)
	rows = is.finite(y) & y > 0
	if (!is.null(weights)) rows = rows & is.finite(as.numeric(weights)) & as.numeric(weights) > 0
	if (!any(rows)) return(unchanged)
	X_pos = X_fit[rows, , drop = FALSE]
	if (any(!is.finite(X_pos))) return(unchanged)
	# column 1 is the intercept: centring (one stratum) accounts for it
	cols = seq.int(2L, p)
	X_c = X_pos[, cols, drop = FALSE]
	colnames(X_c) = as.character(cols)
	kept = as.integer(colnames(kk_strat_cox_drop_within_strata_aliased_cols(X_c, rep(1L, nrow(X_c)))))
	if (length(kept) == length(cols) || !(2L %in% kept)) return(unchanged)
	keep = c(1L, sort(kept))
	nms = colnames(X_fit)
	list(X = X_fit[, keep, drop = FALSE], keep = keep,
		dropped = if (is.null(nms)) paste0("column ", setdiff(seq_len(p), keep)) else nms[setdiff(seq_len(p), keep)])
}

# Class-side wrapper used by every fit path of the zero-augmented count classes
# (full fit, randomization refit, weighted bootstrap; the reusable bootstrap
# worker and the slow path refit through the full fit). Only with harden = TRUE
# (the default), like the package's other column drops. warn = TRUE (full fit
# only) raises the edi_covariate_dropped_warning once per object, never inside a
# resampling operation.
edi_zero_augmented_drop_aliased_count_cols = function(self, private, X_fit, weights = NULL, warn = FALSE) {
	if (!isTRUE(private$harden)) return(X_fit)
	res = zero_augmented_drop_aliased_count_cols(X_fit, private$y, j_treat = 2L, weights = weights)
	if (length(res$dropped) && isTRUE(warn)) {
		edi_warn_covariate_dropped_once(self, private, res$dropped, "aliased_on_positive_rows")
	}
	res$X
}

# v1.0.6-TODO-222 (2026-11-19; found under v1.1.0-TODO-217): ZINB negative log-likelihood in R, for comparing two
# fast_zinb_cpp() fits (its estimate_only results carry no neg_loglik). params =
# c(beta_count, beta_zero, log_theta), the C++ layout; zi_off = TRUE evaluates the
# zero-inflation-off limit (pi = 0), which is what a "NegBinNoZI" boundary fit stands for.
zinb_neg_loglik_r = function(params, X, Xzi, y, zi_off = FALSE) {
	p = ncol(X); pz = ncol(Xzi)
	params = as.numeric(params)
	if (length(params) != p + pz + 1L || any(!is.finite(params))) return(NA_real_)
	mu = exp(drop(X %*% params[seq_len(p)]))
	theta = exp(params[p + pz + 1L])
	ll_nb = stats::dnbinom(y, size = theta, mu = mu, log = TRUE)
	if (isTRUE(zi_off)) return(-sum(ll_nb))
	eta_z = drop(Xzi %*% params[p + seq_len(pz)])
	log_pi = stats::plogis(eta_z, log.p = TRUE)
	log_1mpi = stats::plogis(eta_z, lower.tail = FALSE, log.p = TRUE)
	ll = ifelse(y == 0, pmax(log_pi, log_1mpi + ll_nb) + log1p(exp(-abs(log_pi - (log_1mpi + ll_nb)))), log_1mpi + ll_nb)
	-sum(ll)
}

# v1.0.6-TODO-222 (2026-11-19; found under v1.1.0-TODO-217): fast_zinb_cpp() with a guard against a wrong
# (non-MLE) fit. Newton-Raphson (the class default), started from a warm start
# such as the full-data MLE, has two failure modes on ZINB data whose
# zero-inflation logit is flat or separated:
#   * it steps into the region where every zero-inflation linear predictor is
#     below -10, and fast_zinb.cpp's fit_zinb_zi_boundary_fallback() accepts the
#     zero-inflation-off NegBin fit ("NegBinNoZI", zero_inflation_at_boundary =
#     TRUE) without checking that an interior fit has a lower negative
#     log-likelihood;
#   * it runs off along a separation ridge (zero-inflation coefficients ~1e5)
#     and accept_zinb_near_stationary_gradient() reports converged = TRUE with a
#     gradient norm ~1e-2, at a higher negative log-likelihood than the MLE.
# Randomization draws are warm-started from the full-data fit, so on the
# calibration DGP 13-14% of draws returned a wrong treatment estimate (36% when
# chained, the pre-c28bbb34 loop) and the randomization test was oversized.
# When a fit looks suspect (at the zero-inflation boundary, a zero-inflation
# coefficient beyond +-10, or a gradient norm above 1e-5), the data have zeros
# and no zero-inflation coefficient is fixed, it is refit with L-BFGS from the
# same start and from the cold start (and with the caller's algorithm from the
# cold start when a warm start was given); the fit with the lowest negative
# log-likelihood is kept (a refit must improve it by more than 1e-6). The root
# cause is in C++ (both acceptance paths should compare likelihoods); this R
# guard avoids a rebuild and is local to the ZINB fits. Remove it once both C++
# acceptance paths compare likelihoods (the root fix in v1.0.6-TODO-222).
fast_zinb_cpp_guarded = function(...) {
	args = list(...)
	# v1.0.6-TODO-30: never warm-start from a zero part on the ridge (see
	# zero_augmented_warm_start_on_ridge()); such a start is dropped (cold start).
	if (!is.null(args$warm_start_params) && !is.null(args$X) && !is.null(args$Xzi) &&
			zero_augmented_warm_start_on_ridge(args$Xzi, args$warm_start_params, ncol(args$X))) {
		args["warm_start_params"] = list(NULL)
		args["warm_start_fisher_info"] = list(NULL)
	}
	fit = do.call(fast_zinb_cpp, args)
	X = args$X; Xzi = args$Xzi; y = as.numeric(args$y)
	p = ncol(X); pz = ncol(Xzi)
	if (!any(y == 0) || any(as.integer(args$fixed_idx) %in% (p + seq_len(pz)))) return(fit)
	fit_nll = function(f) {
		if (is.null(f) || !isTRUE(f$converged)) return(Inf)
		v = zinb_neg_loglik_r(f$params, X, Xzi, y, zi_off = isTRUE(f$zero_inflation_at_boundary))
		if (is.finite(v)) v else Inf
	}
	params = as.numeric(fit$params)
	gn = suppressWarnings(as.numeric(fit$gradient_norm %||% NA_real_)[1L])
	suspect = !isTRUE(fit$converged) || isTRUE(fit$zero_inflation_at_boundary) ||
		(length(params) == p + pz + 1L && any(abs(params[p + seq_len(pz)]) > 10)) ||
		(is.finite(gn) && gn > 1e-5)
	if (!suspect) return(fit)
	best = fit_nll(fit)
	alg = args$optimization_alg %||% "lbfgs"
	refit = function(start, algorithm) {
		alt_args = args
		alt_args["warm_start_params"] = list(start)
		alt_args["warm_start_fisher_info"] = list(NULL)
		alt_args$optimization_alg = algorithm
		tryCatch(do.call(fast_zinb_cpp, alt_args), error = function(e) NULL)
	}
	alts = list(refit(NULL, "lbfgs"))
	if (!is.null(args$warm_start_params)) {
		alts = c(alts, list(refit(args$warm_start_params, "lbfgs")))
		if (!identical(alg, "lbfgs")) alts = c(alts, list(refit(NULL, alg)))
	}
	for (alt in alts) {
		v = fit_nll(alt)
		if (v < best - 1e-6) {
			fit = alt
			best = v
		}
	}
	fit
}

# v1.0.6-TODO-30 / v1.0.6-TODO-152 (2026-11-19): the zero-inflation (or hurdle)
# part of a zero-augmented Poisson fit often has no finite maximum: some fitted
# zero probabilities run off to 0 or 1 along a flat ridge (e.g. zero intercept
# -23.8 and zero treatment +23.8, or a saturated -234.6 / +121 on plain Poisson
# data). Two consequences, handled by the helpers below:
#   * a fit warm-started from such a point cannot move its zero part (the
#     zero-part gradient there is ~0), so a randomization / bootstrap replicate
#     started from a ridge full-data fit stays near the full-data zero part and
#     lands 0.05-15 log-likelihood units below the fresh fit on the same data.
#     A ridge warm start is therefore dropped and the replicate is cold-started,
#     exactly as a fresh fit is (zero_augmented_warm_start_on_ridge()).
#   * the default (smart) cold start can stop at an interior local maximum while
#     the supremum is out on the ridge, or stop early on the ridge. Each ZIP fit
#     is therefore also run with L-BFGS from pscl::zeroinfl()'s default start (a
#     Poisson GLM for the count part and a logistic GLM of 1(y == 0) for the zero
#     part), and the fit with the lower negative log-likelihood is kept; the
#     candidate must improve it by more than 1e-6, so a fit already at the
#     maximum is returned unchanged (fast_zero_augmented_poisson_cpp_guarded()).
# A warm start is "on the ridge" when any subject's zero-part linear predictor
# is at least ZERO_AUGMENTED_RIDGE_ETA_EDGE = 10 in absolute value (a fitted zero
# probability below 4.5e-5 or above 1 - 4.5e-5). In a 600-dataset sweep (n = 24
# to 150, ZIP / plain Poisson / heavy-inflation DGPs) interior maxima whose
# zero part pscl reproduces stay below 8 except where one covariate-extreme
# subject reaches 10-24; dropping such a start costs one cold start and does
# not change the maximum.
ZERO_AUGMENTED_RIDGE_ETA_EDGE = 10
# v1.0.6-TODO-218 (1): see zero_augmented_zero_part_separation().
ZERO_AUGMENTED_NO_INFLATION_MAX_LOGIT = stats::qlogis(0.05)

# Zero-part linear predictor Xzi %*% gamma for a stacked params vector
# c(beta_count, gamma_zero[, log_theta]); NULL when it cannot be formed.
zero_augmented_zero_part_eta = function(Xzi, params, n_cond) {
	params = as.numeric(params)
	n_zi = ncol(Xzi)
	if (length(params) < n_cond + n_zi) return(NULL)
	gamma = params[n_cond + seq_len(n_zi)]
	if (any(!is.finite(gamma))) return(NULL)
	as.numeric(Xzi %*% gamma)
}

# TRUE when a warm start should not be used for a zero-augmented fit: its zero
# part is on the flat ridge (see above), it cannot be evaluated, or (ZINB) it is
# a zero-inflation-off boundary fit.
zero_augmented_warm_start_on_ridge = function(Xzi, params, n_cond, at_boundary = FALSE, edge = ZERO_AUGMENTED_RIDGE_ETA_EDGE) {
	if (is.null(params)) return(FALSE)
	if (isTRUE(at_boundary)) return(TRUE)
	eta = zero_augmented_zero_part_eta(Xzi, params, n_cond)
	is.null(eta) || any(abs(eta) >= edge)
}

# Negative log-likelihood of a zero-inflated Poisson mixture (not hurdle) at
# params = c(beta_count, gamma_zero), computed stably on the log scale.
zip_neg_loglik_r = function(params, X, Xzi, y) {
	if (is.null(X) || is.null(Xzi)) return(NA_real_)
	p = ncol(X); pz = ncol(Xzi)
	params = as.numeric(params)
	if (length(params) != p + pz || any(!is.finite(params))) return(NA_real_)
	eta_c = drop(X %*% params[seq_len(p)])
	ll_pois = stats::dpois(y, exp(eta_c), log = TRUE)
	eta_z = drop(Xzi %*% params[p + seq_len(pz)])
	log_pi = stats::plogis(eta_z, log.p = TRUE)
	log_1mpi = stats::plogis(eta_z, lower.tail = FALSE, log.p = TRUE)
	a = log_pi; b = log_1mpi + ll_pois
	ll = ifelse(y == 0, pmax(a, b) + log1p(exp(-abs(a - b))), b)
	-sum(ll)
}

# pscl::zeroinfl()'s default starting values (dist = "poisson", EM = FALSE),
# reimplemented so pscl is not needed at run time: the count part is a Poisson
# GLM of y on X and the zero part a logistic GLM of 1(y == 0) on Xzi, both on
# all rows. Fitted with EDI's IRLS kernels; under separation the logistic fit
# stops with large coefficients, as glm.fit() does, and that point is still a
# usable start. Coefficients the kernel cannot estimate start at 0. NULL when no
# finite start results.
zero_augmented_pscl_start = function(X, y, Xzi) {
	irls_coef = function(f, M, resp) {
		b = tryCatch(as.numeric(f(M, resp, estimate_only = TRUE)$b), error = function(e) NULL)
		if (length(b) != ncol(M)) return(NULL)
		b[!is.finite(b)] = 0
		b
	}
	b_count = irls_coef(fast_poisson_regression_cpp, X, as.numeric(y))
	b_zero = irls_coef(fast_logistic_regression_cpp, Xzi, as.numeric(y == 0))
	if (is.null(b_count) || is.null(b_zero)) return(NULL)
	c(b_count, b_zero)
}

# fast_zero_augmented_poisson_cpp() with the two guards described above: a
# warm start on the zero-inflation ridge is dropped (cold start), and for a ZIP
# mixture (not hurdle) whose data have zeros and whose zero part is free, a
# second L-BFGS fit from pscl's start is kept when it lowers the negative
# log-likelihood by more than 1e-6. The candidate is tried only when the primary
# fit converged, so an unconverged primary fit still reaches the callers' own
# recovery paths unchanged. The hurdle likelihood factorizes into two concave
# GLM-type parts (no local maxima), so it gets the warm-start guard only.
fast_zero_augmented_poisson_cpp_guarded = function(X, y, Xzi, is_hurdle = FALSE, warm_start_params = NULL,
		warm_start_fisher_info = NULL, smart_cold_start = TRUE, estimate_only = FALSE,
		optimization_alg = "lbfgs", fixed_idx = NULL, fixed_values = NULL) {
	edi_check_count_kernel_inputs("fast_zero_augmented_poisson_cpp", X, y, Xzi)
	y = as.numeric(y)
	if (!is.null(warm_start_params) && zero_augmented_warm_start_on_ridge(Xzi, warm_start_params, ncol(X))) {
		warm_start_params = NULL
		warm_start_fisher_info = NULL
	}
	fit_from = function(start, fisher, smart, alg) fast_zero_augmented_poisson_cpp(
		X, y, Xzi,
		is_hurdle = is_hurdle,
		warm_start_params = start,
		warm_start_fisher_info = fisher,
		smart_cold_start = smart,
		estimate_only = estimate_only, optimization_alg = alg,
		fixed_idx = fixed_idx, fixed_values = fixed_values
	)
	fit = fit_from(warm_start_params, warm_start_fisher_info, smart_cold_start, optimization_alg)
	if (isTRUE(is_hurdle) || !isTRUE(fit$converged) || !any(y == 0)) return(fit)
	n_cond = ncol(X)
	if (any(as.integer(fixed_idx) %in% (n_cond + seq_len(ncol(Xzi))))) return(fit)
	start = zero_augmented_pscl_start(X, y, Xzi)
	if (is.null(start)) return(fit)
	if (length(fixed_idx)) start[as.integer(fixed_idx)] = as.numeric(fixed_values)
	alt = tryCatch(fit_from(start, NULL, FALSE, "lbfgs"), error = function(e) NULL)
	if (is.null(alt) || !isTRUE(alt$converged)) return(fit)
	v_fit = zip_neg_loglik_r(fit$params, X, Xzi, y)
	v_alt = zip_neg_loglik_r(alt$params, X, Xzi, y)
	if (is.finite(v_alt) && (!is.finite(v_fit) || v_alt < v_fit - 1e-6)) {
		alt$start_candidate = "pscl_start_lbfgs"
		return(alt)
	}
	fit
}

# v1.0.6-TODO-152 (2026-11-19): is the zero-inflation (or hurdle) part of a
# full-data fit separated, i.e. on the ridge where its likelihood has no finite
# maximum? Two rules, either suffices:
#   * a fitted zero probability is numerically 0 or 1: |Xzi gamma| >=
#     qlogis(1 - 1e-8) ~ 18.4 for some subject, the rule
#     edi_logistic_n_fitted_extreme() applies to logistic fits; or
#   * the fit stopped earlier on the ridge: some |Xzi gamma| >= 10 and the
#     zero-part block of the observed information is not positive definite or
#     has smallest / largest eigenvalue below 1e-5 (a flat direction). Interior
#     maxima with one covariate-extreme subject keep that ratio above ~3e-4.
# A ZINB fit at its zero-inflation-off boundary (zero_inflation_at_boundary) is
# separated by definition. v1.0.6-TODO-218 (1), owner 2026-11-19: a separated
# zero-INFLATION part (not a hurdle) whose ridge points only toward "no
# inflation" -- every subject the ridge drives to the boundary is driven to
# pi -> 0, and no subject has a fitted inflation probability above 5% (zero logit
# <= qlogis(0.05) ~ -2.94, ZERO_AUGMENTED_NO_INFLATION_MAX_LOGIT) -- is the benign
# case of no (or arm-specific no) excess zeros, flagged no_inflation = TRUE; the
# ZINB zero-inflation-off boundary fit is the extreme of this. Callers give a
# message, not a warning. A subject pushed to pi ~ 1, or a sizeable fitted
# inflation anywhere next to subjects pushed to 0 (mixed directions), keeps the
# separation warning. On plain Poisson / negative-binomial data the MLE typically
# sends one arm to pi -> 0 and leaves the other at a small interior pi (0.5-4%),
# hence the 5% bound rather than "every logit <= -10".
# Returns list(separated, no_inflation, n_to_zero, max_pi, n_extreme, max_abs_eta).
# zero_info (v1.0.6-TODO-218 (2)): the zero-part block of the observed
# information, for a caller whose fit is not a ZIP / ZINB / hurdle-Poisson kernel
# fit (InferenceCountHurdleNegBin's separately fitted logistic hurdle part); fit
# then only needs params = c(<n_cond placeholders>, gamma).
zero_augmented_zero_part_separation = function(fit, X, y, Xzi, is_hurdle = FALSE, is_zinb = FALSE, zero_info = NULL) {
	none = list(separated = FALSE, no_inflation = FALSE, n_to_zero = 0L, max_pi = NA_real_, n_extreme = 0L, max_abs_eta = NA_real_)
	params = as.numeric(fit$params)
	n_cond = ncol(X)
	n_zi = ncol(Xzi)
	eta = zero_augmented_zero_part_eta(Xzi, params, n_cond)
	if (is.null(eta)) return(none)
	max_abs_eta = max(abs(eta))
	n_extreme = as.integer(sum(abs(eta) >= stats::qlogis(1 - 1e-8)))
	zinb_off = isTRUE(is_zinb) && isTRUE(fit$zero_inflation_at_boundary)
	out = list(
		separated = TRUE,
		no_inflation = !isTRUE(is_hurdle) && (zinb_off || all(eta <= ZERO_AUGMENTED_NO_INFLATION_MAX_LOGIT)),
		n_to_zero = if (zinb_off) length(eta) else as.integer(sum(eta <= -ZERO_AUGMENTED_RIDGE_ETA_EDGE)),
		max_pi = if (zinb_off) 0 else stats::plogis(max(eta)),
		n_extreme = n_extreme, max_abs_eta = max_abs_eta
	)
	if (zinb_off || n_extreme > 0L) return(out)
	if (max_abs_eta < ZERO_AUGMENTED_RIDGE_ETA_EDGE) return(none)
	if (!is.null(zero_info)) {
		info = as.matrix(zero_info)
		if (nrow(info) != n_zi || ncol(info) != n_zi) return(out)
	} else {
		H = tryCatch(
			if (isTRUE(is_zinb)) get_zinb_hessian_cpp(X, as.numeric(y), Xzi, params)
			else get_zero_augmented_poisson_hessian_cpp(X, as.numeric(y), Xzi, params, isTRUE(is_hurdle)),
			error = function(e) NULL
		)
		idx = n_cond + seq_len(n_zi)
		if (is.null(H) || nrow(as.matrix(H)) < max(idx)) return(out)
		info = -as.matrix(H)[idx, idx, drop = FALSE]
	}
	if (any(!is.finite(info))) return(out)
	ev = eigen((info + t(info)) / 2, symmetric = TRUE, only.values = TRUE)$values
	if (min(ev) <= 0 || min(ev) / max(ev) < 1e-5) out else none
}

# v1.0.6-TODO-152: after an accepted full-data fit (never inside resampling), mark
# a separated zero part nonestimable and warn once per object. The zero-part
# rows of the summary table become NA (the coefficients are wherever the
# optimizer stopped on the ridge, and their standard errors are meaningless);
# the count-part treatment estimate is kept, since the count part is identified
# in the ridge limit (it matches pscl::zeroinfl, which runs further along the
# ridge). The warning has class edi_zero_part_separation_warning, a subclass of
# edi_logistic_separation_warning, so suppressing either class silences it.
# v1.0.6-TODO-218 (1), owner 2026-11-19: when the zero-inflation part is pushed to
# "no inflation" for every subject (no excess zeros; see
# zero_augmented_zero_part_separation()'s no_inflation), the rows are still NA but
# the condition is a message of class edi_no_zero_inflation_message, not the
# warning (reason "no_zero_inflation"). A hurdle part has no such benign case: its
# zero probabilities model observed zeros, so a saturated hurdle part is ordinary
# logistic separation and keeps the warning.
edi_zero_augmented_flag_zero_part_separation = function(self, private, fit, X_fit, Xzi_fit, is_hurdle = FALSE, is_zinb = FALSE, zero_info = NULL) {
	private$cached_values$zero_part_nonestimable_reason = NULL
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	# Data with no zeros get the non-inflated fit with the zero part fixed at
	# pi ~ 0 by design (zero_inflation_fixed_args()); that is not separation.
	if (isTRUE(private$cached_values$zero_inflation_fallback)) return(invisible(FALSE))
	sep = tryCatch(
		zero_augmented_zero_part_separation(fit, X_fit, private$y, Xzi_fit, is_hurdle = is_hurdle, is_zinb = is_zinb, zero_info = zero_info),
		error = function(e) NULL
	)
	if (is.null(sep) || !isTRUE(sep$separated)) return(invisible(FALSE))
	component = if (isTRUE(is_hurdle)) "hurdle" else "zero"
	private$cached_values$zero_part_nonestimable_reason = if (isTRUE(sep$no_inflation)) "no_zero_inflation" else "zero_part_separated"
	if (!is.null(private$cached_values$zero_coefficients)) {
		private$cached_values$zero_coefficients[] = NA_real_
	}
	st = private$cached_values$summary_table
	if (!is.null(st)) {
		rows = startsWith(rownames(st), paste0(component, ":"))
		st[rows, ] = NA_real_
		private$cached_values$summary_table = st
	}
	if (isTRUE(private$cached_values$zero_part_separation_warned)) return(invisible(TRUE))
	private$cached_values$zero_part_separation_warned = TRUE
	if (isTRUE(sep$no_inflation)) {
		# v1.0.6-TODO-218 (1), owner 2026-11-19: no excess zeros is not a fault.
		count_model = if (isTRUE(is_zinb)) "negative binomial" else "Poisson"
		n_all = nrow(as.matrix(Xzi_fit))
		everyone = isTRUE(sep$max_pi <= 0.01)
		msg = paste0(
			class(self)[1], ": no evidence of zero inflation: ",
			if (everyone) "the fitted zero-inflation probability is essentially 0 for every subject"
			else paste0("the fitted zero-inflation probability is driven to 0 for ", sep$n_to_zero, " of ", n_all,
				" subjects (at most ", signif(100 * sep$max_pi, 2), "% for the rest)"),
			", so the zero-inflation coefficients are not identified and are reported as NA; ",
			"the count-part estimate is unaffected",
			if (everyone) paste0(" (a plain ", count_model, " model fits these data)") else "",
			". Suppress with suppressMessages(expr, classes = \"edi_no_zero_inflation_message\")."
		)
		message(structure(
			class = c("edi_no_zero_inflation_message", "message", "condition"),
			list(message = paste0(msg, "\n"), call = NULL, n_to_zero = sep$n_to_zero, n = n_all,
				max_pi = sep$max_pi, max_abs_eta = sep$max_abs_eta, component = component)
		))
		return(invisible(TRUE))
	}
	part = if (isTRUE(is_hurdle)) "hurdle (zero vs. positive)" else "zero-inflation"
	msg = paste0(
		class(self)[1], ": the ", part, " part is separated: ",
		if (sep$n_extreme > 0L) paste0(sep$n_extreme, " of ", nrow(as.matrix(Xzi_fit)), " fitted zero probabilities are numerically 0 or 1")
		else paste0("its likelihood is flat along a direction where a fitted zero logit reaches ", signif(sep$max_abs_eta, 3)),
		", so its maximum likelihood estimate does not exist and its coefficients are reported as NA. ",
		"The count-part treatment estimate is still reported; its standard error and Wald inference may be unreliable. ",
		"Consider randomization or bootstrap inference, or a simpler ", part, " formula. ",
		"Suppress with suppressWarnings(expr, classes = \"edi_zero_part_separation_warning\")."
	)
	warning(structure(
		class = c("edi_zero_part_separation_warning", "edi_logistic_separation_warning", "warning", "condition"),
		list(message = msg, call = NULL, n_extreme = sep$n_extreme, n = nrow(as.matrix(Xzi_fit)),
			max_abs_eta = sep$max_abs_eta, component = component, link = "logit")
	))
	invisible(TRUE)
}
