library(testthat)
library(EDI)

mixin_slot_names = function(mixin_names, slot){
	as.character(unlist(lapply(mixin_names, function(mixin_name) {
		mixin = get(mixin_name, envir = asNamespace("EDI"))
		names(mixin[[slot]])
	}), use.names = FALSE))
}

edi_r_source_files = function() {
	files = Sys.glob(file.path("EDI", "R", "*.R"))
	if (length(files) == 0L) {
		files = Sys.glob(file.path("R", "*.R"))
	}
	files
}

canonical_component_names = function() {
	c(
		"RandomizationTest", "RandomizationCI", "NonparametricBootstrap",
		"RandomizationBootstrap", "RandomizationBootstrapCI",
		"BayesianBootstrap", "Jackknife", "Wald",
		"SimpleMeanDifference", "SimpleMeanDifferencePooledVar",
		"KKMeanDifferenceIVWC", "SimpleWilcox", "KKWilcoxIVWC", "KKNewcombeRiskDiffIVWC", "CountKKHurdlePoissonIVWC",
		"ContinKKRobustRegrIVWC", "ContinKKOLSIVWC", "ContinKKOLSOneLikLikelihood",
		"ContinKKRobustRegrOneLik", "SurvivalKKRankRegrIVWC",
		"BaiAdjustedT", "SurvivalKKStratCoxIVWC", "IncidKKCondLogitIVWC",
		"KKQuantileRegrIVWC", "KKQuantileRegrOneLik", "CountKKHurdlePoissonOneLikLikelihood",
		"CountKKCondPoissonOneLikLikelihood", "IncidKKCondLogitOneLikLikelihood",
		"IncidenceKKGComputation",
		"ExactTest", "ExactBinomialIncidence", "ExactFisherIncidence",
		"ExactZhangIncidence",
		"LikelihoodTests", "ParametricLikelihoodBootstrap", "StandardModelCache",
		"CoxPartialLikelihood", "StratifiedCoxPartialLikelihood",
		"ConditionalLogitPartialLikelihood", "OrdinalConditionalLogitPartialLikelihood",
		"KKLWACoxIVWCPartialLikelihood", "KKLWACoxOneLikPartialLikelihood",
		"SurvivalKKStratCoxOneLikPartialLikelihood",
		"KKSurvivalRankRegression",
			"CountLikelihoodPlumbing", "CountCompositeLikelihood",
			"ZeroAugmentedCountLikelihood",
			"OrdinalProportionalOddsLikelihood", "OrdinalAdjacentCategoryLikelihood",
			"OrdinalCloglogLikelihood", "OrdinalCauchitLikelihood",
			"OrdinalStereotypeLikelihood", "OrdinalContinuationRatioLikelihood",
			"OrdinalOrderedProbitLikelihood",
			"IncidenceLogisticLikelihood", "IncidenceProbitLikelihood",
			"IncidenceLogBinomialLikelihood", "IncidenceModifiedPoissonLikelihood",
			"IncidenceBinomialIdentityLikelihood", "IncidenceGComputation",
			"SurvivalWeibullLikelihood", "SurvivalDepCensTransform",
			"SurvivalKKWeibullMarginal", "SurvivalKKWeibullFrailtyLoggammaIVWC",
			"SurvivalKKWeibullFrailtyLoggammaOneLik", "SurvivalKKWeibullFrailtyNormalIVWC",
			"SurvivalKKWeibullFrailtyNormalOneLik",
			"SurvivalKKWeibullFrailtyNormalOneLikLeaf",
					"KKPassThrough", "KKCompound", "KKGEE",
		"RobustSandwich", "KKGLMM", "OffOptimumLikelihoodEval",
		"QuantileRandomizationCI", "BartlettApproximation", "MarginalEstimand"
	)
}

test_that("every mixin has a documented host contract and is collated after the registry", {
	contracts = EDI:::EDI_MIXIN_CONTRACTS
	mixin_names = ls(asNamespace("EDI"), pattern = "^InferenceMixin")
	expect_setequal(names(contracts), mixin_names)

	for (mixin_name in names(contracts)) {
		contract = contracts[[mixin_name]]
		expect_named(contract, c("file", "private_methods", "private_state"))
		expect_true(is.character(contract$file) && length(contract$file) == 1L)
		expect_true(is.character(contract$private_methods))
		expect_true(is.character(contract$private_state))
	}

	collate = strsplit(utils::packageDescription("EDI")$Collate, "[[:space:]]+")[[1L]]
	collate = gsub("'", "", collate, fixed = TRUE)
	registry_position = match("contracts_mixins.R", collate)
	expect_true(is.finite(registry_position))
	for (file in vapply(contracts, `[[`, character(1), "file")) {
		expect_gt(match(file, collate), registry_position)
	}
})

