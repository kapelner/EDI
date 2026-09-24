library(testthat)
library(EDI)

# InferenceExtBcaBootstrapCI's shared bca_ci_core()/bca_pval_core() "unstable_bias_or_acceleration"
# branch already has thorough MATH coverage (test-bootstrap-bca-wrappers-and-core-instability-branches-
# reference.R), but that file calls bca_ci_core()/bca_pval_core() directly with a test-only reason_prefix
# ("bca_"), never the real production prefixes ("bootstrap_bca_" / "bayesian_bootstrap_bca_") a genuine
# class user would see via get_nonestimable_reason(). The sibling "adjustment_on_boundary" branch DOES
# have real-prefix coverage, through the public bootstrap-CI/pval API
# (test-bayesian-bootstrap-symmetric-studentized-bca-types.R), but "unstable_bias_or_acceleration" with
# the real prefixes was never exercised (confirmed via a zero-hit grep for both literal production
# strings). Reached by calling each of the four real private wrappers (ci_bca/pval_bca for plain
# bootstrap, ci_bayesian_bca/pval_bayesian_bca for the Bayesian bootstrap) directly with a hand-built
# boot_distr entirely on one side of est -- pinning p_less to the eps/1-eps boundary, which drives
# |z0| = |qnorm(p_less)| far past the 2.5 threshold -- while letting the jackknife distribution come
# from the real (ordinary) machinery, so only the z0 extremity triggers the guard.

bca_fixture <- function(n = 20L, seed = 1L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.3))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	list(inf = inf, priv = inf$.__enclos_env__$private, n = n)
}

extreme_boot_distr <- rep(0.1, 50)
extreme_est <- 5

test_that("ci_bca() caches 'bootstrap_bca_unstable_bias_or_acceleration' when z0 is extreme", {
	f <- bca_fixture()
	ci <- f$priv$ci_bca(extreme_boot_distr, 0.05, extreme_est)
	expect_true(all(is.na(ci)))
	expect_identical(f$inf$get_nonestimable_reason(), "bootstrap_bca_unstable_bias_or_acceleration")
})

test_that("pval_bca() caches the same exact reason", {
	f <- bca_fixture(seed = 2L)
	pv <- f$priv$pval_bca(extreme_boot_distr, extreme_est, 0.2)
	expect_true(is.na(pv))
	expect_identical(f$inf$get_nonestimable_reason(), "bootstrap_bca_unstable_bias_or_acceleration")
})

test_that("ci_bayesian_bca() caches 'bayesian_bootstrap_bca_unstable_bias_or_acceleration' when z0 is extreme", {
	f <- bca_fixture(seed = 3L)
	f$priv$current_bayesian_bootstrap_context <- list(row_to_unit = seq_len(f$n), unit_group_id = rep(1L, f$n), n_units = f$n)
	ci <- f$priv$ci_bayesian_bca(extreme_boot_distr, 0.05, extreme_est)
	expect_true(all(is.na(ci)))
	expect_identical(f$inf$get_nonestimable_reason(), "bayesian_bootstrap_bca_unstable_bias_or_acceleration")
})

test_that("pval_bayesian_bca() caches the same exact reason", {
	f <- bca_fixture(seed = 4L)
	f$priv$current_bayesian_bootstrap_context <- list(row_to_unit = seq_len(f$n), unit_group_id = rep(1L, f$n), n_units = f$n)
	pv <- f$priv$pval_bayesian_bca(extreme_boot_distr, extreme_est, 0.2)
	expect_true(is.na(pv))
	expect_identical(f$inf$get_nonestimable_reason(), "bayesian_bootstrap_bca_unstable_bias_or_acceleration")
})
