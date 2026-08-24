library(testthat)
library(EDI)

# InferenceIncidKKNewcombeRiskDiff migration (fix_inference_hierarchy.md,
# "KK And IVWC Estimators"): from `R6::R6Class(inherit =
# InferenceKKPassThroughCompoundNoParamBootstrap, ...)` to
# `define_inference_class()` composing
# `BayesianBootstrap`/`Wald`/`KKNewcombeRiskDiffIVWC` (the estimator body
# harvested verbatim into `KKNewcombeRiskDiffIVWCSource`, with
# `dependencies = "KKCompound"`), following the already-migrated
# `InferenceAllKKMeanDiffIVWC` template. One deliberate difference from that
# continuous-response template: `compute_rand_two_sided_pval` is pinned from
# `InferenceRandCI` (not `InferenceRand`) so the incidence Zhang exact
# randomization dispatch the old ladder had is preserved — same decision and
# rationale as the `InferenceIncidRiskDiff` migration.
make_kk_newcombe_legacy_generator = function() {
	R6::R6Class(
		"InferenceIncidKKNewcombeRiskDiffLegacy",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceKKPassThroughCompoundNoParamBootstrap,
		public = list(
			initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL){
				if (EDI:::should_run_asserts()) {
					checkmate::assertChoice(des_obj$get_response_type(), "incidence")
				}
				if (EDI:::should_run_asserts()) {
					if (!des_obj$is_a_kk_matching_capable()){
						stop(class(self)[1], " requires a KK matching-on-the-fly design.")
					}
				}
				super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
				if (EDI:::should_run_asserts()) {
					EDI:::assertNoCensoring(private$any_censoring)
				}
			},
			compute_estimate = function(estimate_only = FALSE){
				private$shared(estimate_only = estimate_only)
				est = private$cached_values$beta_hat_T
				if (is.null(est) || length(est) != 1L) NA_real_ else est
			}
		),
		private = list(
			compute_basic_match_data = function(){
				private$cached_values$KKstats = EDI:::compute_zhang_match_data_cpp(private$get_X(), private$y, private$w, private$m)
			},
			shared = function(estimate_only = FALSE){
				private$shared_combined()
			},
			pool_estimates_ivwc = function(est1, var1, est2, var2){
				ok1 = is.finite(est1) && is.finite(var1) && var1 > 0
				ok2 = is.finite(est2) && is.finite(var2) && var2 > 0
				if (ok1 && ok2){
					w1 = var2 / (var1 + var2)
					return(list(
						estimate = w1 * est1 + (1 - w1) * est2,
						variance = var1 * var2 / (var1 + var2)
					))
				} else if (ok1){
					return(list(estimate = est1, variance = var1))
				} else if (ok2){
					return(list(estimate = est2, variance = var2))
				} else {
					return(list(estimate = NA_real_, variance = NA_real_))
				}
			},
			weighted_empirical_risk_difference = function(row_weights){
				ok_t = is.finite(private$w) & private$w == 1 & is.finite(row_weights) & row_weights > 0
				ok_c = is.finite(private$w) & private$w == 0 & is.finite(row_weights) & row_weights > 0
				if (!any(ok_t) || !any(ok_c)) return(NA_real_)
				p_t = stats::weighted.mean(as.numeric(private$y[ok_t]), as.numeric(row_weights[ok_t]))
				p_c = stats::weighted.mean(as.numeric(private$y[ok_c]), as.numeric(row_weights[ok_c]))
				if (!is.finite(p_t) || !is.finite(p_c)) return(NA_real_)
				p_t - p_c
			},
			shared_combined = function(){
				if (!isTRUE(private$has_match_structure)) {
					private$cache_nonestimable_estimate("kk_design_required")
					return(invisible(NULL))
				}
				if (!is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
				if (is.null(private$cached_values$KKstats)) private$compute_basic_match_data()
				if (is.null(private$cached_values$KKstats)) return(invisible(NULL))
				KKstats = private$cached_values$KKstats
				m = KKstats$m
				nRT = KKstats$nRT
				nRC = KKstats$nRC
				est_m = NA_real_
				var_m = NA_real_
				if (m > 0){
					n = m
					p10 = KKstats$d_plus / n
					p01 = KKstats$d_minus / n
					est_m = p10 - p01
					var_m = (p10 + p01 - (p10 - p01)^2) / n
				}
				est_r = NA_real_
				var_r = NA_real_
				if (nRT > 0 && nRC > 0){
					pRT = KKstats$n11 / nRT
					pRC = KKstats$n01 / nRC
					est_r = pRT - pRC
					var_r = pRT * (1 - pRT) / nRT + pRC * (1 - pRC) / nRC
				}
				res = private$pool_estimates_ivwc(est_m, var_m, est_r, var_r)
				private$cached_values$beta_hat_T = res$estimate
				private$cached_values$s_beta_hat_T = sqrt(res$variance)
				private$cached_values$df = NA_real_
			}
		)
	)
}

