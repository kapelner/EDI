library(testthat)
library(EDI)

# InferenceSurvivalKKWeibullFrailtyOneLik migration (fix_inference_hierarchy.md,
# "Full-Likelihood Estimators" / "KK And IVWC Estimators"): same structural
# shape as InferenceSurvivalKKClaytonCopulaOneLik's migration (see that
# golden's header comment for the full rationale) -- pre-existing self-
# harvested components (`SurvivalKKWeibullFrailtyOneLik` for the abstract,
# `SurvivalKKWeibullFrailtyOneLikLeaf` for the thin concrete leaf) already
# existed. Unlike Clayton (single layer), this was a genuine two-layer chain
# (abstract `InferenceAbstractKKWeibullFrailtyOneLik` raw-splicing
# `InferenceMixinKKPassThrough$public/private` onto `InferenceParamBootstrap`,
# plus a thin concrete leaf using TRUE R6 inheritance onto the abstract, only
# overriding `initialize`). Both raw R6 generators are kept alive under
# renamed, non-exported bindings (`InferenceAbstractKKWeibullFrailtyOneLikLegacyRaw`
# / `InferenceSurvivalKKWeibullFrailtyOneLikLegacyRaw`) purely so the
# pre-existing harvests still have something to snapshot from. Two
# `super$compute_asymp_confidence_interval`/`super$compute_asymp_two_sided_pval`
# fallback calls in the abstract (same "wald" fast-path/fallback-for-others
# shape as `InferenceIncidKKCondLogitOneLik`) rewritten to `self$..._generic()`
# aliases. New wrinkle not seen in the Clayton migration: the leaf's own
# `initialize` (`self$set_optimization_alg(optimization_alg); super$initialize(
# ...)`) cannot reach the abstract component's initialize via `super$` under a
# flat composition (Lesson 1 corollary) -- solved by ordering
# `SurvivalKKWeibullFrailtyOneLikLeak` BEFORE `SurvivalKKWeibullFrailtyOneLik`
# in the factory's `components =` vector so the abstract's fuller initialize
# (which already calls `set_optimization_alg()` itself, making the leaf's own
# call redundant) resolves last and wins the collision.
make_survival_kk_weibull_frailty_onelik_legacy_generator = function() {
	EDI:::InferenceSurvivalKKWeibullFrailtyOneLikLegacyRaw
}

survival_kk_weibull_frailty_onelik_golden_design = function(n = 24L, seed = 20260817L) {
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

test_that("InferenceSurvivalKKWeibullFrailtyOneLik migration produces identical outputs", {
	Legacy = make_survival_kk_weibull_frailty_onelik_legacy_generator()
	des = survival_kk_weibull_frailty_onelik_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceSurvivalKKWeibullFrailtyOneLik$new(des)
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

test_that("InferenceSurvivalKKWeibullFrailtyOneLik is marked migrated", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceSurvivalKKWeibullFrailtyOneLik")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceSurvivalKKWeibullFrailtyOneLik"]]$migration_status, "migrated")
})
