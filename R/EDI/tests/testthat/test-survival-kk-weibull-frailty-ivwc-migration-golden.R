library(testthat)
library(EDI)

# InferenceSurvivalKKWeibullFrailtyIVWC migration (fix_inference_hierarchy.md,
# "KK And IVWC Estimators", same reshaping as the Clayton copula IVWC
# migration): pre-migration this was a two-layer ladder -- abstract
# `InferenceAbstractKKWeibullFrailtyIVWC` on
# `InferenceKKPassThroughCompoundNoParamBootstrap` (self-harvested into the
# registered component) plus a thin leaf (optimization_alg setter +
# delegation, self-harvested as a separate ...IVWCLeaf component, now
# deleted). Both layers are merged into the static
# `SurvivalKKWeibullFrailtyIVWCSource` (`dependencies = "KKCompound"`) and
# the class is `define_inference_class()` composing
# `BayesianBootstrap`/`Wald`/`SurvivalKKWeibullFrailtyIVWC`. The abstract's
# `eval(body(...))` bootstrap override and pure-passthrough public
# `duplicate` were dropped (verified no-ops, same argument as Clayton), so
# the legacy generator below -- source spliced straight onto the compound
# base -- reproduces the pre-migration class verbatim. Real classname on the
# fixture (see the count-KK golden for why "...Legacy" suffixes break
# dispatch).
make_survival_kk_weibull_frailty_legacy_generator = function() {
	src = EDI:::SurvivalKKWeibullFrailtyIVWCSource
	R6::R6Class(
		"InferenceSurvivalKKWeibullFrailtyIVWC",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceKKPassThroughCompoundNoParamBootstrap,
		public = src$public,
		private = src$private
	)
}

survival_kk_weibull_frailty_golden_design = function(n = 24L, seed = 20260817L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			y_lat = exp(0.8 - 0.3 * ((w_i + 1) / 2) + 0.15 * X$x1[i]) * stats::rexp(1L)
			cens = stats::rexp(1L, rate = 0.15)
			if (y_lat <= cens) {
				des$add_one_subject_response(i, y = max(y_lat, 0.05))
			} else {
				des$add_one_subject_response(i, y_L = max(cens, 0.05), y_R = Inf)
			}
		}
		des
	})
}

survival_kk_weibull_frailty_maybe_dropped_labels = c(
	"score_ci", "score_pval", "gradient_ci", "gradient_pval",
	"lik_ratio_ci", "lik_ratio_pval", "param_boot_pval", "param_boot_ci"
)

test_that("InferenceSurvivalKKWeibullFrailtyIVWC migration produces identical outputs", {
	Legacy = make_survival_kk_weibull_frailty_legacy_generator()
	des = survival_kk_weibull_frailty_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceSurvivalKKWeibullFrailtyIVWC$new(des)
	for (label in names(inference_migration_method_calls)) {
		spec = inference_migration_method_calls[[label]]
		legacy$set_seed(20260817L)
		legacy_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(legacy, spec$method, spec$args))
		migrated$set_seed(20260817L)
		migrated_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(migrated, spec$method, spec$args))
		if (legacy_result$status %in% c("absent", "unsupported") &&
				migrated_result$status %in% c("absent", "unsupported")) {
			next
		}
		if (label %in% survival_kk_weibull_frailty_maybe_dropped_labels && identical(migrated_result$status, "absent")) {
			if (identical(legacy_result$status, "ok")) {
				legacy_value = as.numeric(legacy_result$value)
				legacy$set_seed(20260817L)
				legacy_wald_ci = inference_migration_with_seed(20260817L,
					as.numeric(legacy$compute_wald_confidence_interval(alpha = 0.2)))
				degenerate = all(is.na(legacy_value))
				# Collapsed-onto-estimate degenerate form (see the Bai golden).
				if (!degenerate && length(legacy_value) == 2L && all(is.finite(legacy_value)) &&
						isTRUE(all.equal(legacy_value[1L], legacy_value[2L], tolerance = 1e-8))) {
					legacy$set_seed(20260817L)
					legacy_estimate = inference_migration_with_seed(20260817L,
						as.numeric(legacy$compute_estimate()))
					degenerate = isTRUE(all.equal(legacy_value[1L], legacy_estimate, tolerance = 1e-6))
				}
				wald_fallback = length(legacy_value) == 2L && all(is.finite(legacy_value)) &&
					isTRUE(all.equal(legacy_value, legacy_wald_ci, tolerance = 1e-4))
				expect_true(degenerate || wald_fallback,
					info = paste0(label, ": legacy produced a real non-Wald value; dropping it would lose real surface"))
			}
			next
		}
		expect_identical(legacy_result$status, migrated_result$status, info = label)
		if (identical(legacy_result$status, "ok")) {
			expect_equal(migrated_result$value, legacy_result$value, tolerance = 1e-6, info = label)
		}
	}
})

test_that("InferenceSurvivalKKWeibullFrailtyIVWC is marked migrated in the registry", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceSurvivalKKWeibullFrailtyIVWC")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceSurvivalKKWeibullFrailtyIVWC"]]$migration_status, "migrated")
})
