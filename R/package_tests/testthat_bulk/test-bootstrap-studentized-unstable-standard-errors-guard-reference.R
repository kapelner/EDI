library(testthat)
library(EDI)

# InferenceBootstrap's compute_bootstrap_two_sided_pval() studentized/bootstrap-t path
# (inference_all_abstract_non_param_boot.R) has a guard with two distinct triggers, sharing the
# single reason "bootstrap_unstable_studentized_standard_errors", neither of which had a test
# reference anywhere (a sibling of the 5 guards on this same method closed in
# test-bootstrap-two-sided-pval-nonestimable-guards-reference.R earlier this session):
#   1. studentized_bootstrap_pivots() itself returns too few pivots (fewer than
#      min_number_usable_samples).
#   2. the pivots are numerous enough, but studentized_interval_scale_unstable() flags the
#      resulting interval as implausibly wide relative to the original SE.
# Both reached via InferenceAllSimpleAverageDiff (the same fixture already used for the sibling
# guards), mocking studentized_bootstrap_pivots() and studentized_interval_scale_unstable()
# respectively (unlockBinding, private).

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

test_that("'bootstrap_unstable_studentized_standard_errors' fires when studentized_bootstrap_pivots() returns too few pivots", {
	f <- smd_boot_fixture()
	unlockBinding("approximate_bootstrap_statistics_beta_hat_T", f$priv)
	f$priv$approximate_bootstrap_statistics_beta_hat_T <- function(...) {
		list(theta = rnorm(10, mean = 0.5, sd = 0.2), se = rep(0.2, 10))
	}
	unlockBinding("studentized_bootstrap_pivots", f$priv)
	f$priv$studentized_bootstrap_pivots <- function(...) c(0.1, 0.2)  # fewer than min_number_usable_samples

	pval <- f$inf$compute_bootstrap_two_sided_pval(type = "studentized", min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "bootstrap_unstable_studentized_standard_errors")
})

test_that("'bootstrap_unstable_studentized_standard_errors' fires when studentized_interval_scale_unstable() flags the interval", {
	f <- smd_boot_fixture(seed = 6L)
	unlockBinding("approximate_bootstrap_statistics_beta_hat_T", f$priv)
	f$priv$approximate_bootstrap_statistics_beta_hat_T <- function(...) {
		list(theta = rnorm(10, mean = 0.5, sd = 0.2), se = rep(0.2, 10))
	}
	unlockBinding("studentized_interval_scale_unstable", f$priv)
	f$priv$studentized_interval_scale_unstable <- function(...) TRUE

	pval <- f$inf$compute_bootstrap_two_sided_pval(type = "studentized", min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "bootstrap_unstable_studentized_standard_errors")
})
