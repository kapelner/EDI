library(testthat)
library(EDI)

# InferenceBootstrap's compute_bootstrap_two_sided_pval() (inference_all_abstract_non_param_boot.R)
# has several distinct nonestimable guards after the original estimate is confirmed finite, none of
# which had a test reference anywhere:
#   1. "bootstrap_too_few_finite_estimates": the (percentile/symmetric/bca) bootstrap distribution has
#      fewer than min_number_usable_samples finite draws.
#   2. "bootstrap_too_few_finite_standard_errors": the SAME shortfall, but on the studentized path's
#      theta vector (a distinct branch -- reported as an SE guard, not an estimate guard).
#   3. "bootstrap_extreme_finite_estimates": bootstrap_estimates_extreme() flags the (finite, numerous
#      enough) bootstrap distribution as implausibly wide/extreme relative to the original estimate.
#   4. "bootstrap_original_standard_error_unavailable": the studentized path's own original-estimate
#      SE (infer_original_se()) is non-finite/non-positive.
#   5. "bootstrap_pvalue_unavailable": the bca path's pval_bca() itself errors.
# All reached via InferenceAllSimpleAverageDiff (already used for the sibling jackknife guards closed
# earlier this session), mocking the public approximate_bootstrap_distribution_beta_hat_T() and/or
# the private approximate_bootstrap_statistics_beta_hat_T()/infer_original_se()/pval_bca() -- the
# same unlockBinding-override technique already used throughout this suite.

smd_boot_fixture <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- w + rnorm(n, sd = 0.5)
	des$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("'bootstrap_too_few_finite_estimates' fires when the percentile-path distribution has too few finite draws", {
	f <- smd_boot_fixture()
	unlockBinding("approximate_bootstrap_distribution_beta_hat_T", f$inf)
	f$inf$approximate_bootstrap_distribution_beta_hat_T <- function(...) c(0.1, 0.2, NA_real_, NA_real_, NA_real_)

	pval <- f$inf$compute_bootstrap_two_sided_pval(type = "percentile", na.rm = TRUE, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "bootstrap_too_few_finite_estimates")
})

test_that("'bootstrap_too_few_finite_standard_errors' fires when the studentized-path theta vector has too few finite draws", {
	f <- smd_boot_fixture(seed = 2L)
	unlockBinding("approximate_bootstrap_statistics_beta_hat_T", f$priv)
	f$priv$approximate_bootstrap_statistics_beta_hat_T <- function(...) {
		list(theta = c(0.1, 0.2, NA_real_, NA_real_, NA_real_), se = c(0.3, 0.3, NA_real_, NA_real_, NA_real_))
	}

	pval <- f$inf$compute_bootstrap_two_sided_pval(type = "studentized", na.rm = TRUE, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "bootstrap_too_few_finite_standard_errors")
})

test_that("'bootstrap_extreme_finite_estimates' fires when the bootstrap distribution is implausibly extreme", {
	f <- smd_boot_fixture(seed = 3L)
	unlockBinding("approximate_bootstrap_distribution_beta_hat_T", f$inf)
	f$inf$approximate_bootstrap_distribution_beta_hat_T <- function(...) c(2e6, -2e6, 2e6, -2e6, 2e6, -2e6)

	pval <- f$inf$compute_bootstrap_two_sided_pval(type = "percentile", min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "bootstrap_extreme_finite_estimates")
})

test_that("'bootstrap_original_standard_error_unavailable' fires when infer_original_se() is unusable", {
	f <- smd_boot_fixture(seed = 4L)
	unlockBinding("approximate_bootstrap_statistics_beta_hat_T", f$priv)
	f$priv$approximate_bootstrap_statistics_beta_hat_T <- function(...) {
		theta <- rnorm(10, mean = 0.5, sd = 0.2)
		list(theta = theta, se = rep(0.2, 10))
	}
	unlockBinding("infer_original_se", f$priv)
	f$priv$infer_original_se <- function(...) NA_real_

	pval <- f$inf$compute_bootstrap_two_sided_pval(type = "studentized", min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "bootstrap_original_standard_error_unavailable")
})

test_that("'bootstrap_pvalue_unavailable' fires when the bca path's pval_bca() itself errors", {
	f <- smd_boot_fixture(seed = 5L)
	unlockBinding("approximate_bootstrap_distribution_beta_hat_T", f$inf)
	f$inf$approximate_bootstrap_distribution_beta_hat_T <- function(...) rnorm(50, mean = 0.5, sd = 0.2)
	unlockBinding("pval_bca", f$priv)
	f$priv$pval_bca <- function(...) stop("forced failure")

	pval <- f$inf$compute_bootstrap_two_sided_pval(type = "bca", min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "bootstrap_pvalue_unavailable")
})
