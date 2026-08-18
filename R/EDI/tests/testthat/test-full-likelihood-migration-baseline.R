library(testthat)
library(EDI)

full_likelihood_expected_classes = c(
	"InferenceContinKKGLMM",
	"InferenceContinKKOLSIVWC",
	"InferenceContinKKOLSOneLik",
	"InferenceContinKKQuantileRegrOneLik",
	"InferenceContinLin",
	"InferenceContinOLS",
	"InferenceCountHurdleNegBin",
	"InferenceCountHurdlePoisson",
	"InferenceCountKKCondPoissonOneLik",
	"InferenceCountKKGLMM",
	"InferenceCountKKHurdlePoissonIVWC",
	"InferenceCountKKHurdlePoissonOneLik",
	"InferenceCountNegBin",
	"InferenceCountPoisson",
	"InferenceCountZeroInflatedNegBin",
	"InferenceCountZeroInflatedPoisson",
	"InferenceIncidBinomialIdentityRiskDiff",
	"InferenceIncidKKModifiedPoisson",
	"InferenceIncidLogBinomial",
	"InferenceIncidLogRegr",
	"InferenceIncidModifiedPoisson",
	"InferenceIncidProbitRegr",
	"InferenceOrdinalAdjCatLogitRegr",
	"InferenceOrdinalCauchitRegr",
	"InferenceOrdinalCloglogRegr",
	"InferenceOrdinalContRatioRegr",
	"InferenceOrdinalKKCLMM",
	"InferenceOrdinalKKCLMMCauchit",
	"InferenceOrdinalKKCLMMCloglog",
	"InferenceOrdinalKKCLMMProbit",
	"InferenceOrdinalKKGLMM",
	"InferenceOrdinalOrderedProbitRegr",
	"InferenceOrdinalPropOddsRegr",
	"InferenceOrdinalStereotypeLogitRegr",
	"InferencePropBetaRegr",
	"InferencePropFractionalLogit",
	"InferencePropKKGLMM",
	"InferencePropKKQuantileRegrOneLik",
	"InferencePropZeroOneInflatedBetaRegr",
	"InferenceSurvivalDepCensTransformRegr",
	"InferenceSurvivalKKClaytonCopulaIVWC",
	"InferenceSurvivalKKClaytonCopulaOneLik",
	"InferenceSurvivalKKWeibullFrailtyIVWC",
	"InferenceSurvivalKKWeibullFrailtyOneLik",
	"InferenceSurvivalKKWeibullMarginal",
	"InferenceSurvivalWeibullRegr"
)

