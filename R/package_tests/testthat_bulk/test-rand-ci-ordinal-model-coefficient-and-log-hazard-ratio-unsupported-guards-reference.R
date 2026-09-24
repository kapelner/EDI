library(testthat)
library(EDI)

# InferenceRandCI$compute_rand_confidence_interval() (inference_all_abstract_rand_ci.R:183-258)
# refuses, ahead of any real search, for two disjoint class families registered in
# inference_class_registry.R:
#   1. Ordinal model-coefficient estimand classes (EDI_ORDINAL_MODEL_COEFFICIENT_INFERENCE_
#      CLASSES, e.g. InferenceOrdinalCauchitRegr): "Randomization confidence intervals are not
#      implemented for ordinal model-coefficient estimands." -- the AFT sharp-null transform
#      has no counterpart for a cumulative-link model coefficient.
#   2. Log-hazard-ratio estimand classes (EDI_LOG_HAZARD_RATIO_INFERENCE_CLASSES, e.g. the
#      plain InferenceSurvivalCoxPHRegr, distinct from the already-tested stratified-Cox
#      sibling): "...the estimator units (Log-Hazard Ratio) are inconsistent with the
#      randomization test's required transformed scale (Log-Time Ratio / AFT effect)..." --
#      the Cox model has no shape parameter linking a log-hazard-ratio axis to the log-time
#      axis the AFT sharp null is imposed on.
# A codebase-wide grep confirmed both exact messages had zero test references anywhere --
# distinct from the five OTHER "Randomization confidence intervals are not supported for..."
# guards already covered elsewhere (RMST, stratified Cox, Gehan-Wilcox, KM-diff, log-rank),
# none of which share this message text. Exercised via the plain public API, no mocking
# needed: both refusals fire before any permutation/bisection machinery runs.

test_that("an ordinal model-coefficient class refuses with the documented 'not implemented' message", {
	set.seed(1)
	n <- 30L
	des <- DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	inf <- InferenceOrdinalCauchitRegr$new(des, verbose = FALSE)

	expect_error(
		inf$compute_rand_confidence_interval(r = 21L, show_progress = FALSE),
		"Randomization confidence intervals are not implemented for ordinal model-coefficient estimands.",
		fixed = TRUE
	)
})

test_that("a log-hazard-ratio class (plain Cox PH, not the stratified sibling) refuses with the inconsistent-scale message", {
	set.seed(2)
	n <- 30L
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rexp(n, rate = exp(0.3 * w)))
	inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)

	expect_error(
		inf$compute_rand_confidence_interval(r = 21L, show_progress = FALSE),
		"Randomization confidence intervals are not supported for InferenceSurvivalCoxPHRegr because the estimator units (Log-Hazard Ratio) are inconsistent",
		fixed = TRUE
	)
})
