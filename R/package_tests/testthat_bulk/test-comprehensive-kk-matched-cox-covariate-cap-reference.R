library(testthat)
library(EDI)

# TODO-10 (G6 #19, decided 2026-10-22; release_v1_0_5.md G4-C runbook R7): the
# comprehensive harness caps the `~.` Cox adjustment set of the two KK-matched
# Cox classes at the first K = 6 dataset covariates, in the per-row fit and in
# the MC coverage truth alike, with K in the truth cache key. Load only the
# named top-level assignments: sourcing comprehensive_tests.R would start the
# suite.
comprehensive_path <- testthat::test_path("..", "comprehensive_tests.R")
comprehensive_exprs <- parse(comprehensive_path)

load_comprehensive_assignments <- function(wanted, e = new.env(parent = globalenv())) {
	remaining <- wanted
	for (expr in comprehensive_exprs) {
		if (!is.call(expr) || !(identical(expr[[1L]], as.name("=")) || identical(expr[[1L]], as.name("<-"))) || !is.name(expr[[2L]])) next
		name <- as.character(expr[[2L]])
		if (!(name %in% remaining)) next
		eval(expr, envir = e)
		remaining <- setdiff(remaining, name)
	}
	if (length(remaining)) stop("Missing comprehensive assignment(s): ", paste(remaining, collapse = ", "))
	e
}

cap_helpers <- c(
	"COVERAGE_TRUTH_UNAVAILABLE", "KK_MATCHED_COX_COVARIATE_CAP_CLASSES", "KK_MATCHED_COX_COVARIATE_CAP_K",
	"comprehensive_covariate_cap_k", "comprehensive_capped_model_formula",
	"comprehensive_kk_survival_model_formula"
)

test_that("the cap is K = 6, covers exactly the two KK-matched Cox classes, and they stay truth-unavailable", {
	e <- load_comprehensive_assignments(cap_helpers)
	expect_identical(e$KK_MATCHED_COX_COVARIATE_CAP_K, 6L)
	expect_setequal(e$KK_MATCHED_COX_COVARIATE_CAP_CLASSES,
		c("InferenceSurvivalKKStratCoxPHOneLik", "InferenceSurvivalKKLWACoxPHOneLik"))
	# Removal from COVERAGE_TRUTH_UNAVAILABLE waits for the capped-truth
	# convergence check (runbook R7).
	expect_true(all(e$KK_MATCHED_COX_COVARIATE_CAP_CLASSES %in% e$COVERAGE_TRUTH_UNAVAILABLE))
	expect_identical(e$comprehensive_covariate_cap_k("InferenceSurvivalKKStratCoxPHOneLik"), 6L)
	expect_identical(e$comprehensive_covariate_cap_k("InferenceSurvivalKKLWACoxPHOneLik"), 6L)
	expect_identical(e$comprehensive_covariate_cap_k("InferenceSurvivalCoxPHRegr"), NA_integer_)
	expect_identical(e$comprehensive_covariate_cap_k(NA_character_), NA_integer_)
})

test_that("the per-row formula caps only the `~.` arm of the cap classes, on the first K columns", {
	e <- load_comprehensive_assignments(cap_helpers)
	X <- as.data.frame(matrix(0, 3L, 9L, dimnames = list(NULL, c("carat", "cutVery Good", "color^4", paste0("v", 4:9)))))
	capped <- e$comprehensive_kk_survival_model_formula("InferenceSurvivalKKStratCoxPHOneLik", ~ ., X)
	expect_s3_class(capped, "formula")
	expect_identical(all.vars(capped), names(X)[1:6])
	expect_identical(attr(stats::terms(capped), "term.labels"), c("carat", "`cutVery Good`", "`color^4`", "v4", "v5", "v6"))
	expect_identical(all.vars(e$comprehensive_kk_survival_model_formula("InferenceSurvivalKKLWACoxPHOneLik", ~ ., X)), names(X)[1:6])
	# `~1`, NULL and non-cap classes are untouched.
	expect_identical(e$comprehensive_kk_survival_model_formula("InferenceSurvivalKKStratCoxPHOneLik", ~ 1, X), ~ 1)
	expect_null(e$comprehensive_kk_survival_model_formula("InferenceSurvivalKKStratCoxPHOneLik", NULL, X))
	expect_identical(e$comprehensive_kk_survival_model_formula("InferenceSurvivalKKWeibullMarginal", ~ ., X), ~ .)
	# Fewer than K columns: all of them; no columns: unchanged.
	expect_identical(all.vars(e$comprehensive_kk_survival_model_formula("InferenceSurvivalKKStratCoxPHOneLik", ~ ., X[, 1:3])), names(X)[1:3])
	expect_identical(e$comprehensive_kk_survival_model_formula("InferenceSurvivalKKStratCoxPHOneLik", ~ ., X[, 0]), ~ .)
})

