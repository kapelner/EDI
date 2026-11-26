# Numerical-robustness review audit, 2026-11-17: zhang_combine_exact_pvals treats a matched-pairs
# p-value that has underflowed to exactly 0 as missing (`has_M` requires p_M > 0) and returns the
# reservoir p-value alone. With many discordant pairs, p_M is exactly 0 at a moderate delta (k =
# 1000, delta = 8.5). If the reservoir has a zero cell, so that p_R is about 1 at large delta, the CI
# bisection never sees a rejection and returns an upper endpoint of +Inf, even though the matched
# pairs pin the endpoint below 0.5.
# Where: R/EDI/R/inference_helpers_zhang.R:17 (kind: other_numerical).
# On commit 48765322fe90 this test failed with: Expected `p_fn(8.5)` <= 0.05. Actual comparison: 1.00
# > 0.05 Difference: 0.95 > 0
# Tracked as v1.0.7-TODO-97; remove the skip() when it is fixed.

test_that("Zhang combined p-value does not drop an underflowed matched-pairs p-value and the exact CI stays finite", {
	skip("v1.0.7-TODO-97: has_M treats an underflowed p_M = 0 as missing")
		d_plus = 500L
		d_minus = 500L
		n11 = 3L; n10 = 0L; n01 = 1L; n00 = 2L
		p_fn = function(delta_0){
			p_M = EDI:::zhang_exact_binom_pval_cpp(d_plus, d_minus, delta_0)
			p_R = EDI:::zhang_exact_fisher_pval_cpp(n11, n10, n01, n00, delta_0)
			EDI:::zhang_combine_exact_pvals(p_M, p_R, 1000L, 3L, 3L, "Fisher")
		}
		# 1000 balanced discordant pairs reject delta = 8.5 overwhelmingly; the combined test must too
		expect_lte(p_fn(8.5), 0.05)
		upper = EDI:::zhang_bisect_ci_boundary(p_fn, inside = 0, outside = 8.5, pval_th = 0.05, tol = 1e-6)
		expect_true(is.finite(upper))
		expect_lt(upper, 1)
})
