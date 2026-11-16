# Every likelihood-based inference class ("full" or "partial" likelihood tier)
# must declare whether its fitted objective is concave, i.e. whether every local
# optimum is global (EDI_INFERENCE_CLASSES_CONCAVE_LIKELIHOOD /
# EDI_INFERENCE_CLASSES_NONCONCAVE_LIKELIHOOD in R/inference_class_registry.R).
# A new likelihood class that is in neither list fails here. The fix is to trace
# its fit to the kernel it optimizes and add it to the right list, not to relax
# this test.

concave_registry_concrete = function() {
	reg = EDI:::inference_class_registry_as_list()
	Filter(function(r) !isTRUE(r$abstract), reg)
}

test_that("every full/partial likelihood class declares likelihood_concave", {
	reg = concave_registry_concrete()
	undeclared = vapply(Filter(function(r) r$likelihood_tier %in% c("full", "partial"), reg),
		function(r) if (is.na(r$likelihood_concave)) r$name else NA_character_, character(1))
	undeclared = undeclared[!is.na(undeclared)]
	expect(length(undeclared) == 0L, sprintf(
		"Likelihood classes with no likelihood_concave declaration: %s",
		paste(undeclared, collapse = ", ")
	))
})

test_that("no-likelihood classes leave likelihood_concave unset", {
	reg = concave_registry_concrete()
	declared = vapply(Filter(function(r) identical(r$likelihood_tier, "none"), reg),
		function(r) if (!is.na(r$likelihood_concave)) r$name else NA_character_, character(1))
	declared = declared[!is.na(declared)]
	expect(length(declared) == 0L, sprintf(
		"likelihood_tier = 'none' classes that declare likelihood_concave: %s",
		paste(declared, collapse = ", ")
	))
})

test_that("concave and nonconcave lists are disjoint and name real concrete classes", {
	concave = EDI:::EDI_INFERENCE_CLASSES_CONCAVE_LIKELIHOOD
	nonconcave = EDI:::EDI_INFERENCE_CLASSES_NONCONCAVE_LIKELIHOOD
	expect_identical(intersect(concave, nonconcave), character())
	expect_false(anyDuplicated(concave) > 0L)
	expect_false(anyDuplicated(nonconcave) > 0L)
	concrete_names = vapply(concave_registry_concrete(), function(r) r$name, character(1))
	expect_identical(setdiff(c(concave, nonconcave), concrete_names), character())
})

test_that("registry likelihood_concave matches the audited lists", {
	expect_true(EDI:::get_inference_class_metadata("InferenceIncidLogRegr")$likelihood_concave)
	expect_false(EDI:::get_inference_class_metadata("InferenceOrdinalStereotypeLogitRegr")$likelihood_concave)
	expect_true(is.na(EDI:::get_inference_class_metadata("InferenceIncidKKGEE")$likelihood_concave))
})

test_that("validator rejects a non-logical likelihood_concave", {
	expect_error(
		EDI:::validate_inference_class_metadata(utils::modifyList(
			EDI:::get_inference_class_metadata("InferenceIncidLogRegr"),
			list(likelihood_concave = "yes")
		)),
		"invalid `likelihood_concave`"
	)
})
