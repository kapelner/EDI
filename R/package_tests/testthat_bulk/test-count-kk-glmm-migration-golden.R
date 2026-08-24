library(testthat)
library(EDI)

# InferenceCountKKGLMM migration (fix_inference_hierarchy.md, "KK And IVWC
# Estimators", "Migrate KK GEE and GLMM classes"): flipped from the hybrid
# `define_inference_class(inherit = InferenceParamBootstrap, components =
# "KKGLMM")` state (already a factory call, but still R6-inheriting
# BayesianBootstrap/ParametricLikelihoodBootstrap instead of composing them
# explicitly) to `inherit = Inference` with `components = c("BayesianBootstrap",
# "ParametricLikelihoodBootstrap", "KKGLMM")` -- same hybrid-state fix as
# InferenceContinKKGLMM. Method bodies for compute_lik_ratio_confidence_interval/
# compute_lik_ratio_two_sided_pval were rewritten to call the new
# `..._generic` pinned aliases instead of `super$...()` (which does not
# resolve under flat composition); the legacy fixture below is the
# pre-migration file content verbatim (fixtures/legacy_count_kk_glmm.R,
# copied from the committed source before this migration's edits, with the
# top-level class binding renamed to avoid colliding with the real migrated
# class, but the literal class-name STRING passed to define_inference_class()
# kept as "InferenceCountKKGLMM" so name-keyed dispatch policies -- e.g.
# edi_optimization_dispatch_policy()'s regex table in globals.R, matched
# against class(self)[1] -- resolve identically for legacy and migrated
# objects) -- sourced into a child environment of the EDI namespace (not the
# namespace itself, which is locked against new top-level bindings) so
# `define_inference_class`/`InferenceParamBootstrap`/`KKGLMM` etc. resolve
# normally.
make_count_kk_glmm_legacy_generator = function() {
	env = new.env(parent = asNamespace("EDI"))
	sys.source(testthat::test_path("fixtures", "legacy_count_kk_glmm.R"), envir = env)
	get("InferenceCountKKGLMMLegacyOrig", envir = env)
}

count_kk_glmm_golden_design = function(n = 24L, seed = 20260819L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			des$add_one_subject_response(i, rpois(1L, lambda = exp(0.3 * ((w_i + 1) / 2) + 0.1 * X$x1[i])))
		}
		des
	})
}

test_that("InferenceCountKKGLMM migration produces identical outputs", {
	Legacy = make_count_kk_glmm_legacy_generator()
	des = count_kk_glmm_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceCountKKGLMM$new(des)
	for (label in names(inference_migration_method_calls)) {
		spec = inference_migration_method_calls[[label]]
		legacy$set_seed(20260819L)
		legacy_result = inference_migration_with_seed(20260819L,
			inference_migration_call_optional_method(legacy, spec$method, spec$args))
		migrated$set_seed(20260819L)
		migrated_result = inference_migration_with_seed(20260819L,
			inference_migration_call_optional_method(migrated, spec$method, spec$args))
		if (legacy_result$status %in% c("absent", "unsupported") &&
				migrated_result$status %in% c("absent", "unsupported")) {
			next
		}
		expect_identical(legacy_result$status, migrated_result$status, info = label)
		if (identical(legacy_result$status, "ok")) {
			expect_equal(migrated_result$value, legacy_result$value, tolerance = 1e-6, info = label)
		}
	}
})

test_that("InferenceCountKKGLMM is marked migrated", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceCountKKGLMM")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceCountKKGLMM"]]$migration_status, "migrated")
})
