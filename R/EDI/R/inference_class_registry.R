#' Inference Class Metadata Registry
#'
#' The registry is the source of truth for structural metadata used by the
#' future shallow inference hierarchy. It is intentionally separated from R6
#' generator environments so metadata can be validated without instantiating
#' inference classes.
#'
#' @keywords internal
#' @noRd
EDI_INFERENCE_CLASS_REGISTRY = new.env(parent = emptyenv())
EDI_INFERENCE_EFFECTIVE_COMPONENTS_CACHE = new.env(parent = emptyenv())
EDI_INFERENCE_EFFECTIVE_CAPABILITIES_CACHE = new.env(parent = emptyenv())

EDI_INFERENCE_ALLOWED_LIKELIHOOD_TIERS = c("none", "quasi", "partial", "full")

# Transitional corrections for legacy deep-inheritance classes whose parent
# ladder supplies ParametricLikelihoodBootstrap even though the concrete class
# explicitly disables that operation. Remove each entry when the class is
# migrated to shallow component composition and no longer inherits the
# capability accidentally.
EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES = list(
	InferenceIncidKKCondLogitGLMMIVWC = "parametric_likelihood_bootstrap",
	InferenceIncidKKCondLogitGLMMOneLik = "parametric_likelihood_bootstrap",
	InferenceIncidKKGCompRiskDiff = "parametric_likelihood_bootstrap",
	InferenceIncidKKGCompRiskRatio = "parametric_likelihood_bootstrap",
	InferenceIncidModifiedPoisson = "parametric_likelihood_bootstrap"
)

EDI_EXACT_INCIDENCE_CLASS_NAMES = c(
	"InferenceIncidExactBinomial",
	"InferenceIncidExactFisher",
	"InferenceIncidenceExactZhang"
)

EDI_EXACT_INCIDENCE_TARGETS = list(
	InferenceIncidExactBinomial = list(
		intentional_capabilities = "exact_test",
		target_components = c("ExactTest", "ExactBinomialIncidence"),
		notes = "Matched-pair exact binomial inference should retain exact APIs only; inherited bootstrap, randomization, Bayesian-bootstrap, and jackknife APIs are treated as legacy surface."
	),
	InferenceIncidExactFisher = list(
		intentional_capabilities = "exact_test",
		target_components = c("ExactTest", "ExactFisherIncidence"),
		notes = "Fisher/mantelhaen exact incidence inference should retain exact APIs only; inherited bootstrap, randomization, Bayesian-bootstrap, and jackknife APIs are treated as legacy surface."
	),
	InferenceIncidenceExactZhang = list(
		intentional_capabilities = "exact_test",
		target_components = c("ExactTest", "ExactZhangIncidence"),
		notes = "Zhang exact incidence inference should retain exact APIs only; generic resampling-weight methods are legacy surface and are not valid exact Zhang capabilities."
	)
)

EDI_NO_LIKELIHOOD_SPECIAL_CLASSIFICATIONS = list(
	InferenceIncidCMH = list(
		classification = "wald_blocked_incidence",
		exact_test_component = FALSE,
		notes = "CMH is a blocked-incidence Wald/asymptotic class with randomization-based standard-error computation, not an exact-test class."
	)
)

EDI_CUSTOM_RANDOMIZATION_TARGETS = list(
	InferenceCustomRand = list(
		host_kind = "extension_base",
		target_parent = "Inference",
		target_components = "RandomizationTest",
		class_owned_capabilities = character(),
		intentional_capabilities = "randomization_test",
		migration_status = "migrated",
		migration_evidence = c("method_snapshot", "golden_randomization"),
		notes = "Custom randomization extension hosts should inherit only the root Inference state and add RandomizationTest explicitly; randomization CI and bootstrap APIs are accidental unless their components are listed."
	)
)

EDI_SIMPLE_ESTIMATOR_CLASS_NAMES = c(
	"InferenceAllSimpleMeanDiff",
	"InferenceAllSimpleMeanDiffPooledVar",
	"InferenceAllKKMeanDiffIVWC",
	"InferenceAllSimpleWilcox",
	"InferenceAllKKWilcoxIVWC"
)

EDI_NO_LIKELIHOOD_MIGRATION_REQUIRED_EVIDENCE = c(
	"before_after_manifest_counts",
	"kept_dropped_optional_methods",
	"mark_inference_class_migrated",
	"golden_outputs",
	"method_availability_snapshot",
	"private_state_owner_snapshot"
)

EDI_SIMPLE_ESTIMATOR_TARGETS = list(
	InferenceAllSimpleMeanDiff = list(
		family = "simple_mean_difference",
		target_components = c(
			"RandomizationTest", "RandomizationCI", "NonparametricBootstrap",
			"RandomizationBootstrap", "RandomizationBootstrapCI",
			"BayesianBootstrap", "Jackknife", "Wald"
		),
		intentional_capabilities = c(
			"randomization_test", "randomization_ci", "nonparametric_bootstrap",
			"randomization_bootstrap", "bayesian_bootstrap", "jackknife", "wald"
		),
		notes = "Closed-form mean-difference estimator keeps randomization, randomization-CI, nonparametric bootstrap, randomization-bootstrap, Bayesian-bootstrap, jackknife, and Wald APIs; likelihood-test and parametric-likelihood-bootstrap APIs are legacy surface."
	),
	InferenceAllSimpleMeanDiffPooledVar = list(
		family = "simple_mean_difference",
		target_components = c(
			"RandomizationTest", "RandomizationCI", "NonparametricBootstrap",
			"RandomizationBootstrap", "RandomizationBootstrapCI",
			"BayesianBootstrap", "Jackknife", "Wald"
		),
		intentional_capabilities = c(
			"randomization_test", "randomization_ci", "nonparametric_bootstrap",
			"randomization_bootstrap", "bayesian_bootstrap", "jackknife", "wald"
		),
		notes = "Pooled-variance mean-difference estimator keeps the same no-likelihood resampling/Wald APIs as the base simple mean-difference estimator; likelihood-test and parametric-likelihood-bootstrap APIs are legacy surface."
	),
	InferenceAllKKMeanDiffIVWC = list(
		family = "simple_mean_difference",
		target_components = c(
			"RandomizationTest", "RandomizationCI", "NonparametricBootstrap",
			"RandomizationBootstrap", "RandomizationBootstrapCI",
			"BayesianBootstrap", "Jackknife", "Wald",
			"KKPassThrough", "KKCompound"
		),
		intentional_capabilities = c(
			"randomization_test", "randomization_ci", "nonparametric_bootstrap",
			"randomization_bootstrap", "bayesian_bootstrap", "jackknife", "wald",
			"kk_passthrough", "kk_compound"
		),
		notes = "KK IVWC mean-difference estimator keeps no-likelihood resampling/Wald APIs plus KK pass-through and compound behavior; likelihood-test APIs are legacy surface."
	),
	InferenceAllSimpleWilcox = list(
		family = "wilcoxon_rank",
		target_components = c(
			"RandomizationTest", "RandomizationCI", "NonparametricBootstrap",
			"RandomizationBootstrap", "RandomizationBootstrapCI", "Jackknife", "Wald"
		),
		intentional_capabilities = c(
			"randomization_test", "randomization_ci", "nonparametric_bootstrap",
			"randomization_bootstrap", "jackknife", "wald"
		),
		notes = "Simple Wilcoxon/Hodges-Lehmann estimator keeps randomization, randomization-CI, nonparametric bootstrap, randomization-bootstrap, jackknife stubs, and Wald/asymptotic rank APIs; Bayesian-bootstrap, likelihood-test, and parametric-likelihood-bootstrap APIs are legacy surface."
	),
	InferenceAllKKWilcoxIVWC = list(
		family = "wilcoxon_rank",
		target_components = c(
			"RandomizationTest", "RandomizationCI", "NonparametricBootstrap",
			"RandomizationBootstrap", "RandomizationBootstrapCI", "Jackknife", "Wald",
			"KKWilcoxIVWC"
		),
		intentional_capabilities = c(
			"randomization_test", "randomization_ci", "nonparametric_bootstrap",
			"randomization_bootstrap", "jackknife", "wald", "kk_passthrough", "kk_compound"
		),
		notes = "KK Wilcoxon IVWC estimator keeps rank randomization/resampling APIs plus KK pass-through and compound behavior; Bayesian-bootstrap and likelihood-test APIs are legacy surface."
	)
)

EDI_SIMPLE_ESTIMATOR_TARGETS = lapply(EDI_SIMPLE_ESTIMATOR_TARGETS, function(target) {
	if (is.null(target$migration_status)) {
		target$migration_status = "migrated"
	}
	if (is.null(target$migration_evidence)) {
		target$migration_evidence = EDI_NO_LIKELIHOOD_MIGRATION_REQUIRED_EVIDENCE
	}
	target
})

