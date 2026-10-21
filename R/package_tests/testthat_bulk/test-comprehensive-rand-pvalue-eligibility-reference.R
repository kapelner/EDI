library(testthat)
library(EDI)

source(testthat::test_path("..", "comprehensive_rand_pvalue_eligibility.R"), local = TRUE)
source(testthat::test_path("..", "comprehensive_rand_ci_eligibility.R"), local = TRUE)

comprehensive_source_assignment_rhs <- function(path, name) {
	parsed <- parse(path)
	matches <- Filter(function(expr) {
		is.call(expr) && length(expr) >= 3L &&
			(identical(expr[[1L]], as.name("=")) ||
				identical(expr[[1L]], as.name("<-"))) &&
			identical(expr[[2L]], as.name(name))
	}, as.list(parsed))
	if (length(matches) != 1L) {
		stop("expected one top-level source assignment for ", name, call. = FALSE)
	}
	matches[[1L]][[3L]]
}

comprehensive_named_call_argument <- function(expr, name) {
	if (!is.call(expr)) return(NULL)
	args <- as.list(expr)[-1L]
	arg_names <- names(args)
	if (is.null(arg_names) || !name %in% arg_names) return(NULL)
	args[[match(name, arg_names)]]
}

comprehensive_source_contains_named_list_field <- function(expr, field) {
	if (!is.call(expr)) return(FALSE)
	args <- as.list(expr)[-1L]
	arg_names <- names(args)
	if (identical(expr[[1L]], as.name("list")) &&
		!is.null(arg_names) && field %in% arg_names) return(TRUE)
	any(vapply(args, comprehensive_source_contains_named_list_field, logical(1), field = field))
}

comprehensive_proportion_dataset_roster <- function(dataset_source_path) {
	dataset_list <- comprehensive_source_assignment_rhs(
		dataset_source_path, "datasets_and_response_models"
	)
	finagle <- comprehensive_source_assignment_rhs(
		dataset_source_path, "finagle_different_responses_from_continuous"
	)
	if (!comprehensive_source_contains_named_list_field(finagle, "proportion")) {
		stop("source response transformer no longer declares proportion", call. = FALSE)
	}
	datasets <- as.list(dataset_list)[-1L]
	response_fields <- lapply(datasets, comprehensive_named_call_argument, name = "y_original")
	has_proportion <- vapply(response_fields, function(y_expr) {
		if (!is.call(y_expr)) return(FALSE)
		if (identical(y_expr[[1L]], as.name("finagle_different_responses_from_continuous"))) return(TRUE)
		if (!identical(y_expr[[1L]], as.name("list"))) return(FALSE)
		"proportion" %in% names(as.list(y_expr)[-1L])
	}, logical(1))
	names(datasets)[has_proportion]
}

comprehensive_runner_design_class_map <- function(runner_path) {
	runner <- parse(runner_path)
	run_tests_assignment <- Filter(function(expr) {
		is.call(expr) && length(expr) >= 3L &&
			(identical(expr[[1L]], as.name("=")) ||
				identical(expr[[1L]], as.name("<-"))) &&
			identical(expr[[2L]], as.name("run_tests_for_response"))
	}, as.list(runner))
	if (length(run_tests_assignment) != 1L) stop("missing run_tests_for_response()", call. = FALSE)
	body <- run_tests_assignment[[1L]][[3L]][[3L]]

	find_design_switch <- function(expr) {
		if (!is.call(expr)) return(NULL)
		if (identical(expr[[1L]], as.name("switch")) &&
			length(expr) >= 2L && identical(expr[[2L]], as.name("design_type"))) return(expr)
		children <- as.list(expr)[-1L]
		for (child_index in seq_along(children)) {
			if (identical(children[child_index], list(quote(expr = )))) next
			found <- find_design_switch(children[[child_index]])
			if (!is.null(found)) return(found)
		}
		NULL
	}
	design_switch <- find_design_switch(body)
	if (is.null(design_switch)) stop("missing design_type switch", call. = FALSE)
	switch_args <- as.list(design_switch)[-c(1L, 2L)]
	design_labels <- names(switch_args)
	design_classes <- vapply(switch_args, function(expr) {
		if (is.call(expr) && is.call(expr[[1L]]) &&
			identical(expr[[1L]][[1L]], as.name("$")) &&
			identical(expr[[1L]][[3L]], as.name("new"))) {
			return(as.character(expr[[1L]][[2L]]))
		}
		NA_character_
	}, character(1))
	stats::setNames(design_classes, design_labels)
}

