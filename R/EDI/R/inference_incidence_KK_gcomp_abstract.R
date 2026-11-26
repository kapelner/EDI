#' Marginal Standardization / G-Computation for Binary Responses in KK Designs
#'
#' Internal base class for all-subject incidence-outcome g-computation estimators
#' under KK matching-on-the-fly designs. A logistic working model is fit on all
#' subjects, then potential-outcome risks under all-treated and all-control
#' assignments are standardized over the empirical covariate distribution.
#' Inference uses a cluster-robust covariance where matched pairs form clusters
#' and reservoir subjects are singletons.
#'
#' @details
#' The implementation is optimized for high-throughput resampling. It leverages a
#' fast C++ IRLS solver for the logistic regression. During resampling (bootstrap
#' or randomization), it skips the computation of the cluster-robust sandwich
#' covariance matrix and delta-method variance components, focusing only on the
#' standardized effect estimate.
#'
#' @keywords internal
#' @noRd
InferenceIncidKKGCompAbstract = R6::R6Class("InferenceIncidKKGCompAbstract",
	lock_objects = FALSE,
	inherit = InferenceAbstractKKMarginalIncid,
	public = list(
		# 2026-08-19 (fix_inference_hierarchy.md "Full-Likelihood Estimators",
		# "ModifiedPoisson full-likelihood migration"): this class's own
		# `super$compute_bootstrap_confidence_interval()`/`super$compute_
		# bootstrap_two_sided_pval()`/`super$compute_bayesian_bootstrap_*()`/
		# `super$compute_jackknife_wald_*()` calls below were valid under the
		# old deep R6 ladder (reaching InferenceNonParamBootstrap/
		# InferenceBayesianBootstrap/InferenceJackknife's real generic
		# dispatch through true multi-level inheritance) but silently became
		# infinite self-recursion once its parent
		# `InferenceAbstractKKMarginalIncid` was migrated to flat
		# composition, where `super$X()` on a class with no further real R6
		# ancestor layer above the composed one can loop back into `self`
		# rather than erroring outright. Same "generic self-aliased
		# overrides" pattern already used by this file's separately-
		# harvested `IncidenceKKGComputationSource`/
		# `incidence_kk_gcomp_generic_alias_overrides` (which `modifyList()`s
		# these exact same aliases on top of this class's harvested body for
		# the real migrated `InferenceIncidKKGCompRiskDiff`/`RiskRatio`
		# classes -- unaffected either way, since its override already wins)
		# -- applying it here too makes this class self-sufficient
		# regardless of its ancestor's composition state, which also fixes
		# the test-only legacy R6 reconstruction in
		# test-incid-kk-gcomp-migration-golden.R that inherits this class
		# directly.
		compute_bootstrap_confidence_interval_generic = InferenceNonParamBootstrap$public_methods$compute_bootstrap_confidence_interval,
		compute_bootstrap_two_sided_pval_generic = InferenceNonParamBootstrap$public_methods$compute_bootstrap_two_sided_pval,
		compute_bayesian_bootstrap_two_sided_pval_generic = InferenceBayesianBootstrap$public_methods$compute_bayesian_bootstrap_two_sided_pval,
		compute_bayesian_bootstrap_confidence_interval_generic = InferenceBayesianBootstrap$public_methods$compute_bayesian_bootstrap_confidence_interval,
		compute_jackknife_wald_two_sided_pval_generic = InferenceJackknife$public_methods$compute_jackknife_wald_two_sided_pval,
		compute_jackknife_wald_confidence_interval_generic = InferenceJackknife$public_methods$compute_jackknife_wald_confidence_interval,
		#' @description Compute the KK g-computation treatment estimate by fitting the
		#'   logistic working model and standardizing predicted all-treated and
		#'   all-control risks over the empirical covariate distribution.
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$get_effect_estimate()
		},
		get_standard_error = function(){
			private$shared(estimate_only = FALSE)
			estimand = private$get_estimand_type()
			se = if (identical(estimand, "RD")) {
				private$cached_values$se_rd
			} else {
				private$cached_values$rr * private$cached_values$se_log_rr
			}
			if (is.null(se) || length(se) == 0L) {
				return(NA_real_)
			}
			as.numeric(se)[1L]
		},
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			if (weights_are_effectively_constant(row_weights)) {
				beta_hat_T = as.numeric(self$compute_estimate(estimate_only = TRUE))[1L]
				if (is.finite(beta_hat_T)) {
					# v1.0.6-TODO-100: constant weights are the unweighted fit, so its SE is this
					# draw's SE. Reuse a cached full-fit SE only (no refit here).
					se_const = if (isTRUE(estimate_only)) NA_real_ else
						suppressWarnings(as.numeric(private$cached_values$s_beta_hat_T %||% NA_real_)[1L])
					private$cached_values$beta_hat_T = beta_hat_T
					private$cached_values$s_beta_hat_T = if (length(se_const) == 1L && is.finite(se_const) && se_const > 0) se_const else NA_real_
					private$cached_values$gcomp_standardized_effects_inference_ready = FALSE
					return(private$cached_values$beta_hat_T)
				}
			}
			est_w = private$compute_weighted_gcomp_estimate(row_weights, with_se = !isTRUE(estimate_only))
			se_w = suppressWarnings(as.numeric(attr(est_w, "se", exact = TRUE) %||% NA_real_)[1L])
			private$cached_values$beta_hat_T = as.numeric(est_w)[1L]
			# v1.0.6-TODO-100: the Bayesian-bootstrap studentized path reads this draw's SE
			# (last_weighted_refit$s_beta_hat_T); weighted KK-pair cluster sandwich SE.
			private$cached_values$s_beta_hat_T = if (length(se_w) == 1L && is.finite(se_w) && se_w > 0) se_w else NA_real_
			private$cached_values$gcomp_standardized_effects_inference_ready = FALSE
			private$cached_values$beta_hat_T
		},
		#' @description Compute the KK g-computation asymptotic confidence interval
		#'   for the standardized risk difference or risk ratio using the
		#'   cluster-robust delta-method standard error. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for shared interval
		#'   semantics.
		#' @param alpha The significance level (default 0.05).
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
			}
			private$shared(estimate_only = FALSE)
			private$compute_effect_confidence_interval(alpha)
		},
		#' @description Compute the KK g-computation asymptotic two-sided p-value for
		#'   the standardized risk difference or risk ratio using the cluster-robust
		#'   delta-method standard error. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param delta The null treatment effect on the estimand's own scale. Defaults to 0 for RD and 1 for RR.
		compute_asymp_two_sided_pval = function(delta = NULL){
			private$shared(estimate_only = FALSE)
			private$compute_effect_pvalue(delta)
		},
		#' @description Compute Wald two sided pval for treatment effect.
		#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
		compute_wald_two_sided_pval = function(delta = NULL){
			private$shared(estimate_only = FALSE)
			private$compute_effect_pvalue(delta)
		},
		#' @description Compute Wald confidence interval.
		#' @param alpha The significance level (default 0.05).
		compute_wald_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
			}
			private$shared(estimate_only = FALSE)
			private$compute_effect_confidence_interval(alpha)
		},
		#' @description Compute bootstrap confidence interval
		#' @param alpha The significance level (default 0.05).
		#' @param B The number of bootstrap samples (default 501).
		#' @param type Bootstrap CI type. See \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
		#' @param na.rm Whether to remove NA values. (default \code{TRUE}).
		#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
		#' @param reimpute_missing_vals_each_resample Missing covariate values in the resamples: \code{FALSE}
		#'   (default) keeps the design's original imputation in every resample, \code{TRUE} re-runs it per
		#'   resample. See \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
		compute_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L, reimpute_missing_vals_each_resample = FALSE){
			gcomp_incid_bootstrap_confidence_interval(private, self$compute_bootstrap_confidence_interval_generic,
				alpha, B, type, na.rm, show_progress, min_number_usable_samples,
				reimpute_missing_vals_each_resample = edi_bootstrap_reimpute_forward(reimpute_missing_vals_each_resample, missing(reimpute_missing_vals_each_resample)))
		},
		#' @description Compute bootstrap two sided pval
		#' @param delta The null treatment effect on the estimand's own scale. Defaults to 0 for RD and 1 for RR.
		#' @param B The number of bootstrap samples (default 501).
		#' @param type Bootstrap p-value type. See \code{InferenceNonParamBootstrap$compute_bootstrap_two_sided_pval}.
		#' @param na.rm Whether to remove non-finite bootstrap replicates. Default
		#'   \code{FALSE}: any non-finite replicate makes the p-value \code{NA}, with a
		#'   once-per-object warning of class \code{edi_bootstrap_nonfinite_na_warning}.
		#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
		#' @param min_fraction_usable_samples Minimum fraction of the \code{B} replicates that must be
		#'   finite when \code{na.rm = TRUE}. Default 0.95. See
		#'   \code{InferenceNonParamBootstrap$compute_bootstrap_two_sided_pval}.
		#' @param reimpute_missing_vals_each_resample Missing covariate values in the resamples: \code{FALSE}
		#'   (default) keeps the design's original imputation in every resample, \code{TRUE} re-runs it per
		#'   resample. See \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
		compute_bootstrap_two_sided_pval = function(delta = NULL, B = 501, type = "symmetric", na.rm = FALSE, show_progress = TRUE, min_number_usable_samples = 5L, min_fraction_usable_samples = 0.95, reimpute_missing_vals_each_resample = FALSE){
			gcomp_incid_bootstrap_two_sided_pval(private, self$compute_bootstrap_two_sided_pval_generic,
				delta, B, type, na.rm, show_progress, min_number_usable_samples, min_fraction_usable_samples,
				reimpute_missing_vals_each_resample = edi_bootstrap_reimpute_forward(reimpute_missing_vals_each_resample, missing(reimpute_missing_vals_each_resample)))
		},
		#' @description Compute Bayesian-bootstrap two sided pval
		#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
		#' @param B The number of Bayesian-bootstrap samples (default 501).
		#' @param type Bayesian-bootstrap p-value type. See \code{InferenceBayesianBootstrap$compute_bayesian_bootstrap_two_sided_pval}.
		#' @param na.rm Whether to remove non-finite bootstrap replicates. Default
		#'   \code{FALSE}: any non-finite replicate makes the p-value \code{NA}, with a
		#'   once-per-object warning of class \code{edi_bootstrap_nonfinite_na_warning}.
		#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
		#' @param min_fraction_usable_samples Minimum fraction of the \code{B} replicates that must be
		#'   finite when \code{na.rm = TRUE}. Default 0.95. See
		#'   \code{InferenceBayesianBootstrap$compute_bayesian_bootstrap_two_sided_pval}.
		compute_bayesian_bootstrap_two_sided_pval = function(delta = NULL, B = 501, type = NULL, na.rm = FALSE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL, min_fraction_usable_samples = 0.95){
			gcomp_incid_bayesian_bootstrap_two_sided_pval(private, self$compute_bayesian_bootstrap_two_sided_pval_generic,
				delta, B, type, na.rm, show_progress, min_number_usable_samples, weighting_unit_type, min_fraction_usable_samples)
		},
		#' @description Compute Bayesian-bootstrap confidence interval
		#' @param alpha The significance level (default 0.05).
		#' @param B The number of Bayesian-bootstrap samples (default 501).
		#' @param type Bayesian-bootstrap CI type. See \code{InferenceBayesianBootstrap$compute_bayesian_bootstrap_confidence_interval}.
		#' @param na.rm Whether to remove NA values. (default \code{TRUE}).
		#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
		compute_bayesian_bootstrap_confidence_interval = function(alpha = 0.05, B = 501, type = NULL, na.rm = TRUE, show_progress = TRUE, min_number_usable_samples = 5L, weighting_unit_type = NULL){
			gcomp_incid_bayesian_bootstrap_confidence_interval(private, self$compute_bayesian_bootstrap_confidence_interval_generic,
				alpha, B, type, na.rm, show_progress, min_number_usable_samples, weighting_unit_type)
		},
		#' @description Compute jackknife-Wald two sided pval
		#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
		#' @param unit Deletion unit. Default \code{"auto"}.
		compute_jackknife_wald_two_sided_pval = function(delta = NULL, unit = "auto"){
			gcomp_incid_jackknife_wald_two_sided_pval(private, self$compute_jackknife_wald_two_sided_pval_generic,
				delta, unit)
		},
		#' @description Compute jackknife-Wald confidence interval
		#' @param alpha Significance level. Default \code{0.05}.
		#' @param unit Deletion unit. Default \code{"auto"}.
		compute_jackknife_wald_confidence_interval = function(alpha = 0.05, unit = "auto"){
			gcomp_incid_jackknife_wald_confidence_interval(private, self$compute_jackknife_wald_confidence_interval_generic,
				alpha, unit)
		}
	),
	# default_null_value() and the compute_rr_*() risk-ratio methods: gcomp_incid_rr_private_methods
	# (helper_gcomp.R), shared by the KK and non-KK classes (v1.0.7-TODO-54).
	private = c(gcomp_incid_rr_private_methods, list(
		is_a_incid_kk_gcomp = function() TRUE,
		max_abs_reasonable_coef = 25,
		best_X_colnames = NULL,
		gcomp_boot_beta = NULL,
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			gcomp_incid_rand_estimate(self, private, estimate_only)
		},
		build_design_matrix = function() stop(class(self)[1], " must implement build_design_matrix()."),
		get_estimand_type = function() stop(class(self)[1], " must implement get_estimand_type()."),
		compute_weighted_gcomp_estimate = function(row_weights, with_se = FALSE){
			X = private$build_design_matrix()
			if (is.null(X)) return(NA_real_)
			X = as.matrix(X)
			ok = is.finite(row_weights) & row_weights > 0 & is.finite(as.numeric(private$y))
			if (!any(ok)) return(NA_real_)
			X_fit = X[ok, , drop = FALSE]
			y_fit = as.numeric(private$y[ok])
			w_fit = as.numeric(row_weights[ok])
			p_fit = ncol(X_fit)
			# v1.0.6-TODO-138: accept a fit only if IRLS converged and the coefficients are
			# usable. Otherwise retry from the full-data warm start, then cold. A failed fit is
			# never cached as the next replicate's warm start (one diverged fit used to make
			# every later replicate of the chain garbage: RR exactly 1, NA SE).
			mod = gcomp_weighted_logistic_fit_with_retries(private, X_fit, y_fit, w_fit,
				chain_beta = private$gcomp_boot_beta)$fit
			if (is.null(mod)) {
				private$gcomp_boot_beta = NULL
				return(NA_real_)
			}
			coef_hat = as.numeric(mod$b)
			private$gcomp_boot_beta = coef_hat
			X1 = X_fit
			X0 = X_fit
			X1[, 2L] = 1
			X0[, 2L] = 0
			# Bootstrap weights perturb the logistic-model fit, but the g-computation
			# estimand remains standardized over the empirical covariate distribution.
			# This matches the non-KK incidence, proportion, and ordinal g-computation
			# implementations and their sample-conditional delta-method SEs.
			risk1 = mean(stats::plogis(as.numeric(X1 %*% coef_hat)))
			risk0 = mean(stats::plogis(as.numeric(X0 %*% coef_hat)))
			if (!is.finite(risk1) || !is.finite(risk0)) return(NA_real_)
			is_rd = identical(private$get_estimand_type(), "RD")
			est = if (is_rd) risk1 - risk0 else if (risk1 > 0 && risk0 > 0) risk1 / risk0 else NA_real_
			if (isTRUE(with_se) && is.finite(est)) {
				# v1.0.6-TODO-100: delta-method SE through the weighted KK-pair cluster
				# sandwich (gcomp_weighted_logistic_cluster_sandwich_vcov(); unit weights
				# reproduce the unweighted cluster-robust SE).
				attr(est, "se") = NA_real_
				cluster_id = tryCatch(private$get_cluster_ids(), error = function(e) NULL)
				if (!is.null(cluster_id) && length(cluster_id) == length(ok)) {
					names(coef_hat) = colnames(X_fit)
					vcov_w = gcomp_weighted_logistic_cluster_sandwich_vcov(X_fit, y_fit, coef_hat, w_fit,
						cluster_id[ok])
					if (!is.null(vcov_w)) {
						eff_w = tryCatch(private$compute_standardized_effects_r(list(
							X = X_fit, coefficients = coef_hat, vcov = vcov_w, j_treat = 2L, estimate_only = FALSE
						)), error = function(e) NULL)
						se_w = if (is.null(eff_w)) NA_real_ else if (is_rd) eff_w$se_rd else est * eff_w$se_log_rr
						se_w = suppressWarnings(as.numeric(se_w)[1L])
						if (length(se_w) == 1L && is.finite(se_w) && se_w > 0) attr(est, "se") = se_w
					}
				}
			}
			est
		},
		set_failed_fit_cache = function(inference_ready = TRUE){
			private$cached_values = gcomp_cache_failed_standardized_effects(
				private$cached_values,
				inference_ready = inference_ready
			)
		},
		effects_are_usable = function(effects, estimate_only = FALSE){
			estimand = private$get_estimand_type()
			if (estimate_only) {
				if (identical(estimand, "RD")){
					return(is.finite(effects$rd))
				} else {
					return(is.finite(effects$rr) && effects$rr > 0)
				}
			}
			if (identical(estimand, "RD")){
				is.finite(effects$rd) && is.finite(effects$se_rd) && effects$se_rd > 0
			} else {
				is.finite(effects$rr) && effects$rr > 0 &&
					is.finite(effects$log_rr) &&
					is.finite(effects$se_log_rr) && effects$se_log_rr > 0
			}
		},
		coefficients_are_usable = function(coef_hat){
			gcomp_incid_coefficients_are_usable(private, coef_hat)
		},
		# One body with the non-KK class (v1.0.7-TODO-54, code-duplication audit decision
		# code-duplication-da35f9c8f): this class clamps at machine epsilon and uses the KK-pair
		# cluster-robust sandwich.
		fit_logistic_with_sandwich = function(X_full, estimate_only = FALSE){
			gcomp_fit_logistic_with_sandwich(private, X_full, estimate_only, clip_eps = .Machine$double.eps,
				post_fit = function(X_fit, coef_hat, mu_hat, j_treat){
					gcomp_logistic_cluster_post_fit_cpp(
						X_fit = X_fit,
						y = as.numeric(private$y),
						coef_hat = coef_hat,
						mu_hat = mu_hat,
						cluster_id = private$get_cluster_ids(),
						j_treat = j_treat
					)
				})
		},
		compute_standardized_effects_r = function(fit){
			gcomp_incid_compute_standardized_effects_r(private, fit)
		},
		compute_standardized_effects = function(fit){
			gcomp_incid_compute_standardized_effects(private, fit)
		},
		get_effect_estimate = function(){
			gcomp_incid_get_effect_estimate(private)
		},
		compute_effect_confidence_interval = function(alpha){
			gcomp_incid_compute_effect_confidence_interval(self, private, alpha, "KK g-computation")
		},
		compute_effect_pvalue = function(delta){
			gcomp_incid_compute_effect_pvalue(self, private, delta)
		},
		shared = function(estimate_only = FALSE){
			if (gcomp_standardized_effect_cache_is_ready(private$cached_values, estimate_only = estimate_only)) return(invisible(NULL))
			gcomp_incid_fit_and_cache_effects(self, private, estimate_only)
		}
	))
)

