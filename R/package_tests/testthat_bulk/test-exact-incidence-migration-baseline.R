library(testthat)
library(EDI)

exact_incidence_baseline_public_methods = c(
	"approximate_bayesian_bootstrap_distribution_beta_hat_T",
	"approximate_bootstrap_distribution_beta_hat_T",
	"approximate_jackknife_distribution_beta_hat_T",
	"approximate_m_out_of_n_bootstrap_distribution_beta_hat_T",
	"approximate_rand_bootstrap_distribution_beta_hat_T",
	"approximate_randomization_distribution_beta_hat_T",
	"approximate_subsampling_distribution_beta_hat_T",
	"capabilities",
	"clone",
	"compute_asymp_confidence_interval",
	"compute_asymp_two_sided_pval",
	"compute_bayesian_bootstrap_confidence_interval",
	"compute_bayesian_bootstrap_two_sided_pval",
	"compute_bootstrap_confidence_interval",
	"compute_bootstrap_two_sided_pval",
	"compute_estimate",
	"compute_estimate_with_bootstrap_weights",
	"compute_exact_confidence_interval",
	"compute_exact_two_sided_pval_for_treatment_effect",
	"compute_jackknife_bias_estimate",
	"compute_jackknife_estimate",
	"compute_jackknife_std_error",
	"compute_jackknife_wald_confidence_interval",
	"compute_jackknife_wald_two_sided_pval",
	"compute_m_out_of_n_bootstrap_confidence_interval",
	"compute_m_out_of_n_bootstrap_two_sided_pval",
	"compute_rand_bootstrap_confidence_interval",
	"compute_rand_bootstrap_two_sided_pval",
	"compute_rand_confidence_interval",
	"compute_rand_two_sided_pval",
	"compute_subsampling_confidence_interval",
	"compute_subsampling_sensitivity",
	"compute_subsampling_two_sided_pval",
	"duplicate",
	"get_analysis_data",
	"get_covariates",
	"get_design_object",
	"get_model_formula",
	"get_nonestimable_reason",
	"get_nonestimable_stage",
	"get_optimization_alg",
	"get_response",
	"get_response_type",
	# 2026-08-19 (inference_suite_inspect.md audit, "Add real
	# get_supported_*_types() accessor methods" TODO): six new public
	# accessors added to the NonparametricBootstrap/BayesianBootstrap/
	# RandomizationBootstrap(CI) components, all composed transitively by
	# every exact-incidence legacy generator here (via BayesianBootstrap).
	"get_supported_bayesian_bootstrap_ci_types",
	"get_supported_bayesian_bootstrap_pval_types",
	"get_supported_bootstrap_ci_types",
	"get_supported_bootstrap_pval_types",
	"get_supported_rand_bootstrap_ci_types",
	"get_supported_rand_bootstrap_pval_types",
	"get_treatment",
	"initialize",
	"is_nonestimable",
	"select_optimal_b_subsampling",
	"select_optimal_m_out_of_n_bootstrap",
	"set_custom_randomization_statistic_cpp",
	"set_custom_randomization_statistic_function",
	"set_optimization_alg",
	"set_seed",
	"supports",
	"supports_rand_pval_for_incidence"
)

# `resolve_exact_type`/`compute_exact_confidence_interval_by_type`/
# `compute_exact_two_sided_pval_for_treatment_effect_by_type`/
# `default_exact_type` used to also appear here (4 more names), back when the
# legacy generators below inherited `exact_test_private` from the standalone
# `InferenceExact` R6 class instead of having it merged directly into their
# own `private` list (see "Base Deletion" > `InferenceExact` in
# fix_inference_hierarchy.md, deleted 2026-08-16): those 4 names were
# defined at both the legacy generator's own level (via
# `ExactXXXIncidenceSource$private`) and `InferenceExact`'s level (via
# `exact_test_private`) -- two separate ancestor levels. Now that both live
# on the SAME (legacy generator's own) level, `inference_migration_
# duplicate_private_owners()`'s ancestor-chain walk correctly no longer
# counts them as duplicated -- they are still shadowed by
# `utils::modifyList()` at generator-construction time exactly as before,
# just no longer detectable as a *structural* R6 ancestor-chain duplication.
# The remaining 5 names below are genuine collisions with a still-separate,
# deeper ancestor (`InferenceRandCI`'s own Zhang-exact-CI private methods,
# `InferenceNonParamBootstrap`'s jackknife triplet) and are unaffected by
# the `InferenceExact` deletion.
exact_incidence_baseline_duplicate_private_owners = c(
	"normalize_exact_inference_args",
	"assert_exact_inference_params",
	"resolve_jackknife_unit",
	"jackknife_block_size_gt_one_unsupported",
	"mark_jackknife_nonestimable_if_block_unsupported"
)