test_that("proportion plain-rand source cases expose the two runner p-value keys", {
	# Independent expected labels are the two explicit safe_call labels under
	# the proportion-compatible plain-rand branch in comprehensive_tests.R.
	cases <- data.frame(
		rep = c(3L, 4L),
		beta_T = c(0.5, 0.5),
		dataset = c("fixture", "fixture"),
		response_type = c("proportion", "proportion"),
		design = c("Bernoulli", "Bernoulli"),
		inference_class = c("InferencePropGCompMeanDiff (model_formula=~1)",
			"InferencePropGCompMeanDiff (model_formula=~.)"),
		supports_randomization_test = c(TRUE, TRUE),
		test_family_filter = c(NA_character_, NA_character_),
		skip_slow = c(FALSE, FALSE),
		skip_rand = c(FALSE, FALSE),
		skip_rand_pval = c(FALSE, FALSE),
		skip_rand_slow = c(FALSE, FALSE),
		skip_rand_delta_pval_slow = c(FALSE, FALSE),
		stringsAsFactors = FALSE
	)
	runner_source <- testthat::test_path("..", "comprehensive_tests.R")
	manifest <- comprehensive_rand_pvalue_attempt_manifest(cases, runner_source)
	expected_functions <- c("compute_rand_two_sided_pval", "compute_rand_two_sided_pval(delta=0.5)")
	expect_identical(names(manifest), c(
		"rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run"
	))
	expect_identical(manifest$rep, c(3L, 3L, 4L, 4L))
	expect_identical(manifest$inference_class, rep(cases$inference_class, each = 2L))
	expect_identical(manifest$function_run, rep(expected_functions, 2L))
})

test_that("unsupported or slow proportion cases fail closed in the expected-key inventory", {
	cases <- data.frame(
		rep = c(3L, 4L),
		beta_T = c(0.5, 0.5),
		dataset = c("fixture", "fixture"),
		response_type = c("proportion", "proportion"),
		design = c("Bernoulli", "Bernoulli"),
		inference_class = c("InferencePropGCompMeanDiff (model_formula=~1)",
			"InferencePropGCompMeanDiff (model_formula=~.)"),
		supports_randomization_test = c(TRUE, FALSE),
		test_family_filter = c(NA_character_, NA_character_),
		skip_slow = c(FALSE, FALSE),
		skip_rand = c(FALSE, FALSE),
		skip_rand_pval = c(FALSE, FALSE),
		skip_rand_slow = c(TRUE, FALSE),
		skip_rand_delta_pval_slow = c(FALSE, FALSE),
		stringsAsFactors = FALSE
	)
	runner_source <- testthat::test_path("..", "comprehensive_tests.R")
	expect_equal(nrow(comprehensive_rand_pvalue_attempt_manifest(cases, runner_source)), 0L)
	bad_guard <- cases[1L, , drop = FALSE]
	bad_guard$skip_rand_slow <- NA
	expect_error(
		comprehensive_rand_pvalue_attempt_manifest(bad_guard, runner_source),
		"skip_rand_slow must be one non-missing logical value"
	)
	modified_source <- tempfile(fileext = ".R")
	on.exit(unlink(modified_source), add = TRUE)
	source_text <- readLines(runner_source, warn = FALSE)
	guard_line <- grep("!skip_rand_slow && response_type %in%", source_text, fixed = TRUE)
	expect_length(guard_line, 1L)
	source_text[guard_line] <- sub(
		"!skip_rand_slow && response_type %in%",
		"!skip_rand_slow && !unknown_rand_gate && response_type %in%",
		source_text[guard_line], fixed = TRUE
	)
	writeLines(source_text, modified_source)
	expect_error(
		comprehensive_rand_pvalue_attempt_manifest(cases[1L, , drop = FALSE], modified_source),
		"unrecognized plain-rand p-value source guards"
	)
})

