library(testthat)
library(EDI)

# InferenceContinKKQuantileRegrIVWC / InferencePropKKQuantileRegrIVWC
# migration (fix_inference_hierarchy.md, "KK And IVWC Estimators"): from a
# three-tier R6 chain -- concrete leaf -> `InferenceAbstractKKQuantileRegrIVWC`
# (shared estimator machinery) -> `InferenceAbstractQuantileRandCI` (a
# *hybrid* class: already `define_inference_class(inherit =
# InferenceKKPassThroughCompoundNoParamBootstrap, components =
# "QuantileRandomizationCI")`) -- to two `define_inference_class()` factories
# composing `BayesianBootstrap`/`Wald`/`KKQuantileRegrIVWC` (the latter now a
# static component with `dependencies = c("KKCompound",
# "QuantileRandomizationCI")`). Because two concrete leaves share this one
# component and each needs different response-type assertions and
# post-init logic wrapped around the same KK-setup/tau/transform_y_fn
# machinery, the merged Source's initialize body was factored into a plain
# free-function helper (`.init_kk_quantile_regr_ivwc()`, same pattern as the
# existing `.compute_kk_basic_match_data_cached()` helper) that each leaf's
# own `initialize` calls directly, passing its own `super` -- `super$
# initialize()` must be called from inside a method actually defined on each
# leaf, since a flat composition's `overrides` mechanism means the
# component's own `initialize` is otherwise unreachable once a host wins the
# name collision (Lesson 1 corollary). Despite the "KK" name, the class
# supports both kk14/kk21 sequential designs and DesignFixedBinaryMatch (both
# pass `is_a_kk_matching_capable()`); only the kk14/kk21 golden path is
# exercised here (matching every other KK/IVWC golden this stretch). Real
# classname on both fixtures (see the count-KK golden for why "...Legacy"
# suffixes break dispatch).
# NOTE: the "abstract" layer is reconstructed as a real R6 generator below
# (rather than reusing KKQuantileRegrIVWCSource's public/private directly on
# each concrete leaf) because the pre-migration 3-tier chain had the leaf's
# super$initialize() calling the ABSTRACT's tau/transform_y_fn-aware
# initialize, not InferenceAbstractQuantileRandCI's tau-agnostic one
# directly. Written out as an inline `R6::R6Class(...)` expression passed
# directly to `inherit = ` (rather than a variable/function call) because
# `inherit = ` is evaluated lazily in `parent_env` (the EDI namespace) at
# `$new()` time, where a locally-defined test symbol is not visible -- only
# a self-contained expression referencing exclusively namespace-qualified
# (`EDI:::...`) or base symbols survives that deferred re-evaluation.
make_contin_kk_quantile_regr_legacy_generator = function() {
	R6::R6Class(
		"InferenceContinKKQuantileRegrIVWC",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = R6::R6Class(
			"InferenceAbstractKKQuantileRegrIVWCLegacy",
			lock_objects = FALSE,
			parent_env = asNamespace("EDI"),
			inherit = EDI:::InferenceAbstractQuantileRandCI,
			public = EDI:::KKQuantileRegrIVWCSource$public,
			private = EDI:::KKQuantileRegrIVWCSource$private
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
			}
		)
	)
}

make_prop_kk_quantile_regr_legacy_generator = function() {
	R6::R6Class(
		"InferencePropKKQuantileRegrIVWC",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = R6::R6Class(
			"InferenceAbstractKKQuantileRegrIVWCLegacy",
			lock_objects = FALSE,
			parent_env = asNamespace("EDI"),
			inherit = EDI:::InferenceAbstractQuantileRandCI,
			public = EDI:::KKQuantileRegrIVWCSource$public,
			private = EDI:::KKQuantileRegrIVWCSource$private
		),
		public = list(
			initialize = function(des_obj, model_formula = NULL, tau = 0.5, verbose = FALSE, smart_cold_start_default = NULL){
				if (should_run_asserts()) {
					assertResponseType(des_obj$get_response_type(), "proportion")
				}
				super$initialize(des_obj = des_obj, model_formula = model_formula, tau = tau, transform_y_fn = qlogis, verbose = verbose, smart_cold_start_default = smart_cold_start_default)
				if (should_run_asserts()) {
					assertNoCensoring(private$any_censoring)
				}
				private$y = .sanitize_proportion_response(private$y, interior = TRUE)
				if (should_run_asserts()) {
					assertNumeric(private$y, any.missing = FALSE, lower = .Machine$double.eps, upper = 1 - .Machine$double.eps)
				}
				private$cached_values$KKstats = NULL
				private$compute_basic_match_data()
			}
		)
	)
}