exact_binomial_migrated_public_methods = c(
	"capabilities",
	"clone",
	"compute_asymp_confidence_interval",
	"compute_asymp_two_sided_pval",
	"compute_estimate",
	"compute_estimate_with_bootstrap_weights",
	"compute_exact_confidence_interval",
	"compute_exact_two_sided_pval_for_treatment_effect",
	"duplicate",
	"get_analysis_data",
	"get_covariates",
	"get_design_object",
	"get_model_formula",
	"get_nonestimable_reason",
	"get_nonestimable_stage",
	"get_optimization_alg",
	"get_response",
	"get_response_type",
	"get_treatment",
	"initialize",
	"is_nonestimable",
	"set_optimization_alg",
	"set_seed",
	"supports"
)

make_exact_binomial_legacy_generator = function() {
	with_edi_env = function(entries) {
		lapply(entries, function(entry) {
			if (is.function(entry)) environment(entry) = asNamespace("EDI")
			entry
		})
	}
	R6::R6Class(
		"InferenceIncidExactBinomialLegacy",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceJackknife,
		public = utils::modifyList(
			with_edi_env(EDI:::exact_test_public),
			c(
				with_edi_env(EDI:::ExactBinomialIncidenceSource$public),
				list(
					approximate_bootstrap_distribution_beta_hat_T = function(B = 501, show_progress = TRUE, debug = FALSE, bootstrap_type = NULL){
						super$approximate_bootstrap_distribution_beta_hat_T(B, show_progress, debug, bootstrap_type)
					}
				)
			)
		),
		private = utils::modifyList(
			with_edi_env(EDI:::exact_test_private),
			with_edi_env(EDI:::ExactBinomialIncidenceSource$private)
		)
	)
}

make_exact_fisher_legacy_generator = function() {
	with_edi_env = function(entries) {
		lapply(entries, function(entry) {
			if (is.function(entry)) environment(entry) = asNamespace("EDI")
			entry
		})
	}
	R6::R6Class(
		"InferenceIncidExactFisherLegacy",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceJackknife,
		public = utils::modifyList(
			with_edi_env(EDI:::exact_test_public),
			c(
				with_edi_env(EDI:::ExactFisherIncidenceSource$public),
				list(
					approximate_bootstrap_distribution_beta_hat_T = function(B = 501, show_progress = TRUE, debug = FALSE, bootstrap_type = NULL){
						super$approximate_bootstrap_distribution_beta_hat_T(B, show_progress, debug, bootstrap_type)
					}
				)
			)
		),
		private = utils::modifyList(
			with_edi_env(EDI:::exact_test_private),
			with_edi_env(EDI:::ExactFisherIncidenceSource$private)
		)
	)
}

make_exact_zhang_legacy_generator = function() {
	with_edi_env = function(entries) {
		lapply(entries, function(entry) {
			if (is.function(entry)) environment(entry) = asNamespace("EDI")
			entry
		})
	}
	R6::R6Class(
		"InferenceIncidExactZhangLegacy",
		lock_objects = FALSE,
		parent_env = asNamespace("EDI"),
		inherit = EDI:::InferenceJackknife,
		public = utils::modifyList(
			with_edi_env(EDI:::exact_test_public),
			with_edi_env(EDI:::ExactZhangIncidenceSource$public)
		),
		private = utils::modifyList(
			with_edi_env(EDI:::exact_test_private),
			with_edi_env(EDI:::ExactZhangIncidenceSource$private)
		)
	)
}

