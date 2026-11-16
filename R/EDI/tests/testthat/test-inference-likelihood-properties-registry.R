# Static checks on the audited likelihood properties in R/inference_class_registry.R
# (EDI_INFERENCE_LIKELIHOOD_PROPERTIES): mle_nonexistence, boundary_parameters,
# parameter_layout, derivatives and nonregular_points. A new "full" or "partial"
# likelihood class with no entry fails here. The fix is to audit the class and add
# its entry, not to relax this test. The live-fit check of the layouts is in
# test-inference-likelihood-parameter-layout-live-fits.R.

lik_prop_concrete = function() {
	Filter(function(r) !isTRUE(r$abstract), EDI:::inference_class_registry_as_list())
}

test_that("every full/partial likelihood class has a likelihood-properties entry", {
	props = EDI:::EDI_INFERENCE_LIKELIHOOD_PROPERTIES
	lik_names = vapply(Filter(function(r) r$likelihood_tier %in% c("full", "partial"), lik_prop_concrete()),
		function(r) r$name, character(1))
	missing = setdiff(lik_names, names(props))
	expect(length(missing) == 0L, sprintf(
		"Likelihood classes with no EDI_INFERENCE_LIKELIHOOD_PROPERTIES entry: %s",
		paste(missing, collapse = ", ")
	))
	concrete_names = vapply(lik_prop_concrete(), function(r) r$name, character(1))
	expect_identical(setdiff(names(props), concrete_names), character())
	expect_false(anyDuplicated(names(props)) > 0L)
})

test_that("registry records carry the audited properties", {
	for (nm in names(EDI:::EDI_INFERENCE_LIKELIHOOD_PROPERTIES)) {
		rec = EDI:::get_inference_class_metadata(nm)
		expected = EDI:::EDI_INFERENCE_LIKELIHOOD_PROPERTIES[[nm]]
		for (field in names(expected)) {
			expect_identical(rec[[field]], expected[[field]], info = paste(nm, field))
		}
	}
	none = Filter(function(r) identical(r$likelihood_tier, "none"), lik_prop_concrete())
	for (r in none) {
		expect_true(is.null(r$parameter_layout), info = r$name)
		expect_identical(r$mle_nonexistence, NA_character_, info = r$name)
	}
})

test_that("boundary and nonexistence declarations agree with concavity and kernels", {
	props = EDI:::EDI_INFERENCE_LIKELIHOOD_PROPERTIES
	# A random-effect or copula boundary only arises in a nonconcave likelihood.
	for (nm in names(props)) {
		b = props[[nm]]$boundary_parameters
		if (any(c("random_effect_variance", "copula_dependence", "correlation", "dispersion_poisson_limit") %in% b)) {
			expect_false(EDI:::get_inference_class_metadata(nm)$likelihood_concave, info = nm)
		}
	}
	# A class whose layout has a log-scale variance component must declare the boundary.
	for (nm in names(props)) {
		lay = props[[nm]]$parameter_layout
		if (is.null(lay)) next
		blk_names = vapply(lay$blocks, `[[`, character(1), "name")
		if (any(blk_names %in% c("log_sigma_b", "log_sigma_u")) ||
				(any(blk_names == "log_sigma") && grepl("GLMM|Hurdle", nm) && !grepl("Weibull", nm))) {
			expect_true("random_effect_variance" %in% props[[nm]]$boundary_parameters, info = nm)
		}
	}
})

test_that("layouts and derivatives are declared together", {
	for (nm in names(EDI:::EDI_INFERENCE_LIKELIHOOD_PROPERTIES)) {
		p = EDI:::EDI_INFERENCE_LIKELIHOOD_PROPERTIES[[nm]]
		expect_identical(is.null(p$parameter_layout), is.null(p$derivatives), info = nm)
	}
})

test_that("validator rejects malformed likelihood properties", {
	base = EDI:::get_inference_class_metadata("InferenceIncidLogRegr")
	# Replace fields wholesale; utils::modifyList() would merge nested layouts.
	bad = function(...) { rec = base; vals = list(...); rec[names(vals)] = vals; EDI:::validate_inference_class_metadata(rec) }
	expect_error(bad(mle_nonexistence = "infinite"), "invalid `mle_nonexistence`")
	expect_error(bad(boundary_parameters = "sigma"), "invalid `boundary_parameters`")
	expect_error(bad(derivatives = c(score = "exact", information = "analytic")), "invalid `derivatives`")
	expect_error(bad(parameter_layout = list(blocks = list(), treatment_index = "2")), "invalid `parameter_layout`")
	no_coef = base$parameter_layout
	no_coef$blocks[[1]]$role = "nuisance"
	expect_error(bad(parameter_layout = no_coef), "exactly one block")
})

test_that("evaluate_likelihood_parameter_layout resolves p and K", {
	lay = EDI:::EDI_INFERENCE_LIKELIHOOD_PROPERTIES$InferenceOrdinalStereotypeLogitRegr$parameter_layout
	ev = EDI:::evaluate_likelihood_parameter_layout(lay, p = 3L, K = 4L)
	expect_identical(ev$length, 8L)
	expect_identical(ev$treatment_index, 4L)
	expect_identical(unname(ev$sizes), c(3L, 3L, 2L))
})
