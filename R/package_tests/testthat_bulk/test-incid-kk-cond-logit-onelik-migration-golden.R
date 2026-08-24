library(testthat)
library(EDI)

# InferenceIncidKKCondLogitOneLik migration (fix_inference_hierarchy.md,
# "Full-Likelihood Estimators" / "KK And IVWC Estimators"): formerly a
# single-layer R6 leaf raw-splicing `InferenceMixinKKPassThrough$public/
# private` onto `InferenceParamBootstrap`. This class's own
# `compute_asymp_confidence_interval`/`compute_asymp_two_sided_pval`
# fast-path the "wald" testing type directly and fall back to `super$...()`
# for score/gradient/lik_ratio (reaching `InferenceAsympLik`'s generic
# switch dispatch, now `self$..._generic()` aliases bound from
# `InferenceAsympLik$public_methods$...`, same technique as the count OneLik
# migrations' `self$..._generic` aliases -- see either of those goldens'
# header comments for the full rationale). This class's own
# `compute_basic_match_data = function() private$compute_basic_kk_match_data_
# impl()` was a verified no-op restatement of
# `InferenceMixinKKPassThrough`'s own default body -- dropped, along with
# the usual no-op `eval(body(...))`
# `approximate_bootstrap_distribution_beta_hat_T` restatement. Incidence
# class, so the fixture pin is `InferenceRandCI` (Zhang dispatch), not
# `InferenceRand` -- Lesson 3, matching the already-migrated IVWC sibling.
# The legacy generator below manually re-splices
# `InferenceMixinKKPassThrough$public/private` onto `InferenceParamBootstrap`
# and re-adds both dropped no-op restatements, same treatment as the count
# OneLik goldens' legacy fixtures.
make_incid_kk_cond_logit_onelik_legacy_generator = function() {
	src = EDI:::IncidKKCondLogitOneLikLikelihoodSource
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
		c(
			src$private,
			list(
				compute_basic_match_data = function() private$compute_basic_kk_match_data_impl()
			)
		)
	)
	R6::R6Class(
		"InferenceIncidKKCondLogitOneLik",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceParamBootstrap,
		public = legacy_public,
		private = legacy_private
	)
}

incid_kk_cond_logit_onelik_golden_design = function(n = 30L, seed = 20260819L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			des$add_one_subject_response(i, stats::rbinom(1L, 1L, stats::plogis(-0.3 + 0.8 * ((w_i + 1) / 2) + 0.25 * X$x1[i])))
		}
		des
	})
}

test_that("InferenceIncidKKCondLogitOneLik migration produces identical outputs", {
	Legacy = make_incid_kk_cond_logit_onelik_legacy_generator()
	des = incid_kk_cond_logit_onelik_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceIncidKKCondLogitOneLik$new(des)
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

test_that("InferenceIncidKKCondLogitOneLik is marked migrated", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceIncidKKCondLogitOneLik")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceIncidKKCondLogitOneLik"]]$migration_status, "migrated")
})
