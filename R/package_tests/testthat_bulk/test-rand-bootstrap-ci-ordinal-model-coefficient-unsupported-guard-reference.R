library(testthat)
library(EDI)

# InferenceRandBootstrapCI$compute_rand_bootstrap_confidence_interval() (inference_all_
# abstract_rand_bootstrap_ci.R:88-94) refuses immediately, before any resampling, for
# ordinal model-coefficient estimand classes (EDI_ORDINAL_MODEL_COEFFICIENT_INFERENCE_
# CLASSES, e.g. InferenceOrdinalCauchitRegr) -- the bootstrap-randomization-CI sibling of
# the plain compute_rand_confidence_interval() guard closed earlier this session
# (test-rand-ci-ordinal-model-coefficient-and-log-hazard-ratio-unsupported-guards-
# reference.R). The two guards live in different files with distinct, non-overlapping
# messages ("Randomization-bootstrap confidence intervals..." vs "Randomization confidence
# intervals..."), so covering one does not cover the other. A codebase-wide grep confirmed
# this exact bootstrap-CI message had zero test references anywhere. Exercised via the
# plain public API, no mocking needed: the refusal fires before any bootstrap-resampling
# machinery runs.

test_that("an ordinal model-coefficient class refuses the randomization-bootstrap CI with the documented 'not implemented' message", {
	set.seed(1)
	n <- 30L
	des <- DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	inf <- InferenceOrdinalCauchitRegr$new(des, verbose = FALSE)

	expect_error(
		inf$compute_rand_bootstrap_confidence_interval(B = 21L, show_progress = FALSE),
		"Randomization-bootstrap confidence intervals are not implemented for ordinal model-coefficient estimands.",
		fixed = TRUE
	)
})
