library(testthat)
library(EDI)

# Three sibling survival inference classes each unconditionally reject compute_rand_confidence_
# interval() with a class-specific "inconsistent estimator units" message, because their point
# estimate's scale isn't commensurate with the time-ratio null the randomization-CI bisection search
# assumes: InferenceSurvivalGehanWilcox (inference_survival_gehan_wilcox.R, Peto-Prentice score
# scale), InferenceSurvivalKMDiff (inference_survival_km_diff.R, transformed scale), and
# InferenceSurvivalLogRank (inference_survival_log_rank.R, log-rank score scale) -- the identical
# guard on their sibling InferenceSurvivalRestrictedMeanDiff is already tested. A codebase-wide grep
# confirmed none of these 3 exact messages had any test reference anywhere, despite all 3 classes
# being otherwise extensively tested elsewhere (including the analogous "non-zero delta not yet
# implemented" guard on two of them, e.g. test-gehan-wilcox-nonzero-delta-not-yet-implemented-
# reference.R, whose fixture this file reuses).

fx <- function(seed, n = 40L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rexp(n, exp(0.3 * w)))
	des
}

test_that("InferenceSurvivalGehanWilcox rejects compute_rand_confidence_interval() with the documented message", {
	inf <- InferenceSurvivalGehanWilcox$new(fx(1L), verbose = FALSE)
	expect_error(
		inf$compute_rand_confidence_interval(),
		"Randomization confidence intervals are not supported for InferenceSurvivalGehanWilcox due to inconsistent estimator units on the Peto-Prentice score scale.",
		fixed = TRUE
	)
})

test_that("InferenceSurvivalKMDiff rejects compute_rand_confidence_interval() with the documented message", {
	inf <- InferenceSurvivalKMDiff$new(fx(2L), verbose = FALSE)
	expect_error(
		inf$compute_rand_confidence_interval(),
		"Randomization confidence intervals are not supported for InferenceSurvivalKMDiff due to inconsistent estimator units on the transformed scale.",
		fixed = TRUE
	)
})

test_that("InferenceSurvivalLogRank rejects compute_rand_confidence_interval() with the documented message", {
	inf <- InferenceSurvivalLogRank$new(fx(3L), verbose = FALSE)
	expect_error(
		inf$compute_rand_confidence_interval(),
		"Randomization confidence intervals are not supported for InferenceSurvivalLogRank due to inconsistent estimator units on the log-rank score scale.",
		fixed = TRUE
	)
})
