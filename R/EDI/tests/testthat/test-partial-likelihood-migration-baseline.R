library(testthat)
library(EDI)

partial_likelihood_expected_classes = c(
	"InferenceIncidKKCondLogitGLMMIVWC",
	"InferenceIncidKKCondLogitGLMMOneLik",
	"InferenceIncidKKCondLogitIVWC",
	"InferenceIncidKKCondLogitOneLik",
	"InferenceOrdinalKKCondAdjCatLogitRegr",
	"InferenceSurvivalCoxPHRegr",
	"InferenceSurvivalKKLWACoxPHIVWC",
	"InferenceSurvivalKKLWACoxPHOneLik",
	"InferenceSurvivalKKStratCoxPHIVWC",
	"InferenceSurvivalKKStratCoxPHOneLik",
	"InferenceSurvivalStratCoxPHRegr"
)

partial_likelihood_expected_behaviors = list(
	conditional_logit = c(
		"InferenceIncidKKCondLogitGLMMIVWC",
		"InferenceIncidKKCondLogitGLMMOneLik",
		"InferenceIncidKKCondLogitIVWC",
		"InferenceIncidKKCondLogitOneLik",
		"InferenceOrdinalKKCondAdjCatLogitRegr"
	),
	cox = c(
		"InferenceSurvivalCoxPHRegr",
		"InferenceSurvivalKKLWACoxPHIVWC",
		"InferenceSurvivalKKLWACoxPHOneLik",
		"InferenceSurvivalKKStratCoxPHIVWC",
		"InferenceSurvivalKKStratCoxPHOneLik",
		"InferenceSurvivalStratCoxPHRegr"
	),
	glmm = c(
		"InferenceIncidKKCondLogitGLMMIVWC",
		"InferenceIncidKKCondLogitGLMMOneLik"
	),
	kk_compound = c(
		"InferenceIncidKKCondLogitGLMMIVWC",
		"InferenceIncidKKCondLogitIVWC",
		"InferenceSurvivalKKLWACoxPHIVWC",
		"InferenceSurvivalKKStratCoxPHIVWC"
	),
	kk_passthrough = c(
		"InferenceIncidKKCondLogitGLMMIVWC",
		"InferenceIncidKKCondLogitGLMMOneLik",
		"InferenceIncidKKCondLogitIVWC",
		"InferenceIncidKKCondLogitOneLik",
		"InferenceOrdinalKKCondAdjCatLogitRegr",
		"InferenceSurvivalKKLWACoxPHIVWC",
		"InferenceSurvivalKKLWACoxPHOneLik",
		"InferenceSurvivalKKStratCoxPHIVWC",
		"InferenceSurvivalKKStratCoxPHOneLik"
	),
	lwa_cox = c(
		"InferenceSurvivalKKLWACoxPHIVWC",
		"InferenceSurvivalKKLWACoxPHOneLik"
	),
	ordinal = "InferenceOrdinalKKCondAdjCatLogitRegr",
	standard_model_cache = c(
		"InferenceSurvivalCoxPHRegr",
		"InferenceSurvivalStratCoxPHRegr"
	),
	stratified_cox = c(
		"InferenceSurvivalKKStratCoxPHIVWC",
		"InferenceSurvivalKKStratCoxPHOneLik",
		"InferenceSurvivalStratCoxPHRegr"
	)
)

partial_likelihood_expected_component_families = list(
	ConditionalLogitPartialLikelihood = c(
		"InferenceIncidKKCondLogitGLMMIVWC",
		"InferenceIncidKKCondLogitGLMMOneLik",
		"InferenceIncidKKCondLogitIVWC",
		"InferenceIncidKKCondLogitOneLik",
		"InferenceOrdinalKKCondAdjCatLogitRegr"
	),
	CoxPartialLikelihood = c(
		"InferenceSurvivalCoxPHRegr",
		"InferenceSurvivalStratCoxPHRegr"
	),
	KKLWACoxPartialLikelihood = c(
		"InferenceSurvivalKKLWACoxPHIVWC",
		"InferenceSurvivalKKLWACoxPHOneLik"
	),
	KKStratifiedCoxPartialLikelihood = c(
		"InferenceSurvivalKKStratCoxPHIVWC",
		"InferenceSurvivalKKStratCoxPHOneLik"
	)
)