make_exact_binomial_migration_design = function() {
	x_dat = data.frame(
		x1 = c(-2.00, -2.01, -1.00, -1.01, 1.00, 1.01, 2.00, 2.01),
		x2 = c(0, 0, 1, 1, 0, 0, 1, 1)
	)
	des = DesignFixedBinaryMatch$new(n = nrow(x_dat), response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(x_dat)
	des$assign_w_to_all_subjects()
	des$.__enclos_env__$private$ensure_matching_structure_computed()
	m = as.integer(des$.__enclos_env__$private$m)
	w = des$get_w()
	y = integer(length(w))
	for (pair_id in sort(unique(m[m > 0L]))) {
		idx = which(m == pair_id)
		if (pair_id <= 3L) {
			y[idx[w[idx] == 1L]] = 1L
			y[idx[w[idx] == 0L]] = 0L
		} else {
			y[idx[w[idx] == 1L]] = 0L
			y[idx[w[idx] == 0L]] = 1L
		}
	}
	des$add_all_subject_responses(y)
	des
}

make_exact_fisher_migration_design = function() {
	set.seed(2026)
	n = 20L
	des = DesignSeqOneByOneiBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	}
	w = des$.__enclos_env__$private$w
	y = rbinom(n, 1, plogis(-0.3 + 0.7 * w))
	for (i in seq_along(y)) {
		des$add_one_subject_response(i, y[i])
	}
	des
}

make_exact_fisher_blocking_migration_design = function() {
	x_dat = data.frame(
		stratum = factor(rep(c("a", "b", "c", "d"), each = 4)),
		x1 = seq_len(16)
	)
	des = DesignFixedBlocking$new(
		n = nrow(x_dat),
		response_type = "incidence",
		strata_cols = "stratum",
		equal_block_sizes = TRUE,
		B_target = 4,
		verbose = FALSE
	)
	des$add_all_subjects_to_experiment(x_dat)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = as.integer(
		(x_dat$stratum %in% c("a", "c") & w == 1L) |
			(x_dat$stratum %in% c("b", "d") & w == 0L)
	)
	des$add_all_subject_responses(y)
	des
}

make_exact_zhang_migration_design = function() {
	set.seed(321)
	n = 24L
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	}
	treatment = des$.__enclos_env__$private$w
	prob = plogis(-0.2 + 0.8 * treatment)
	y = rbinom(n, 1, prob)
	for (i in seq_along(y)) {
		des$add_one_subject_response(i, y[i])
	}
	des
}

expect_exact_incidence_current_snapshot = function(class_name, extra_duplicate_private_owners = character()) {
	method_snapshot = inference_migration_method_snapshot(class_name)
	duplicate_private_owner_names = names(inference_migration_duplicate_private_owners(class_name))

	expect_identical(method_snapshot$public_methods, exact_incidence_baseline_public_methods)
	# setequal, not identical: the ancestor-chain walk order in
	# inference_migration_private_owners() is an insertion-order byproduct of
	# traversal, not a meaningful contract -- the invariant that matters is
	# which names are duplicated, not the order they're discovered in.
	expect_setequal(
		duplicate_private_owner_names,
		c(extra_duplicate_private_owners, exact_incidence_baseline_duplicate_private_owners)
	)
}

