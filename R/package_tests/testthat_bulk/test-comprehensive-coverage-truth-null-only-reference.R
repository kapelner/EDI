# Owner decision 2026-11-11 (v1.0.5 G4, KKCondLogitGLMMOneLik regeneration):
# comprehensive_tests.R grades coverage and MSE at beta_T = 0 only. There the
# truth is the estimand's null value (closed form where one exists, else 0) with
# no Monte Carlo simulation; away from the null there is no truth (NA).
library(testthat)
library(EDI)

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

null_only_fixture <- function() {
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
	e$.coverage_truth_failed <- new.env(parent = emptyenv())
	e$mc_calls <- 0L
	e$compute_mc_coverage_truth_simframe <- function(...) {
		e$mc_calls <- e$mc_calls + 1L
		stop("the runner must not simulate a truth")
	}
	eval_comprehensive_assignments(c(
		"COVERAGE_MC_TRUTH_ENABLED",
		"SD_NOISE_BY_RESPONSE_TYPE", "sd_noise_for", "prop_logistic_normal_mean",
		"incid_p_base_and_treated",
		"compute_incid_logit_coverage_truth", "compute_incid_risk_diff_coverage_truth",
		"compute_incid_risk_ratio_coverage_truth", "compute_incid_log_risk_ratio_coverage_truth",
		"compute_prop_mean_diff_coverage_truth", "compute_survival_mean_diff_coverage_truth",
		"COVERAGE_CLOSED_FORM", "COVERAGE_MC_SPEC",
		"COVERAGE_TRUTH_UNAVAILABLE", "COVERAGE_TRUTH_UNAVAILABLE_REAL_COVARIATES",
		"coverage_truth_unavailable", "coverage_truth_uses_real_covariates", "coverage_truth_cache_key",
		"KK_MATCHED_COX_COVARIATE_CAP_CLASSES", "KK_MATCHED_COX_COVARIATE_CAP_K",
		"comprehensive_covariate_cap_k", "comprehensive_capped_model_formula",
		"coverage_truth_seed", "get_coverage_mc_spec", "get_coverage_truth",
		".screen_estimate_theta_cache", "estimate_logging_theta_base_class",
		"screen_estimate_theta_key", "get_estimate_logging_theta"
	), e)
	e
}

test_that("the runner ships with the Monte Carlo truth switched off", {
	e <- null_only_fixture()
	expect_false(e$COVERAGE_MC_TRUTH_ENABLED)
})

test_that("away from the null there is no truth, closed form or simulated", {
	e <- null_only_fixture()
	for (label in c(
		"InferenceIncidKKCondLogitGLMMOneLik (model_formula=~.) [design_formula=~.]",
		"InferenceIncidGCompRiskRatio",
		"InferenceIncidRiskDiff",
		"InferenceIncidLogRegr"
	)) {
		expect_identical(e$get_coverage_truth(label, "toy", 0.5, "incidence"), NA_real_, info = label)
		expect_identical(e$get_estimate_logging_theta(label, "toy", 0.5, "incidence"), NA_real_, info = label)
	}
	expect_identical(e$mc_calls, 0L)
})

test_that("at the null the truth is the estimand's null value without simulating", {
	e <- null_only_fixture()
	# Closed forms give the exact null: 1 for a risk ratio, 0 for a difference or log ratio.
	# (Up to round-off: plogis(qlogis(p) + 0) is not bit-exact.)
	expect_equal(e$get_coverage_truth("InferenceIncidGCompRiskRatio", "toy", 0, "incidence"), 1, tolerance = 1e-12)
	expect_equal(e$get_coverage_truth("InferenceIncidRiskDiff", "toy", 0, "incidence"), 0, tolerance = 1e-12)
	expect_equal(e$get_coverage_truth("InferenceIncidModifiedPoisson", "toy", 0, "incidence"), 0, tolerance = 1e-12)
	# A class that used to need a Monte Carlo truth now gets 0 directly.
	label <- "InferenceIncidKKCondLogitGLMMOneLik (model_formula=~.) [design_formula=~.]"
	expect_false(is.null(e$get_coverage_mc_spec("InferenceIncidKKCondLogitGLMMOneLik", "incidence")))
	expect_identical(e$get_coverage_truth(label, "toy", 0, "incidence"), 0)
	expect_identical(e$get_estimate_logging_theta(label, "toy", 0, "incidence"), 0)
	expect_identical(e$mc_calls, 0L)
})
