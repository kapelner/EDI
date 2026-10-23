library(testthat)
library(EDI)

# Load only named assignments from the comprehensive harness. Sourcing the
# file would launch the full multi-hour suite.
comprehensive_path <- testthat::test_path("..", "comprehensive_tests.R")
comprehensive_exprs <- parse(comprehensive_path)

eval_comprehensive_assignments <- function(names, envir) {
	remaining <- names
	for (expr in comprehensive_exprs) {
		if (!is.call(expr) || !(identical(expr[[1L]], as.name("=")) || identical(expr[[1L]], as.name("<-"))) || !is.name(expr[[2L]])) next
		name <- as.character(expr[[2L]])
		if (!(name %in% remaining)) next
		eval(expr, envir = envir)
		remaining <- setdiff(remaining, name)
	}
	if (length(remaining)) stop("Missing comprehensive assignment(s): ", paste(remaining, collapse = ", "))
	invisible(envir)
}

registry_fixture <- function() {
	e <- new.env(parent = globalenv())
	e$datasets_and_response_models <- list(toy = list(
		X = data.frame(x1 = 1:4, x2 = 4:1),
		y_original = list(incidence = c(0, 1, 0, 1), survival = 1:4, ordinal = 1:4)
	))
	e$.coverage_truth_cache <- new.env(parent = emptyenv())
	e$.screen_estimate_theta_cache <- new.env(parent = emptyenv())
	e$compute_mc_coverage_truth_simframe <- function(...) stop("MC stub not installed")
	e$DesignFixedBernoulli <- "fixed-bernoulli-generator"
	e$DesignFixedBinaryMatch <- "fixed-binary-match-generator"
	for (class_name in c(
		"InferenceSurvivalKMDiff", "InferenceSurvivalKKWeibullMarginal", "InferenceIncidLogRegr",
		"InferenceOrdinalCauchitRegr", "InferenceOrdinalCloglogRegr",
		"InferenceOrdinalOrderedProbitRegr", "InferenceOrdinalAdjCatLogitRegr",
		"InferenceOrdinalContRatioRegr", "InferenceOrdinalPartialProportionalOddsRegr"
	)) assign(class_name, class_name, envir = e)
	eval_comprehensive_assignments(c(
		"serialize_beta_T",
		"incid_p_base_and_treated", "compute_incid_logit_coverage_truth",
		"compute_incid_risk_diff_coverage_truth", "compute_incid_risk_ratio_coverage_truth",
		"compute_incid_log_risk_ratio_coverage_truth", "compute_prop_mean_diff_coverage_truth",
		"compute_survival_mean_diff_coverage_truth",
		"COVERAGE_CLOSED_FORM", "COVERAGE_MC_SPEC", "COVERAGE_TRUTH_UNAVAILABLE",
		"coverage_truth_uses_real_covariates", "coverage_truth_cache_key",
		# TODO-10 (2026-10-22): get_coverage_truth()/get_estimate_logging_theta() read the matched-Cox covariate cap.
		"KK_MATCHED_COX_COVARIATE_CAP_CLASSES", "KK_MATCHED_COX_COVARIATE_CAP_K", "comprehensive_covariate_cap_k", "comprehensive_capped_model_formula",
		"coverage_truth_seed", "get_coverage_mc_spec", "get_coverage_truth", "estimate_logging_theta_base_class",
		"screen_estimate_theta_key", "get_estimate_logging_theta"
	), e)
	e
}

test_that("every newly audited truth-scale mismatch dispatches through MC truth", {
	e <- registry_fixture()
	cases <- list(
		InferenceSurvivalKMDiff = "survival",
		InferenceIncidLogRegr = "incidence",
		InferenceOrdinalCauchitRegr = "ordinal",
		InferenceOrdinalCloglogRegr = "ordinal",
		InferenceOrdinalOrderedProbitRegr = "ordinal",
		InferenceOrdinalAdjCatLogitRegr = "ordinal",
		InferenceOrdinalContRatioRegr = "ordinal",
		InferenceOrdinalPartialProportionalOddsRegr = "ordinal"
	)
	seen <- character()
	e$compute_mc_coverage_truth_simframe <- function(class_gen, design_gen, response_type, dataset_name, beta_T_val, mc_n, real_X = NULL) {
		seen <<- c(seen, response_type)
		expect_identical(dataset_name, "toy")
		expect_identical(mc_n, 20000L)
		expect_identical(real_X, e$datasets_and_response_models$toy$X)
		0.125
	}

	for (class_name in names(cases)) {
		label <- paste0(class_name, " [model_formula=~.]")
		expect_equal(e$get_coverage_truth(label, "toy", 0.5, cases[[class_name]]), 0.125,
			info = class_name)
		expect_equal(e$get_estimate_logging_theta(label, "toy", 0.5, cases[[class_name]]), 0.125,
			info = class_name)
	}
	expect_identical(seen, unname(unlist(cases)))
	expect_null(e$COVERAGE_CLOSED_FORM$InferenceIncidLogRegr)
})

