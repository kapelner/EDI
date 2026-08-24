library(testthat)
library(EDI)

# InferenceIncidRiskDiff migration (fix_inference_hierarchy.md, "Asymptotic
# (Wald) No-Likelihood Migration"): from `R6::R6Class(inherit =
# InferenceAsympLikStdModCacheNoParamBootstrap, ...)` to
# `define_inference_class()` composing `BayesianBootstrap`/`Wald`, with the
# likelihood-free subset of StandardModelCacheSource it actually used
# (shared() state machine, cached-SE/df getters, design-backed worker
# delegation) absorbed as host-owned private methods. The class is
# likelihood_tier "none" (OLS linear-probability working model on binary y,
# supports_likelihood_tests = FALSE), so it cannot compose StandardModelCache
# (whose standard_model_cache capability requires likelihood_tests, tier >=
# quasi); the likelihood-test public surface it nominally inherited from the
# old ladder always errored at runtime and is intentionally dropped. This
# legacy generator is a byte-for-byte copy of the pre-migration class body.
make_incid_risk_diff_legacy_generator = function() {
	R6::R6Class(
		"InferenceIncidRiskDiffLegacy",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceAsympLikStdModCacheNoParamBootstrap,
		public = list(
			initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL){
				if (EDI:::should_run_asserts()) {
					checkmate::assertChoice(des_obj$get_response_type(), "incidence")
				}
				super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
				if (EDI:::should_run_asserts()) {
					EDI:::assertNoCensoring(private$any_censoring)
				}
			},
			compute_estimate = function(estimate_only = FALSE){
				if (estimate_only) {
					if (!is.null(private$cached_values$beta_hat_T)) return(private$cached_values$beta_hat_T)
					if (isFALSE(private$harden)) {
						X = private$build_design_matrix()
						fit = stats::lm.fit(x = X, y = as.numeric(private$y))
						b = stats::coef(fit)
						j = 2L
						private$cached_values$beta_hat_T = if (length(b) >= j && is.finite(b[j])) {
							private$best_X_colnames = setdiff(colnames(X), c("(Intercept)", "treatment"))
							as.numeric(b[j])
						} else NA_real_
						return(private$cached_values$beta_hat_T)
					}
				}
				private$shared(estimate_only = estimate_only)
				private$cached_values$beta_hat_T
			},
			compute_asymp_confidence_interval = function(alpha = 0.05){
				private$shared(estimate_only = FALSE)
				private$compute_z_or_t_ci_from_s_and_df(alpha)
			},
			compute_asymp_two_sided_pval = function(delta = 0){
				private$shared(estimate_only = FALSE)
				private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
			},
			compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
				row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
				X_full = private$build_design_matrix()
				attempt = private$fit_with_hardened_qr_column_dropping(
					X_full = X_full,
					fit_fun = function(X_fit, keep){
						w_fit = row_weights
						ok = is.finite(w_fit) & w_fit > 0 & is.finite(private$y)
						if (sum(ok) <= ncol(X_fit)) return(NULL)
						stats::lm.wfit(
							x = X_fit[ok, , drop = FALSE],
							y = as.numeric(private$y[ok]),
							w = as.numeric(w_fit[ok])
						)
					},
					fit_ok = function(mod, X_fit, keep){
						j_treat = which(keep == 2L)
						!is.null(mod) &&
							is.finite(j_treat) &&
							length(mod$coefficients) >= j_treat &&
							is.finite(mod$coefficients[j_treat])
					}
				)
				if (is.null(attempt$fit)) {
					private$cached_values$beta_hat_T = NA_real_
					private$cached_values$s_beta_hat_T = NA_real_
					return(NA_real_)
				}
				j_treat = which(attempt$keep == 2L)
				private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
				private$cached_values$beta_hat_T = as.numeric(attempt$fit$coefficients[j_treat])
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$beta_hat_T
			}
		),
		private = list(
			supports_likelihood_tests = function(){ FALSE },
			best_X_colnames = NULL,
			build_design_matrix = function(){
				X_cov = private$X
				if (is.null(X_cov) || ncol(X_cov) == 0) {
					X = cbind(`(Intercept)` = 1, treatment = private$w)
				} else {
					X = cbind(`(Intercept)` = 1, treatment = private$w, X_cov)
				}
				X
			},
			compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
				if (is.null(private$best_X_colnames)){
					private$shared(estimate_only = TRUE)
				}
				if (is.null(private$best_X_colnames)){
					return(self$compute_estimate(estimate_only = estimate_only))
				}
				X_cols = private$best_X_colnames
				X_data = private$get_X()
				if (length(X_cols) == 0L){
					X = cbind(1, private$w)
				} else {
					X_cov = X_data[, intersect(X_cols, colnames(X_data)), drop = FALSE]
					X = cbind(1, treatment = private$w, X_cov)
				}
				res = tryCatch(EDI:::fast_ols_cpp(X = X, y = as.numeric(private$y)), error = function(e) NULL)
				if (is.null(res) || !is.finite(res$b[2])){
					return(NA_real_)
				}
				as.numeric(res$b[2])
			},
			supports_reusable_bootstrap_worker = function(){
				TRUE
			},
			get_supported_testing_types_impl = function(){
				"wald"
			},
			generate_mod = function(estimate_only = FALSE){
				attempt = private$fit_with_hardened_qr_column_dropping(
					X_full = private$build_design_matrix(),
					fit_fun = function(X_fit, keep){
						j_treat = which(keep == 2L)
						if (estimate_only) {
							res = stats::lm.fit(x = X_fit, y = as.numeric(private$y))
							b = as.numeric(stats::coef(res))
							list(b = b, beta_hat_T = as.numeric(b[j_treat]), ssq_b_j = NA_real_, j_treat = j_treat)
						} else {
							res = EDI:::fast_ols_with_var_cpp(X = X_fit, y = private$y, j = j_treat)
							res$j_treat = j_treat
							res$beta_hat_T = as.numeric(res$b[j_treat])
							res
						}
					},
					fit_ok = function(mod, X_fit, keep){
						j_treat = mod$j_treat
						if (is.null(mod) || length(mod$b) < j_treat || !is.finite(mod$b[j_treat])) return(FALSE)
						if (estimate_only) return(TRUE)
						is.finite(mod$ssq_b_j) && mod$ssq_b_j > 0
					}
				)
				if (!is.null(attempt$fit)){
					private$best_X_colnames = setdiff(colnames(attempt$X), c("(Intercept)", "treatment"))
				}
				attempt$fit
			}
		)
	)
}

