library(testthat)
library(EDI)

# InferenceOrdinalKKCLMM/...Probit/...Cauchit/...Cloglog migration
# (fix_inference_hierarchy.md, "Partial-Likelihood Estimators", "Migrate KK
# partial-likelihood classes"): all four are plain R6::R6Class leaves
# inheriting from the shared abstract base InferenceAbstractKKOrdinalCLMM
# (inference_ordinal_KK_clmm_abstract.R), which was flipped from the hybrid
# `define_inference_class(inherit = InferenceAsympLik, components =
# "KKPassThrough")` state to `inherit = Inference` with `components =
# c("BayesianBootstrap", "Wald", "KKPassThrough")` -- same fix, same
# rationale, as InferenceOrdinalKKCondAdjCatLogitRegr (see that class's
# golden test for the full writeup; this class's `supports_likelihood_tests()`
# is also hard-`FALSE`, so it never gets ParametricLikelihoodBootstrap's
# transitive Wald, and its `compute_rand_two_sided_pval` pin resolved to the
# same `InferenceRandCI` version via the same pre-migration ancestor walk).
# None of the four leaves call `super$...()` anywhere in their own bodies
# (verified by grep), so no generic-alias overrides were needed. The legacy
# fixture below (fixtures/legacy_ordinal_kk_clmm.R) is the pre-migration
# file content of all five classes (the abstract base plus all four link
# leaves) copied verbatim from git HEAD, with top-level class bindings
# renamed to avoid colliding with the real migrated classes but literal
# class-name STRINGs kept unchanged for dispatch-by-name policies.
make_ordinal_kk_clmm_legacy_env = function() {
	env = new.env(parent = asNamespace("EDI"))
	sys.source(testthat::test_path("fixtures", "legacy_ordinal_kk_clmm.R"), envir = env)
	env
}

ordinal_kk_clmm_golden_design = function(n = 60L, seed = 20260819L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			eta = 0.4 * ((w_i + 1) / 2) + 0.2 * X$x1[i]
			u = runif(1L)
			cuts = plogis(c(-0.8, 0.2, 1.2) - eta)
			y = if (u <= cuts[1L]) 1L else if (u <= cuts[2L]) 2L else if (u <= cuts[3L]) 3L else 4L
			des$add_one_subject_response(i, y)
		}
		des
	})
}

# Same leaked-InferenceAsympLik-ladder-plumbing pattern as
# InferenceOrdinalKKCondAdjCatLogitRegr (see that class's golden test for the
# full writeup): `supports_likelihood_tests() = FALSE` and
# `set_testing_type("score"/"gradient"/"lik_ratio")` correctly throws on both
# legacy and migrated, but calling compute_score/gradient/lik_ratio_*()
# directly (bypassing that gate) reaches pre-migration ladder plumbing that
# silently returns NA or falls back to the Wald result rather than erroring
# -- surface the migrated (flat composition) class no longer exposes at all.
ordinal_kk_clmm_maybe_dropped_labels = c(
	"score_ci", "score_pval", "gradient_ci", "gradient_pval",
	"lik_ratio_ci", "lik_ratio_pval"
)

run_ordinal_kk_clmm_golden_comparison = function(Legacy, migrated_generator, des) {
	legacy = Legacy$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	migrated = migrated_generator$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
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
		if (label %in% ordinal_kk_clmm_maybe_dropped_labels && identical(migrated_result$status, "absent")) {
			if (identical(legacy_result$status, "ok")) {
				legacy_value = as.numeric(legacy_result$value)
				degenerate = all(is.na(legacy_value))
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
}

test_that("InferenceOrdinalKKCLMM migration produces identical outputs", {
	env = make_ordinal_kk_clmm_legacy_env()
	des = ordinal_kk_clmm_golden_design()
	run_ordinal_kk_clmm_golden_comparison(get("InferenceOrdinalKKCLMMLegacyOrig", envir = env), InferenceOrdinalKKCLMM, des)
})

test_that("InferenceOrdinalKKCLMMProbit migration produces identical outputs", {
	env = make_ordinal_kk_clmm_legacy_env()
	des = ordinal_kk_clmm_golden_design()
	run_ordinal_kk_clmm_golden_comparison(get("InferenceOrdinalKKCLMMProbitLegacyOrig", envir = env), InferenceOrdinalKKCLMMProbit, des)
})

test_that("InferenceOrdinalKKCLMMCauchit migration produces identical outputs", {
	env = make_ordinal_kk_clmm_legacy_env()
	des = ordinal_kk_clmm_golden_design()
	run_ordinal_kk_clmm_golden_comparison(get("InferenceOrdinalKKCLMMCauchitLegacyOrig", envir = env), InferenceOrdinalKKCLMMCauchit, des)
})

test_that("InferenceOrdinalKKCLMMCloglog migration produces identical outputs", {
	env = make_ordinal_kk_clmm_legacy_env()
	des = ordinal_kk_clmm_golden_design()
	run_ordinal_kk_clmm_golden_comparison(get("InferenceOrdinalKKCLMMCloglogLegacyOrig", envir = env), InferenceOrdinalKKCLMMCloglog, des)
})

test_that("InferenceAbstractKKOrdinalCLMM base is marked migrated", {
	# The four concrete leaves plain-R6-inherit from
	# InferenceAbstractKKOrdinalCLMM rather than composing directly, so their
	# own migration_status stays "pending" under
	# build_inference_hierarchy_migration_record()'s heuristic (it only
	# auto-detects "migrated" when a class's *immediate* parent is
	# "Inference") -- same as every already-migrated
	# InferenceAsympLikStdModCache leaf and the KKCondLogitGLMM family. What
	# matters is the shared abstract base itself.
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceAbstractKKOrdinalCLMM")
	expect_identical(metadata$parent, "Inference")
})
