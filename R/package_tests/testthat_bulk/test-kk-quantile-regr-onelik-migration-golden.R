library(testthat)
library(EDI)

# InferenceContinKKQuantileRegrOneLik / InferencePropKKQuantileRegrOneLik
# migration (fix_inference_hierarchy.md, "Full-Likelihood Estimators" / "KK
# And IVWC Estimators"): from a three-tier R6 chain -- concrete leaf ->
# `InferenceAbstractKKQuantileRegrOneLik` (shared estimator machinery) ->
# `InferenceAbstractQuantileRandCI` (the same hybrid class as the IVWC
# sibling family) -- to two `define_inference_class()` factories composing
# `BayesianBootstrap`/`Wald`/`KKQuantileRegrOneLik` (the latter now a static
# component with `dependencies = c("KKCompound", "QuantileRandomizationCI")`,
# no `ParametricLikelihoodBootstrap` since this class has no real
# likelihood-test surface despite the "OneLik" naming). Same free-function-
# helper Lesson-1 corollary as the IVWC sibling's golden (see that file's
# header comment for the full explanation): `.init_kk_quantile_regr_one_lik()`
# is called directly from each leaf's own `initialize`, not via
# `super$initialize()`. The pre-migration leaves' `compute_estimate =
# function(estimate_only = FALSE) super$compute_estimate()` was a pure
# delegating passthrough with no added logic -- dropped from both migrated
# classes, letting the composed component's real `compute_estimate` win
# directly (declared as a collision override on the factory since Wald's
# generic default also defines the name).
# NOTE: the "abstract" layer is reconstructed as a real R6 generator below,
# same reasoning and same lazy-`inherit=`-evaluation constraint as the IVWC
# golden's legacy generators (see that file's header comment).
make_contin_kk_quantile_regr_one_lik_legacy_generator = function() {
	R6::R6Class(
		"InferenceContinKKQuantileRegrOneLik",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = R6::R6Class(
			"InferenceAbstractKKQuantileRegrOneLikLegacy",
			lock_objects = FALSE,
			parent_env = asNamespace("EDI"),
			inherit = EDI:::InferenceAbstractQuantileRandCI,
			public = EDI:::KKQuantileRegrOneLikSource$public,
			private = EDI:::KKQuantileRegrOneLikSource$private
		),
		public = list(
			initialize = function(des_obj, model_formula = NULL, tau = 0.5, verbose = FALSE){
				if (should_run_asserts()) {
					assertResponseType(des_obj$get_response_type(), "continuous")
				}
				super$initialize(des_obj, tau, identity, verbose = verbose, model_formula = model_formula)
				if (should_run_asserts()) {
					assertNoCensoring(private$any_censoring)
				}
			},
			compute_estimate = function(estimate_only = FALSE) super$compute_estimate()
		)
	)
}

make_prop_kk_quantile_regr_one_lik_legacy_generator = function() {
	R6::R6Class(
		"InferencePropKKQuantileRegrOneLik",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = R6::R6Class(
			"InferenceAbstractKKQuantileRegrOneLikLegacy",
			lock_objects = FALSE,
			parent_env = asNamespace("EDI"),
			inherit = EDI:::InferenceAbstractQuantileRandCI,
			public = EDI:::KKQuantileRegrOneLikSource$public,
			private = EDI:::KKQuantileRegrOneLikSource$private
		),
		public = list(
			initialize = function(des_obj, model_formula = NULL, tau = 0.5, verbose = FALSE){
				if (should_run_asserts()) {
					assertResponseType(des_obj$get_response_type(), "proportion")
				}
				super$initialize(des_obj, tau, qlogis, verbose = verbose, model_formula = model_formula)
				if (should_run_asserts()) {
					assertNoCensoring(private$any_censoring)
				}
				private$y = .sanitize_proportion_response(private$y, interior = TRUE)
				if (should_run_asserts()) {
					assertNumeric(private$y, any.missing = FALSE, lower = .Machine$double.eps, upper = 1 - .Machine$double.eps)
				}
				private$cached_values$KKstats = NULL
				private$compute_basic_match_data()
			},
			compute_estimate = function(estimate_only = FALSE) super$compute_estimate()
		)
	)
}

kk_quantile_regr_one_lik_golden_design = function(response_type, seed = 20260817L, n = 24L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			if (identical(response_type, "continuous")) {
				des$add_one_subject_response(i, 0.6 * ((w_i + 1) / 2) + 0.3 * X$x1[i] + rnorm(1L, sd = 0.8))
			} else {
				des$add_one_subject_response(i, stats::plogis(0.6 * ((w_i + 1) / 2) + 0.3 * X$x1[i] + rnorm(1L, sd = 0.8)))
			}
		}
		des
	})
}

