library(testthat)
library(EDI)

# summary_glm_lean()'s estimated-dispersion branch (helper_robust_regression.R) has a zero-weight
# guard -- warn("observations with zero weight not used for calculating dispersion") -- ported
# verbatim from stats::summary.glm(), matching its own identical warning for this exact scenario.
# test-summary-glm-lean-dispersion-branches-aliasing-and-correlation-reference.R already covers the
# estimated-dispersion branch generally (all weights positive) but never with any zero-weight rows,
# so this specific warning had no test reference anywhere (confirmed via a zero-hit grep for its
# literal text). Reference: stats::summary.glm() on the identical fit, which fires the same warning
# and computes the same dispersion (both drop the zero-weight rows from the residual sum of squares).

test_that("zero-weight rows trigger the documented warning and match summary.glm()'s own dispersion exactly", {
	set.seed(1L); n <- 30L
	x <- rnorm(n)
	y <- 1 + 2 * x + rnorm(n)
	w <- rep(1, n); w[1:5] <- 0
	fit <- glm(y ~ x, family = gaussian(), weights = w)

	expect_warning(
		lean <- EDI:::summary_glm_lean(fit),
		"observations with zero weight not used for calculating dispersion"
	)
	ref <- suppressWarnings(summary(fit))
	expect_equal(lean$dispersion, ref$dispersion, tolerance = 1e-12)
	expect_equal(lean$coefficients, ref$coefficients, tolerance = 1e-12)
})

test_that("no zero-weight rows: the same warning is NOT emitted", {
	set.seed(2L); n <- 30L
	x <- rnorm(n)
	y <- 1 + 2 * x + rnorm(n)
	fit <- glm(y ~ x, family = gaussian())

	expect_no_warning(EDI:::summary_glm_lean(fit))
})