# Both Cox classes compose c("BayesianBootstrap", <cox component>) in their
# factory calls (BayesianBootstrap first, resolution-order load-bearing --
# see the factory-call comments): the bootstrap layer is NOT in the Cox
# components' dependency chains, and omitting it left the classes with NULL
# bootstrap-machinery privates (plain Cox: TODO-13; StratCox: found and fixed
# 2026-08-17, fix_inference_hierarchy.md Follow-Ups). The registry
# direct-components mappings were updated to match the factory reality in the
# same change, so these expectations carry the full resolved chain.
partial_likelihood_expected_extracted_cox_targets = list(
	InferenceSurvivalCoxPHRegr = list(
		target_direct_components = c("BayesianBootstrap", "CoxPartialLikelihood"),
		target_components = c(
			"RandomizationTest", "RandomizationCI", "NonparametricBootstrap",
			"RandomizationBootstrap", "RandomizationBootstrapCI", "BayesianBootstrap",
			"Jackknife", "Wald", "LikelihoodTests", "StandardModelCache",
			"CoxPartialLikelihood"
		)
	),
	InferenceSurvivalStratCoxPHRegr = list(
		target_direct_components = c("BayesianBootstrap", "StratifiedCoxPartialLikelihood"),
		target_components = c(
			"RandomizationTest", "RandomizationCI", "NonparametricBootstrap",
			"RandomizationBootstrap", "RandomizationBootstrapCI", "BayesianBootstrap",
			"Jackknife", "Wald", "LikelihoodTests", "StandardModelCache",
			"CoxPartialLikelihood", "StratifiedCoxPartialLikelihood"
		)
	)
)

partial_likelihood_expected_extracted_conditional_logit_targets = list(
	InferenceIncidKKCondLogitGLMMIVWC = list(
		target_direct_components = c("ConditionalLogitPartialLikelihood", "KKGLMM", "KKCompound"),
		target_components = c(
			"ConditionalLogitPartialLikelihood", "KKGLMM",
			"KKPassThrough", "KKCompound"
		)
	),
	InferenceIncidKKCondLogitGLMMOneLik = list(
		target_direct_components = c("ConditionalLogitPartialLikelihood", "KKGLMM"),
		target_components = c("ConditionalLogitPartialLikelihood", "KKGLMM")
	),
	InferenceIncidKKCondLogitIVWC = list(
		target_direct_components = c("ConditionalLogitPartialLikelihood", "KKCompound"),
		target_components = c("ConditionalLogitPartialLikelihood", "KKPassThrough", "KKCompound")
	),
	InferenceIncidKKCondLogitOneLik = list(
		target_direct_components = c("ConditionalLogitPartialLikelihood", "KKPassThrough"),
		target_components = c("ConditionalLogitPartialLikelihood", "KKPassThrough")
	),
	InferenceOrdinalKKCondAdjCatLogitRegr = list(
		target_direct_components = c("OrdinalConditionalLogitPartialLikelihood", "KKPassThrough"),
		target_components = c(
			"ConditionalLogitPartialLikelihood",
			"OrdinalConditionalLogitPartialLikelihood",
			"KKPassThrough"
		)
	)
)

partial_likelihood_expected_extracted_lwa_cox_targets = list(
	InferenceSurvivalKKLWACoxPHIVWC = list(
		target_direct_components = c("KKLWACoxIVWCPartialLikelihood", "KKCompound"),
		target_components = c(
			"Jackknife",
			"Wald",
			"KKLWACoxIVWCPartialLikelihood",
			"KKPassThrough",
			"KKCompound"
		)
	),
	InferenceSurvivalKKLWACoxPHOneLik = list(
		target_direct_components = c("KKLWACoxOneLikPartialLikelihood", "KKPassThrough"),
		target_components = c(
			"Jackknife",
			"Wald",
			"LikelihoodTests",
			"ParametricLikelihoodBootstrap",
			"KKLWACoxOneLikPartialLikelihood",
			"KKPassThrough"
		)
	)
)

