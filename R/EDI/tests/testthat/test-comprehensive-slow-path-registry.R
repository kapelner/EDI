library(testthat)
library(EDI)

test_that("comprehensive slow-path registry is public and structurally valid", {
	expect_true("EDI_COMPREHENSIVE_SLOW_PATHS" %in% getNamespaceExports("EDI"))
	expect_identical(EDI::EDI_COMPREHENSIVE_SLOW_PATHS, EDI_COMPREHENSIVE_SLOW_PATHS)
	expect_true(getFromNamespace("validate_comprehensive_slow_path_rules", "EDI")(
		EDI::EDI_COMPREHENSIVE_SLOW_PATHS
	))
})

test_that("slow-path validation rejects malformed, duplicate, and abstract entries", {
	validate = getFromNamespace("validate_comprehensive_slow_path_rules", "EDI")
	rules = EDI::EDI_COMPREHENSIVE_SLOW_PATHS

	bad = rules
	bad$rand = c(bad$rand, bad$rand[[1L]])
	expect_error(validate(bad), "unique nonempty strings", fixed = TRUE)

	bad = rules
	bad$exact_operations[[1L]] = "not-an-operation-key"
	expect_error(validate(bad), "Invalid comprehensive exact-operation", fixed = TRUE)

	bad = rules
	bad$rand = c(bad$rand, "Inference")
	expect_error(validate(bad), "concrete classes", fixed = TRUE)
})

test_that("InferenceSuite default task filtering honors slow class and operation rules", {
	is_slow = getFromNamespace(
		"run_all_inference_task_is_comprehensive_slow_path",
		"EDI"
	)

	expect_true(is_slow(
		list(cls_name = "InferenceOrdinalStereotypeLogitRegr", method = "rand", type = NA_character_),
		"ordinal"
	))
	expect_true(is_slow(
		list(cls_name = "InferenceOrdinalStereotypeLogitRegr", method = "bootstrap", type = "studentized"),
		"ordinal"
	))
	expect_true(is_slow(
		list(cls_name = "InferenceContinRobustRegr", method = "bayes_boot", type = "percentile"),
		"continuous"
	))
	expect_true(is_slow(
		list(cls_name = "InferenceContinRobustRegr", method = "rand_bootstrap", type = "percentile"),
		"continuous"
	))
	expect_false(is_slow(
		list(cls_name = "InferenceOrdinalStereotypeLogitRegr", method = "wald", type = NA_character_),
		"ordinal"
	))
	expect_true(is_slow(
		list(cls_name = "InferenceCountHurdleNegBin", method = "rand", type = NA_character_),
		"count"
	))
	expect_false(is_slow(
		list(cls_name = "InferenceSurvivalCoxPHRegr", method = "wald", type = NA_character_),
		"survival"
	))
	expect_true(is_slow(
		list(cls_name = "InferenceOrdinalKKGEE", method = "bootstrap", type = "studentized"),
		"ordinal"
	))
	for (class_name in c(
		"InferenceSurvivalGLMMWeibullFrailtyNormalOneLik",
		"InferenceSurvivalKKStratCoxPHOneLik"
	)) {
		expect_true(class_name %in% EDI::EDI_COMPREHENSIVE_SLOW_PATHS$rand_ci)
		expect_true(is_slow(
			list(cls_name = class_name, method = "rand", type = NA_character_),
			"survival"
		), info = class_name)
	}
	expect_false(is_slow(
		list(cls_name = "InferenceOrdinalKKGEE", method = "bootstrap", type = "bca"),
		"ordinal"
	))
	expect_true("InferenceOrdinalKKGLMM" %in% EDI::EDI_COMPREHENSIVE_SLOW_PATHS$boot_ci)
	for (bootstrap_type in c("percentile", "basic", "bca", "studentized")) {
		expect_true(is_slow(
			list(cls_name = "InferenceOrdinalKKGLMM", method = "bootstrap", type = bootstrap_type),
			"ordinal"
		), info = bootstrap_type)
	}
})

test_that("explicit InferenceSuite methods opt back into registered slow paths", {
	build_tasks = getFromNamespace("run_all_inference_build_tasks", "EDI")
	args = list(
		cls_names = "InferenceOrdinalStereotypeLogitRegr",
		formulas = NULL,
		methods = c("wald", "rand"),
		des_obj = NULL,
		inference_params = list(),
		type_requests = list(),
		basic_bootstrap = FALSE,
		response_type = "ordinal"
	)

	default_tasks = do.call(build_tasks, c(args, list(exclude_comprehensive_slow_paths = TRUE)))
	explicit_tasks = do.call(build_tasks, c(args, list(exclude_comprehensive_slow_paths = FALSE)))
	expect_identical(vapply(default_tasks, `[[`, character(1L), "method"), "wald")
	expect_setequal(vapply(explicit_tasks, `[[`, character(1L), "method"), c("wald", "rand"))
})