test_that("active behavior components are registered with canonical names", {
	EDI:::populate_inference_component_registry()
	components = EDI:::inference_component_registry_as_list()

	expect_setequal(names(components), canonical_component_names())
	expect_false(any(grepl("^InferenceMixin", names(components))))
	for (component_name in names(components)) {
		component = components[[component_name]]
		expect_silent(EDI:::validate_inference_component(component))
		expect_named(component, c(
			"name", "status", "source_name", "file", "public", "private",
			"component_loader", "dependencies", "provides_public_methods", "provides_private_methods",
			"owns_state", "requires_state", "requires_public_methods",
			"requires_private_methods", "optional_public_methods",
			"optional_private_methods", "requires_super_methods",
			"requires_capabilities", "provides_capabilities",
			"allowed_likelihood_tiers", "conflicts", "allowed_host_overrides",
			"forbidden_refs"
		))
		expect_true(component$status %in% c("active", "scaffold"))
		expect_true(is.list(component$public))
		expect_true(is.list(component$private))
		expect_true(is.character(component$owns_state))
		expect_true(is.character(component$requires_state))
		expect_true(is.character(component$requires_public_methods))
		expect_true(is.character(component$requires_private_methods))
		expect_true(is.character(component$optional_public_methods))
		expect_true(is.character(component$optional_private_methods))
		expect_true(is.character(component$dependencies))
		expect_true(is.character(component$requires_capabilities))
		expect_true(is.character(component$provides_capabilities))
		expect_true(is.character(component$conflicts))
		expect_true(all(component$allowed_likelihood_tiers %in% EDI:::EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS))
	}
	expect_identical(components$KKPassThrough$source_name, "InferenceMixinKKPassThrough")
	expect_identical(components$RandomizationTest$source_name, "InferenceRand")
	expect_identical(components$ExactTest$source_name, "ExactTestSource")
	expect_identical(components$ExactBinomialIncidence$source_name, "ExactBinomialIncidenceSource")
	expect_identical(components$ExactFisherIncidence$source_name, "ExactFisherIncidenceSource")
	expect_identical(components$ExactZhangIncidence$source_name, "ExactZhangIncidenceSource")
	expect_identical(components$RobustSandwich$source_name, "RobustSandwichSource")
	expect_identical(components$BartlettApproximation$source_name, "InferenceExtBartlettApprox")
	expect_identical(components$ParametricLikelihoodBootstrap$component_loader$load_policy, "lazy")
	expect_identical(components$BartlettApproximation$component_loader$load_policy, "lazy")
	expect_equal(length(components$ParametricLikelihoodBootstrap$public), 0L)
	expect_equal(length(components$BartlettApproximation$private), 0L)
	expect_equal(length(components$RandomizationTest$optional_private_methods), 0L)
})

test_that("lazy component private fields are declared as owned state", {
	specs = EDI:::EDI_COMPONENT_SPECS
	ns = asNamespace("EDI")
	for (component_name in names(specs)) {
		spec = specs[[component_name]]
		if (!identical(spec$load_policy, "lazy")) next
		source = get(spec$source_name, envir = ns, inherits = TRUE)
		private = EDI:::inference_component_source_parts(source)$private
		private_fields = as.character(names(private)[!vapply(private, is.function, logical(1L))])
		declared_state = if (is.null(spec$owns_state)) character() else spec$owns_state
		expect_setequal(declared_state, private_fields)
	}
})

test_that("every lazy component implementation matches its declared contract", {
	on.exit(EDI:::clear_inference_component_implementation_cache(), add = TRUE)
	EDI:::clear_inference_component_implementation_cache()
	components = EDI:::inference_component_registry_as_list()
	lazy_names = names(Filter(function(component) {
		identical(component$component_loader$load_policy, "lazy")
	}, components))
	errors = character()
	for (component_name in lazy_names) {
		tryCatch(
			EDI:::get_lazy_component_dispatch(component_name, class_name = "InferenceLazyContractProbe"),
			error = function(e) errors[[component_name]] <<- conditionMessage(e)
		)
	}
	expect_true(
		length(errors) == 0L,
		info = if (length(errors) == 0L) NULL else paste(names(errors), errors, sep = ": ", collapse = "\n")
	)
})

test_that("component provided method metadata matches actual list names", {
	EDI:::populate_inference_component_registry()
	components = EDI:::inference_component_registry_as_list()
	for (component in components) {
		expect_identical(
			sort(component$provides_public_methods),
			sort(EDI:::component_public_names(component))
		)
		expect_identical(
			sort(component$provides_private_methods),
			sort(EDI:::component_private_names(component))
		)
	}
})