test_that("exact incidence migration baseline pins current golden outputs", {
	InferenceIncidExactBinomialLegacy = make_exact_binomial_legacy_generator()
	InferenceIncidExactFisherLegacy = make_exact_fisher_legacy_generator()
	InferenceIncidExactZhangLegacy = make_exact_zhang_legacy_generator()
	specs = list(
		InferenceIncidExactBinomial = list(
			generator = EDI:::InferenceIncidExactBinomial,
			legacy_generator = InferenceIncidExactBinomialLegacy,
			design = make_exact_binomial_migration_design(),
			alpha = 0.05,
			pval_epsilon = NULL,
			estimate = 0.847297860387204,
			pval = 0.625,
			ci = c(-1.42345544898852, 5.05937522382816)
		),
		InferenceIncidExactFisher = list(
			generator = EDI:::InferenceIncidExactFisher,
			legacy_generator = InferenceIncidExactFisherLegacy,
			design = make_exact_fisher_migration_design(),
			alpha = 0.10,
			pval_epsilon = NULL,
			estimate = 0.385034429779156,
			pval = 1,
			ci = c(-1.40296790485226, 2.22290783523223)
		),
		InferenceIncidExactZhang = list(
			generator = EDI:::InferenceIncidExactZhang,
			legacy_generator = InferenceIncidExactZhangLegacy,
			design = make_exact_zhang_migration_design(),
			alpha = 0.10,
			pval_epsilon = 0.01,
			estimate = 1.80191184069207,
			pval = 0.0648822319302868,
			ci = c(0.235551994035931, 3.55040655323846)
		)
	)

	for (class_name in names(specs)) {
		spec = specs[[class_name]]
		inf = spec$generator$new(spec$design, verbose = FALSE)
		ci = if (is.null(spec$pval_epsilon)) {
			inf$compute_exact_confidence_interval(alpha = spec$alpha)
		} else {
			inf$compute_exact_confidence_interval(alpha = spec$alpha, pval_epsilon = spec$pval_epsilon)
		}

		expect_equal(inf$compute_estimate(), spec$estimate, tolerance = 1e-12, info = class_name)
		expect_equal(
			inf$compute_exact_two_sided_pval_for_treatment_effect(delta = 0),
			spec$pval,
			tolerance = 1e-12,
			info = class_name
		)
		expect_equal(as.numeric(ci), spec$ci, tolerance = 1e-12, info = class_name)
		if (!is.null(spec$legacy_generator)) {
			exact_ci_args = list(alpha = spec$alpha)
			if (!is.null(spec$pval_epsilon)) {
				exact_ci_args$pval_epsilon = spec$pval_epsilon
			}
			expect_silent(expect_inference_migration_outputs_equal(
				legacy_class = spec$legacy_generator,
				migrated_class = spec$generator,
				design = spec$design,
				method_calls = list(
					estimate = inference_migration_method_calls$estimate,
					exact_ci = list(
						method = "compute_exact_confidence_interval",
						args = exact_ci_args
					),
					exact_pval = list(
						method = "compute_exact_two_sided_pval_for_treatment_effect",
						args = list(delta = 0)
					)
				),
				tolerance = 1e-12
			))
		}
	}
})

test_that("exact Zhang migration matches legacy outputs across supported fixtures", {
	skip_on_cran()
	InferenceIncidExactZhangLegacy = make_exact_zhang_legacy_generator()
	specs = list(
		Bernoulli = list(
			design = make_exact_zhang_migration_design(),
			alpha = 0.10,
			pval_epsilon = 0.01,
			estimate = 1.80191184069207,
			pval = 0.0648822319302868,
			ci = c(0.235551994035931, 3.55040655323846)
		),
		matching = list(
			design = make_exact_binomial_migration_design(),
			alpha = 0.10,
			pval_epsilon = 0.01,
			estimate = 0,
			pval = 0.625,
			ci = c(-0.79291957713222, 3.62477520974729)
		)
	)

	for (fixture_name in names(specs)) {
		spec = specs[[fixture_name]]
		inf = EDI:::InferenceIncidExactZhang$new(spec$design, verbose = FALSE)
		expect_equal(inf$compute_estimate(), spec$estimate, tolerance = 1e-12, info = fixture_name)
		expect_equal(
			inf$compute_exact_two_sided_pval_for_treatment_effect(delta = 0),
			spec$pval,
			tolerance = 1e-12,
			info = fixture_name
		)
		expect_equal(
			as.numeric(inf$compute_exact_confidence_interval(alpha = spec$alpha, pval_epsilon = spec$pval_epsilon)),
			spec$ci,
			tolerance = 1e-12,
			info = fixture_name
		)
		expect_silent(expect_inference_migration_outputs_equal(
			legacy_class = InferenceIncidExactZhangLegacy,
			migrated_class = EDI:::InferenceIncidExactZhang,
			design = spec$design,
			method_calls = list(
				estimate = inference_migration_method_calls$estimate,
				exact_ci = list(
					method = "compute_exact_confidence_interval",
					args = list(alpha = spec$alpha, pval_epsilon = spec$pval_epsilon)
				),
				exact_pval = list(
					method = "compute_exact_two_sided_pval_for_treatment_effect",
					args = list(delta = 0)
				)
			),
			tolerance = 1e-12
		))
	}
})

