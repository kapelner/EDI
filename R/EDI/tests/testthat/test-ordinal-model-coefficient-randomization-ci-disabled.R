library(testthat)
library(EDI)

test_that("ordinal model-coefficient estimands do not advertise generic randomization CIs", {
	classes <- EDI:::EDI_ORDINAL_MODEL_COEFFICIENT_INFERENCE_CLASSES

	expect_length(classes, 15L)
	expect_true(all(vapply(classes, EDI:::inference_is_ordinal_model_coefficient_class, logical(1))))

	for (class_name in classes) {
		metadata <- EDI:::get_inference_class_metadata(class_name)
		capabilities <- EDI:::get_effective_capabilities(class_name)

		expect_identical(metadata$response_types, "ordinal", info = class_name)
		expect_false("randomization_ci" %in% capabilities, info = class_name)
		expect_false("randomization_bootstrap_ci" %in% capabilities, info = class_name)
		expect_true(
			all(c("randomization_ci", "randomization_bootstrap_ci") %in%
				metadata$excluded_capabilities),
			info = class_name
		)

		# Only CI inversion is disabled. If the class composes either underlying
		# p-value capability, the registry must continue to advertise it.
		raw_capabilities <- unique(c(
			metadata$capabilities,
			unlist(lapply(EDI:::get_effective_components(class_name), function(component_name) {
				EDI:::get_inference_component(component_name)$provides_capabilities
			}), use.names = FALSE)
		))
		for (pvalue_capability in c("randomization_test", "randomization_bootstrap")) {
			if (pvalue_capability %in% raw_capabilities) {
				expect_true(pvalue_capability %in% capabilities, info = class_name)
			}
		}
	}
})

test_that("non-coefficient ordinal estimands are outside the CI disablement", {
	non_coefficient_classes <- c(
		"InferenceOrdinalGCompMeanDiff",
		"InferenceOrdinalJonckheereTerpstraTest",
		"InferenceOrdinalPairedSignTest",
		"InferenceOrdinalRidit"
	)

	expect_false(any(vapply(
		non_coefficient_classes,
		EDI:::inference_is_ordinal_model_coefficient_class,
		logical(1)
	)))
})