test_that("proportion rand manifest rejects malformed source keys and unknown family filters", {
	case <- data.frame(
		rep = 1L,
		beta_T = 0.5,
		dataset = "fixture",
		response_type = "proportion",
		design = "Bernoulli",
		inference_class = "InferencePropGCompMeanDiff (model_formula=~1)",
		supports_randomization_test = TRUE,
		test_family_filter = NA_character_,
		skip_slow = FALSE,
		skip_rand = FALSE,
		skip_rand_pval = FALSE,
		skip_rand_slow = FALSE,
		skip_rand_delta_pval_slow = FALSE,
		stringsAsFactors = FALSE
	)
	runner_source <- testthat::test_path("..", "comprehensive_tests.R")

	bad_rep <- case
	bad_rep$rep <- 1.5
	expect_error(
		comprehensive_rand_pvalue_attempt_manifest(bad_rep, runner_source),
		"positive finite integer reps"
	)
	bad_complex_rep <- case
	bad_complex_rep$rep <- 1 + 0i
	expect_error(
		comprehensive_rand_pvalue_attempt_manifest(bad_complex_rep, runner_source),
		"rep and beta_T must be numeric key columns"
	)
	bad_beta <- case
	bad_beta$beta_T <- Inf
	expect_error(
		comprehensive_rand_pvalue_attempt_manifest(bad_beta, runner_source),
		"finite beta_T"
	)
	bad_key_type <- case
	bad_key_type$design <- factor("Bernoulli")
	expect_error(
		comprehensive_rand_pvalue_attempt_manifest(bad_key_type, runner_source),
		"design must be a character key column"
	)
	bad_filter <- case
	bad_filter$test_family_filter <- "ran"
	expect_error(
		comprehensive_rand_pvalue_attempt_manifest(bad_filter, runner_source),
		"test_family_filter must be one supported family or NA"
	)

	# A recognized non-rand family legitimately excludes this operation; this
	# keeps the guard from conflating a valid family filter with a misspelling.
	case$test_family_filter <- "estimate"
	expect_equal(nrow(comprehensive_rand_pvalue_attempt_manifest(case, runner_source)), 0L)
})

test_that("a delta-only slow-path rule removes only its own function key", {
	functions <- comprehensive_rand_pvalue_attempted_functions(
		response_type = "proportion",
		supports_randomization_test = TRUE,
		skip_rand_delta_pval_slow = TRUE
	)
	expect_identical(functions, "compute_rand_two_sided_pval")
})

test_that("plain-rand p-value and CI attempts project to runner result IDs", {
	# This fixture composes only the existing eligibility helpers. It does not
	# construct a design/inference object or call an estimator.
	case <- data.frame(
		rep = 7L,
		beta_T = 0.5,
		dataset = "fixture",
		response_type = "proportion",
		design = "Bernoulli",
		inference_class = "InferencePropGCompMeanDiff (model_formula=~.)",
		supports_randomization_test = TRUE,
		supports_randomization_ci = TRUE,
		supports_randomization_bootstrap = FALSE,
		test_family_filter = NA_character_,
		skip_slow = FALSE,
		skip_rand = FALSE,
		skip_rand_pval = FALSE,
		skip_rand_slow = FALSE,
		skip_rand_delta_pval_slow = FALSE,
		skip_ci_rand = FALSE,
		skip_rand_ci_slow = FALSE,
		skip_brt_ci = FALSE,
		skip_brt_ci_smoothed_slow = FALSE,
		skip_brt_ci_typed_slow = FALSE,
		test_compute_confidence_interval_rand = TRUE,
		stringsAsFactors = FALSE
	)
	pvalue_manifest <- comprehensive_rand_pvalue_attempt_manifest(
		case, testthat::test_path("..", "comprehensive_tests.R")
	)
	ci_manifest <- comprehensive_rand_ci_attempt_manifest(case)
	combined <- rbind(pvalue_manifest, ci_manifest)

	# Evaluate only the two pure key-serialization definitions from the runner;
	# parsing/evaluating these function assignments does not execute the runner.
	runner_source <- parse(testthat::test_path("..", "comprehensive_tests.R"))
	top_level_assignment <- function(name) {
		matches <- Filter(function(expr) {
			is.call(expr) && length(expr) >= 3L &&
				(identical(expr[[1L]], as.name("=")) ||
					identical(expr[[1L]], as.name("<-"))) &&
				identical(expr[[2L]], as.name(name))
		}, as.list(runner_source))
		expect_length(matches, 1L)
		matches[[1L]]
	}
	key_env <- new.env(parent = baseenv())
	eval(top_level_assignment("serialize_beta_T"), envir = key_env)
	eval(top_level_assignment("build_result_key"), envir = key_env)
	combined$id <- with(combined, key_env$build_result_key(
		rep, beta_T, dataset, response_type, design, inference_class, function_run
	))

	# Literal expected IDs independently pin the runner's seven-field layout and
	# beta token for this fixture, rather than deriving expectations from its key function.
	expect_identical(combined$function_run, c(
		"compute_rand_two_sided_pval",
		"compute_rand_two_sided_pval(delta=0.5)",
		"compute_rand_confidence_interval"
	))
	expect_identical(combined$id, c(
		"7||5e-01||fixture||proportion||Bernoulli||InferencePropGCompMeanDiff (model_formula=~.)||compute_rand_two_sided_pval",
		"7||5e-01||fixture||proportion||Bernoulli||InferencePropGCompMeanDiff (model_formula=~.)||compute_rand_two_sided_pval(delta=0.5)",
		"7||5e-01||fixture||proportion||Bernoulli||InferencePropGCompMeanDiff (model_formula=~.)||compute_rand_confidence_interval"
	))
})

