library(testthat)
library(EDI)

# InferenceCountKKHurdlePoissonIVWC migration (fix_inference_hierarchy.md,
# "KK And IVWC Estimators", first named target): from a raw
# `modifyList(InferenceMixinKKPassThrough$public/$private, ...)` splice class
# inheriting `InferenceAsymp` to `define_inference_class()` composing
# `BayesianBootstrap`/`Wald`/`CountKKHurdlePoissonIVWC` (static leaf source,
# `dependencies = "KKPassThrough"`), the same shape as
# `InferenceSurvivalKKWeibullMarginal`'s migration. The old `eval(body(...))`
# bootstrap override is gone (KKPassThrough supplies the real function). The
# legacy generator reproduces the pre-migration class verbatim, splices and
# evaluated-body override included.
make_count_kk_hurdle_legacy_generator = function() {
	src = EDI:::CountKKHurdlePoissonIVWCSource
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
	# Deliberately the REAL classname (not "...Legacy"): globals.R keys the
	# optimizer policy on the $-anchored pattern "KKHurdlePoissonIVWC$", so a
	# suffixed fixture name silently got a different optimization algorithm
	# than the pre-migration class and drifted ~1e-4 -- caught by this very
	# golden before the rename. The generator is bound to a local variable
	# only; populate_inference_class_registry() scans the namespace, so no
	# registry interference.
	R6::R6Class(
		"InferenceCountKKHurdlePoissonIVWC",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceAsymp,
		public = as.list(legacy_public),
		private = as.list(legacy_private)
	)
}

count_kk_golden_design = function(n = 24L, seed = 20260817L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			is_zero = stats::rbinom(1L, 1L, stats::plogis(0.3 - 0.8 * ((w_i + 1) / 2)))
			pos = stats::rpois(1L, lambda = exp(0.4 + 0.35 * ((w_i + 1) / 2) + 0.2 * X$x1[i]))
			des$add_one_subject_response(i, if (is_zero == 1L) 0L else pos)
		}
		des
	})
}

test_that("InferenceCountKKHurdlePoissonIVWC migration produces identical outputs", {
	Legacy = make_count_kk_hurdle_legacy_generator()
	des = count_kk_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceCountKKHurdlePoissonIVWC$new(des)
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
			expect_equal(migrated_result$value, legacy_result$value, tolerance = 1e-7, info = label)
		}
	}
})

test_that("InferenceCountKKHurdlePoissonIVWC is marked migrated in the registry", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceCountKKHurdlePoissonIVWC")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceCountKKHurdlePoissonIVWC"]]$migration_status, "migrated")
})
