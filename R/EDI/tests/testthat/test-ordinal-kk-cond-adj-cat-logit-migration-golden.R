library(testthat)
library(EDI)

# InferenceOrdinalKKCondAdjCatLogitRegr migration (fix_inference_hierarchy.md,
# "Partial-Likelihood Estimators", "Migrate KK partial-likelihood classes"):
# flipped from the hybrid `define_inference_class(inherit = InferenceAsympLik,
# components = c("OrdinalConditionalLogitPartialLikelihood", "KKPassThrough"))`
# state (already a factory call composing the right domain components, but
# still R6-inheriting the deep InferenceAsympLik/InferenceAsymp/.../Wald
# ladder for compute_z_or_t_*/get_standard_error/etc.) to `inherit =
# Inference` with `Wald` composed explicitly (this class's
# `supports_likelihood_tests()` is hard-`FALSE`, so it never gets
# ParametricLikelihoodBootstrap, whose LikelihoodTests dependency would
# otherwise pull Wald in transitively -- same rationale as every other
# Wald-only KK IVWC class). No method bodies were touched (only the
# inherit/components/pins/overrides), so the legacy fixture below is the
# pre-migration file content verbatim (fixtures/legacy_ordinal_kk_cond_adj_
# cat_logit.R, copied from git HEAD, with the top-level class binding
# renamed to avoid colliding with the real migrated class but the literal
# class-name STRING kept unchanged for dispatch-by-name policies) -- sourced
# into a child environment of the EDI namespace.
make_ordinal_kk_cond_adj_cat_logit_legacy_generator = function() {
	env = new.env(parent = asNamespace("EDI"))
	sys.source(testthat::test_path("fixtures", "legacy_ordinal_kk_cond_adj_cat_logit.R"), envir = env)
	get("InferenceOrdinalKKCondAdjCatLogitRegrLegacyOrig", envir = env)
}

ordinal_kk_cond_adj_cat_logit_golden_design = function(n = 80L, seed = 3L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			eta = 0.5 * ((w_i + 1) / 2) + 0.2 * X$x1[i]
			u = runif(1L)
			cuts = plogis(c(-0.8, 0.2, 1.2) - eta)
			y = if (u <= cuts[1L]) 1L else if (u <= cuts[2L]) 2L else if (u <= cuts[3L]) 3L else 4L
			des$add_one_subject_response(i, y)
		}
		des
	})
}

# This class hard-declares `supports_likelihood_tests() = FALSE` and
# `set_testing_type("score"/"gradient"/"lik_ratio")` correctly throws "does
# not support testing_type" on both legacy and migrated -- confirming the
# class's own designed API surface is unchanged by the migration. But
# calling `compute_score_two_sided_pval()`/`compute_gradient_confidence_
# interval()`/`compute_lik_ratio_*()` *directly* (bypassing that gate, which
# is exactly what the golden harness's method-name-keyed labels below do)
# reaches leaked InferenceAsympLik ladder plumbing on the pre-migration
# (deep R6 inheritance) legacy class that silently returns NA rather than
# erroring -- there is no real (non-degenerate) value being dropped here,
# just an inaccessible-via-the-documented-API artifact of the old ladder
# that the migrated (flat composition, no LikelihoodTests component)
# class no longer exposes at all. Same "maybe dropped label, verify the
# legacy value was actually degenerate" pattern as
# test-incid-kk-cond-logit-ivwc-migration-golden.R.
ordinal_kk_cond_adj_cat_logit_maybe_dropped_labels = c(
	"score_ci", "score_pval", "gradient_ci", "gradient_pval",
	"lik_ratio_ci", "lik_ratio_pval"
)

test_that("InferenceOrdinalKKCondAdjCatLogitRegr migration produces identical outputs", {
	Legacy = make_ordinal_kk_cond_adj_cat_logit_legacy_generator()
	des = ordinal_kk_cond_adj_cat_logit_golden_design()
	legacy = Legacy$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	migrated = InferenceOrdinalKKCondAdjCatLogitRegr$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
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
		if (label %in% ordinal_kk_cond_adj_cat_logit_maybe_dropped_labels && identical(migrated_result$status, "absent")) {
			if (identical(legacy_result$status, "ok")) {
				legacy_value = as.numeric(legacy_result$value)
				degenerate = all(is.na(legacy_value))
				# Some of these leaked ladder methods (e.g. score_ci) turn out to
				# just silently fall back to the Wald result rather than NA --
				# still not real score/gradient/lik_ratio surface, just a
				# different flavor of "not actually computing what its name
				# claims." Confirmed via test-incid-kk-cond-logit-ivwc-migration-
				# golden.R's identical wald_fallback check for the sibling class.
				legacy$set_seed(20260819L)
				legacy_wald_ci = inference_migration_with_seed(20260819L,
					as.numeric(legacy$compute_wald_confidence_interval(alpha = 0.2)))
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
})

test_that("InferenceOrdinalKKCondAdjCatLogitRegr is marked migrated", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceOrdinalKKCondAdjCatLogitRegr")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceOrdinalKKCondAdjCatLogitRegr"]]$migration_status, "migrated")
})