full_likelihood_expected_groups = list(
	glm = c(
		"InferenceContinKKGLMM",
		"InferenceContinKKOLSIVWC",
		"InferenceContinKKOLSOneLik",
		"InferenceContinKKQuantileRegrOneLik",
		"InferenceContinLin",
		"InferenceContinOLS"
	),
	count = c(
		"InferenceCountHurdleNegBin",
		"InferenceCountHurdlePoisson",
		"InferenceCountKKCondPoissonOneLik",
		"InferenceCountKKGLMM",
		"InferenceCountKKHurdlePoissonIVWC",
		"InferenceCountKKHurdlePoissonOneLik",
		"InferenceCountNegBin",
		"InferenceCountPoisson",
		"InferenceCountZeroInflatedNegBin",
		"InferenceCountZeroInflatedPoisson"
	),
	ordinal = c(
		"InferenceOrdinalAdjCatLogitRegr",
		"InferenceOrdinalCauchitRegr",
		"InferenceOrdinalCloglogRegr",
		"InferenceOrdinalContRatioRegr",
		"InferenceOrdinalKKCLMM",
		"InferenceOrdinalKKCLMMCauchit",
		"InferenceOrdinalKKCLMMCloglog",
		"InferenceOrdinalKKCLMMProbit",
		"InferenceOrdinalKKGLMM",
		"InferenceOrdinalOrderedProbitRegr",
		"InferenceOrdinalPropOddsRegr",
		"InferenceOrdinalStereotypeLogitRegr"
	),
	incidence = c(
		"InferenceIncidBinomialIdentityRiskDiff",
		"InferenceIncidKKModifiedPoisson",
		"InferenceIncidLogBinomial",
		"InferenceIncidLogRegr",
		"InferenceIncidModifiedPoisson",
		"InferenceIncidProbitRegr"
	),
	proportion = c(
		"InferencePropBetaRegr",
		"InferencePropFractionalLogit",
		"InferencePropKKGLMM",
		"InferencePropKKQuantileRegrOneLik",
		"InferencePropZeroOneInflatedBetaRegr"
	),
	survival = c(
		"InferenceSurvivalDepCensTransformRegr",
		"InferenceSurvivalKKClaytonCopulaIVWC",
		"InferenceSurvivalKKClaytonCopulaOneLik",
		"InferenceSurvivalKKWeibullFrailtyIVWC",
		"InferenceSurvivalKKWeibullFrailtyOneLik",
		"InferenceSurvivalKKWeibullMarginal",
		"InferenceSurvivalWeibullRegr"
	),
	kk_or_ivwc = c(
		"InferenceContinKKGLMM",
		"InferenceContinKKOLSIVWC",
		"InferenceContinKKOLSOneLik",
		"InferenceContinKKQuantileRegrOneLik",
		"InferenceCountKKCondPoissonOneLik",
		"InferenceCountKKGLMM",
		"InferenceCountKKHurdlePoissonIVWC",
		"InferenceCountKKHurdlePoissonOneLik",
		"InferenceIncidKKModifiedPoisson",
		"InferenceOrdinalKKCLMM",
		"InferenceOrdinalKKCLMMCauchit",
		"InferenceOrdinalKKCLMMCloglog",
		"InferenceOrdinalKKCLMMProbit",
		"InferenceOrdinalKKGLMM",
		"InferencePropKKGLMM",
		"InferencePropKKQuantileRegrOneLik",
		"InferenceSurvivalKKClaytonCopulaIVWC",
		"InferenceSurvivalKKClaytonCopulaOneLik",
		"InferenceSurvivalKKWeibullFrailtyIVWC",
		"InferenceSurvivalKKWeibullFrailtyOneLik",
		"InferenceSurvivalKKWeibullMarginal"
	),
	non_kk = c(
		"InferenceContinLin",
		"InferenceContinOLS",
		"InferenceCountHurdleNegBin",
		"InferenceCountHurdlePoisson",
		"InferenceCountNegBin",
		"InferenceCountPoisson",
		"InferenceCountZeroInflatedNegBin",
		"InferenceCountZeroInflatedPoisson",
		"InferenceIncidBinomialIdentityRiskDiff",
		"InferenceIncidLogBinomial",
		"InferenceIncidLogRegr",
		"InferenceIncidModifiedPoisson",
		"InferenceIncidProbitRegr",
		"InferenceOrdinalAdjCatLogitRegr",
		"InferenceOrdinalCauchitRegr",
		"InferenceOrdinalCloglogRegr",
		"InferenceOrdinalContRatioRegr",
		"InferenceOrdinalOrderedProbitRegr",
		"InferenceOrdinalPropOddsRegr",
		"InferenceOrdinalStereotypeLogitRegr",
		"InferencePropBetaRegr",
		"InferencePropFractionalLogit",
		"InferencePropZeroOneInflatedBetaRegr",
		"InferenceSurvivalDepCensTransformRegr",
		"InferenceSurvivalWeibullRegr"
	)
)

full_likelihood_expected_standard_model_cache_classes = c(
	"InferenceIncidBinomialIdentityRiskDiff",
	"InferenceIncidLogBinomial",
	"InferenceIncidLogRegr",
	"InferenceIncidModifiedPoisson",
	"InferenceIncidProbitRegr",
	"InferenceOrdinalAdjCatLogitRegr",
	"InferenceOrdinalCauchitRegr",
	"InferenceOrdinalCloglogRegr",
	"InferenceOrdinalContRatioRegr",
	"InferenceOrdinalOrderedProbitRegr",
	"InferenceOrdinalPropOddsRegr",
	"InferenceOrdinalStereotypeLogitRegr",
	"InferencePropBetaRegr",
	"InferencePropFractionalLogit",
	"InferencePropZeroOneInflatedBetaRegr",
	"InferenceSurvivalDepCensTransformRegr",
	"InferenceSurvivalWeibullRegr"
)