test_that("partial-likelihood migration manifest records every current concrete class", {
	EDI:::populate_inference_class_registry()
	manifest = EDI:::partial_likelihood_behavior_manifest()

	expect_identical(names(manifest), partial_likelihood_expected_classes)
	expect_identical(
		EDI:::partial_likelihood_concrete_class_names(),
		sort(partial_likelihood_expected_classes)
	)
	for (class_name in names(manifest)) {
		record = manifest[[class_name]]
		expect_identical(record$name, class_name)
		expect_identical(record$current_likelihood_tier, "partial", info = class_name)
		expect_identical(record$target_likelihood_tier, "partial", info = class_name)
		expect_identical(record$target_parent, "Inference", info = class_name)
		expect_true(length(record$behavior) > 0L, info = class_name)
		expect_true(nzchar(record$estimator_family), info = class_name)
		expect_true(nzchar(record$component_family), info = class_name)
		expect_true(is.character(record$target_direct_components), info = class_name)
		expect_true(is.character(record$target_components), info = class_name)
		expect_true(nzchar(record$notes), info = class_name)
		expect_true(is.character(record$current_effective_components), info = class_name)
		expect_true(is.character(record$current_effective_capabilities), info = class_name)
	}
})

test_that("partial-likelihood migration groups classify estimator behavior explicitly", {
	EDI:::populate_inference_class_registry()

	expect_identical(
		EDI:::partial_likelihood_behavior_groups(),
		partial_likelihood_expected_behaviors
	)
	expect_identical(
		EDI:::partial_likelihood_component_family_groups(),
		partial_likelihood_expected_component_families
	)
	expect_identical(
		EDI:::partial_likelihood_behavior_counts(),
		structure(data.frame(
			behavior = names(partial_likelihood_expected_behaviors),
			class_count = vapply(partial_likelihood_expected_behaviors, length, integer(1L)),
			stringsAsFactors = FALSE
		), row.names = c(NA_integer_, -length(partial_likelihood_expected_behaviors)))
	)
})

test_that("Cox partial-likelihood components expose extracted helper contracts", {
	EDI:::populate_inference_component_registry()
	cox_component = EDI:::get_inference_component("CoxPartialLikelihood")
	strat_component = EDI:::get_inference_component("StratifiedCoxPartialLikelihood")

	expect_identical(cox_component$source_name, "CoxPartialLikelihoodSource")
	expect_identical(cox_component$component_loader$load_policy, "lazy")
	expect_identical(cox_component$dependencies, "StandardModelCache")
	expect_identical(EDI:::component_public_names(cox_component), character())
	expect_setequal(
		EDI:::component_private_names(cox_component),
		c(
			"fit_survival_coxph_kernel",
			"fit_survival_coxph_fixed_kernel",
			"cox_neg_loglik_breslow_r",
			"cox_score_breslow_fd_r",
			"cox_information_breslow_fd_r",
			"cox_partial_likelihood_coefficients_extreme"
		)
	)

	expect_identical(strat_component$source_name, "StratifiedCoxPartialLikelihoodSource")
	expect_identical(strat_component$component_loader$load_policy, "lazy")
	expect_identical(strat_component$dependencies, "CoxPartialLikelihood")
	expect_identical(EDI:::component_public_names(strat_component), character())
	expect_setequal(
		EDI:::component_private_names(strat_component),
		c(
			"cox_partial_likelihood_strata_info",
			"cox_partial_likelihood_reduce_covariates",
			"cox_partial_likelihood_informative_rows",
			"cox_partial_likelihood_fit_with_formula",
			"cox_partial_likelihood_fit_estimate_only_fast"
		)
	)
})