# Static leaf-shared source (2026-08-18 migration, fix_inference_hierarchy.md
# "KK And IVWC Estimators"): `InferenceIncidKKGCompAbstract` and
# `InferenceAbstractKKMarginalIncid` (inference_incidence_KK_marginal_abstract.R)
# are left completely untouched -- both remain real R6 generators, because
# `InferenceAbstractKKMarginalIncid` is also the parent of
# `InferenceAbstractKKModifiedPoisson`/`InferenceIncidKKModifiedPoisson`
# (inference_incidence_KK_marginal.R), a separate estimator family not being
# migrated in this change. Only the two concrete leaves
# (`InferenceIncidKKGCompRiskDiff`/`RiskRatio`, both previously empty
# `public = list()` R6 leaves relying entirely on the abstract chain) are
# migrated; this component supplies everything they need. Self-harvests
# `InferenceIncidKKGCompAbstract`'s own body (which has no `initialize` of
# its own -- it inherited straight through) via
# `inference_component_source_parts()`, same as the non-KK sibling component
# `IncidenceGComputationSource` at the bottom of inference_incidence_gcomp_
# abstract.R, then layers in: (1) a hand-written `initialize` replicating
# `InferenceAbstractKKMarginalIncid$initialize` (incidence-response assert +
# no-censoring assert + Lesson 1's explicit `private$init_kk_passthrough()`,
# since post-migration `super$initialize()` resolves straight to root
# `Inference`); (2) `InferenceAbstractKKMarginalIncid`'s own KK-cluster
# helpers (`get_cluster_ids`, `get_covariate_names`, `compute_basic_match_
# data`, `supports_likelihood_tests`), copied verbatim since that class isn't
# itself a registered component; (3) the same generic-self-aliased-override
# pattern as `incidence_gcomp_generic_alias_overrides`
# (inference_incidence_gcomp.R) for every method whose harvested body calls
# `super$...` -- valid under the old R6 ladder, not under flat composition.
# The KK list is the non-KK list (incidence_gcomp_generic_alias_overrides,
# inference_incidence_gcomp.R) with one alias changed (v1.0.7-TODO-54,
# code-duplication audit decision code-duplication-dfe6e2293).
# compute_rand_two_sided_pval is pinned from InferenceRandCI, NOT InferenceRand:
# unlike the non-KK sibling (whose legacy ladder resolves to InferenceRand via
# InferenceAsymp), this KK class's legacy ladder (InferenceParamBootstrap -> ... ->
# InferenceRandCI) resolves compute_rand_two_sided_pval to InferenceRandCI's
# version (verified via R6 ancestor walk) -- InferenceRand's version refuses
# incidence data outright ("Randomization tests are not supported for
# incidence. Use Zhang method"), which is NOT what the legacy class does.
incidence_kk_gcomp_generic_alias_overrides = utils::modifyList(
	incidence_gcomp_generic_alias_overrides,
	list(compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval)
)