test_that("exact-specific components provide names matching their source lists", {
	EDI:::populate_inference_component_registry()
	components = EDI:::inference_component_registry_as_list()
	for (component_name in c("ExactBinomialIncidence", "ExactFisherIncidence", "ExactZhangIncidence")) {
		component = components[[component_name]]
		expect_identical(
			sort(component$provides_public_methods),
			sort(EDI:::component_public_names(component))
		)
		expect_identical(
			sort(component$provides_private_methods),
			sort(EDI:::component_private_names(component))
		)
	}
})

test_that("scaffold components are forbidden from effective class components", {
	EDI:::populate_inference_component_registry()
	expect_silent(EDI:::validate_no_scaffold_effective_components())
	on.exit(EDI:::populate_inference_component_registry(), add = TRUE)
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "TemporaryScaffoldComponent",
		status = "scaffold",
		file = "test"
	))

	metadata = list(
		abstract = FALSE,
		exported = FALSE,
		response_types = "continuous",
		design_families = "all",
		compatibility = EDI:::always_compatible_inference_metadata,
		likelihood_tier = "none",
		required_packages = character()
	)
	on.exit(EDI:::populate_inference_class_registry(), add = TRUE)
	EDI:::register_inference_class(
		name = "InferenceTemporaryScaffoldComponentHost",
		parent = "Inference",
		metadata = metadata,
		direct_components = "TemporaryScaffoldComponent"
	)
	expect_error(
		EDI:::get_effective_components("InferenceTemporaryScaffoldComponentHost"),
		"Scaffold component"
	)
})

test_that("component body references are declared by component contracts", {
	EDI:::populate_inference_component_registry()
	components = EDI:::inference_component_registry_as_list()
	for (component in components) {
		expect_silent(EDI:::validate_component_body_references(component))
	}
})

test_that("expensive component contract completion is explicit", {
	old_option = getOption("EDI.validate_inference_contracts")
	on.exit(options(EDI.validate_inference_contracts = old_option), add = TRUE)
	on.exit(EDI:::populate_inference_component_registry(), add = TRUE)

	options(EDI.validate_inference_contracts = FALSE)
	EDI:::populate_inference_component_registry()
	cheap_component = EDI:::get_inference_component("RandomizationTest")
	expect_equal(length(cheap_component$optional_private_methods), 0L)
	expect_silent(EDI:::validate_component_body_references(cheap_component))

	options(EDI.validate_inference_contracts = TRUE)
	EDI:::populate_inference_component_registry()
	completed_component = EDI:::get_inference_component("RandomizationTest")
	expect_gt(length(completed_component$optional_private_methods), 0L)
	expect_silent(EDI:::validate_component_body_references(completed_component))
})

test_that("exact-specific component body references are declared by their contracts", {
	EDI:::populate_inference_component_registry()
	components = EDI:::inference_component_registry_as_list()
	for (component_name in c("ExactBinomialIncidence", "ExactFisherIncidence", "ExactZhangIncidence")) {
		expect_silent(EDI:::validate_component_body_references(components[[component_name]]))
	}
})

test_that("mixin composition has no undocumented method-name collisions", {
	for (target in names(EDI:::EDI_MIXIN_COMPOSITIONS)) {
		mixins = EDI:::EDI_MIXIN_COMPOSITIONS[[target]]
		allowed = EDI:::EDI_MIXIN_ALLOWED_COLLISIONS[[target]]
		if (is.null(allowed)) allowed = list(public = character(), private = character())
		for (slot in c("public", "private")) {
			methods = mixin_slot_names(mixins, slot)
			collisions = sort(unique(methods[duplicated(methods)]))
			expect_setequal(collisions, allowed[[slot]])
		}
	}
})

test_that("mixin composition declares dependencies and intended overrides", {
	expect_silent(EDI:::assert_valid_mixin_composition(
		target_name = "InferenceKKPassThroughCompound",
		mixin_names = EDI:::EDI_MIXIN_COMPOSITIONS$InferenceKKPassThroughCompound,
		public_overrides = c(
			"approximate_bootstrap_distribution_beta_hat_T",
			"compute_estimate_with_bootstrap_weights"
		)
	))
	expect_silent(EDI:::assert_valid_mixin_composition(
		target_name = "InferenceKKPassThroughCompoundNoParamBootstrap",
		mixin_names = EDI:::EDI_MIXIN_COMPOSITIONS$InferenceKKPassThroughCompoundNoParamBootstrap,
		public_overrides = c(
			"approximate_bootstrap_distribution_beta_hat_T",
			"compute_estimate_with_bootstrap_weights"
		)
	))
	expect_error(
		EDI:::assert_valid_mixin_composition(
			target_name = "BadCompound",
			mixin_names = c("InferenceMixinKKPassThrough", "InferenceMixinKKPassThrough")
		),
		"duplicate mixin"
	)
	expect_error(
		EDI:::assert_valid_mixin_composition(
			target_name = "BadCompound",
			mixin_names = "InferenceMixinKKPassThroughCompound"
		),
		"without required component"
	)
	expect_error(
		EDI:::assert_valid_mixin_composition(
			target_name = "BadCompound",
			mixin_names = c("InferenceMixinKKPassThrough", "InferenceMixinKKPassThroughCompound")
		),
		"undeclared private mixin collision"
	)
	expect_error(
		EDI:::assert_valid_mixin_composition(
			target_name = "BadCompound",
			mixin_names = "InferenceMixinKKPassThrough",
			public_overrides = "approximate_bootstrap_distribution_beta_hat_T"
		),
		"without declaration"
	)
})

