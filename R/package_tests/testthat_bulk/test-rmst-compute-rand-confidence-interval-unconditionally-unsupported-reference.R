library(testthat)
library(EDI)

# InferenceSurvivalRestrictedMeanDiff$compute_rand_confidence_interval() unconditionally stop()s -- randomization
# confidence intervals are not supported for this class at all (its estimator is a time difference, but the
# randomization-CI machinery searches on the log-time-ratio scale, an inconsistent unit) -- regardless of alpha,
# censoring type, or any other argument. No test anywhere called this method; the class's other randomization-
# adjacent methods (compute_rand_two_sided_pval, its "TO-DO" nonzero-delta guard) are covered elsewhere.

make_design <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w(); y <- rexp(n, 0.15 * exp(0.4 * w)); dead <- rbinom(n, 1, 0.75)
	des$add_all_subject_responses(ifelse(dead == 1, y, NA_real_), ifelse(dead == 0, y, NA_real_), ifelse(dead == 0, Inf, NA_real_))
	des
}

test_that("compute_rand_confidence_interval() always errors with an informative message naming the unit mismatch", {
	inf <- InferenceSurvivalRestrictedMeanDiff$new(make_design(), verbose = FALSE)
	expect_error(
		inf$compute_rand_confidence_interval(alpha = 0.05),
		"Randomization confidence intervals are not supported for InferenceSurvivalRestrictedMeanDiff"
	)
	expect_error(inf$compute_rand_confidence_interval(alpha = 0.05), "log-time ratio")
})

test_that("the error fires regardless of alpha or other arguments", {
	inf <- InferenceSurvivalRestrictedMeanDiff$new(make_design(seed = 2L), verbose = FALSE)
	for (a in c(0.01, 0.1, 0.5)) {
		expect_error(inf$compute_rand_confidence_interval(alpha = a), "not supported")
	}
	expect_error(inf$compute_rand_confidence_interval(alpha = 0.05, r = 10L, show_progress = FALSE), "not supported")
})
