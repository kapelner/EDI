library(testthat)
library(EDI)

# InferenceContinKKRobustRegrOneLik migration (fix_inference_hierarchy.md,
# "Quasi And Robust Estimators" / "KK And IVWC Estimators"): formerly a
# plain R6 leaf using real R6 inheritance (not a raw mixin splice) on the
# real R6 abstract `InferenceKKPassThroughCompoundNoParamBootstrap` --
# structurally the same shape as `InferenceContinKKOLSOneLik`'s
# pre-migration state, but on the NoParamBootstrap sibling since this class
# has no likelihood-test surface ("quasi" tier, same as
# `InferenceContinKKRobustRegrIVWC`). This class's own body becomes the new
# registered component `ContinKKRobustRegrOneLik` (`dependencies =
# "KKCompound"`, no `ParametricLikelihoodBootstrap`), composed via
# `define_inference_class()` as `c("BayesianBootstrap", "Wald",
# "ContinKKRobustRegrOneLik")`. The legacy generator below reproduces the
# pre-migration class via real R6 inheritance on
# `InferenceKKPassThroughCompoundNoParamBootstrap` (no raw splice needed).
make_contin_kk_robust_regr_one_lik_legacy_generator = function() {
	src = EDI:::ContinKKRobustRegrOneLikSource
	R6::R6Class(
		"InferenceContinKKRobustRegrOneLik",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceKKPassThroughCompoundNoParamBootstrap,
		public = src$public,
		private = src$private
	)
}

contin_kk_robust_regr_one_lik_golden_design = function(n = 24L, seed = 20260817L) {
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
# asserting, same as InferenceContinKKOLSIVWC/ContinKKRobustRegrIVWC): score/
# gradient/lik_ratio labels may come back "unsupported" on both sides for
# this "quasi"-tier class since it composes no LikelihoodTests component.
kk_robust_regr_one_lik_maybe_dropped_labels = c(
	"score_ci", "score_pval", "gradient_ci", "gradient_pval",
	"lik_ratio_ci", "lik_ratio_pval", "param_boot_pval", "param_boot_ci"
)

test_that("InferenceContinKKRobustRegrOneLik migration produces identical outputs", {
	Legacy = make_contin_kk_robust_regr_one_lik_legacy_generator()
	des = contin_kk_robust_regr_one_lik_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceContinKKRobustRegrOneLik$new(des)
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
		if (label %in% kk_robust_regr_one_lik_maybe_dropped_labels && identical(migrated_result$status, "absent")) {
			if (identical(legacy_result$status, "ok")) {
				legacy_value = as.numeric(legacy_result$value)
				legacy$set_seed(20260817L)
				legacy_wald_ci = inference_migration_with_seed(20260817L,
					as.numeric(legacy$compute_wald_confidence_interval(alpha = 0.2)))
				degenerate = all(is.na(legacy_value))
				# Same Wald-fallback-or-degenerate verification as the IVWC
				# sibling's golden (see that file's comment): compute_score_
				# confidence_interval() bypasses the supports_likelihood_tests()
				# gate and root-finds around the Wald estimate rather than
				# returning it in closed form, so it can come back "ok" with a
				# value that is numerically (not bit-identically) equal to the
				# Wald CI.
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

test_that("InferenceContinKKRobustRegrOneLik is marked migrated and the R6 abstract is no longer inherited", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceContinKKRobustRegrOneLik")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceContinKKRobustRegrOneLik"]]$migration_status, "migrated")
})
