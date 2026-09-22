library(testthat)
library(EDI)

# helper_bootstrap_ci.R's bootstrap_studentized_pivots() has three sibling guards. Two -- "Studentized
# bootstrap requires finite positive standard errors." and "Studentized bootstrap returned too few
# stable standard errors." -- are already covered by
# test-bootstrap-studentized-pivot-filtering-ci-formulas-and-interval-scale-instability-reference.R
# (via a shortened substring match on each), but the third -- "Studentized bootstrap pivots are
# numerically unstable.", fired when the 97.5th percentile of |pivot| exceeds 50 -- had zero test
# references anywhere despite being a pure, directly callable internal helper (no inference-object
# construction needed at all). A handful of extreme-but-finite theta draws against an otherwise
# well-behaved standard error is enough to trip it.

test_that("bootstrap_studentized_pivots(): extreme theta draws relative to se trip the numerical-instability guard", {
	piv <- EDI:::bootstrap_studentized_pivots
	theta <- c(rep(0, 20), 1000)
	se <- rep(1, 21)
	expect_error(
		piv(theta, se, est = 0, se_hat = 1, min_number_usable_samples = 5L),
		"Studentized bootstrap pivots are numerically unstable\\."
	)
})

test_that("bootstrap_studentized_pivots(): well-scaled theta draws do NOT trip the instability guard", {
	set.seed(1)
	piv <- EDI:::bootstrap_studentized_pivots
	theta <- rnorm(200, mean = 0, sd = 1)
	se <- rep(1, 200)
	pivots <- piv(theta, se, est = 0, se_hat = 1, min_number_usable_samples = 5L)
	expect_true(is.numeric(pivots))
	expect_true(all(is.finite(pivots)))
})