# Labels for the intentionally-dropped likelihood-test API family (see the
# file-header comment): on the old ladder these methods existed but could
# never do real likelihood work for this class (supports_likelihood_tests =
# FALSE / get_likelihood_test_spec = NULL). Verified empirically: the
# p-value paths error ("does not expose a likelihood-test specification"),
# while the CI paths silently fall back to bounds *bit-identical to the Wald
# confidence interval* -- a mislabeled-Wald interval presented as a
# score/LR/gradient interval, the exact "exposes an operation it cannot
# execute" pattern fix_inference_hierarchy.md's property 1 bans (and the
# tier table forbids outright at tier "none"). The migrated class drops them
# outright. The comparison below therefore asserts, for these labels only:
# migrated is "absent", and legacy either errored as unsupported, returned
# fully-NA bounds, or returned exactly its own Wald interval -- proving the
# dropped surface never carried information the retained Wald API doesn't.
risk_diff_intentionally_dropped_labels = c(
	"score_ci", "score_pval", "gradient_ci", "gradient_pval",
	"lik_ratio_ci", "lik_ratio_pval", "param_boot_pval", "param_boot_ci"
)

# Labels whose *numeric value* is intentionally no longer bit-identical to the
# legacy class (2026-08-24): `InferenceIncidRiskDiff$generate_mod()` now
# replaces `fast_ols_with_var_cpp()`'s classical homoskedastic OLS variance
# with a Huber-White (HC0) sandwich variance for `ssq_b_j`/`ssq_b_2` (see the
# class-level roxygen). This is a deliberate statistical-correctness fix, not
# a migration regression -- OLS on a binary y is a linear probability model,
# whose conditional variance is heteroskedastic by construction
# (Var(y|x)=p(x)(1-p(x))), so the classical SE the legacy class used is
# misspecified. Only the four methods that read the cached standard error
# (asymp/wald CI and pval -- "asymp" and "wald" are the same computation for
# this class, since it only ever supports the "wald" testing type) are
# affected; the point estimate, bootstrap, jackknife, and randomization paths
# never touch `ssq_b_j`/`ssq_b_2` and are asserted bit-identical as before.
risk_diff_se_formula_changed_labels = c("asymp_ci", "asymp_pval", "wald_ci", "wald_pval")

