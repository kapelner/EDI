library(testthat)
library(EDI)

# 2026-09-24: this file originally pinned a "zinb_fit_unavailable" nonestimable
# reason for this fixture (no genuine excess zeros), mirroring the sibling
# OBSERVATION in test-count-classes-estimates-match-glm-nb-and-pscl-and-zinb-
# kernel-reference.R. That reason is no longer reached here: fast_zinb.cpp's
# accept_zinb_near_stationary_gradient() (added after tracing a deterministic
# CI-only non-convergence -- runs 35921934011/35954909878/35960688203, always
# the exact same optimizer iterate) now accepts this fixture's fit as
# converged instead of failing it, since it was already unambiguously near-
# stationary. Verified locally (independent of that fix, since this fixture
# converges cleanly without needing the new fallback in every local
# environment tried): both the point estimate AND a second compute_estimate()
# call stay finite and the fit is never marked nonestimable("estimate") here.
# The asymptotic CI/p-value do still come back NA -- a separate, narrower SE-
# specific gap this fixture also happens to hit, unrelated to the fit-
# convergence fix and NOT flagged via is_nonestimable()/get_nonestimable_
# reason() at all, so nothing here asserts an exact reason string anymore.

skip_if_not_installed("pscl")

zinb_no_excess_zeros_fixture <- function(seed = 4L, n = 200L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	x <- rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rnbinom(n, size = 3, mu = exp(0.6 + 0.4 * w + 0.3 * x))
	des$add_all_subject_responses(y)
	inf <- InferenceCountZeroInflatedNegBin$new(des, verbose = FALSE)
	if (is.function(inf$set_estimand)) inf$set_estimand("conditional")
	inf
}

test_that("with no genuine excess zeros, the point estimate is finite and stable even though the asymptotic CI is not", {
	inf <- zinb_no_excess_zeros_fixture()
	e1 <- inf$compute_estimate()
	expect_true(is.finite(e1))

	ci <- suppressWarnings(inf$compute_asymp_confidence_interval())
	expect_true(all(is.na(ci)))

	e2 <- inf$compute_estimate()
	expect_true(is.finite(e2))
	expect_equal(e2, e1)
	expect_false(inf$is_nonestimable("estimate"))
})
