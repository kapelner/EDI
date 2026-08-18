library(testthat)
library(EDI)

# InferenceIncidKKGCompRiskDiff / InferenceIncidKKGCompRiskRatio migration
# (fix_inference_hierarchy.md, "KK And IVWC Estimators"): from a three-tier
# R6 chain (concrete leaf -- previously an empty `public = list()` R6 leaf
# with only `build_design_matrix`/`get_estimand_type` privates --
# -> `InferenceIncidKKGCompAbstract` [gcomp machinery] ->
# `InferenceAbstractKKMarginalIncid` [KK cluster helpers, raw-splices
# `InferenceMixinKKPassThrough`, inherits `InferenceParamBootstrap`]) to
# `define_inference_class()` composing `BayesianBootstrap`/`Jackknife`/
# `IncidenceKKGComputation`. `InferenceIncidKKGCompAbstract` and
# `InferenceAbstractKKMarginalIncid` are BOTH deliberately left untouched as
# real R6 generators (not deleted/converted): `InferenceAbstractKKMarginalIncid`
# is also the parent of `InferenceAbstractKKModifiedPoisson`/
# `InferenceIncidKKModifiedPoisson`, a separate estimator family not migrated
# in this change, so its R6 ladder must keep working. The new
# `IncidenceKKGComputationSource` self-harvests `InferenceIncidKKGCompAbstract`'s
# own body via `inference_component_source_parts()` (same pattern as the
# non-KK sibling `IncidenceGComputationSource`) and manually layers in a
# fresh `initialize` (replicating `InferenceAbstractKKMarginalIncid`'s: assert
# + Lesson 1's explicit `private$init_kk_passthrough()`) plus that class's
# `get_cluster_ids`/`get_covariate_names`/`compute_basic_match_data`/
# `supports_likelihood_tests` helpers, copied verbatim since that abstract
# isn't itself a registered component. The generic-self-aliased-override
# pattern for methods whose harvested bodies called `super$...` mirrors
# `incidence_gcomp_generic_alias_overrides` (same six methods), but the
# `compute_rand_two_sided_pval` pin differs from that non-KK sibling: this
# class's legacy ladder (InferenceParamBootstrap -> ... -> InferenceRandCI)
# resolves to InferenceRandCI's version, not InferenceRand's (verified via
# R6 ancestor walk -- InferenceRand's version refuses incidence data
# outright, which the legacy class does not do). The legacy fixture below
# reconstructs the full 3-tier chain verbatim (only `build_design_matrix`/
# `get_estimand_type` differ between the RD/RR fixtures, matching the real
# leaves). Real classnames (see the count-KK golden for why "...Legacy"
# suffixes break dispatch); `parametric_likelihood_bootstrap` capability
# transitional-exclusion entries for both classes were removed from
# `EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES` since the migrated classes no
# longer accidentally inherit that capability at all.
# NOTE: written as two literal generators rather than one parameterized
# factory function -- R6 rebinds each method's enclosing environment to the
# instance at construction time, which breaks ordinary lexical closure over
# a factory function's local variables (see the identical note in
# test-kk-quantile-regr-ivwc-migration-golden.R).
make_incid_kk_gcomp_rd_legacy_generator = function() {
	R6::R6Class(
		"InferenceIncidKKGCompRiskDiff",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceIncidKKGCompAbstract,
		public = list(),
		private = list(
			build_design_matrix = function(){
				private$create_design_matrix()
			},
			get_estimand_type = function() "RD"
		)
	)
}

make_incid_kk_gcomp_rr_legacy_generator = function() {
	R6::R6Class(
		"InferenceIncidKKGCompRiskRatio",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceIncidKKGCompAbstract,
		public = list(),
		private = list(
			build_design_matrix = function(){
				private$create_design_matrix()
			},
			get_estimand_type = function() "RR"
		)
	)
}