full_likelihood_expected_count_likelihood_classes = c(
	"InferenceCountHurdleNegBin",
	"InferenceCountHurdlePoisson",
	"InferenceCountNegBin",
	"InferenceCountPoisson",
	"InferenceCountZeroInflatedNegBin",
	"InferenceCountZeroInflatedPoisson"
)

full_likelihood_expected_zero_augmented_count_classes = c(
	"InferenceCountHurdlePoisson",
	"InferenceCountZeroInflatedNegBin",
	"InferenceCountZeroInflatedPoisson"
)

full_likelihood_expected_ordinal_components = list(
	InferenceOrdinalPropOddsRegr = "OrdinalProportionalOddsLikelihood",
	InferenceOrdinalAdjCatLogitRegr = "OrdinalAdjacentCategoryLikelihood",
	InferenceOrdinalCloglogRegr = "OrdinalCloglogLikelihood",
	InferenceOrdinalCauchitRegr = "OrdinalCauchitLikelihood",
	InferenceOrdinalStereotypeLogitRegr = "OrdinalStereotypeLikelihood",
	InferenceOrdinalContRatioRegr = "OrdinalContinuationRatioLikelihood",
	InferenceOrdinalOrderedProbitRegr = "OrdinalOrderedProbitLikelihood"
)

full_likelihood_expected_incidence_components = list(
	InferenceIncidLogRegr = "IncidenceLogisticLikelihood",
	InferenceIncidProbitRegr = "IncidenceProbitLikelihood",
	InferenceIncidLogBinomial = "IncidenceLogBinomialLikelihood",
	InferenceIncidModifiedPoisson = "IncidenceModifiedPoissonLikelihood",
	InferenceIncidBinomialIdentityRiskDiff = "IncidenceBinomialIdentityLikelihood"
)

# InferenceIncidGCompRiskDiff/RiskRatio are deliberately not listed here: once
# migrated to define_inference_class() (fix_inference_hierarchy.md, "Simple
# No-Likelihood Estimators"), they compose the shared IncidenceGComputation
# component directly plus a literal build_design_matrix/get_estimand_type pair
# in their own class bodies -- they are no longer sourced via a dedicated
# IncidenceGComputationRiskDiff/RiskRatio harvested component, so this
# pre-migration "component extraction" invariant no longer applies to them.
incidence_gcomputation_expected_components = list(
	InferenceIncidGCompAbstract = "IncidenceGComputation"
)

full_likelihood_expected_survival_components = list(
	# Moved here from the deleted survival_none_tier_expected_components table
	# (2026-08-17): InferenceSurvivalDepCensTransformRegr was misclassified
	# likelihood_tier "none" by infer_inference_likelihood_tier()'s name regex
	# despite implementing a full parametric likelihood (score/information/LR
	# spec, parametric bootstrap); the regex, the class's registry tier, and
	# the SurvivalDepCensTransform component's allowed_likelihood_tiers are
	# all "full" now -- see fix_inference_hierarchy.md, "Asymptotic (Wald)
	# No-Likelihood Migration", 2026-08-17 tier-fix note.
	InferenceSurvivalDepCensTransformRegr = "SurvivalDepCensTransform",
	InferenceSurvivalWeibullRegr = "SurvivalWeibullLikelihood",
	InferenceSurvivalKKWeibullMarginal = "SurvivalKKWeibullMarginal",
	InferenceSurvivalKKClaytonCopulaIVWC = "SurvivalKKClaytonCopulaIVWC",
	InferenceSurvivalKKClaytonCopulaOneLik = "SurvivalKKClaytonCopulaOneLik",
	# Merged to a single component at migration time (2026-08-18): the
	# separate self-harvested ...IVWCLeaf component was folded into the main
	# source, same reshaping as the Clayton IVWC entry above.
	InferenceSurvivalKKWeibullFrailtyIVWC = "SurvivalKKWeibullFrailtyIVWC",
	InferenceSurvivalKKWeibullFrailtyOneLik = c(
		"SurvivalKKWeibullFrailtyOneLik",
		"SurvivalKKWeibullFrailtyOneLikLeaf"
	)
)

