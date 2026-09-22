library(testthat)
library(EDI)

# InferenceIncidGCompRiskRatio's compute_rr_jackknife_wald_two_sided_pval() has its own "original estimate
# must be finite and positive" guard, caching "jackknife_original_risk_ratio_unavailable" and returning NA --
# the identical guard/reason on the sibling compute_rr_jackknife_wald_confidence_interval() is already tested
# (test-incid-gcomp-risk-ratio-and-related-jackknife-and-m-out-of-n-bootstrap-reference.R, which only stubs
# compute_estimate() and calls the CONFIDENCE INTERVAL method), but the p-value method's own copy of this exact
# branch -- reached only with a valid (positive) null delta, since an invalid delta short-circuits earlier on a
# DIFFERENT reason -- had no test calling it.

rr_fx <- function(seed = 3L, n = 80L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x)); des$assign_w_to_all_subjects()
	w <- des$get_w(); y <- rbinom(n, 1, plogis(-0.6 + 0.7 * w + 0.4 * x)); des$add_all_subject_responses(y)
	InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
}

test_that("compute_rr_jackknife_wald_two_sided_pval: an unusable (non-positive) original risk-ratio estimate is nonestimable, with a valid delta", {
	inf <- rr_fx()
	unlockBinding("compute_estimate", inf); inf$compute_estimate <- function(estimate_only = FALSE) -0.2
	pv <- inf$compute_jackknife_wald_two_sided_pval(1.2)
	expect_true(is.na(pv))
	expect_identical(inf$get_nonestimable_reason(), "jackknife_original_risk_ratio_unavailable")
	expect_true(inf$is_nonestimable("estimate"))

	inf2 <- rr_fx()
	unlockBinding("compute_estimate", inf2); inf2$compute_estimate <- function(estimate_only = FALSE) NA_real_
	pv2 <- inf2$compute_jackknife_wald_two_sided_pval(1.2)
	expect_true(is.na(pv2))
	expect_identical(inf2$get_nonestimable_reason(), "jackknife_original_risk_ratio_unavailable")

	inf3 <- rr_fx()
	unlockBinding("compute_estimate", inf3); inf3$compute_estimate <- function(estimate_only = FALSE) 0
	pv3 <- inf3$compute_jackknife_wald_two_sided_pval(1.2)
	expect_true(is.na(pv3))
	expect_identical(inf3$get_nonestimable_reason(), "jackknife_original_risk_ratio_unavailable")
})

test_that("this guard is reached only after the delta check: a non-positive delta gives a DIFFERENT reason even with an unusable original estimate", {
	inf <- rr_fx()
	unlockBinding("compute_estimate", inf); inf$compute_estimate <- function(estimate_only = FALSE) -0.2
	pv <- inf$compute_jackknife_wald_two_sided_pval(0)                    # delta <= 0 short-circuits first
	expect_true(is.na(pv))
	expect_identical(inf$get_nonestimable_reason(), "jackknife_log_risk_ratio_null_unavailable")
})

test_that("a usable positive original estimate does not trip this guard at all", {
	inf <- rr_fx()
	pv <- inf$compute_jackknife_wald_two_sided_pval(1)
	expect_true(is.finite(pv))
	expect_false(inf$is_nonestimable("any"))
})