test_that("exact Fisher migration matches legacy outputs across supported fixtures", {
	skip_on_cran()
	InferenceIncidExactFisherLegacy = make_exact_fisher_legacy_generator()
	specs = list(
		iBCRD = list(
			design = make_exact_fisher_migration_design(),
			alpha = 0.10,
			estimate = 0.385034429779156,
			pval = 1,
			ci = c(-1.40296790485226, 2.22290783523223)
		),
		blocking = list(
			design = make_exact_fisher_blocking_migration_design(),
			alpha = 0.05,
			estimate = 0,
			pval = 1,
			ci = c(-2.04528646513743, 2.04528646513743)
		),
		matching = list(
			design = make_exact_binomial_migration_design(),
			alpha = 0.05,
			estimate = 1.09867332568708,
			pval = 0.625,
			ci = c(-1.42343022222885, 5.05857648377888)
		)
	)

	for (fixture_name in names(specs)) {
		spec = specs[[fixture_name]]
		inf = EDI:::InferenceIncidExactFisher$new(spec$design, verbose = FALSE)
		expect_equal(inf$compute_estimate(), spec$estimate, tolerance = 1e-12, info = fixture_name)
		expect_equal(
			inf$compute_exact_two_sided_pval_for_treatment_effect(delta = 0),
			spec$pval,
			tolerance = 1e-12,
			info = fixture_name
		)
		expect_equal(
			as.numeric(inf$compute_exact_confidence_interval(alpha = spec$alpha)),
			spec$ci,
			tolerance = 1e-12,
			info = fixture_name
		)
		expect_silent(expect_inference_migration_outputs_equal(
			legacy_class = InferenceIncidExactFisherLegacy,
			migrated_class = EDI:::InferenceIncidExactFisher,
			design = spec$design,
			method_calls = list(
				estimate = inference_migration_method_calls$estimate,
				exact_ci = list(
					method = "compute_exact_confidence_interval",
					args = list(alpha = spec$alpha)
				),
				exact_pval = list(
					method = "compute_exact_two_sided_pval_for_treatment_effect",
					args = list(delta = 0)
				)
			),
			tolerance = 1e-12
		))
	}
})