kk_newcombe_golden_design = function(n = 20L, seed = 20260817L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			des$add_one_subject_response(i, stats::rbinom(1L, 1L, stats::plogis(-0.4 + 0.9 * ((w_i + 1) / 2) + 0.3 * X$x1[i])))
		}
		des
	})
}

# Intentionally-dropped likelihood-test API family, same verified pattern as
# the InferenceIncidRiskDiff migration: on the old ladder the score/gradient/
# LR *confidence intervals* silently returned bounds bit-identical to the
# Wald interval (AsympLik's fallback) and the *p-values* returned NA -- a
# mislabeled/degenerate surface tier "none" forbids. The migrated class drops
# these outright; the loop below asserts migrated-absent AND that the legacy
# value carried no information beyond the retained Wald API.
kk_newcombe_dropped_labels = c(
	"score_ci", "score_pval", "gradient_ci", "gradient_pval",
	"lik_ratio_ci", "lik_ratio_pval", "param_boot_pval", "param_boot_ci"
)

# Per-call seeded comparison on both sides -- see
# test-incid-cmh-extended-robins-migration-golden.R for why every call is
# seeded (obj$set_seed + a global-RNG reset), not just pre-classified
# stochastic ones.
test_that("InferenceIncidKKNewcombeRiskDiff migration produces identical outputs", {
	Legacy = make_kk_newcombe_legacy_generator()
	des = kk_newcombe_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceIncidKKNewcombeRiskDiff$new(des)
	for (label in names(inference_migration_method_calls)) {
		spec = inference_migration_method_calls[[label]]
		legacy$set_seed(20260817L)
		legacy_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(legacy, spec$method, spec$args))
		migrated$set_seed(20260817L)
		migrated_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(migrated, spec$method, spec$args))
		if (label %in% kk_newcombe_dropped_labels) {
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
		if (identical(legacy_result$status, "ok")) {
			expect_equal(migrated_result$value, legacy_result$value, tolerance = 1e-7, info = label)
		}
	}
})

test_that("InferenceIncidKKNewcombeRiskDiff keeps its public surface and is marked migrated", {
	Legacy = make_kk_newcombe_legacy_generator()
	before = inference_migration_public_methods(Legacy)
	after = inference_migration_public_methods(InferenceIncidKKNewcombeRiskDiff)
	dropped = setdiff(before, after)
	expect_true(all(grepl(
		"score|gradient|lik_ratio|likelihood|bartlett|testing_type|information",
		dropped
	)), info = paste("unexpected dropped methods:", paste(dropped, collapse = ", ")))
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceIncidKKNewcombeRiskDiff")
	expect_identical(metadata$parent, "Inference")
	expect_identical(metadata$likelihood_tier, "none")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceIncidKKNewcombeRiskDiff"]]$migration_status, "migrated")
})
