library(testthat)
library(EDI)

# InferencePropKKGLMM migration (fix_inference_hierarchy.md, "KK And IVWC
# Estimators", "Migrate KK GEE and GLMM classes"): a plain R6::R6Class leaf
# inheriting from the shared abstract base InferenceAbstractKKCondLogitGLMM,
# which was migrated from a hybrid `define_inference_class(inherit =
# InferenceParamBootstrap, components = "KKPassThrough")` state to `inherit
# = Inference` with `components = c("BayesianBootstrap",
# "ParametricLikelihoodBootstrap", "KKPassThrough")` -- see
# test-incid-kk-cond-logit-glmm-migration-golden.R for the full migration
# writeup (same abstract base, same fixture file). This class itself has no
# `super$...()` calls needing generic-alias treatment.
make_prop_kk_glmm_legacy_env = function() {
	env = new.env(parent = asNamespace("EDI"))
	sys.source(testthat::test_path("fixtures", "legacy_kk_cond_logit_glmm.R"), envir = env)
	env
}

prop_kk_glmm_golden_design = function(n = 60L, seed = 20260819L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "proportion", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			des$add_one_subject_response(i, plogis(0.3 * ((w_i + 1) / 2) + 0.2 * X$x1[i] + rnorm(1L, sd = 0.3)))
		}
		des
	})
}

test_that("InferencePropKKGLMM migration produces identical outputs", {
	env = make_prop_kk_glmm_legacy_env()
	Legacy = get("InferencePropKKGLMMLegacyOrig", envir = env)
	des = prop_kk_glmm_golden_design()
	legacy = Legacy$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	migrated = InferencePropKKGLMM$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
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

test_that("InferenceAbstractKKCondLogitGLMM base is marked migrated", {
	# InferencePropKKGLMM plain-R6-inherits from InferenceAbstractKKCondLogitGLMM
	# rather than composing directly, so its own migration_status stays
	# "pending" under build_inference_hierarchy_migration_record()'s
	# heuristic (it only auto-detects "migrated" when a class's *immediate*
	# parent is "Inference") -- see
	# test-incid-kk-cond-logit-glmm-migration-golden.R for the full writeup
	# (same abstract base). What matters is the shared abstract base itself.
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceAbstractKKCondLogitGLMM")
	expect_identical(metadata$parent, "Inference")
})
