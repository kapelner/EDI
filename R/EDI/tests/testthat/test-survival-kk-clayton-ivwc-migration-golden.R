library(testthat)
library(EDI)

# InferenceSurvivalKKClaytonCopulaIVWC migration (fix_inference_hierarchy.md,
# "KK And IVWC Estimators"): from a plain leaf on the
# `InferenceKKPassThroughCompoundNoParamBootstrap` ladder (with an
# `eval(body(...))` bootstrap override and a pure-passthrough `duplicate()`)
# to `define_inference_class()` composing
# `BayesianBootstrap`/`Wald`/`SurvivalKKClaytonCopulaIVWC` (static leaf
# source, `dependencies = "KKCompound"`). The legacy generator reproduces
# the pre-migration class verbatim, evaluated-body override included, using
# the REAL classname (see the count-KK golden for why fixtures must not use
# a "...Legacy" suffix: name-keyed optimizer policy and capability
# resolution).
make_clayton_ivwc_legacy_generator = function() {
	src = EDI:::SurvivalKKClaytonCopulaIVWCSource
	R6::R6Class(
		"InferenceSurvivalKKClaytonCopulaIVWC",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceKKPassThroughCompoundNoParamBootstrap,
		public = c(
			src$public,
			list(
				approximate_bootstrap_distribution_beta_hat_T = function(B = 501, show_progress = TRUE, debug = FALSE, bootstrap_type = NULL){
					eval(body(EDI:::InferenceMixinKKPassThrough$public$approximate_bootstrap_distribution_beta_hat_T))
				},
				duplicate = function(verbose = FALSE, make_fork_cluster = FALSE){
					inf_obj = super$duplicate(verbose = verbose, make_fork_cluster = make_fork_cluster)
					inf_obj
				}
			)
		),
		private = src$private
	)
}

clayton_golden_design = function(n = 24L, seed = 20260817L) {
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

# Intentionally-dropped likelihood-test API family: same verified pattern as
# the InferenceIncidRiskDiff / KK Newcombe migrations -- on the old ladder the
# score/gradient/LR CIs silently returned Wald-identical bounds and the
# p-values NA (the AsympLik fallback family); tier-"none"-style surface a
# no-LikelihoodTests composition correctly drops.
clayton_dropped_labels = c(
	"score_ci", "score_pval", "gradient_ci", "gradient_pval",
	"lik_ratio_ci", "lik_ratio_pval", "param_boot_pval", "param_boot_ci"
)

test_that("InferenceSurvivalKKClaytonCopulaIVWC migration produces identical outputs", {
	Legacy = make_clayton_ivwc_legacy_generator()
	des = clayton_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceSurvivalKKClaytonCopulaIVWC$new(des)
	for (label in names(inference_migration_method_calls)) {
		spec = inference_migration_method_calls[[label]]
		legacy$set_seed(20260817L)
		legacy_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(legacy, spec$method, spec$args))
		migrated$set_seed(20260817L)
		migrated_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(migrated, spec$method, spec$args))
		if (label %in% clayton_dropped_labels) {
			expect_identical(migrated_result$status, "absent", info = label)
			if (identical(legacy_result$status, "ok")) {
				legacy_value = as.numeric(legacy_result$value)
				legacy$set_seed(20260817L)
				legacy_wald_ci = inference_migration_with_seed(20260817L,
					as.numeric(legacy$compute_wald_confidence_interval(alpha = 0.2)))
				degenerate = all(is.na(legacy_value))
				wald_fallback = length(legacy_value) == 2L && all(is.finite(legacy_value)) &&
					isTRUE(all.equal(legacy_value, legacy_wald_ci, tolerance = 1e-10))
				expect_true(degenerate || wald_fallback,
					info = paste0(label, ": legacy produced a real non-Wald value; dropping it would lose real surface"))
			}
			next
		}
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

test_that("InferenceSurvivalKKClaytonCopulaIVWC is marked migrated in the registry", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceSurvivalKKClaytonCopulaIVWC")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceSurvivalKKClaytonCopulaIVWC"]]$migration_status, "migrated")
})