test_that("define_inference_class assembles component public and private members", {
	on.exit(EDI:::populate_inference_component_registry(), add = TRUE)
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "InferenceTemporaryFactoryComponent",
		status = "active",
		file = "test",
		public = list(
			component_public = function() private$component_private()
		),
		private = list(
			component_state = "assembled",
			component_private = function() private$component_state
		),
		owns_state = "component_state",
		provides_capabilities = "temporary_factory_capability"
	))
	gen = EDI:::define_inference_class(
		classname = "InferenceTemporaryFactoryHost",
		components = "InferenceTemporaryFactoryComponent",
		public = list(
			host_public = function() "host"
		),
		private = list(
			host_private = function() "private"
		),
		metadata = list(
			likelihood_tier = "none"
		)
	)
	obj = gen$new()

	expect_false(gen$lock_objects)
	expect_identical(obj$component_public(), "assembled")
	expect_identical(obj$host_public(), "host")
	expect_true("component_public" %in% names(gen$public_methods))
	expect_true("component_private" %in% names(gen$private_methods))
})

test_that("factory NULL state survives assembly, locked subclasses, and duplicate cache reset", {
	gen = EDI:::define_inference_class(
		classname = "InferenceTemporaryNullStateHost",
		inherit = EDI:::Inference,
		public = list(
			initialize = function(config) {
				private$config = config
				private$cached_values$config = config
			},
			persistent_config = function() private$config,
			cached_config = function() private$cached_values$config
		),
		private = list(config = NULL),
		metadata = list(likelihood_tier = "none")
	)
	locked_child = R6::R6Class(
		"InferenceTemporaryNullStateLockedChild",
		inherit = gen
	)

	obj = locked_child$new(config = 0.75)
	expect_identical(obj$persistent_config(), 0.75)
	expect_identical(obj$cached_config(), 0.75)

	worker = obj$duplicate()
	expect_identical(worker$persistent_config(), 0.75)
	expect_null(worker$cached_config())
})

test_that("lazy components preserve method presence and load on first use", {
	on.exit(EDI:::populate_inference_component_registry(), add = TRUE)
	on.exit(EDI:::clear_inference_component_implementation_cache(), add = TRUE)
	source_file = tempfile(fileext = ".R")
	writeLines(c(
		"TemporaryLazySource = list(",
		"  public = list(",
		"    lazy_public = function(x = 'ok') private$lazy_private(x),",
		"    diagnostic_public = function() private$lazy_state",
		"  ),",
		"  private = list(",
		"    lazy_state = 'loaded',",
		"    lazy_private = function(x) paste(private$lazy_state, x)",
		"  )",
		")"
	), source_file)

	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "TemporaryLazyComponent",
		status = "active",
		source_name = "TemporaryLazySource",
		file = source_file,
		component_loader = list(load_policy = "lazy"),
		provides_public_methods = c("lazy_public", "diagnostic_public"),
		provides_private_methods = c("lazy_state", "lazy_private"),
		owns_state = "lazy_state",
		provides_capabilities = "temporary_lazy_capability"
	))
	gen = EDI:::define_inference_class(
		classname = "InferenceTemporaryLazyHost",
		components = "TemporaryLazyComponent",
		metadata = list(likelihood_tier = "none")
	)
	obj = gen$new()

	expect_true("lazy_public" %in% names(gen$public_methods))
	expect_true("diagnostic_public" %in% names(gen$public_methods))
	expect_false("unsupported_lazy_public" %in% names(gen$public_methods))
	expect_identical(EDI:::inference_component_load_trace("InferenceTemporaryLazyHost"), character())
	expect_identical(obj$lazy_public("first"), "loaded first")
	expect_identical(obj$diagnostic_public(), "loaded")
	dispatch_cache = EDI:::get_inference_component_dispatch_cache_env("InferenceTemporaryLazyHost")
	expect_true(exists("TemporaryLazyComponent", envir = dispatch_cache, inherits = FALSE))
	dispatch = get("TemporaryLazyComponent", envir = dispatch_cache, inherits = FALSE)
	expect_true("lazy_public" %in% names(dispatch$public))
	expect_true("lazy_private" %in% names(dispatch$private))
	expect_true("TemporaryLazyComponent" %in% obj$.__enclos_env__$private$.__loaded_lazy_components)
	expect_identical(
		EDI:::inference_component_load_trace("InferenceTemporaryLazyHost"),
		"TemporaryLazyComponent"
	)
	expect_identical(obj$lazy_public("second"), "loaded second")
	obj2 = gen$new()
	expect_identical(obj2$lazy_public("third"), "loaded third")
	expect_identical(names(get("TemporaryLazyComponent", envir = dispatch_cache, inherits = FALSE)$public), names(dispatch$public))
	expect_identical(
		EDI:::inference_component_load_trace("InferenceTemporaryLazyHost"),
		"TemporaryLazyComponent"
	)
})

