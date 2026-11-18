library(testthat)
library(EDI)

# inference_all_abstract_rand.R's approximate_randomization_distribution_beta_hat_T() (a public
# method, directly callable and bypassing compute_rand_two_sided_pval()'s own Zhang-dispatch/
# supports_rand_pval_for_incidence() gating entirely) has two sibling nonzero-delta guards inside its
# setup_randomization_template_and_shifts() helper: an incidence-response instance with no custom
# randomization statistic errors "randomization tests with delta nonzero not supported for
# incidence". (A sibling guard refused any design with interval-/left-censored survival data (a finite
# y_R); the v1.0.6-TODO-143 follow-up lifted it, so that case now runs.) Both were reachable even on a Zhang-eligible or otherwise fully-supported
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

# v1.0.6-TODO-143 follow-up (owner decision 2026-11-18): the interval-censoring refusal was lifted; a
# nonzero delta now shifts y_L / y_R along with y.
test_that("approximate_randomization_distribution_beta_hat_T(): a nonzero delta on a design with interval-censored data runs and moves the null distribution", {
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

	inf$set_seed(1)
	d0 <- inf$approximate_randomization_distribution_beta_hat_T(r = 20, delta = 0, transform_responses = "log", show_progress = FALSE)
	inf$set_seed(1)
	d3 <- inf$approximate_randomization_distribution_beta_hat_T(r = 20, delta = 0.3, transform_responses = "log", show_progress = FALSE)
	expect_length(d3, 20L)
	expect_true(sum(is.finite(d3)) >= 10L)
	expect_false(isTRUE(all.equal(d0, d3)))
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

test_that("public incidence randomization p-value rejects a nonzero shift before generating draws", {
	set.seed(4L)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1L, 0.5))
	inf <- InferenceIncidRiskDiff$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	draw_calls <- 0L
	unlockBinding("generate_permutations", priv)
	priv$generate_permutations <- function(...) {
		draw_calls <<- draw_calls + 1L
		stop("sentinel: permutation generation was reached", call. = FALSE)
	}

	expect_error(
		inf$compute_rand_two_sided_pval(delta = 0.3, show_progress = FALSE),
		"randomization tests with delta nonzero not supported for incidence"
	)
	expect_identical(draw_calls, 0L)
})