# Every method call is seeded fresh on both sides (obj$set_seed + a global-RNG
# reset) before being invoked -- see test-incid-cmh-extended-robins-migration-
# golden.R for why this is the only safe general pattern for classes whose
# nominally-deterministic methods may consume the global RNG stream.
expect_risk_diff_migration_outputs_equal = function(legacy_class, migrated_class, design) {
	legacy = legacy_class$new(design)
	migrated = migrated_class$new(design)
	for (label in names(inference_migration_method_calls)) {
		spec = inference_migration_method_calls[[label]]
		legacy$set_seed(20260817L)
		legacy_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(legacy, spec$method, spec$args))
		migrated$set_seed(20260817L)
		migrated_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(migrated, spec$method, spec$args))
		if (label %in% risk_diff_intentionally_dropped_labels) {
			expect_identical(migrated_result$status, "absent", info = label)
			if (identical(legacy_result$status, "ok")) {
				legacy_value = as.numeric(legacy_result$value)
				legacy$set_seed(20260817L)
				legacy_wald_ci = inference_migration_with_seed(20260817L,
					as.numeric(legacy$compute_wald_confidence_interval(alpha = 0.2)))
				degenerate = all(is.na(legacy_value))
				wald_fallback = length(legacy_value) == 2L && all(is.finite(legacy_value)) &&
					isTRUE(all.equal(legacy_value, legacy_wald_ci, tolerance = 1e-10))
				expect_true(degenerate || wald_fallback,
					info = paste0(label, ": legacy produced a real non-Wald value; dropping it would lose real surface"))
			}
			next
		}
		if (legacy_result$status %in% c("absent", "unsupported") &&
				migrated_result$status %in% c("absent", "unsupported")) {
			next
		}
		expect_identical(legacy_result$status, migrated_result$status, info = label)
		if (!identical(legacy_result$status, "ok")) next
		if (label %in% risk_diff_se_formula_changed_labels) {
			legacy_value = as.numeric(legacy_result$value)
			migrated_value = as.numeric(migrated_result$value)
			expect_true(all(is.finite(migrated_value)), info = label)
			if (endsWith(label, "_ci")) {
				# Both CIs are symmetric around beta_hat_T (+-multiplier*SE), so
				# the midpoint is SE-independent and must still match exactly;
				# only the half-width (driven by the SE formula) is allowed to
				# differ.
				expect_equal(mean(migrated_value), mean(legacy_value), tolerance = 1e-7, info = label)
			}
			next
		}
		expect_equal(migrated_result$value, legacy_result$value, tolerance = 1e-7, info = label)
	}
}

test_that("InferenceIncidRiskDiff migration produces identical outputs (no covariates beyond x)", {
	InferenceIncidRiskDiffLegacy = make_incid_risk_diff_legacy_generator()
	des = inference_migration_complete_design("incidence", n = 20L, seed = 20260817L)
	expect_risk_diff_migration_outputs_equal(InferenceIncidRiskDiffLegacy, InferenceIncidRiskDiff, des)
})

test_that("InferenceIncidRiskDiff migration: dropped surface is exactly the never-executable likelihood-test API", {
	InferenceIncidRiskDiffLegacy = make_incid_risk_diff_legacy_generator()
	before = inference_migration_public_methods(InferenceIncidRiskDiffLegacy)
	after = inference_migration_public_methods(InferenceIncidRiskDiff)
	dropped = setdiff(before, after)
	# On the old ladder these could never do real work for this class
	# (supports_likelihood_tests = FALSE / get_likelihood_test_spec = NULL:
	# test p-values errored, CI inversions degraded to all-NA, and the
	# testing-type/information-preference accessors configured a dispatch
	# with only "wald" ever supported): accidental legacy surface, not
	# capability. Anything else dropped is a migration bug.
	expect_true(all(grepl(
		"score|gradient|lik_ratio|likelihood|bartlett|testing_type|information",
		dropped
	)), info = paste("unexpected dropped methods:", paste(dropped, collapse = ", ")))
	expect_false(any(c(
		"compute_estimate", "compute_asymp_confidence_interval",
		"compute_asymp_two_sided_pval", "compute_estimate_with_bootstrap_weights",
		"compute_bootstrap_confidence_interval", "compute_rand_two_sided_pval",
		"compute_bayesian_bootstrap_confidence_interval", "compute_jackknife_std_error"
	) %in% dropped))
})

test_that("InferenceIncidRiskDiff is marked migrated with tier none in the class registry", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceIncidRiskDiff")
	expect_identical(metadata$parent, "Inference")
	expect_identical(metadata$likelihood_tier, "none")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceIncidRiskDiff"]]$migration_status, "migrated")
})
