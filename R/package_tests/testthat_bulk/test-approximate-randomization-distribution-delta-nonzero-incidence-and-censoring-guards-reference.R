library(testthat)
library(EDI)

# inference_all_abstract_rand.R's approximate_randomization_distribution_beta_hat_T() (a public
# method, directly callable and bypassing compute_rand_two_sided_pval()'s own Zhang-dispatch/
# supports_rand_pval_for_incidence() gating entirely) has two sibling nonzero-delta guards inside its
# setup_randomization_template_and_shifts() helper: an incidence-response instance with no custom
# randomization statistic errors "randomization tests with delta nonzero not supported for
# incidence", and any instance whose design has interval-/left-censored survival data (a finite
# y_R) errors "randomization tests with delta nonzero are not yet supported for left-/interval-
# censored survival data." Both reachable even on a Zhang-eligible or otherwise fully-supported
# instance, since this lower-level method has no incidence/censoring gating of its own before this
# point. Zero test references anywhere for either message.

test_that("approximate_randomization_distribution_beta_hat_T(): a nonzero delta on an incidence-response instance errors with the documented message", {
	set.seed(1)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidRiskDiff$new(des, verbose = FALSE)

	expect_error(
		inf$approximate_randomization_distribution_beta_hat_T(r = 20, delta = 0.3, show_progress = FALSE),
		"randomization tests with delta nonzero not supported for incidence"
	)
})

test_that("approximate_randomization_distribution_beta_hat_T(): a nonzero delta on a design with interval-censored data errors with the documented message", {
	set.seed(2)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	for (i in seq_len(n)) {
		if (i == 1L) {
			des$add_one_subject_response(i, y_L = 1, y_R = 2)
		} else {
			des$add_one_subject_response(i, y = i + 0.5)
		}
	}
	inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)

	expect_error(
		inf$approximate_randomization_distribution_beta_hat_T(r = 20, delta = 0.3, show_progress = FALSE),
		"randomization tests with delta nonzero are not yet supported for left-/interval-censored survival data\\."
	)
})

test_that("approximate_randomization_distribution_beta_hat_T(): delta = 0 on both fixtures does not error", {
	set.seed(3)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidRiskDiff$new(des, verbose = FALSE)
	expect_no_error(inf$approximate_randomization_distribution_beta_hat_T(r = 20, delta = 0, show_progress = FALSE))
})