test_that("bare fixed-formula coverage labels retain the default real covariates", {
	e <- registry_fixture()
	seen_real_X <- NULL
	e$compute_mc_coverage_truth_simframe <- function(class_gen, design_gen, response_type, dataset_name, beta_T_val, mc_n, real_X = NULL) {
		seen_real_X <<- real_X
		0.125
	}

	# run_tests_for_response() treats a bare fixed-formula class label as ~.;
	# the MC truth must therefore receive the same real adjustment set as an
	# explicit [model_formula=~.] label.
	expect_true(e$coverage_truth_uses_real_covariates("InferenceIncidLogRegr"))
	expect_equal(e$get_coverage_truth("InferenceIncidLogRegr", "toy", 0.5, "incidence"), 0.125)
	expect_identical(seen_real_X, e$datasets_and_response_models$toy$X)
})

test_that("MC truth cache keys isolate the real-covariate adjustment argument", {
	e <- registry_fixture()
	seen_real_X <- list()
	e$compute_mc_coverage_truth_simframe <- function(class_gen, design_gen, response_type, dataset_name, beta_T_val, mc_n, real_X = NULL) {
		seen_real_X <<- c(seen_real_X, list(real_X))
		as.numeric(length(seen_real_X))
	}

	# These are the same class, dataset, effect, and response, but the
	# comprehensive runner's `~.` and `~1` routes target different adjustment
	# sets. They must not share a cached MC truth.
	real_covariates <- e$get_coverage_truth(
		"InferenceOrdinalCauchitRegr [model_formula=~.]", "toy", 0.5, "ordinal"
	)
	intercept_only <- e$get_coverage_truth(
		"InferenceOrdinalCauchitRegr [model_formula=~1]", "toy", 0.5, "ordinal"
	)

	expect_identical(real_covariates, 1)
	expect_identical(intercept_only, 2)
	expect_identical(seen_real_X, list(e$datasets_and_response_models$toy$X, NULL))
	expect_identical(e$get_coverage_truth(
		"InferenceOrdinalCauchitRegr [model_formula=~.]", "toy", 0.5, "ordinal"
	), real_covariates)
	expect_identical(e$get_coverage_truth(
		"InferenceOrdinalCauchitRegr [model_formula=~1]", "toy", 0.5, "ordinal"
	), intercept_only)
	expect_length(seen_real_X, 2L)
})

test_that("TODO-26 KK Weibull matrix labels route formula-matched MC truth inputs", {
	e <- registry_fixture()
	seen <- list()
	e$compute_mc_coverage_truth_simframe <- function(class_gen, design_gen, response_type, dataset_name, beta_T_val, mc_n, real_X = NULL) {
		seen[[length(seen) + 1L]] <<- list(
			class_gen = class_gen, design_gen = design_gen, response_type = response_type,
			dataset_name = dataset_name, beta_T_val = beta_T_val, mc_n = mc_n, real_X = real_X
		)
		as.numeric(length(seen))
	}

	# The retained TODO-26 matrix labels this class with design_formula (not
	# model_formula). Match the run contract: ~1 has no adjustment covariates,
	# while ~. and a bare fixed-formula label use the real dataset covariates.
	intercept_only <- e$get_coverage_truth(
		"InferenceSurvivalKKWeibullMarginal [design_formula=~1]", "toy", 0, "survival"
	)
	adjusted <- e$get_coverage_truth(
		"InferenceSurvivalKKWeibullMarginal [design_formula=~.]", "toy", 0, "survival"
	)
	bare <- e$get_coverage_truth("InferenceSurvivalKKWeibullMarginal", "toy", 0, "survival")

	expect_identical(intercept_only, 1)
	expect_identical(adjusted, 2)
	expect_identical(bare, adjusted)
	expect_length(seen, 2L)
	expect_identical(seen[[1L]], list(
		class_gen = "InferenceSurvivalKKWeibullMarginal",
		design_gen = "fixed-binary-match-generator", response_type = "survival",
		dataset_name = "toy", beta_T_val = 0, mc_n = 3000L, real_X = NULL
	))
	expect_identical(seen[[2L]], list(
		class_gen = "InferenceSurvivalKKWeibullMarginal",
		design_gen = "fixed-binary-match-generator", response_type = "survival",
		dataset_name = "toy", beta_T_val = 0, mc_n = 3000L,
		real_X = e$datasets_and_response_models$toy$X
	))
})

