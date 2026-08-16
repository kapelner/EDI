make_model_scale_classification_probe = function(capabilities = character(), classes = "ModelScaleProbe") {
	structure(
		list(capabilities = function() capabilities),
		class = classes
	)
}

test_that("randomization CI model-scale classification uses capabilities", {
	model_scale_capabilities = c(
		"standard_model_cache",
		"count_likelihood_plumbing",
		"kk_gee",
		"kk_glmm",
		"kk_passthrough"
	)
	for (capability in model_scale_capabilities) {
		expect_true(EDI:::inference_uses_model_scale_randomization_transform(
			make_model_scale_classification_probe(capability)
		))
	}
	expect_false(EDI:::inference_uses_model_scale_randomization_transform(
		make_model_scale_classification_probe(c("wald", "bayesian_bootstrap"))
	))
})

test_that("randomization CI retains explicit non-component model-scale families", {
	for (classname in c(
		"InferencePropQuantileRegr",
		"InferencePropGCompMeanDiff",
		"InferenceCountHurdleNegBin"
	)) {
		expect_true(EDI:::inference_uses_model_scale_randomization_transform(
			make_model_scale_classification_probe(classes = c(classname, "ModelScaleProbe"))
		))
	}
})
