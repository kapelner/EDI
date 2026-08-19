library(testthat)
library(EDI)

# InferenceCountKKHurdlePoissonOneLik migration (fix_inference_hierarchy.md,
# "Full-Likelihood Estimators" / "KK And IVWC Estimators"): formerly a
# single-layer R6 leaf inheriting `InferenceParamBootstrap` and raw-splicing
# `InferenceMixinKKPassThrough$public/private`. This class's own
# `compute_score_confidence_interval`/`compute_lik_ratio_confidence_interval`/
# `compute_gradient_confidence_interval`/`compute_score_two_sided_pval`/
# `compute_lik_ratio_two_sided_pval`/`compute_gradient_two_sided_pval` are
# NOT pure delegating passthroughs -- each computes a "design-conservative"
# combination of a design-based CI/p-value and a "model"-based CI/p-value
# obtained via `super$...()` under the old ladder (reaching InferenceAsympLik's
# generic likelihood-test dispatch). Since a flat composition has no `super$`
# path into a component's own method once the host wins that name collision
# (Lesson 1), those six `super$...()` calls became `self$..._generic()` calls
# against six new aliases bound directly from
# `InferenceAsympLik$public_methods$...` -- the same generic-`self$`-aliased-
# override pattern `incidence_gcomp_generic_alias_overrides`
# (inference_incidence_gcomp.R) already uses for exactly this problem.
# `get_standard_error` copied in verbatim (Lesson 5: this class never defined
# it itself, relying on InferenceMLEorKMSummaryTable's graceful NA-on-
# missing-SE version via the old ladder). No KKCompound dependency: this
# class's own `compute_basic_match_data` uses `.compute_kk_basic_match_data_
# cached()` directly and its `initialize` performs its own manual match-
# structure setup rather than calling `init_kk_passthrough()` -- no Lesson-1
# fix needed there (preserved verbatim).
# The legacy generator below manually re-splices `InferenceMixinKKPassThrough$
# public/private` onto `InferenceParamBootstrap` (the merged Source
# deliberately dropped both the splice and the no-op `eval(body(...))`
# `approximate_bootstrap_distribution_beta_hat_T` restatement) to stay
# faithful, same treatment as `test-count-kk-hurdle-ivwc-migration-golden.R`'s
# legacy fixture.
make_count_kk_hurdle_onelik_legacy_generator = function() {
	src = EDI:::CountKKHurdlePoissonOneLikLikelihoodSource
	legacy_public = utils::modifyList(
		as.list(EDI:::InferenceMixinKKPassThrough$public),
		c(
			src$public,
			list(
				approximate_bootstrap_distribution_beta_hat_T = function(B = 501, show_progress = TRUE, debug = FALSE, bootstrap_type = NULL){
					eval(body(EDI:::InferenceMixinKKPassThrough$public$approximate_bootstrap_distribution_beta_hat_T))
				}
			)
		)
	)
	legacy_private = utils::modifyList(
		as.list(EDI:::InferenceMixinKKPassThrough$private),
		src$private
	)
	R6::R6Class(
		"InferenceCountKKHurdlePoissonOneLik",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceParamBootstrap,
		public = legacy_public,
		private = legacy_private
	)
}

count_kk_hurdle_onelik_golden_design = function(n = 40L, seed = 20260819L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			des$add_one_subject_response(i, rpois(1L, exp(0.4 + 0.35 * ((w_i + 1) / 2) + 0.2 * X$x1[i])))
		}
		des
	})
}

test_that("InferenceCountKKHurdlePoissonOneLik migration produces identical outputs", {
	Legacy = make_count_kk_hurdle_onelik_legacy_generator()
	des = count_kk_hurdle_onelik_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceCountKKHurdlePoissonOneLik$new(des)
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

test_that("InferenceCountKKHurdlePoissonOneLik is marked migrated", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceCountKKHurdlePoissonOneLik")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceCountKKHurdlePoissonOneLik"]]$migration_status, "migrated")
})
