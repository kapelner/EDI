library(testthat)
library(EDI)

# A Bayesian-bootstrap reweighting can leave a Kaplan-Meier curve above 0.5,
# so the weighted median and the treatment-minus-control median difference are
# non-finite for that draw. InferenceSurvivalKMDiff filters those draws by
# default, but retains the caller's explicit na.rm = FALSE choice and the
# generic minimum-usable-draw guard.

km_bb_fixture <- function(seed = 1901L, bootstrap_seed = 4L) {
	set.seed(seed)
	n <- 100L
	des <- DesignFixedBernoulli$new(
		n = n, response_type = "survival", seed = seed, verbose = FALSE
	)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	event_time <- rexp(n, rate = 0.5 * exp(-0.25 * w))
	censor_time <- rexp(n, rate = 0.3)
	y <- pmin(event_time, censor_time)
	dead <- as.integer(event_time <= censor_time)
	des$add_all_subject_responses(
		ifelse(dead == 1L, y, NA_real_),
		ifelse(dead == 0L, y, NA_real_),
		ifelse(dead == 0L, Inf, NA_real_)
	)
	inf <- InferenceSurvivalKMDiff$new(des, verbose = FALSE)
	inf$set_seed(bootstrap_seed)
	inf$num_cores <- 1L
	inf
}

stub_km_bb_distribution <- function(inf, values) {
	unlockBinding("approximate_bayesian_bootstrap_distribution_beta_hat_T", inf)
	inf$approximate_bayesian_bootstrap_distribution_beta_hat_T <- function(...) values
	invisible(inf)
}

test_that("KM-difference Bayesian p-values drop occasional undefined weighted medians by default", {
	inf <- km_bb_fixture()
	draws <- inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(
		B = 101L, show_progress = FALSE
	)
	expect_gt(sum(!is.finite(draws)), 0L)
	expect_gte(sum(is.finite(draws)), 5L)

	# Use a fresh object because this assertion is about the public p-value's
	# default policy, independently of a preceding distribution-only call.
	pval <- km_bb_fixture()$compute_bayesian_bootstrap_two_sided_pval(
		B = 101L, show_progress = FALSE
	)
	expect_true(is.finite(pval))
	expect_gte(pval, 0)
	expect_lte(pval, 1)
})

test_that("KM-difference Bayesian p-values retain explicit fail-on-nonfinite behavior", {
	inf <- km_bb_fixture(bootstrap_seed = 5L)
	stub_km_bb_distribution(inf, c(-0.2, -0.1, 0, 0.1, 0.2, NA_real_))

	pval <- inf$compute_bayesian_bootstrap_two_sided_pval(
		B = 6L, na.rm = FALSE, show_progress = FALSE
	)
	expect_true(is.na(pval))
	expect_identical(
		inf$get_nonestimable_reason(),
		"bayesian_bootstrap_nonfinite_estimates"
	)
})

test_that("KM-difference Bayesian p-values type too few finite weighted medians", {
	inf <- km_bb_fixture(bootstrap_seed = 6L)
	stub_km_bb_distribution(inf, c(-0.1, 0.1, NA_real_, Inf, NA_real_))

	pval <- inf$compute_bayesian_bootstrap_two_sided_pval(
		B = 5L, min_number_usable_samples = 3L, show_progress = FALSE
	)
	expect_true(is.na(pval))
	expect_identical(
		inf$get_nonestimable_reason(),
		"bayesian_bootstrap_too_few_finite_estimates"
	)
})