kk_quantile_regr_golden_design = function(response_type, seed = 20260817L, n = 24L) {
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

kk_quantile_regr_maybe_dropped_labels = c(
	"score_ci", "score_pval", "gradient_ci", "gradient_pval",
	"lik_ratio_ci", "lik_ratio_pval", "param_boot_pval", "param_boot_ci"
)

run_kk_quantile_regr_golden = function(legacy, migrated) {
	for (label in names(inference_migration_method_calls)) {
		spec = inference_migration_method_calls[[label]]
		# score_ci/score_pval/gradient_ci/gradient_pval/lik_ratio_ci/lik_ratio_pval
		# are probed on a throwaway deep clone, not the shared `legacy` used for
		# every other label: this class's legacy score/gradient/lik_ratio-test
		# machinery has a demonstrated corrupting side effect on
		# private$cached_values$beta_hat_T that only manifests several calls
		# later (after the bootstrap-worker machinery runs), silently turning
		# compute_estimate() -- and everything downstream, including
		# randomization_ci -- into NA on the SAME shared object for the rest of
		# the loop. Since the migrated side never exposes these labels at all
		# (verified absent), this corrupting call path can never be reached in
		# the new architecture; isolating the probe preserves every other
		# label's real bit-identical comparison for the remainder of the run.
		is_probed_on_clone = label %in% kk_quantile_regr_maybe_dropped_labels
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
		if (label %in% kk_quantile_regr_maybe_dropped_labels && identical(migrated_result$status, "absent")) {
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

test_that("InferenceContinKKQuantileRegrIVWC migration produces identical outputs", {
	skip_if_not_installed("quantreg")
	Legacy = make_contin_kk_quantile_regr_legacy_generator()
	des = kk_quantile_regr_golden_design("continuous")
	run_kk_quantile_regr_golden(Legacy$new(des), InferenceContinKKQuantileRegrIVWC$new(des))
})

test_that("InferenceContinKKQuantileRegrIVWC randomization CI matches", {
	skip_if_not_installed("quantreg")
	Legacy = make_contin_kk_quantile_regr_legacy_generator()
	des = kk_quantile_regr_golden_design("continuous")
	legacy = Legacy$new(des)
	migrated = InferenceContinKKQuantileRegrIVWC$new(des)
	legacy$set_seed(20260817L)
	legacy_ci = inference_migration_with_seed(20260817L, legacy$compute_rand_confidence_interval(r = 51L))
	migrated$set_seed(20260817L)
	migrated_ci = inference_migration_with_seed(20260817L, migrated$compute_rand_confidence_interval(r = 51L))
	expect_equal(migrated_ci, legacy_ci, tolerance = 1e-6)
})

test_that("InferencePropKKQuantileRegrIVWC migration produces identical outputs", {
	skip_if_not_installed("quantreg")
	Legacy = make_prop_kk_quantile_regr_legacy_generator()
	des = kk_quantile_regr_golden_design("proportion")
	run_kk_quantile_regr_golden(Legacy$new(des), InferencePropKKQuantileRegrIVWC$new(des))
})

test_that("KK quantile-regression leaves are marked migrated in the registry", {
	EDI:::populate_inference_class_registry()
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	for (cls in c("InferenceContinKKQuantileRegrIVWC", "InferencePropKKQuantileRegrIVWC")) {
		metadata = EDI:::get_inference_class_metadata(cls)
		expect_identical(metadata$parent, "Inference", info = cls)
		expect_identical(manifest[[cls]]$migration_status, "migrated", info = cls)
	}
})
