library(testthat)
library(EDI)

# InferenceBaiAdjustedTKK14 / InferenceBaiAdjustedTKK21 migration
# (fix_inference_hierarchy.md, "KK And IVWC Estimators", abstract-base
# group): pre-migration this was a two-layer ladder -- abstract base
# `InferenceBaiAdjustedT` on `InferenceKKPassThroughCompoundNoParamBootstrap`
# holding all the machinery, plus two thin leaves each adding only a
# `distance` private that nothing calls. The machinery is now the shared
# registered `BaiAdjustedT` component (`dependencies = "KKCompound"`), and
# each leaf is `define_inference_class()` composing
# `BayesianBootstrap`/`Wald`/`BaiAdjustedT` plus its own host-level
# `distance` private. One intentional drop: the abstract's PRIVATE
# `duplicate` passthrough (`i = super$duplicate(...); i`) was unreachable
# (self$duplicate always resolves to the public root method) and
# define_inference_class() rejects a name in both public and private, so it
# is absent from the source -- the legacy generator below therefore also
# omits it, which is verbatim-faithful in behavior. Real classname fixtures
# (see the count-KK golden for why "...Legacy" suffixes break dispatch).
make_bai_legacy_generator = function(classname, distance_fn) {
	src = EDI:::BaiAdjustedTSource
	R6::R6Class(
		classname,
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceKKPassThroughCompoundNoParamBootstrap,
		public = src$public,
		private = c(src$private, list(distance = distance_fn))
	)
}

bai_golden_design = function(generator, n = 24L, seed = 20260817L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = generator$new(n = n, response_type = "continuous", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			des$add_one_subject_response(i, 0.6 * ((w_i + 1) / 2) + 0.3 * X$x1[i] + rnorm(1L, sd = 0.8))
		}
		des
	})
}

bai_maybe_dropped_labels = c(
	"score_ci", "score_pval", "gradient_ci", "gradient_pval",
	"lik_ratio_ci", "lik_ratio_pval", "param_boot_pval", "param_boot_ci"
)

run_bai_migration_golden = function(legacy, migrated) {
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
		if (label %in% bai_maybe_dropped_labels && identical(migrated_result$status, "absent")) {
			if (identical(legacy_result$status, "ok")) {
				legacy_value = as.numeric(legacy_result$value)
				legacy$set_seed(20260817L)
				legacy_wald_ci = inference_migration_with_seed(20260817L,
					as.numeric(legacy$compute_wald_confidence_interval(alpha = 0.2)))
				degenerate = all(is.na(legacy_value))
				# For this class the legacy score_ci comes back as a zero-width
				# interval collapsed onto the point estimate (both endpoints
				# 1.276772... vs Wald 0.826/1.728) -- the score-test inversion
				# degenerates because there is no real likelihood surface behind
				# it. A collapsed interval is degenerate legacy output, not real
				# surface, so it also licenses the drop.
				if (!degenerate && length(legacy_value) == 2L && all(is.finite(legacy_value)) &&
						isTRUE(all.equal(legacy_value[1L], legacy_value[2L], tolerance = 1e-8))) {
					legacy$set_seed(20260817L)
					legacy_estimate = inference_migration_with_seed(20260817L,
						as.numeric(legacy$compute_estimate()))
					degenerate = isTRUE(all.equal(legacy_value[1L], legacy_estimate, tolerance = 1e-6))
				}
				wald_fallback = length(legacy_value) == 2L && all(is.finite(legacy_value)) &&
					isTRUE(all.equal(legacy_value, legacy_wald_ci, tolerance = 1e-4))
				expect_true(degenerate || wald_fallback,
					info = paste0(label, ": legacy produced a real non-Wald value; dropping it would lose real surface"))
			}
			next
		}
		expect_identical(legacy_result$status, migrated_result$status, info = label)
		if (identical(legacy_result$status, "ok")) {
			expect_equal(migrated_result$value, legacy_result$value, tolerance = 1e-6, info = label)
		}
	}
}

test_that("InferenceBaiAdjustedTKK14 migration produces identical outputs", {
	skip_if_not_installed("nbpMatching")
	Legacy = make_bai_legacy_generator("InferenceBaiAdjustedTKK14",
		function(avg1, avg2) sum((avg1 - avg2)^2))
	des = bai_golden_design(DesignSeqOneByOneKK14)
	run_bai_migration_golden(Legacy$new(des, verbose = FALSE), InferenceBaiAdjustedTKK14$new(des, verbose = FALSE))
})

test_that("InferenceBaiAdjustedTKK14 convex-combination path matches", {
	skip_if_not_installed("nbpMatching")
	Legacy = make_bai_legacy_generator("InferenceBaiAdjustedTKK14",
		function(avg1, avg2) sum((avg1 - avg2)^2))
	des = bai_golden_design(DesignSeqOneByOneKK14)
	legacy = Legacy$new(des, verbose = FALSE, convex_flag = TRUE)
	migrated = InferenceBaiAdjustedTKK14$new(des, verbose = FALSE, convex_flag = TRUE)
	for (getter in c("compute_estimate", "compute_asymp_confidence_interval", "compute_asymp_two_sided_pval")) {
		expect_equal(migrated[[getter]](), legacy[[getter]](), tolerance = 1e-10, info = getter)
	}
})

test_that("InferenceBaiAdjustedTKK21 migration produces identical outputs", {
	skip_if_not_installed("nbpMatching")
	Legacy = make_bai_legacy_generator("InferenceBaiAdjustedTKK21",
		function(avg1, avg2) sum(private$des_obj_priv_int$covariate_weights * (avg1 - avg2)^2))
	des = bai_golden_design(DesignSeqOneByOneKK21)
	run_bai_migration_golden(Legacy$new(des, verbose = FALSE), InferenceBaiAdjustedTKK21$new(des, verbose = FALSE))
})

test_that("Bai leaves are marked migrated in the registry", {
	EDI:::populate_inference_class_registry()
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	for (cls in c("InferenceBaiAdjustedTKK14", "InferenceBaiAdjustedTKK21")) {
		metadata = EDI:::get_inference_class_metadata(cls)
		expect_identical(metadata$parent, "Inference", info = cls)
		expect_identical(manifest[[cls]]$migration_status, "migrated", info = cls)
	}
})