test_that("unconverged matched-Cox truth is unavailable rather than raw beta_T", {
	e <- registry_fixture()
	for (class_name in e$COVERAGE_TRUTH_UNAVAILABLE) {
		label <- paste0(class_name, " [model_formula=~.]")
		expect_true(is.na(e$get_coverage_truth(label, "toy", 0.5, "survival")), info = class_name)
		expect_true(is.na(e$get_estimate_logging_theta(label, "toy", 0.5, "survival")), info = class_name)
	}
})

test_that("MC coverage truth uses a key-specific seed without advancing the caller RNG", {
	withr::local_seed(731L)
	e <- registry_fixture()
	e$compute_mc_coverage_truth_simframe <- function(...) stats::runif(1L)

	caller_seed <- .Random.seed
	expected_next <- stats::runif(1L)
	assign(".Random.seed", caller_seed, envir = .GlobalEnv)
	value <- e$get_coverage_truth(
		"InferenceOrdinalCauchitRegr [model_formula=~.]", "toy", 0.5, "ordinal"
	)
	expect_identical(get(".Random.seed", envir = .GlobalEnv), caller_seed)
	expect_identical(stats::runif(1L), expected_next)

	# The same cache key gets the same fit seed even when the caller arrives
	# with a different main-stream state.
	withr::local_seed(918L)
	e2 <- registry_fixture()
	e2$compute_mc_coverage_truth_simframe <- function(...) stats::runif(1L)
	second_caller_seed <- .Random.seed
	second_value <- e2$get_coverage_truth(
		"InferenceOrdinalCauchitRegr [model_formula=~.]", "toy", 0.5, "ordinal"
	)
	expect_identical(get(".Random.seed", envir = .GlobalEnv), second_caller_seed)
	expect_identical(second_value, value)
})

test_that("MC coverage truth leaves no RNG seed behind when the caller had none", {
	had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
	if (had_seed) {
		original_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
	}
	withr::defer({
		if (had_seed) {
			assign(".Random.seed", original_seed, envir = .GlobalEnv)
		} else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
			rm(".Random.seed", envir = .GlobalEnv)
		}
	}, envir = parent.frame())
	if (had_seed) rm(".Random.seed", envir = .GlobalEnv)

	e <- registry_fixture()
	e$compute_mc_coverage_truth_simframe <- function(...) stats::runif(1L)
	expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
	expect_true(is.finite(e$get_coverage_truth(
		"InferenceOrdinalCauchitRegr [model_formula=~.]", "toy", 0.5, "ordinal"
	)))
	expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
})

