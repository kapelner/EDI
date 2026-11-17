# Numerical-robustness review audit, 2026-11-17: .breslow_hazard() rescales risks by exp(eta -
# max(eta)) and then floors each risk-set sum at an absolute 1e-10. When the risk set at a later
# event time contains only subjects whose linear predictor is more than about 23 below the maximum,
# the true sum (e.g. 2*exp(-30) = 1.9e-13) is replaced by 1e-10. The cumulative baseline-hazard
# increment is then wrong by orders of magnitude (1e10 instead of 5.3e12), so Cox simulations that
# invert this hazard draw the wrong survival times.
# Where: R/EDI/R/helper_survival_fits.R:596 (kind: near_zero_division).
# On commit 4fc58cd063bc this test failed with: Expected `bh$cumhaz` to equal `ref`. Differences: 2/3
# mismatches (average diff: 1.07e+13) [2] 1e+10 - 5.34e+12 == -5.33e+12 [3] 2e+10 - 1.60e+13 ==
# -1.60e+13
# Tracked by v1.0.6-TODO-51; remove the skip() when that fix lands.

test_that("Breslow cumulative hazard is exact when late risk sets have very low relative risk", {
	skip("known bug, v1.0.6-TODO-51")
		y = c(1, 2, 3)
		dead = c(1, 1, 1)
		X = matrix(c(30, 0, 0), ncol = 1)
		b_null = 1
		bh = EDI:::.breslow_hazard(y, dead, X, b_null)
		risk = exp(as.numeric(X %*% b_null) - 30)
		ref = cumsum(c(1 / sum(risk), 1 / sum(risk[2:3]), 1 / risk[3]))
		expect_equal(bh$times, c(1, 2, 3))
		expect_equal(bh$cumhaz, ref, tolerance = 1e-8)
})
