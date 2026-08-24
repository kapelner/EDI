library(testthat)
library(EDI)

simple_estimator_expected_classes = c(
	"InferenceAllSimpleAverageDiff",
	"InferenceAllSimpleMeanDiffPooledVar",
	"InferenceAllKKMeanDiffIVWC",
	"InferenceAllSimpleWilcox",
	"InferenceAllKKWilcoxIVWC"
)

simple_estimator_expected_current = list(
	InferenceAllSimpleAverageDiff = list(
		family = "simple_mean_difference",
		parent = "Inference",
		public_count = 66L,
		private_owner_count = 304L,
		duplicate_private_owner_count = 0L,
		target_components = c(
			"RandomizationTest", "RandomizationCI", "NonparametricBootstrap",
			"RandomizationBootstrap", "RandomizationBootstrapCI",
			"BayesianBootstrap", "Jackknife", "Wald"
		),
		dropped_capabilities = c("likelihood_tests", "parametric_likelihood_bootstrap")
	),
	InferenceAllSimpleMeanDiffPooledVar = list(
		family = "simple_mean_difference",
		parent = "Inference",
		public_count = 66L,
		private_owner_count = 307L,
		duplicate_private_owner_count = 0L,
		target_components = c(
			"RandomizationTest", "RandomizationCI", "NonparametricBootstrap",
			"RandomizationBootstrap", "RandomizationBootstrapCI",
			"BayesianBootstrap", "Jackknife", "Wald"
		),
		dropped_capabilities = c("likelihood_tests", "parametric_likelihood_bootstrap")
	),
	InferenceAllKKMeanDiffIVWC = list(
		family = "simple_mean_difference",
		parent = "Inference",
		public_count = 66L,
		private_owner_count = 321L,
		duplicate_private_owner_count = 0L,
		target_components = c(
			"RandomizationTest", "RandomizationCI", "NonparametricBootstrap",
			"RandomizationBootstrap", "RandomizationBootstrapCI",
			"BayesianBootstrap", "Jackknife", "Wald",
			"KKPassThrough", "KKCompound"
		),
		dropped_capabilities = "likelihood_tests"
	),
	InferenceAllSimpleWilcox = list(
		family = "wilcoxon_rank",
		parent = "Inference",
		public_count = 60L,
		private_owner_count = 289L,
		duplicate_private_owner_count = 0L,
		target_components = c(
			"RandomizationTest", "RandomizationCI", "NonparametricBootstrap",
			"RandomizationBootstrap", "RandomizationBootstrapCI", "Jackknife", "Wald"
		),
		dropped_capabilities = c("bayesian_bootstrap", "likelihood_tests", "parametric_likelihood_bootstrap")
	),
	InferenceAllKKWilcoxIVWC = list(
		family = "wilcoxon_rank",
		parent = "Inference",
		public_count = 60L,
		private_owner_count = 309L,
		duplicate_private_owner_count = 0L,
		target_components = c(
			"RandomizationTest", "RandomizationCI", "NonparametricBootstrap",
			"RandomizationBootstrap", "RandomizationBootstrapCI", "Jackknife", "Wald",
			"KKWilcoxIVWC"
		),
		dropped_capabilities = c("bayesian_bootstrap", "likelihood_tests", "parametric_likelihood_bootstrap")
	)
)

test_that("simple estimator migration groups are recorded", {
	EDI:::populate_inference_class_registry()
	groups = EDI:::simple_estimator_migration_groups()
	counts = EDI:::simple_estimator_migration_counts()

	expect_identical(
		groups$simple_mean_difference,
		c(
			"InferenceAllKKMeanDiffIVWC",
			"InferenceAllSimpleAverageDiff",
			"InferenceAllSimpleMeanDiffPooledVar"
		)
	)
	expect_identical(
		groups$wilcoxon_rank,
		c("InferenceAllKKWilcoxIVWC", "InferenceAllSimpleWilcox")
	)
	expect_identical(
		counts,
		data.frame(
			family = c("simple_mean_difference", "wilcoxon_rank"),
			total = c(3L, 2L),
			migrated = c(3L, 2L),
			pending = c(0L, 0L),
			stringsAsFactors = FALSE
		)
	)
})

test_that("simple estimator migration manifest records current structure", {
	EDI:::populate_inference_class_registry()
	manifest = EDI:::simple_estimator_behavior_manifest()

	expect_identical(names(manifest), simple_estimator_expected_classes)
	for (class_name in names(simple_estimator_expected_current)) {
		expected = simple_estimator_expected_current[[class_name]]
		record = manifest[[class_name]]

		expect_identical(record$family, expected$family, info = class_name)
		expect_identical(record$current_parent, expected$parent, info = class_name)
		expect_identical(length(record$current_public_methods), expected$public_count, info = class_name)
		expect_identical(length(record$private_owner_names), expected$private_owner_count, info = class_name)
		if (is.na(expected$duplicate_private_owner_count)) {
			expect_true(length(record$duplicate_private_owner_names) > 0L, info = class_name)
		} else {
		expect_identical(length(record$duplicate_private_owner_names), expected$duplicate_private_owner_count, info = class_name)
		}
		expect_identical(record$migration_status, "migrated", info = class_name)
		expect_setequal(
			record$migration_evidence,
			EDI:::EDI_NO_LIKELIHOOD_MIGRATION_REQUIRED_EVIDENCE
		)
		expect_true("compute_estimate" %in% record$current_public_methods, info = class_name)
		expect_true("compute_asymp_confidence_interval" %in% record$current_public_methods, info = class_name)
		expect_true("compute_asymp_two_sided_pval" %in% record$current_public_methods, info = class_name)
		if (identical(record$family, "wilcoxon_rank")) {
			expect_true("compute_rand_bootstrap_confidence_interval" %in% record$current_public_methods, info = class_name)
		}
	}
})

test_that("simple estimator retained and dropped capability decisions are explicit", {
	EDI:::populate_inference_class_registry()
	manifest = EDI:::simple_estimator_behavior_manifest()

	for (class_name in names(simple_estimator_expected_current)) {
		expected = simple_estimator_expected_current[[class_name]]
		record = manifest[[class_name]]
		dropped_methods = EDI:::inference_optional_method_names_for_capabilities(expected$dropped_capabilities)

		expect_identical(record$target_parent, "Inference", info = class_name)
		expect_identical(record$target_components, expected$target_components, info = class_name)
		expect_true(all(record$intentional_public_methods %in% record$current_public_methods), info = class_name)
		remaining_dropped_methods = intersect(dropped_methods, record$current_public_methods)
		remaining_dropped_methods = setdiff(remaining_dropped_methods, c("get_supported_testing_types", "set_testing_type"))
		expect_true(all(remaining_dropped_methods %in% record$legacy_optional_surface), info = class_name)
		expect_false(any(dropped_methods %in% record$intentional_public_methods), info = class_name)
		expect_identical(record$legacy_optional_surface, character(), info = class_name)
	}
})

test_that("reviewed simple estimators are marked migrated through no-likelihood gate", {
	EDI:::populate_inference_class_registry()

	expect_silent(EDI:::mark_simple_estimator_classes_migrated(simple_estimator_expected_classes))
	for (class_name in simple_estimator_expected_classes) {
		expect_identical(
			EDI:::get_inference_hierarchy_migration_record(class_name)$migration_status,
			"migrated",
			info = class_name
		)
	}
})