test_that("conditional-logit partial-likelihood components expose extracted helper contracts", {
	EDI:::populate_inference_component_registry()
	component = EDI:::get_inference_component("ConditionalLogitPartialLikelihood")
	ordinal_component = EDI:::get_inference_component("OrdinalConditionalLogitPartialLikelihood")

	expect_identical(component$source_name, "ConditionalLogitPartialLikelihoodSource")
	expect_identical(component$component_loader$load_policy, "lazy")
	expect_identical(component$dependencies, character())
	expect_identical(EDI:::component_public_names(component), character())
	expect_setequal(
		EDI:::component_private_names(component),
		c(
			"conditional_logit_prepare_combined_design",
			"conditional_logit_weighted_combined_estimate",
			"conditional_logit_neg_loglik",
			"conditional_logit_fit_matched_pairs",
			"conditional_logit_fit_reservoir"
		)
	)

	expect_identical(ordinal_component$source_name, "OrdinalConditionalLogitPartialLikelihoodSource")
	expect_identical(ordinal_component$component_loader$load_policy, "lazy")
	expect_identical(ordinal_component$dependencies, "ConditionalLogitPartialLikelihood")
	expect_identical(EDI:::component_public_names(ordinal_component), character())
	expect_setequal(
		EDI:::component_private_names(ordinal_component),
		c(
			"ordinal_cond_clogit_compute_setup",
			"ordinal_cond_clogit_assert_finite_se",
			"ordinal_cond_clogit_shared_univ",
			"ordinal_cond_clogit_shared_multi"
		)
	)
})

test_that("LWA Cox and survival rank-regression components expose extracted helper contracts", {
	EDI:::populate_inference_component_registry()
	ivwc_component = EDI:::get_inference_component("KKLWACoxIVWCPartialLikelihood")
	one_lik_component = EDI:::get_inference_component("KKLWACoxOneLikPartialLikelihood")
	rank_component = EDI:::get_inference_component("KKSurvivalRankRegression")

	expect_identical(ivwc_component$source_name, "KKLWACoxIVWCPartialLikelihoodSource")
	expect_identical(ivwc_component$component_loader$load_policy, "lazy")
	expect_identical(ivwc_component$dependencies, "Wald")
	expect_identical(EDI:::component_public_names(ivwc_component), character())
	expect_setequal(
		EDI:::component_private_names(ivwc_component),
		c(
			"kk_lwa_cox_ivwc_shared",
			"kk_lwa_cox_ivwc_assert_finite_se",
			"kk_lwa_cox_design_candidates",
			"kk_lwa_cox_fit_model",
			"kk_lwa_cox_for_matched_pairs",
			"kk_lwa_cox_for_reservoir"
		)
	)

	expect_identical(one_lik_component$source_name, "KKLWACoxOneLikPartialLikelihoodSource")
	expect_identical(one_lik_component$component_loader$load_policy, "lazy")
	expect_identical(one_lik_component$dependencies, "ParametricLikelihoodBootstrap")
	expect_identical(EDI:::component_public_names(one_lik_component), character())
	expect_setequal(
		EDI:::component_private_names(one_lik_component),
		c(
			"kk_lwa_cox_one_lik_get_standard_error",
			"kk_lwa_cox_one_lik_get_degrees_of_freedom",
			"kk_lwa_cox_one_lik_assert_finite_se",
			"kk_lwa_cox_one_lik_supports_likelihood_tests",
			"kk_lwa_cox_one_lik_supports_lik_ratio_param_bootstrap",
			"kk_lwa_cox_one_lik_simulate_under_lik_null",
			"kk_lwa_cox_one_lik_get_likelihood_test_spec",
			"kk_lwa_cox_one_lik_compute_treatment_estimate_during_randomization_inference",
			"kk_lwa_cox_one_lik_design_matrix_candidates",
			"kk_lwa_cox_one_lik_shared_combined_likelihood"
		)
	)

	expect_identical(rank_component$source_name, "KKSurvivalRankRegressionSource")
	expect_identical(rank_component$component_loader$load_policy, "lazy")
	expect_identical(rank_component$dependencies, "Wald")
	expect_identical(EDI:::component_public_names(rank_component), character())
	expect_setequal(
		EDI:::component_private_names(rank_component),
		c(
			"kk_survival_rank_design_candidates",
			"kk_survival_rank_extract_term_estimate",
			"kk_survival_rank_extract_term_se",
			"kk_survival_rank_shared",
			"kk_survival_rank_assert_finite_se",
			"kk_survival_rank_aftsrr_for_matched_pairs",
			"kk_survival_rank_aftsrr_for_reservoir"
		)
	)
})

