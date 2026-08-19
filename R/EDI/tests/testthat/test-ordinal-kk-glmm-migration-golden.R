library(testthat)
library(EDI)

# InferenceOrdinalKKGLMM migration (fix_inference_hierarchy.md, "KK And IVWC
# Estimators", "Migrate KK GEE and GLMM classes"): flipped from the raw-splice
# `utils::modifyList(as.list(InferenceMixinKKGLMMShared$public), list(...))`
# state (manual harvesting of the KKGLMM raw source under `inherit =
# InferenceParamBootstrap`) to `inherit = Inference` with `components =
# c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "KKGLMM")` -- same
# hybrid-state fix as InferenceContinKKGLMM/InferenceCountKKGLMM. No method
# bodies were touched (only the splice mechanism, pins/overrides/metadata),
# so the legacy fixture below is the pre-migration file content verbatim
# (fixtures/legacy_ordinal_kk_glmm.R, copied from the committed source before
# this migration's edits, with the top-level class binding renamed to avoid
# colliding with the real migrated class, but the literal class-name STRING
# passed to R6::R6Class() kept as "InferenceOrdinalKKGLMM" so name-keyed
# dispatch policies -- e.g. edi_optimization_dispatch_policy()'s regex table
# in globals.R, matched against class(self)[1] -- resolve identically for
# legacy and migrated objects; see the analogous Contin/CountKKGLMM golden
# tests for the numeric-drift bug this avoids) -- sourced into a child
# environment of the EDI namespace (not the namespace itself, which is locked
# against new top-level bindings) so `InferenceParamBootstrap`/
# `InferenceMixinKKGLMMShared` etc. resolve normally.
make_ordinal_kk_glmm_legacy_generator = function() {
	env = new.env(parent = asNamespace("EDI"))
	sys.source(testthat::test_path("fixtures", "legacy_ordinal_kk_glmm.R"), envir = env)
	get("InferenceOrdinalKKGLMMLegacyOrig", envir = env)
}

ordinal_kk_glmm_golden_design = function(n = 60L, seed = 20260819L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			eta = 0.4 * ((w_i + 1) / 2) + 0.2 * X$x1[i]
			u = runif(1L)
			cuts = plogis(c(-0.8, 0.2, 1.2) - eta)
			y = if (u <= cuts[1L]) 1L else if (u <= cuts[2L]) 2L else if (u <= cuts[3L]) 3L else 4L
			des$add_one_subject_response(i, y)
		}
		des
	})
}

test_that("InferenceOrdinalKKGLMM migration produces identical outputs", {
	Legacy = make_ordinal_kk_glmm_legacy_generator()
	des = ordinal_kk_glmm_golden_design()
	legacy = Legacy$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	migrated = InferenceOrdinalKKGLMM$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
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

test_that("InferenceOrdinalKKGLMM is marked migrated", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceOrdinalKKGLMM")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceOrdinalKKGLMM"]]$migration_status, "migrated")
})
