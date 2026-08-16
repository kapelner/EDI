find_inherited_public_method = function(generator, method_name) {
	parent = generator$get_inherit()
	while (!is.null(parent)) {
		method = parent$public_methods[[method_name]]
		if (is.function(method)) return(method)
		parent = parent$get_inherit()
	}
	NULL
}

test_that("KK OLS and quantile IVWC inherit the shared bootstrap implementation", {
	method_name = "approximate_bootstrap_distribution_beta_hat_T"
	for (generator in list(
		EDI:::InferenceContinKKOLSIVWC,
		EDI:::InferenceAbstractKKQuantileRegrIVWC
	)) {
		expect_false(method_name %in% names(generator$public_methods))
		expect_true(is.function(find_inherited_public_method(generator, method_name)))
	}
})

test_that("KK pass-through hosts retain the directly composed bootstrap implementation", {
	method_name = "approximate_bootstrap_distribution_beta_hat_T"
	expected_body = body(EDI:::InferenceMixinKKPassThrough$public[[method_name]])
	for (generator in list(
		EDI:::InferenceAbstractKKCondLogitGLMM,
		EDI:::InferenceAbstractKKLWACoxOneLik,
		EDI:::InferenceAbstractKKMarginalIncid,
		EDI:::InferenceAbstractKKOrdinalCLMM,
		EDI:::InferenceOrdinalKKCondAdjCatLogitRegr,
		EDI:::InferenceKKPassThroughCompound,
		EDI:::InferenceKKPassThroughCompoundNoParamBootstrap
	)) {
		method = generator$public_methods[[method_name]]
		expect_true(is.function(method))
		expect_identical(body(method), expected_body)
	}
})
