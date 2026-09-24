library(testthat)
library(EDI)

# InferenceRandBootstrapCI's compute_rand_bootstrap_confidence_interval() (inference_all_abstract_
# rand_bootstrap_ci.R) emits an informational message when B is too small for the requested alpha --
# the Monte Carlo p-value floor 2/B is >= alpha/2, so the search can never bracket and both bounds
# degrade to the conservative search boundary. The sibling "conservative bound" messages tied to
# rand_bootstrap_ci_conservative_count are already covered elsewhere, but this specific upfront
# "B is too small for alpha" message had no test reference anywhere (confirmed via a zero-hit grep for
# its literal text). Reached with the same InferenceAllSimpleAverageDiff fixture already established
# for this file's sibling guard tests, just with B small enough (25, well under the alpha = 0.05
# threshold of B > 80) to trigger it on an ordinary, otherwise-successful call -- no mocking needed.

test_that("a B too small for the requested alpha emits the documented 'too small' message", {
	set.seed(1L); n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1L)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.5))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L

	expect_message(
		ci <- inf$compute_rand_bootstrap_confidence_interval(B = 25L, alpha = 0.05, show_progress = FALSE, type = "percentile"),
		"B = 25 is too small for alpha = 0.05.*p-value floor 2/B = 0\\.08.*Use B > 80"
	)
	expect_length(ci, 2L)
})

test_that("a B large enough for the requested alpha does NOT emit the 'too small' message", {
	set.seed(2L); n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 2L)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.5))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L

	expect_no_message(
		inf$compute_rand_bootstrap_confidence_interval(B = 201L, alpha = 0.05, show_progress = FALSE, type = "percentile"),
		message = "is too small for alpha"
	)
})
