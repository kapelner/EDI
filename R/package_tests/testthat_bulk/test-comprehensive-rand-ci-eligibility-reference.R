library(testthat)
library(EDI)

source(testthat::test_path("..", "comprehensive_rand_ci_eligibility.R"), local = TRUE)

rand_ci_context <- function(...) {
	defaults <- list(
		response_type = "continuous",
		supports_randomization_ci = TRUE,
		supports_randomization_bootstrap = TRUE,
		test_family_filter = NA_character_,
		skip_slow = FALSE,
		skip_rand = FALSE,
		skip_rand_slow = FALSE,
		skip_ci_rand = FALSE,
		skip_rand_ci_slow = FALSE,
		skip_brt_ci = FALSE,
		skip_brt_ci_smoothed_slow = FALSE,
		skip_brt_ci_typed_slow = FALSE,
		test_compute_confidence_interval_rand = TRUE
	)
	utils::modifyList(defaults, list(...))
}

rand_ci_attempts <- function(...) {
	do.call(comprehensive_rand_ci_attempted_functions, rand_ci_context(...))
}

test_that("comprehensive rand-CI attempts match the supported response and method set", {
	expected <- c(
		"compute_rand_confidence_interval",
		"compute_rand_bootstrap_confidence_interval",
		"compute_rand_bootstrap_confidence_interval_studentized",
		"compute_rand_bootstrap_confidence_interval_symmetric-percentile-t",
		"compute_rand_bootstrap_confidence_interval_smoothed"
	)
	for (response_type in c("continuous", "proportion", "count", "survival")) {
		expect_identical(rand_ci_attempts(response_type = response_type), expected)
	}
	for (response_type in c("incidence", "ordinal")) {
		expect_identical(rand_ci_attempts(response_type = response_type), character())
	}
	expect_true(comprehensive_should_run_test_family("rand", NA_character_))
	expect_true(comprehensive_should_run_test_family("rand", "rand"))
	expect_false(comprehensive_should_run_test_family("rand", "rand_bootstrap"))
})

test_that("plain and bootstrap randomization-CI capability gates are independent", {
	expect_identical(
		rand_ci_attempts(supports_randomization_ci = FALSE),
		c(
			"compute_rand_bootstrap_confidence_interval",
			"compute_rand_bootstrap_confidence_interval_studentized",
			"compute_rand_bootstrap_confidence_interval_symmetric-percentile-t",
			"compute_rand_bootstrap_confidence_interval_smoothed"
		)
	)
	expect_identical(
		rand_ci_attempts(supports_randomization_bootstrap = FALSE),
		"compute_rand_confidence_interval"
	)
})

test_that("the pure attempt enumerator emits exact seven-field result keys", {
	case <- data.frame(
		rep = 2L,
		beta_T = 0.5,
		dataset = "fixture",
		response_type = "continuous",
		design = "Bernoulli",
		inference_class = "InferenceContinOLS (model_formula=~1)",
		supports_randomization_ci = TRUE,
		supports_randomization_bootstrap = TRUE,
		test_family_filter = NA_character_,
		skip_slow = FALSE,
		skip_rand = FALSE,
		skip_rand_slow = FALSE,
		skip_ci_rand = FALSE,
		skip_rand_ci_slow = FALSE,
		skip_brt_ci = FALSE,
		skip_brt_ci_smoothed_slow = FALSE,
		skip_brt_ci_typed_slow = FALSE,
		test_compute_confidence_interval_rand = TRUE,
		stringsAsFactors = FALSE
	)
	functions <- c(
		"compute_rand_confidence_interval",
		"compute_rand_bootstrap_confidence_interval",
		"compute_rand_bootstrap_confidence_interval_studentized",
		"compute_rand_bootstrap_confidence_interval_symmetric-percentile-t",
		"compute_rand_bootstrap_confidence_interval_smoothed"
	)
	manifest <- comprehensive_rand_ci_attempt_manifest(case)
	expect_identical(names(manifest), c(
		"rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run"
	))
	expect_identical(manifest$rep, rep(2L, length(functions)))
	expect_identical(manifest$beta_T, rep(0.5, length(functions)))
	expect_identical(manifest$dataset, rep("fixture", length(functions)))
	expect_identical(manifest$response_type, rep("continuous", length(functions)))
	expect_identical(manifest$design, rep("Bernoulli", length(functions)))
	expect_identical(manifest$inference_class, rep(case$inference_class, length(functions)))
	expect_identical(manifest$function_run, functions)
	expect_error(
		comprehensive_rand_ci_attempt_manifest(rbind(case, case)),
		"duplicate attempted result key"
	)
})

