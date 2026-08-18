library(testthat)
library(EDI)

# InferenceContinKKRobustRegrIVWC migration (fix_inference_hierarchy.md, "KK
# And IVWC Estimators"): from a plain leaf on
# `InferenceKKPassThroughCompoundNoParamBootstrap` (no eval(body(...))
# override -- this class simply inherited the mixin's
# approximate_bootstrap_distribution_beta_hat_T/compute_estimate_with_
# bootstrap_weights without overriding either) to `define_inference_class()`
# composing `BayesianBootstrap`/`Wald`/`ContinKKRobustRegrIVWC` (static leaf
# source, `dependencies = "KKCompound"`), the same shape as the other four KK
# leaves migrated the same day. The legacy generator uses the REAL classname
# (see the count-KK golden for why fixtures must not use a "...Legacy"
# suffix).
make_contin_kk_robust_legacy_generator = function() {
	src = EDI:::ContinKKRobustRegrIVWCSource
	R6::R6Class(
		"InferenceContinKKRobustRegrIVWC",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceKKPassThroughCompoundNoParamBootstrap,
		public = src$public,
		private = src$private
	)
}

contin_kk_robust_golden_design = function(n = 24L, seed = 20260817L) {
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
# asserting, same as InferenceIncidRiskDiff / KK Newcombe / Clayton IVWC):
# some labels may come back "unsupported" on the legacy side (get_likelihood_
# test_spec() is NULL for this class -- it inherits supports_likelihood_
# tests = TRUE from the old AsympLik ladder with no real spec to back it) or
# a genuine Wald-identical fallback; both are acceptable degenerate legacy
# outcomes as long as the migrated side is simply absent.
kk_robust_maybe_dropped_labels = c(
	"score_ci", "score_pval", "gradient_ci", "gradient_pval",
	"lik_ratio_ci", "lik_ratio_pval", "param_boot_pval", "param_boot_ci"
)

test_that("InferenceContinKKRobustRegrIVWC migration produces identical outputs", {
	Legacy = make_contin_kk_robust_legacy_generator()
	des = contin_kk_robust_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceContinKKRobustRegrIVWC$new(des)
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
		if (label %in% kk_robust_maybe_dropped_labels && identical(migrated_result$status, "absent")) {
			if (identical(legacy_result$status, "ok")) {
				legacy_value = as.numeric(legacy_result$value)
				legacy$set_seed(20260817L)
				legacy_wald_ci = inference_migration_with_seed(20260817L,
					as.numeric(legacy$compute_wald_confidence_interval(alpha = 0.2)))
				degenerate = all(is.na(legacy_value))
				# score_ci is the one label here that is NOT bit-identical to the Wald CI: legacy
				# has supports_likelihood_tests() == FALSE and get_likelihood_test_spec() == NULL
				# (InferenceMixinKKPassThroughCompound's default), but compute_score_confidence_
				# interval() bypasses that gate and calls invert_test_pval_confidence_interval()
				# directly, which numerically root-finds (uniroot) around the Wald estimate rather
				# than returning it in closed form. Verified: legacy value 0.7157783/1.3328011 vs
				# Wald 0.7157792/1.3328002 -- a ~1e-6 uniroot convergence residual, not real
				# likelihood-test surface. Tolerance widened accordingly for this class only.
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

test_that("InferenceContinKKRobustRegrIVWC is marked migrated in the registry", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceContinKKRobustRegrIVWC")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceContinKKRobustRegrIVWC"]]$migration_status, "migrated")
})