test_that("full-likelihood migration baseline identifies and groups concrete classes", {
	EDI:::populate_inference_class_registry()
	manifest = EDI:::full_likelihood_behavior_manifest()
	groups = EDI:::full_likelihood_behavior_groups()
	counts = EDI:::full_likelihood_behavior_counts(manifest)

	expect_setequal(names(manifest), full_likelihood_expected_classes)
	expect_identical(EDI:::full_likelihood_concrete_class_names(), sort(full_likelihood_expected_classes))
	expect_identical(groups, lapply(full_likelihood_expected_groups, sort))
	expect_equal(sum(counts$class_count[counts$group %in% c("glm", "count", "ordinal", "incidence", "proportion", "survival")]), 46L)
	expect_equal(sum(counts$class_count[counts$group %in% c("KK_or_IVWC", "non_KK")]), 46L)

	for (record in manifest) {
		expect_identical(record$current_likelihood_tier, "full")
		expect_false(record$family == "other", info = record$name)
		expect_true(record$kk_status %in% c("KK_or_IVWC", "non_KK"))
		expect_identical(record$target_parent, "Inference")
		expect_identical(record$target_likelihood_tier, "full")
		expect_setequal(record$current_effective_components, EDI:::get_effective_components(record$name))
		expect_setequal(record$current_effective_capabilities, EDI:::get_effective_capabilities(record$name))
	}
})

full_likelihood_expected_migrated_classes = c(
	"InferenceOrdinalPropOddsRegr",
	"InferenceOrdinalAdjCatLogitRegr",
	"InferenceOrdinalCauchitRegr",
	"InferenceOrdinalCloglogRegr"
)

test_that("first full-likelihood class migrations remove algorithmic parents", {
	EDI:::populate_inference_component_registry()
	EDI:::populate_inference_class_registry()
	expected_family_components = c(
		InferenceOrdinalPropOddsRegr = "OrdinalProportionalOddsLikelihood",
		InferenceOrdinalAdjCatLogitRegr = "OrdinalAdjacentCategoryLikelihood",
		InferenceOrdinalCauchitRegr = "OrdinalCauchitLikelihood",
		InferenceOrdinalCloglogRegr = "OrdinalCloglogLikelihood"
	)

	for (class_name in full_likelihood_expected_migrated_classes) {
		record = EDI:::get_inference_hierarchy_migration_record(class_name)

		expect_identical(record$current_parent, "Inference", info = class_name)
		expect_identical(record$current_ancestors, "Inference", info = class_name)
		expect_identical(record$migration_status, "migrated", info = class_name)
		expect_identical(record$algorithmic_compatibility_ancestors, character(), info = class_name)
		expect_identical(
			EDI:::get_effective_components(class_name),
			c(
				"RandomizationTest",
				"RandomizationCI",
				"NonparametricBootstrap",
				"RandomizationBootstrap",
				# RandomizationBootstrapCI is a genuine addition to the base
				# resolved chain since this table was first written -- missing
				# here was a stale expectation, not a real regression (same
				# fix already applied to the dedicated Cauchit/Cloglog
				# goldens; PropOdds/AdjCatLogit are newly migrated as of
				# 2026-08-18 and start from the corrected chain).
				"RandomizationBootstrapCI",
				"BayesianBootstrap",
				"Jackknife",
				"Wald",
				"LikelihoodTests",
				"ParametricLikelihoodBootstrap",
				"StandardModelCache",
				expected_family_components[[class_name]]
			),
			info = class_name
		)
		expect_true("parametric_likelihood_bootstrap" %in% EDI:::get_effective_capabilities(class_name), info = class_name)
	}
})

