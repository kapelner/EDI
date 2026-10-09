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

test_that("the generic bootstrap-randomization search forwards alpha to expansion, stopping, and bisection", {
	f <- smd_fixture(seed = 68L)
	p <- f$priv
	seen <- new.env(parent = emptyenv())
	seen$expansion <- numeric(0)
	seen$bisection <- numeric(0)
	seen$mc <- numeric(0)
	unlockBinding("compute_rand_bootstrap_ci_affine_coefs", p)
	p$compute_rand_bootstrap_ci_affine_coefs <- function(...) NULL
	unlockBinding("expand_rand_bootstrap_bound", p)
	p$expand_rand_bootstrap_bound <- function(bound, est, target_pval, ...) {
		seen$expansion <- c(seen$expansion, target_pval)
		seen$mc <- c(seen$mc, p$brt_mc_control$mc_stop_threshold)
		bound
	}
	unlockBinding("invert_rand_bootstrap_test_bisection", p)
	p$invert_rand_bootstrap_test_bisection <- function(l, u, pval_th, ...) {
		seen$bisection <- c(seen$bisection, pval_th)
		if (length(seen$bisection) == 1L) l else u
	}

	ci <- f$inf$compute_rand_bootstrap_confidence_interval(
		alpha = 0.2, B = 25L, pval_epsilon = 0.01, show_progress = FALSE, type = "percentile"
	)
	expect_true(all(is.finite(ci)))
	expect_equal(seen$expansion, c(0.2, 0.2))
	expect_equal(seen$bisection, c(0.2, 0.2))
	expect_equal(seen$mc, c(0.2, 0.2))
})

test_that("the affine bootstrap-randomization shortcut inverts at alpha rather than alpha/2", {
	f <- smd_fixture(seed = 69L)
	A <- seq(-2, 2, length.out = 20L)
	ci <- f$priv$closed_form_ci_from_affine_null_draws(
		A = A, c_slopes = rep(1, length(A)), t_obs = 0, alpha = 0.2
	)
	# At alpha/2 the 2/B floor equals the threshold and the old path returned NULL.
	expect_equal(ci, c(-1.78947368421053, 1.78947368421053), tolerance = 1e-12)
})