test_that("shared rand-CI filters suppress exactly the call families they guard", {
	shared_skips <- c("skip_slow", "skip_rand", "skip_ci_rand")
	for (skip_name in shared_skips) {
		args <- stats::setNames(list(TRUE), skip_name)
		expect_identical(do.call(rand_ci_attempts, args), character(), info = skip_name)
	}
	expect_identical(
		rand_ci_attempts(test_compute_confidence_interval_rand = FALSE),
		character()
	)
	expect_identical(
		rand_ci_attempts(test_family_filter = "rand"),
		"compute_rand_confidence_interval"
	)
	expect_identical(
		rand_ci_attempts(test_family_filter = "rand_bootstrap"),
		c(
			"compute_rand_bootstrap_confidence_interval",
			"compute_rand_bootstrap_confidence_interval_studentized",
			"compute_rand_bootstrap_confidence_interval_symmetric-percentile-t",
			"compute_rand_bootstrap_confidence_interval_smoothed"
		)
	)
})

test_that("plain-only and typed-bootstrap slow-path guards match the harness", {
	brt_only <- c(
		"compute_rand_bootstrap_confidence_interval",
		"compute_rand_bootstrap_confidence_interval_studentized",
		"compute_rand_bootstrap_confidence_interval_symmetric-percentile-t",
		"compute_rand_bootstrap_confidence_interval_smoothed"
	)
	expect_identical(rand_ci_attempts(skip_rand_slow = TRUE), brt_only)
	expect_identical(rand_ci_attempts(skip_rand_ci_slow = TRUE), brt_only)
	expect_identical(
		rand_ci_attempts(skip_brt_ci = TRUE),
		"compute_rand_confidence_interval"
	)
	expect_identical(
		rand_ci_attempts(skip_brt_ci_typed_slow = TRUE),
		c(
			"compute_rand_confidence_interval",
			"compute_rand_bootstrap_confidence_interval",
			"compute_rand_bootstrap_confidence_interval_smoothed"
		)
	)
	expect_identical(
		rand_ci_attempts(skip_brt_ci_smoothed_slow = TRUE),
		c(
			"compute_rand_confidence_interval",
			"compute_rand_bootstrap_confidence_interval",
			"compute_rand_bootstrap_confidence_interval_studentized",
			"compute_rand_bootstrap_confidence_interval_symmetric-percentile-t"
		)
	)
})

test_that("dispatch roster follows the harness response and KK branches without construction", {
	comprehensive_tests_source <- testthat::test_path("..", "comprehensive_tests.R")
	continuous_non_kk <- comprehensive_rand_ci_dispatch_roster(
		comprehensive_tests_source, "continuous", FALSE
	)
	continuous_kk <- comprehensive_rand_ci_dispatch_roster(
		comprehensive_tests_source, "continuous", TRUE
	)
	expect_setequal(continuous_non_kk, c(
		"InferenceAllSimpleAverageDiff", "InferenceAllSimpleMeanDiffPooledVar",
		"InferenceAllSimpleWilcox",
		"InferenceContinRobustRegr", "InferenceContinQuantileRegr",
		"InferenceContinLin", "InferenceContinOLS"
	))
	expect_setequal(continuous_kk, c(
		"InferenceAllSimpleAverageDiff", "InferenceAllSimpleMeanDiffPooledVar",
		"InferenceAllSimpleWilcox",
		"InferenceContinKKRobustRegrOneLik", "InferenceContinKKOLSOneLik",
		"InferenceContinKKGLMM", "InferenceContinKKQuantileRegrOneLik"
	))
	expect_true(all(grepl("^Inference(AllSimple|Contin)", c(continuous_non_kk, continuous_kk))))

	survival_kk <- comprehensive_rand_ci_dispatch_roster(
		comprehensive_tests_source, "survival", TRUE
	)
	expect_true(all(c(
		"InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC",
		"InferenceSurvivalKKStratCoxPHOneLik",
		"InferenceSurvivalWeibullRegr"
	) %in% survival_kk))
})

test_that("class eligibility uses metadata and harness slow-path categories without fitting", {
	base_args <- list(
		class_name = "InferenceContinOLS",
		response_type = "continuous",
		design_class = "DesignSeqOneByOneBernoulli",
		model_formula = "~ .",
		test_family_filter = "rand_bootstrap",
		slow_path_rules = list(),
		additional_slow_paths = list()
	)
	expect_length(do.call(comprehensive_rand_ci_class_attempts, base_args), 4L)

	base_args$test_family_filter <- "rand"
	base_args$additional_slow_paths <- list(rand_ci = "InferenceContinOLS")
	expect_length(do.call(comprehensive_rand_ci_class_attempts, base_args), 0L)

	base_args$test_family_filter <- "rand_bootstrap"
	base_args$additional_slow_paths <- list()
	base_args$slow_path_rules <- list(rand = "InferenceContinOLS")
	expect_length(do.call(comprehensive_rand_ci_class_attempts, base_args), 0L)
})

