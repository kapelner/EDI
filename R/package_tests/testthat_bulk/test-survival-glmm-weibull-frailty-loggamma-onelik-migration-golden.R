library(testthat)
library(EDI)

# InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik migration (fix_inference_hierarchy.md,
# "Full-Likelihood Estimators" / "KK And IVWC Estimators"): formerly a
# single-layer R6 leaf raw-splicing `InferenceMixinKKPassThrough$public/
# private` onto `InferenceParamBootstrap`, no `super$` calls needing the
# generic-`self$`-aliased-override fix (unlike the count/incidence OneLik
# classes above). A registered component `SurvivalGLMMWeibullFrailtyLoggammaOneLik`
# already existed (self-harvested, `dependencies = character()`) -- since
# this class's public/private were built via a raw
# `modifyList(InferenceMixinKKPassThrough$public/private, list(...))` splice
# rather than true R6 inheritance, `inference_component_source_parts()`
# necessarily captures the FULL flattened surface (mixin content + own
# logic merged into one list at harvest time; R6 cannot separate "own" from
# "spliced-in" once they are merged like this, unlike the leaf-only+
# KKPassThrough-dependency shape used for every other OneLik class this
# stretch). The pre-migration class body itself is kept alive as the
# non-exported `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLikLegacyRaw` R6 generator
# purely so the harvest at load time has something to snapshot from -- see
# that variable's own header comment in inference_survival_KK_clayton_
# copula.R. Composed as `c("BayesianBootstrap", "ParametricLikelihoodBootstrap",
# "SurvivalGLMMWeibullFrailtyLoggammaOneLik")` (the harvested component supplies
# `get_likelihood_test_spec()` but not the public score/gradient/lik_ratio
# dispatch methods themselves, which `ParametricLikelihoodBootstrap`'s
# `LikelihoodTests` dependency provides). The legacy generator below simply
# instantiates the already-alive raw R6 generator directly (no re-splicing
# needed, unlike the count/incidence OneLik goldens, since the raw class was
# never modified).
# 2026-08-23 (fix_inference_hierarchy.md "Static Cleanup" / "Ban raw component
# splicing"): the `...LegacyRaw` generator is gone from the package (its
# source is now the plain leaf-only `SurvivalGLMMWeibullFrailtyLoggammaOneLikSource`
# depending on `KKPassThrough`), so -- exactly like the hurdle/cond-logit
# OneLik goldens -- the legacy generator is rebuilt here from that source
# plus the mixin, with the historical `optimization_alg = "lbfgs"`
# private-list redeclaration restored so it is the pre-migration object.
make_survival_kk_clayton_copula_onelik_legacy_generator = function() {
	src = EDI:::SurvivalGLMMWeibullFrailtyLoggammaOneLikSource
	mixin = EDI:::InferenceMixinKKPassThrough
	R6::R6Class(
		"InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceParamBootstrap,
		public = utils::modifyList(as.list(mixin$public), src$public),
		private = utils::modifyList(
			as.list(mixin$private),
			c(list(optimization_alg = "lbfgs"), src$private)
		)
	)
}

survival_kk_clayton_copula_onelik_golden_design = function(n = 24L, seed = 20260817L) {
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

# NOTE: this class's compute_treatment_estimate_during_randomization_
# inference() used to reassign `private$dead = private$des_obj_priv_int$dead`
# -- the defunct-field pattern documented and fixed in fix_inference_
# hierarchy.md's Follow-Ups (found 2026-08-19, fixed 2026-08-19 alongside the
# InferenceSurvivalKKLWACoxPHOneLik segfault and the WeibullFrailtyNormalOneLik/
# WeibullFrailtyLoggammaIVWC instances of the same bug). Before the fix this produced
# a genuine, identical-on-both-sides R error ("Clayton copula fit inputs must
# have matching row counts") from every randomization-family method on this
# golden design; the standard comparison loop below now covers those labels
# like any other (no special-casing needed post-fix).

test_that("InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik migration produces identical outputs", {
	Legacy = make_survival_kk_clayton_copula_onelik_legacy_generator()
	des = survival_kk_clayton_copula_onelik_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik$new(des)
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

test_that("InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik is marked migrated", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik"]]$migration_status, "migrated")
})
