library(testthat)

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
	for (class_name in c(
		"InferenceSurvivalKMDiff", "InferenceIncidLogRegr",
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