test_that("parametric likelihood bootstrap metadata is lazy until a stub or loader is used", {
	on.exit(EDI:::clear_inference_component_implementation_cache(), add = TRUE)
	EDI:::clear_inference_component_implementation_cache()
	component = EDI:::get_inference_component("ParametricLikelihoodBootstrap")

	expect_identical(component$component_loader$load_policy, "lazy")
	expect_equal(length(component$public), 0L)
	expect_true("compute_lik_ratio_bootstrap_two_sided_pval" %in% EDI:::component_public_names(component))
	expect_true("parametric_likelihood_bootstrap" %in% EDI:::get_effective_capabilities("InferenceParamBootstrap"))
	expect_identical(EDI:::inference_component_load_trace("InferenceParamBootstrap"), character())

	loaded = EDI:::load_inference_component("ParametricLikelihoodBootstrap", class_name = "InferenceParamBootstrap")
	expect_true("compute_lik_ratio_bootstrap_two_sided_pval" %in% names(loaded$public))
	expect_identical(
		EDI:::inference_component_load_trace("InferenceParamBootstrap"),
		c("Jackknife", "Wald", "LikelihoodTests", "ParametricLikelihoodBootstrap")
	)
	again = EDI:::load_inference_component("ParametricLikelihoodBootstrap", class_name = "InferenceParamBootstrap")
	expect_identical(names(again$public), names(loaded$public))
	expect_identical(
		EDI:::inference_component_load_trace("InferenceParamBootstrap"),
		c("Jackknife", "Wald", "LikelihoodTests", "ParametricLikelihoodBootstrap")
	)
})

test_that("lazy component dependency cycles fail before implementation load", {
	on.exit(EDI:::populate_inference_component_registry(), add = TRUE)
	on.exit(EDI:::clear_inference_component_implementation_cache(), add = TRUE)
	source_file = tempfile(fileext = ".R")
	writeLines("CycleSource = list(public = list(), private = list())", source_file)
	for (spec in list(
		list(name = "TemporaryLazyCycleA", dependencies = "TemporaryLazyCycleB"),
		list(name = "TemporaryLazyCycleB", dependencies = "TemporaryLazyCycleA")
	)) {
		EDI:::register_inference_component(EDI:::InferenceComponent(
			name = spec$name,
			status = "active",
			source_name = "CycleSource",
			file = source_file,
			component_loader = list(load_policy = "lazy"),
			dependencies = spec$dependencies,
			provides_public_methods = character(),
			provides_private_methods = character()
		))
	}

	expect_error(
		EDI:::load_inference_component("TemporaryLazyCycleA", class_name = "CycleHost"),
		"Component dependency cycle detected"
	)
	expect_identical(EDI:::inference_component_load_trace("CycleHost"), character())
})

test_that("lazy component dependencies load in resolved topological order", {
	on.exit(EDI:::populate_inference_component_registry(), add = TRUE)
	on.exit(EDI:::clear_inference_component_implementation_cache(), add = TRUE)
	specs = list(
		list(name = "TemporaryLazyTopoLeaf", method = "leaf_public", dependencies = character()),
		list(name = "TemporaryLazyTopoMiddle", method = "middle_public", dependencies = "TemporaryLazyTopoLeaf"),
		list(name = "TemporaryLazyTopoRoot", method = "root_public", dependencies = "TemporaryLazyTopoMiddle")
	)
	for (spec in specs) {
		source_file = tempfile(fileext = ".R")
		writeLines(sprintf(
			"TopoSource = list(public = list(%s = function() '%s'), private = list())",
			spec$method,
			spec$name
		), source_file)
		EDI:::register_inference_component(EDI:::InferenceComponent(
			name = spec$name,
			status = "active",
			source_name = "TopoSource",
			file = source_file,
			component_loader = list(load_policy = "lazy"),
			dependencies = spec$dependencies,
			provides_public_methods = spec$method,
			provides_private_methods = character()
		))
	}

	loaded = EDI:::load_inference_component("TemporaryLazyTopoRoot", class_name = "TopoHost")

	expect_true("root_public" %in% names(loaded$public))
	expect_identical(
		EDI:::inference_component_load_trace("TopoHost"),
		c("TemporaryLazyTopoLeaf", "TemporaryLazyTopoMiddle", "TemporaryLazyTopoRoot")
	)
})

