library(testthat)
library(EDI)

# InferenceIncidKKCondLogitGLMMIVWC/InferenceIncidKKCondLogitGLMMOneLik
# migration (fix_inference_hierarchy.md, "KK And IVWC Estimators", "Migrate
# KK GEE and GLMM classes"): both are plain R6::R6Class leaves inheriting
# from the shared abstract base InferenceAbstractKKCondLogitGLMM
# (inference_incidence_KK_cond_logit_glmm_abstract.R), which was flipped
# from the hybrid `define_inference_class(inherit = InferenceParamBootstrap,
# components = "KKPassThrough")` state to `inherit = Inference` with
# `components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap",
# "KKPassThrough")` -- same hybrid-state fix as InferenceContinKKGLMM/
# InferenceCountKKGLMM/InferenceOrdinalKKGLMM. Neither leaf class calls
# `super$...()` anywhere in its own body (verified by grep), so no
# generic-alias overrides were needed. The abstract base's own
# `get_standard_error` was moved from `public` to `private` during this
# migration (see that file's comment): it was public-only pre-migration,
# harmless only because KKPassThrough alone never pulled in a competing
# private `get_standard_error`; composing ParametricLikelihoodBootstrap now
# does (via its LikelihoodTests -> Wald dependency chain), so the
# public/private duplicate had to be resolved -- moving to `private`
# (the canonical location everywhere else in the codebase) preserves
# behavior exactly since no caller used `$get_standard_error()` publicly.
# The legacy fixture below (fixtures/legacy_kk_cond_logit_glmm.R) is the
# pre-migration file content of all three files (the abstract base plus
# both leaves) copied verbatim from git HEAD, with top-level class bindings
# renamed to avoid colliding with the real migrated classes, but the
# literal class-name STRINGs kept unchanged (dispatch-by-name policies key
# off `class(self)[1]`; see the analogous Contin/Count/OrdinalKKGLMM golden
# tests for the numeric-drift bug this avoids) -- sourced into a child
# environment of the EDI namespace (not the namespace itself, which is
# locked against new top-level bindings).
# 2026-11-03 (v1.0.5 TODO-173): deliberate deviation from the verbatim
# pre-migration snapshot. After the migration the incidence leaves' model was
# replaced (conditional logit on discordant pairs + logistic regression on the
# reservoir, instead of a random-intercept GLMM on concordant pairs), so the
# live methods implementing it are grafted onto the frozen classes here. This
# keeps the golden doing its job -- comparing the old inheritance ladder with
# the new composition for every inherited driver (bootstrap, randomization,
# jackknife, likelihood tests) -- rather than comparing two different models.
kk_cond_logit_reservoir_logit_private_methods = c(
	"uses_reservoir_logit", "prepare_clogit_reservoir_logit_data", "assemble_clogit_reservoir_logit",
	"fit_clogit_reservoir_logit", "clogit_reservoir_logit_score", "clogit_reservoir_logit_information",
	"clogit_reservoir_logit_coefs_out_of_bounds", "shared_clogit_reservoir_logit",
	"compute_clogit_reservoir_logit_weighted_estimate", "get_clogit_reservoir_logit_spec",
	"shared", "get_likelihood_test_spec"
)
make_kk_cond_logit_glmm_legacy_env = function() {
	env = new.env(parent = asNamespace("EDI"))
	sys.source(testthat::test_path("fixtures", "legacy_kk_cond_logit_glmm.R"), envir = env)
	live = EDI:::InferenceAbstractKKCondLogitGLMM
	legacy_base = get("InferenceAbstractKKCondLogitGLMMLegacyOrig", envir = env)
	for (nm in kk_cond_logit_reservoir_logit_private_methods) {
		legacy_base$set("private", nm, live$private_methods[[nm]], overwrite = TRUE)
	}
	legacy_base$set("public", "compute_estimate_with_bootstrap_weights",
		live$public_methods$compute_estimate_with_bootstrap_weights, overwrite = TRUE)
	for (leaf in c("InferenceIncidKKCondLogitGLMMIVWCLegacyOrig", "InferenceIncidKKCondLogitGLMMOneLikLegacyOrig")) {
		get(leaf, envir = env)$set("private", "uses_reservoir_logit", function() TRUE, overwrite = TRUE)
	}
	env
}

kk_cond_logit_glmm_incid_golden_design = function(n = 60L, seed = 20260819L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			des$add_one_subject_response(i, rbinom(1L, 1L, plogis(0.3 * ((w_i + 1) / 2) + 0.2 * X$x1[i])))
		}
		des
	})
}

run_kk_cond_logit_glmm_golden_comparison = function(Legacy, migrated_generator, des, constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)) {
	legacy = do.call(Legacy$new, c(list(des), constructor_args))
	migrated = do.call(migrated_generator$new, c(list(des), constructor_args))
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
}

test_that("InferenceIncidKKCondLogitGLMMIVWC migration produces identical outputs", {
	env = make_kk_cond_logit_glmm_legacy_env()
	des = kk_cond_logit_glmm_incid_golden_design()
	run_kk_cond_logit_glmm_golden_comparison(
		get("InferenceIncidKKCondLogitGLMMIVWCLegacyOrig", envir = env),
		InferenceIncidKKCondLogitGLMMIVWC,
		des
	)
})

test_that("InferenceIncidKKCondLogitGLMMOneLik migration produces identical outputs", {
	env = make_kk_cond_logit_glmm_legacy_env()
	des = kk_cond_logit_glmm_incid_golden_design()
	run_kk_cond_logit_glmm_golden_comparison(
		get("InferenceIncidKKCondLogitGLMMOneLikLegacyOrig", envir = env),
		InferenceIncidKKCondLogitGLMMOneLik,
		des
	)
})

test_that("InferenceAbstractKKCondLogitGLMM base is marked migrated", {
	# The two concrete leaf classes plain-R6-inherit from
	# InferenceAbstractKKCondLogitGLMM rather than composing directly, so
	# their own migration_status stays "pending" under
	# build_inference_hierarchy_migration_record()'s heuristic (it only
	# auto-detects "migrated" when a class's *immediate* parent is
	# "Inference") -- same as every other already-migrated
	# InferenceAsympLikStdModCache leaf (e.g. InferenceIncidProbitRegr,
	# confirmed still "pending" despite its shared base being fully
	# composed). What matters is the shared abstract base itself.
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceAbstractKKCondLogitGLMM")
	expect_identical(metadata$parent, "Inference")
})
