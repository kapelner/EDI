library(testthat)
library(EDI)

# InferenceIncidGCompRiskRatio's private compute_rr_resampling_pivot() (inference_incidence_gcomp_
# abstract.R) has a preflight guard -- an unusable (nonpositive or non-finite) original point estimate
# short-circuits every downstream subsampling/m-out-of-n RR method with reason
# "resampling_original_estimate_unavailable" -- already exercised (via the exact same unlockBinding(
# "compute_estimate") override technique) in test-gcomp-risk-ratio-subsampling-m-out-of-n-pivot-
# reference.R's own "unusable original estimate" block, but that test only asserts
# is_nonestimable("estimate")/all-NA outputs, never the specific reason string -- confirmed via a
# zero-hit grep for the literal string across the whole test suite. Closes it directly across all
# three public entry points that route through this shared pivot: compute_subsampling_confidence_
# interval(), compute_subsampling_two_sided_pval(), and compute_m_out_of_n_bootstrap_confidence_
# interval() (the m-out-of-n pval variant shares the identical pivot call and reason propagation, so
# is not re-tested separately).

rr_fixture <- function(n = 60L, seed = 4L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(-0.5 + 0.9 * w + 0.3 * x))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	inf
}

force_bad_estimate <- function(inf, bad) {
	unlockBinding("compute_estimate", inf)
	inf$compute_estimate <- function(estimate_only = FALSE) bad
	inf
}

test_that("compute_subsampling_confidence_interval() caches the exact reason 'resampling_original_estimate_unavailable'", {
	for (bad in list(0, -1, NA_real_)) {
		inf <- force_bad_estimate(rr_fixture(), bad)
		ci <- inf$compute_subsampling_confidence_interval(B = 40, b = 15, show_progress = FALSE)
		expect_true(all(is.na(ci)), info = format(bad))
		expect_identical(inf$get_nonestimable_reason(), "resampling_original_estimate_unavailable", info = format(bad))
	}
})

test_that("compute_subsampling_two_sided_pval() caches the same exact reason", {
	inf <- force_bad_estimate(rr_fixture(seed = 5L), NA_real_)
	pv <- inf$compute_subsampling_two_sided_pval(B = 40, b = 15, show_progress = FALSE)
	expect_true(is.na(pv))
	expect_identical(inf$get_nonestimable_reason(), "resampling_original_estimate_unavailable")
})

test_that("compute_m_out_of_n_bootstrap_confidence_interval() caches the same exact reason", {
	inf <- force_bad_estimate(rr_fixture(seed = 6L), -1)
	ci <- inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 40, m = 15, show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_identical(inf$get_nonestimable_reason(), "resampling_original_estimate_unavailable")
})
