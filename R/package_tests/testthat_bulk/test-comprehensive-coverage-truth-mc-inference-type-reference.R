library(testthat)
library(EDI)

# TODO-126 follow-up (release_v1_0_5.md, 2026-10-22): the coverage-truth Monte
# Carlo (compute_mc_coverage_truth_simframe() in comprehensive_tests.R) reads
# only res$estimate, which SimulationFramework computes with compute_estimate()
# before any inference type runs. It now requests the cheap `asymp_pval`
# instead of the 201-draw `rand_pval`, replaying the same draw with `rand_pval`
# when the class yields no `asymp_pval` row. Load only the named top-level
# assignments: sourcing comprehensive_tests.R would start the suite.
comprehensive_path <- testthat::test_path("..", "comprehensive_tests.R")
comprehensive_exprs <- parse(comprehensive_path)

mc_type_fixture <- function() {
	e <- new.env(parent = globalenv())
	wanted <- c("prob_censoring", "SD_NOISE_BY_RESPONSE_TYPE", "sd_noise_for", "apply_treatment_effect_and_noise",
		"COVERAGE_MC_TRUTH_DEFAULT_INFERENCE_TYPE", "COVERAGE_MC_TRUTH_RAND_PVAL_CLASSES",
		"coverage_mc_truth_inference_type", "compute_mc_coverage_truth_simframe")
	remaining <- wanted
	for (expr in comprehensive_exprs) {
		if (!is.call(expr) || !(identical(expr[[1L]], as.name("=")) || identical(expr[[1L]], as.name("<-"))) || !is.name(expr[[2L]])) next
		name <- as.character(expr[[2L]])
		if (!(name %in% remaining)) next
		eval(expr, envir = e)
		remaining <- setdiff(remaining, name)
	}
	if (length(remaining)) stop("Missing comprehensive assignment(s): ", paste(remaining, collapse = ", "))
	set.seed(11L)
	n0 <- 40L
	X <- data.frame(x1 = stats::rnorm(n0), x2 = stats::rnorm(n0))
	e$toy_X <- X
	e$datasets_and_response_models <- list(toy = list(X = X, y_original = list(
		survival = exp(1 + 0.5 * X$x1 + stats::rnorm(n0, 0, 0.5)),
		continuous = X$x1 + stats::rnorm(n0)
	)))
	e
}

# Stub SimulationFramework/Report: records the requested inference types and
# the RNG state at construction; `rows_for(type)` decides whether a row comes back.
install_simframe_stub <- function(e, rows_for) {
	log <- new.env(parent = emptyenv())
	log$types <- character(0)
	log$seeds <- list()
	e$SimulationFramework <- list(new = function(..., inference_types_and_params) {
		type <- names(inference_types_and_params)
		log$types <- c(log$types, type)
		log$seeds[[length(log$seeds) + 1L]] <- get(".Random.seed", envir = .GlobalEnv)
		draw <- stats::runif(1L)
		if (identical(type, "asymp_pval")) warning("stub first-attempt warning")
		list(run = function() invisible(NULL), type = type, draw = draw)
	})
	e$SimulationFrameworkReport <- list(new = function(sim) list(get_results = function() {
		if (rows_for(sim$type)) data.frame(inference_type = sim$type, estimate = sim$draw) else data.frame(estimate = numeric(0))
	}))
	log
}

test_that("the MC truth requests asymp_pval by default and rand_pval only for listed classes", {
	e <- mc_type_fixture()
	expect_identical(e$COVERAGE_MC_TRUTH_DEFAULT_INFERENCE_TYPE, "asymp_pval")
	expect_identical(e$coverage_mc_truth_inference_type("InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik"), "asymp_pval")
	expect_identical(e$coverage_mc_truth_inference_type(NA_character_), "asymp_pval")
	e$COVERAGE_MC_TRUTH_RAND_PVAL_CLASSES <- "InferenceFoo"
	expect_identical(e$coverage_mc_truth_inference_type("InferenceFoo"), "rand_pval")
	expect_identical(e$coverage_mc_truth_inference_type("InferenceBar"), "asymp_pval")
})

test_that("a supported cheap type runs once and never runs rand_pval", {
	e <- mc_type_fixture()
	log <- install_simframe_stub(e, rows_for = function(type) TRUE)
	set.seed(5L)
	expect_warning(
		truth <- e$compute_mc_coverage_truth_simframe(list(classname = "InferenceX"), NULL, "survival", "toy", 0, 10L),
		"stub first-attempt warning"
	)
	expect_identical(log$types, "asymp_pval")
	expect_true(is.finite(truth))
})

test_that("zero asymp_pval rows replay rand_pval from the same RNG state", {
	e <- mc_type_fixture()
	log <- install_simframe_stub(e, rows_for = function(type) identical(type, "rand_pval"))
	set.seed(6L)
	expect_no_warning(
		truth <- e$compute_mc_coverage_truth_simframe(list(classname = "InferenceX"), NULL, "survival", "toy", 0, 10L)
	)
	expect_identical(log$types, c("asymp_pval", "rand_pval"))
	expect_identical(log$seeds[[1L]], log$seeds[[2L]])
	# Same value as the old rand_pval-only request from the same seed.
	log2 <- install_simframe_stub(e, rows_for = function(type) TRUE)
	set.seed(6L)
	old <- e$compute_mc_coverage_truth_simframe(list(classname = "InferenceX"), NULL, "survival", "toy", 0, 10L,
		inference_type = "rand_pval")
	expect_identical(log2$types, "rand_pval")
	expect_identical(truth, old)
})

test_that("real SimulationFramework: the truth estimate is identical under rand_pval and the default", {
	skip_on_cran()
	e <- mc_type_fixture()
	old_beta <- if (exists("beta_T", envir = globalenv(), inherits = FALSE)) get("beta_T", envir = globalenv()) else NULL
	on.exit(if (is.null(old_beta)) rm("beta_T", envir = globalenv()) else assign("beta_T", old_beta, envir = globalenv()), add = TRUE)
	assign("beta_T", 0.5, envir = globalenv())
	run <- function(type) {
		set.seed(20261022L)
		suppressWarnings(e$compute_mc_coverage_truth_simframe(
			InferenceSurvivalCoxPHRegr, DesignFixedBernoulli, "survival", "toy", 0.5, 80L,
			real_X = e$toy_X, inference_type = type))
	}
	old <- run("rand_pval")
	new <- run(e$coverage_mc_truth_inference_type("InferenceSurvivalCoxPHRegr"))
	expect_true(is.finite(old))
	expect_identical(new, old)
})