test_that("full-likelihood survival behavior is component sourced", {
	EDI:::clear_inference_component_implementation_cache()
	EDI:::populate_inference_component_registry()
	EDI:::populate_inference_class_registry()
	manifest = EDI:::full_likelihood_behavior_manifest()

	for (class_name in names(full_likelihood_expected_survival_components)) {
		component_names = full_likelihood_expected_survival_components[[class_name]]
		record = manifest[[class_name]]
		expect_identical(record$family, "survival", info = class_name)
		expect_true(record$kk_status %in% c("KK_or_IVWC", "non_KK"), info = class_name)

		for (component_name in component_names) {
			component = EDI:::get_inference_component(component_name)
			loaded_component = EDI:::load_inference_component(component_name, class_name = paste0("test_", class_name))
			source = get(component$source_name, envir = asNamespace("EDI"))
			source_public_names = names(source$public) %||% character()
			source_private_names = names(source$private) %||% character()

			expect_identical(component$provides_capabilities, character(), info = component_name)
			expect_identical(component$component_loader$load_policy, "lazy", info = component_name)
			expect_identical(component$allowed_likelihood_tiers, "full", info = component_name)
			expect_identical(sort(component$provides_public_methods), sort(source_public_names), info = component_name)
			expect_identical(sort(component$provides_private_methods), sort(source_private_names), info = component_name)
			expect_identical(loaded_component$component_loader$load_policy, "eager", info = component_name)
			expect_identical(sort(names(loaded_component$public) %||% character()), sort(source_public_names), info = component_name)
			expect_identical(sort(names(loaded_component$private) %||% character()), sort(source_private_names), info = component_name)
			expect_true(component_name %in% record$current_effective_components, info = class_name)
		}
	}
})

test_that("full-likelihood incidence behavior is component sourced", {
	EDI:::clear_inference_component_implementation_cache()
	EDI:::populate_inference_component_registry()
	EDI:::populate_inference_class_registry()
	manifest = EDI:::full_likelihood_behavior_manifest()

	for (class_name in names(full_likelihood_expected_incidence_components)) {
		component_name = full_likelihood_expected_incidence_components[[class_name]]
		component = EDI:::get_inference_component(component_name)
		loaded_component = EDI:::load_inference_component(component_name, class_name = paste0("test_", class_name))
		source = get(component$source_name, envir = asNamespace("EDI"))
		record = manifest[[class_name]]

		expect_identical(component$dependencies, "StandardModelCache", info = component_name)
		expect_identical(component$provides_capabilities, character(), info = component_name)
		expect_identical(component$component_loader$load_policy, "lazy", info = component_name)
		expect_identical(sort(component$provides_public_methods), sort(names(source$public)), info = component_name)
		expect_identical(sort(component$provides_private_methods), sort(names(source$private)), info = component_name)
		expect_identical(loaded_component$component_loader$load_policy, "eager", info = component_name)
		expect_identical(sort(names(loaded_component$public)), sort(names(source$public)), info = component_name)
		expect_identical(sort(names(loaded_component$private)), sort(names(source$private)), info = component_name)

		expect_identical(record$family, "incidence", info = class_name)
		expect_identical(record$kk_status, "non_KK", info = class_name)
		expect_true("StandardModelCache" %in% record$current_effective_components, info = class_name)
		expect_true(component_name %in% record$current_effective_components, info = class_name)
		expect_true("standard_model_cache" %in% record$current_effective_capabilities, info = class_name)
	}
})

test_that("incidence g-computation behavior is component sourced", {
	EDI:::clear_inference_component_implementation_cache()
	EDI:::populate_inference_component_registry()
	EDI:::populate_inference_class_registry()

	for (class_name in names(incidence_gcomputation_expected_components)) {
		component_name = incidence_gcomputation_expected_components[[class_name]]
		component = EDI:::get_inference_component(component_name)
		loaded_component = EDI:::load_inference_component(component_name, class_name = paste0("test_", class_name))
		source = get(component$source_name, envir = asNamespace("EDI"))
		metadata = EDI:::get_inference_class_metadata(class_name)

		expect_identical(component$provides_capabilities, character(), info = component_name)
		expect_identical(component$component_loader$load_policy, "lazy", info = component_name)
		expect_identical(component$allowed_likelihood_tiers, "none", info = component_name)
		expect_identical(sort(component$provides_public_methods), sort(names(source$public)), info = component_name)
		expect_identical(sort(component$provides_private_methods), sort(names(source$private)), info = component_name)
		expect_identical(loaded_component$component_loader$load_policy, "eager", info = component_name)
		expect_identical(sort(names(loaded_component$public)), sort(names(source$public)), info = component_name)
		expect_identical(sort(names(loaded_component$private)), sort(names(source$private)), info = component_name)
		expect_identical(metadata$response_types, "incidence", info = class_name)
		expect_identical(metadata$likelihood_tier, "none", info = class_name)
		expect_true(component_name %in% EDI:::get_effective_components(class_name), info = class_name)
	}
})

