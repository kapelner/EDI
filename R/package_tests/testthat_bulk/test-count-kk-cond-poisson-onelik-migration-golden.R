library(testthat)
library(EDI)

# InferenceCountKKCondPoissonOneLik migration (fix_inference_hierarchy.md,
# "Full-Likelihood Estimators" / "KK And IVWC Estimators"): same shape and
# same generic-`self$`-aliased-override fix as
# `InferenceCountKKHurdlePoissonOneLik`'s migration (see that golden's
# header comment for the full rationale) -- formerly a single-layer R6 leaf
# raw-splicing `InferenceMixinKKPassThrough$public/private` onto
# `InferenceParamBootstrap`, with six `compute_score/lik_ratio/gradient_*`
# overrides computing a "design-adjusted" combination via `super$...()` into
# InferenceAsympLik's generic likelihood-test dispatch (now `self$..._generic()`
# aliases bound from `InferenceAsympLik$public_methods$...`). Unlike
# HurdlePoisson OneLik, this class's `initialize` DID already call
# `private$init_kk_passthrough(des_obj)` explicitly (preserved verbatim, no
# Lesson-1 fix needed). `get_standard_error` copied in verbatim (Lesson 5).
# The legacy generator below manually re-splices
# `InferenceMixinKKPassThrough$public/private` onto `InferenceParamBootstrap`
# and re-adds the dropped no-op `eval(body(...))`
# `approximate_bootstrap_distribution_beta_hat_T` restatement, same
# treatment as the HurdlePoisson OneLik golden's legacy fixture.
make_count_kk_cpoisson_onelik_legacy_generator = function() {
	src = EDI:::CountKKCondPoissonOneLikLikelihoodSource
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
		"InferenceCountKKCondPoissonOneLik",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceParamBootstrap,
		public = legacy_public,
		private = legacy_private
	)
}

count_kk_cpoisson_onelik_golden_design = function(n = 40L, seed = 20260819L) {
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

test_that("InferenceCountKKCondPoissonOneLik migration produces identical outputs", {
	Legacy = make_count_kk_cpoisson_onelik_legacy_generator()
	des = count_kk_cpoisson_onelik_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceCountKKCondPoissonOneLik$new(des)
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

test_that("InferenceCountKKCondPoissonOneLik is marked migrated", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceCountKKCondPoissonOneLik")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceCountKKCondPoissonOneLik"]]$migration_status, "migrated")
})
