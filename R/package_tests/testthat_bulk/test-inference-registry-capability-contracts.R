library(testthat)
library(EDI)

test_that("inference registry exposes coherent metadata for representative families", {
	registry = EDI:::inference_class_registry_as_list()
	expect_true(length(registry) > 50L)
	expect_true(all(c("InferenceContinOLS", "InferenceAllSimpleAverageDiff", "InferenceCountPoissonKKGEE") %in% names(registry)))

	ols = EDI:::get_inference_class_metadata("InferenceContinOLS")
	expect_false(ols$abstract)
	expect_true("continuous" %in% ols$response_types)
	expect_true(is.character(ols$likelihood_tier))
	expect_true(is.logical(ols$exported))
	expect_error(EDI:::get_inference_class_metadata("DefinitelyMissingInference"), "No inference class metadata")

	expect_true(EDI:::is_inference_r6_generator(InferenceContinOLS))
	expect_false(EDI:::is_inference_r6_generator(list()))
	expect_identical(EDI:::infer_inference_response_types("InferencePropBetaRegr"), "proportion")
	expect_true(EDI:::infer_inference_requires_kk_matching_design("InferenceCountPoissonKKGEE"))
	expect_false(EDI:::infer_inference_requires_kk_matching_design("InferenceContinOLS"))
})

test_that("effective components and capabilities include inherited contracts", {
	direct = EDI:::get_direct_components("InferenceContinOLS")
	effective = EDI:::get_effective_components("InferenceContinOLS")
	expect_true(all(direct %in% effective))
	expect_true(length(effective) >= length(direct))
	caps = EDI:::get_effective_capabilities("InferenceContinOLS")
	expect_true(all(c("wald", "likelihood_tests", "nonparametric_bootstrap") %in% caps))

	avg_caps = EDI:::get_effective_capabilities("InferenceAllSimpleAverageDiff")
	expect_true("randomization_test" %in% avg_caps)
	expect_true("nonparametric_bootstrap" %in% avg_caps)
	expect_identical(EDI:::target_inference_parent("InferenceContinOLS"), "Inference")
	expect_true(is.character(EDI:::inference_class_ancestor_names("InferenceContinOLS")))
})

test_that("component dependency resolution is ordered and rejects unknown names", {
	resolved = EDI:::resolve_component_dependencies(c("KKGEE"))
	expect_true("KKGEE" %in% resolved)
	expect_true(all(EDI:::get_inference_component("KKGEE")$dependencies %in% resolved))
	expect_identical(resolved, unique(resolved))
	expect_error(EDI:::resolve_component_dependencies("NoSuchComponent"), "Unknown component")

	kk = EDI:::get_inference_component("KKPassThrough")
	gee = EDI:::get_inference_component("KKGEE")
	compound = EDI:::get_inference_component("KKCompound")
	expect_silent(EDI:::validate_inference_component(kk))
	expect_silent(EDI:::validate_inference_component(gee))
	expect_silent(EDI:::validate_inference_component(compound))
	expect_true("init_kk_passthrough" %in% EDI:::component_private_names(kk))
	expect_true("init_kk_gee_shared" %in% EDI:::component_private_names(gee))
	expect_true("compute_estimate_from_matched_and_reservoir" %in% EDI:::component_private_names(compound))
})

test_that("capability manifests map to real public methods", {
	ols_caps = EDI:::get_effective_capabilities("InferenceContinOLS")
	required = EDI:::public_methods_required_for_capabilities(ols_caps)
	public = EDI:::inference_public_method_names("InferenceContinOLS")
	expect_true(all(required %in% public))
	expect_silent(EDI:::validate_inference_public_optional_method_presence("InferenceContinOLS", ols_caps, public))

	record = EDI:::get_inference_hierarchy_migration_record("InferenceContinOLS")
	expect_identical(record$name, "InferenceContinOLS")
	expect_identical(record$migration_status, "migrated")
	expect_silent(EDI:::validate_inference_hierarchy_migration_record(record))

	summary = EDI:::inference_hierarchy_migration_summary()
	expect_true(is.list(summary))
	expect_true(length(summary) > 0L)
})

test_that("resampling contract manifest names match component cache vocabulary", {
	contracts = EDI:::EDI_RESAMPLING_DRAW_CONTRACTS
	expect_setequal(names(contracts), c(
		"rand", "non_param_boot", "m_out_of_n_boot", "subsampling",
		"rand_bootstrap", "bayesian_boot"
	))
	expect_true(all(vapply(contracts, function(x) is.character(x$loader) && length(x$loader) == 1L, logical(1))))
	expect_true(all(vapply(contracts, function(x) is.character(x$cache_name) && length(x$cache_name) == 1L, logical(1))))
	expect_identical(EDI:::resampling_draw_contract("rand_bootstrap")$draw_type, "row_sample_plus_assignment")
	expect_identical(EDI:::resampling_draw_contract("bayesian_boot")$draw_type, "weights_plus_context")
})
