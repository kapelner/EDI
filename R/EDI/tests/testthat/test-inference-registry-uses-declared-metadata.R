# The metadata and components a class gives define_inference_class() are the single source of
# truth for the inference class registry (2026-11-18). Before that, the registry took the
# likelihood tier from the class name (infer_inference_likelihood_tier()) and ignored the
# declaration, so a class could declare one tier and be registered with another:
# InferenceIncidKKCondLogitOneLik (declared "full", registered "partial"), InferenceContinKKOLSIVWC
# ("quasi" vs "full") and the two KK quantile-regression OneLik classes ("none" vs "full").

ns = asNamespace("EDI")
decl_of = get("inference_class_declaration", envir = ns)
reg = get("inference_class_registry_as_list", envir = ns)()
factory_classes = Filter(function(nm) !is.null(decl_of(get0(nm, envir = ns))), names(reg))

test_that("most registered inference classes are built with define_inference_class()", {
	expect_gt(length(factory_classes), 90L)
})

test_that("every declared metadata field is what the registry holds", {
	for (nm in factory_classes) {
		d = decl_of(get0(nm, envir = ns))
		md = d$metadata
		r = reg[[nm]]
		if (!is.null(md$likelihood_tier)) expect_identical(r$likelihood_tier, md$likelihood_tier, info = nm)
		if (!is.null(md$response_types)) expect_setequal(r$response_types, md$response_types)
		if (!is.null(md$capabilities)) expect_true(all(md$capabilities %in% r$capabilities), info = nm)
		if (!is.null(md$supports_additive_delta_shift)) {
			expect_identical(r$supports_additive_delta_shift, isTRUE(md$supports_additive_delta_shift), info = nm)
		}
		expect_identical(r$direct_components, d$components, info = nm)
	}
})

test_that("a declaration overrides the name rules", {
	tier = function(nm) reg[[nm]]$likelihood_tier
	# The name rules say "full" (OneLik / OLS tokens) and "partial" (CondLogit) for these.
	expect_identical(tier("InferenceContinKKQuantileRegrOneLik"), "none")
	expect_identical(tier("InferencePropKKQuantileRegrOneLik"), "none")
	expect_identical(tier("InferenceContinKKOLSIVWC"), "quasi")
	expect_identical(tier("InferenceIncidKKCondLogitOneLik"), "partial")
})

test_that("likelihood testing has one capability word, likelihood_tests", {
	caps = unique(unlist(lapply(reg, `[[`, "capabilities")))
	for (gone in c("likelihood_ratio", "estimating_equation_likelihood_ratio")) {
		expect_false(gone %in% names(EDI:::capability_requires), info = gone)
		expect_false(gone %in% names(EDI:::public_methods_for_capability), info = gone)
		expect_false(gone %in% caps, info = gone)
	}
	expect_identical(EDI:::capability_requires$parametric_likelihood_bootstrap$capabilities, "likelihood_tests")
})