EDI_QUASI_ROBUST_CLASS_NAMES = c(
	"InferenceContinRobustRegr",
	"InferenceContinKKRobustRegrIVWC",
	"InferenceContinKKRobustRegrOneLik",
	"InferenceCountPoissonKKGEE",
	"InferenceCountQuasiPoisson",
	"InferenceCountRobustPoisson",
	"InferenceIncidKKGEE",
	"InferenceOrdinalKKGEE",
	"InferencePropKKGEE"
)

	EDI_QUASI_ROBUST_TARGETS = list(
	InferenceContinRobustRegr = list(
		behavior = "m_estimator_variance",
		estimator_family = "continuous_robust_regression",
		notes = "Huber/Tukey M-estimator continuous regression path using its model-based asymptotic variance; no sandwich component or normalized likelihood-ratio surface should be implied by the quasi tier."
	),
	InferenceContinKKRobustRegrIVWC = list(
		behavior = c("robust_sandwich", "kk_passthrough", "kk_compound"),
		estimator_family = "continuous_kk_robust_regression_ivwc",
		notes = "KK IVWC robust-regression estimator; keep KK pass-through/compound behavior separate from robust/sandwich estimator logic."
	),
	InferenceContinKKRobustRegrOneLik = list(
		behavior = c("robust_sandwich", "kk_passthrough", "kk_compound"),
		estimator_family = "continuous_kk_robust_regression_one_likelihood",
		notes = "KK one-likelihood robust-regression estimator; its robust/sandwich behavior must not be treated as normalized likelihood-ratio support."
	),
	InferenceCountPoissonKKGEE = list(
		behavior = c("gee", "kk_gee"),
		estimator_family = "count_poisson_kk_gee",
		notes = "KK GEE count estimator backed by InferenceMixinKKGEEShared; migrate after KKGEE host requirements are complete."
	),
	InferenceCountQuasiPoisson = list(
		behavior = c("quasi_likelihood", "composite_likelihood"),
		estimator_family = "count_quasipoisson",
		composite_likelihood_tests_component = FALSE,
		composite_likelihood_public_methods = character(),
		notes = "Count quasi-Poisson uses quasi-likelihood estimating equations while currently inheriting CountCompositeLikelihood plumbing."
	),
	InferenceCountRobustPoisson = list(
		behavior = c("robust_sandwich", "composite_likelihood"),
		estimator_family = "count_robust_poisson",
		composite_likelihood_tests_component = FALSE,
		composite_likelihood_public_methods = character(),
		notes = "Modified/robust Poisson uses sandwich variance while currently inheriting CountCompositeLikelihood plumbing."
	),
	InferenceIncidKKGEE = list(
		behavior = c("gee", "kk_gee"),
		estimator_family = "incidence_kk_gee",
		notes = "Incidence KK GEE estimator backed by InferenceMixinKKGEEShared."
	),
	InferenceOrdinalKKGEE = list(
		behavior = c("gee", "kk_gee"),
		estimator_family = "ordinal_kk_gee",
		notes = "Ordinal KK GEE estimator backed by InferenceMixinKKGEEShared."
	),
	InferencePropKKGEE = list(
		behavior = c("gee", "kk_gee"),
		estimator_family = "proportion_kk_gee",
		notes = "Proportion KK GEE estimator backed by InferenceMixinKKGEEShared."
		)
	)

	EDI_PARTIAL_LIKELIHOOD_CLASS_NAMES = c(
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

	EDI_PARTIAL_LIKELIHOOD_TARGETS = list(
		InferenceIncidKKCondLogitGLMMIVWC = list(
			behavior = c("conditional_logit", "glmm", "kk_compound", "kk_passthrough"),
			estimator_family = "incidence_kk_conditional_logit_glmm_ivwc",
			component_family = "ConditionalLogitPartialLikelihood",
			target_direct_components = c("ConditionalLogitPartialLikelihood", "KKGLMM", "KKCompound"),
			notes = "KK incidence conditional-logit GLMM IVWC estimator; migrate only after conditional-logit and KK compound/pass-through host contracts are explicit."
		),
		InferenceIncidKKCondLogitGLMMOneLik = list(
			behavior = c("conditional_logit", "glmm", "kk_passthrough"),
			estimator_family = "incidence_kk_conditional_logit_glmm_one_likelihood",
			component_family = "ConditionalLogitPartialLikelihood",
			target_direct_components = c("ConditionalLogitPartialLikelihood", "KKGLMM"),
			notes = "KK incidence conditional-logit GLMM one-likelihood estimator; keep conditional-logit plumbing separate from GLMM package/runtime requirements."
		),
		InferenceIncidKKCondLogitIVWC = list(
			behavior = c("conditional_logit", "kk_compound", "kk_passthrough"),
			estimator_family = "incidence_kk_conditional_logit_ivwc",
			component_family = "ConditionalLogitPartialLikelihood",
			target_direct_components = c("ConditionalLogitPartialLikelihood", "KKCompound"),
			notes = "KK incidence conditional-logit IVWC estimator; depends on KK pass-through/compound behavior plus conditional-logit fit helpers."
		),
		InferenceIncidKKCondLogitOneLik = list(
			behavior = c("conditional_logit", "kk_passthrough"),
			estimator_family = "incidence_kk_conditional_logit_one_likelihood",
			component_family = "ConditionalLogitPartialLikelihood",
			target_direct_components = c("ConditionalLogitPartialLikelihood", "KKPassThrough"),
			notes = "KK incidence conditional-logit one-likelihood estimator; migrate after conditional-logit null-fit and likelihood-test contracts are declared."
		),
		InferenceOrdinalKKCondAdjCatLogitRegr = list(
			behavior = c("conditional_logit", "ordinal", "kk_passthrough"),
			estimator_family = "ordinal_kk_conditional_adjacent_category_logit",
			component_family = "ConditionalLogitPartialLikelihood",
			target_direct_components = c("OrdinalConditionalLogitPartialLikelihood", "KKPassThrough"),
			notes = "Ordinal KK conditional adjacent-category logit estimator; shares conditional-logit-style matched-set likelihood behavior with incidence paths."
		),
		InferenceSurvivalCoxPHRegr = list(
			behavior = c("cox", "standard_model_cache"),
			estimator_family = "survival_cox_ph",
			component_family = "CoxPartialLikelihood",
			# BayesianBootstrap is a real direct component: the factory composes
			# c("BayesianBootstrap", "CoxPartialLikelihood") because the bootstrap
			# layer is not in the Cox chain (TODO-13; StratCox twin fixed 2026-08-17).
			target_direct_components = c("BayesianBootstrap", "CoxPartialLikelihood"),
			notes = "Non-KK Cox proportional-hazards estimator currently inherits standard-model-cache likelihood behavior."
		),
		InferenceSurvivalStratCoxPHRegr = list(
			behavior = c("cox", "stratified_cox", "standard_model_cache"),
			estimator_family = "survival_stratified_cox_ph",
			component_family = "CoxPartialLikelihood",
			target_direct_components = c("BayesianBootstrap", "StratifiedCoxPartialLikelihood"),
			notes = "Non-KK stratified Cox PH estimator should share the Cox partial-likelihood component family while preserving stratification-specific caches."
		),
		InferenceSurvivalKKLWACoxPHIVWC = list(
			behavior = c("cox", "lwa_cox", "kk_compound", "kk_passthrough"),
			estimator_family = "survival_kk_lwa_cox_ivwc",
			component_family = "KKLWACoxPartialLikelihood",
			target_direct_components = c("KKLWACoxIVWCPartialLikelihood", "KKCompound"),
			notes = "KK LWA Cox IVWC estimator combines matched cluster-robust Cox and reservoir Cox components."
		),
		InferenceSurvivalKKLWACoxPHOneLik = list(
			behavior = c("cox", "lwa_cox", "kk_passthrough"),
			estimator_family = "survival_kk_lwa_cox_one_likelihood",
			component_family = "KKLWACoxPartialLikelihood",
			target_direct_components = c("KKLWACoxOneLikPartialLikelihood", "KKPassThrough"),
			notes = "KK LWA Cox one-likelihood estimator uses a combined marginal Cox partial likelihood with cluster-robust variance."
		),
		InferenceSurvivalKKStratCoxPHIVWC = list(
			behavior = c("cox", "stratified_cox", "kk_compound", "kk_passthrough"),
			estimator_family = "survival_kk_stratified_cox_ivwc",
			component_family = "KKStratifiedCoxPartialLikelihood",
			notes = "KK stratified Cox IVWC estimator needs KK compound/pass-through contracts before migration."
		),
		InferenceSurvivalKKStratCoxPHOneLik = list(
			behavior = c("cox", "stratified_cox", "kk_passthrough"),
			estimator_family = "survival_kk_stratified_cox_one_likelihood",
			component_family = "KKStratifiedCoxPartialLikelihood",
			notes = "KK stratified Cox one-likelihood estimator combines matched sets and reservoir subjects in one stratified Cox partial likelihood."
		)
	)

	EDI_INFERENCE_ALGORITHM_COMPATIBILITY_BASES = c(
	"InferenceAsymp",
	"InferenceJackknife",
	"InferenceNonParamBootstrap",
	"InferenceBayesianBootstrap",
	"InferenceRand",
	"InferenceRandCI",
	"InferenceRandBootstrap",
	"InferenceRandBootstrapCI",
	"InferenceAsympLik",
	"InferenceParamBootstrap",
	"InferenceAsympLikStdModCache",
	"InferenceAsympLikStdModCacheNoParamBootstrap",
	"InferenceCountLikelihood",
	"InferenceKKPassThroughCompound",
	"InferenceKKPassThroughCompoundNoParamBootstrap",
	"InferenceMLEorKMSummaryTable"
)

EDI_INFERENCE_HIERARCHY_MIGRATION_MANIFEST = new.env(parent = emptyenv())

EDI_INFERENCE_ABSTRACT_CLASS_NAMES = c(
	"Inference",
	"InferenceAsymp",
	"InferenceJackknife",
	"InferenceNonParamBootstrap",
	"InferenceBayesianBootstrap",
	"InferenceRand",
	"InferenceRandCI",
	"InferenceRandBootstrap",
	"InferenceRandBootstrapCI",
	"InferenceAsympLik",
	"InferenceParamBootstrap",
	"InferenceKKPassThroughCompound",
	"InferenceKKPassThroughCompoundNoParamBootstrap",
	"InferenceAsympLikStdModCache",
	"InferenceAsympLikStdModCacheNoParamBootstrap",
	"InferenceCountLikelihood",
	"InferenceMLEorKMSummaryTable"
)

is_inference_r6_generator = function(obj) {
	if (!inherits(obj, "R6ClassGenerator")) return(FALSE)
	anc = obj
	while (!is.null(anc)) {
		if (identical(anc$classname, "Inference")) return(TRUE)
		anc = anc$get_inherit()
	}
	FALSE
}

infer_inference_response_types = function(name) {
	if (identical(name, "Inference") || grepl("^InferenceAll", name)) {
		return(c("continuous", "incidence", "count", "proportion", "survival", "ordinal"))
	}
	if (grepl("^InferenceContin", name) || grepl("^InferenceBai", name)) return("continuous")
	if (grepl("^InferenceCount", name)) return("count")
	if (grepl("^InferenceIncid", name) || grepl("^InferenceIncidence", name)) return("incidence")
	if (grepl("^InferenceOrdinal", name)) return("ordinal")
	if (grepl("^InferenceProp", name)) return("proportion")
	if (grepl("^InferenceSurvival", name)) return("survival")
	character()
}

infer_inference_likelihood_tier = function(name) {
	if (grepl("GEE|Quasi|Robust|Composite", name)) return("quasi")
	if (grepl("Cox|CondLogit|CondAdjCat|LWA", name)) return("partial")
	# DepCensTransform: InferenceSurvivalDepCensTransformRegr fits a full
	# parametric (bivariate log-normal transformation) likelihood with real
	# score/information/LR machinery and a parametric bootstrap -- before this
	# token was added it fell through every branch to "none", which violated
	# the tier table (none permits no LR/score/parametric bootstrap). See
	# fix_inference_hierarchy.md, "Asymptotic (Wald) No-Likelihood Migration",
	# 2026-08-17 tier-fix note.
	if (grepl(
		"OLS|Lin|LogRegr|LogBinomial|Probit|Poisson|NegBin|Hurdle|ZeroInflated|Beta|Weibull|GLMM|CLMM|PropOdds|Cauchit|Cloglog|Stereotype|ContRatio|AdjCat|OrderedProbit|BinomialIdentity|FractionalLogit|CountLikelihood|AsympLik|ParamBootstrap|OneLik|Copula|Frailty|DepCensTransform",
		name
	)) {
		return("full")
	}
	"none"
}

infer_inference_abstract = function(name) {
	identical(name, "Inference") ||
		name %in% EDI_INFERENCE_ABSTRACT_CLASS_NAMES ||
		grepl("Abstract", name, fixed = TRUE)
}

#' Whether a concrete `Inference` generator supports left-/interval-censored
#' survival data (finite `y_R`), i.e. whether `Inference$initialize()` would
#' accept construction on a design with `has_general_censoring() == TRUE`.
#'
#' Every `supports_interval_or_left_censored_data()` implementation across
#' the codebase is a trivial, argument-less, `self`/`private`-free literal
#' (`function() TRUE`/`function() FALSE`) -- confirmed by inspection of all
#' seven definitions as of 2026-08 -- so it is safe to invoke the nearest
#' ancestor's copy directly from the generator's own `private_methods` list
#' without constructing an instance (unlike private-method-name *sniffing*,
#' which this codebase is banning elsewhere, this reads the method's
#' *declared return value*, not just whether it exists).
#'
#' @keywords internal
#' @noRd
infer_inference_supports_general_censoring = function(generator) {
	current = generator
	while (!is.null(current)) {
		fn = current$private_methods$supports_interval_or_left_censored_data
		if (!is.null(fn)) return(isTRUE(fn()))
		current = current$get_inherit()
	}
	FALSE
}

#' Whether a concrete `Inference` generator requires a blocking design
#' (`Design$is_blocking_design()`), i.e. whether its constructor would
#' unconditionally reject a non-blocking design. Same safe-invoke-without-
#' construction approach as `infer_inference_supports_general_censoring()`
#' above (see that function's doc for why this is safe); currently only
#' `InferenceIncidExtendedRobins` overrides the default `FALSE`.
#'
#' @keywords internal
#' @noRd
infer_inference_requires_blocking_design = function(generator) {
	current = generator
	while (!is.null(current)) {
		fn = current$private_methods$requires_blocking_design
		if (!is.null(fn)) return(isTRUE(fn()))
		current = current$get_inherit()
	}
	FALSE
}

infer_inference_direct_components = function(name) {
	switch(
		name,
		InferenceRand = "RandomizationTest",
		InferenceRandCI = "RandomizationCI",
		InferenceNonParamBootstrap = "NonparametricBootstrap",
		InferenceRandBootstrap = "RandomizationBootstrap",
		InferenceRandBootstrapCI = "RandomizationBootstrapCI",
		InferenceBayesianBootstrap = "BayesianBootstrap",
		InferenceJackknife = "Jackknife",
		InferenceAsymp = "Wald",
		InferenceIncidExactBinomial = "ExactBinomialIncidence",
		InferenceIncidExactFisher = "ExactFisherIncidence",
		InferenceIncidenceExactZhang = "ExactZhangIncidence",
		InferenceAsympLik = "LikelihoodTests",
		InferenceParamBootstrap = "ParametricLikelihoodBootstrap",
		InferenceAsympLikStdModCache = "StandardModelCache",
		InferenceAsympLikStdModCacheNoParamBootstrap = "StandardModelCache",
			InferenceCountLikelihood = "CountLikelihoodPlumbing",
			InferenceCountZeroAugmentedPoissonAbstract = "ZeroAugmentedCountLikelihood",
			InferenceCountQuasiPoisson = c("Wald", "CountCompositeLikelihood"),
			InferenceCountRobustPoisson = c("Wald", "CountCompositeLikelihood", "RobustSandwich"),
			InferenceOrdinalPropOddsRegr = "OrdinalProportionalOddsLikelihood",
			InferenceOrdinalAdjCatLogitRegr = "OrdinalAdjacentCategoryLikelihood",
			InferenceOrdinalCloglogRegr = c(
				"BayesianBootstrap",
				"ParametricLikelihoodBootstrap",
				"OrdinalCloglogLikelihood"
			),
			InferenceOrdinalCauchitRegr = c(
				"BayesianBootstrap",
				"ParametricLikelihoodBootstrap",
				"OrdinalCauchitLikelihood"
			),
			InferenceOrdinalStereotypeLogitRegr = "OrdinalStereotypeLikelihood",
			InferenceOrdinalContRatioRegr = "OrdinalContinuationRatioLikelihood",
			InferenceOrdinalOrderedProbitRegr = "OrdinalOrderedProbitLikelihood",
			InferenceIncidLogRegr = "IncidenceLogisticLikelihood",
			InferenceIncidProbitRegr = "IncidenceProbitLikelihood",
			InferenceIncidLogBinomial = "IncidenceLogBinomialLikelihood",
			InferenceIncidModifiedPoisson = "IncidenceModifiedPoissonLikelihood",
			InferenceIncidBinomialIdentityRiskDiff = "IncidenceBinomialIdentityLikelihood",
			InferenceIncidGCompAbstract = "IncidenceGComputation",
			InferenceSurvivalWeibullRegr = "SurvivalWeibullLikelihood",
			InferenceSurvivalDepCensTransformRegr = "SurvivalDepCensTransform",
			InferenceSurvivalKKWeibullMarginal = c("BayesianBootstrap", "Wald", "SurvivalKKWeibullMarginal"),
			InferenceSurvivalKKClaytonCopulaIVWC = c("BayesianBootstrap", "Wald", "SurvivalKKClaytonCopulaIVWC"),
			InferenceSurvivalKKClaytonCopulaOneLik = "SurvivalKKClaytonCopulaOneLik",
			InferenceAbstractKKWeibullFrailtyIVWC = "SurvivalKKWeibullFrailtyIVWC",
			InferenceSurvivalKKWeibullFrailtyIVWC = "SurvivalKKWeibullFrailtyIVWCLeaf",
			InferenceAbstractKKWeibullFrailtyOneLik = "SurvivalKKWeibullFrailtyOneLik",
			InferenceSurvivalKKWeibullFrailtyOneLik = "SurvivalKKWeibullFrailtyOneLikLeaf",
			InferenceCountPoissonKKGEE = "KKGEE",
		InferenceIncidKKGEE = "KKGEE",
		InferenceOrdinalKKGEE = "KKGEE",
		InferencePropKKGEE = "KKGEE",
		InferenceKKPassThroughCompound = "KKCompound",
		InferenceKKPassThroughCompoundNoParamBootstrap = "KKCompound",
		InferenceCustomRand = "RandomizationTest",
		InferenceAllSimpleMeanDiff = c("BayesianBootstrap", "Wald", "SimpleMeanDifference"),
		InferenceAllSimpleMeanDiffPooledVar = c("BayesianBootstrap", "Wald", "SimpleMeanDifferencePooledVar"),
		InferenceAllKKMeanDiffIVWC = c("BayesianBootstrap", "Wald", "KKMeanDifferenceIVWC"),
		InferenceIncidKKNewcombeRiskDiff = c("BayesianBootstrap", "Wald", "KKNewcombeRiskDiffIVWC"),
		InferenceCountKKHurdlePoissonIVWC = c("BayesianBootstrap", "Wald", "CountKKHurdlePoissonIVWC"),
		InferenceAllSimpleWilcox = c("RandomizationBootstrap", "Wald", "SimpleWilcox"),
		InferenceAllKKWilcoxIVWC = c("RandomizationBootstrap", "Wald", "KKWilcoxIVWC"),
		# Both Cox entries list BayesianBootstrap explicitly: their factory calls
		# compose c("BayesianBootstrap", <cox component>) (the bootstrap layer is
		# NOT in the Cox components' dependency chains -- see the 2026-08-17
		# StratCox NULL-bootstrap-privates fix), so the registry mapping must say
		# so or effective/target components drift from the assembled reality.
		InferenceSurvivalCoxPHRegr = c("BayesianBootstrap", "CoxPartialLikelihood"),
		InferenceSurvivalStratCoxPHRegr = c("BayesianBootstrap", "StratifiedCoxPartialLikelihood"),
		# The following classes compose components directly via their own
		# define_inference_class(components = ...) call (no intermediate
		# algorithmic abstract base), so their direct_components here must
		# mirror that call exactly -- these were omitted from this switch,
		# which silently gave them character(0) direct_components and, via
		# get_effective_capabilities(), zero capabilities (e.g. supports("wald")
		# returning FALSE despite composing the Wald component and advertising
		# "wald" from get_supported_testing_types()). Found investigating
		# spurious "every design/inference combo was filtered out" simulation
		# warnings and CMH/get_standard_error test warnings.
		InferenceContinRobustRegr = c("BayesianBootstrap", "Wald"),
		InferenceIncidWald = c("BayesianBootstrap", "Wald", "SimpleMeanDifference"),
		InferencePropGCompMeanDiff = c("BayesianBootstrap", "Jackknife"),
		InferenceSurvivalLogRank = c("BayesianBootstrap", "Wald"),
		InferencePropQuantileRegr = c("BayesianBootstrap", "Wald"),
		InferenceAbstractKKCondLogitGLMM = "KKPassThrough",
		InferenceSurvivalGehanWilcox = c("BayesianBootstrap", "Wald"),
		InferenceIncidCMH = c("BayesianBootstrap", "Wald", "SimpleMeanDifference"),
		InferenceOrdinalKKCondAdjCatLogitRegr = c("OrdinalConditionalLogitPartialLikelihood", "KKPassThrough"),
		InferenceOrdinalRidit = c("BayesianBootstrap", "Wald"),
		InferenceOrdinalGCompMeanDiff = c("BayesianBootstrap", "Wald"),
		InferenceSurvivalRestrictedMeanDiff = c("BayesianBootstrap", "Wald"),
		InferenceIncidExtendedRobins = c("BayesianBootstrap", "Wald", "SimpleMeanDifference"),
		InferenceContinQuantileRegr = c("BayesianBootstrap", "Wald"),
		InferenceOrdinalJonckheereTerpstraTest = c("BayesianBootstrap", "Wald"),
		InferenceIncidNewcombeRiskDiff = c("BayesianBootstrap", "Wald"),
		InferenceSurvivalKMDiff = c("BayesianBootstrap", "Wald"),
		InferenceIncidRiskDiff = c("BayesianBootstrap", "Wald"),
		InferenceOrdinalPartialProportionalOddsRegr = c("BayesianBootstrap", "Wald"),
		InferenceAbstractQuantileRandCI = "QuantileRandomizationCI",
		InferenceCustomAsymp = c("Wald", "NonparametricBootstrap"),
		InferenceCustomBoot = "NonparametricBootstrap",
		InferenceAbstractKKOrdinalCLMM = "KKPassThrough",
		InferenceIncidMiettinenNurminenRiskDiff = c("BayesianBootstrap", "Wald"),
		InferenceIncidGCompRiskDiff = c("BayesianBootstrap", "Jackknife", "IncidenceGComputation"),
		InferenceIncidGCompRiskRatio = c("BayesianBootstrap", "Jackknife", "IncidenceGComputation"),
		character()
	)
}

always_compatible_inference_metadata = function(design_metadata) {
	TRUE
}

validate_inference_class_metadata = function(metadata) {
	required = c(
		"name", "parent", "abstract", "exported", "response_types",
		"design_families", "compatibility", "likelihood_tier",
		"direct_components", "required_packages"
	)
	missing = setdiff(required, names(metadata))
	if (length(missing) > 0L) {
		stop(sprintf(
			"Inference metadata for %s is missing required field(s): %s",
			metadata$name %||% "<unknown>",
			paste(missing, collapse = ", ")
		), call. = FALSE)
	}
	if ("alias_of" %in% names(metadata)) {
		stop(sprintf(
			"Inference metadata for %s contains forbidden alias metadata.",
			metadata$name
		), call. = FALSE)
	}
	if (!is.character(metadata$name) || length(metadata$name) != 1L || !nzchar(metadata$name)) {
		stop("Inference metadata field `name` must be a non-empty character scalar.", call. = FALSE)
	}
	if (!(is.null(metadata$parent) || (is.character(metadata$parent) && length(metadata$parent) == 1L && nzchar(metadata$parent)))) {
		stop(sprintf("Inference metadata for %s has invalid `parent`.", metadata$name), call. = FALSE)
	}
	if (!is.logical(metadata$abstract) || length(metadata$abstract) != 1L || is.na(metadata$abstract)) {
		stop(sprintf("Inference metadata for %s has invalid `abstract`.", metadata$name), call. = FALSE)
	}
	# NA is a valid, deliberate sentinel here (see design_class_registry.R's identical
	# note): it means "not yet resolved against the live namespace", resolved lazily by
	# get_inference_class_metadata()/inference_class_registry_as_list().
	if (!is.logical(metadata$exported) || length(metadata$exported) != 1L) {
		stop(sprintf("Inference metadata for %s has invalid `exported`.", metadata$name), call. = FALSE)
	}
	if (!is.character(metadata$response_types)) {
		stop(sprintf("Inference metadata for %s has invalid `response_types`.", metadata$name), call. = FALSE)
	}
	if (!is.character(metadata$design_families)) {
		stop(sprintf("Inference metadata for %s has invalid `design_families`.", metadata$name), call. = FALSE)
	}
	if (!is.function(metadata$compatibility)) {
		stop(sprintf("Inference metadata for %s has invalid `compatibility`.", metadata$name), call. = FALSE)
	}
	if (!is.character(metadata$likelihood_tier) ||
			length(metadata$likelihood_tier) != 1L ||
			!(metadata$likelihood_tier %in% EDI_INFERENCE_ALLOWED_LIKELIHOOD_TIERS)) {
		stop(sprintf(
			"Inference metadata for %s has invalid `likelihood_tier`: %s",
			metadata$name,
			paste(metadata$likelihood_tier, collapse = ", ")
		), call. = FALSE)
	}
	if (!is.character(metadata$direct_components)) {
		stop(sprintf("Inference metadata for %s has invalid `direct_components`.", metadata$name), call. = FALSE)
	}
	if (!is.character(metadata$required_packages)) {
		stop(sprintf("Inference metadata for %s has invalid `required_packages`.", metadata$name), call. = FALSE)
	}
	if (!is.character(metadata$excluded_capabilities %||% character())) {
		stop(sprintf("Inference metadata for %s has invalid `excluded_capabilities`.", metadata$name), call. = FALSE)
	}
	invisible(TRUE)
}

register_inference_class = function(name, parent = NULL, metadata = list(), direct_components = character()) {
	record = utils::modifyList(
		list(
			name = name,
			parent = parent,
			abstract = FALSE,
			exported = FALSE,
			response_types = character(),
			design_families = "all",
			compatibility = always_compatible_inference_metadata,
			likelihood_tier = "none",
			direct_components = direct_components,
			required_packages = character(),
			capabilities = character(),
			excluded_capabilities = character(),
			supports_general_censoring = FALSE,
			requires_blocking_design = FALSE
		),
		metadata
	)
	record$name = name
	record["parent"] = list(parent)
	record$direct_components = direct_components
	validate_inference_class_metadata(record)
	if (exists(name, envir = EDI_INFERENCE_CLASS_REGISTRY, inherits = FALSE)) {
		stop(sprintf("Inference class metadata already registered for %s.", name), call. = FALSE)
	}
	assign(name, record, envir = EDI_INFERENCE_CLASS_REGISTRY)
	clear_inference_effective_metadata_cache()
	invisible(record)
}

inference_class_registry_as_list = function() {
	records = mget(ls(EDI_INFERENCE_CLASS_REGISTRY), envir = EDI_INFERENCE_CLASS_REGISTRY, inherits = FALSE)
	unresolved = vapply(records, function(r) is.na(r$exported), logical(1))
	if (any(unresolved)) {
		live_exports = tryCatch(getNamespaceExports("EDI"), error = function(e) character())
		for (name in names(records)[unresolved]) {
			records[[name]]$exported = name %in% live_exports
		}
	}
	records
}

validate_inference_class_registry = function(registry = inference_class_registry_as_list()) {
	if (!is.list(registry)) {
		stop("Inference class registry must be a list of metadata records.", call. = FALSE)
	}
	for (name in names(registry)) {
		validate_inference_class_metadata(registry[[name]])
		if (!identical(registry[[name]]$name, name)) {
			stop(sprintf("Inference metadata name mismatch for registry key %s.", name), call. = FALSE)
		}
		parent = registry[[name]]$parent
		if (!is.null(parent) && !(parent %in% names(registry))) {
			stop(sprintf("Inference metadata for %s has unregistered parent %s.", name, parent), call. = FALSE)
		}
	}
	invisible(TRUE)
}

get_inference_class_metadata = function(name) {
	if (!exists(name, envir = EDI_INFERENCE_CLASS_REGISTRY, inherits = FALSE)) {
		stop(sprintf("No inference class metadata registered for %s.", name), call. = FALSE)
	}
	record = get(name, envir = EDI_INFERENCE_CLASS_REGISTRY, inherits = FALSE)
	# `exported = NA` is a populate-time sentinel meaning "not yet resolved against the
	# live namespace" -- see the identical note on get_design_class_metadata() in
	# design_class_registry.R for why (confirmed empirically both registries share this
	# defect and fix). A non-NA value means the record was registered explicitly (e.g. a
	# test's register_inference_class() call) and is trusted as-is, not overwritten.
	if (is.na(record$exported)) {
		record$exported = name %in% tryCatch(getNamespaceExports("EDI"), error = function(e) character())
	}
	record
}

get_direct_components = function(name) {
	get_inference_class_metadata(name)$direct_components
}

clear_inference_effective_metadata_cache = function() {
	rm(list = ls(EDI_INFERENCE_EFFECTIVE_COMPONENTS_CACHE), envir = EDI_INFERENCE_EFFECTIVE_COMPONENTS_CACHE)
	rm(list = ls(EDI_INFERENCE_EFFECTIVE_CAPABILITIES_CACHE), envir = EDI_INFERENCE_EFFECTIVE_CAPABILITIES_CACHE)
	invisible(TRUE)
}

resolve_inference_components = function(name) {
	metadata = get_inference_class_metadata(name)
	parent_components = if (is.null(metadata$parent)) {
		character()
	} else {
		resolve_inference_components(metadata$parent)
	}
	duplicate_components = intersect(parent_components, metadata$direct_components)
	if (length(duplicate_components) > 0L) {
		stop(sprintf(
			"%s re-lists inherited component(s): %s",
			name,
			paste(duplicate_components, collapse = ", ")
		), call. = FALSE)
	}
	direct_components = tryCatch(
		resolve_component_dependencies(
			metadata$direct_components,
			satisfied_components = parent_components
		),
		error = function(e) {
			stop(sprintf("%s: %s", name, conditionMessage(e)), call. = FALSE)
		}
	)
	duplicate_transitive = intersect(parent_components, direct_components)
	if (length(duplicate_transitive) > 0L) {
		stop(sprintf(
			"%s duplicates inherited transitive component(s): %s",
			name,
			paste(duplicate_transitive, collapse = ", ")
		), call. = FALSE)
	}
	c(parent_components, direct_components)
}

get_effective_components = function(name) {
	if (exists(name, envir = EDI_INFERENCE_EFFECTIVE_COMPONENTS_CACHE, inherits = FALSE)) {
		return(get(name, envir = EDI_INFERENCE_EFFECTIVE_COMPONENTS_CACHE, inherits = FALSE))
	}
	components = resolve_inference_components(name)
	assign(name, components, envir = EDI_INFERENCE_EFFECTIVE_COMPONENTS_CACHE)
	components
}

get_effective_capabilities = function(name) {
	if (exists(name, envir = EDI_INFERENCE_EFFECTIVE_CAPABILITIES_CACHE, inherits = FALSE)) {
		return(get(name, envir = EDI_INFERENCE_EFFECTIVE_CAPABILITIES_CACHE, inherits = FALSE))
	}
	metadata = get_inference_class_metadata(name)
	component_capabilities = as.character(unlist(lapply(get_effective_components(name), function(component_name) {
		get_inference_component(component_name)$provides_capabilities
	}), use.names = FALSE))
	capabilities = setdiff(
		unique(c(component_capabilities, metadata$capabilities %||% character())),
		metadata$excluded_capabilities %||% character()
	)
	assign(name, capabilities, envir = EDI_INFERENCE_EFFECTIVE_CAPABILITIES_CACHE)
	capabilities
}

inference_class_ancestor_names = function(name, registry = inference_class_registry_as_list()) {
	ancestors = character()
	current = registry[[name]]
	while (!is.null(current) && !is.null(current$parent)) {
		ancestors = c(ancestors, current$parent)
		current = registry[[current$parent]]
	}
	ancestors
}

target_inference_components = function(name) {
	if (identical(name, "Inference")) return(character())
	metadata = get_inference_class_metadata(name)
	if (isTRUE(metadata$abstract)) return(get_effective_components(name))
	get_effective_components(name)
}

target_inference_parent = function(name) {
	metadata = get_inference_class_metadata(name)
	if (identical(name, "Inference")) return(NULL)
	if (isTRUE(metadata$abstract)) return(metadata$parent)
	"Inference"
}

build_inference_hierarchy_migration_record = function(name) {
	metadata = get_inference_class_metadata(name)
	ancestors = inference_class_ancestor_names(name)
	algorithmic_ancestors = intersect(ancestors, EDI_INFERENCE_ALGORITHM_COMPATIBILITY_BASES)
	target_components = target_inference_components(name)
	target_capabilities = setdiff(
		unique(c(
			as.character(unlist(lapply(target_components, function(component_name) {
				get_inference_component(component_name)$provides_capabilities
			}), use.names = FALSE)),
			metadata$capabilities %||% character()
		)),
		metadata$excluded_capabilities %||% character()
	)
	migration_status = if (identical(name, "Inference")) {
		"root"
	} else if (isTRUE(metadata$abstract)) {
		"infrastructure"
	} else if (name %in% names(EDI_CUSTOM_RANDOMIZATION_TARGETS)) {
		EDI_CUSTOM_RANDOMIZATION_TARGETS[[name]]$migration_status %||% "pending"
	} else if (length(algorithmic_ancestors) == 0L && identical(metadata$parent, "Inference")) {
		"migrated"
	} else {
		"pending"
	}
	list(
		name = name,
		current_parent = metadata$parent,
		current_ancestors = ancestors,
		current_abstract = metadata$abstract,
		current_exported = metadata$exported,
		current_response_types = metadata$response_types,
		current_design_families = metadata$design_families,
		current_likelihood_tier = metadata$likelihood_tier,
		algorithmic_compatibility_ancestors = algorithmic_ancestors,
		target_parent = target_inference_parent(name),
		target_components = target_components,
		target_capabilities = target_capabilities,
		target_likelihood_tier = metadata$likelihood_tier,
		target_response_types = metadata$response_types,
		target_design_families = metadata$design_families,
		migration_status = migration_status
	)
}

validate_inference_hierarchy_migration_record = function(record) {
	required = c(
		"name", "current_parent", "current_ancestors", "current_abstract",
		"current_exported", "current_response_types", "current_design_families",
		"current_likelihood_tier", "algorithmic_compatibility_ancestors",
		"target_parent", "target_components", "target_capabilities",
		"target_likelihood_tier", "target_response_types", "target_design_families",
		"migration_status"
	)
	missing = setdiff(required, names(record))
	if (length(missing) > 0L) {
		stop(sprintf(
			"Inference hierarchy migration record for %s is missing field(s): %s",
			record$name %||% "<unknown>",
			paste(missing, collapse = ", ")
		), call. = FALSE)
	}
	if (!is.character(record$name) || length(record$name) != 1L || !nzchar(record$name)) {
		stop("Migration record `name` must be a non-empty character scalar.", call. = FALSE)
	}
	if (!(record$migration_status %in% c("root", "infrastructure", "pending", "migrated"))) {
		stop(sprintf("Invalid migration status for %s.", record$name), call. = FALSE)
	}
	if (!(record$target_likelihood_tier %in% EDI_INFERENCE_ALLOWED_LIKELIHOOD_TIERS)) {
		stop(sprintf("Invalid target likelihood tier for %s.", record$name), call. = FALSE)
	}
	unknown_components = setdiff(record$target_components, ls(EDI_INFERENCE_COMPONENTS))
	if (length(unknown_components) > 0L) {
		stop(sprintf(
			"Migration record for %s has unknown target component(s): %s",
			record$name,
			paste(unknown_components, collapse = ", ")
		), call. = FALSE)
	}
	if (any(grepl("^InferenceMixin", record$target_components))) {
		stop(sprintf("Migration record for %s contains legacy mixin component names.", record$name), call. = FALSE)
	}
	invisible(TRUE)
}

clear_inference_hierarchy_migration_manifest = function() {
	rm(list = ls(EDI_INFERENCE_HIERARCHY_MIGRATION_MANIFEST), envir = EDI_INFERENCE_HIERARCHY_MIGRATION_MANIFEST)
	invisible(TRUE)
}

populate_inference_hierarchy_migration_manifest = function() {
	clear_inference_hierarchy_migration_manifest()
	for (name in ls(EDI_INFERENCE_CLASS_REGISTRY)) {
		record = build_inference_hierarchy_migration_record(name)
		validate_inference_hierarchy_migration_record(record)
		assign(name, record, envir = EDI_INFERENCE_HIERARCHY_MIGRATION_MANIFEST)
	}
	invisible(EDI_INFERENCE_HIERARCHY_MIGRATION_MANIFEST)
}

inference_hierarchy_migration_manifest_as_list = function() {
	mget(ls(EDI_INFERENCE_HIERARCHY_MIGRATION_MANIFEST), envir = EDI_INFERENCE_HIERARCHY_MIGRATION_MANIFEST, inherits = FALSE)
}

get_inference_hierarchy_migration_record = function(name) {
	if (!exists(name, envir = EDI_INFERENCE_HIERARCHY_MIGRATION_MANIFEST, inherits = FALSE)) {
		stop(sprintf("No inference hierarchy migration record registered for %s.", name), call. = FALSE)
	}
	get(name, envir = EDI_INFERENCE_HIERARCHY_MIGRATION_MANIFEST, inherits = FALSE)
}

inference_public_method_names = function(name, generator = NULL) {
	if (is.null(generator)) {
		ns = environment(populate_inference_class_registry)
		if (!exists(name, envir = ns, inherits = FALSE)) {
			stop(sprintf("No R6 generator found for inference class %s.", name), call. = FALSE)
		}
		generator = get(name, envir = ns, inherits = FALSE)
	}
	if (!inherits(generator, "R6ClassGenerator")) {
		stop(sprintf("Object for %s is not an R6 generator.", name), call. = FALSE)
	}
	public_names = character()
	current = generator
	while (!is.null(current)) {
		public_names = c(public_names, names(current$public_methods) %||% character())
		current = current$get_inherit()
	}
	unique(public_names)
}

inference_private_owner_names = function(name, generator = NULL) {
	if (is.null(generator)) {
		ns = environment(populate_inference_class_registry)
		if (!exists(name, envir = ns, inherits = FALSE)) {
			stop(sprintf("No R6 generator found for inference class %s.", name), call. = FALSE)
		}
		generator = get(name, envir = ns, inherits = FALSE)
	}
	if (!inherits(generator, "R6ClassGenerator")) {
		stop(sprintf("Object for %s is not an R6 generator.", name), call. = FALSE)
	}
	owners = list()
	current = generator
	while (!is.null(current)) {
		private_names = unique(c(
			names(current$private_methods) %||% character(),
			names(current$private_fields) %||% character()
		))
		for (private_name in private_names) {
			owners[[private_name]] = c(owners[[private_name]] %||% character(), current$classname)
		}
		current = current$get_inherit()
	}
	owners
}

public_methods_required_for_capabilities = function(capabilities) {
	unique(as.character(unlist(
		public_methods_for_capability[intersect(names(public_methods_for_capability), capabilities)],
		use.names = FALSE
	)))
}

inference_optional_method_names_for_capabilities = function(capabilities) {
	sort(unique(public_methods_required_for_capabilities(capabilities)))
}

validate_inference_public_optional_method_presence = function(name, capabilities = get_effective_capabilities(name), public_method_names = NULL) {
	required_public_methods = public_methods_required_for_capabilities(capabilities)
	if (length(required_public_methods) == 0L) return(invisible(TRUE))
	if (is.null(public_method_names)) {
		public_method_names = inference_public_method_names(name)
	}
	missing_public_methods = setdiff(required_public_methods, public_method_names)
	if (length(missing_public_methods) > 0L) {
		stop(sprintf(
			"%s is missing public method(s) required by effective capabilities: %s",
			name,
			paste(missing_public_methods, collapse = ", ")
		), call. = FALSE)
	}
	invisible(TRUE)
}

mark_inference_class_migrated = function(name, public_method_names = NULL) {
	record = get_inference_hierarchy_migration_record(name)
	metadata = get_inference_class_metadata(name)
	if (identical(record$migration_status, "root") || identical(record$migration_status, "infrastructure") || isTRUE(metadata$abstract)) {
		stop(sprintf("%s is not a concrete inference class and cannot be marked migrated.", name), call. = FALSE)
	}
	if (!identical(metadata$parent, record$target_parent)) {
		stop(sprintf(
			"%s cannot be marked migrated: current parent `%s` does not match target parent `%s`.",
			name,
			metadata$parent %||% "<none>",
			record$target_parent %||% "<none>"
		), call. = FALSE)
	}
	current_ancestors = inference_class_ancestor_names(name)
	algorithmic_ancestors = intersect(current_ancestors, EDI_INFERENCE_ALGORITHM_COMPATIBILITY_BASES)
	if (length(algorithmic_ancestors) > 0L) {
		stop(sprintf(
			"%s cannot be marked migrated: it still descends from algorithmic compatibility base(s): %s",
			name,
			paste(algorithmic_ancestors, collapse = ", ")
		), call. = FALSE)
	}
	effective_components = get_effective_components(name)
	if (!identical(effective_components, record$target_components)) {
		stop(sprintf(
			"%s cannot be marked migrated: effective components do not match target components.",
			name
		), call. = FALSE)
	}
	effective_capabilities = get_effective_capabilities(name)
	if (!identical(effective_capabilities, record$target_capabilities)) {
		stop(sprintf(
			"%s cannot be marked migrated: effective capabilities do not match target capabilities.",
			name
		), call. = FALSE)
	}
	validate_inference_public_optional_method_presence(
		name = name,
		capabilities = effective_capabilities,
		public_method_names = public_method_names
	)
	record$migration_status = "migrated"
	validate_inference_hierarchy_migration_record(record)
	assign(name, record, envir = EDI_INFERENCE_HIERARCHY_MIGRATION_MANIFEST)
	invisible(record)
}

is_kk_inference_migration_record = function(record) {
	grepl("KK|IVWC", record$name) ||
		any(grepl("KK|IVWC", record$current_ancestors)) ||
		any(grepl("^KK", record$target_components))
}

count_inference_migration_records_by = function(records, values_fn, field_name) {
	values = as.character(unlist(lapply(records, values_fn), use.names = FALSE))
	if (length(values) == 0L) {
		return(data.frame(
			metric = character(),
			value = character(),
			n = integer(),
			row.names = NULL,
			stringsAsFactors = FALSE
		))
	}
	counts = sort(table(values), decreasing = TRUE)
	data.frame(
		metric = field_name,
		value = names(counts),
		n = as.integer(counts),
		row.names = NULL,
		stringsAsFactors = FALSE
	)
}

inference_hierarchy_migration_summary = function(manifest = inference_hierarchy_migration_manifest_as_list()) {
	pending = Filter(function(record) {
		identical(record$migration_status, "pending") && !isTRUE(record$current_abstract)
	}, manifest)
	list(
		by_current_parent = count_inference_migration_records_by(
			pending,
			function(record) record$current_parent %||% "<none>",
			"current_parent"
		),
		by_likelihood_tier = count_inference_migration_records_by(
			pending,
			function(record) record$current_likelihood_tier,
			"likelihood_tier"
		),
		by_response_type = count_inference_migration_records_by(
			pending,
			function(record) record$current_response_types,
			"response_type"
		),
		by_kk_status = count_inference_migration_records_by(
			pending,
			function(record) if (is_kk_inference_migration_record(record)) "KK_or_IVWC" else "non_KK",
			"kk_status"
		)
	)

	}

inference_hierarchy_migration_order = function(
	manifest = inference_hierarchy_migration_manifest_as_list(),
	statuses = c("pending", "migrated")
) {
	records = Filter(function(record) {
		!isTRUE(record$current_abstract) && record$migration_status %in% statuses
	}, manifest)
	if (length(records) == 0L) return(character())
	class_names = names(records)
	parent_map = stats::setNames(vapply(records, function(record) record$current_parent %||% NA_character_, character(1L)), class_names)
	children_for = function(parent_name) class_names[!is.na(parent_map) & parent_map == parent_name]
	depth_cache = new.env(parent = emptyenv())
	descendant_depth = function(name) {
		if (exists(name, envir = depth_cache, inherits = FALSE)) {
			return(get(name, envir = depth_cache, inherits = FALSE))
		}
		children = children_for(name)
		depth = if (length(children) == 0L) 0L else 1L + max(vapply(children, descendant_depth, integer(1L)))
		assign(name, depth, envir = depth_cache)
		depth
	}
	depths = vapply(class_names, descendant_depth, integer(1L))
	class_names[order(depths, class_names)]
}

edi_require_shallow_inference_hierarchy = function() {
	tolower(Sys.getenv("EDI_REQUIRE_SHALLOW_INFERENCE_HIERARCHY", unset = "false")) %in% c("1", "true", "yes")
}

assert_shallow_inference_hierarchy_complete = function(manifest = inference_hierarchy_migration_manifest_as_list(), require = edi_require_shallow_inference_hierarchy()) {
	if (!isTRUE(require)) return(invisible(TRUE))
	pending = Filter(function(record) {
		identical(record$migration_status, "pending") && !isTRUE(record$current_abstract)
	}, manifest)
	if (length(pending) > 0L) {
		stop(sprintf(
			"EDI_REQUIRE_SHALLOW_INFERENCE_HIERARCHY is enabled, but %d concrete inference class(es) are still pending migration: %s",
			length(pending),
			paste(utils::head(sort(names(pending)), 10L), collapse = ", ")
		), call. = FALSE)
	}
	invisible(TRUE)
}

inference_no_likelihood_group = function(record) {
	capabilities = record$target_capabilities %||% character()
	ancestors = record$current_ancestors %||% character()
	if ("exact_test" %in% capabilities || grepl("Exact", record$name)) {
		return("exact")
	}
	if ("randomization_test" %in% capabilities || "InferenceRand" %in% ancestors) {
		return("randomization")
	}
	if (any(c("jackknife", "wald") %in% capabilities) ||
			any(c("InferenceJackknife", "InferenceAsymp") %in% ancestors)) {
		return("jackknife_asymptotic")
	}
	"pure_estimator"
}

inference_no_likelihood_concrete_groups = function(manifest = inference_hierarchy_migration_manifest_as_list()) {
	no_likelihood = Filter(function(record) {
		!isTRUE(record$current_abstract) &&
			identical(record$current_likelihood_tier, "none")
	}, manifest)
	groups = list(
		exact = character(),
		randomization = character(),
		jackknife_asymptotic = character(),
		pure_estimator = character()
	)
	for (record in no_likelihood) {
		group = inference_no_likelihood_group(record)
		groups[[group]] = c(groups[[group]], record$name)
	}
	lapply(groups, sort)
}

get_no_likelihood_special_classification = function(name) {
	EDI_NO_LIKELIHOOD_SPECIAL_CLASSIFICATIONS[[name]] %||% NULL
}

build_exact_incidence_behavior_record = function(name) {
	if (!(name %in% EDI_EXACT_INCIDENCE_CLASS_NAMES)) {
		stop(sprintf("%s is not a registered exact incidence class.", name), call. = FALSE)
	}
	target = EDI_EXACT_INCIDENCE_TARGETS[[name]]
	current_public_methods = inference_public_method_names(name)
	current_optional_methods = sort(unique(intersect(
		current_public_methods,
		inference_optional_method_names_for_capabilities(c(
			"exact_test",
			"nonparametric_bootstrap",
			"randomization_test",
			"randomization_ci",
			"randomization_bootstrap",
			"bayesian_bootstrap",
			"jackknife"
		))
	)))
	intentional_methods = inference_optional_method_names_for_capabilities(target$intentional_capabilities)
	list(
		name = name,
		current_public_optional_methods = current_optional_methods,
		intentional_capabilities = target$intentional_capabilities,
		intentional_public_methods = intentional_methods,
		legacy_optional_surface = setdiff(current_optional_methods, intentional_methods),
		target_components = target$target_components,
		notes = target$notes
	)
}

exact_incidence_behavior_manifest = function() {
	stats::setNames(lapply(EDI_EXACT_INCIDENCE_CLASS_NAMES, build_exact_incidence_behavior_record), EDI_EXACT_INCIDENCE_CLASS_NAMES)
}

simple_estimator_migration_groups = function(class_names = EDI_SIMPLE_ESTIMATOR_CLASS_NAMES) {
	targets = EDI_SIMPLE_ESTIMATOR_TARGETS[class_names]
	missing_targets = setdiff(class_names, names(EDI_SIMPLE_ESTIMATOR_TARGETS))
	if (length(missing_targets) > 0L) {
		stop(sprintf(
			"Simple estimator class(es) are missing target metadata: %s",
			paste(missing_targets, collapse = ", ")
		), call. = FALSE)
	}
	families = vapply(targets, function(target) target$family, character(1L))
	list(
		simple_mean_difference = sort(class_names[families == "simple_mean_difference"]),
		wilcoxon_rank = sort(class_names[families == "wilcoxon_rank"])
	)
}

build_simple_estimator_behavior_record = function(name) {
	target = EDI_SIMPLE_ESTIMATOR_TARGETS[[name]]
	if (is.null(target)) {
		stop(sprintf("%s is not a registered simple estimator migration target.", name), call. = FALSE)
	}
	metadata = get_inference_class_metadata(name)
	private_owners = inference_private_owner_names(name)
	current_public_methods = inference_public_method_names(name)
	current_optional_methods = sort(unique(intersect(
		current_public_methods,
		inference_optional_method_names_for_capabilities(c(
			"randomization_test",
			"randomization_ci",
			"nonparametric_bootstrap",
			"randomization_bootstrap",
			"bayesian_bootstrap",
			"jackknife",
			"wald",
			"likelihood_tests",
			"parametric_likelihood_bootstrap"
		))
	)))
	intentional_methods = inference_optional_method_names_for_capabilities(target$intentional_capabilities)
	list(
		name = name,
		family = target$family,
		current_parent = metadata$parent,
		current_effective_components = get_effective_components(name),
		current_effective_capabilities = get_effective_capabilities(name),
		current_public_methods = current_public_methods,
		current_public_optional_methods = current_optional_methods,
		private_owner_names = names(private_owners),
		duplicate_private_owner_names = names(private_owners[vapply(private_owners, length, integer(1L)) > 1L]),
		migration_status = target$migration_status %||% "pending",
		migration_evidence = target$migration_evidence %||% character(),
		target_parent = "Inference",
		target_components = target$target_components,
		intentional_capabilities = target$intentional_capabilities,
		intentional_public_methods = intentional_methods,
		legacy_optional_surface = setdiff(current_optional_methods, c(intentional_methods, "get_supported_testing_types")),
		notes = target$notes
	)
}

simple_estimator_behavior_manifest = function() {
	stats::setNames(lapply(EDI_SIMPLE_ESTIMATOR_CLASS_NAMES, build_simple_estimator_behavior_record), EDI_SIMPLE_ESTIMATOR_CLASS_NAMES)
}

simple_estimator_migration_counts = function(manifest = simple_estimator_behavior_manifest()) {
	families = sort(unique(vapply(manifest, function(record) record$family, character(1L))))
	do.call(rbind, lapply(families, function(family) {
		records = Filter(function(record) identical(record$family, family), manifest)
		data.frame(
			family = family,
			total = length(records),
			migrated = sum(vapply(records, function(record) identical(record$migration_status, "migrated"), logical(1L))),
			pending = sum(vapply(records, function(record) !identical(record$migration_status, "migrated"), logical(1L))),
			stringsAsFactors = FALSE
		)
	}))
}

mark_simple_estimator_classes_migrated = function(class_names = EDI_SIMPLE_ESTIMATOR_CLASS_NAMES) {
	for (name in class_names) {
		target = EDI_SIMPLE_ESTIMATOR_TARGETS[[name]]
		if (is.null(target)) {
			stop(sprintf("%s is not a registered simple-estimator migration target.", name), call. = FALSE)
		}
		if (!identical(target$migration_status %||% "pending", "migrated")) next
		missing_evidence = setdiff(
			EDI_NO_LIKELIHOOD_MIGRATION_REQUIRED_EVIDENCE,
			target$migration_evidence %||% character()
		)
		if (length(missing_evidence) > 0L) {
			stop(sprintf(
				"%s cannot be marked migrated: missing no-likelihood migration evidence: %s",
				name,
				paste(missing_evidence, collapse = ", ")
			), call. = FALSE)
		}
		record = build_simple_estimator_behavior_record(name)
		if (length(record$legacy_optional_surface) > 0L) {
			stop(sprintf(
				"%s cannot be marked migrated: legacy optional public method(s) remain: %s",
				name,
				paste(record$legacy_optional_surface, collapse = ", ")
			), call. = FALSE)
		}
		mark_inference_class_migrated(
			name,
			public_method_names = record$current_public_optional_methods
		)
	}
	invisible(inference_hierarchy_migration_manifest_as_list()[class_names])
}

quasi_robust_concrete_class_names = function(manifest = inference_hierarchy_migration_manifest_as_list()) {
	sort(names(Filter(function(record) {
		identical(record$current_likelihood_tier, "quasi") && !isTRUE(record$current_abstract)
	}, manifest)))
}

quasi_robust_behavior_groups = function(class_names = EDI_QUASI_ROBUST_CLASS_NAMES) {
	targets = EDI_QUASI_ROBUST_TARGETS[class_names]
	missing_targets = setdiff(class_names, names(EDI_QUASI_ROBUST_TARGETS))
	if (length(missing_targets) > 0L) {
		stop(sprintf(
			"Quasi/robust class(es) are missing target metadata: %s",
			paste(missing_targets, collapse = ", ")
		), call. = FALSE)
	}
	behaviors = sort(unique(unlist(lapply(targets, `[[`, "behavior"), use.names = FALSE)))
	stats::setNames(lapply(behaviors, function(behavior) {
		sort(names(Filter(function(target) behavior %in% target$behavior, targets)))
	}), behaviors)
}

build_quasi_robust_behavior_record = function(name) {
	target = EDI_QUASI_ROBUST_TARGETS[[name]]
	if (is.null(target)) {
		stop(sprintf("%s is not a registered quasi/robust migration target.", name), call. = FALSE)
	}
	metadata = get_inference_class_metadata(name)
	list(
		name = name,
		estimator_family = target$estimator_family,
		behavior = target$behavior,
		current_parent = metadata$parent,
		current_effective_components = get_effective_components(name),
		current_effective_capabilities = get_effective_capabilities(name),
		current_likelihood_tier = metadata$likelihood_tier,
		target_parent = "Inference",
		target_likelihood_tier = "quasi",
		composite_likelihood_tests_component = isTRUE(target$composite_likelihood_tests_component),
		composite_likelihood_public_methods = target$composite_likelihood_public_methods %||% character(),
		notes = target$notes
	)
}

quasi_robust_behavior_manifest = function() {
	manifest_names = quasi_robust_concrete_class_names()
	missing_targets = setdiff(manifest_names, names(EDI_QUASI_ROBUST_TARGETS))
	extra_targets = setdiff(names(EDI_QUASI_ROBUST_TARGETS), manifest_names)
	if (length(missing_targets) > 0L || length(extra_targets) > 0L) {
		stop(sprintf(
			"Quasi/robust migration target mismatch. Missing target(s): %s. Extra target(s): %s.",
			paste(missing_targets, collapse = ", "),
			paste(extra_targets, collapse = ", ")
		), call. = FALSE)
	}
	stats::setNames(lapply(EDI_QUASI_ROBUST_CLASS_NAMES, build_quasi_robust_behavior_record), EDI_QUASI_ROBUST_CLASS_NAMES)
}

	quasi_robust_behavior_counts = function(manifest = quasi_robust_behavior_manifest()) {
		groups = quasi_robust_behavior_groups(names(manifest))
		do.call(rbind, lapply(names(groups), function(behavior) {
			data.frame(
				behavior = behavior,
				class_count = length(groups[[behavior]]),
				stringsAsFactors = FALSE
			)
		}))
	}

	partial_likelihood_concrete_class_names = function(manifest = inference_hierarchy_migration_manifest_as_list()) {
		sort(names(Filter(function(record) {
			identical(record$current_likelihood_tier, "partial") && !isTRUE(record$current_abstract)
		}, manifest)))
	}

	partial_likelihood_behavior_groups = function(class_names = EDI_PARTIAL_LIKELIHOOD_CLASS_NAMES) {
		targets = EDI_PARTIAL_LIKELIHOOD_TARGETS[class_names]
		missing_targets = setdiff(class_names, names(EDI_PARTIAL_LIKELIHOOD_TARGETS))
		if (length(missing_targets) > 0L) {
			stop(sprintf(
				"Partial-likelihood class(es) are missing target metadata: %s",
				paste(missing_targets, collapse = ", ")
			), call. = FALSE)
		}
		behaviors = sort(unique(unlist(lapply(targets, `[[`, "behavior"), use.names = FALSE)))
		stats::setNames(lapply(behaviors, function(behavior) {
			sort(names(Filter(function(target) behavior %in% target$behavior, targets)))
		}), behaviors)
	}

	partial_likelihood_component_family_groups = function(class_names = EDI_PARTIAL_LIKELIHOOD_CLASS_NAMES) {
		targets = EDI_PARTIAL_LIKELIHOOD_TARGETS[class_names]
		missing_targets = setdiff(class_names, names(EDI_PARTIAL_LIKELIHOOD_TARGETS))
		if (length(missing_targets) > 0L) {
			stop(sprintf(
				"Partial-likelihood class(es) are missing target metadata: %s",
				paste(missing_targets, collapse = ", ")
			), call. = FALSE)
		}
		component_families = sort(unique(vapply(targets, `[[`, character(1L), "component_family")))
		stats::setNames(lapply(component_families, function(component_family) {
			sort(names(Filter(function(target) identical(target$component_family, component_family), targets)))
		}), component_families)
	}

	build_partial_likelihood_behavior_record = function(name) {
		target = EDI_PARTIAL_LIKELIHOOD_TARGETS[[name]]
		if (is.null(target)) {
			stop(sprintf("%s is not a registered partial-likelihood migration target.", name), call. = FALSE)
		}
		metadata = get_inference_class_metadata(name)
		target_components = if (length(target$target_direct_components %||% character()) > 0L) {
			resolve_component_dependencies(target$target_direct_components)
		} else {
			character()
		}
		current_capabilities = get_effective_capabilities(name)
		target_capabilities = unique(as.character(unlist(lapply(target_components, function(component_name) {
			get_inference_component(component_name)$provides_capabilities
		}), use.names = FALSE)))
		has_null_simulator = "simulate_under_lik_null" %in% names(inference_private_owner_names(name))
		list(
			name = name,
			estimator_family = target$estimator_family,
			behavior = target$behavior,
			component_family = target$component_family,
			target_direct_components = target$target_direct_components %||% character(),
			target_components = target_components,
			current_parent = metadata$parent,
			current_effective_components = get_effective_components(name),
			current_effective_capabilities = current_capabilities,
			current_likelihood_tier = metadata$likelihood_tier,
			target_parent = "Inference",
			target_likelihood_tier = "partial",
			target_effective_capabilities = target_capabilities,
			provides_parametric_likelihood_bootstrap = "parametric_likelihood_bootstrap" %in% current_capabilities,
			target_provides_parametric_likelihood_bootstrap = "parametric_likelihood_bootstrap" %in% target_capabilities,
			has_null_simulator = has_null_simulator,
			notes = target$notes
		)
	}

	partial_likelihood_parametric_bootstrap_violations = function(manifest = partial_likelihood_behavior_manifest()) {
		records = Filter(function(record) {
			(isTRUE(record$provides_parametric_likelihood_bootstrap) ||
				isTRUE(record$target_provides_parametric_likelihood_bootstrap)) &&
				!isTRUE(record$has_null_simulator)
		}, manifest)
		if (length(records) == 0L) {
			return(data.frame(
				name = character(),
				current_provides_parametric_likelihood_bootstrap = logical(),
				target_provides_parametric_likelihood_bootstrap = logical(),
				has_null_simulator = logical(),
				stringsAsFactors = FALSE
			))
		}
		do.call(rbind, lapply(records, function(record) {
			data.frame(
				name = record$name,
				current_provides_parametric_likelihood_bootstrap = isTRUE(record$provides_parametric_likelihood_bootstrap),
				target_provides_parametric_likelihood_bootstrap = isTRUE(record$target_provides_parametric_likelihood_bootstrap),
				has_null_simulator = isTRUE(record$has_null_simulator),
				stringsAsFactors = FALSE
			)
		}))
	}

	partial_likelihood_behavior_manifest = function() {
		manifest_names = partial_likelihood_concrete_class_names()
		missing_targets = setdiff(manifest_names, names(EDI_PARTIAL_LIKELIHOOD_TARGETS))
		extra_targets = setdiff(names(EDI_PARTIAL_LIKELIHOOD_TARGETS), manifest_names)
		if (length(missing_targets) > 0L || length(extra_targets) > 0L) {
			stop(sprintf(
				"Partial-likelihood migration target mismatch. Missing target(s): %s. Extra target(s): %s.",
				paste(missing_targets, collapse = ", "),
				paste(extra_targets, collapse = ", ")
			), call. = FALSE)
		}
		stats::setNames(lapply(EDI_PARTIAL_LIKELIHOOD_CLASS_NAMES, build_partial_likelihood_behavior_record), EDI_PARTIAL_LIKELIHOOD_CLASS_NAMES)
	}

	partial_likelihood_behavior_counts = function(manifest = partial_likelihood_behavior_manifest()) {
		groups = partial_likelihood_behavior_groups(names(manifest))
		do.call(rbind, lapply(names(groups), function(behavior) {
			data.frame(
				behavior = behavior,
				class_count = length(groups[[behavior]]),
				stringsAsFactors = FALSE
			)
		}))
	}

	full_likelihood_concrete_class_names = function(manifest = inference_hierarchy_migration_manifest_as_list()) {
		sort(names(Filter(function(record) {
			identical(record$current_likelihood_tier, "full") && !isTRUE(record$current_abstract)
		}, manifest)))
	}

	full_likelihood_family = function(record) {
		response_types = record$current_response_types %||% character()
		if ("continuous" %in% response_types) {
			return("glm")
		}
		for (family in c("count", "ordinal", "incidence", "proportion", "survival")) {
			if (family %in% response_types) {
				return(family)
			}
		}
		"other"
	}

	full_likelihood_behavior_groups = function(class_names = full_likelihood_concrete_class_names()) {
		manifest = inference_hierarchy_migration_manifest_as_list()[class_names]
		missing_records = class_names[!vapply(manifest, Negate(is.null), logical(1L))]
		if (length(missing_records) > 0L) {
			stop(sprintf(
				"Full-likelihood class(es) are missing migration metadata: %s",
				paste(missing_records, collapse = ", ")
			), call. = FALSE)
		}
		groups = list(
			glm = character(),
			count = character(),
			ordinal = character(),
			incidence = character(),
			proportion = character(),
			survival = character(),
			kk_or_ivwc = character(),
			non_kk = character()
		)
		for (record in manifest) {
			family = full_likelihood_family(record)
			groups[[family]] = c(groups[[family]], record$name)
			if (is_kk_inference_migration_record(record)) {
				groups$kk_or_ivwc = c(groups$kk_or_ivwc, record$name)
			} else {
				groups$non_kk = c(groups$non_kk, record$name)
			}
		}
		lapply(groups, sort)
	}

	build_full_likelihood_behavior_record = function(name) {
		metadata = get_inference_class_metadata(name)
		if (!identical(metadata$likelihood_tier, "full") || isTRUE(metadata$abstract)) {
			stop(sprintf("%s is not a concrete full-likelihood inference class.", name), call. = FALSE)
		}
		migration_record = get_inference_hierarchy_migration_record(name)
		list(
			name = name,
			family = full_likelihood_family(migration_record),
			kk_status = if (is_kk_inference_migration_record(migration_record)) "KK_or_IVWC" else "non_KK",
			current_parent = metadata$parent,
			current_effective_components = get_effective_components(name),
			current_effective_capabilities = get_effective_capabilities(name),
			current_likelihood_tier = metadata$likelihood_tier,
			current_response_types = metadata$response_types,
			target_parent = "Inference",
			target_likelihood_tier = "full"
		)
	}

	full_likelihood_behavior_manifest = function() {
		class_names = full_likelihood_concrete_class_names()
		stats::setNames(lapply(class_names, build_full_likelihood_behavior_record), class_names)
	}

	full_likelihood_behavior_counts = function(manifest = full_likelihood_behavior_manifest()) {
		families = sort(unique(vapply(manifest, function(record) record$family, character(1L))))
		family_counts = do.call(rbind, lapply(families, function(family) {
			records = Filter(function(record) identical(record$family, family), manifest)
			data.frame(
				group = family,
				class_count = length(records),
				stringsAsFactors = FALSE
			)
		}))
		kk_counts = do.call(rbind, lapply(c("KK_or_IVWC", "non_KK"), function(kk_status) {
			records = Filter(function(record) identical(record$kk_status, kk_status), manifest)
			data.frame(
				group = kk_status,
				class_count = length(records),
				stringsAsFactors = FALSE
			)
		}))
		rbind(family_counts, kk_counts)
	}

	custom_randomization_direct_host_names = function(registry = inference_class_registry_as_list()) {
	direct_inference_rand_children = names(Filter(function(metadata) {
		identical(metadata$parent, "InferenceRand") && !isTRUE(metadata$abstract)
	}, registry))
	sort(direct_inference_rand_children)
}

custom_randomization_host_names = function() {
	sort(names(EDI_CUSTOM_RANDOMIZATION_TARGETS))
}

custom_randomization_host_groups = function(registry = inference_class_registry_as_list()) {
	direct_hosts = custom_randomization_direct_host_names(registry)
	missing_targets = setdiff(direct_hosts, names(EDI_CUSTOM_RANDOMIZATION_TARGETS))
	if (length(missing_targets) > 0L) {
		stop(sprintf(
			"Custom randomization host(s) are missing target metadata: %s",
			paste(missing_targets, collapse = ", ")
		), call. = FALSE)
	}
	hosts = custom_randomization_host_names()
	targets = EDI_CUSTOM_RANDOMIZATION_TARGETS[hosts]
	host_kinds = vapply(targets, function(target) target$host_kind %||% "concrete_package_estimator", character(1L))
	list(
		extension_bases = sort(hosts[host_kinds == "extension_base"]),
		concrete_package_estimators = sort(hosts[host_kinds == "concrete_package_estimator"])
	)
}

build_custom_randomization_behavior_record = function(name) {
	target = EDI_CUSTOM_RANDOMIZATION_TARGETS[[name]]
	if (is.null(target)) {
		stop(sprintf("%s is not a registered custom randomization host.", name), call. = FALSE)
	}
	metadata = get_inference_class_metadata(name)
	current_public_methods = inference_public_method_names(name)
	current_optional_methods = sort(unique(intersect(
		current_public_methods,
		inference_optional_method_names_for_capabilities(c(
			"randomization_test",
			"randomization_ci",
			"randomization_bootstrap",
			"nonparametric_bootstrap",
			"bayesian_bootstrap",
			"jackknife"
		))
	)))
	intentional_methods = inference_optional_method_names_for_capabilities(target$intentional_capabilities)
	list(
		name = name,
		host_kind = target$host_kind,
		current_parent = metadata$parent,
		target_parent = target$target_parent,
		target_components = target$target_components,
		class_owned_capabilities = target$class_owned_capabilities,
		intentional_capabilities = unique(c(target$intentional_capabilities, target$class_owned_capabilities)),
		migration_status = target$migration_status %||% "pending",
		migration_evidence = target$migration_evidence %||% character(),
		current_public_optional_methods = current_optional_methods,
		intentional_public_methods = intentional_methods,
		legacy_optional_surface = setdiff(current_optional_methods, intentional_methods),
		notes = target$notes
	)
}

custom_randomization_behavior_manifest = function() {
	hosts = custom_randomization_host_names()
	stats::setNames(lapply(hosts, build_custom_randomization_behavior_record), hosts)
}

mark_custom_randomization_classes_migrated = function(class_names = custom_randomization_host_names()) {
	required_evidence = c("method_snapshot", "golden_randomization")
	for (name in class_names) {
		target = EDI_CUSTOM_RANDOMIZATION_TARGETS[[name]]
		if (is.null(target)) {
			stop(sprintf("%s is not a registered custom randomization host.", name), call. = FALSE)
		}
		if (!identical(target$migration_status %||% "pending", "migrated")) next
		missing_evidence = setdiff(required_evidence, target$migration_evidence %||% character())
		if (length(missing_evidence) > 0L) {
			stop(sprintf(
				"%s cannot be marked migrated: missing custom-randomization migration evidence: %s",
				name,
				paste(missing_evidence, collapse = ", ")
			), call. = FALSE)
		}
		record = build_custom_randomization_behavior_record(name)
		if (length(record$legacy_optional_surface) > 0L) {
			stop(sprintf(
				"%s cannot be marked migrated: legacy optional public method(s) remain: %s",
				name,
				paste(record$legacy_optional_surface, collapse = ", ")
			), call. = FALSE)
		}
		mark_inference_class_migrated(
			name,
			public_method_names = record$current_public_optional_methods
		)
	}
	invisible(inference_hierarchy_migration_manifest_as_list()[class_names])
}

clear_inference_class_registry = function() {
	rm(list = ls(EDI_INFERENCE_CLASS_REGISTRY), envir = EDI_INFERENCE_CLASS_REGISTRY)
	clear_inference_effective_metadata_cache()
	invisible(TRUE)
}

populate_inference_class_registry = function(ns = environment(populate_inference_class_registry)) {
	clear_inference_class_registry()
	all_names = sort(ls(ns))
	for (name in all_names) {
		obj = get(name, envir = ns)
		if (!is_inference_r6_generator(obj)) next
		if (!identical(obj$classname, name)) next
		parent_gen = obj$get_inherit()
		parent_name = if (is.null(parent_gen)) NULL else parent_gen$classname
		register_inference_class(
			name = name,
			parent = parent_name,
			metadata = list(
				abstract = infer_inference_abstract(name),
				# NA sentinel: getNamespaceExports("EDI") is unreliable this early in the
				# sourcing sequence (see get_inference_class_metadata()'s note); resolved
				# lazily on read instead of computed here.
				exported = NA,
				response_types = infer_inference_response_types(name),
				design_families = "all",
				compatibility = always_compatible_inference_metadata,
				likelihood_tier = infer_inference_likelihood_tier(name),
				required_packages = character(),
				capabilities = character(),
				excluded_capabilities = EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES[[name]] %||% character(),
				supports_general_censoring = infer_inference_supports_general_censoring(obj),
				requires_blocking_design = infer_inference_requires_blocking_design(obj)
			),
			direct_components = infer_inference_direct_components(name)
		)
	}
	validate_inference_class_registry()
	populate_inference_hierarchy_migration_manifest()
	mark_custom_randomization_classes_migrated()
	mark_simple_estimator_classes_migrated()
	invisible(EDI_INFERENCE_CLASS_REGISTRY)
}

populate_inference_component_registry()
populate_inference_class_registry()