test_that("Cox partial-likelihood component implementations load with matching contracts", {
	EDI:::populate_inference_component_registry()
	EDI:::clear_inference_component_implementation_cache()

	cox_component = EDI:::load_inference_component("CoxPartialLikelihood", class_name = "CoxPartialLikelihoodContractTest")
	strat_component = EDI:::load_inference_component("StratifiedCoxPartialLikelihood", class_name = "StratifiedCoxPartialLikelihoodContractTest")

	expect_identical(cox_component$component_loader$load_policy, "eager")
	expect_identical(strat_component$component_loader$load_policy, "eager")
	expect_setequal(names(cox_component$private), EDI:::get_inference_component("CoxPartialLikelihood")$provides_private_methods)
	expect_setequal(names(strat_component$private), EDI:::get_inference_component("StratifiedCoxPartialLikelihood")$provides_private_methods)
	expect_true("CoxPartialLikelihood" %in% EDI:::inference_component_load_trace("CoxPartialLikelihoodContractTest"))
	expect_true(all(c("CoxPartialLikelihood", "StratifiedCoxPartialLikelihood") %in% EDI:::inference_component_load_trace("StratifiedCoxPartialLikelihoodContractTest")))
})

test_that("conditional-logit component implementations load with matching contracts", {
	EDI:::populate_inference_component_registry()
	EDI:::clear_inference_component_implementation_cache()

	component = EDI:::load_inference_component("ConditionalLogitPartialLikelihood", class_name = "ConditionalLogitPartialLikelihoodContractTest")
	ordinal_component = EDI:::load_inference_component("OrdinalConditionalLogitPartialLikelihood", class_name = "OrdinalConditionalLogitPartialLikelihoodContractTest")

	expect_identical(component$component_loader$load_policy, "eager")
	expect_identical(ordinal_component$component_loader$load_policy, "eager")
	expect_setequal(names(component$private), EDI:::get_inference_component("ConditionalLogitPartialLikelihood")$provides_private_methods)
	expect_setequal(names(ordinal_component$private), EDI:::get_inference_component("OrdinalConditionalLogitPartialLikelihood")$provides_private_methods)
	expect_true("ConditionalLogitPartialLikelihood" %in% EDI:::inference_component_load_trace("ConditionalLogitPartialLikelihoodContractTest"))
	expect_true(all(c("ConditionalLogitPartialLikelihood", "OrdinalConditionalLogitPartialLikelihood") %in% EDI:::inference_component_load_trace("OrdinalConditionalLogitPartialLikelihoodContractTest")))
})

test_that("LWA Cox and survival rank-regression component implementations load with matching contracts", {
	EDI:::populate_inference_component_registry()
	EDI:::clear_inference_component_implementation_cache()

	ivwc_component = EDI:::load_inference_component("KKLWACoxIVWCPartialLikelihood", class_name = "KKLWACoxIVWCPartialLikelihoodContractTest")
	one_lik_component = EDI:::load_inference_component("KKLWACoxOneLikPartialLikelihood", class_name = "KKLWACoxOneLikPartialLikelihoodContractTest")
	rank_component = EDI:::load_inference_component("KKSurvivalRankRegression", class_name = "KKSurvivalRankRegressionContractTest")

	expect_identical(ivwc_component$component_loader$load_policy, "eager")
	expect_identical(one_lik_component$component_loader$load_policy, "eager")
	expect_identical(rank_component$component_loader$load_policy, "eager")
	expect_setequal(names(ivwc_component$private), EDI:::get_inference_component("KKLWACoxIVWCPartialLikelihood")$provides_private_methods)
	expect_setequal(names(one_lik_component$private), EDI:::get_inference_component("KKLWACoxOneLikPartialLikelihood")$provides_private_methods)
	expect_setequal(names(rank_component$private), EDI:::get_inference_component("KKSurvivalRankRegression")$provides_private_methods)
	expect_true(all(c("Wald", "KKLWACoxIVWCPartialLikelihood") %in% EDI:::inference_component_load_trace("KKLWACoxIVWCPartialLikelihoodContractTest")))
	expect_true(all(c("Wald", "LikelihoodTests", "ParametricLikelihoodBootstrap", "KKLWACoxOneLikPartialLikelihood") %in% EDI:::inference_component_load_trace("KKLWACoxOneLikPartialLikelihoodContractTest")))
	expect_true(all(c("Wald", "KKSurvivalRankRegression") %in% EDI:::inference_component_load_trace("KKSurvivalRankRegressionContractTest")))
})