kk_quantile_regr_one_lik_maybe_dropped_labels = c(
	"score_ci", "score_pval", "gradient_ci", "gradient_pval",
	"lik_ratio_ci", "lik_ratio_pval", "param_boot_pval", "param_boot_ci"
)

run_kk_quantile_regr_one_lik_golden = function(legacy, migrated) {
	for (label in names(inference_migration_method_calls)) {
		spec = inference_migration_method_calls[[label]]
		# Same isolation precaution as the IVWC sibling's golden: probe the
		# maybe-dropped labels on a throwaway deep clone in case this legacy
		# class exhibits the same corrupting side effect its IVWC sibling has.
		is_probed_on_clone = label %in% kk_quantile_regr_one_lik_maybe_dropped_labels
		legacy_call_target = if (is_probed_on_clone) legacy$clone(deep = TRUE) else legacy
		legacy_call_target$set_seed(20260817L)
		legacy_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(legacy_call_target, spec$method, spec$args))
		migrated$set_seed(20260817L)
		migrated_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(migrated, spec$method, spec$args))
		if (legacy_result$status %in% c("absent", "unsupported") &&
				migrated_result$status %in% c("absent", "unsupported")) {
			next
		}
		if (label %in% kk_quantile_regr_one_lik_maybe_dropped_labels && identical(migrated_result$status, "absent")) {
			if (identical(legacy_result$status, "ok")) {
				legacy_value = as.numeric(legacy_result$value)
				legacy_call_target$set_seed(20260817L)
				legacy_wald_ci = inference_migration_with_seed(20260817L,
					as.numeric(legacy_call_target$compute_wald_confidence_interval(alpha = 0.2)))
				degenerate = all(is.na(legacy_value))
				if (!degenerate && length(legacy_value) == 2L && all(is.finite(legacy_value)) &&
						isTRUE(all.equal(legacy_value[1L], legacy_value[2L], tolerance = 1e-8))) {
					legacy_call_target$set_seed(20260817L)
					legacy_estimate = inference_migration_with_seed(20260817L,
						as.numeric(legacy_call_target$compute_estimate()))
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

test_that("InferenceContinKKQuantileRegrOneLik migration produces identical outputs", {
	skip_if_not_installed("quantreg")
	Legacy = make_contin_kk_quantile_regr_one_lik_legacy_generator()
	des = kk_quantile_regr_one_lik_golden_design("continuous")
	run_kk_quantile_regr_one_lik_golden(Legacy$new(des), InferenceContinKKQuantileRegrOneLik$new(des))
})

test_that("InferenceContinKKQuantileRegrOneLik randomization CI matches", {
	skip_on_cran()
	skip_if_not_installed("quantreg")
	Legacy = make_contin_kk_quantile_regr_one_lik_legacy_generator()
	des = kk_quantile_regr_one_lik_golden_design("continuous")
	legacy = Legacy$new(des)
	migrated = InferenceContinKKQuantileRegrOneLik$new(des)
	legacy$set_seed(20260817L)
	legacy_ci = inference_migration_with_seed(20260817L, legacy$compute_rand_confidence_interval(r = 51L))
	migrated$set_seed(20260817L)
	migrated_ci = inference_migration_with_seed(20260817L, migrated$compute_rand_confidence_interval(r = 51L))
	expect_equal(migrated_ci, legacy_ci, tolerance = 1e-6)
})

test_that("InferencePropKKQuantileRegrOneLik migration produces identical outputs", {
	skip_on_cran()
	skip_if_not_installed("quantreg")
	Legacy = make_prop_kk_quantile_regr_one_lik_legacy_generator()
	des = kk_quantile_regr_one_lik_golden_design("proportion")
	run_kk_quantile_regr_one_lik_golden(Legacy$new(des), InferencePropKKQuantileRegrOneLik$new(des))
})

test_that("KK one-likelihood quantile-regression leaves are marked migrated in the registry", {
	EDI:::populate_inference_class_registry()
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	for (cls in c("InferenceContinKKQuantileRegrOneLik", "InferencePropKKQuantileRegrOneLik")) {
		metadata = EDI:::get_inference_class_metadata(cls)
		expect_identical(metadata$parent, "Inference", info = cls)
		expect_identical(manifest[[cls]]$migration_status, "migrated", info = cls)
	}
})