test_that("full-likelihood ordinal behavior is component sourced", {
	EDI:::clear_inference_component_implementation_cache()
	EDI:::populate_inference_component_registry()
	EDI:::populate_inference_class_registry()
	manifest = EDI:::full_likelihood_behavior_manifest()

	for (class_name in names(full_likelihood_expected_ordinal_components)) {
		component_name = full_likelihood_expected_ordinal_components[[class_name]]
		component = EDI:::get_inference_component(component_name)
		loaded_component = EDI:::load_inference_component(component_name, class_name = paste0("test_", class_name))
		source = get(component$source_name, envir = asNamespace("EDI"))
		record = manifest[[class_name]]

		expect_identical(component$dependencies, "StandardModelCache", info = component_name)
		expect_identical(component$provides_capabilities, character(), info = component_name)
		expect_identical(component$component_loader$load_policy, "lazy", info = component_name)
		expect_identical(sort(component$provides_public_methods), sort(names(source$public)), info = component_name)
		expect_identical(sort(component$provides_private_methods), sort(names(source$private)), info = component_name)
		expect_identical(loaded_component$component_loader$load_policy, "eager", info = component_name)
		expect_identical(sort(names(loaded_component$public)), sort(names(source$public)), info = component_name)
		expect_identical(sort(names(loaded_component$private)), sort(names(source$private)), info = component_name)

		expect_identical(record$family, "ordinal", info = class_name)
		expect_identical(record$kk_status, "non_KK", info = class_name)
		expect_true("StandardModelCache" %in% record$current_effective_components, info = class_name)
		expect_true(component_name %in% record$current_effective_components, info = class_name)
		expect_true("standard_model_cache" %in% record$current_effective_capabilities, info = class_name)
	}
})

test_that("full-likelihood zero-augmented count behavior is component sourced", {
	EDI:::clear_inference_component_implementation_cache()
	EDI:::populate_inference_component_registry()
	EDI:::populate_inference_class_registry()
	component = EDI:::get_inference_component("ZeroAugmentedCountLikelihood")
	loaded_component = EDI:::load_inference_component("ZeroAugmentedCountLikelihood", class_name = "test_zero_augmented_count")
	manifest = EDI:::full_likelihood_behavior_manifest()
	zero_augmented_records = Filter(function(record) {
		"ZeroAugmentedCountLikelihood" %in% record$current_effective_components
	}, manifest)

	expect_identical(component$source_name, "ZeroAugmentedCountLikelihoodSource")
	expect_identical(component$file, "inference_count_zero_augmented_poisson_abstract.R")
	expect_identical(component$dependencies, "CountLikelihoodPlumbing")
	expect_identical(component$provides_capabilities, character())
	expect_identical(component$component_loader$load_policy, "lazy")
	expect_identical(sort(component$provides_public_methods), sort(names(EDI:::ZeroAugmentedCountLikelihoodSource$public)))
	expect_identical(sort(component$provides_private_methods), sort(names(EDI:::ZeroAugmentedCountLikelihoodSource$private)))
	expect_identical(loaded_component$component_loader$load_policy, "eager")
	expect_identical(sort(names(loaded_component$public)), sort(names(EDI:::ZeroAugmentedCountLikelihoodSource$public)))
	expect_identical(sort(names(loaded_component$private)), sort(names(EDI:::ZeroAugmentedCountLikelihoodSource$private)))

	expect_identical(
		sort(names(zero_augmented_records)),
		sort(full_likelihood_expected_zero_augmented_count_classes)
	)
	for (record in zero_augmented_records) {
		expect_identical(record$family, "count", info = record$name)
		expect_identical(record$kk_status, "non_KK", info = record$name)
		expect_true("CountLikelihoodPlumbing" %in% record$current_effective_components, info = record$name)
		expect_true("count_likelihood_plumbing" %in% record$current_effective_capabilities, info = record$name)
	}
})