test_that("lazy loader reports deterministic source, package, object, and contract failures", {
	on.exit(EDI:::populate_inference_component_registry(), add = TRUE)
	on.exit(EDI:::clear_inference_component_implementation_cache(), add = TRUE)
	missing_file = tempfile(fileext = ".R")
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "TemporaryLazyMissingFile",
		status = "active",
		source_name = "MissingSource",
		file = missing_file,
		component_loader = list(load_policy = "lazy"),
		provides_public_methods = "x",
		provides_private_methods = character()
	))
	expect_error(
		EDI:::load_inference_component("TemporaryLazyMissingFile", class_name = "LoaderErrorHost"),
		"source file"
	)

	optional_file = tempfile(fileext = ".R")
	writeLines("OptionalSource = list(public = list(x = function() TRUE), private = list())", optional_file)
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "TemporaryLazyMissingPackage",
		status = "active",
		source_name = "OptionalSource",
		file = optional_file,
		component_loader = list(
			load_policy = "lazy",
			optional_packages = "EDIDefinitelyMissingPackageForLazyTest"
		),
		provides_public_methods = "x",
		provides_private_methods = character()
	))
	expect_true("TemporaryLazyMissingPackage" %in% ls(EDI:::EDI_INFERENCE_COMPONENTS))
	expect_error(
		EDI:::load_inference_component("TemporaryLazyMissingPackage", class_name = "LoaderErrorHost"),
		"optional package"
	)
	expect_true(exists(
		"EDIDefinitelyMissingPackageForLazyTest",
		envir = EDI:::EDI_OPTIONAL_PACKAGE_AVAILABILITY_CACHE,
		inherits = FALSE
	))
	expect_false(EDI:::optional_package_available("EDIDefinitelyMissingPackageForLazyTest"))

	invalid_file = tempfile(fileext = ".R")
	writeLines("InvalidSource = 1", invalid_file)
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "TemporaryLazyInvalidObject",
		status = "active",
		source_name = "InvalidSource",
		file = invalid_file,
		component_loader = list(load_policy = "lazy"),
		provides_public_methods = "x",
		provides_private_methods = character()
	))
	expect_error(
		EDI:::load_inference_component("TemporaryLazyInvalidObject", class_name = "LoaderErrorHost"),
		"source must be an R6 generator or public/private list"
	)

	mismatch_file = tempfile(fileext = ".R")
	writeLines("MismatchSource = list(public = list(y = function() TRUE), private = list())", mismatch_file)
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "TemporaryLazyContractMismatch",
		status = "active",
		source_name = "MismatchSource",
		file = mismatch_file,
		component_loader = list(load_policy = "lazy"),
		provides_public_methods = "x",
		provides_private_methods = character()
	))
	expect_error(
		EDI:::load_inference_component("TemporaryLazyContractMismatch", class_name = "LoaderErrorHost"),
		"public method contract mismatch"
	)
})

test_that("factory validation rejects unsatisfied component contracts", {
	on.exit(EDI:::populate_inference_component_registry(), add = TRUE)
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "InferenceTemporaryNeedsHostContract",
		status = "active",
		file = "test",
		requires_public_methods = "needed_public",
		requires_private_methods = "needed_private",
		requires_state = "needed_state"
	))

	expect_error(
		EDI:::define_inference_class(
			classname = "InferenceTemporaryMissingPublic",
			components = "InferenceTemporaryNeedsHostContract",
			private = list(
				needed_private = function() TRUE,
				needed_state = TRUE
			)
		),
		"missing public method"
	)
	expect_error(
		EDI:::define_inference_class(
			classname = "InferenceTemporaryMissingPrivate",
			components = "InferenceTemporaryNeedsHostContract",
			public = list(needed_public = function() TRUE),
			private = list(needed_state = TRUE)
		),
		"missing private method"
	)
	expect_error(
		EDI:::define_inference_class(
			classname = "InferenceTemporaryMissingState",
			components = "InferenceTemporaryNeedsHostContract",
			public = list(needed_public = function() TRUE),
			private = list(needed_private = function() TRUE)
		),
		"missing private state"
	)
	expect_silent(EDI:::define_inference_class(
		classname = "InferenceTemporarySatisfiedContract",
		components = "InferenceTemporaryNeedsHostContract",
		public = list(needed_public = function() TRUE),
		private = list(
			needed_private = function() TRUE,
			needed_state = TRUE
		)
	))
})