test_that("reduced source-derived proportion case lattice has exact rand attempt IDs", {
	runner_path <- testthat::test_path("..", "comprehensive_tests.R")
	class_roster <- comprehensive_rand_ci_dispatch_roster(
		runner_path, response_type = "proportion", is_kk_design = FALSE
	)
	expect_true("InferencePropGCompMeanDiff" %in% class_roster)
	runner_lines <- readLines(runner_path, warn = FALSE)
	expect_length(grep("formulas_to_test = list(~ 1, ~ .)", runner_lines, fixed = TRUE), 1L)
	expect_length(grep(
		'univ_label = paste0(class_name, " (model_formula=~1)")', runner_lines, fixed = TRUE
	), 1L)
	expect_length(grep(
		'multi_label = paste0(class_name, " (model_formula=~.)")', runner_lines, fixed = TRUE
	), 1L)

	# The harness's formulas_to_test and run_inference_checks_both_paths labels
	# above anchor these formula values to source. Keep a small 2-rep slice and the single source-rostered
	# class; no dataset, design, or inference object is constructed here.
	cases <- expand.grid(
		rep = c(1L, 2L),
		model_formula = c("~1", "~."),
		stringsAsFactors = FALSE
	)
	cases$beta_T <- 0.5
	cases$dataset <- "fixture"
	cases$response_type <- "proportion"
	cases$design <- "Bernoulli"
	cases$inference_class <- paste0(
		"InferencePropGCompMeanDiff (model_formula=", cases$model_formula, ")"
	)
	# These are the precomputed harness eligibility/skip decisions consumed by
	# the pure helpers. The second case suppresses only p-values; the fourth
	# suppresses only the plain-rand CI.
	cases$supports_randomization_test <- TRUE
	cases$supports_randomization_ci <- TRUE
	cases$supports_randomization_bootstrap <- FALSE
	cases$test_family_filter <- NA_character_
	cases$skip_slow <- FALSE
	cases$skip_rand <- FALSE
	cases$skip_rand_pval <- c(FALSE, TRUE, FALSE, FALSE)
	cases$skip_rand_slow <- FALSE
	cases$skip_rand_delta_pval_slow <- FALSE
	cases$skip_ci_rand <- c(FALSE, FALSE, FALSE, TRUE)
	cases$skip_rand_ci_slow <- FALSE
	cases$skip_brt_ci <- FALSE
	cases$skip_brt_ci_smoothed_slow <- FALSE
	cases$skip_brt_ci_typed_slow <- FALSE
	cases$test_compute_confidence_interval_rand <- TRUE
	cases$inference_class <- as.character(cases$inference_class)

	pvalue_manifest <- comprehensive_rand_pvalue_attempt_manifest(cases, runner_path)
	ci_manifest <- comprehensive_rand_ci_attempt_manifest(cases)
	combined <- rbind(pvalue_manifest, ci_manifest)

	# Project using only the runner's pure serializer definitions. Evaluating
	# these assignments cannot enter the harness or invoke inference.
	runner_source <- parse(runner_path)
	key_env <- new.env(parent = baseenv())
	for (name in c("serialize_beta_T", "build_result_key", "screen_estimate_theta_key")) {
		matches <- Filter(function(expr) {
			is.call(expr) && length(expr) >= 3L &&
				(identical(expr[[1L]], as.name("=")) ||
					identical(expr[[1L]], as.name("<-"))) &&
				identical(expr[[2L]], as.name(name))
		}, as.list(runner_source))
		expect_length(matches, 1L)
		eval(matches[[1L]], envir = key_env)
	}
	expect_identical(key_env$serialize_beta_T(c(0, 0.5)), c("0e+00", "5e-01"))
	combined$id <- with(combined, key_env$build_result_key(
		rep, beta_T, dataset, response_type, design, inference_class, function_run
	))

	expect_identical(nrow(cases), 4L)
	expect_identical(nrow(combined), 9L)
	expect_false(anyDuplicated(combined$id) > 0L)
	expect_setequal(combined$function_run, c(
		"compute_rand_two_sided_pval",
		"compute_rand_two_sided_pval(delta=0.5)",
		"compute_rand_confidence_interval"
	))

	# Independent expected row roster: reps 1/2 use ~1, then reps 1/2 use ~.;
	# case 2 contributes only CI, and case 4 contributes only the two p-values.
	expected_case <- c(1L, 1L, 3L, 3L, 4L, 4L, 1L, 2L, 3L)
	expected_function <- c(
		"compute_rand_two_sided_pval",
		"compute_rand_two_sided_pval(delta=0.5)",
		"compute_rand_two_sided_pval",
		"compute_rand_two_sided_pval(delta=0.5)",
		"compute_rand_two_sided_pval",
		"compute_rand_two_sided_pval(delta=0.5)",
		"compute_rand_confidence_interval",
		"compute_rand_confidence_interval",
		"compute_rand_confidence_interval"
	)
	expected_ids <- paste(
		cases$rep[expected_case], "5e-01", "fixture", "proportion", "Bernoulli",
		cases$inference_class[expected_case], expected_function,
		sep = "||"
	)
	expect_setequal(combined$id, expected_ids)
})

