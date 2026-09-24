library(testthat)
library(EDI)

# InferenceCountZeroInflatedNegBin's "no genuine excess zeros" nonestimable path is already covered as
# a pinned OBSERVATION in test-count-classes-estimates-match-glm-nb-and-pscl-and-zinb-kernel-reference.R
# -- that test's own header comment even NAMES the reason ("zinb_fit_unavailable") but never actually
# asserts it via get_nonestimable_reason()/is_nonestimable(), only that the estimate becomes NA and the
# CI is all-NA. This closes that gap directly, matching the same "boolean/NA checked, exact reason
# string never asserted" pattern already closed for InferenceIncidLogRegr and InferenceIncidKKModified
# Poisson in earlier iterations. Same fixture (seed = 4, n = 200, no injected zero inflation) as the
# pinned-observation test, so the reason is reached exactly the same way.

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

test_that("with no genuine excess zeros, the full-fit failure caches the exact reason 'zinb_fit_unavailable'", {
	inf <- zinb_no_excess_zeros_fixture()
	e1 <- inf$compute_estimate()
	expect_true(is.finite(e1))                                             # estimate-only value still exists

	ci <- suppressWarnings(inf$compute_asymp_confidence_interval())
	expect_true(all(is.na(ci)))

	expect_true(is.na(inf$compute_estimate()))                             # the full fit having failed now poisons the cached estimate
	expect_true(inf$is_nonestimable("estimate"))
	expect_identical(inf$get_nonestimable_reason(), "zinb_fit_unavailable")
})
