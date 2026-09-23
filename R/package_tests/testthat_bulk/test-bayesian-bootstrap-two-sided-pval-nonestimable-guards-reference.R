library(testthat)
library(EDI)

# InferenceBayesianBootstrap's compute_bayesian_bootstrap_two_sided_pval()
# (inference_all_abstract_bayesian_bootstrap.R) shares the exact same shape as its non-Bayesian
# sibling InferenceBootstrap::compute_bootstrap_two_sided_pval() (closed earlier this session in
# test-bootstrap-two-sided-pval-nonestimable-guards-reference.R and
# test-bootstrap-studentized-unstable-standard-errors-guard-reference.R), but has its own distinct
# "bayesian_bootstrap_*" reason strings, none of which had a test reference anywhere:
#   1. "bayesian_bootstrap_nonfinite_estimates": na.rm = FALSE (default) and the Bayesian-bootstrap
#      distribution contains a non-finite draw.
#   2. "bayesian_bootstrap_too_few_finite_estimates": after na.rm = TRUE filtering, too few finite
#      draws remain.
#   3. "bayesian_bootstrap_extreme_finite_estimates": bootstrap_estimates_extreme() flags the
#      distribution as implausibly extreme.
#   4. "bayesian_bootstrap_standard_error_unavailable": the type = "wald" fallback path's own
#      sd(boot_distr) is non-finite/non-positive.
#   5. "bayesian_bootstrap_original_standard_error_unavailable": the studentized path's
#      infer_original_se() is unusable.
#   6. "bayesian_bootstrap_unstable_studentized_standard_errors": the studentized path's pivots are
#      too few.
#   7. "bayesian_bootstrap_bca_pvalue_unavailable": the bca path's pval_bayesian_bca() itself errors.
# All reached via InferenceAllSimpleAverageDiff (the same fixture used for the non-Bayesian sibling
# guards), mocking the public approximate_bayesian_bootstrap_distribution_beta_hat_T() and/or the
# private approximate_bayesian_bootstrap_statistics_beta_hat_T()/infer_original_se()/
# studentized_bootstrap_pivots()/pval_bayesian_bca() (unlockBinding).

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

test_that("'bayesian_bootstrap_nonfinite_estimates' fires when na.rm = FALSE and the distribution has a non-finite draw", {
	f <- smd_boot_fixture()
	unlockBinding("approximate_bayesian_bootstrap_distribution_beta_hat_T", f$inf)
	f$inf$approximate_bayesian_bootstrap_distribution_beta_hat_T <- function(...) c(rnorm(10, 0.5, 0.2), NA_real_)

	pval <- f$inf$compute_bayesian_bootstrap_two_sided_pval(type = "percentile", na.rm = FALSE, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "bayesian_bootstrap_nonfinite_estimates")
})

test_that("'bayesian_bootstrap_too_few_finite_estimates' fires when too few finite draws remain after na.rm = TRUE", {
	f <- smd_boot_fixture(seed = 2L)
	unlockBinding("approximate_bayesian_bootstrap_distribution_beta_hat_T", f$inf)
	f$inf$approximate_bayesian_bootstrap_distribution_beta_hat_T <- function(...) c(0.1, 0.2, NA_real_, NA_real_, NA_real_)

	pval <- f$inf$compute_bayesian_bootstrap_two_sided_pval(type = "percentile", na.rm = TRUE, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "bayesian_bootstrap_too_few_finite_estimates")
})

test_that("'bayesian_bootstrap_extreme_finite_estimates' fires when the distribution is implausibly extreme", {
	f <- smd_boot_fixture(seed = 3L)
	unlockBinding("approximate_bayesian_bootstrap_distribution_beta_hat_T", f$inf)
	f$inf$approximate_bayesian_bootstrap_distribution_beta_hat_T <- function(...) c(2e6, -2e6, 2e6, -2e6, 2e6, -2e6)

	pval <- f$inf$compute_bayesian_bootstrap_two_sided_pval(type = "percentile", min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "bayesian_bootstrap_extreme_finite_estimates")
})

test_that("'bayesian_bootstrap_standard_error_unavailable' fires on the wald fallback path when sd(boot_distr) is unusable", {
	f <- smd_boot_fixture(seed = 4L)
	unlockBinding("approximate_bayesian_bootstrap_distribution_beta_hat_T", f$inf)
	f$inf$approximate_bayesian_bootstrap_distribution_beta_hat_T <- function(...) rep(0.5, 10)  # zero variance

	pval <- f$inf$compute_bayesian_bootstrap_two_sided_pval(type = "wald", min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "bayesian_bootstrap_standard_error_unavailable")
})

test_that("'bayesian_bootstrap_original_standard_error_unavailable' fires when infer_original_se() is unusable", {
	f <- smd_boot_fixture(seed = 5L)
	unlockBinding("approximate_bayesian_bootstrap_statistics_beta_hat_T", f$priv)
	f$priv$approximate_bayesian_bootstrap_statistics_beta_hat_T <- function(...) {
		list(theta = rnorm(10, mean = 0.5, sd = 0.2), se = rep(0.2, 10))
	}
	unlockBinding("infer_original_se", f$priv)
	f$priv$infer_original_se <- function(...) NA_real_

	pval <- f$inf$compute_bayesian_bootstrap_two_sided_pval(type = "studentized", min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "bayesian_bootstrap_original_standard_error_unavailable")
})

test_that("'bayesian_bootstrap_unstable_studentized_standard_errors' fires when studentized_bootstrap_pivots() returns too few pivots", {
	f <- smd_boot_fixture(seed = 6L)
	unlockBinding("approximate_bayesian_bootstrap_statistics_beta_hat_T", f$priv)
	f$priv$approximate_bayesian_bootstrap_statistics_beta_hat_T <- function(...) {
		list(theta = rnorm(10, mean = 0.5, sd = 0.2), se = rep(0.2, 10))
	}
	unlockBinding("studentized_bootstrap_pivots", f$priv)
	f$priv$studentized_bootstrap_pivots <- function(...) c(0.1, 0.2)

	pval <- f$inf$compute_bayesian_bootstrap_two_sided_pval(type = "studentized", min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "bayesian_bootstrap_unstable_studentized_standard_errors")
})

test_that("'bayesian_bootstrap_bca_pvalue_unavailable' fires when pval_bayesian_bca() itself errors", {
	f <- smd_boot_fixture(seed = 7L)
	unlockBinding("approximate_bayesian_bootstrap_distribution_beta_hat_T", f$inf)
	f$inf$approximate_bayesian_bootstrap_distribution_beta_hat_T <- function(...) rnorm(50, mean = 0.5, sd = 0.2)
	unlockBinding("pval_bayesian_bca", f$priv)
	f$priv$pval_bayesian_bca <- function(...) stop("forced failure")

	pval <- f$inf$compute_bayesian_bootstrap_two_sided_pval(type = "bca", min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "bayesian_bootstrap_bca_pvalue_unavailable")
})