test_that("the MC truth uses the same capped formula and a K-specific cache key; other keys are unchanged", {
	e <- load_comprehensive_assignments(c(cap_helpers,
		"coverage_truth_uses_real_covariates", "coverage_truth_cache_key", "coverage_truth_seed",
		"get_coverage_mc_spec", "get_coverage_truth", "COVERAGE_MC_SPEC"))
	e$COVERAGE_CLOSED_FORM <- list()
	e$.coverage_truth_cache <- new.env(parent = emptyenv())
	X <- data.frame(matrix(stats::rnorm(80L), 10L, 8L))
	e$datasets_and_response_models <- list(toy = list(X = X))
	calls <- list()
	e$compute_mc_coverage_truth_simframe <- function(class_gen, design_gen, response_type, dataset_name, beta_T_val, mc_n,
			real_X = NULL, inference_params = NULL) {
		calls[[length(calls) + 1L]] <<- list(class = class_gen$classname, real_X = real_X, inference_params = inference_params, mc_n = mc_n)
		0.25
	}
	# Still unavailable: no MC call at all.
	expect_identical(e$get_coverage_truth("InferenceSurvivalKKStratCoxPHOneLik [design_formula=~.]", "toy", 0.5, "survival"), NA_real_)
	expect_length(calls, 0L)

	# Once released from COVERAGE_TRUTH_UNAVAILABLE (after the convergence
	# check), the truth fits the capped formula against the full real X.
	e$COVERAGE_TRUTH_UNAVAILABLE <- character(0)
	expect_identical(e$get_coverage_truth("InferenceSurvivalKKStratCoxPHOneLik [design_formula=~.]", "toy", 0.5, "survival"), 0.25)
	expect_length(calls, 1L)
	expect_identical(calls[[1L]]$class, "InferenceSurvivalKKStratCoxPHOneLik")
	expect_identical(ncol(calls[[1L]]$real_X), 8L)
	expect_identical(all.vars(calls[[1L]]$inference_params$model_formula), names(X)[1:6])
	expect_identical(calls[[1L]]$mc_n, 3000L)
	capped_key <- e$coverage_truth_cache_key("InferenceSurvivalKKStratCoxPHOneLik", "toy", 0.5, TRUE, "survival", 6L)
	expect_match(capped_key, "||covariate_cap=6", fixed = TRUE)
	expect_true(exists(capped_key, envir = e$.coverage_truth_cache, inherits = FALSE))

	# The `~1` arm has no adjustment set: no cap, no params, historical key.
	e$get_coverage_truth("InferenceSurvivalKKLWACoxPHOneLik [design_formula=~1]", "toy", 0.5, "survival")
	expect_null(calls[[2L]]$real_X)
	expect_null(calls[[2L]]$inference_params)
	expect_true(exists(e$coverage_truth_cache_key("InferenceSurvivalKKLWACoxPHOneLik", "toy", 0.5, FALSE, "survival"),
		envir = e$.coverage_truth_cache, inherits = FALSE))

	# Uncapped classes keep their historical key (and so their seed).
	e$get_coverage_truth("InferenceSurvivalKKWeibullMarginal [design_formula=~.]", "toy", 0, "survival")
	expect_null(calls[[3L]]$inference_params)
	expect_identical(
		e$coverage_truth_cache_key("InferenceSurvivalKKWeibullMarginal", "toy", 0, TRUE, "survival"),
		paste("InferenceSurvivalKKWeibullMarginal", "toy", 0, TRUE, "survival", sep = "||")
	)
	expect_identical(
		e$coverage_truth_cache_key("InferenceSurvivalKKWeibullMarginal", "toy", 0, TRUE, "survival", NA_integer_),
		e$coverage_truth_cache_key("InferenceSurvivalKKWeibullMarginal", "toy", 0, TRUE, "survival")
	)
})

test_that("compute_mc_coverage_truth_simframe forwards inference_params to SimulationFramework by class name", {
	e <- load_comprehensive_assignments(c("prob_censoring", "SD_NOISE", "apply_treatment_effect_and_noise",
		"COVERAGE_MC_TRUTH_DEFAULT_INFERENCE_TYPE", "COVERAGE_MC_TRUTH_RAND_PVAL_CLASSES",
		"coverage_mc_truth_inference_type", "compute_mc_coverage_truth_simframe"))
	e$datasets_and_response_models <- list(toy = list(X = data.frame(a = 1:4), y_original = list(survival = c(1, 2, 3, 4))))
	seen <- list()
	e$SimulationFramework <- list(new = function(..., inference_classes_and_params) {
		seen[[length(seen) + 1L]] <<- inference_classes_and_params
		list(run = function() invisible(NULL))
	})
	e$SimulationFrameworkReport <- list(new = function(sim) list(get_results = function() data.frame(estimate = 0.1)))
	cls <- list(classname = "InferenceSurvivalKKStratCoxPHOneLik")
	e$compute_mc_coverage_truth_simframe(cls, NULL, "survival", "toy", 0, 8L, real_X = data.frame(a = 1:4),
		inference_params = list(model_formula = ~ a))
	expect_identical(names(seen[[1L]]), "InferenceSurvivalKKStratCoxPHOneLik")
	expect_identical(seen[[1L]][[1L]]$model_formula, ~ a)
	e$compute_mc_coverage_truth_simframe(cls, NULL, "survival", "toy", 0, 8L)
	expect_identical(seen[[2L]], list(cls))
})
