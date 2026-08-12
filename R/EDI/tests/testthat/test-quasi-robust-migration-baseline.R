library(testthat)
library(EDI)

quasi_robust_expected_classes = c(
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

quasi_robust_expected_behaviors = list(
	composite_likelihood = c("InferenceCountQuasiPoisson", "InferenceCountRobustPoisson"),
	gee = c(
		"InferenceCountPoissonKKGEE",
		"InferenceIncidKKGEE",
		"InferenceOrdinalKKGEE",
		"InferencePropKKGEE"
	),
	kk_compound = c("InferenceContinKKRobustRegrIVWC", "InferenceContinKKRobustRegrOneLik"),
	kk_gee = c(
		"InferenceCountPoissonKKGEE",
		"InferenceIncidKKGEE",
		"InferenceOrdinalKKGEE",
		"InferencePropKKGEE"
	),
	kk_passthrough = c("InferenceContinKKRobustRegrIVWC", "InferenceContinKKRobustRegrOneLik"),
	quasi_likelihood = "InferenceCountQuasiPoisson",
	robust_sandwich = c(
		"InferenceContinKKRobustRegrIVWC",
		"InferenceContinKKRobustRegrOneLik",
		"InferenceContinRobustRegr",
		"InferenceCountRobustPoisson"
	)
)

test_that("quasi/robust migration manifest records every current quasi concrete class", {
	EDI:::populate_inference_class_registry()
	manifest = EDI:::quasi_robust_behavior_manifest()

	expect_identical(names(manifest), quasi_robust_expected_classes)
	expect_identical(
		EDI:::quasi_robust_concrete_class_names(),
		sort(quasi_robust_expected_classes)
	)
	for (class_name in names(manifest)) {
		record = manifest[[class_name]]
		expect_identical(record$name, class_name)
		expect_identical(record$current_likelihood_tier, "quasi", info = class_name)
		expect_identical(record$target_likelihood_tier, "quasi", info = class_name)
		expect_identical(record$target_parent, "Inference", info = class_name)
		expect_true(length(record$behavior) > 0L, info = class_name)
		expect_true(nzchar(record$estimator_family), info = class_name)
		expect_true(nzchar(record$notes), info = class_name)
		expect_true(is.character(record$current_effective_components), info = class_name)
		expect_true(is.character(record$current_effective_capabilities), info = class_name)
		expect_true(is.logical(record$composite_likelihood_tests_component), info = class_name)
		expect_true(is.character(record$composite_likelihood_public_methods), info = class_name)
	}
})

test_that("RobustSandwich component exposes the extracted sandwich helpers", {
	EDI:::populate_inference_component_registry()
	component = EDI:::get_inference_component("RobustSandwich")

	expect_identical(component$source_name, "RobustSandwichSource")
	expect_identical(component$provides_capabilities, "robust_sandwich")
	expect_identical(EDI:::component_public_names(component), character())
	expect_setequal(
		EDI:::component_private_names(component),
		c(
			"robust_sandwich_meat_from_residuals",
			"robust_sandwich_vcov",
			"robust_sandwich_variance",
			"robust_sandwich_variance_from_xtwx"
		)
	)
})

test_that("RobustSandwich helper matches the existing Huber-White calculation", {
	X = cbind(1, treatment = c(0, 1, 0, 1, 1), x = c(-1, -0.5, 0, 0.5, 1))
	residuals = c(-0.2, 0.7, -0.1, 0.3, -0.4)
	XtWX = crossprod(X, X)
	j_treat = 2L

	bread = solve(XtWX)
	meat = crossprod(X, X * (residuals^2))
	expected = as.numeric((bread %*% meat %*% bread)[j_treat, j_treat])

	expect_equal(
		EDI:::robust_sandwich_variance_from_xtwx(X, residuals, XtWX, j_treat),
		expected
	)
	expect_true(is.na(EDI:::robust_sandwich_variance_from_xtwx(X, residuals[-1L], XtWX, j_treat)))
})

test_that("composite likelihood targets do not need a distinct test component yet", {
	EDI:::populate_inference_component_registry()
	manifest = EDI:::quasi_robust_behavior_manifest()
	composite_names = names(Filter(function(record) {
		"composite_likelihood" %in% record$behavior
	}, manifest))

	expect_identical(
		composite_names,
		c("InferenceCountQuasiPoisson", "InferenceCountRobustPoisson")
	)
	expect_false("CompositeLikelihoodTests" %in% names(EDI:::EDI_COMPONENT_SPECS))
	expect_false("CompositeLikelihoodTests" %in% names(EDI:::inference_component_registry_as_list()))
	for (record in manifest[composite_names]) {
		expect_false(record$composite_likelihood_tests_component, info = record$name)
		expect_identical(record$composite_likelihood_public_methods, character(), info = record$name)
		expect_false("estimating_equation_likelihood_ratio" %in% record$current_effective_capabilities, info = record$name)
		expect_false("likelihood_ratio" %in% record$current_effective_capabilities, info = record$name)
	}
})

test_that("current composite count classes advertise Wald-only testing", {
	des = DesignSeqOneByOneBernoulli$new(n = 12, response_type = "count")
	for (i in seq_len(12)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x = i / 12))
	}
	des$add_all_subject_responses(c(0, 1, 0, 2, 1, 3, 1, 2, 3, 4, 2, 5))

		for (class_name in c("InferenceCountQuasiPoisson", "InferenceCountRobustPoisson")) {
			generator = get(class_name, envir = asNamespace("EDI"))
			inf = generator$new(des, verbose = FALSE)
			private = inf$.__enclos_env__$private

			expect_identical(inf$get_supported_testing_types(), "wald", info = class_name)
			expect_false(isTRUE(private$supports_likelihood_tests()), info = class_name)
			expect_false(isTRUE(private$supports_lik_ratio_param_bootstrap()), info = class_name)
			expect_null(inf$compute_lik_ratio_two_sided_pval, info = class_name)
			expect_false(inf$supports("likelihood_ratio"), info = class_name)
			expect_false(inf$supports("estimating_equation_likelihood_ratio"), info = class_name)
			expect_true(is.finite(inf$compute_estimate()), info = class_name)
			expect_true(is.finite(private$get_standard_error()), info = class_name)
			expect_true(all(is.finite(inf$compute_asymp_confidence_interval())), info = class_name)
			expect_true(is.finite(inf$compute_asymp_two_sided_pval()), info = class_name)
		}
	})

test_that("quasi/robust migration groups classify estimator behavior explicitly", {
	EDI:::populate_inference_class_registry()
	groups = EDI:::quasi_robust_behavior_groups()
	counts = EDI:::quasi_robust_behavior_counts()

	expect_identical(groups, quasi_robust_expected_behaviors)
	expect_identical(
		counts,
		structure(data.frame(
			behavior = names(quasi_robust_expected_behaviors),
			class_count = vapply(quasi_robust_expected_behaviors, length, integer(1L)),
			stringsAsFactors = FALSE
		), row.names = c(NA_integer_, -length(quasi_robust_expected_behaviors)))
	)
	expect_setequal(groups$gee, groups$kk_gee)
	expect_true(all(groups$composite_likelihood %in% quasi_robust_expected_classes))
	expect_true(all(groups$robust_sandwich %in% quasi_robust_expected_classes))
})
