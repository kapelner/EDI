library(testthat)
library(EDI)

# InferenceIncidGCompRiskRatio's compute_effect_pvalue() (the shared engine behind both compute_asymp_two_sided_pval()
# and compute_wald_two_sided_pval() for the RR estimand): delta must be strictly positive on the risk-ratio scale
# (delta = 0/negative is meaningless as a ratio null), rejected with an explicit error before any z-statistic is
# computed. Had no test calling either public wrapper with a non-positive delta on this estimand.

rr_fx <- function(seed = 3L, n = 80L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x)); des$assign_w_to_all_subjects()
	w <- des$get_w(); y <- rbinom(n, 1, plogis(-0.6 + 0.7 * w + 0.4 * x)); des$add_all_subject_responses(y)
	InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
}

test_that("compute_asymp_two_sided_pval: delta = 0 or negative is rejected with the exact documented message", {
	for (d in c(0, -1, -0.001)) {
		inf <- rr_fx()
		expect_error(inf$compute_asymp_two_sided_pval(delta = d), "For RR inference, delta must be strictly positive\\.", info = d)
	}
})

test_that("compute_wald_two_sided_pval: the identical guard (same shared compute_effect_pvalue engine)", {
	for (d in c(0, -1)) {
		inf <- rr_fx()
		expect_error(inf$compute_wald_two_sided_pval(delta = d), "For RR inference, delta must be strictly positive\\.", info = d)
	}
})

test_that("a strictly positive delta does not trip the guard and returns a finite p-value", {
	inf <- rr_fx()
	pv <- inf$compute_asymp_two_sided_pval(delta = 1.2)
	expect_true(is.finite(pv) && pv >= 0 && pv <= 1)
	inf2 <- rr_fx()
	pv2 <- inf2$compute_wald_two_sided_pval(delta = 1.2)
	expect_equal(pv2, pv, tolerance = 1e-10)
})

# Confirmed source bug, NOT fixed here (out of scope for this coverage-writing pass): delta = NA does NOT
# reach the intended "delta must be strictly positive" validation message. assertNumeric(delta, len = 1) allows
# NA through (checkmate's default is any.missing = TRUE), and `if (delta <= 0)` with delta = NA then crashes with
# a generic, unhelpful R condition ("missing value where TRUE/FALSE needed") instead of a clear validation error.
test_that("KNOWN BUG: delta = NA crashes with a generic R error instead of the intended validation message", {
	inf <- rr_fx()
	expect_error(inf$compute_asymp_two_sided_pval(delta = NA_real_), "missing value where TRUE/FALSE needed")
})
