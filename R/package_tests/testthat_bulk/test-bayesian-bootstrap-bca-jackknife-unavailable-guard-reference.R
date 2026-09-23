library(testthat)
library(EDI)

# InferenceBayesianBootstrap's BCa engine (inference_all_abstract_bayesian_bootstrap.R) has a guard
# shared by both its CI and p-value entry points -- ci_bayesian_bca() and pval_bayesian_bca() -- fired
# when approximate_bayesian_jackknife_distribution_beta_hat_T(), after filtering to finite values,
# leaves fewer than 2 usable jackknife replicates. This had no test reference anywhere (a sibling of
# the 7 compute_bayesian_bootstrap_two_sided_pval() guards closed earlier this session in
# test-bayesian-bootstrap-two-sided-pval-nonestimable-guards-reference.R -- that file's own bca test
# exercises pval_bayesian_bca() failing via a mocked error, a different branch of the same function).
# Reached via InferenceAllSimpleAverageDiff (the same fixture used for the sibling guards), mocking
# approximate_bayesian_jackknife_distribution_beta_hat_T() directly (unlockBinding, private) to return
# a single finite value.

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

test_that("pval_bayesian_bca() caches 'bayesian_bootstrap_bca_jackknife_unavailable' when fewer than 2 finite jackknife replicates remain", {
	f <- smd_boot_fixture()
	unlockBinding("approximate_bayesian_jackknife_distribution_beta_hat_T", f$priv)
	f$priv$approximate_bayesian_jackknife_distribution_beta_hat_T <- function(...) c(0.5, NA_real_)

	res <- f$priv$pval_bayesian_bca(boot_distr = rnorm(50, 0.5, 0.2), est = 0.5, delta = 0)
	expect_true(is.na(res))
	expect_identical(f$inf$get_nonestimable_reason(), "bayesian_bootstrap_bca_jackknife_unavailable")
})

test_that("ci_bayesian_bca() reports 'bayesian_bootstrap_bca_jackknife_unavailable' as an NA CI when fewer than 2 finite jackknife replicates remain", {
	f <- smd_boot_fixture(seed = 2L)
	unlockBinding("approximate_bayesian_jackknife_distribution_beta_hat_T", f$priv)
	f$priv$approximate_bayesian_jackknife_distribution_beta_hat_T <- function(...) numeric(0)

	ci <- f$priv$ci_bayesian_bca(boot_distr = rnorm(50, 0.5, 0.2), alpha = 0.05, est = 0.5)
	expect_true(all(is.na(ci)))
	expect_identical(f$inf$get_nonestimable_reason(), "bayesian_bootstrap_bca_jackknife_unavailable")
})