test_that("partial-likelihood manifest records extracted Cox target component stacks", {
	EDI:::populate_inference_class_registry()
	manifest = EDI:::partial_likelihood_behavior_manifest()

	for (class_name in names(partial_likelihood_expected_extracted_cox_targets)) {
		expected = partial_likelihood_expected_extracted_cox_targets[[class_name]]
		expect_identical(manifest[[class_name]]$target_direct_components, expected$target_direct_components, info = class_name)
		expect_identical(manifest[[class_name]]$target_components, expected$target_components, info = class_name)
	}

	unextracted = setdiff(
		names(manifest),
		c(
			names(partial_likelihood_expected_extracted_cox_targets),
			names(partial_likelihood_expected_extracted_conditional_logit_targets),
			names(partial_likelihood_expected_extracted_lwa_cox_targets)
		)
	)
	for (class_name in unextracted) {
		expect_identical(manifest[[class_name]]$target_direct_components, character(), info = class_name)
		expect_identical(manifest[[class_name]]$target_components, character(), info = class_name)
	}
})

test_that("non-KK Cox partial-likelihood classes are migrated to root plus components", {
	EDI:::populate_inference_class_registry()
	migration_manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	partial_manifest = EDI:::partial_likelihood_behavior_manifest()
	param_bootstrap_public = c(
		"get_last_param_bootstrap_diagnostics",
		"compute_lik_ratio_bootstrap_two_sided_pval",
		"compute_lik_ratio_bootstrap_confidence_interval",
		"get_last_param_bootstrap_estimate_diagnostics",
		"compute_param_bootstrap_estimate",
		"compute_param_bootstrap_confidence_interval",
		"compute_param_bootstrap_pval"
	)

	for (class_name in names(partial_likelihood_expected_extracted_cox_targets)) {
		expected = partial_likelihood_expected_extracted_cox_targets[[class_name]]
		record = migration_manifest[[class_name]]
		class_metadata = EDI:::get_inference_class_metadata(class_name)
		public_methods = EDI:::inference_public_method_names(class_name)

		expect_identical(class_metadata$parent, "Inference", info = class_name)
		expect_identical(class_metadata$direct_components, expected$target_direct_components, info = class_name)
		expect_identical(record$current_parent, "Inference", info = class_name)
		expect_identical(record$algorithmic_compatibility_ancestors, character(), info = class_name)
		expect_identical(record$target_components, expected$target_components, info = class_name)
		expect_identical(record$migration_status, "migrated", info = class_name)
		expect_identical(partial_manifest[[class_name]]$target_components, expected$target_components, info = class_name)
		expect_true(all(c(
			"compute_estimate",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_lik_ratio_two_sided_pval"
		) %in% public_methods), info = class_name)
		expect_false(any(param_bootstrap_public %in% public_methods), info = class_name)
		expect_silent(EDI:::mark_inference_class_migrated(
			class_name,
			public_method_names = public_methods
		))
	}
})

test_that("partial-likelihood manifest records extracted conditional-logit target component stacks", {
	EDI:::populate_inference_class_registry()
	manifest = EDI:::partial_likelihood_behavior_manifest()

	for (class_name in names(partial_likelihood_expected_extracted_conditional_logit_targets)) {
		expected = partial_likelihood_expected_extracted_conditional_logit_targets[[class_name]]
		expect_identical(manifest[[class_name]]$target_direct_components, expected$target_direct_components, info = class_name)
		expect_identical(manifest[[class_name]]$target_components, expected$target_components, info = class_name)
	}
})

test_that("partial-likelihood manifest records extracted LWA Cox target component stacks", {
	EDI:::populate_inference_class_registry()
	manifest = EDI:::partial_likelihood_behavior_manifest()

	for (class_name in names(partial_likelihood_expected_extracted_lwa_cox_targets)) {
		expected = partial_likelihood_expected_extracted_lwa_cox_targets[[class_name]]
		expect_identical(manifest[[class_name]]$target_direct_components, expected$target_direct_components, info = class_name)
		expect_identical(manifest[[class_name]]$target_components, expected$target_components, info = class_name)
	}
})