test_that("class eligibility preserves inherited sequential-design bootstrap exclusions", {
	kk21 <- DesignSeqOneByOneKK21$new(
		n = 10L, response_type = "continuous", verbose = FALSE
	)
	bernoulli <- DesignSeqOneByOneBernoulli$new(
		n = 10L, response_type = "continuous", verbose = FALSE
	)

	# The concrete KK21 class inherits DesignSeqOneByOne's exclusion; the
	# Bernoulli subclass is the documented exception because its assignment
	# does not depend on prior subjects.
	expect_false("nonparametric_bootstrap" %in% EDI:::get_effective_capabilities(
		"InferenceContinOLS", des_obj = kk21
	))
	expect_true("nonparametric_bootstrap" %in% EDI:::get_effective_capabilities(
		"InferenceContinOLS", des_obj = bernoulli
	))

	base_args <- list(
		class_name = "InferenceCountKKHurdlePoissonOneLik",
		response_type = "count",
		design_class = class(kk21)[[1L]],
		model_formula = "~1",
		test_family_filter = "rand_bootstrap",
		slow_path_rules = list(),
		additional_slow_paths = list(),
		narrow_mode = TRUE
	)
	expect_identical(do.call(comprehensive_rand_ci_class_attempts, base_args), character())

	# Control: same family and an unrestricted host/design must retain the raw
	# percentile CI attempt; narrow mode intentionally omits typed/smoothed CIs.
	base_args$class_name <- "InferenceContinOLS"
	base_args$response_type <- "continuous"
	base_args$design_class <- class(bernoulli)[[1L]]
	expect_identical(
		do.call(comprehensive_rand_ci_class_attempts, base_args),
		"compute_rand_bootstrap_confidence_interval"
	)
})

test_that("TODO-119 scale-mismatch classes never get a randomization-CI attempt", {
	refused <- EDI:::EDI_RAND_CI_SHIFT_SCALE_MISMATCH_CLASSES
	expect_gt(length(refused), 0L)
	expect_true(all(vapply(refused, comprehensive_rand_ci_refused_for_scale_mismatch, logical(1))))
	expect_false(comprehensive_rand_ci_refused_for_scale_mismatch("InferenceContinOLS"))

	# Even if the capability were (wrongly) reported, the helper forces the
	# class out of the compute_rand_confidence_interval roster; p-values and
	# randomization-bootstrap CIs are separate functions and are not touched.
	args <- list(
		class_name = "InferencePropGCompMeanDiff",
		response_type = "proportion",
		design_class = "DesignFixedBernoulli",
		model_formula = "~1",
		test_family_filter = "rand",
		slow_path_rules = list(),
		additional_slow_paths = list(),
		force_run_slow_paths = TRUE
	)
	expect_false("compute_rand_confidence_interval" %in% do.call(comprehensive_rand_ci_class_attempts, args))
	for (cls in setdiff(refused, "InferencePropGCompMeanDiff")) {
		args$class_name <- cls
		args$response_type <- "ordinal"
		expect_false("compute_rand_confidence_interval" %in% do.call(comprehensive_rand_ci_class_attempts, args))
	}
	# A class outside the list keeps the attempt (control).
	args$class_name <- "InferenceContinOLS"
	args$response_type <- "continuous"
	expect_true("compute_rand_confidence_interval" %in% do.call(comprehensive_rand_ci_class_attempts, args))
})

test_that("TODO-119 / G6 exact 0/1 proportion refusal is read from the package predicate", {
	f <- comprehensive_rand_ci_refused_for_exact_zero_one
	expect_true(f("proportion", TRUE, c(0, 0.4, 0.6)))
	expect_true(f("proportion", TRUE, c(0.4, 1)))
	expect_false(f("proportion", TRUE, c(0.05, 0.5, 0.95)))
	expect_false(f("proportion", FALSE, c(0, 0.5, 1)))
	expect_false(f("continuous", TRUE, c(0, 1)))
	# classes overriding the generic rand CI (no refusal there) are not skipped
	expect_false(f("proportion", TRUE, c(0, 0.5, 1), uses_generic_rand_ci = FALSE))
	generic <- EDI:::InferenceRandCI$public_methods$compute_rand_confidence_interval
	expect_true(comprehensive_rand_ci_uses_generic_implementation(list(compute_rand_confidence_interval = generic)))
	expect_false(comprehensive_rand_ci_uses_generic_implementation(list(compute_rand_confidence_interval = function(...) NULL)))
	expect_false(comprehensive_rand_ci_uses_generic_implementation(list()))
})
