# Numerical-robustness review audit, 2026-11-17: When every treated subject has the event and no
# control subject does (p_T = 1, p_C = 0, so the estimate is 1), compute_asymp_two_sided_pval(delta =
# 1) returns the alpha floor 1e-300. The p-value should be 1: delta equals the estimate, and the
# Newcombe upper bound, capped at 1, contains delta at every alpha. The upper-boundary branch
# measures ci[2] - delta, which is exactly 0 at the floor, and the test `at_floor <= 0` counts that 0
# as 'outside the interval'.
# Where: R/EDI/R/inference_incidence_newcombe_univ.R:197 (kind: other_numerical).
# On commit 48765322fe90 this test failed with: Expected `pval` to equal 1. Differences: 1/1
# mismatches [1] 1e-300 - 1 == -1
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("Newcombe p-value is one when delta equals a boundary estimate of one", {
	skip("open a release TODO for this")
		n = 20L
		w = rep(c(1, 0), length.out = n)
		y = as.numeric(w == 1)
		des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence")
		for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i / 10))
		des$overwrite_all_subject_assignments(w)
		des$add_all_subject_responses(y)
		inf = InferenceIncidNewcombeRiskDiff$new(des)
		expect_equal(inf$compute_estimate(), 1)
		ci = inf$compute_asymp_confidence_interval(alpha = 0.05)
		expect_true(ci[1] <= 1 && ci[2] >= 1)
		pval = inf$compute_asymp_two_sided_pval(delta = 1)
		expect_equal(pval, 1)
})
