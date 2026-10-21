library(testthat)
library(EDI)

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
		"SD_NOISE",
		"prop_logistic_normal_mean",
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
		"coverage_truth_seed",
		"get_coverage_mc_spec",
		"get_coverage_truth",
		"record_result",
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

test_that("proportion mean-difference truth is the noisy marginal contrast (owner decision 2026-10-21)", {
	e <- truth_fixture()
	beta <- 0.5
	p <- e$datasets_and_response_models$toy$y_original$proportion
	ref <- logit_shift_reference(p, beta)
	zero_noise <- mean(ref$p_t - ref$p_base)
	# Independent oracle: integrate() per baseline, noise in both arms.
	lnm <- function(p_i, shift) stats::integrate(
		function(eps) stats::plogis(stats::qlogis(p_i) + shift + eps) * stats::dnorm(eps, 0, e$SD_NOISE),
		-Inf, Inf, rel.tol = 1e-12)$value
	expected <- mean(vapply(ref$p_base, function(p_i) lnm(p_i, beta) - lnm(p_i, 0), numeric(1)))

	expect_equal(e$compute_prop_mean_diff_coverage_truth("toy", beta), expected, tolerance = 1e-10)
	expect_equal(e$compute_prop_mean_diff_coverage_truth("toy", 0), 0, tolerance = 1e-12)
	# Distinct from the zero-noise contrast, but only at the 1e-4 scale.
	expect_gt(abs(expected - zero_noise), 1e-5)
	expect_lt(abs(expected - zero_noise), 1e-3)

	stale_additive_truth <- mean(pmin(1, pmax(0, p + beta)) - p)
	expect_gt(abs(stale_additive_truth - expected), 0.1)
})

test_that("all proportion mean-difference classes dispatch to the corrected truth", {
	e <- truth_fixture()
	beta <- 0.5
	expected <- e$compute_prop_mean_diff_coverage_truth("toy", beta)

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

test_that("record_result stores coverage truth and checks the CI against it, not beta_T", {
	e <- truth_fixture()
	beta <- 0.5
	p <- e$datasets_and_response_models$toy$y_original$proportion
	ref <- logit_shift_reference(p, beta)
	logistic_normal_mean <- function(p_i, shift) stats::integrate(
		function(eps) stats::plogis(stats::qlogis(p_i) + shift + eps) *
			stats::dnorm(eps, mean = 0, sd = e$SD_NOISE),
		-Inf, Inf, rel.tol = 1e-12)$value
	expected_truth <- mean(vapply(ref$p_base, function(p_i) {
		logistic_normal_mean(p_i, beta) - logistic_normal_mean(p_i, 0)
	}, numeric(1)))
	ci <- c(expected_truth - 0.01, expected_truth + 0.01)
	expect_false(beta >= min(ci) && beta <= max(ci))

	e$beta_T <- beta
	e$rep_curr <- 1L
	e$run_row_id <- 0L
	e$results_dt <- data.table::data.table()
	e$GITHUB_COMMIT_ID <- "test-commit"
	e$HEARTBEAT_LOG_FILE <- ""
	e$r <- 1L
	e$pval_epsilon <- 1e-12
	e$prob_censoring <- 0
	e$NUM_CORES <- 1L
	e$data.table <- data.table::data.table
	e$sleep_adjust_duration <- function(duration, start_epoch, end_epoch) {
		list(adjusted = duration, sleep_adjustment = 0)
	}
	e$round_duration_field <- identity
	e$round_result_field <- as.numeric
	e$method_family_for_function_run <- function(...) "asymp"
	e$skip_reason_for_result <- function(...) ""
	e$build_result_key <- function(...) "synthetic-row-id"
	e$build_comprehensive_case_id <- function(...) "synthetic-case-id"
	e$cache_estimate_logging_theta <- function(...) invisible(NULL)
	e$mark_row_completed <- function(...) invisible(NULL)
	e$record_comprehensive_attempt_event <- function(...) invisible(NULL)
	e$write_results_if_needed <- function(...) invisible(NULL)

	e$record_result(
		dataset_name = "toy",
		dataset_n_rows = length(p),
		dataset_n_cols = 1L,
		response_type = "proportion",
		design_type = "Bernoulli",
		inference_class = "InferencePropGCompMeanDiff [model_formula=~1]",
		function_run = "compute_confidence_interval_asymp",
		result = ci,
		status = "ok",
		duration_time_sec = 1,
		start_epoch = 100,
		end_epoch = 101
	)

	row <- e$results_dt[1L]
	expect_equal(row$coverage_truth[[1L]], expected_truth, tolerance = 1e-15)
	expect_gt(abs(row$coverage_truth[[1L]] - row$beta_T[[1L]]), 0.1)
	expect_true(row$coverage_truth[[1L]] >= min(ci) && row$coverage_truth[[1L]] <= max(ci))
	expect_identical(row$beta_T_in_confidence_interval[[1L]], TRUE)
})

test_that("the selected noisy-marginal truth matches retained quadrature values", {
	# Integrating treated and control means separately makes this oracle
	# independent of the selected Gauss-Hermite implementation.
	logistic_normal_mean <- function(p, beta, sd_noise) {
		stats::integrate(
			function(eps) stats::plogis(stats::qlogis(p) + beta + eps) *
				stats::dnorm(eps, mean = 0, sd = sd_noise),
			lower = -Inf, upper = Inf, rel.tol = 1e-12
		)$value
	}

	p <- c(0.1, 0.2, 0.5, 0.8, 0.9)
	beta <- 0.5
	sd_noise <- 0.1
	zero_noise <- stats::plogis(stats::qlogis(p) + beta) - p
	noisy_marginal <- vapply(p, function(p_i) {
		logistic_normal_mean(p_i, beta, sd_noise) -
			logistic_normal_mean(p_i, 0, sd_noise)
	}, numeric(1))

	# Independent quadrature values retained in the linked TODO-55 sensitivity
	# note; these pin the chosen truth, not an empirical-coverage threshold.
	expect_equal(zero_noise, c(
		0.05482809896, 0.09187513274, 0.12245933120, 0.06833243833, 0.03686267382
	), tolerance = 1e-10)
	expect_equal(noisy_marginal, c(
		0.05491920733, 0.09182481165, 0.12217284861, 0.06839061025, 0.03696400487
	), tolerance = 1e-10)
	expect_gt(max(abs(noisy_marginal - zero_noise)), 2e-4)
	e <- truth_fixture()
	e$datasets_and_response_models$toy$y_original$proportion <- p
	expect_equal(e$compute_prop_mean_diff_coverage_truth("toy", beta), mean(noisy_marginal), tolerance = 1e-10)
})