test_that("factory validation enforces likelihood tiers and capabilities", {
	on.exit(EDI:::populate_inference_component_registry(), add = TRUE)
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "InferenceTemporaryProviderCapability",
		status = "active",
		file = "test",
		provides_capabilities = "temporary_needed_capability"
	))
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "InferenceTemporaryNeedsCapability",
		status = "active",
		file = "test",
		requires_capabilities = "temporary_needed_capability"
	))

	expect_error(
		EDI:::define_inference_class(
			classname = "InferenceTemporaryWrongTier",
			components = "OffOptimumLikelihoodEval",
			metadata = list(likelihood_tier = "none")
		),
		"disallowed likelihood tier"
	)
	expect_error(
		EDI:::define_inference_class(
			classname = "InferenceTemporaryMissingCapability",
			components = "InferenceTemporaryNeedsCapability"
		),
		"missing capability"
	)
	expect_silent(EDI:::define_inference_class(
		classname = "InferenceTemporarySatisfiedCapability",
		components = c("InferenceTemporaryProviderCapability", "InferenceTemporaryNeedsCapability")
	))
	expect_error(
		EDI:::define_inference_class(
			classname = "InferenceTemporaryCapabilityMissingMethod",
			components = "InferenceTemporaryProviderCapability",
			public_methods_for_capability = list(
				temporary_needed_capability = "capability_public_method"
			)
		),
		"without public method"
	)
	expect_silent(EDI:::define_inference_class(
		classname = "InferenceTemporaryCapabilityHasMethod",
		components = "InferenceTemporaryProviderCapability",
		public = list(capability_public_method = function() TRUE),
		public_methods_for_capability = list(
			temporary_needed_capability = "capability_public_method"
		)
	))
})

test_that("factory validation rejects collisions unless overrides declare them", {
	on.exit(EDI:::populate_inference_component_registry(), add = TRUE)
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "InferenceTemporaryCollisionA",
		status = "active",
		file = "test",
		public = list(dup_public = function() "a"),
		private = list(dup_private = function() "a")
	))
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "InferenceTemporaryCollisionB",
		status = "active",
		file = "test",
		public = list(dup_public = function() "b"),
		private = list(dup_private = function() "b")
	))
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "InferenceTemporaryStateCollision",
		status = "active",
		file = "test",
		private = list(dup_private = "state")
	))

	expect_error(
		EDI:::assemble_public(
			"BadCollisionHost",
			c("InferenceTemporaryCollisionA", "InferenceTemporaryCollisionB"),
			resolve = FALSE
		),
		"undeclared public component collision"
	)
	expect_silent(EDI:::assemble_public(
		"DeclaredCollisionHost",
		c("InferenceTemporaryCollisionA", "InferenceTemporaryCollisionB"),
		overrides = list(public = "dup_public"),
		resolve = FALSE
	))
	expect_error(
		EDI:::assemble_private(
			"BadStateCollisionHost",
			c("InferenceTemporaryCollisionA", "InferenceTemporaryStateCollision"),
			resolve = FALSE
		),
		"method/state collision"
	)
	expect_error(
		EDI:::define_inference_class(
			classname = "InferenceTemporaryPublicPrivateDup",
			public = list(same_name = function() TRUE),
			private = list(same_name = function() TRUE)
		),
		"public/private name duplication"
	)
	expect_silent(EDI:::validate_inference_class_definition(
		classname = "InferenceTemporaryDeclaredPublicPrivateDup",
		public = list(same_name = function() TRUE),
		private = list(same_name = function() TRUE),
		overrides = list(public_private = "same_name")
	))
	expect_error(
		EDI:::define_inference_class(
			classname = "InferenceTemporaryLocked",
			lock_objects = TRUE
		),
		"lock_objects = FALSE"
	)
})

test_that("compound descendants do not re-splice KK pass-through mixins", {
	files = edi_r_source_files()
	records = list()
	for (file in files) {
		lines = readLines(file, warn = FALSE)
		starts = grep("R6::R6Class", lines, fixed = TRUE)
		for (i in seq_along(starts)) {
			start = starts[[i]]
			end = if (i < length(starts)) starts[[i + 1L]] - 1L else length(lines)
			block = paste(lines[start:end], collapse = "\n")
			class_name = sub(".*R6Class\\(\"([^\"]+)\".*", "\\1", lines[[start]])
			inherit_line = grep("inherit =", lines[start:end], value = TRUE)[1L]
			inherit_name = if (length(inherit_line) == 0L || is.na(inherit_line)) {
				NA_character_
			} else {
				sub(".*inherit = ([A-Za-z0-9_]+).*", "\\1", inherit_line)
			}
			records[[class_name]] = list(
				file = basename(file),
				inherit = inherit_name,
				splices_pass_through =
					grepl("public = .*InferenceMixinKKPassThrough\\$public", block) ||
					grepl("private = .*InferenceMixinKKPassThrough\\$private", block)
			)
		}
	}
	inherits_compound_base = function(class_name) {
		seen = character()
		while (!is.na(class_name) && !(class_name %in% seen)) {
			if (class_name %in% c("InferenceKKPassThroughCompound", "InferenceKKPassThroughCompoundNoParamBootstrap")) {
				return(TRUE)
			}
			seen = c(seen, class_name)
			class_name = records[[class_name]]$inherit
			if (is.null(class_name)) return(FALSE)
		}
		FALSE
	}
	offenders = names(records)[vapply(names(records), function(class_name) {
		isTRUE(records[[class_name]]$splices_pass_through) && inherits_compound_base(class_name)
	}, logical(1L))]
	if (is.null(offenders)) offenders = character()
	expect_equal(offenders, character())
})

