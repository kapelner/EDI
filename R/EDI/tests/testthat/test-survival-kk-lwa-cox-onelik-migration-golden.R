library(testthat)
library(EDI)

# InferenceSurvivalKKLWACoxPHOneLik migration (fix_inference_hierarchy.md,
# "Partial-Likelihood Estimators" / "KK And IVWC Estimators"): pre-migration
# this was a two-layer ladder -- abstract `InferenceAbstractKKLWACoxOneLik`
# on `InferenceParamBootstrap` (raw-splicing `InferenceMixinKKPassThrough$
# public/private`) plus a thin assertFormula/delegating leaf. Both layers
# were merged into the previously shim-only registered component source
# `KKLWACoxOneLikPartialLikelihoodSource` (`dependencies` reshaped from
# `"ParametricLikelihoodBootstrap"` alone to `c("KKPassThrough",
# "ParametricLikelihoodBootstrap")`) and the class is now
# `define_inference_class()` composing
# `BayesianBootstrap`/`KKLWACoxOneLikPartialLikelihood`. Unlike every KK
# leaf migrated earlier this stretch, this is a REAL full-likelihood-tier
# ("partial") class with score/gradient/LR test support and parametric-
# bootstrap LR calibration (`get_likelihood_test_spec()`/
# `simulate_under_lik_null()`), so `metadata$capabilities =
# "likelihood_ratio"` had to be declared explicitly (no component spec in
# this codebase declares `provides_capabilities = "likelihood_ratio"`
# anywhere; every class composing `ParametricLikelihoodBootstrap` directly
# rather than through `StandardModelCache` needs this, matching
# `InferenceOrdinalCauchitRegr`/`InferenceOrdinalCloglogRegr`'s identical
# requirement). The legacy generator below -- source spliced straight onto
# `InferenceParamBootstrap` -- reproduces the pre-migration class verbatim.
# Real classname on the fixture (see the count-KK golden for why
# "...Legacy" suffixes break dispatch).
# NOTE: `inherit = InferenceParamBootstrap` does NOT itself supply
# `init_kk_passthrough` (it's not KK-specific) -- the pre-migration abstract
# got it via a raw splice (`as.list(InferenceMixinKKPassThrough$private)`)
# that the merged Source deliberately dropped (the migrated class gets it
# via composing the KKPassThrough component instead). The legacy fixture
# must therefore replicate that same raw splice manually to be faithful.
make_survival_kk_lwa_cox_onelik_legacy_generator = function() {
	src = EDI:::KKLWACoxOneLikPartialLikelihoodSource
	R6::R6Class(
		"InferenceSurvivalKKLWACoxPHOneLik",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceParamBootstrap,
		public = utils::modifyList(as.list(EDI:::InferenceMixinKKPassThrough$public), src$public),
		private = utils::modifyList(as.list(EDI:::InferenceMixinKKPassThrough$private), src$private)
	)
}

survival_kk_lwa_cox_onelik_golden_design = function(n = 24L, seed = 20260817L) {
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

test_that("InferenceSurvivalKKLWACoxPHOneLik migration produces identical outputs", {
	Legacy = make_survival_kk_lwa_cox_onelik_legacy_generator()
	des = survival_kk_lwa_cox_onelik_golden_design()
	# A FRESH legacy/migrated pair is built per label rather than reused
	# across the whole loop (unlike every other golden this stretch), because
	# of a found-and-documented PRE-EXISTING NATIVE CRASH (see
	# fix_inference_hierarchy.md's Follow-Ups entry, "InferenceSurvivalKK
	# LWACoxPHOneLik native segfault..."): calling `compute_rand_two_sided_
	# pval()` (which mutates `private$w`/`private$y`/`private$dead` in place
	# during its permutation loop, then explicitly re-reads them from the
	# design object afterward -- see `compute_treatment_estimate_during_
	# randomization_inference`'s own comment) and THEN calling
	# `approximate_rand_bootstrap_distribution_beta_hat_T()` on the SAME
	# object segfaults inside `fast_coxph_regression_cpp` (a dimension/
	# pointer mismatch reaching the reusable-bootstrap-worker's duplicated
	# private state). Reproduced identically on a from-scratch reconstruction
	# of the pre-migration legacy class -- not a migration regression.
	# Rebuilding fresh objects per label sidesteps the corrupting call-order
	# entirely while still comparing every label's own in-isolation output.
	for (label in names(inference_migration_method_calls)) {
		spec = inference_migration_method_calls[[label]]
		legacy = Legacy$new(des)
		migrated = InferenceSurvivalKKLWACoxPHOneLik$new(des)
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

test_that("InferenceSurvivalKKLWACoxPHOneLik is marked migrated and eval(body) is gone from its files", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceSurvivalKKLWACoxPHOneLik")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceSurvivalKKLWACoxPHOneLik"]]$migration_status, "migrated")
	for (f in c("inference_survival_KK_lwa_cox.R", "inference_survival_KK_lwa_cox_one_lik_abstract.R")) {
		src_path = file.path(testthat::test_path(), "..", "..", "R", f)
		if (!file.exists(src_path)) {
			installed_path = system.file("R", f, package = "EDI")
			if (nzchar(installed_path)) src_path = installed_path
		}
		if (file.exists(src_path)) {
			src = readLines(src_path, warn = FALSE)
			code_lines = ifelse(grepl("^\\s*#", src), "", src)
			expect_false(any(grepl("as.list(InferenceMixinKKPassThrough", code_lines, fixed = TRUE)), label = f)
		}
	}
})