# Reusable-bootstrap-worker wiring, mirroring `incidence_gcomp_worker_
# overrides` in inference_incidence_gcomp.R exactly (same rationale:
# `best_X_colnames`/`gcomp_boot_beta`, the warm-start caches
# `compute_weighted_gcomp_estimate()` chains across resampling replicates,
# only do anything useful when the SAME worker object is reused across an
# entire resampling run rather than being freshly re-cloned per replicate).
# Missing this block on the first pass of this migration left
# `supports_reusable_bootstrap_worker()` silently falling back to the
# generic default (FALSE) instead of the legacy ladder's TRUE, which
# produced a *wrong-but-plausible-looking* divergence: the migrated class's
# `approximate_randomization_distribution_beta_hat_T`/
# `approximate_rand_bootstrap_distribution_beta_hat_T` varied properly
# across replicates while the legacy class returned the same constant value
# every time (a symptom of the worker-reuse path, not a red flag on its
# own) -- caught by the golden, not by inspection.
incidence_kk_gcomp_worker_overrides = list(
	supports_reusable_bootstrap_worker = function(){
		TRUE
	},
	create_bootstrap_worker_state = function(){
		private$create_design_backed_bootstrap_worker_state()
	},
	load_bootstrap_sample_into_worker = function(worker_state, indices){
		private$load_bootstrap_sample_into_design_backed_worker(worker_state, indices)
	},
	# v1.0.6-TODO-137 / v1.0.6-TODO-164: marks degenerate risk-ratio subsampling /
	# m-out-of-n draws as unusable (NaN).
	compute_bootstrap_worker_estimate = function(worker_state){
		edi_mark_degenerate_resampling_worker_draw(self, private,
			private$compute_bootstrap_worker_estimate_via_compute_treatment_estimate(worker_state), worker_state)
	}
)