test_that("R6 generator private lists are not accessed from generator objects", {
	files = edi_r_source_files()
	generator_names = character()
	source_lines = list()
	for (file in files) {
		lines = readLines(file, warn = FALSE)
		source_lines[[file]] = lines
		generator_lines = grep("R6::R6Class", lines, fixed = TRUE, value = TRUE)
		generator_names = c(
			generator_names,
			sub("^\\s*([A-Za-z][A-Za-z0-9_.]*)\\s*(=|<-).*", "\\1", generator_lines)
		)
	}
	generator_names = sort(unique(generator_names))
	offenders = character()
	for (file in names(source_lines)) {
		lines = source_lines[[file]]
		code_lines = ifelse(grepl("^\\s*#", lines), "", lines)
		for (generator_name in generator_names) {
			pattern = paste0("(^|[^A-Za-z0-9_.])", generator_name, "\\$private([^A-Za-z0-9_]|$)")
			hits = grep(pattern, code_lines)
			if (length(hits) > 0L) {
				offenders = c(
					offenders,
					paste0(basename(file), ":", hits, ": ", trimws(lines[hits]))
				)
			}
		}
	}
	expect_equal(offenders, character())
})

test_that("KK OLS IVWC's bootstrap-weight estimator matches the migrated architecture", {
	# Pre-migration (fix_inference_hierarchy.md, "KK And IVWC Estimators"),
	# InferenceContinKKOLSIVWC inherited compute_estimate_with_bootstrap_weights
	# purely via the R6 ladder from InferenceKKPassThroughCompoundNoParamBootstrap
	# (whose own version -- inference_kk_passthrough_compound_components$public,
	# built ad hoc in inference_all_abstract_KK_passthrough_compound.R and never
	# registered as a reusable component -- differs from
	# InferenceMixinKKPassThrough's raw passthrough), so $public_methods was NULL
	# on the class itself. Post-migration (2026-08-18),
	# define_inference_class() flattens every resolved method directly onto the
	# generator, so this is never NULL for a composed class; the migrated
	# InferenceContinKKOLSIVWC composes only the registered "KKCompound"/
	# "KKPassThrough" components, neither of which carries that ad hoc compound
	# override, so it resolves to KKPassThrough's raw passthrough instead.
	# This is not a behavior regression: neither InferenceContinKKOLSIVWC nor
	# InferenceContinKKRobustRegrIVWC ever defines private$compute_weighted_
	# estimate_ivwc, so the legacy compound override's own body always fell
	# through to its generic "weighted matched-diff mean" fallback branch --
	# mathematically the same surrogate KKPassThrough's passthrough computes --
	# confirmed bit-identical by the bootstrap_ci/bootstrap_pval/bootstrap_distr
	# labels in test-contin-kk-ols-ivwc-migration-golden.R and
	# test-contin-kk-robust-regr-ivwc-migration-golden.R (both of which do
	# exercise this method: InferenceAsymp's supports_reusable_bootstrap_worker()
	# default is TRUE and neither class overrides it).
	fn = EDI:::InferenceContinKKOLSIVWC$public_methods$compute_estimate_with_bootstrap_weights
	expect_true(is.function(fn))
	expect_identical(
		body(fn),
		body(EDI:::InferenceMixinKKPassThrough$public$compute_estimate_with_bootstrap_weights)
	)
})

test_that("single-host protected bases are not decomposed into new mixins", {
	expect_false("InferenceCountZeroAugmentedPoissonAbstract" %in% names(EDI:::EDI_MIXIN_COMPOSITIONS))
	expect_false("InferenceMixinHurdlePoissonClosedForm" %in% names(EDI:::EDI_MIXIN_CONTRACTS))
	expect_false(exists("InferenceMixinHurdlePoissonClosedForm", envir = asNamespace("EDI"), inherits = FALSE))
})