test_that("ordinal coverage attempt roster expands source-derived direct classes and exact keys", {
	source(testthat::test_path("..", "comprehensive_ordinal_coverage_attempt_manifest.R"), local = TRUE)
	runner_path <- testthat::test_path("..", "comprehensive_tests.R")
	case_grid <- data.frame(
		rep = c(2L, 3L),
		beta_T = c(0, 0.5),
		dataset = c("toy", "toy"),
		response_type = c("ordinal", "ordinal"),
		design = c("Bernoulli", "Bernoulli"),
		stringsAsFactors = FALSE
	)
	# This reduced roster takes every ordinal MC-truth class routed through the
	# runner's direct-call path, then models a bounded set of estimate/Wald
	# attempts using explicit fixture flags. These are not live capability
	# claims: exact-inference skip_asymp, method existence, and direct Wald
	# support can vary by concrete class and remain outside this source-only
	# roster. No inference or MC-truth fit is constructed.
	flags <- list(
		test_family_filters = c("estimate", "wald"),
		has_compute_estimate = TRUE,
		skip_asymp = FALSE,
		has_wald_two_sided_pval = TRUE,
		has_wald_confidence_interval = TRUE,
		supports_wald_testing_type = TRUE,
		skip_slow = TRUE
	)
	manifest <- comprehensive_ordinal_coverage_attempt_manifest(
		case_grid, runner_path, attempt_flags = flags
	)
	full_key <- c(
		"rep", "beta_T", "dataset", "response_type", "design",
		"inference_class", "function_run"
	)
	expected_classes <- c(
		"InferenceOrdinalRidit", "InferenceOrdinalCauchitRegr",
		"InferenceOrdinalCloglogRegr", "InferenceOrdinalOrderedProbitRegr",
		"InferenceOrdinalAdjCatLogitRegr", "InferenceOrdinalContRatioRegr",
		"InferenceOrdinalPartialProportionalOddsRegr"
	)
	expected_runs <- c(
		"compute_estimate", "compute_wald_two_sided_pval",
		"compute_wald_confidence_interval"
	)
	attempts <- expand.grid(
		class_name = expected_classes,
		formula = c("~1", "~."),
		function_run = expected_runs,
		stringsAsFactors = FALSE,
		KEEP.OUT.ATTRS = FALSE
	)
	expected <- merge(case_grid, attempts, by = NULL, sort = FALSE)
	expected$inference_class <- paste0(expected$class_name, " [design_formula=", expected$formula, "]")
	expected$class_name <- NULL
	expected$formula <- NULL
	expected <- expected[full_key]
	key_text <- function(x) do.call(paste, c(lapply(x[full_key], as.character), sep = "||"))
	expect_length(manifest$function_run, 84L)
	expect_setequal(manifest$inference_class, as.vector(outer(
		expected_classes, c("~1", "~."), function(cls, formula) paste0(cls, " [design_formula=", formula, "]")
	)))
	expect_setequal(manifest$function_run, expected_runs)
	expect_setequal(key_text(manifest), key_text(expected))
	expect_identical(anyDuplicated(manifest[full_key]), 0L)

	# If the source's exact-inference branch sets skip_asymp, direct Wald
	# attempts disappear even when the explicit fixture says methods exist.
	# This checks the modeled branch boundary without claiming which concrete
	# ordinal classes take that runtime-dependent branch.
	exact_skip_flags <- flags
	exact_skip_flags$skip_asymp <- TRUE
	exact_skip <- comprehensive_ordinal_coverage_attempt_manifest(
		case_grid, runner_path, attempt_flags = exact_skip_flags
	)
	expect_length(exact_skip$function_run, 28L)
	expect_setequal(exact_skip$function_run, "compute_estimate")

	duplicate_case <- rbind(case_grid, case_grid[1L, , drop = FALSE])
	expect_error(
		comprehensive_ordinal_coverage_attempt_manifest(
			duplicate_case, runner_path,
			attempt_flags = flags
		),
		"duplicate ordinal source case key"
	)

	# Attempt flags are an explicit fixture contract, not inferred from live
	# classes. Guard both a missing capability field and a non-scalar-logical
	# value so a malformed fixture cannot silently change the source-derived
	# attempt roster.
	missing_flag <- flags
	missing_flag$skip_slow <- NULL
	expect_error(
		comprehensive_ordinal_coverage_attempt_manifest(
			case_grid, runner_path, attempt_flags = missing_flag
		),
		"bounded roster requires explicit estimate/wald family and capability flags"
	)
	nonlogical_flag <- flags
	nonlogical_flag$has_compute_estimate <- 1L
	expect_error(
		comprehensive_ordinal_coverage_attempt_manifest(
			case_grid, runner_path, attempt_flags = nonlogical_flag
		),
		"all ordinal attempt capability and branch flags must be explicit scalar logicals"
	)
})