test_that("exact incidence migration baseline pins method and private-state snapshots", {
	InferenceIncidExactBinomialLegacy = make_exact_binomial_legacy_generator()
	InferenceIncidExactFisherLegacy = make_exact_fisher_legacy_generator()
	InferenceIncidExactZhangLegacy = make_exact_zhang_legacy_generator()
	expect_identical(
		inference_migration_public_methods(InferenceIncidExactBinomialLegacy),
		exact_incidence_baseline_public_methods
	)
	expect_setequal(
		names(inference_migration_duplicate_private_owners(InferenceIncidExactBinomialLegacy)),
		exact_incidence_baseline_duplicate_private_owners
	)
	expect_identical(
		inference_migration_public_methods("InferenceIncidExactBinomial"),
		exact_binomial_migrated_public_methods
	)
	expect_identical(
		names(inference_migration_duplicate_private_owners("InferenceIncidExactBinomial")),
		character()
	)
	expect_identical(
		EDI:::exact_incidence_behavior_manifest()$InferenceIncidExactBinomial$legacy_optional_surface,
		character()
	)
	expect_identical(
		inference_migration_public_methods(InferenceIncidExactFisherLegacy),
		exact_incidence_baseline_public_methods
	)
	expect_setequal(
		names(inference_migration_duplicate_private_owners(InferenceIncidExactFisherLegacy)),
		exact_incidence_baseline_duplicate_private_owners
	)
	expect_identical(
		inference_migration_public_methods("InferenceIncidExactFisher"),
		exact_binomial_migrated_public_methods
	)
	expect_identical(
		names(inference_migration_duplicate_private_owners("InferenceIncidExactFisher")),
		character()
	)
	expect_identical(
		EDI:::exact_incidence_behavior_manifest()$InferenceIncidExactFisher$legacy_optional_surface,
		character()
	)
	expect_identical(
		inference_migration_public_methods(InferenceIncidExactZhangLegacy),
		exact_incidence_baseline_public_methods
	)
	expect_setequal(
		names(inference_migration_duplicate_private_owners(InferenceIncidExactZhangLegacy)),
		c("supports_bayesian_bootstrap", exact_incidence_baseline_duplicate_private_owners)
	)
	expect_identical(
		inference_migration_public_methods("InferenceIncidExactZhang"),
		exact_binomial_migrated_public_methods
	)
	expect_identical(
		names(inference_migration_duplicate_private_owners("InferenceIncidExactZhang")),
		character()
	)
	expect_identical(
		EDI:::exact_incidence_behavior_manifest()$InferenceIncidExactZhang$legacy_optional_surface,
		character()
	)
})

test_that("exact binomial migration metadata marks the class migrated", {
	EDI:::populate_inference_class_registry()
	record = EDI:::get_inference_hierarchy_migration_record("InferenceIncidExactBinomial")

	expect_identical(EDI:::get_inference_class_metadata("InferenceIncidExactBinomial")$parent, "Inference")
	expect_identical(EDI:::get_effective_components("InferenceIncidExactBinomial"), c("ExactTest", "ExactBinomialIncidence"))
	expect_identical(EDI:::get_effective_capabilities("InferenceIncidExactBinomial"), c("exact_test", "exact_binomial_incidence"))
	expect_identical(record$migration_status, "migrated")
	expect_silent(EDI:::mark_inference_class_migrated(
		"InferenceIncidExactBinomial",
		public_method_names = EDI:::exact_incidence_behavior_manifest()$InferenceIncidExactBinomial$current_public_optional_methods
	))
})

test_that("exact Fisher migration metadata marks the class migrated", {
	EDI:::populate_inference_class_registry()
	record = EDI:::get_inference_hierarchy_migration_record("InferenceIncidExactFisher")

	expect_identical(EDI:::get_inference_class_metadata("InferenceIncidExactFisher")$parent, "Inference")
	expect_identical(EDI:::get_effective_components("InferenceIncidExactFisher"), c("ExactTest", "ExactFisherIncidence"))
	expect_identical(EDI:::get_effective_capabilities("InferenceIncidExactFisher"), c("exact_test", "exact_fisher_incidence"))
	expect_identical(record$migration_status, "migrated")
	expect_silent(EDI:::mark_inference_class_migrated(
		"InferenceIncidExactFisher",
		public_method_names = EDI:::exact_incidence_behavior_manifest()$InferenceIncidExactFisher$current_public_optional_methods
	))
})

test_that("exact Zhang migration metadata marks the class migrated", {
	EDI:::populate_inference_class_registry()
	record = EDI:::get_inference_hierarchy_migration_record("InferenceIncidExactZhang")

	expect_identical(EDI:::get_inference_class_metadata("InferenceIncidExactZhang")$parent, "Inference")
	expect_identical(EDI:::get_effective_components("InferenceIncidExactZhang"), c("ExactTest", "ExactZhangIncidence"))
	expect_identical(EDI:::get_effective_capabilities("InferenceIncidExactZhang"), c("exact_test", "exact_zhang_incidence"))
	expect_identical(record$migration_status, "migrated")
	expect_silent(EDI:::mark_inference_class_migrated(
		"InferenceIncidExactZhang",
		public_method_names = EDI:::exact_incidence_behavior_manifest()$InferenceIncidExactZhang$current_public_optional_methods
	))
})