test_that("full-likelihood count likelihood behavior is component sourced", {
	EDI:::clear_inference_component_implementation_cache()
	EDI:::populate_inference_component_registry()
	EDI:::populate_inference_class_registry()
	component = EDI:::get_inference_component("CountLikelihoodPlumbing")
	loaded_component = EDI:::load_inference_component("CountLikelihoodPlumbing", class_name = "test_count_likelihood")
	manifest = EDI:::full_likelihood_behavior_manifest()
	count_likelihood_records = Filter(function(record) {
		"count_likelihood_plumbing" %in% record$current_effective_capabilities
	}, manifest)

	expect_identical(component$source_name, "CountLikelihoodPlumbingSource")
	expect_identical(component$file, "inference_all_abstract_count_likelihood.R")
	expect_identical(component$dependencies, "LikelihoodTests")
	expect_identical(component$provides_capabilities, "count_likelihood_plumbing")
	expect_identical(component$component_loader$load_policy, "lazy")
	expect_identical(sort(component$provides_public_methods), sort(names(EDI:::CountLikelihoodPlumbingSource$public)))
	expect_identical(sort(component$provides_private_methods), sort(names(EDI:::CountLikelihoodPlumbingSource$private)))
	expect_identical(loaded_component$component_loader$load_policy, "eager")
	expect_identical(loaded_component$public, EDI:::CountLikelihoodPlumbingSource$public)
	expect_identical(loaded_component$private, EDI:::CountLikelihoodPlumbingSource$private)

	expect_identical(
		sort(names(count_likelihood_records)),
		sort(full_likelihood_expected_count_likelihood_classes)
	)
	for (record in count_likelihood_records) {
		expect_identical(record$family, "count", info = record$name)
		expect_identical(record$kk_status, "non_KK", info = record$name)
		expect_true("LikelihoodTests" %in% record$current_effective_components, info = record$name)
		expect_true("CountLikelihoodPlumbing" %in% record$current_effective_components, info = record$name)
	}
})

test_that("count composite likelihood behavior is component sourced", {
	EDI:::populate_inference_component_registry()
	component = EDI:::get_inference_component("CountCompositeLikelihood")

	expect_identical(component$source_name, "CountCompositeLikelihoodSource")
	expect_identical(component$file, "inference_count_composite_likelihood.R")
	expect_identical(component$dependencies, character())
	expect_identical(component$provides_capabilities, "count_composite_likelihood")
	expect_identical(component$component_loader$load_policy, "eager")
	expect_identical(component$public, EDI:::inference_count_composite_likelihood_public)
	expect_identical(component$private, EDI:::inference_count_composite_likelihood_private)
	expect_identical(sort(component$provides_public_methods), sort(names(EDI:::CountCompositeLikelihoodSource$public)))
	expect_identical(sort(component$provides_private_methods), sort(names(EDI:::CountCompositeLikelihoodSource$private)))
})

test_that("full-likelihood GLM-family standard-model-cache behavior is component sourced", {
	EDI:::populate_inference_component_registry()
	EDI:::populate_inference_class_registry()
	component = EDI:::get_inference_component("StandardModelCache")
	manifest = EDI:::full_likelihood_behavior_manifest()
	standard_model_cache_records = Filter(function(record) {
		"standard_model_cache" %in% record$current_effective_capabilities
	}, manifest)

	expect_identical(component$source_name, "StandardModelCacheSource")
	expect_identical(component$file, "inference_all_abstract_asymp_lik_std_mod_cache.R")
	expect_identical(component$dependencies, "LikelihoodTests")
	expect_identical(component$provides_capabilities, "standard_model_cache")
	expect_identical(component$component_loader$load_policy, "eager")
	expect_identical(component$public, EDI:::inference_asymp_lik_std_mod_cache_public)
	expect_identical(component$private, EDI:::inference_asymp_lik_std_mod_cache_private)
	expect_identical(sort(component$provides_public_methods), sort(names(EDI:::StandardModelCacheSource$public)))
	expect_identical(sort(component$provides_private_methods), sort(names(EDI:::StandardModelCacheSource$private)))

	expect_identical(
		sort(names(standard_model_cache_records)),
		sort(full_likelihood_expected_standard_model_cache_classes)
	)
	for (record in standard_model_cache_records) {
		expect_true(record$family %in% c("incidence", "ordinal", "proportion", "survival"), info = record$name)
		expect_identical(record$kk_status, "non_KK", info = record$name)
		expect_true("LikelihoodTests" %in% record$current_effective_components, info = record$name)
		expect_true("StandardModelCache" %in% record$current_effective_components, info = record$name)
	}
})
