# Numerical-robustness review audit, 2026-11-19: run_all_inference_combine_pvalues() counts a row as
# usable when it has a finite weight, even if that weight is zero. Under combined_evidence_weighting
# = "custom" (non-negative weights; unnamed classes get 0), the usable rows can all carry weight 0.
# cct_combine_pvalues_full() then computes weights / sum(weights) = 0/0, and the combined p-value is
# NaN. With exactly one positive weight, it reports that single p-value as a 'combined' result, which
# breaks the documented fewer-than-2 -> NA contract.
# Where: R/EDI/R/inference_suite.R:4059 (kind: near_zero_division).
# On commit 0231668c948b this test failed with: Expected `is.nan(res0$pval)` to be FALSE.
# Differences: `actual`: TRUE `expected`: FALSE
# Tracked as v1.0.6-TODO-386; remove the skip() when it is fixed.

test_that("combined evidence returns NA, not NaN or a single p-value, when fewer than two rows carry positive weight", {
	skip("v1.0.6-TODO-386: zero custom weights count as usable, giving NaN or a single combined p-value")
		res0 = EDI:::run_all_inference_combine_pvalues(c(0.01, 0.2, 0.5), c(0, 0, 0))
		expect_false(is.nan(res0$pval))
		expect_true(is.na(res0$pval))
		res1 = EDI:::run_all_inference_combine_pvalues(c(0.01, 0.2, 0.5), c(1, 0, 0))
		expect_true(is.na(res1$pval))
})
