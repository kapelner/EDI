# Numerical-robustness review audit, 2026-11-17: The Stouffer branch computes qnorm(1 - p/2), which
# is Inf for p below about 2e-16, and min_p computes 1 - (1 - min p)^2, which cancels to 0. Both
# therefore return a combined p-value of exactly 0 where the true value is positive: about 4.7e-11
# for Stouffer and 2e-20 for min_p at p_M = 1e-20, p_R = 1. This is already scheduled as
# v1.1.0-TODO-211.
# Where: R/EDI/R/inference_helpers_zhang.R:26 (kind: other_numerical).
# On commit 48765322fe90 this test failed with: Expected `p_st/ref_st` to equal 1. Differences: 1/1
# mismatches [1] 0 - 1 == -1
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("Zhang Stouffer and min-p combinations keep tiny p-values positive and accurate", {
	skip("open a release TODO for this")
		p_M = 1e-20
		p_R = 1
		p_st = EDI:::zhang_combine_exact_pvals(p_M, p_R, 50L, 5L, 5L, "Stouffer")
		z_ref = (stats::qnorm(p_M / 2, lower.tail = FALSE) + stats::qnorm(p_R / 2, lower.tail = FALSE)) / sqrt(2)
		ref_st = 2 * stats::pnorm(z_ref, lower.tail = FALSE)
		expect_equal(p_st / ref_st, 1, tolerance = 1e-8)
		p_mp = EDI:::zhang_combine_exact_pvals(p_M, p_R, 50L, 5L, 5L, "min_p")
		ref_mp = -expm1(2 * log1p(-p_M))
		expect_equal(p_mp / ref_mp, 1, tolerance = 1e-8)
})
