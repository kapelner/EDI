library(testthat)
library(EDI)

# InferenceContinKKOLSOneLik migration (fix_inference_hierarchy.md,
# "Full-Likelihood Estimators" / "KK And IVWC Estimators"): formerly a plain
# R6 leaf inheriting the real R6 abstract `InferenceKKPassThroughCompound`
# (proper R6 inheritance, not a raw mixin splice -- unlike the LWA/StratCox
# OneLik pairs). This class's own body becomes the new registered component
# `ContinKKOLSOneLikLikelihood` (`dependencies = c("KKCompound",
# "ParametricLikelihoodBootstrap")`), composed via `define_inference_class()`
# as `c("BayesianBootstrap", "ContinKKOLSOneLikLikelihood")`. Genuinely
# `likelihood_tier = "full"` (real Gaussian likelihood with an exact
# Bartlett factor) -- first full (non-Cox-partial) one-likelihood KK class
# migrated this stretch. The legacy generator below reproduces the
# pre-migration class via real R6 inheritance on
# `InferenceKKPassThroughCompound` (no raw splice needed, unlike the LWA/
# StratCox OneLik legacy fixtures).
make_contin_kk_ols_one_lik_legacy_generator = function() {
	src = EDI:::ContinKKOLSOneLikLikelihoodSource
	R6::R6Class(
		"InferenceContinKKOLSOneLik",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceKKPassThroughCompound,
		public = src$public,
		private = src$private
	)
}

contin_kk_ols_one_lik_golden_design = function(n = 24L, seed = 20260817L) {
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

test_that("InferenceContinKKOLSOneLik migration produces identical outputs", {
	Legacy = make_contin_kk_ols_one_lik_legacy_generator()
	des = contin_kk_ols_one_lik_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceContinKKOLSOneLik$new(des)
	# r = 19 (not the default 9): randomization columns compared non-vacuously
	# (finite-draw floor is 10; TODO-124 / G6 #13).
	method_calls = inference_migration_method_calls_with_rand_r(19L)
	rand_values = list()
	for (label in names(method_calls)) {
		spec = method_calls[[label]]
		legacy$set_seed(20260817L)
		legacy_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(legacy, spec$method, spec$args))
		migrated$set_seed(20260817L)
		migrated_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(migrated, spec$method, spec$args))
		if (startsWith(label, "randomization_") && identical(migrated_result$status, "ok")) {
			rand_values[[label]] = migrated_result$value
		}
		if (legacy_result$status %in% c("absent", "unsupported") &&
				migrated_result$status %in% c("absent", "unsupported")) {
			next
		}
		expect_identical(legacy_result$status, migrated_result$status, info = label)
		if (identical(legacy_result$status, "ok")) {
			expect_equal(migrated_result$value, legacy_result$value, tolerance = 1e-6, info = label)
		}
	}
	# Non-vacuity guard: with r = 19 the randomization p-value and CI are finite,
	# so the equality checks above actually compared numbers.
	expect_true(isTRUE(is.finite(rand_values$randomization_pval)), info = "randomization_pval finite at r = 19")
	expect_true(length(rand_values$randomization_ci) == 2L && all(is.finite(rand_values$randomization_ci)), info = "randomization_ci finite at r = 19")
})

test_that("InferenceContinKKOLSOneLik is marked migrated and the R6 abstract is no longer inherited", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceContinKKOLSOneLik")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceContinKKOLSOneLik"]]$migration_status, "migrated")
})
