library(testthat)
library(EDI)

# InferenceRandBootstrapCI's compute_rand_bootstrap_confidence_interval()
# (inference_all_abstract_rand_bootstrap_ci.R) has two distinct nonestimable guards, neither of which
# had a test reference anywhere:
#   1. "rand_bootstrap_ci_closed_form_unavailable": the affine closed-form shortcut (mean-difference/
#      OLS-treatment-coefficient classes only, InferenceAllSimpleAverageDiff among them) finds usable
#      affine null-draw coefficients and a finite observed statistic, but
#      closed_form_ci_from_affine_null_draws() itself returns a malformed (wrong-length) result.
#   2. "rand_bootstrap_ci_bisection_failed": the closed-form shortcut is skipped (affine coefficients
#      unavailable), the general bound-expansion search finds finite bracketing bounds, but both
#      bisection-search calls (invert_rand_bootstrap_test_bisection()) return non-finite results.
# Both reached via InferenceAllSimpleAverageDiff, mocking the exact private helper each site calls
# (unlockBinding) -- the real permutation-draw generation (generate_rand_bootstrap_draws()) and
# point-estimate computation are left real and cheap (small B, simple mean-difference formula); only
# the specific failure-producing step is mocked, the same technique already used for the sibling
# rand_ci_* guards closed the prior iteration on this session's continuous-work loop.

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

test_that("'rand_bootstrap_ci_closed_form_unavailable' fires when closed_form_ci_from_affine_null_draws() returns a malformed result", {
	f <- smd_fixture()
	unlockBinding("closed_form_ci_from_affine_null_draws", f$priv)
	f$priv$closed_form_ci_from_affine_null_draws <- function(...) numeric(1)  # wrong length (expects 2)

	ci <- f$inf$compute_rand_bootstrap_confidence_interval(B = 25L, show_progress = FALSE, type = "percentile")
	expect_true(all(is.na(ci)))
	expect_identical(f$inf$get_nonestimable_reason(), "rand_bootstrap_ci_closed_form_unavailable")
})

test_that("'rand_bootstrap_ci_bisection_failed' fires when bounds are finite but both bisection calls fail", {
	f <- smd_fixture(seed = 2L)
	unlockBinding("compute_rand_bootstrap_ci_affine_coefs", f$priv)
	f$priv$compute_rand_bootstrap_ci_affine_coefs <- function(...) NULL  # skip the closed-form shortcut
	unlockBinding("expand_rand_bootstrap_bound", f$priv)
	f$priv$expand_rand_bootstrap_bound <- function(bound, est, ...) bound  # always "succeeds" with a finite bound
	unlockBinding("invert_rand_bootstrap_test_bisection", f$priv)
	f$priv$invert_rand_bootstrap_test_bisection <- function(...) NA_real_

	ci <- f$inf$compute_rand_bootstrap_confidence_interval(B = 25L, show_progress = FALSE, type = "percentile")
	expect_true(all(is.na(ci)))
	expect_identical(f$inf$get_nonestimable_reason(), "rand_bootstrap_ci_bisection_failed")
})
