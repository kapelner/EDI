library(testthat)
library(EDI)

# InferenceRandBootstrap's compute_rand_bootstrap_two_sided_pval() (inference_all_abstract_rand_
# bootstrap.R) has a preflight guard -- fired when compute_treatment_estimate_during_randomization_
# inference() returns a non-finite (or wrong-length) observed statistic, before any bootstrap draw is
# ever generated -- that had no test reference anywhere. Reached via InferenceAllSimpleAverageDiff
# (the same fixture used for the sibling rand_bootstrap_ci_* guards closed the prior iteration),
# mocking the exact private helper this site calls (unlockBinding); no real permutation/bootstrap
# work is needed since the guard fires before any is done.

smd_fixture <- function(n = 20L, seed = 1L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.5))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("'rand_bootstrap_observed_statistic_unavailable' fires when the observed treatment statistic is non-finite", {
	f <- smd_fixture()
	unlockBinding("compute_treatment_estimate_during_randomization_inference", f$priv)
	f$priv$compute_treatment_estimate_during_randomization_inference <- function(...) NA_real_

	pval <- f$inf$compute_rand_bootstrap_two_sided_pval(B = 25L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "rand_bootstrap_observed_statistic_unavailable")
})

test_that("'rand_bootstrap_observed_statistic_unavailable' fires when the observed statistic is a length-0 vector", {
	f <- smd_fixture(seed = 2L)
	unlockBinding("compute_treatment_estimate_during_randomization_inference", f$priv)
	f$priv$compute_treatment_estimate_during_randomization_inference <- function(...) numeric(0)

	pval <- f$inf$compute_rand_bootstrap_two_sided_pval(B = 25L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(f$inf$get_nonestimable_reason(), "rand_bootstrap_observed_statistic_unavailable")
})
