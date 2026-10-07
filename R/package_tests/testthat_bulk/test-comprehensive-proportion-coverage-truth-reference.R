library(testthat)

# Load only the named top-level assignments from the comprehensive harness.
# Sourcing comprehensive_tests.R would start the suite and is inappropriate for
# a focused unit test.
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

truth_fixture <- function() {
	e <- new.env(parent = globalenv())
	e$datasets_and_response_models <- list(toy = list(
		X = data.frame(x = seq_len(6L)),
		y_original = list(
		proportion = c(0, 0.02, 0.20, 0.80, 0.98, 1),
		incidence = c(-2, 0.02, 0.20, 0.80, 0.98, 2),
		continuous = seq_len(6L),
		survival = seq_len(6L)
	)))
	e$.coverage_truth_cache <- new.env(parent = emptyenv())
	e$DesignFixedBernoulli <- "fixed-bernoulli-generator"
	e$InferenceAllSimpleWilcox <- "wilcox-generator"
	e$compute_mc_coverage_truth_simframe <- function(...) stop("MC truth was not stubbed by this test")
	eval_comprehensive_assignments(c(
		"serialize_beta_T",
		"incid_p_base_and_treated",
		"compute_incid_logit_coverage_truth",
		"compute_incid_risk_diff_coverage_truth",
		"compute_incid_risk_ratio_coverage_truth",
		"compute_incid_log_risk_ratio_coverage_truth",
		"compute_prop_mean_diff_coverage_truth",
		"compute_survival_mean_diff_coverage_truth",
		"COVERAGE_CLOSED_FORM",
		"COVERAGE_MC_SPEC",
		"COVERAGE_TRUTH_UNAVAILABLE",
		"coverage_truth_uses_real_covariates",
		"coverage_truth_cache_key",
		"get_coverage_mc_spec",
		"get_coverage_truth",
		".screen_estimate_theta_cache",
		"estimate_logging_theta_base_class",
		"screen_estimate_theta_key",
		"get_estimate_logging_theta"
	), e)
	e
}

logit_shift_reference <- function(p, beta) {
	p_base <- pmin(0.95, pmax(0.05, p))
	shifted_odds <- exp(beta) * p_base / (1 - p_base)
	p_t <- shifted_odds / (1 + shifted_odds)
	list(p_base = p_base, p_t = p_t)
}

test_that("proportion mean-difference truth independently matches the logit-scale DGP", {
	e <- truth_fixture()
	beta <- 0.5
	p <- e$datasets_and_response_models$toy$y_original$proportion
	ref <- logit_shift_reference(p, beta)
	expected <- mean(ref$p_t - ref$p_base)

	expect_equal(e$compute_prop_mean_diff_coverage_truth("toy", beta), expected, tolerance = 1e-15)
	expect_equal(e$compute_prop_mean_diff_coverage_truth("toy", 0), 0, tolerance = 1e-15)

	stale_additive_truth <- mean(pmin(1, pmax(0, p + beta)) - p)
	expect_gt(abs(stale_additive_truth - expected), 0.1)
})

test_that("all proportion mean-difference classes dispatch to the corrected truth", {
	e <- truth_fixture()
	beta <- 0.5
	ref <- logit_shift_reference(e$datasets_and_response_models$toy$y_original$proportion, beta)
	expected <- mean(ref$p_t - ref$p_base)

	labels <- c(
		"InferenceAllSimpleAverageDiff [design_formula=~1]",
		"InferenceAllSimpleMeanDiffPooledVar [design_formula=~1]",
		"InferencePropGCompMeanDiff [model_formula=~1]"
	)
	for (label in labels) {
		expect_equal(e$get_coverage_truth(label, "toy", beta, "proportion"), expected, tolerance = 1e-15, info = label)
	}
})

test_that("incidence risk-difference siblings already use the matching logit shift", {
	e <- truth_fixture()
	beta <- 0.5
	p <- e$datasets_and_response_models$toy$y_original$incidence
	p_prob <- ifelse(is.finite(p) & p >= 0 & p <= 1, p, stats::plogis(p))
	ref <- logit_shift_reference(p_prob, beta)
	expected <- mean(ref$p_t - ref$p_base)

	labels <- c(
		"InferenceIncidGCompRiskDiff [model_formula=~1]",
		"InferenceIncidKKGCompRiskDiff [model_formula=~1]"
	)
	for (label in labels) {
		expect_equal(e$get_coverage_truth(label, "toy", beta, "incidence"), expected, tolerance = 1e-15, info = label)
	}
})

test_that("Wilcox gets a proportion-only MC truth because its estimand is not a mean", {
	e <- truth_fixture()
	seen <- NULL
	e$compute_mc_coverage_truth_simframe <- function(class_gen, design_gen, response_type, dataset_name, beta_T_val, mc_n, real_X = NULL) {
		seen <<- list(class_gen = class_gen, design_gen = design_gen, response_type = response_type,
			dataset_name = dataset_name, beta_T_val = beta_T_val, mc_n = mc_n, real_X = real_X)
		0.123
	}

	label <- "InferenceAllSimpleWilcox [design_formula=~1]"
	expect_equal(e$get_coverage_truth(label, "toy", 0.5, "proportion"), 0.123)
	expect_identical(seen$class_gen, "wilcox-generator")
	expect_identical(seen$design_gen, "fixed-bernoulli-generator")
	expect_identical(seen$response_type, "proportion")
	expect_identical(seen$mc_n, 20000L)
	expect_null(seen$real_X)
	expect_equal(e$get_estimate_logging_theta(label, "toy", 0.5, "proportion"), 0.123)

	# The generic class is also used for other response families. Those retain
	# their existing native-scale truth rather than reusing the proportion fit.
	expect_equal(e$get_coverage_truth(label, "toy", 0.5, "continuous"), 0.5)
	expect_equal(e$get_estimate_logging_theta(label, "toy", 0.5, "continuous"), 0.5)
	expect_false(identical(
		e$coverage_truth_cache_key("InferenceAllSimpleWilcox", "toy", 0.5, FALSE, "proportion"),
		e$coverage_truth_cache_key("InferenceAllSimpleWilcox", "toy", 0.5, FALSE, "continuous")
	))
})