incidence_kk_gcomp_marginal_incid_overrides = list(
	is_a_kk_marginal_incid = function() TRUE,
	supports_likelihood_tests = function() FALSE,
	compute_basic_match_data = function() private$compute_basic_kk_match_data_impl(),
	get_covariate_names = function(){
		kk_incid_covariate_names(private)
	},
	get_cluster_ids = function(){
		kk_incid_cluster_ids(private)
	}
)

#' KK incidence g-computation component source
#'
#' Source list for the \code{IncidenceKKGComputation} component shared by the KK g-computation incidence classes.
#'
#' @keywords internal
IncidenceKKGComputationSource = local({
	parts = inference_component_source_parts(InferenceIncidKKGCompAbstract)
	list(
		public = utils::modifyList(parts$public, c(
			list(
				#' @description Initialize KK marginal g-computation inference for a
				#'   completed incidence design; prepares the KK match structure used by
				#'   the cluster-robust sandwich covariance.
				#' @param des_obj A completed \code{Design} object with an incidence response.
				#' @param model_formula   Optional formula for covariate adjustment.
				#' @param verbose Whether to print progress messages.
				#' @param smart_cold_start_default Whether to use smart cold start values.
				initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL){
					if (should_run_asserts()) {
						assertResponseType(des_obj$get_response_type(), "incidence")
					}
					super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
					if (should_run_asserts()) {
						assertNoCensoring(private$any_censoring)
					}
					# Lesson 1 (see KKNewcombeRiskDiffIVWCSource): post-migration
					# super$initialize() resolves to the root Inference, not
					# InferenceAbstractKKMarginalIncid, so the KK match-structure setup
					# that ancestor's initialize() performed must be invoked explicitly
					# here.
					private$init_kk_passthrough(des_obj)
				}
			),
			incidence_kk_gcomp_generic_alias_overrides
		)),
		private = utils::modifyList(parts$private, c(
			incidence_kk_gcomp_marginal_incid_overrides,
			incidence_kk_gcomp_worker_overrides
		))
	)
})
