library(testthat)
library(EDI)

# InferenceSurvivalKKWeibullMarginal migration (fix_inference_hierarchy.md,
# "KK And IVWC Estimators", second named target): from a raw
# `modifyList(InferenceMixinKKPassThrough$public/$private, ...)` splice class
# inheriting `InferenceAsymp` (whose component was self-harvested via
# `inference_component_source_parts()`) to `define_inference_class()`
# composing `BayesianBootstrap`/`Wald`/`SurvivalKKWeibullMarginal`, where the
# component is now a static leaf source with `dependencies = "KKPassThrough"`
# -- the mixin content arrives through the registered KKPassThrough component
# and the resolution order reproduces the old modifyList precedence. The old
# `eval(body(...))` bootstrap override is gone (the KKPassThrough component
# supplies the real function), closing one Static Cleanup "Ban eval(body())"
# usage. The legacy generator below reproduces the pre-migration class
# verbatim, splices included.
make_kk_weibull_marginal_legacy_generator = function() {
	# Deliberately the REAL classname (not "...Legacy"): capability resolution
	# (Inference$capabilities() walks to the nearest REGISTERED class) and any
	# name-keyed dispatch tables treat an unregistered suffixed name
	# differently -- e.g. inference_uses_model_scale_randomization_transform()
	# reads capabilities() and a "...Legacy" fixture loses kk_passthrough,
	# flipping the randomization-CI transform path. Same rename rationale as
	# the count-KK golden's fixture. Local variable binding only; no registry
	# interference.
	R6::R6Class(
		"InferenceSurvivalKKWeibullMarginal",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceAsymp,
		public = as.list(utils::modifyList(as.list(EDI:::InferenceMixinKKPassThrough$public), list(
			initialize = function(des_obj, model_formula = NULL, verbose = FALSE){
				if (EDI:::should_run_asserts()) {
					checkmate::assertChoice(des_obj$get_response_type(), "survival")
				}
				super$initialize(des_obj = des_obj, verbose = verbose, model_formula = model_formula)
				private$init_kk_passthrough(des_obj)
			},
			compute_estimate = function(estimate_only = FALSE){
				private$shared(estimate_only = estimate_only)
				private$cached_values$beta_hat_T
			},
			compute_estimate_with_bootstrap_weights = EDI:::SurvivalKKWeibullMarginalSource$public$compute_estimate_with_bootstrap_weights,
			compute_asymp_confidence_interval = EDI:::SurvivalKKWeibullMarginalSource$public$compute_asymp_confidence_interval,
			compute_asymp_two_sided_pval = EDI:::SurvivalKKWeibullMarginalSource$public$compute_asymp_two_sided_pval,
			approximate_bootstrap_distribution_beta_hat_T = function(B = 501, show_progress = TRUE, debug = FALSE, bootstrap_type = NULL){
				eval(body(EDI:::InferenceMixinKKPassThrough$public$approximate_bootstrap_distribution_beta_hat_T))
			},
			duplicate = function(verbose = FALSE, make_fork_cluster = FALSE){
				super$duplicate(verbose = verbose, make_fork_cluster = make_fork_cluster)
			}
		))),
		private = as.list(utils::modifyList(as.list(EDI:::InferenceMixinKKPassThrough$private), c(
			list(
				cached_mod = NULL,
				best_X_colnames = NULL,
				cached_vc_params = NULL,
				max_abs_reasonable_coef = 1e4
			),
			Filter(is.function, EDI:::SurvivalKKWeibullMarginalSource$private)
		)))
	)
}

kk_weibull_golden_design = function(n = 24L, seed = 20260817L) {
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

test_that("InferenceSurvivalKKWeibullMarginal migration produces identical outputs", {
	Legacy = make_kk_weibull_marginal_legacy_generator()
	des = kk_weibull_golden_design()
	legacy = Legacy$new(des)
	migrated = InferenceSurvivalKKWeibullMarginal$new(des)
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

test_that("InferenceSurvivalKKWeibullMarginal is marked migrated and eval(body) is gone from its file", {
	EDI:::populate_inference_class_registry()
	metadata = EDI:::get_inference_class_metadata("InferenceSurvivalKKWeibullMarginal")
	expect_identical(metadata$parent, "Inference")
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	expect_identical(manifest[["InferenceSurvivalKKWeibullMarginal"]]$migration_status, "migrated")
	src_path = file.path(testthat::test_path(), "..", "..", "R", "inference_survival_KK_weibull_marginal.R")
	if (!file.exists(src_path)) {
		installed_path = system.file("R", "inference_survival_KK_weibull_marginal.R", package = "EDI")
		if (nzchar(installed_path)) src_path = installed_path
	}
	if (file.exists(src_path)) {
		src = readLines(src_path, warn = FALSE)
		expect_false(any(grepl("eval(body(", src, fixed = TRUE)))
		expect_false(any(grepl("modifyList(as.list(InferenceMixinKKPassThrough", src, fixed = TRUE)))
	}
})