test_that("MC coverage truth retries with deterministic attempt seeds and caches only an accepted value", {
	# Exercise get_coverage_truth's retry contract without fitting models. The
	# test oracle independently computes the documented polynomial seed from
	# the complete cache key; the stub returns a bad finite value, a non-finite
	# value, then a plausible truth.
	e <- registry_fixture()
	class_name <- "TODO10RetryFixture"
	label <- paste0(class_name, " [model_formula=~1]")
	e$COVERAGE_MC_SPEC[[class_name]] <- list(
		gen = quote(mock_gen), design = quote(mock_design), rt = "proportion", mc_n = 6L
	)
	e$mock_gen <- "mock-generator"
	e$mock_design <- "mock-design"
	seen <- list()
	outcomes <- list(9, Inf, 0.25)
	e$compute_mc_coverage_truth_simframe <- function(class_gen, design_gen, response_type, dataset_name, beta_T_val, mc_n, real_X = NULL) {
		seen[[length(seen) + 1L]] <<- list(
			class_gen = class_gen, design_gen = design_gen,
			response_type = response_type, dataset_name = dataset_name,
			beta_T_val = beta_T_val, mc_n = mc_n, real_X = real_X,
			rng_state = get(".Random.seed", envir = .GlobalEnv)
		)
		outcomes[[length(seen)]]
	}

	key <- e$coverage_truth_cache_key(class_name, "toy", 0.5, FALSE, "proportion")
	reference_seed <- function(key) {
		h <- 0
		for (code in utf8ToInt(key)) h <- (h * 31 + code) %% 2147483647
		as.integer(h)
	}
	seed_state <- function(seed) {
		had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
		if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
		on.exit(if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv) else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv), add = TRUE)
		set.seed(seed)
		get(".Random.seed", envir = .GlobalEnv)
	}
	expected_states <- lapply(seq_len(3L), function(attempt) {
		seed_state((reference_seed(key) + attempt) %% .Machine$integer.max)
	})
	set.seed(91503L)
	caller_rng_state <- get(".Random.seed", envir = .GlobalEnv)

	truth <- e$get_coverage_truth(label, "toy", 0.5, "proportion")

	expect_equal(truth, 0.25, tolerance = 0)
	expect_length(seen, 3L)
	expect_identical(lapply(seen, `[[`, "rng_state"), expected_states)
	expect_true(all(vapply(seen, function(call) {
		identical(call$class_gen, "mock-generator") && identical(call$design_gen, "mock-design") &&
			identical(call$response_type, "proportion") && identical(call$dataset_name, "toy") &&
			identical(call$beta_T_val, 0.5) && identical(call$mc_n, 6L) && is.null(call$real_X)
	}, logical(1))))
	expect_identical(get(".Random.seed", envir = .GlobalEnv), caller_rng_state)
	expect_true(exists(key, envir = e$.coverage_truth_cache, inherits = FALSE))
	expect_equal(get(key, envir = e$.coverage_truth_cache, inherits = FALSE), 0.25, tolerance = 0)
	expect_equal(e$get_coverage_truth(label, "toy", 0.5, "proportion"), 0.25, tolerance = 0)
	expect_length(seen, 3L)
})

test_that("exhausted MC truth retries return NA without caching and restore the caller RNG", {
	e <- registry_fixture()
	class_name <- "TODO10ExhaustedRetryFixture"
	label <- paste0(class_name, " [model_formula=~1]")
	e$COVERAGE_MC_SPEC[[class_name]] <- list(
		gen = quote(mock_gen), design = quote(mock_design), rt = "proportion", mc_n = 6L
	)
	e$mock_gen <- "mock-generator"
	e$mock_design <- "mock-design"
	seen_states <- list()
	outcomes <- list(9, Inf, -7, NaN, 6)
	e$compute_mc_coverage_truth_simframe <- function(...) {
		seen_states[[length(seen_states) + 1L]] <<- get(".Random.seed", envir = .GlobalEnv)
		outcomes[[length(seen_states)]]
	}
	key <- e$coverage_truth_cache_key(class_name, "toy", 0.5, FALSE, "proportion")
	set.seed(91504L)
	caller_rng_state <- get(".Random.seed", envir = .GlobalEnv)

	truth <- e$get_coverage_truth(label, "toy", 0.5, "proportion")

	expect_true(is.na(truth))
	expect_length(seen_states, 5L)
	expect_identical(get(".Random.seed", envir = .GlobalEnv), caller_rng_state)
	expect_false(exists(key, envir = e$.coverage_truth_cache, inherits = FALSE))
})
