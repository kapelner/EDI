library(testthat)
library(EDI)

# InferenceContinKKOLSIVWC migration (fix_inference_hierarchy.md, "KK And
# IVWC Estimators"): from a plain leaf on
# `InferenceKKPassThroughCompoundNoParamBootstrap` (this class never defined
# compute_estimate/compute_asymp_confidence_interval/compute_asymp_two_sided_
# pval itself -- it inherited the generic private$shared()-based versions
# from InferenceMLEorKMSummaryTable via the old ladder) to
# `define_inference_class()` composing `BayesianBootstrap`/`Wald`/
# `ContinKKOLSIVWC` (static leaf source, `dependencies = "KKCompound"`), the
# same shape as the other five KK leaves migrated this week. The legacy
# generator uses the REAL classname (see the count-KK golden for why
# fixtures must not use a "...Legacy" suffix).
make_contin_kk_ols_legacy_generator = function() {
	src = EDI:::ContinKKOLSIVWCSource
	R6::R6Class(
		"InferenceContinKKOLSIVWC",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceKKPassThroughCompoundNoParamBootstrap,
		public = src$public,
		private = src$private
	)
}

contin_kk_ols_golden_design = function(n = 24L, seed = 20260817L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			des$add_one_subject_response(i, 0.6 * ((w_i + 1) / 2) + 0.3 * X$x1[i] + rnorm(1L, sd = 0.8))
		}
		des
	})
}

# The dropped/degenerate-vs-real-surface check pattern (verified before
# asserting, same as InferenceIncidRiskDiff / KK Newcombe / Clayton IVWC /
# Robust-Regr IVWC): some labels may come back "unsupported" on the legacy
# side or a genuine Wald-identical (or Wald-adjacent, via uniroot) fallback;
# both are acceptable degenerate legacy outcomes as long as the migrated
# side is simply absent.
kk_ols_maybe_dropped_labels = c(
	"score_ci", "score_pval", "gradient_ci", "gradient_pval",
	"lik_ratio_ci", "lik_ratio_pval", "param_boot_pval", "param_boot_ci"
)

test_that("InferenceContinKKOLSIVWC migration produces identical outputs", {
	Legacy = make_contin_kk_ols_legacy_generator()
	des = contin_kk_ols_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceContinKKOLSIVWC$new(des)
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
		if (label %in% kk_ols_maybe_dropped_labels && identical(migrated_result$status, "absent")) {
			if (identical(legacy_result$status, "ok")) {
				legacy_value = as.numeric(legacy_result$value)
				legacy$set_seed(20260817L)
				legacy_wald_ci = inference_migration_with_seed(20260817L,
					as.numeric(legacy$compute_wald_confidence_interval(alpha = 0.2)))
				degenerate = all(is.na(legacy_value))
				# Widened tolerance (see ContinKKRobustRegrIVWC golden): compute_score_
				# confidence_interval() bypasses the supports_likelihood_tests() gate and
				# root-finds (uniroot) around the Wald estimate rather than returning it
				# in closed form, so score_ci/score_pval can be Wald-adjacent rather than
				# bit-identical.
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

test_that("InferenceContinKKOLSIVWC is marked migrated in the registry", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceContinKKOLSIVWC")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceContinKKOLSIVWC"]]$migration_status, "migrated")
})
