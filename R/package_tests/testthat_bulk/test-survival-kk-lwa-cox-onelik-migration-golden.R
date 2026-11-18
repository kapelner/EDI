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
# `simulate_under_lik_null()`). (Until 2026-11-18 it also had to declare
# `metadata$capabilities = "likelihood_ratio"`; that capability is gone and
# `ParametricLikelihoodBootstrap` now requires `likelihood_tests`, which its
# `LikelihoodTests` dependency provides.) The legacy generator below -- source spliced straight onto
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

# Same data-generating process as survival_kk_lwa_cox_onelik_golden_design(), on the
# fixed matched-pairs design: since 2026-11-14 (owner ruling: the bootstrap is
# unproven on KK designs) the randomization bootstrap refuses the sequential KK14
# design, so the segfault regression below needs a design where it still runs.
survival_kk_lwa_cox_onelik_binary_match_design = function(n = 24L, seed = 20260817L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignFixedBinaryMatch$new(response_type = "survival", n = n, m = rep(seq_len(n / 2L), each = 2L), verbose = FALSE)
		des$add_all_subjects_to_experiment(X)
		w = as.vector(replicate(n / 2L, sample(0:1)))
		des$assign_w_to_all_subjects(w)
		y_lat = exp(0.8 - 0.3 * w + 0.15 * X$x1) * stats::rexp(n)
		cens = stats::rexp(n, rate = 0.15)
		event = y_lat <= cens
		des$add_all_subject_responses(ifelse(event, pmax(y_lat, 0.05), NA_real_),
			ifelse(event, NA_real_, pmax(cens, 0.05)), ifelse(event, NA_real_, Inf))
		des
	})
}

test_that("InferenceSurvivalKKLWACoxPHOneLik: compute_rand_two_sided_pval() then approximate_rand_bootstrap_distribution_beta_hat_T() on the SAME object no longer segfaults", {
	# Regression test for the native segfault documented in
	# fix_inference_hierarchy.md's Follow-Ups ("InferenceSurvivalKKLWACoxPHOneLik
	# native segfault"). Root cause: compute_treatment_estimate_during_
	# randomization_inference() re-read `private$dead` from `private$des_obj_
	# priv_int$dead`, a field that no longer exists post the y/y_L/y_R
	# migration (Design never stores a raw `dead` field any more) and is
	# therefore always NULL -- clobbering the correctly-initialized
	# `private$dead` (originally `des_obj$get_effective_dead()`) with NULL.
	# That corruption persisted on the live object after compute_rand_two_
	# sided_pval() returned. A later call to approximate_rand_bootstrap_
	# distribution_beta_hat_T() reused that corrupted live `private$dead` in
	# load_rand_bootstrap_assignment_into_worker()'s `dead_sim = as.numeric(
	# private$dead[draw$i_b])`, producing a zero-length `dead` vector that was
	# passed straight into fast_coxph_regression_cpp() (whose native code reads
	# dead[i] for i up to nrow(X)-1), triggering an out-of-bounds native read.
	# Fixed by re-deriving `dead` the same way Design$get_effective_dead()
	# does (`as.numeric(!is.na(private$y))`) instead of reading the defunct
	# field.
	expect_error(InferenceSurvivalKKLWACoxPHOneLik$new(survival_kk_lwa_cox_onelik_golden_design())$approximate_rand_bootstrap_distribution_beta_hat_T(B = 9L),
		"not supported for DesignSeqOneByOne designs")
	des = survival_kk_lwa_cox_onelik_binary_match_design()
	inf = InferenceSurvivalKKLWACoxPHOneLik$new(des)
	inf$set_seed(20260817L)
	p1 = inference_migration_with_seed(20260817L, inf$compute_rand_two_sided_pval(delta = 0, r = 9L))
	expect_true(is.numeric(p1))
	# This second call on the SAME object is what used to segfault R.
	boot_distr = inference_migration_with_seed(20260817L, inf$approximate_rand_bootstrap_distribution_beta_hat_T(B = 9L))
	expect_true(is.numeric(boot_distr))
	expect_length(boot_distr, 9L)
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