test_that("KK pass-through and compound partial-likelihood target stacks validate before migration", {
	EDI:::populate_inference_component_registry()
	EDI:::populate_inference_class_registry()
	manifest = EDI:::partial_likelihood_behavior_manifest()
	kk_records = Filter(function(record) {
		any(record$target_components %in% c("KKPassThrough", "KKCompound"))
	}, manifest)

	expect_true(length(kk_records) > 0L)
	for (record in kk_records) {
		resolved = EDI:::resolve_component_dependencies(record$target_direct_components)
		expect_identical(resolved, record$target_components, info = record$name)
		expect_identical(anyDuplicated(resolved), 0L, info = record$name)
		expect_true("KKPassThrough" %in% resolved, info = record$name)
		if ("KKCompound" %in% record$target_components) {
			expect_true("KKCompound" %in% resolved, info = record$name)
			expect_true(match("KKPassThrough", resolved) < match("KKCompound", resolved), info = record$name)
		}
		expect_equal(
			intersect(
				record$target_direct_components,
				unlist(lapply(record$target_direct_components, function(component_name) {
					EDI:::get_inference_component(component_name)$dependencies
				}), use.names = FALSE)
			),
			character(),
			info = record$name
		)
	}
})

test_that("KK pass-through and compound component implementations load with matching contracts", {
	EDI:::populate_inference_component_registry()
	EDI:::clear_inference_component_implementation_cache()

	pass_component = EDI:::load_inference_component(
		"KKPassThrough",
		class_name = "KKPassThroughContractTest"
	)
	compound_component = EDI:::load_inference_component(
		"KKCompound",
		class_name = "KKCompoundContractTest"
	)

	expect_identical(pass_component$component_loader$load_policy, "eager")
	expect_identical(compound_component$component_loader$load_policy, "eager")
	expect_setequal(
		names(pass_component$public),
		EDI:::get_inference_component("KKPassThrough")$provides_public_methods
	)
	expect_setequal(
		names(pass_component$private),
		EDI:::get_inference_component("KKPassThrough")$provides_private_methods
	)
	expect_setequal(
		names(compound_component$private),
		EDI:::get_inference_component("KKCompound")$provides_private_methods
	)
	expect_identical(
		EDI:::inference_component_load_trace("KKCompoundContractTest"),
		c("KKPassThrough", "KKCompound")
	)
})

test_that("extracted stratified-Cox helpers preserve current private-method behavior", {
	des = DesignSeqOneByOneBernoulli$new(n = 12, response_type = "survival", verbose = FALSE)
	for (i in seq_len(12)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(
			block = rep(c(0, 1), length.out = 12)[i],
			x = i / 12
		))
	}
	y = c(2.0, 1.5, 3.1, 2.7, 4.2, 3.5, 5.1, 4.4, 6.0, 5.5, 7.2, 6.3)
	dead = c(1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0)
	des$add_all_subject_responses(
		ys = ifelse(dead == 1, y, NA_real_),
		y_Ls = ifelse(dead == 0, y, NA_real_),
		y_Rs = ifelse(dead == 0, Inf, NA_real_)
	)

	inf = InferenceSurvivalStratCoxPHRegr$new(des, verbose = FALSE)
	private = inf$.__enclos_env__$private
	X_full = private$get_X()
	strata_info = private$compute_strata_info(X_full)

	expect_identical(strata_info, EDI:::cox_partial_likelihood_strata_info(X_full, length(private$y)))
	expect_identical(
		private$reduce_covariates_preserving_treatment(X_full),
		EDI:::cox_partial_likelihood_reduce_covariates(private$w, private$y, X_full)
	)
	expect_identical(
		private$get_informative_rows(strata_info$strata_id),
		EDI:::cox_partial_likelihood_informative_rows(strata_info$strata_id, private$y, private$dead, private$w)
	)
})

test_that("partial-likelihood parametric bootstrap surface requires a null simulator", {
	EDI:::populate_inference_class_registry()
	manifest = EDI:::partial_likelihood_behavior_manifest()

	expect_equal(nrow(EDI:::partial_likelihood_parametric_bootstrap_violations(manifest)), 0L)
	for (record in manifest) {
		if (isTRUE(record$provides_parametric_likelihood_bootstrap) ||
				isTRUE(record$target_provides_parametric_likelihood_bootstrap)) {
			expect_true(record$has_null_simulator, info = record$name)
		}
	}
})
