library(testthat)
library(EDI)

# InferenceSurvivalKKStratCoxPHOneLik migration (fix_inference_hierarchy.md,
# "Partial-Likelihood Estimators" / "KK And IVWC Estimators"): pre-migration
# this was a single-layer R6 leaf (unlike the LWA Cox OneLik pair's two-layer
# abstract+leaf shape) inheriting `InferenceParamBootstrap` and raw-splicing
# `InferenceMixinKKPassThrough$public/private`. Merged into the registered
# component source `SurvivalKKStratCoxOneLikPartialLikelihoodSource`
# (`dependencies = c("KKPassThrough", "ParametricLikelihoodBootstrap")`) and
# the class is now `define_inference_class()` composing
# `BayesianBootstrap`/`SurvivalKKStratCoxOneLikPartialLikelihood`. Real
# full-likelihood-tier ("partial") class with score/gradient/LR test support
# and parametric-bootstrap LR calibration, so `metadata$capabilities =
# "likelihood_ratio"` is declared explicitly (same requirement as
# InferenceSurvivalKKLWACoxPHOneLik/InferenceOrdinalCauchitRegr/
# InferenceOrdinalCloglogRegr). The legacy generator below -- source spliced
# straight onto `InferenceParamBootstrap` -- reproduces the pre-migration
# class verbatim.
# NOTE: `inherit = InferenceParamBootstrap` does NOT itself supply
# `init_kk_passthrough` -- the pre-migration class got it via a raw splice
# (`as.list(InferenceMixinKKPassThrough$private)`) that the merged Source
# deliberately dropped (the migrated class gets it via composing the
# KKPassThrough component instead). The legacy fixture must therefore
# replicate that same raw splice manually to be faithful.
make_survival_kk_strat_cox_onelik_legacy_generator = function() {
	src = EDI:::SurvivalKKStratCoxOneLikPartialLikelihoodSource
	R6::R6Class(
		"InferenceSurvivalKKStratCoxPHOneLik",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceParamBootstrap,
		public = utils::modifyList(as.list(EDI:::InferenceMixinKKPassThrough$public), src$public),
		private = utils::modifyList(as.list(EDI:::InferenceMixinKKPassThrough$private), src$private)
	)
}

survival_kk_strat_cox_onelik_golden_design = function(n = 24L, seed = 20260817L) {
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

test_that("InferenceSurvivalKKStratCoxPHOneLik migration produces identical outputs", {
	Legacy = make_survival_kk_strat_cox_onelik_legacy_generator()
	des = survival_kk_strat_cox_onelik_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceSurvivalKKStratCoxPHOneLik$new(des)
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
		expect_identical(legacy_result$status, migrated_result$status, info = label)
		if (identical(legacy_result$status, "ok")) {
			expect_equal(migrated_result$value, legacy_result$value, tolerance = 1e-6, info = label)
		}
	}
})

test_that("InferenceSurvivalKKStratCoxPHOneLik is marked migrated and the raw splice is gone", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceSurvivalKKStratCoxPHOneLik")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceSurvivalKKStratCoxPHOneLik"]]$migration_status, "migrated")
	src_path = file.path(testthat::test_path(), "..", "..", "R", "inference_survival_KK_strat_cox.R")
	if (!file.exists(src_path)) {
		installed_path = system.file("R", "inference_survival_KK_strat_cox.R", package = "EDI")
		if (nzchar(installed_path)) src_path = installed_path
	}
	if (file.exists(src_path)) {
		src = readLines(src_path, warn = FALSE)
		code_lines = ifelse(grepl("^\\s*#", src), "", src)
		expect_false(any(grepl("as.list(InferenceMixinKKPassThrough", code_lines, fixed = TRUE)))
	}
})