test_that("full proportion rand candidate inventory has source-derived count and unique IDs", {
	runner_path <- testthat::test_path("..", "comprehensive_tests.R")
	dataset_source_path <- testthat::test_path("..", "_dataset_load.R")
	runner_lines <- readLines(runner_path, warn = FALSE)

	# Parse the data-source declarations instead of sourcing _dataset_load.R:
	# its data()/sampling setup is unnecessary for this key inventory.
	proportion_datasets <- comprehensive_proportion_dataset_roster(dataset_source_path)
	expect_setequal(proportion_datasets, c(
		"diamonds", "pte_example", "ionosphere", "abalone", "iris",
		"boston", "fuel", "cars", "airquality"
	))

	# Read literal harness vectors/branches from the runner source. The outer
	# command under audit supplies Nrep=40 with no beta/design/dataset/rep filter.
	tested_designs <- eval(
		comprehensive_source_assignment_rhs(runner_path, "TESTED_DESIGNS"),
		envir = baseenv()
	)
	beta_rhs <- comprehensive_source_assignment_rhs(runner_path, "beta_T_values")
	default_beta_values <- eval(beta_rhs[[2L]], envir = baseenv())
	expect_identical(default_beta_values, c(0, 0.5))
	formula_lines <- grep("formulas_to_test = list", runner_lines, fixed = TRUE, value = TRUE)
	expect_length(formula_lines, 1L)
	formula_expr <- parse(text = sub("^.*formulas_to_test = ", "", formula_lines))[[1L]]
	formula_values <- eval(formula_expr, envir = baseenv())
	design_formula_labels <- vapply(formula_values, function(f) paste(deparse(f), collapse = ""), character(1))

	kk_lines <- grep("is_kk_design = design_type %in%", runner_lines, fixed = TRUE, value = TRUE)
	expect_length(kk_lines, 1L)
	kk_design_expr <- parse(text = sub("^.*%in%[[:space:]]*", "", kk_lines))[[1L]]
	kk_designs <- eval(kk_design_expr, envir = baseenv())
	proportion_designs <- setdiff(tested_designs, kk_designs)
	expect_setequal(proportion_designs, c(
		"Bernoulli", "SPBR", "FixediBCRD", "FixedBlocking", "FixedMatchingGreedy"
	))

	class_roster <- comprehensive_rand_ci_dispatch_roster(
		runner_path, response_type = "proportion", is_kk_design = FALSE
	)
	target_class <- "InferencePropGCompMeanDiff"
	expect_true(target_class %in% class_roster)
	expect_length(design_formula_labels, 2L)
	expect_setequal(design_formula_labels, c("~1", "~."))
	# `run_inference_checks_both_paths()` independently contributes both
	# inference model-formula labels for every outer design formula. The outer
	# `model_formula` loop in the runner is stored in result labels as
	# `design_formula`, so these are two independent formula dimensions.
	inference_formula_labels <- c("~1", "~.")

	# The source's supported design_type switch yields class names without
	# constructing design objects; the EDI registry capability query below is
	# metadata-only and receives inert proxy objects.
	design_class_map <- comprehensive_runner_design_class_map(runner_path)
	expect_true(all(proportion_designs %in% names(design_class_map)))
	expect_false(anyNA(design_class_map[proportion_designs]))
	design_capabilities <- lapply(proportion_designs, function(label) {
		EDI:::get_effective_capabilities(
			target_class,
			des_obj = structure(list(), class = unname(design_class_map[[label]]))
		)
	})
	names(design_capabilities) <- proportion_designs
	expect_true(all(vapply(design_capabilities, function(x) "randomization_test" %in% x, logical(1))))
	expect_true(all(vapply(design_capabilities, function(x) "randomization_ci" %in% x, logical(1))))

	nrep <- 40L
	cases <- expand.grid(
		design = proportion_designs,
		model_formula = inference_formula_labels,
		design_formula = design_formula_labels,
		rep = seq_len(nrep),
		beta_T = default_beta_values,
		dataset = proportion_datasets,
		KEEP.OUT.ATTRS = FALSE,
		stringsAsFactors = FALSE
	)
	cases$response_type <- "proportion"
	cases$inference_class <- paste0(
		target_class, " (model_formula=", cases$model_formula,
		") [design_formula=", cases$design_formula, "]"
	)
	cases$supports_randomization_test <- vapply(cases$design, function(d) {
		"randomization_test" %in% design_capabilities[[d]]
	}, logical(1))
	cases$supports_randomization_ci <- vapply(cases$design, function(d) {
		"randomization_ci" %in% design_capabilities[[d]]
	}, logical(1))
	cases$supports_randomization_bootstrap <- vapply(cases$design, function(d) {
		"randomization_bootstrap" %in% design_capabilities[[d]]
	}, logical(1))
	# The accepted full-grid invocation sets COMPREHENSIVE_FORCE_SLOW_PATHS=1;
	# source policy then neutralizes class slow-path skips. All other flags below
	# are explicit harness inputs, not inferred from whether an output row exists.
	# This is a candidate-attempt roster conditional on successful case setup;
	# no design/data setup or inference is executed here, and this inventory does
	# not claim that any result row was actually attempted or emitted.
	cases$test_family_filter <- "rand"
	cases$skip_slow <- FALSE
	cases$skip_rand <- FALSE
	cases$skip_rand_pval <- FALSE
	cases$skip_rand_slow <- FALSE
	cases$skip_rand_delta_pval_slow <- FALSE
	cases$skip_ci_rand <- FALSE
	cases$skip_rand_ci_slow <- FALSE
	cases$skip_brt_ci <- FALSE
	cases$skip_brt_ci_smoothed_slow <- FALSE
	cases$skip_brt_ci_typed_slow <- FALSE
	cases$test_compute_confidence_interval_rand <- TRUE

	expect_identical(nrow(cases), 14400L)
	expect_true(all(cases$supports_randomization_test))
	expect_true(all(cases$supports_randomization_ci))
	expect_length(unique(cases$inference_class), 4L)
	expect_setequal(
		unique(paste(cases$model_formula, cases$design_formula, sep = "||")),
		as.vector(outer(inference_formula_labels, design_formula_labels, paste, sep = "||"))
	)
	expect_identical(sort(as.integer(table(paste(
	cases$model_formula, cases$design_formula, sep = "||"
)))), rep(3600L, 4L))

	pvalue_manifest <- comprehensive_rand_pvalue_attempt_manifest(cases, runner_path)
	ci_manifest <- comprehensive_rand_ci_attempt_manifest(cases)
	combined <- rbind(pvalue_manifest, ci_manifest)
	expect_identical(nrow(pvalue_manifest), 28800L)
	expect_identical(nrow(ci_manifest), 14400L)
	expect_identical(nrow(combined), 43200L)
	expect_false(anyNA(combined[c(
		"rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run"
	)]))
	expect_setequal(combined$function_run, c(
		"compute_rand_two_sided_pval",
		"compute_rand_two_sided_pval(delta=0.5)",
		"compute_rand_confidence_interval"
	))

	# Project using the exact pure key definitions from the runner. This is an
	# inventory conditional on successful case setup, not proof that those rows
	# were emitted by a completed post-fix run.
	runner_source <- parse(runner_path)
	key_env <- new.env(parent = baseenv())
	for (name in c("serialize_beta_T", "build_result_key", "screen_estimate_theta_key")) {
		matches <- Filter(function(expr) {
			is.call(expr) && length(expr) >= 3L &&
				(identical(expr[[1L]], as.name("=")) ||
					identical(expr[[1L]], as.name("<-"))) &&
				identical(expr[[2L]], as.name(name))
		}, as.list(runner_source))
		expect_length(matches, 1L)
		eval(matches[[1L]], envir = key_env)
	}
	serialized_beta <- key_env$serialize_beta_T(c(0, 0.5))
	expect_length(serialized_beta, 2L)
	expect_identical(serialized_beta, c("0e+00", "5e-01"))
	expect_length(unique(serialized_beta), 2L)
	expect_identical(key_env$serialize_beta_T(0.5), "5e-01")
	expect_identical(
		key_env$serialize_beta_T(c(0, NA_real_, 0.5)),
		c("0e+00", "NA", "5e-01")
	)
	result_key_by_beta <- key_env$build_result_key(
		rep_val = 1L,
		beta_val = c(0, 0.5),
		dataset_val = "diamonds",
		response_val = "proportion",
		design_val = "Bernoulli",
		inference_val = "InferencePropGCompMeanDiff (model_formula=~1) [design_formula=~1]",
		function_run_val = "compute_rand_two_sided_pval"
	)
	expect_length(unique(result_key_by_beta), 2L)
	estimate_cache_key_by_beta <- key_env$screen_estimate_theta_key(
		base_class = "InferencePropGCompMeanDiff",
		dataset_name = "diamonds",
		beta_T_val = c(0, 0.5),
		response_type_hint = "proportion"
	)
	expect_length(unique(estimate_cache_key_by_beta), 2L)
	combined$id <- with(combined, key_env$build_result_key(
		rep, beta_T, dataset, response_type, design, inference_class, function_run
	))
	duplicate_index <- anyDuplicated(combined$id)
	expect_identical(duplicate_index, 0L, info = if (duplicate_index > 0L) {
		paste(capture.output(print(combined[c(duplicate_index, match(combined$id[duplicate_index], combined$id)), ])), collapse = "\n")
	} else "no duplicate IDs")
	expect_identical(combined$id[1L], paste(
		"1", "0e+00", "diamonds", "proportion", "Bernoulli",
		"InferencePropGCompMeanDiff (model_formula=~1) [design_formula=~1]",
		"compute_rand_two_sided_pval", sep = "||"
	))

	generated <- comprehensive_proportion_rand_candidate_manifest(
		Nrep = nrep,
		runner_path = runner_path,
		dataset_source_path = dataset_source_path,
		force_run_slow_paths = TRUE,
		test_family_filter = "rand"
	)
	expect_identical(nrow(generated), 43200L)
	expect_identical(attr(generated, "candidate_context_count"), 14400L)
	expect_setequal(generated$id, combined$id)
	expect_setequal(generated$function_run, combined$function_run)
	expect_true(all(generated$eligibility_scope == "candidate_if_setup_and_source_capability_succeed"))
	default_run <- comprehensive_proportion_rand_candidate_manifest(
		Nrep = nrep,
		runner_path = runner_path,
		dataset_source_path = dataset_source_path,
		force_run_slow_paths = FALSE
	)
	expect_identical(nrow(default_run), 0L)
	expect_identical(attr(default_run, "candidate_context_count"), 14400L)
	expect_true(isTRUE(attr(default_run, "excluded_by_default_slow_path")))
})
