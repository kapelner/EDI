library(testthat)
library(EDI)

# InferenceIncidKKCondLogitIVWC migration (fix_inference_hierarchy.md, "KK
# And IVWC Estimators"): from a plain leaf on
# `InferenceKKPassThroughCompoundNoParamBootstrap` to
# `define_inference_class()` composing
# `BayesianBootstrap`/`Wald`/`IncidKKCondLogitIVWC` (static leaf source,
# `dependencies = "KKCompound"`), same shape as the other KK IVWC leaves
# migrated this week. Incidence class, so the fixture pin is
# `InferenceRandCI` (Zhang dispatch), not `InferenceRand` -- Lesson 3. The
# class's `eval(body(...))` bootstrap override was dropped as a verified
# no-op (see the source comment), so the legacy generator below -- source
# spliced straight onto the compound base -- reproduces the pre-migration
# class verbatim. Real classname on the fixture (see the count-KK golden for
# why "...Legacy" suffixes break dispatch). The OneLik sibling is untouched
# (one-likelihood phase).
make_incid_kk_cond_logit_legacy_generator = function() {
	src = EDI:::IncidKKCondLogitIVWCSource
	R6::R6Class(
		"InferenceIncidKKCondLogitIVWC",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceKKPassThroughCompoundNoParamBootstrap,
		public = src$public,
		private = src$private
	)
}

incid_kk_cond_logit_golden_design = function(n = 24L, seed = 20260817L) {
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

incid_kk_cond_logit_maybe_dropped_labels = c(
	"score_ci", "score_pval", "gradient_ci", "gradient_pval",
	"lik_ratio_ci", "lik_ratio_pval", "param_boot_pval", "param_boot_ci"
)

test_that("InferenceIncidKKCondLogitIVWC migration produces identical outputs", {
	Legacy = make_incid_kk_cond_logit_legacy_generator()
	des = incid_kk_cond_logit_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceIncidKKCondLogitIVWC$new(des)
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
		if (label %in% incid_kk_cond_logit_maybe_dropped_labels && identical(migrated_result$status, "absent")) {
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

test_that("InferenceIncidKKCondLogitIVWC is marked migrated in the registry", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceIncidKKCondLogitIVWC")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceIncidKKCondLogitIVWC"]]$migration_status, "migrated")
})