incid_kk_gcomp_golden_design = function(n = 24L, seed = 20260817L) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			des$add_one_subject_response(i, stats::rbinom(1L, 1L, stats::plogis(-0.4 + 0.9 * ((w_i + 1) / 2) + 0.3 * X$x1[i])))
		}
		des
	})
}

incid_kk_gcomp_maybe_dropped_labels = c(
	"score_ci", "score_pval", "gradient_ci", "gradient_pval",
	"lik_ratio_ci", "lik_ratio_pval", "param_boot_pval", "param_boot_ci"
)

# RR's compute_effect_pvalue() rejects delta <= 0 ("For RR inference, delta
# must be strictly positive"); the harness's generic label specs hardcode
# delta = 0 for every pval label regardless of estimand, which every RR-type
# class (KK or non-KK) would reject identically -- not a migration issue,
# just untested infrastructure until this golden. Substitute the correct
# per-estimand null (0 for RD, 1 for RR, matching default_null_value()) for
# every delta-bearing label when running the RR golden.
incid_kk_gcomp_resolve_args = function(spec, estimand){
	args = spec$args
	if (identical(estimand, "RR") && "delta" %in% names(args) && identical(args$delta, 0)){
		args$delta = 1
	}
	args
}

run_incid_kk_gcomp_golden = function(legacy, migrated, estimand){
	for (label in names(inference_migration_method_calls)) {
		spec = inference_migration_method_calls[[label]]
		args = incid_kk_gcomp_resolve_args(spec, estimand)
		# score_ci/score_pval/gradient_ci/gradient_pval/lik_ratio_ci/lik_ratio_pval
		# are probed on a throwaway deep clone, not the shared `legacy`/`migrated`
		# objects used for every other label -- same corrupting-side-effect
		# precaution as the quantile-regr IVWC golden (this class's legacy
		# AsympLik-fallback score/gradient/LR machinery is not verified free of
		# the same kind of cross-call state leakage, and isolating the probe
		# costs nothing when it turns out to be clean).
		is_probed_on_clone = label %in% incid_kk_gcomp_maybe_dropped_labels
		legacy_call_target = if (is_probed_on_clone) legacy$clone(deep = TRUE) else legacy
		migrated_call_target = if (is_probed_on_clone) migrated$clone(deep = TRUE) else migrated
		legacy_call_target$set_seed(20260817L)
		legacy_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(legacy_call_target, spec$method, args))
		migrated_call_target$set_seed(20260817L)
		migrated_result = inference_migration_with_seed(20260817L,
			inference_migration_call_optional_method(migrated_call_target, spec$method, args))
		if (legacy_result$status %in% c("absent", "unsupported") &&
				migrated_result$status %in% c("absent", "unsupported")) {
			next
		}
		if (label %in% incid_kk_gcomp_maybe_dropped_labels && identical(migrated_result$status, "absent")) {
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

test_that("InferenceIncidKKGCompRiskDiff migration produces identical outputs", {
	Legacy = make_incid_kk_gcomp_rd_legacy_generator()
	des = incid_kk_gcomp_golden_design()
	run_incid_kk_gcomp_golden(Legacy$new(des, verbose = FALSE), InferenceIncidKKGCompRiskDiff$new(des, verbose = FALSE), "RD")
})

test_that("InferenceIncidKKGCompRiskRatio migration produces identical outputs", {
	skip_on_cran()
	Legacy = make_incid_kk_gcomp_rr_legacy_generator()
	des = incid_kk_gcomp_golden_design()
	run_incid_kk_gcomp_golden(Legacy$new(des, verbose = FALSE), InferenceIncidKKGCompRiskRatio$new(des, verbose = FALSE), "RR")
})

test_that("KK g-computation leaves are marked migrated in the registry", {
	EDI:::populate_inference_class_registry()
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	for (cls in c("InferenceIncidKKGCompRiskDiff", "InferenceIncidKKGCompRiskRatio")) {
		metadata = EDI:::get_inference_class_metadata(cls)
		expect_identical(metadata$parent, "Inference", info = cls)
		expect_identical(manifest[[cls]]$migration_status, "migrated", info = cls)
	}
})
